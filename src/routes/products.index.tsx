import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, useEffect } from "react";
import { PageHero, Section, Reveal, TealButton } from "@/components/site/primitives";
import { CTABand } from "@/components/site/CTABand";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/integrations/supabase/client";
import vials from "@/assets/vials.jpg";
import exosomeImg from "@/assets/exosome.jpg";
import molecular from "@/assets/molecular.jpg";
import cleanroom from "@/assets/cleanroom.jpg";
import qcLab from "@/assets/qc-lab.jpg";

export const Route = createFileRoute("/products/")({
  head: () => ({
    meta: [
      { title: "B2B Product Catalogue — Exosome, Fillers, PDRN/PN, Peptide, Botulinum Toxin" },
      {
        name: "description",
        content:
          "Vesco Science B2B product catalogue: lyophilized hUC-MSC exosomes, dermal fillers, peptide bio-remodeling, botulinum toxin, PDRN/PN solutions — including ExoGenesis, Exolyra, Hyalique-X, Luminelle, BlueVive, CuveraX, Botivex, Toxexa, Nucelvia, Polynexa, DNAVIA.",
      },
      { property: "og:title", content: "B2B Product Catalogue — Vesco Science" },
      {
        property: "og:description",
        content:
          "Five product categories. Full specifications and documentation issued on request under confidentiality.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Page,
});

// ─── Category cards metadata ──────────────────────────────────────────────────

const CATEGORIES_BASE = [
  {
    key: "exosome",
    num: "01",
    title: "Exosomes",
    description:
      "Lyophilized hUC-MSC exosome platforms, scalp and vital diluents, and branded collaboration kits for professional regenerative applications. Every format is produced under controlled conditions with full batch documentation.",
    img: exosomeImg,
    imgAlt: "Lyophilized exosome vials in a cleanroom environment",
    defaultCount: 27,
  },
  {
    key: "dermal-fillers",
    num: "02",
    title: "Dermal Fillers",
    description:
      "Small and large-molecular hyaluronic acid fillers in multiple concentrations, alongside Hyalique-X and Luminelle™ branded collaboration formats for professional aesthetic and regenerative applications.",
    img: vials,
    imgAlt: "Dermal filler syringes and vials",
    defaultCount: 17,
  },
  {
    key: "peptide-bio-remodeling",
    num: "03",
    title: "Peptide-Based Bio-Remodeling",
    description:
      "Blue copper peptide platforms in 100 mg, 200 mg and 300 mg formats, paired with HA diluent. BlueVive Booster and CuveraX™ are branded collaboration products for professional bio-remodeling use.",
    img: molecular,
    imgAlt: "Peptide molecular structure and laboratory vials",
    defaultCount: 7,
  },
  {
    key: "botulinum-toxin",
    num: "04",
    title: "Botulinum Toxin",
    description:
      "Botulinum toxin in 50 U to 500 U formats, alongside Botivex and Toxexa branded collaboration products. Manufactured under aseptic conditions with full quality documentation per batch.",
    img: cleanroom,
    imgAlt: "Aseptic cleanroom filling line for injectable products",
    defaultCount: 10,
  },
  {
    key: "pdrn-pn",
    num: "05",
    title: "PDRN / PN Solutions",
    description:
      "PDRN and PN injectable solutions including combination HA formats, plus Nucelvia, POLYNEXA and DNAVIA™ branded collaboration products for professional regenerative and aesthetic use.",
    img: qcLab,
    imgAlt: "Quality control laboratory testing PDRN and PN solutions",
    defaultCount: 18,
  },
];

function Page() {
  const { t } = useI18n();
  const [counts, setCounts] = useState<Record<string, number>>({});

  useEffect(() => {
    async function loadProductCounts() {
      try {
        const { data, error } = await supabase
          .from("products")
          .select("category")
          .eq("published", true);

        if (!error && data) {
          const map: Record<string, number> = {};
          data.forEach((item: any) => {
            map[item.category] = (map[item.category] || 0) + 1;
          });
          setCounts(map);
        }
      } catch (err) {
        console.error("Failed to load product counts from DB:", err);
      }
    }
    loadProductCounts();
  }, []);

  return (
    <>
      <PageHero
        eyebrow={t("products.eyebrow")}
        title={t("products.title")}
        lead={t("products.intro")}
        image={vials}
        imageAlt={t("facility.imageAlt")}
        crumb={{ label: t("nav.products"), homeLabel: t("common.breadcrumbHome") }}
      />

      <Section>
        {/* Intro note */}
        <Reveal>
          <div className="mb-14 border border-hairline bg-card p-6 md:p-8">
            <p className="text-[0.8rem] font-semibold uppercase tracking-[0.16em] text-science mb-3">
              About This Catalogue
            </p>
            <p className="text-[0.95rem] leading-relaxed text-muted-foreground">
              Full product specifications, batch documentation, COA and TDS are issued on request
              under confidentiality. All products are intended for B2B, professional, and research
              use in accordance with the regulatory framework of the destination market.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <TealButton to="/contact" variant="outline">Request Product Information</TealButton>
              <TealButton to="/oem" variant="outline">OEM / ODM Inquiry</TealButton>
            </div>
          </div>
        </Reveal>

        {/* Category cards */}
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
          {CATEGORIES_BASE.map((cat, i) => {
            const productCount = counts[cat.key] !== undefined ? counts[cat.key] : cat.defaultCount;
            return (
              <Reveal key={cat.key} delay={i * 60}>
                <Link
                  to="/products/$category"
                  params={{ category: cat.key }}
                  className="group flex flex-col overflow-hidden border border-hairline bg-card transition-shadow hover:shadow-lg"
                >
                  {/* Image */}
                  <div className="aspect-[16/9] overflow-hidden">
                    <img
                      src={cat.img}
                      alt={cat.imgAlt}
                      loading="lazy"
                      className="h-full w-full object-cover opacity-90 transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>

                  {/* Content */}
                  <div className="flex flex-1 flex-col p-7">
                    <div className="flex items-center justify-between">
                      <span className="font-display text-[0.7rem] font-bold tracking-[0.18em] text-teal">
                        {cat.num}
                      </span>
                      <span className="text-[0.7rem] text-muted-foreground font-medium">
                        {productCount} products
                      </span>
                    </div>
                    <h3 className="mt-3 text-[1.15rem] font-semibold text-navy transition-colors group-hover:text-science">
                      {cat.title}
                    </h3>
                    <p className="mt-3 flex-1 text-[0.85rem] leading-relaxed text-muted-foreground">
                      {cat.description}
                    </p>
                    <div className="mt-5 flex items-center gap-2 text-[0.75rem] font-semibold tracking-[0.1em] uppercase text-teal">
                      Explore Category
                      <span className="h-px w-5 bg-teal transition-all duration-300 group-hover:w-8" />
                    </div>
                  </div>
                </Link>
              </Reveal>
            );
          })}
        </div>

        {/* Footer note */}
        <Reveal>
          <div className="mt-16 border-t border-hairline pt-8">
            <p className="text-[0.85rem] text-muted-foreground">
              {t("products.detail.demoNote")}
            </p>
            <div className="mt-6">
              <TealButton to="/contact" variant="outline">
                Request Product Catalogue
              </TealButton>
            </div>
          </div>
        </Reveal>
      </Section>

      <CTABand />
    </>
  );
}
