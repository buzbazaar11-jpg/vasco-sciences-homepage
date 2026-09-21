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
    if (!ALL_CATEGORY_KEYS.includes(params.category)) throw notFound();
    return { category: params.category };
  },
  head: ({ params }) => {
    const meta = CATEGORY_META[params.category];
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

function CategoryPage() {
  const { category } = Route.useParams();
  const { t } = useI18n();

  const meta = CATEGORY_META[category];
  const imgMeta = CATEGORY_IMAGES[category];

  const [products, setProducts] = useState<DbProductItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadDbProducts() {
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from("products")
          .select("*")
          .eq("category", category)
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
          setProducts(ALL_PRODUCTS[category] ?? []);
        }
      } catch (err) {
        console.error("Supabase product load error, using static fallback:", err);
        setProducts(ALL_PRODUCTS[category] ?? []);
      } finally {
        setLoading(false);
      }
    }
    loadDbProducts();
  }, [category]);

  if (!meta || !imgMeta) return null;

  return (
    <>
      <PageHero
        eyebrow={t("products.eyebrow")}
        title={meta.title}
        lead={meta.description}
        crumb={{ label: meta.title, homeLabel: t("common.breadcrumbHome") }}
      />

      <Section>
        {/* Back to all categories */}
        <Reveal>
          <Link
            to="/products"
            className="mb-10 inline-flex items-center gap-2 text-[0.82rem] font-medium text-science transition-colors hover:text-navy"
          >
            <span className="text-teal">←</span> All Categories
          </Link>
        </Reveal>

        {/* Category hero card */}
        <Reveal>
          <div className="mb-14 grid gap-0 overflow-hidden border border-hairline lg:grid-cols-[1.1fr_1fr]">
            <img
              src={imgMeta.img}
              alt={imgMeta.imageAlt}
              className="aspect-[16/9] w-full object-cover lg:aspect-auto lg:h-full"
              loading="eager"
            />
            <div className="flex flex-col justify-center bg-card p-8 md:p-10">
              <span className="font-display text-[0.72rem] font-bold tracking-[0.18em] text-teal">
                {meta.num}
              </span>
              <h2 className="mt-3 text-[1.85rem] font-semibold leading-tight text-navy">
                {meta.title}
              </h2>
              <p className="mt-4 text-[0.97rem] leading-relaxed text-muted-foreground">
                {meta.description}
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <TealButton to="/contact" variant="outline">
                  Request Product Information
                </TealButton>
              </div>
            </div>
          </div>
        </Reveal>

        {/* Product count header */}
        <div className="mb-8 flex items-center justify-between border-b border-hairline pb-4">
          <h3 className="text-[0.75rem] font-bold uppercase tracking-[0.2em] text-science">
            {products.length} Products Available in {meta.title}
          </h3>
          <span className="text-[0.75rem] text-muted-foreground">
            B2B Specification & Documentation Ready
          </span>
        </div>

        {/* Product grid */}
        {loading ? (
          <div className="py-20 text-center text-xs text-muted-foreground">Loading products database...</div>
        ) : products.length === 0 ? (
          <div className="py-20 text-center text-xs text-muted-foreground">No products available in this category.</div>
        ) : (
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {products.map((item, i) => (
              <Reveal key={item.slug} delay={(i % 12) * 20}>
                <div className="group flex h-full flex-col overflow-hidden border border-hairline bg-card p-6 shadow-sm transition-all hover:border-teal/40 hover:shadow-md">
                  {/* Custom Product Image or Fallback */}
                  <div className="mb-5 aspect-[16/10] w-full overflow-hidden bg-navy/5 rounded-sm">
                    <img
                      src={item.image_url ? item.image_url : imgMeta.img}
                      alt={item.name}
                      loading="lazy"
                      className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
                      onError={(e) => {
                        // Fallback to category default image if custom image URL fails to load
                        (e.target as HTMLImageElement).src = imgMeta.img;
                      }}
                    />
                  </div>

                  {/* Sub-group badge */}
                  {item.group && (
                    <span className="mb-2 self-start rounded-full bg-science/10 px-2.5 py-0.5 text-[0.65rem] font-semibold uppercase tracking-[0.12em] text-science">
                      {item.group}
                    </span>
                  )}

                  {/* Name */}
                  <h4 className="text-[1.05rem] font-semibold leading-snug text-navy">
                    {item.name}
                  </h4>

                  {/* Detailed overview */}
                  <p className="mt-3 flex-1 text-[0.84rem] leading-relaxed text-muted-foreground">
                    {item.detail}
                  </p>

                  {/* Specifications */}
                  {item.specs && item.specs.length > 0 && (
                    <div className="mt-4 border-t border-hairline pt-3">
                      <p className="text-[0.68rem] font-bold uppercase tracking-[0.12em] text-science mb-2">
                        Key Specifications:
                      </p>
                      <ul className="space-y-1">
                        {item.specs.slice(0, 4).map((spec, idx) => (
                          <li key={idx} className="flex items-start text-[0.76rem] text-muted-foreground">
                            <span className="mr-1.5 text-teal">•</span>
                            <span className="line-clamp-1">{spec}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {/* B2B Status Footer */}
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
            ))}
          </div>
        )}

        <Reveal>
          <div className="mt-14 border-t border-hairline pt-8">
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

