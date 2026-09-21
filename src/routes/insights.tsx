import { createFileRoute, Link, Outlet, useRouterState } from "@tanstack/react-router";
import { useState, useEffect } from "react";
import { PageHero, Section, SectionHeading, Reveal } from "@/components/site/primitives";
import { CTABand } from "@/components/site/CTABand";
import { useI18n } from "@/lib/i18n";
import { ARTICLES, Article } from "@/data/articles";
import { supabase } from "@/integrations/supabase/client";
import molecular from "@/assets/molecular.jpg";

export type DbArticleItem = Article & {
  hero_image?: string;
};

export const Route = createFileRoute("/insights")({
  head: () => ({
    meta: [
      { title: "Science & Insights — Vesco Science Knowledge Center" },
      {
        name: "description",
        content:
          "Articles on exosome science, PDRN/PN platforms, biotech manufacturing, Korean biotechnology and regulatory documentation for B2B partners.",
      },
      { property: "og:title", content: "Science & Insights — Vesco Science" },
      {
        property: "og:description",
        content: "A knowledge center for regenerative biotechnology and manufacturing practice.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [{ rel: "canonical", href: "/insights" }],
  }),
  component: Layout,
});

function Layout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  if (pathname !== "/insights") return <Outlet />;
  return <Index />;
}

function Index() {
  const { t } = useI18n();
  const [active, setActive] = useState<string | null>(null);
  const [allArticles, setAllArticles] = useState<DbArticleItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadDbArticles() {
      setLoading(true);
      try {
        const { data, error } = await supabase
          .from("articles")
          .select("*")
          .eq("published", true)
          .order("created_at", { ascending: false });

        if (!error && data && data.length > 0) {
          setAllArticles(
            data.map((d: any) => ({
              slug: d.slug,
              category: d.category,
              title: d.title,
              excerpt: d.excerpt || "",
              hero_image: d.hero_image || "",
              sections: Array.isArray(d.sections) ? d.sections : [],
              references: Array.isArray(d.references_list) ? d.references_list : [],
            }))
          );
        } else {
          // Fallback if DB empty
          setAllArticles(ARTICLES);
        }
      } catch (err) {
        console.error("DB articles load fallback to static:", err);
        setAllArticles(ARTICLES);
      } finally {
        setLoading(false);
      }
    }
    loadDbArticles();
  }, []);

  // Compute categories dynamically from active DB articles
  const categories = Array.from(new Set(allArticles.map((a) => a.category))).filter(Boolean);

  const shown = active ? allArticles.filter((a) => a.category === active) : allArticles;

  const chip = (on: boolean) =>
    `rounded-sm border px-4 py-2 text-[0.78rem] font-medium transition-colors ${
      on
        ? "border-teal bg-teal text-[#05231f]"
        : "border-hairline text-navy hover:border-teal hover:text-science"
    }`;

  return (
    <>
      <PageHero
        eyebrow={t("insights.eyebrow")}
        title={t("insights.title")}
        lead={t("insights.intro")}
        image={molecular}
        imageAlt={t("exosome.imageAlt")}
        crumb={{ label: t("insights.eyebrow"), homeLabel: t("common.breadcrumbHome") }}
      />

      <Section>
        <SectionHeading eyebrow={t("insights.eyebrow")} title={t("insights.title")} />

        {/* Dynamic Category Filters */}
        <div className="mt-10 flex flex-wrap gap-2">
          <button onClick={() => setActive(null)} className={chip(active === null)}>
            {t("common.viewAll")} ({allArticles.length})
          </button>
          {categories.map((c) => (
            <button key={c} onClick={() => setActive(c)} className={chip(active === c)}>
              {c}
            </button>
          ))}
        </div>

        {/* Dynamic Blog Cards */}
        {loading ? (
          <div className="py-20 text-center text-xs text-muted-foreground">Loading science articles...</div>
        ) : shown.length === 0 ? (
          <div className="py-20 text-center text-xs text-muted-foreground">No articles available in this category.</div>
        ) : (
          <div className="mt-12 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {shown.map((a, i) => (
              <Reveal key={a.slug} delay={(i % 6) * 60}>
                <Link
                  to="/insights/$slug"
                  params={{ slug: a.slug }}
                  className="card-flat group flex h-full flex-col overflow-hidden transition-all hover:border-teal/50"
                >
                  {/* Article Hero Image preview if uploaded */}
                  {a.hero_image ? (
                    <div className="aspect-[16/9] w-full overflow-hidden bg-navy/5">
                      <img
                        src={a.hero_image}
                        alt={a.title}
                        className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
                      />
                    </div>
                  ) : null}

                  <div className="flex flex-1 flex-col p-8">
                    <span className="text-[0.7rem] font-semibold tracking-[0.16em] uppercase text-science">
                      {a.category}
                    </span>
                    <h3 className="mt-4 text-[1.15rem] leading-snug font-semibold text-navy group-hover:text-science transition-colors">
                      {a.title}
                    </h3>
                    <p className="mt-3 flex-1 text-[0.93rem] leading-relaxed text-muted-foreground line-clamp-3">
                      {a.excerpt}
                    </p>
                    <span className="mt-7 inline-flex items-center gap-3 text-[0.75rem] font-semibold tracking-[0.14em] uppercase text-science">
                      <span className="h-px w-6 bg-teal transition-all duration-500 group-hover:w-10" />
                      {t("common.readMore")}
                    </span>
                  </div>
                </Link>
              </Reveal>
            ))}
          </div>
        )}

        <p className="mt-12 text-[0.85rem] text-muted-foreground">{t("insights.note")}</p>
      </Section>

      <CTABand />
    </>
  );
}
