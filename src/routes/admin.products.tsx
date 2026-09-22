import { createFileRoute } from "@tanstack/react-router";
import { useState, useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import { ALL_PRODUCTS, ProductDetailItem } from "@/data/allProductsData";
import { uploadAdminImage } from "@/lib/admin";
import JSZip from "jszip";
import {
  listDriveProductImages,
  fetchDriveImage,
  type DriveFolderImage,
} from "@/lib/driveImport.functions";


export const Route = createFileRoute("/admin/products")({
  component: AdminProductsPage,
});

export type DbProduct = {
  id?: string;
  slug: string;
  category: string;
  group_name: string;
  label: string;
  name: string;
  detail: string;
  specs: string[];
  image_url: string;
  sort_order: number;
  published: boolean;
};

export type ZipMatchItem = {
  id: string;
  fileName: string;
  file: File;
  previewUrl: string;
  matchedSlug: string;
  score: number;
  selectedSlug: string;
  replaceName: boolean;
  newName: string;
  status: "idle" | "uploading" | "done" | "error";
};

const CATEGORIES = [
  { key: "all", label: "All Categories" },
  { key: "exosome", label: "Exosomes" },
  { key: "dermal-fillers", label: "Dermal Fillers" },
  { key: "peptide-bio-remodeling", label: "Peptide-Based Bio-Remodeling" },
  { key: "botulinum-toxin", label: "Botulinum Toxin" },
  { key: "pdrn-pn", label: "PDRN / PN Solutions" },
];

function calculateMatchScore(fileName: string, product: DbProduct): number {
  const cleanName = fileName
    .toLowerCase()
    .replace(/\.[^/.]+$/, "") // Remove extension
    .replace(/[-_]/g, " ") // Replace dashes & underscores
    .replace(/\b(vial|image|photo|pic|kit|final|copy|new|product|img|\d+px|\d+x\d+)\b/gi, "")
    .trim();

  const prodText = `${product.name} ${product.slug} ${product.group_name} ${product.label}`.toLowerCase();

  const fileTokens = cleanName.split(/\s+/).filter((t) => t.length > 1);
  if (fileTokens.length === 0) return 0;

  let matches = 0;
  for (const ft of fileTokens) {
    if (prodText.includes(ft)) {
      matches += 1;
    }
  }

  // Exact slug match bonus
  if (product.slug.toLowerCase().includes(cleanName) || cleanName.includes(product.slug.toLowerCase())) {
    return 100;
  }

  return Math.min(100, Math.round((matches / fileTokens.length) * 100));
}

function AdminProductsPage() {
  const [products, setProducts] = useState<DbProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");

  // Modal State
  const [editingItem, setEditingItem] = useState<DbProduct | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // Initial Form Data
  const [formData, setFormData] = useState<DbProduct>({
    slug: "",
    category: "exosome",
    group_name: "",
    label: "",
    name: "",
    detail: "",
    specs: [],
    image_url: "",
    sort_order: 0,
    published: true,
  });

  // ZIP AI Batch Importer State
  const [isZipModalOpen, setIsZipModalOpen] = useState(false);
  const [zipFile, setZipFile] = useState<File | null>(null);
  const [zipMatches, setZipMatches] = useState<ZipMatchItem[]>([]);
  const [parsingZip, setParsingZip] = useState(false);
  const [batchUploading, setBatchUploading] = useState(false);
  const [batchProgress, setBatchProgress] = useState({ current: 0, total: 0 });
  const [zipMsg, setZipMsg] = useState<string | null>(null);
  const zipInputRef = useRef<HTMLInputElement>(null);

  const handleZipFileSelected = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.name.endsWith(".zip")) {
      alert("Please select a valid .ZIP file containing product images!");
      return;
    }

    setZipFile(file);
    setParsingZip(true);
    setZipMsg("Unpacking ZIP archive and running AI matching...");
    setZipMatches([]);

    try {
      const zip = new JSZip();
      const content = await zip.loadAsync(file);

      const items: ZipMatchItem[] = [];

      for (const [relativePath, entry] of Object.entries(content.files)) {
        if (entry.dir) continue;
        const lower = relativePath.toLowerCase();
        if (
          lower.endsWith(".png") ||
          lower.endsWith(".jpg") ||
          lower.endsWith(".jpeg") ||
          lower.endsWith(".webp") ||
          lower.endsWith(".gif") ||
          lower.endsWith(".svg")
        ) {
          const blob = await entry.async("blob");
          const fileName = relativePath.split("/").pop() || relativePath;
          const imageFile = new File([blob], fileName, { type: blob.type || "image/jpeg" });
          const previewUrl = URL.createObjectURL(blob);

          // Find best matching DB product
          let bestSlug = "";
          let maxScore = 0;

          products.forEach((p) => {
            const score = calculateMatchScore(fileName, p);
            if (score > maxScore) {
              maxScore = score;
              bestSlug = p.slug;
            }
          });

          // Fallback to first product if no match
          if (!bestSlug && products[0]) {
            bestSlug = products[0].slug;
          }

          const matchedProd = products.find((p) => p.slug === bestSlug);

          items.push({
            id: Math.random().toString(36).substring(2, 9),
            fileName,
            file: imageFile,
            previewUrl,
            matchedSlug: bestSlug,
            score: maxScore,
            selectedSlug: bestSlug,
            replaceName: false,
            newName: matchedProd ? matchedProd.name : "",
            status: "idle",
          });
        }
      }

      setZipMatches(items);
      setZipMsg(`Extracted ${items.length} images from ZIP archive!`);
    } catch (err: any) {
      setZipMsg("Error reading ZIP file: " + err.message);
    } finally {
      setParsingZip(false);
      e.target.value = "";
    }
  };

  const handleExecuteBatchUpload = async () => {
    if (zipMatches.length === 0) return;
    setBatchUploading(true);
    setBatchProgress({ current: 0, total: zipMatches.length });
    setZipMsg("Starting batch upload & DB synchronization...");

    let successCount = 0;

    for (let i = 0; i < zipMatches.length; i++) {
      const match = zipMatches[i];
      if (!match) continue;
      setBatchProgress({ current: i + 1, total: zipMatches.length });

      try {
        setZipMatches((prev) =>
          prev.map((m) => (m.id === match.id ? { ...m, status: "uploading" } : m))
        );

        // Upload image to Supabase
        const publicUrl = await uploadAdminImage(match.file, "products");

        // Update product in DB
        const prod = products.find((p) => p.slug === match.selectedSlug);
        if (prod) {
          const updateData: any = {
            image_url: publicUrl,
            updated_at: new Date().toISOString(),
          };

          if (match.replaceName && match.newName.trim()) {
            updateData.name = match.newName.trim();
          }

          const { error } = await supabase
            .from("products")
            .update(updateData)
            .eq("slug", match.selectedSlug);

          if (error) {
            console.error("Failed to update product DB row:", error);
          }
        }

        successCount++;
        setZipMatches((prev) =>
          prev.map((m) => (m.id === match.id ? { ...m, status: "done" } : m))
        );
      } catch (err: any) {
        console.error("Failed to process item:", match.fileName, err);
        setZipMatches((prev) =>
          prev.map((m) => (m.id === match.id ? { ...m, status: "error" } : m))
        );
      }
    }

    setZipMsg(`Batch upload complete! Updated ${successCount} products in database.`);
    setBatchUploading(false);
    loadProducts(); // Reload DB items
  };

  const handleImageFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingImage(true);
    setMsg("Uploading image from PC...");
    try {
      const url = await uploadAdminImage(file, "products");
      setFormData((prev) => ({ ...prev, image_url: url }));
      setMsg("Image uploaded successfully!");
    } catch (err: any) {
      setMsg("Image Upload Error: " + err.message);
    } finally {
      setUploadingImage(false);
      e.target.value = "";
    }
  };

  // Load products from Supabase DB, or fallback to ALL_PRODUCTS
  const loadProducts = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("products")
        .select("*")
        .order("category", { ascending: true })
        .order("sort_order", { ascending: true });

      if (error || !data || data.length === 0) {
        // Fallback to static ALL_PRODUCTS
        const list: DbProduct[] = [];
        let orderCounter = 0;
        for (const [catKey, catItems] of Object.entries(ALL_PRODUCTS)) {
          catItems.forEach((item: ProductDetailItem) => {
            list.push({
              slug: item.slug,
              category: catKey,
              group_name: item.group || "",
              label: item.label || "",
              name: item.name,
              detail: item.detail,
              specs: item.specs || [],
              image_url: "",
              sort_order: orderCounter++,
              published: true,
            });
          });
        }
        setProducts(list);
      } else {
        setProducts(
          data.map((d: any) => ({
            id: d.id,
            slug: d.slug,
            category: d.category,
            group_name: d.group_name || "",
            label: d.label || "",
            name: d.name,
            detail: d.detail || "",
            specs: Array.isArray(d.specs) ? d.specs : [],
            image_url: d.image_url || "",
            sort_order: d.sort_order || 0,
            published: d.published ?? true,
          }))
        );
      }
    } catch (err) {
      console.error("Failed to load products", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProducts();
  }, []);

  const handleOpenAddModal = () => {
    setEditingItem(null);
    setFormData({
      slug: "",
      category: selectedCategory !== "all" ? selectedCategory : "exosome",
      group_name: "",
      label: "",
      name: "",
      detail: "",
      specs: [],
      image_url: "",
      sort_order: products.length,
      published: true,
    });
    setMsg(null);
    setIsModalOpen(true);
  };

  const handleOpenEditModal = (item: DbProduct) => {
    setEditingItem(item);
    setFormData({ ...item });
    setMsg(null);
    setIsModalOpen(true);
  };

  const handleDelete = async (slug: string) => {
    if (!confirm(`Are you sure you want to delete product "${slug}"?`)) return;
    try {
      const { error } = await supabase.from("products").delete().eq("slug", slug);
      if (error) {
        alert("Failed to delete from DB: " + error.message);
      }
      setProducts((prev) => prev.filter((p) => p.slug !== slug));
    } catch (err) {
      console.error(err);
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setMsg(null);

    const slugToSave =
      formData.slug.trim() ||
      formData.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "");

    const payload = {
      slug: slugToSave,
      category: formData.category,
      group_name: formData.group_name,
      label: formData.label,
      name: formData.name,
      detail: formData.detail,
      specs: formData.specs,
      image_url: formData.image_url,
      sort_order: formData.sort_order,
      published: formData.published,
      updated_at: new Date().toISOString(),
    };

    try {
      const { error } = await supabase.from("products").upsert(payload, { onConflict: "slug" });

      if (error) {
        setMsg("Save Warning: " + error.message + " (Updated locally)");
      } else {
        setMsg("Product saved successfully!");
      }

      // Update local state
      setProducts((prev) => {
        const exists = prev.some((p) => p.slug === slugToSave);
        if (exists) {
          return prev.map((p) => (p.slug === slugToSave ? { ...formData, slug: slugToSave } : p));
        } else {
          return [{ ...formData, slug: slugToSave }, ...prev];
        }
      });

      setTimeout(() => {
        setIsModalOpen(false);
      }, 800);
    } catch (err: any) {
      setMsg("Error: " + err.message);
    } finally {
      setSaving(false);
    }
  };

  // Filter products
  const filteredProducts = products.filter((p) => {
    const matchesCat = selectedCategory === "all" || p.category === selectedCategory;
    const matchesQuery =
      searchQuery.trim() === "" ||
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.slug.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.group_name.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesQuery;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-hairline pb-4">
        <div>
          <h1 className="text-xl font-bold text-navy">Products Catalogue Manager</h1>
          <p className="text-xs text-muted-foreground">
            Manage all 79+ products across Exosomes, Fillers, Peptides, Toxin & PDRN with full CRUD.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => {
              setZipMsg(null);
              setIsZipModalOpen(true);
            }}
            className="rounded-sm bg-navy px-4 py-2 text-xs font-semibold uppercase tracking-[0.12em] text-white hover:bg-navy/90 flex items-center gap-1.5 shadow-sm"
          >
            <span>📦</span> Batch Upload ZIP (AI Matcher)
          </button>

          <button
            onClick={handleOpenAddModal}
            className="rounded-sm bg-teal px-4 py-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#05231f] transition-opacity hover:opacity-90"
          >
            + Add New Product
          </button>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center gap-4 bg-card p-4 border border-hairline">
        <div className="flex-1 min-w-[240px]">
          <input
            type="text"
            placeholder="Search by product name, group or slug..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full border border-hairline bg-background px-3 py-2 text-xs outline-none focus:border-teal"
          />
        </div>

        <div className="flex flex-wrap gap-2">
          {CATEGORIES.map((cat) => (
            <button
              key={cat.key}
              onClick={() => setSelectedCategory(cat.key)}
              className={`rounded-sm px-3 py-1.5 text-xs font-medium transition-colors ${
                selectedCategory === cat.key
                  ? "bg-navy text-white"
                  : "bg-background text-navy hover:bg-navy/5 border border-hairline"
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </div>

      {/* Product List Table */}
      {loading ? (
        <div className="p-12 text-center text-xs text-muted-foreground">Loading products database...</div>
      ) : (
        <div className="overflow-x-auto border border-hairline bg-card shadow-sm">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-hairline bg-navy/5 font-semibold text-navy uppercase tracking-[0.1em] text-[0.68rem]">
              <tr>
                <th className="p-3">Category</th>
                <th className="p-3">Product Name & Group</th>
                <th className="p-3">Slug</th>
                <th className="p-3">Specs</th>
                <th className="p-3 text-center">Status</th>
                <th className="p-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline">
              {filteredProducts.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-muted-foreground">
                    No products found matching your search.
                  </td>
                </tr>
              ) : (
                filteredProducts.map((p) => (
                  <tr key={p.slug} className="hover:bg-navy/5 transition-colors">
                    <td className="p-3 font-medium text-teal capitalize">
                      {p.category.replace(/-/g, " ")}
                    </td>
                    <td className="p-3">
                      <p className="font-semibold text-navy">{p.name}</p>
                      {p.group_name && (
                        <span className="inline-block mt-0.5 rounded-full bg-science/10 px-2 py-0.5 text-[0.62rem] font-medium text-science">
                          {p.group_name}
                        </span>
                      )}
                    </td>
                    <td className="p-3 text-muted-foreground font-mono text-[0.72rem]">{p.slug}</td>
                    <td className="p-3 text-muted-foreground max-w-xs truncate">
                      {p.specs && p.specs.length > 0 ? `${p.specs.length} specs` : "—"}
                    </td>
                    <td className="p-3 text-center">
                      <span
                        className={`inline-block rounded-full px-2 py-0.5 text-[0.62rem] font-semibold ${
                          p.published ? "bg-teal/20 text-teal" : "bg-muted text-muted-foreground"
                        }`}
                      >
                        {p.published ? "Active" : "Draft"}
                      </span>
                    </td>
                    <td className="p-3 text-right space-x-2">
                      <button
                        onClick={() => handleOpenEditModal(p)}
                        className="rounded border border-navy/20 px-2.5 py-1 text-[0.68rem] font-semibold text-navy hover:bg-navy/10"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(p.slug)}
                        className="rounded border border-red-200 px-2.5 py-1 text-[0.68rem] font-semibold text-red-600 hover:bg-red-50"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal Dialog for Add / Edit */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-2xl max-h-[90vh] overflow-y-auto border border-hairline bg-card p-6 shadow-xl">
            <div className="flex items-center justify-between border-b border-hairline pb-3 mb-4">
              <h2 className="text-base font-bold text-navy">
                {editingItem ? `Edit Product: ${editingItem.name}` : "Add New Product"}
              </h2>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-muted-foreground hover:text-navy text-lg leading-none"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSave} className="space-y-4 text-xs">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block font-semibold text-navy mb-1">Product Title / Name *</label>
                  <input
                    required
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal"
                    placeholder="e.g. Lyophilized hUC-MSC Exosomes 50B"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-navy mb-1">URL Slug</label>
                  <input
                    type="text"
                    value={formData.slug}
                    onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal font-mono text-[0.72rem]"
                    placeholder="auto-generated if left blank"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block font-semibold text-navy mb-1">Category *</label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal"
                  >
                    <option value="exosome">Exosomes</option>
                    <option value="dermal-fillers">Dermal Fillers</option>
                    <option value="peptide-bio-remodeling">Peptide-Based Bio-Remodeling</option>
                    <option value="botulinum-toxin">Botulinum Toxin</option>
                    <option value="pdrn-pn">PDRN / PN Solutions</option>
                  </select>
                </div>

                <div>
                  <label className="block font-semibold text-navy mb-1">Sub-Group / Platform Name</label>
                  <input
                    type="text"
                    value={formData.group_name}
                    onChange={(e) => setFormData({ ...formData, group_name: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal"
                    placeholder="e.g. ExoGenesis™, Lyophilized hUC-MSC, HYALIQUE-X™"
                  />
                </div>
              </div>

              <div>
                <label className="block font-semibold text-navy mb-1">Product Description / Details</label>
                <textarea
                  rows={4}
                  value={formData.detail}
                  onChange={(e) => setFormData({ ...formData, detail: e.target.value })}
                  className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal leading-relaxed"
                  placeholder="Detailed overview fetched from Google Docs..."
                />
              </div>

              <div>
                <label className="block font-semibold text-navy mb-1">
                  Specifications (One per line)
                </label>
                <textarea
                  rows={4}
                  value={formData.specs.join("\n")}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      specs: e.target.value.split("\n").filter((s) => s.trim() !== ""),
                    })
                  }
                  className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal font-mono text-[0.72rem]"
                  placeholder="Source: Human Umbilical Cord MSCs&#10;Exosome Content: 10 Billion Particles&#10;Format: Lyophilized Powder"
                />
              </div>

              <div>
                <label className="block font-semibold text-navy mb-1">Product Image</label>
                <div className="space-y-2">
                  <div className="flex items-center gap-3">
                    <button
                      type="button"
                      disabled={uploadingImage}
                      onClick={() => fileInputRef.current?.click()}
                      className="rounded bg-navy px-4 py-2 text-xs font-semibold text-white hover:bg-navy/90 disabled:opacity-50 flex items-center gap-1.5"
                    >
                      <span>📁</span> {uploadingImage ? "Uploading from PC..." : "Upload Image from PC"}
                    </button>

                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={handleImageFileUpload}
                    />

                    <span className="text-[0.68rem] text-muted-foreground">or paste URL below</span>
                  </div>

                  <input
                    type="text"
                    value={formData.image_url}
                    onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal font-mono text-[0.72rem]"
                    placeholder="https://... or upload from PC above"
                  />

                  {formData.image_url && (
                    <div className="mt-2 flex items-center gap-3 border border-hairline bg-background p-2 rounded">
                      <img
                        src={formData.image_url}
                        alt="Product Preview"
                        className="h-16 w-16 object-cover rounded border border-hairline"
                        onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
                      />
                      <div>
                        <p className="text-[0.7rem] font-semibold text-navy">Uploaded Image Preview</p>
                        <p className="text-[0.62rem] text-muted-foreground truncate max-w-xs">{formData.image_url}</p>
                        <button
                          type="button"
                          onClick={() => setFormData({ ...formData, image_url: "" })}
                          className="text-[0.62rem] font-semibold text-red-600 hover:underline mt-0.5"
                        >
                          Remove Image
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-2 pt-2">
                <input
                  type="checkbox"
                  id="pub"
                  checked={formData.published}
                  onChange={(e) => setFormData({ ...formData, published: e.target.checked })}
                  className="h-4 w-4 rounded border-hairline text-teal focus:ring-teal"
                />
                <label htmlFor="pub" className="font-semibold text-navy">
                  Published & Visible on Website
                </label>
              </div>

              {msg && <p className="text-xs font-semibold text-teal mt-2">{msg}</p>}

              <div className="flex justify-end gap-3 pt-4 border-t border-hairline">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="rounded border border-hairline px-4 py-2 font-semibold text-navy hover:bg-navy/5"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="rounded bg-teal px-5 py-2 font-semibold uppercase tracking-[0.1em] text-[#05231f] hover:opacity-90 disabled:opacity-50"
                >
                  {saving ? "Saving..." : "Save Product"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ZIP AI Importer Modal */}
      {isZipModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm">
          <div className="w-full max-w-4xl max-h-[90vh] overflow-y-auto border border-hairline bg-card p-6 shadow-2xl space-y-5 rounded-sm">
            <div className="flex items-center justify-between border-b border-hairline pb-3">
              <div>
                <h2 className="text-base font-bold text-navy flex items-center gap-2">
                  <span>📦</span> AI ZIP Image & Product Auto-Matcher
                </h2>
                <p className="text-[0.72rem] text-muted-foreground">
                  Upload a ZIP file containing product images. Our AI matcher will pair images with database products by filename.
                </p>
              </div>
              <button
                onClick={() => setIsZipModalOpen(false)}
                className="text-muted-foreground hover:text-navy text-lg leading-none"
              >
                ✕
              </button>
            </div>

            {/* ZIP File Input Dropzone */}
            <div className="border-2 border-dashed border-teal/40 bg-teal/5 p-6 text-center rounded-sm space-y-3">
              <input
                ref={zipInputRef}
                type="file"
                accept=".zip"
                className="hidden"
                onChange={handleZipFileSelected}
              />

              <div className="flex justify-center text-3xl">📦</div>
              <div>
                <p className="text-xs font-bold text-navy">
                  {zipFile ? zipFile.name : "Select or Drop Product Images .ZIP File"}
                </p>
                <p className="text-[0.68rem] text-muted-foreground mt-0.5">
                  Supports .zip files containing .png, .jpg, .webp, .svg images
                </p>
              </div>

              <button
                type="button"
                disabled={parsingZip || batchUploading}
                onClick={() => zipInputRef.current?.click()}
                className="rounded bg-navy px-5 py-2 text-xs font-semibold text-white hover:bg-navy/90 disabled:opacity-50 inline-flex items-center gap-2"
              >
                <span>📂</span> {parsingZip ? "Reading & Unpacking ZIP..." : "Choose ZIP File from PC"}
              </button>
            </div>

            {zipMsg && (
              <div className="bg-navy/5 border border-hairline p-3 rounded text-xs font-semibold text-teal flex items-center justify-between">
                <span>{zipMsg}</span>
                {batchUploading && (
                  <span className="font-mono text-[0.7rem] bg-teal text-[#05231f] px-2 py-0.5 rounded font-bold">
                    {batchProgress.current} / {batchProgress.total}
                  </span>
                )}
              </div>
            )}

            {/* Matched Images Table */}
            {zipMatches.length > 0 && (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-xs font-bold text-navy uppercase tracking-[0.1em]">
                    Matched Images Preview ({zipMatches.length})
                  </h3>
                  <button
                    type="button"
                    disabled={batchUploading}
                    onClick={handleExecuteBatchUpload}
                    className="rounded bg-teal px-5 py-2 text-xs font-bold uppercase tracking-[0.12em] text-[#05231f] hover:opacity-90 disabled:opacity-50 shadow"
                  >
                    {batchUploading ? "Uploading & Syncing DB..." : "🚀 Upload All & Replace DB Images"}
                  </button>
                </div>

                <div className="overflow-x-auto border border-hairline rounded bg-background max-h-[360px] overflow-y-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="border-b border-hairline bg-navy/5 font-semibold text-navy uppercase tracking-[0.1em] text-[0.65rem] sticky top-0 bg-background">
                      <tr>
                        <th className="p-3">Zip Image</th>
                        <th className="p-3">File Name</th>
                        <th className="p-3">Target DB Product</th>
                        <th className="p-3 text-center">AI Match Score</th>
                        <th className="p-3 text-center">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-hairline">
                      {zipMatches.map((m) => {
                        return (
                          <tr key={m.id} className="hover:bg-navy/5">
                            <td className="p-2">
                              <img
                                src={m.previewUrl}
                                alt={m.fileName}
                                className="h-12 w-12 object-cover rounded border border-hairline"
                              />
                            </td>
                            <td className="p-3 font-mono text-[0.72rem] font-medium text-navy max-w-[160px] truncate">
                              {m.fileName}
                            </td>
                            <td className="p-3">
                              <select
                                value={m.selectedSlug}
                                disabled={batchUploading}
                                onChange={(e) => {
                                  const slug = e.target.value;
                                  const prod = products.find((p) => p.slug === slug);
                                  setZipMatches((prev) =>
                                    prev.map((item) =>
                                      item.id === m.id
                                        ? {
                                            ...item,
                                            selectedSlug: slug,
                                            newName: prod ? prod.name : item.newName,
                                          }
                                        : item
                                    )
                                  );
                                }}
                                className="w-full border border-hairline bg-card px-2 py-1 text-xs outline-none focus:border-teal rounded font-medium"
                              >
                                {products.map((p) => (
                                  <option key={p.slug} value={p.slug}>
                                    [{p.category}] {p.name}
                                  </option>
                                ))}
                              </select>
                            </td>
                            <td className="p-3 text-center">
                              <span
                                className={`inline-block rounded-full px-2.5 py-0.5 text-[0.62rem] font-bold ${
                                  m.score >= 70
                                    ? "bg-teal/20 text-teal"
                                    : m.score >= 30
                                    ? "bg-amber-100 text-amber-800"
                                    : "bg-gray-100 text-gray-600"
                                }`}
                              >
                                {m.score}% Match
                              </span>
                            </td>
                            <td className="p-3 text-center">
                              {m.status === "uploading" && (
                                <span className="font-semibold text-amber-600 animate-pulse text-[0.68rem]">
                                  Uploading...
                                </span>
                              )}
                              {m.status === "done" && (
                                <span className="font-semibold text-teal text-[0.68rem]">✓ Synced</span>
                              )}
                              {m.status === "error" && (
                                <span className="font-semibold text-red-600 text-[0.68rem]">✕ Error</span>
                              )}
                              {m.status === "idle" && (
                                <span className="text-muted-foreground text-[0.68rem]">Ready</span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
