import { createFileRoute } from "@tanstack/react-router";
import { useState, useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import { ARTICLES, Article, ArticleSection, Reference } from "@/data/articles";
import { uploadAdminImage } from "@/lib/admin";

export const Route = createFileRoute("/admin/articles")({
  component: AdminArticlesPage,
});

export type DbArticle = {
  id?: string;
  slug: string;
  category: string;
  title: string;
  excerpt: string;
  hero_image: string;
  sections: (ArticleSection & { image?: string })[];
  references_list: Reference[];
  published: boolean;
};

const ARTICLE_CATEGORIES = [
  "All Categories",
  "Exosome Science",
  "PDRN / PN",
  "Manufacturing",
  "Hyaluronic Acid",
  "Industry Insights",
];

function AdminArticlesPage() {
  const [articles, setArticles] = useState<DbArticle[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState("All Categories");
  const [searchQuery, setSearchQuery] = useState("");

  // Modal State
  const [editingItem, setEditingItem] = useState<DbArticle | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploadingHero, setUploadingHero] = useState(false);
  const [uploadingSectionIdx, setUploadingSectionIdx] = useState<number | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  const heroInputRef = useRef<HTMLInputElement>(null);

  // Form State
  const [formData, setFormData] = useState<DbArticle>({
    slug: "",
    category: "Exosome Science",
    title: "",
    excerpt: "",
    hero_image: "",
    sections: [{ heading: "Introduction", body: "", image: "" }],
    references_list: [],
    published: true,
  });

  const handleHeroUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploadingHero(true);
    setMsg("Uploading hero image from PC...");
    try {
      const url = await uploadAdminImage(file, "articles");
      setFormData((prev) => ({ ...prev, hero_image: url }));
      setMsg("Hero image uploaded successfully!");
    } catch (err: any) {
      setMsg("Hero Upload Error: " + err.message);
    } finally {
      setUploadingHero(false);
      e.target.value = "";
    }
  };

  const handleSectionImageUpload = async (index: number, file: File) => {
    setUploadingSectionIdx(index);
    setMsg(`Uploading section #${index + 1} image from PC...`);
    try {
      const url = await uploadAdminImage(file, "articles");
      updateSection(index, "image", url);
      setMsg(`Section #${index + 1} image uploaded!`);
    } catch (err: any) {
      setMsg("Section Upload Error: " + err.message);
    } finally {
      setUploadingSectionIdx(null);
    }
  };

  const loadArticles = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("articles")
        .select("*")
        .order("created_at", { ascending: false });

      if (error || !data || data.length === 0) {
        // Fallback to ARTICLES static data
        setArticles(
          ARTICLES.map((a: Article) => ({
            slug: a.slug,
            category: a.category,
            title: a.title,
            excerpt: a.excerpt,
            hero_image: "",
            sections: a.sections || [],
            references_list: a.references || [],
            published: true,
          }))
        );
      } else {
        setArticles(
          data.map((d: any) => ({
            id: d.id,
            slug: d.slug,
            category: d.category,
            title: d.title,
            excerpt: d.excerpt || "",
            hero_image: d.hero_image || "",
            sections: Array.isArray(d.sections) ? d.sections : [],
            references_list: Array.isArray(d.references_list) ? d.references_list : [],
            published: d.published ?? true,
          }))
        );
      }
    } catch (err) {
      console.error("Failed to load articles", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadArticles();
  }, []);

  const handleOpenAddModal = () => {
    setEditingItem(null);
    setFormData({
      slug: "",
      category: selectedCategory !== "All Categories" ? selectedCategory : "Exosome Science",
      title: "",
      excerpt: "",
      hero_image: "",
      sections: [{ heading: "Introduction", body: "", image: "" }],
      references_list: [],
      published: true,
    });
    setMsg(null);
    setIsModalOpen(true);
  };

  const handleOpenEditModal = (item: DbArticle) => {
    setEditingItem(item);
    setFormData({
      ...item,
      sections: item.sections && item.sections.length > 0 ? item.sections : [{ heading: "", body: "", image: "" }],
      references_list: item.references_list || [],
    });
    setMsg(null);
    setIsModalOpen(true);
  };

  const handleDelete = async (slug: string) => {
    if (!confirm(`Are you sure you want to delete article "${slug}"?`)) return;
    try {
      const { error } = await supabase.from("articles").delete().eq("slug", slug);
      if (error) {
        alert("Failed to delete from DB: " + error.message);
      }
      setArticles((prev) => prev.filter((a) => a.slug !== slug));
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
      formData.title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "");

    const payload = {
      slug: slugToSave,
      category: formData.category,
      title: formData.title,
      excerpt: formData.excerpt,
      hero_image: formData.hero_image,
      sections: formData.sections,
      references_list: formData.references_list,
      published: formData.published,
      updated_at: new Date().toISOString(),
    };

    try {
      const { error } = await supabase.from("articles").upsert(payload, { onConflict: "slug" });

      if (error) {
        setMsg("Save Notice: " + error.message + " (Saved locally)");
      } else {
        setMsg("Article saved successfully!");
      }

      setArticles((prev) => {
        const exists = prev.some((a) => a.slug === slugToSave);
        if (exists) {
          return prev.map((a) => (a.slug === slugToSave ? { ...formData, slug: slugToSave } : a));
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

  // Section Helpers
  const addSection = () => {
    setFormData((prev) => ({
      ...prev,
      sections: [...prev.sections, { heading: "", body: "", image: "" }],
    }));
  };

  const removeSection = (index: number) => {
    setFormData((prev) => ({
      ...prev,
      sections: prev.sections.filter((_, i) => i !== index),
    }));
  };

  const updateSection = (index: number, key: string, val: string) => {
    setFormData((prev) => {
      const updated = [...prev.sections];
      updated[index] = { ...updated[index], [key]: val };
      return { ...prev, sections: updated };
    });
  };

  const filteredArticles = articles.filter((a) => {
    const matchesCat = selectedCategory === "All Categories" || a.category === selectedCategory;
    const matchesQuery =
      searchQuery.trim() === "" ||
      a.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.slug.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.excerpt.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesQuery;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-hairline pb-4">
        <div>
          <h1 className="text-xl font-bold text-navy">Science Insights & Blogs Manager</h1>
          <p className="text-xs text-muted-foreground">
            Manage research articles, blog posts, hero images & embedded section images with full CRUD.
          </p>
        </div>

        <button
          onClick={handleOpenAddModal}
          className="rounded-sm bg-teal px-4 py-2 text-xs font-semibold uppercase tracking-[0.12em] text-[#05231f] transition-opacity hover:opacity-90"
        >
          + Add New Article
        </button>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center gap-4 bg-card p-4 border border-hairline">
        <div className="flex-1 min-w-[240px]">
          <input
            type="text"
            placeholder="Search article by title, excerpt or slug..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full border border-hairline bg-background px-3 py-2 text-xs outline-none focus:border-teal"
          />
        </div>

        <div className="flex flex-wrap gap-2">
          {ARTICLE_CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`rounded-sm px-3 py-1.5 text-xs font-medium transition-colors ${
                selectedCategory === cat
                  ? "bg-navy text-white"
                  : "bg-background text-navy hover:bg-navy/5 border border-hairline"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* Articles Table */}
      {loading ? (
        <div className="p-12 text-center text-xs text-muted-foreground">Loading articles database...</div>
      ) : (
        <div className="overflow-x-auto border border-hairline bg-card shadow-sm">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-hairline bg-navy/5 font-semibold text-navy uppercase tracking-[0.1em] text-[0.68rem]">
              <tr>
                <th className="p-3">Category</th>
                <th className="p-3">Article Title & Excerpt</th>
                <th className="p-3">Sections</th>
                <th className="p-3 text-center font-semibold">Hero / Sub-Images</th>
                <th className="p-3 text-center">Status</th>
                <th className="p-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline">
              {filteredArticles.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-muted-foreground">
                    No articles found matching your criteria.
                  </td>
                </tr>
              ) : (
                filteredArticles.map((a) => (
                  <tr key={a.slug} className="hover:bg-navy/5 transition-colors">
                    <td className="p-3 font-medium text-teal">{a.category}</td>
                    <td className="p-3 max-w-md">
                      <p className="font-semibold text-navy line-clamp-1">{a.title}</p>
                      <p className="mt-0.5 text-[0.72rem] text-muted-foreground line-clamp-2">
                        {a.excerpt}
                      </p>
                    </td>
                    <td className="p-3 text-muted-foreground font-mono text-[0.72rem]">
                      {a.sections ? `${a.sections.length} sections` : "0"}
                    </td>
                    <td className="p-3 text-center">
                      {a.hero_image ? (
                        <span className="rounded bg-teal/20 px-2 py-0.5 text-[0.62rem] font-medium text-teal">
                          Hero Custom
                        </span>
                      ) : (
                        <span className="text-muted-foreground text-[0.68rem]">Default Image</span>
                      )}
                    </td>
                    <td className="p-3 text-center">
                      <span
                        className={`inline-block rounded-full px-2 py-0.5 text-[0.62rem] font-semibold ${
                          a.published ? "bg-teal/20 text-teal" : "bg-muted text-muted-foreground"
                        }`}
                      >
                        {a.published ? "Published" : "Draft"}
                      </span>
                    </td>
                    <td className="p-3 text-right space-x-2">
                      <button
                        onClick={() => handleOpenEditModal(a)}
                        className="rounded border border-navy/20 px-2.5 py-1 text-[0.68rem] font-semibold text-navy hover:bg-navy/10"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(a.slug)}
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

      {/* Modal Dialog for Add / Edit Article */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-3xl max-h-[90vh] overflow-y-auto border border-hairline bg-card p-6 shadow-xl space-y-5">
            <div className="flex items-center justify-between border-b border-hairline pb-3">
              <h2 className="text-base font-bold text-navy">
                {editingItem ? `Edit Article: ${editingItem.title}` : "Add New Science Article"}
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
                  <label className="block font-semibold text-navy mb-1">Article Category *</label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal"
                  >
                    {ARTICLE_CATEGORIES.filter((c) => c !== "All Categories").map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block font-semibold text-navy mb-1">URL Slug</label>
                  <input
                    type="text"
                    value={formData.slug}
                    onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal font-mono text-[0.72rem]"
                    placeholder="auto-generated from title"
                  />
                </div>
              </div>

              <div>
                <label className="block font-semibold text-navy mb-1">Article Title *</label>
                <input
                  required
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal text-sm font-medium"
                  placeholder="e.g. Exosomes vs. Microvesicles: Key Biological Differences"
                />
              </div>

              <div>
                <label className="block font-semibold text-navy mb-1">Article Summary / Excerpt</label>
                <textarea
                  rows={2}
                  value={formData.excerpt}
                  onChange={(e) => setFormData({ ...formData, excerpt: e.target.value })}
                  className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal leading-relaxed"
                  placeholder="Short 2-line summary shown on blog grid cards..."
                />
              </div>

              {/* Hero Image Section */}
              <div>
                <label className="block font-semibold text-navy mb-1">Hero Image (Top Header)</label>
                <div className="space-y-2">
                  <div className="flex items-center gap-3">
                    <button
                      type="button"
                      disabled={uploadingHero}
                      onClick={() => heroInputRef.current?.click()}
                      className="rounded bg-navy px-4 py-2 text-xs font-semibold text-white hover:bg-navy/90 disabled:opacity-50 flex items-center gap-1.5"
                    >
                      <span>📁</span> {uploadingHero ? "Uploading Hero..." : "Upload Hero Image from PC"}
                    </button>

                    <input
                      ref={heroInputRef}
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={handleHeroUpload}
                    />

                    <span className="text-[0.68rem] text-muted-foreground">or paste URL below</span>
                  </div>

                  <input
                    type="text"
                    value={formData.hero_image}
                    onChange={(e) => setFormData({ ...formData, hero_image: e.target.value })}
                    className="w-full border border-hairline bg-background px-3 py-2 outline-none focus:border-teal font-mono text-[0.72rem]"
                    placeholder="https://... or upload from PC above"
                  />

                  {formData.hero_image && (
                    <div className="mt-2 flex items-center gap-3 border border-hairline bg-background p-2 rounded">
                      <img
                        src={formData.hero_image}
                        alt="Hero Preview"
                        className="h-16 w-28 object-cover rounded border border-hairline"
                        onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
                      />
                      <div>
                        <p className="text-[0.7rem] font-semibold text-navy">Hero Image Preview</p>
                        <p className="text-[0.62rem] text-muted-foreground truncate max-w-xs">{formData.hero_image}</p>
                        <button
                          type="button"
                          onClick={() => setFormData({ ...formData, hero_image: "" })}
                          className="text-[0.62rem] font-semibold text-red-600 hover:underline mt-0.5"
                        >
                          Remove Hero Image
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Dynamic Content Sections Editor */}
              <div className="border-t border-hairline pt-4 space-y-3">
                <div className="flex items-center justify-between">
                  <label className="block font-bold text-navy uppercase tracking-[0.1em] text-[0.7rem]">
                    Article Content Sections ({formData.sections.length})
                  </label>
                  <button
                    type="button"
                    onClick={addSection}
                    className="rounded bg-navy/10 px-3 py-1 font-semibold text-navy hover:bg-navy/20"
                  >
                    + Add Section
                  </button>
                </div>

                {formData.sections.map((sec, idx) => (
                  <div key={idx} className="border border-hairline bg-background p-4 rounded-sm space-y-2.5 relative">
                    <div className="flex items-center justify-between mb-1">
                      <span className="font-bold text-teal text-[0.72rem]">Section #{idx + 1}</span>
                      {formData.sections.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeSection(idx)}
                          className="text-red-500 hover:underline font-semibold text-[0.68rem]"
                        >
                          Remove
                        </button>
                      )}
                    </div>

                    <input
                      type="text"
                      placeholder="Section Heading (e.g. Understanding Extracellular Vesicles)"
                      value={sec.heading || ""}
                      onChange={(e) => updateSection(idx, "heading", e.target.value)}
                      className="w-full border border-hairline bg-card px-3 py-1.5 font-semibold text-navy outline-none focus:border-teal"
                    />

                    <textarea
                      rows={4}
                      placeholder="Section paragraph body content..."
                      value={sec.body || ""}
                      onChange={(e) => updateSection(idx, "body", e.target.value)}
                      className="w-full border border-hairline bg-card px-3 py-2 outline-none focus:border-teal leading-relaxed"
                    />

                    {/* Mid-Section Image Picker */}
                    <div className="space-y-1.5 pt-1">
                      <label className="block font-semibold text-navy text-[0.7rem]">Mid-Section Image (Optional)</label>
                      <div className="flex items-center gap-2">
                        <label className="cursor-pointer rounded bg-navy/10 px-3 py-1 text-[0.68rem] font-semibold text-navy hover:bg-navy/20">
                          {uploadingSectionIdx === idx ? "Uploading..." : "📁 Upload Image from PC"}
                          <input
                            type="file"
                            accept="image/*"
                            className="hidden"
                            onChange={(e) => {
                              const f = e.target.files?.[0];
                              if (f) void handleSectionImageUpload(idx, f);
                              e.target.value = "";
                            }}
                          />
                        </label>

                        <input
                          type="text"
                          placeholder="or paste section image URL..."
                          value={sec.image || ""}
                          onChange={(e) => updateSection(idx, "image", e.target.value)}
                          className="flex-1 border border-hairline bg-card px-3 py-1 font-mono text-[0.7rem] outline-none focus:border-teal"
                        />
                      </div>

                      {sec.image && (
                        <div className="flex items-center gap-3 border border-hairline bg-card p-2 rounded mt-1">
                          <img
                            src={sec.image}
                            alt={`Section ${idx + 1} Preview`}
                            className="h-12 w-20 object-cover rounded border border-hairline"
                            onError={(e) => { (e.target as HTMLImageElement).style.display = "none"; }}
                          />
                          <div>
                            <p className="text-[0.68rem] font-semibold text-navy">Section #{idx + 1} Image Preview</p>
                            <button
                              type="button"
                              onClick={() => updateSection(idx, "image", "")}
                              className="text-[0.62rem] font-semibold text-red-600 hover:underline"
                            >
                              Remove Image
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex items-center gap-2 pt-2">
                <input
                  type="checkbox"
                  id="pub-art"
                  checked={formData.published}
                  onChange={(e) => setFormData({ ...formData, published: e.target.checked })}
                  className="h-4 w-4 rounded border-hairline text-teal focus:ring-teal"
                />
                <label htmlFor="pub-art" className="font-semibold text-navy">
                  Published & Visible on Insights Page
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
                  {saving ? "Saving..." : "Save Article"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
