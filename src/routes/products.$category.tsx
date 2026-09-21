import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { useState, useEffect } from "react";
import { PageHero, Section, Reveal, TealButton } from "@/components/site/primitives";
import { CTABand } from "@/components/site/CTABand";
import { useI18n } from "@/lib/i18n";
import { ALL_PRODUCTS, CATEGORY_META, ProductDetailItem } from "@/data/allProductsData";
import { supabase } from "@/integrations/supabase/client";
import exosomeImg from "@/assets/exosome.jpg";
import vialsImg from "@/assets/vials.jpg";
import molecularImg from "@/assets/molecular.jpg";
import cleanroomImg from "@/assets/cleanroom.jpg";
import qcLabImg from "@/assets/qc-lab.jpg";

export type DbProductItem = ProductDetailItem & {
  image_url?: string;
};

export interface SubGroup {
  name: string;
  items: DbProductItem[];
  nestedGroups?: { name: string; items: DbProductItem[] }[];
}

export interface StructuredCategoryData {
  partA: {
    title: string;
    description: string;
    subgroups: SubGroup[];
    totalCount: number;
  };
  partB: {
    title: string;
    description: string;
    subgroups: SubGroup[];
    totalCount: number;
  };
}

// ─── Image mapping per category ───────────────────────────────────────────────

const CATEGORY_IMAGES: Record<string, { img: string; imageAlt: string }> = {
  exosome: {
    img: exosomeImg,
    imageAlt: "Lyophilized exosome vials in a cleanroom environment",
  },
  "dermal-fillers": {
    img: vialsImg,
    imageAlt: "Dermal filler syringes and vials",
  },
  "peptide-bio-remodeling": {
    img: molecularImg,
    imageAlt: "Peptide molecular structure and laboratory vials",
  },
  "botulinum-toxin": {
    img: cleanroomImg,
    imageAlt: "Aseptic cleanroom filling line for injectable products",
  },
  "pdrn-pn": {
    img: qcLabImg,
    imageAlt: "Quality control laboratory testing PDRN and PN solutions",
  },
};

const ALL_CATEGORY_KEYS = Object.keys(CATEGORY_META);

export const Route = createFileRoute("/products/$category")({
  loader: ({ params }) => {
    const baseCategory = params.category.replace(/-part-[ab]$/, "");
    if (!ALL_CATEGORY_KEYS.includes(baseCategory)) throw notFound();
    return { category: params.category };
  },
  validateSearch: (search: Record<string, unknown>): { part?: "a" | "b" | undefined } => {
    const val = search["part"];
    return {
      part: val === "a" || val === "b" ? val : undefined,
    };
  },
  head: ({ params }) => {
    const baseCategory = params.category.replace(/-part-[ab]$/, "");
    const meta = CATEGORY_META[baseCategory];
    const title = meta
      ? `${meta.title} — Vesco Science Products`
      : "Products — Vesco Science";
    return {
      meta: [
        { title },
        {
          name: "description",
          content: meta?.description ?? "B2B product catalogue — Vesco Science.",
        },
        { property: "og:title", content: title },
        { property: "og:type", content: "website" },
      ],
    };
  },
  component: CategoryPage,
});

// ─── Helper logic to classify items into Part A & Part B hierarchy ──────────

function isPartBItem(category: string, item: DbProductItem): boolean {
  const text = `${item.slug} ${item.group || ""} ${item.name} ${item.label || ""}`.toLowerCase();
  if (category === "exosome") {
    return text.includes("exogenesis") || text.includes("exolyra") || text.includes("derived");
  }
  if (category === "dermal-fillers") {
    return text.includes("hyalique") || text.includes("luminelle");
  }
  if (category === "peptide-bio-remodeling") {
    return text.includes("bluevive") || text.includes("cuvera");
  }
  if (category === "botulinum-toxin") {
    return text.includes("botivex") || text.includes("toxexa");
  }
  if (category === "pdrn-pn") {
    return text.includes("nucelvia") || text.includes("polynexa") || text.includes("dnavia");
  }
  return false;
}

function organizeCategoryProducts(category: string, products: DbProductItem[]): StructuredCategoryData {
  const partAItems = products.filter((p) => !isPartBItem(category, p));
  const partBItems = products.filter((p) => isPartBItem(category, p));

  const buildSubgroups = (items: DbProductItem[], isPartB: boolean): SubGroup[] => {
    const map = new Map<string, DbProductItem[]>();

    items.forEach((item) => {
      const text = `${item.slug} ${item.group || ""} ${item.name} ${item.label || ""}`.toLowerCase();
      let groupName = item.group || "Core Formats";

      if (category === "exosome") {
        if (!isPartB) {
          if (text.includes("lyophilized") || text.includes("huc-msc")) groupName = "Lyophilized hUC-MSC Exosomes";
          else if (text.includes("scalp")) groupName = "Scalp Exosome Diluent";
          else if (text.includes("vital")) groupName = "Vital Exosome Diluent";
        } else {
          if (text.includes("exogenesis")) groupName = "ExoGenesis™";
          else if (text.includes("exolyra")) groupName = "Exolyra™";
          else if (text.includes("derived")) groupName = "Derived";
        }
      } else if (category === "dermal-fillers") {
        if (!isPartB) {
          if (text.includes("24-mg") || text.includes("24 mg") || text.includes("26-mg") || text.includes("26 mg") || text.includes("large")) {
            groupName = "Large-Molecular Hyaluronic Acid";
          } else {
            groupName = "Small-Molecular Hyaluronic Acid";
          }
        } else {
          if (text.includes("hyalique")) groupName = "Hyalique-X";
          else if (text.includes("luminelle")) groupName = "Luminelle™";
        }
      } else if (category === "peptide-bio-remodeling") {
        if (!isPartB) {
          if (text.includes("copper") || text.includes("pepetide")) groupName = "Blue Copper Pepetide";
          else if (text.includes("ha-diluent") || text.includes("ha diluent")) groupName = "HA Diluent";
        } else {
          if (text.includes("bluevive")) groupName = "BlueVive Booster";
          else if (text.includes("cuvera")) groupName = "Cuvera-X™";
        }
      } else if (category === "botulinum-toxin") {
        if (!isPartB) {
          groupName = "Vesco Science Standard Formats";
        } else {
          if (text.includes("botivex")) groupName = "Botivex";
          else if (text.includes("toxexa")) groupName = "Toxexa";
        }
      } else if (category === "pdrn-pn") {
        if (!isPartB) {
          if (text.includes("pdrn-ha") || text.includes("pdrn + ha")) groupName = "PDRN + HA Solutions";
          else if (text.includes("pdrn")) groupName = "PDRN Solutions";
          else if (text.includes("pn")) groupName = "PN Solutions";
        } else {
          if (text.includes("nucelvia")) groupName = "Nucelvia";
          else if (text.includes("polynexa")) groupName = "Polynexa";
          else if (text.includes("dnavia")) groupName = "DNAVIA";
        }
      }

      const list = map.get(groupName) || [];
      list.push(item);
      map.set(groupName, list);
    });

    const result: SubGroup[] = [];

    map.forEach((subItems, subName) => {
      // Check for nested sub-groups (e.g. for Dermal Fillers or Hyalique-X)
      if (category === "dermal-fillers") {
        const nestedMap = new Map<string, DbProductItem[]>();
        subItems.forEach((subItem) => {
          let nestedKey = subItem.group || subItem.label || "Variants";
          if (subName === "Small-Molecular Hyaluronic Acid") {
            if (subItem.slug.includes("15-mg")) nestedKey = "15 mg";
            else if (subItem.slug.includes("18-mg")) nestedKey = "18 mg";
            else if (subItem.slug.includes("20-mg")) nestedKey = "20 mg";
          } else if (subName === "Large-Molecular Hyaluronic Acid") {
            if (subItem.slug.includes("24-mg")) nestedKey = "24 mg";
            else if (subItem.slug.includes("26-mg")) nestedKey = "26 mg";
          } else if (subName === "Hyalique-X") {
            if (subItem.slug.includes("soft")) nestedKey = "HYALIQUE-X (Soft Filler)";
            else if (subItem.slug.includes("hard")) nestedKey = "HYALIQUE-X (Hard Filler)";
          }
          const nList = nestedMap.get(nestedKey) || [];
          nList.push(subItem);
          nestedMap.set(nestedKey, nList);
        });

        if (nestedMap.size > 1 || subName === "Small-Molecular Hyaluronic Acid" || subName === "Large-Molecular Hyaluronic Acid" || subName === "Hyalique-X") {
          const nestedGroups: { name: string; items: DbProductItem[] }[] = [];
          nestedMap.forEach((nItems, nName) => {
            nestedGroups.push({ name: nName, items: nItems });
          });
          result.push({ name: subName, items: subItems, nestedGroups });
          return;
        }
      }

      result.push({ name: subName, items: subItems });
    });

    return result;
  };

  return {
    partA: {
      title: "Part A. VESCO SCIENCE PLATFORMS",
      description: "Proprietary core formulations, lyophilized platforms, and standardized active diluent solutions developed under Vesco Science quality standards.",
      subgroups: buildSubgroups(partAItems, false),
      totalCount: partAItems.length,
    },
    partB: {
      title: "Part B. OFFICIAL COLLABORATIONS",
      description: "Co-developed brand series and official global partner formulations engineered for targeted clinical and aesthetic applications.",
      subgroups: buildSubgroups(partBItems, true),
      totalCount: partBItems.length,
    },
  };
}

function CategoryPage() {
  const { category } = Route.useParams();
  const search = Route.useSearch();
  const { t } = useI18n();

  let baseCategory = category;
  let activePart: "a" | "b" | undefined = search.part;

  if (category.endsWith("-part-a")) {
    baseCategory = category.replace("-part-a", "");
    activePart = "a";
  } else if (category.endsWith("-part-b")) {
    baseCategory = category.replace("-part-b", "");
    activePart = "b";
  }

  const meta = CATEGORY_META[baseCategory];
  const imgMeta = CATEGORY_IMAGES[baseCategory];

  const [products, setProducts] = useState<DbProductItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadDbProducts() {
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from("products")
          .select("*")
          .eq("category", baseCategory)
          .eq("published", true)
          .order("sort_order", { ascending: true });

        if (!error && data && data.length > 0) {
          setProducts(
            data.map((d: any) => ({
              slug: d.slug,
              name: d.name,
              detail: d.detail,
              group: d.group_name || undefined,
              label: d.label || undefined,
              specs: Array.isArray(d.specs) ? d.specs : [],
              image_url: d.image_url || "",
            }))
          );
        } else {
          setProducts(ALL_PRODUCTS[baseCategory] ?? []);
        }
      } catch (err) {
        console.error("Supabase product load error, using static fallback:", err);
        setProducts(ALL_PRODUCTS[baseCategory] ?? []);
      } finally {
        setLoading(false);
      }
    }
    loadDbProducts();
  }, [baseCategory]);

  if (!meta || !imgMeta) return null;

  const structuredData = organizeCategoryProducts(baseCategory, products);

  // Dynamic Page Title & Breadcrumb Label
  const pageTitle =
    activePart === "a"
      ? `${meta.title} — Part A: Vesco Science Platforms`
      : activePart === "b"
      ? `${meta.title} — Part B: Official Collaborations`
      : meta.title;

  const crumbLabel =
    activePart === "a"
      ? `${meta.title} (Part A)`
      : activePart === "b"
      ? `${meta.title} (Part B)`
      : meta.title;

  return (
    <>
      <PageHero
        eyebrow={
          activePart === "a"
            ? "PART A • VESCO SCIENCE PLATFORMS"
            : activePart === "b"
            ? "PART B • OFFICIAL COLLABORATIONS"
            : t("products.eyebrow")
        }
        title={pageTitle}
        lead={meta.description}
        crumb={{ label: crumbLabel, homeLabel: t("common.breadcrumbHome") }}
      />

      <Section>
        {/* Navigation Back Link */}
        <Reveal>
          {activePart ? (
            <Link
              to="/products/$category"
              params={{ category: baseCategory }}
              className="mb-8 inline-flex items-center gap-2 text-[0.85rem] font-semibold text-teal transition-colors hover:text-navy"
            >
              <span>←</span> Back to {meta.title} Platform Selection
            </Link>
          ) : (
            <Link
              to="/products"
              className="mb-8 inline-flex items-center gap-2 text-[0.85rem] font-semibold text-science transition-colors hover:text-navy"
            >
              <span>←</span> Back to All Product Categories
            </Link>
          )}
        </Reveal>

        {/* ─── STATE 1: INITIAL CATEGORY VIEW (ONLY 2 SELECTION CARDS SHOW) ─── */}
        {!activePart && (
          <div className="space-y-12">
            {/* Category Banner */}
            <Reveal>
              <div className="grid gap-0 overflow-hidden border border-hairline lg:grid-cols-[1.1fr_1fr] bg-card shadow-sm">
                <img
                  src={imgMeta.img}
                  alt={imgMeta.imageAlt}
                  className="aspect-[16/9] w-full object-cover lg:aspect-auto lg:h-full"
                  loading="eager"
                />
                <div className="flex flex-col justify-center bg-card p-8 md:p-10">
                  <span className="font-display text-[0.72rem] font-bold tracking-[0.18em] text-teal">
                    CATEGORY {meta.num}
                  </span>
                  <h2 className="mt-3 text-[1.85rem] font-semibold leading-tight text-navy">
                    {meta.title}
                  </h2>
                  <p className="mt-4 text-[0.95rem] leading-relaxed text-muted-foreground">
                    {meta.description}
                  </p>
                  <div className="mt-6">
                    <span className="inline-block rounded bg-teal/10 px-3 py-1.5 text-[0.75rem] font-bold text-teal tracking-wider uppercase">
                      Select a Series Platform Below ({products.length} Total Products)
                    </span>
                  </div>
                </div>
              </div>
            </Reveal>

            {/* ONLY 2 CARDS ARE RENDERED ON THIS INITIAL PAGE */}
            <Reveal delay={100}>
              <div className="space-y-4">
                <h3 className="text-[0.8rem] font-bold uppercase tracking-[0.2em] text-science border-b border-hairline pb-3">
                  Choose Platform Section:
                </h3>

                <div className="grid gap-8 md:grid-cols-2">
                  {/* CARD A: VESCO SCIENCE PLATFORMS */}
                  <Link
                    to="/products/$category"
                    params={{ category: baseCategory }}
                    search={{ part: "a" }}
                    className="group flex flex-col justify-between border-2 border-teal/40 bg-card p-8 transition-all hover:border-teal hover:shadow-xl hover:-translate-y-0.5 rounded-sm"
                  >
                    <div>
                      <div className="flex items-center justify-between">
                        <span className="rounded-full bg-teal text-[#05231f] px-3.5 py-1 text-[0.7rem] font-bold uppercase tracking-[0.16em]">
                          Part A
                        </span>
                        <span className="text-[0.78rem] font-semibold text-teal font-mono">
                          {structuredData.partA.totalCount} Products
                        </span>
                      </div>
                      <h4 className="mt-5 text-[1.35rem] font-bold text-navy transition-colors group-hover:text-teal">
                        VESCO SCIENCE PLATFORMS
                      </h4>
                      <p className="mt-3 text-[0.88rem] leading-relaxed text-muted-foreground">
                        {structuredData.partA.description}
                      </p>
                    </div>

                    <div className="mt-8 flex items-center justify-between border-t border-hairline/80 pt-4 text-[0.78rem] font-bold tracking-[0.12em] uppercase text-teal">
                      <span>Open Part A Catalogue ({structuredData.partA.totalCount})</span>
                      <span className="text-teal transition-transform duration-300 group-hover:translate-x-1.5">→</span>
                    </div>
                  </Link>

                  {/* CARD B: OFFICIAL COLLABORATIONS */}
                  <Link
                    to="/products/$category"
                    params={{ category: baseCategory }}
                    search={{ part: "b" }}
                    className="group flex flex-col justify-between border-2 border-science/40 bg-card p-8 transition-all hover:border-science hover:shadow-xl hover:-translate-y-0.5 rounded-sm"
                  >
                    <div>
                      <div className="flex items-center justify-between">
                        <span className="rounded-full bg-science text-white px-3.5 py-1 text-[0.7rem] font-bold uppercase tracking-[0.16em]">
                          Part B
                        </span>
                        <span className="text-[0.78rem] font-semibold text-science font-mono">
                          {structuredData.partB.totalCount} Products
                        </span>
                      </div>
                      <h4 className="mt-5 text-[1.35rem] font-bold text-navy transition-colors group-hover:text-science">
                        OFFICIAL COLLABORATIONS
                      </h4>
                      <p className="mt-3 text-[0.88rem] leading-relaxed text-muted-foreground">
                        {structuredData.partB.description}
                      </p>
                    </div>

                    <div className="mt-8 flex items-center justify-between border-t border-hairline/80 pt-4 text-[0.78rem] font-bold tracking-[0.12em] uppercase text-science">
                      <span>Open Part B Catalogue ({structuredData.partB.totalCount})</span>
                      <span className="text-science transition-transform duration-300 group-hover:translate-x-1.5">→</span>
                    </div>
                  </Link>
                </div>
              </div>
            </Reveal>
          </div>
        )}

        {/* ─── STATE 2: DEDICATED PART A SLUG PAGE (ONLY PART A PRODUCTS SHOW) ─ */}
        {activePart === "a" && (
          <div className="space-y-10">
            {/* Dedicated Part A Header */}
            <Reveal>
              <div className="flex flex-wrap items-center justify-between border-b-2 border-teal pb-4">
                <div className="flex items-center gap-3">
                  <span className="flex h-8 w-8 items-center justify-center rounded-full bg-teal text-sm font-bold text-[#05231f]">
                    A
                  </span>
                  <div>
                    <h3 className="text-xl font-bold text-navy">
                      VESCO SCIENCE PLATFORMS — {meta.title}
                    </h3>
                    <p className="text-[0.82rem] text-muted-foreground mt-0.5">
                      {structuredData.partA.description}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3 mt-2 sm:mt-0">
                  <span className="text-[0.75rem] font-semibold text-teal bg-teal/10 px-3 py-1 rounded-full uppercase tracking-wider">
                    {structuredData.partA.totalCount} Dedicated Formats
                  </span>
                </div>
              </div>
            </Reveal>

            {/* Part A Subgroups & Products Grid */}
            {loading ? (
              <div className="py-20 text-center text-xs text-muted-foreground">Loading Part A products database...</div>
            ) : structuredData.partA.subgroups.length === 0 ? (
              <div className="py-20 text-center text-xs text-muted-foreground">No Part A products available in this category.</div>
            ) : (
              <div className="space-y-12">
                {structuredData.partA.subgroups.map((subgroup, sgIdx) => (
                  <Reveal key={subgroup.name} delay={sgIdx * 40}>
                    <div className="space-y-6">
                      <div className="flex items-center gap-3 border-l-4 border-teal bg-card p-4 border-r border-t border-b border-hairline">
                        <h4 className="text-[1.1rem] font-bold text-navy">
                          {subgroup.name}
                        </h4>
                        <span className="rounded-full bg-science/10 px-2.5 py-0.5 text-[0.68rem] font-semibold text-science">
                          {subgroup.items.length} Formats
                        </span>
                      </div>

                      {subgroup.nestedGroups ? (
                        <div className="space-y-8 pl-2 md:pl-4">
                          {subgroup.nestedGroups.map((nested) => (
                            <div key={nested.name} className="space-y-4">
                              <div className="flex items-center gap-2">
                                <span className="h-2 w-2 rounded-full bg-teal"></span>
                                <h5 className="text-[0.9rem] font-bold uppercase tracking-[0.1em] text-science">
                                  {nested.name}
                                </h5>
                                <span className="text-[0.72rem] text-muted-foreground font-mono">
                                  ({nested.items.length} variants)
                                </span>
                              </div>

                              <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                                {nested.items.map((item, itemIdx) => (
                                  <ProductCard key={item.slug} item={item} imgMeta={imgMeta} index={itemIdx} />
                                ))}
                              </div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                          {subgroup.items.map((item, itemIdx) => (
                            <ProductCard key={item.slug} item={item} imgMeta={imgMeta} index={itemIdx} />
                          ))}
                        </div>
                      )}
                    </div>
                  </Reveal>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ─── STATE 3: DEDICATED PART B SLUG PAGE (ONLY PART B PRODUCTS SHOW) ─ */}
        {activePart === "b" && (
          <div className="space-y-10">
            {/* Dedicated Part B Header */}
            <Reveal>
              <div className="flex flex-wrap items-center justify-between border-b-2 border-science pb-4">
                <div className="flex items-center gap-3">
                  <span className="flex h-8 w-8 items-center justify-center rounded-full bg-science text-sm font-bold text-white">
                    B
                  </span>
                  <div>
                    <h3 className="text-xl font-bold text-navy">
                      OFFICIAL COLLABORATIONS — {meta.title}
                    </h3>
                    <p className="text-[0.82rem] text-muted-foreground mt-0.5">
                      {structuredData.partB.description}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3 mt-2 sm:mt-0">
                  <span className="text-[0.75rem] font-semibold text-science bg-science/10 px-3 py-1 rounded-full uppercase tracking-wider">
                    {structuredData.partB.totalCount} Dedicated Formats
                  </span>
                </div>
              </div>
            </Reveal>

            {/* Part B Subgroups & Products Grid */}
            {loading ? (
              <div className="py-20 text-center text-xs text-muted-foreground">Loading Part B products database...</div>
            ) : structuredData.partB.subgroups.length === 0 ? (
              <div className="py-20 text-center text-xs text-muted-foreground">No Part B products available in this category.</div>
            ) : (
              <div className="space-y-12">
                {structuredData.partB.subgroups.map((subgroup, sgIdx) => (
                  <Reveal key={subgroup.name} delay={sgIdx * 40}>
                    <div className="space-y-6">
                      <div className="flex items-center gap-3 border-l-4 border-science bg-card p-4 border-r border-t border-b border-hairline">
                        <h4 className="text-[1.1rem] font-bold text-navy">
                          {subgroup.name}
                        </h4>
                        <span className="rounded-full bg-teal/15 px-2.5 py-0.5 text-[0.68rem] font-semibold text-teal">
                          Official Partner Line
                        </span>
                        <span className="text-[0.72rem] text-muted-foreground font-mono">
                          ({subgroup.items.length} Products)
                        </span>
                      </div>

                      {subgroup.nestedGroups ? (
                        <div className="space-y-8 pl-2 md:pl-4">
                          {subgroup.nestedGroups.map((nested) => (
                            <div key={nested.name} className="space-y-4">
                              <div className="flex items-center gap-2">
                                <span className="h-2 w-2 rounded-full bg-science"></span>
                                <h5 className="text-[0.9rem] font-bold uppercase tracking-[0.1em] text-navy">
                                  {nested.name}
                                </h5>
                                <span className="text-[0.72rem] text-muted-foreground font-mono">
                                  ({nested.items.length} variants)
                                </span>
                              </div>

                              <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                                {nested.items.map((item, itemIdx) => (
                                  <ProductCard key={item.slug} item={item} imgMeta={imgMeta} index={itemIdx} />
                                ))}
                              </div>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                          {subgroup.items.map((item, itemIdx) => (
                            <ProductCard key={item.slug} item={item} imgMeta={imgMeta} index={itemIdx} />
                          ))}
                        </div>
                      )}
                    </div>
                  </Reveal>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Footer CTAs */}
        <Reveal>
          <div className="mt-16 border-t border-hairline pt-8">
            <p className="text-[0.85rem] text-muted-foreground">
              {t("products.detail.demoNote")}
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <TealButton to="/contact" variant="outline">
                Request Product Catalogue
              </TealButton>
              <TealButton to="/oem" variant="outline">
                OEM / ODM Inquiry
              </TealButton>
            </div>
          </div>
        </Reveal>
      </Section>

      <CTABand />
    </>
  );
}

// ─── Single Product Card Component ────────────────────────────────────────────

function ProductCard({
  item,
  imgMeta,
  index,
}: {
  item: DbProductItem;
  imgMeta: { img: string; imageAlt: string };
  index: number;
}) {
  return (
    <Reveal delay={(index % 6) * 30}>
      <div className="group flex h-full flex-col overflow-hidden border border-hairline bg-card p-6 shadow-sm transition-all hover:border-teal/40 hover:shadow-md">
        {/* Product Image */}
        <div className="mb-4 aspect-[16/10] w-full overflow-hidden bg-navy/5 rounded-sm">
          <img
            src={item.image_url ? item.image_url : imgMeta.img}
            alt={item.name}
            loading="lazy"
            className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
            onError={(e) => {
              (e.target as HTMLImageElement).src = imgMeta.img;
            }}
          />
        </div>

        {/* Labels & Badges */}
        <div className="flex flex-wrap items-center gap-2 mb-2">
          {item.label && (
            <span className="rounded bg-teal/15 px-2 py-0.5 text-[0.64rem] font-bold text-teal font-mono">
              {item.label}
            </span>
          )}
          {item.group && (
            <span className="rounded bg-science/10 px-2 py-0.5 text-[0.64rem] font-semibold text-science truncate max-w-[200px]">
              {item.group}
            </span>
          )}
        </div>

        {/* Product Title */}
        <h4 className="text-[1.02rem] font-semibold leading-snug text-navy">
          {item.name}
        </h4>

        {/* Overview */}
        <p className="mt-3 flex-1 text-[0.83rem] leading-relaxed text-muted-foreground line-clamp-4">
          {item.detail}
        </p>

        {/* Specs */}
        {item.specs && item.specs.length > 0 && (
          <div className="mt-4 border-t border-hairline pt-3">
            <p className="text-[0.66rem] font-bold uppercase tracking-[0.12em] text-science mb-1.5">
              Key Specifications:
            </p>
            <ul className="space-y-1">
              {item.specs.slice(0, 3).map((spec, idx) => (
                <li key={idx} className="flex items-start text-[0.74rem] text-muted-foreground">
                  <span className="mr-1.5 text-teal">•</span>
                  <span className="line-clamp-1">{spec}</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Footer status */}
        <div className="mt-5 flex items-center justify-between border-t border-hairline/60 pt-3 text-[0.72rem] text-muted-foreground">
          <span className="inline-flex items-center gap-1.5 text-teal font-medium">
            <span className="h-1.5 w-1.5 rounded-full bg-teal"></span>
            COA / TDS Ready
          </span>
          <Link to="/contact" className="font-semibold text-science hover:underline">
            Inquire B2B →
          </Link>
        </div>
      </div>
    </Reveal>
  );
}


