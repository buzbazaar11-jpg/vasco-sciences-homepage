import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { useState, useEffect } from "react";
import { PageHero, Section, Reveal, TealButton } from "@/components/site/primitives";
import { CTABand } from "@/components/site/CTABand";
import { useI18n } from "@/lib/i18n";
import { ARTICLES, getArticle } from "@/data/articles";

import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/insights/$slug")({
  loader: async ({ params }) => {
    try {
      const { data, error } = await supabase
        .from("articles")
        .select("*")
        .eq("slug", params.slug)
        .maybeSingle();

      if (!error && data) {
        return {
          article: {
            slug: data.slug,
            category: data.category,
            title: data.title,
            excerpt: data.excerpt || "",
            hero_image: data.hero_image || "",
            sections: Array.isArray(data.sections) ? data.sections : [],
            references: Array.isArray(data.references_list) ? data.references_list : [],
          },
        };
      }
    } catch (e) {
      console.error("Supabase article loader error fallback to static:", e);
    }

    const staticArticle = getArticle(params.slug);
    if (!staticArticle) throw notFound();
    return { article: staticArticle };
  },
  head: ({ loaderData }) => {
    if (!loaderData) {
      return {
        meta: [
          { title: "Article not found — Vesco Science" },
          { name: "robots", content: "noindex" },
        ],
      };
    }
    const { title, excerpt, category, slug } = loaderData.article;
    return {
      meta: [
        { title: `${title} — Science & Insights | Vesco Science` },
        { name: "description", content: excerpt },
        { property: "og:title", content: title },
        { property: "og:description", content: excerpt },
        { property: "og:type", content: "article" },
        { name: "twitter:card", content: "summary_large_image" },
      ],
      links: [{ rel: "canonical", href: `/insights/${slug}` }],
      scripts: [
        {
          type: "application/ld+json",
          children: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "Article",
            headline: title,
            description: excerpt,
            articleSection: category,
            publisher: {
              "@type": "Organization",
              name: "Vesco Science Co., Ltd.",
              url: "https://vescoscience.com",
            },
          }),
        },
      ],
    };
  },
  component: Page,
});

function Page() {
  const { article } = Route.useLoaderData();
  const { t } = useI18n();

  const [dbRelated, setDbRelated] = useState<any[]>([]);

  useEffect(() => {
    async function loadRelated() {
      try {
        const { data, error } = await supabase
          .from("articles")
          .select("slug, title, excerpt, category")
          .eq("published", true)
          .eq("category", article.category)
          .neq("slug", article.slug)
          .limit(4);

        if (!error && data && data.length > 0) {
          setDbRelated(data);
        } else {
          setDbRelated(
            ARTICLES.filter(
              (a) => a.category === article.category && a.slug !== article.slug
            ).slice(0, 4)
          );
        }
      } catch (err) {
        setDbRelated(
          ARTICLES.filter(
            (a) => a.category === article.category && a.slug !== article.slug
          ).slice(0, 4)
        );
      }
    }
    loadRelated();
  }, [article.slug, article.category]);

  const related = dbRelated;

  return (
    <>
      <PageHero
        eyebrow={article.category}
        title={article.title}
        lead={article.excerpt}
        crumb={{ label: t("article.eyebrow"), homeLabel: t("common.breadcrumbHome") }}
      />

      <Section>
        <div className="grid gap-14 lg:grid-cols-[1.6fr_1fr]">

          {/* ── Main article body ──────────────────────────────────── */}
          <article>
            <Link
              to="/insights"
              className="text-[0.75rem] font-semibold tracking-[0.14em] uppercase text-science"
            >
              ← {t("article.back")}
            </Link>

            {/* Top Hero Header Image (if set from Admin or DB) */}
            {article.hero_image && (
              <Reveal>
                <div className="mt-6 aspect-[16/9] w-full overflow-hidden border border-hairline rounded-sm bg-navy/5">
                  <img
                    src={article.hero_image}
                    alt={article.title}
                    className="h-full w-full object-cover"
                  />
                </div>
              </Reveal>
            )}

            {/* Article sections from DB */}
            <div className="mt-10 grid gap-10">
              {article.sections.map((s, i) => (
                <Reveal key={i} delay={i * 40}>
                  <section className="space-y-4">
                    {s.heading && (
                      <h2 className="text-[1.35rem] leading-snug font-semibold text-navy mb-4">
                        {s.heading}
                      </h2>
                    )}

                    {/* Mid-Section Image (if set from Admin PC upload or DB) */}
                    {s.image && (
                      <div className="my-6 aspect-[16/9] w-full overflow-hidden border border-hairline rounded-sm bg-navy/5">
                        <img
                          src={s.image}
                          alt={s.heading || `Section ${i + 1}`}
                          className="h-full w-full object-cover"
                        />
                      </div>
                    )}

                    {/* Render body — handle newline-separated paragraphs */}
                    {s.body.split("\n\n").map((para, pi) => {
                      // Bullet list paragraphs start with "• "
                      if (para.startsWith("•")) {
                        const lines = para.split("\n").filter((l) => l.trim());
                        return (
                          <ul key={pi} className="mt-4 space-y-2 pl-1">
                            {lines.map((line, li) => (
                              <li key={li} className="flex items-start gap-2 text-[0.97rem] leading-relaxed text-muted-foreground">
                                <span className="mt-[6px] h-1.5 w-1.5 shrink-0 rounded-full bg-teal" />
                                <span>{line.replace(/^•\s*/, "")}</span>
                              </li>
                            ))}
                          </ul>
                        );
                      }
                      // Numbered list paragraphs
                      if (/^\d+\./.test(para)) {
                        const lines = para.split("\n").filter((l) => l.trim());
                        return (
                          <ul key={pi} className="mt-4 space-y-3 pl-1">
                            {lines.map((line, li) => (
                              <li key={li} className="flex items-start gap-3 text-[0.97rem] leading-relaxed text-muted-foreground">
                                <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-teal/10 text-[0.65rem] font-bold text-teal">
                                  {li + 1}
                                </span>
                                <span>{line.replace(/^\d+\.\s*/, "")}</span>
                              </li>
                            ))}
                          </ul>
                        );
                      }
                      // Normal paragraph
                      return (
                        <p key={pi} className="mt-4 text-[0.97rem] leading-relaxed text-muted-foreground">
                          {para}
                        </p>
                      );
                    })}
                  </section>
                </Reveal>
              ))}
            </div>

            {/* References */}
            {article.references && article.references.length > 0 && (
              <Reveal>
                <div className="mt-14 border-t border-hairline pt-8">
                  <h3 className="text-[0.72rem] font-semibold uppercase tracking-[0.18em] text-science mb-5">
                    References
                  </h3>
                  <ol className="space-y-2">
                    {article.references.map((ref, i) => (
                      <li key={i} className="flex items-start gap-3 text-[0.82rem] text-muted-foreground">
                        <span className="shrink-0 font-semibold text-teal">{i + 1}.</span>
                        <span>
                          {ref.phrase} —{" "}
                          <a
                            href={ref.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-science underline underline-offset-2 hover:text-teal transition-colors"
                          >
                            {ref.url.replace("https://", "").split("/")[0]}
                          </a>
                        </span>
                      </li>
                    ))}
                  </ol>
                </div>
              </Reveal>
            )}

            <p className="mt-10 border-t border-hairline pt-6 text-[0.82rem] text-muted-foreground">
              {t("article.note")}
            </p>

            <div className="mt-8">
              <TealButton to="/contact">{t("article.cta")}</TealButton>
            </div>
          </article>

          {/* ── Sidebar ───────────────────────────────────────────── */}
          <Reveal>
            <aside className="space-y-8">
              {/* Category badge */}
              <div className="card-flat p-6">
                <p className="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-science mb-2">
                  Category
                </p>
                <span className="inline-block rounded-sm border border-teal/30 bg-teal/5 px-3 py-1.5 text-[0.8rem] font-medium text-navy">
                  {article.category}
                </span>
              </div>

              {/* Related articles */}
              {related.length > 0 && (
                <div className="card-flat sticky top-28 p-6">
                  <h3 className="text-[0.72rem] font-semibold tracking-[0.14em] uppercase text-science mb-5">
                    {t("article.related")}
                  </h3>
                  <ul className="grid gap-4">
                    {related.map((r) => (
                      <li
                        key={r.slug}
                        className="border-t border-hairline pt-4 first:border-0 first:pt-0"
                      >
                        <Link
                          to="/insights/$slug"
                          params={{ slug: r.slug }}
                          className="block text-[0.9rem] leading-snug font-medium text-navy transition-colors hover:text-science"
                        >
                          {r.title}
                        </Link>
                        <p className="mt-1.5 text-[0.78rem] leading-relaxed text-muted-foreground line-clamp-2">
                          {r.excerpt}
                        </p>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {/* All articles link */}
              <div className="card-flat p-6">
                <TealButton to="/insights" variant="outline">
                  {t("article.back")}
                </TealButton>
              </div>
            </aside>
          </Reveal>

        </div>
      </Section>

      <CTABand />
    </>
  );
}
