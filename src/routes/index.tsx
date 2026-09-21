import { createFileRoute, Link } from "@tanstack/react-router";
import { useI18n } from "@/lib/i18n";
import {
  Eyebrow,
  NumberedCard,
  Reveal,
  Section,
  SectionHeading,
  TealButton,
} from "@/components/site/primitives";
import { CTABand } from "@/components/site/CTABand";
import { GlobalPartnershipSection } from "@/components/site/GlobalPartnership";
import { ARTICLES } from "@/data/articles";
import heroLab from "@/assets/hero-lab.jpg";
import exosomeImg from "@/assets/exosome.jpg";
import cleanroom from "@/assets/cleanroom.jpg";
import qcLab from "@/assets/qc-lab.jpg";
import molecular from "@/assets/molecular.jpg";
import koreanLabTeam from "@/assets/korean-lab-team.jpg";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Vesco Science — Korean Regenerative Biotechnology & OEM/ODM" },
      {
        name: "description",
        content:
          "Vesco Science develops and manufactures exosome, PDRN/PN and regenerative formulations in Korea, with OEM/ODM, lyophilization and cold chain capability for global partners.",
      },
      { property: "og:title", content: "Vesco Science — Advanced Regenerative Biotechnology" },
      {
        property: "og:description",
        content:
          "From cellular science to scalable manufacturing: exosome technology, PDRN/PN platforms and OEM/ODM development from Korea.",
      },
    ],
  }),
  component: Home,
});

function Home() {
  const { t, tx } = useI18n();

  const capabilities = tx<{ title: string; body: string }[]>("capabilities.items");
  const metrics = tx<{ label: string; value: string }[]>("capabilities.metrics");
  const techCards = tx<{ num: string; slug: string; title: string; body: string }[]>(
    "technology.cards",
  );
  const introPoints = tx<string[]>("intro.points");
  const productCats = tx<{ key: string; title: string; items: { slug: string; name: string }[] }[]>(
    "products.categories",
  );
  const researchAreas = tx<string[]>("research.areas");
  const researchTeamItems = tx<string[]>("research.team");
  const partnershipModels = tx<{ title: string; body: string }[]>("partnership.models");
  const featuredArticles = ARTICLES.slice(0, 3);

  return (
    <>
      {/* ================================================================
          01. HERO — Full-screen
          Main Heading: Advancing Regenerative Biotechnology
          Subheading: From scientific discovery to scalable manufacturing.
          Body: Vesco Science develops advanced biotechnology solutions through
                integrated R&D, formulation, manufacturing and quality systems.
          Button: Explore Our Technology
          ================================================================ */}
      <section className="relative isolate flex min-h-screen items-center overflow-hidden bg-navy-deep">

        {/* =========================================================
            HERO VIDEO — upload a licensed lab video to use here.
            Place the file at: public/videos/hero-background.mp4
            Then uncomment the <video> block below and remove the
            fallback <img> (or keep it as poster/fallback).
            ========================================================= */}
        {/* Fallback background image */}
        <img
          src={heroLab}
          alt={t("hero.imageAlt")}
          className="absolute inset-0 h-full w-full object-cover opacity-45"
          style={{ animation: "vs-slow-zoom 26s ease-in-out infinite alternate" }}
        />
        {/*
        <video autoPlay muted loop playsInline
          className="absolute inset-0 h-full w-full object-cover opacity-50"
          poster={heroLab}>
          <source src="/videos/hero-background.mp4" type="video/mp4" />
        </video>
        */}

        {/* Gradient overlay for text readability */}
        <div className="absolute inset-0 bg-gradient-to-r from-navy-deep via-navy-deep/88 to-navy/35" />
        <div className="absolute inset-0 navy-grid opacity-35" />

        <div className="relative mx-auto w-full max-w-[1240px] px-6 pt-32 pb-24 md:px-10">
          <Reveal>
            <Eyebrow invert>{t("hero.eyebrow")}</Eyebrow>
          </Reveal>
          <Reveal delay={120}>
            <h1 className="mt-7 max-w-4xl text-[clamp(2.4rem,5.6vw,4.4rem)] leading-[1.03] font-semibold text-white">
              {t("hero.title")}
            </h1>
          </Reveal>
          <Reveal delay={220}>
            <p className="mt-6 font-display text-[clamp(1.05rem,1.7vw,1.4rem)] text-teal">
              {t("hero.subtitle")}
            </p>
          </Reveal>
          <Reveal delay={320}>
            <p className="mt-7 max-w-2xl text-[1.0625rem] leading-relaxed text-white/70">
              {t("hero.body")}
            </p>
          </Reveal>
          <Reveal delay={420}>
            <div className="mt-11 flex flex-wrap gap-3">
              <TealButton to="/technology">{t("hero.ctaPrimary")}</TealButton>
              <TealButton to="/oem" variant="ghost">
                {t("hero.ctaSecondary")}
              </TealButton>
            </div>
          </Reveal>
        </div>

        <div className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-teal/60 to-transparent" />
      </section>

      {/* ================================================================
          02. TRUST / CAPABILITY BAR
          PDF: "R&D Driven | Advanced Manufacturing | Exosome Technology |
                Regenerative Platforms | OEM / ODM"
          ================================================================ */}
      <section className="relative bg-white border-b border-hairline">
        <div className="mx-auto w-full max-w-[1240px] px-6 py-10 md:px-10">
          <div className="grid grid-cols-2 gap-6 sm:grid-cols-3 lg:grid-cols-5">
            {[
              {
                icon: "🔬",
                title: "R&D Driven",
                body: "Continuous research and innovation to advance biotechnology solutions.",
              },
              {
                icon: "🏭",
                title: "Advanced Manufacturing",
                body: "State-of-the-art facilities ensuring precision, consistency and scale.",
              },
              {
                icon: "🧬",
                title: "Exosome Technology",
                body: "Advanced isolation, purification and characterization of extracellular vesicles.",
              },
              {
                icon: "🧫",
                title: "Regenerative Platforms",
                body: "Exosome, PDRN/PN, Peptide and HA-based solutions for regenerative applications.",
              },
              {
                icon: "⚙️",
                title: "OEM / ODM Solutions",
                body: "End-to-end development and manufacturing tailored to your brand.",
              },
            ].map((item) => (
              <div key={item.title} className="flex flex-col items-center text-center p-4">
                <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-full bg-teal/10 text-2xl">
                  {item.icon}
                </div>
                <h3 className="text-[0.8rem] font-bold uppercase tracking-[0.1em] text-navy">
                  {item.title}
                </h3>
                <div className="mt-2 h-px w-8 bg-teal/60" />
                <p className="mt-2 text-[0.75rem] leading-relaxed text-muted-foreground">
                  {item.body}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ================================================================
          03. ABOUT VESCO — "Where Biotechnology Meets Manufacturing"
          PDF section 03
          ================================================================ */}
      <Section>
        <div className="grid gap-14 lg:grid-cols-2 lg:items-center">
          <Reveal>
            <div>
              {/* PDF: small heading "WHO WE ARE" */}
              <p className="eyebrow">{t("intro.eyebrow")}</p>
              {/* PDF: "Where Biotechnology Meets Manufacturing" */}
              <h2 className="mt-5 text-[clamp(1.75rem,3.4vw,2.85rem)] leading-[1.12] font-semibold text-navy">
                Where Biotechnology Meets Manufacturing
              </h2>
              {/* PDF copy */}
              <p className="mt-6 text-[1rem] leading-relaxed text-muted-foreground">
                {t("intro.body1")}
              </p>
              <p className="mt-4 text-[1rem] leading-relaxed text-muted-foreground">
                {t("intro.body2")}
              </p>
              <ul className="mt-8 flex flex-wrap gap-2">
                {introPoints.map((p) => (
                  <li
                    key={p}
                    className="border border-hairline bg-card px-3.5 py-2 text-[0.78rem] font-medium text-navy"
                  >
                    {p}
                  </li>
                ))}
              </ul>
              <div className="mt-10">
                {/* PDF: "Discover Vesco Science →" */}
                <TealButton to="/about" variant="outline">
                  Discover Vesco Science
                </TealButton>
              </div>
            </div>
          </Reveal>

          {/* PDF: Lab / scientist / facility image */}
          <Reveal delay={140}>
            <div className="relative">
              {/* =========================================================
                  PDF IMAGE — HOME PAGE, ABOUT SECTION (Section 03)
                  Upload the lab/scientist/facility image from the Home PDF.
                  Suggested filename: home-about-lab.jpg
                  Replace cleanroom with your uploaded asset below.
                  ========================================================= */}
              <img
                src={cleanroom}
                alt="Vesco Science laboratory facility"
                loading="lazy"
                className="aspect-[4/3] w-full object-cover"
              />
              {/* TODO: PDF IMAGE — upload/replace with lab image from Home PDF section 03 */}
              <div className="absolute -bottom-5 -left-5 hidden border border-hairline bg-card px-6 py-5 md:block">
                <p className="eyebrow">{t("meta.company")}</p>
                <p className="mt-2 text-[0.9rem] text-navy">{t("meta.tagline")}</p>
              </div>
            </div>
          </Reveal>
        </div>
      </Section>

      {/* ================================================================
          04. CORE TECHNOLOGY — "Technology at the Cellular Level"
          PDF section 04 — 4 cards (Exosome, PDRN/PN, Peptide, HA)
          ================================================================ */}
      <Section tone="white">
        <Reveal>
          {/* PDF: eyebrow label */}
          <p className="eyebrow">{t("technology.eyebrow")}</p>
          {/* PDF: "Technology at the Cellular Level" */}
          <h2 className="mt-5 text-[clamp(1.75rem,3.4vw,2.85rem)] leading-[1.12] font-semibold text-navy">
            {t("technology.title")}
          </h2>
          <p className="mt-5 max-w-3xl text-[1.0625rem] leading-relaxed text-muted-foreground">
            {t("technology.intro")}
          </p>
        </Reveal>

        {/* PDF: 4 primary technology cards */}
        <div className="mt-14 grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {[
            {
              num: "01",
              slug: "exosome",
              title: "Exosome Technology",
              body: "Extracellular vesicle development, purification, characterization and formulation.",
            },
            {
              num: "02",
              slug: "pdrn-pn",
              title: "PDRN / PN Technology",
              body: "Advanced regenerative material platforms and formulation development.",
            },
            {
              num: "03",
              slug: "formulation",
              title: "Peptide Technology",
              body: "Bioactive peptide and peptide-complex formulation capabilities.",
            },
            {
              num: "04",
              slug: "formulation",
              title: "HA & Regenerative Formulation",
              body: "Hyaluronic acid and advanced aesthetic/regenerative formulations.",
            },
          ].map((card, i) => (
            <Reveal key={card.num} delay={i * 70}>
              <NumberedCard
                num={card.num}
                title={card.title}
                body={card.body}
                to="/technology/$slug"
                params={{ slug: card.slug }}
              />
            </Reveal>
          ))}
        </div>

        {/* Show all 6 technology cards below the primary 4 */}
        <Reveal delay={200}>
          <div className="mt-8 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {techCards.slice(4).map((card) => (
              <NumberedCard
                key={card.slug}
                num={card.num}
                title={card.title}
                body={card.body}
                to="/technology/$slug"
                params={{ slug: card.slug }}
              />
            ))}
          </div>
        </Reveal>

        <Reveal delay={120}>
          <div className="mt-12">
            {/* PDF: "Explore All Technologies →" */}
            <TealButton to="/technology" variant="outline">
              Explore All Technologies
            </TealButton>
          </div>
        </Reveal>
      </Section>

      {/* ================================================================
          05. EXOSOME FEATURE SECTION
          Google Doc: "From Cellular Source to Characterized Product"
          Left: EXOSOME TECHNOLOGY heading + description + 3 feature badges
          Right: 7-step process (Cell Source → Culture → Isolation →
                 Purification → Characterization → Formulation → Quality Control)
          ================================================================ */}
      <section className="relative isolate overflow-hidden bg-navy">
        <img
          src={exosomeImg}
          alt={t("exosome.imageAlt")}
          loading="lazy"
          className="absolute inset-0 h-full w-full object-cover opacity-20"
        />
        <div className="absolute inset-0 bg-gradient-to-b from-navy-deep/95 via-navy/85 to-navy-deep/95" />
        <div className="relative mx-auto w-full max-w-[1240px] px-6 py-20 md:px-10 md:py-28">
          <div className="grid gap-14 lg:grid-cols-[1fr_1.1fr] lg:items-start">

            {/* Left — description */}
            <Reveal>
              <div>
                <p className="eyebrow !text-teal">Exosome Technology</p>
                <h2 className="mt-5 text-[clamp(1.75rem,3.4vw,2.85rem)] leading-[1.12] font-semibold text-white">
                  From Cellular Source to Characterized Product
                </h2>
                <p className="mt-6 text-[1rem] leading-relaxed text-white/70">
                  {t("exosome.body1")}
                </p>
                <p className="mt-4 text-[1rem] leading-relaxed text-white/70">
                  {t("exosome.body2")}
                </p>
                {/* 3 feature badges */}
                <div className="mt-10 grid gap-px bg-white/10 sm:grid-cols-3">
                  {[
                    { label: "High Purity", desc: "Advanced isolation & purification technology" },
                    { label: "Consistent Quality", desc: "Rigorous testing and quality control" },
                    { label: "Proven Technology", desc: "Science-driven process and characterization" },
                  ].map((feat) => (
                    <div key={feat.label} className="bg-white/[0.04] px-5 py-5 text-center">
                      <p className="text-[0.8rem] font-semibold text-white">{feat.label}</p>
                      <p className="mt-1.5 text-[0.72rem] leading-relaxed text-white/55">{feat.desc}</p>
                    </div>
                  ))}
                </div>
                <div className="mt-10">
                  <TealButton to="/technology/$slug" params={{ slug: "exosome" }}>
                    {t("exosome.cta")}
                  </TealButton>
                </div>
              </div>
            </Reveal>

            {/* Right — 7-step process (exact Google Doc order) */}
            <Reveal delay={140}>
              <div>
                <p className="eyebrow !text-teal">Production Process</p>
                <ol className="mt-6 space-y-px">
                  {[
                    { step: "Cell Source",       desc: "Carefully selected and screened cell sources" },
                    { step: "Culture",           desc: "Optimized cell culture conditions for exosome production" },
                    { step: "Isolation",         desc: "Initial separation of exosomes from cell culture" },
                    { step: "Purification",      desc: "Advanced purification to achieve high purity exosomes" },
                    { step: "Characterization",  desc: "Comprehensive analysis of size, concentration and markers" },
                    { step: "Formulation",       desc: "Stabilized formulation for optimal performance" },
                    { step: "Quality Control",   desc: "Rigorous quality control at every batch" },
                  ].map((item, i) => (
                    <li
                      key={item.step}
                      className="flex items-start gap-4 bg-white/[0.04] px-5 py-4 outline outline-white/10"
                    >
                      <div className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-teal text-[0.62rem] font-bold text-[#05231f]">
                        {String(i + 1).padStart(2, "0")}
                      </div>
                      <div>
                        <p className="text-[0.88rem] font-semibold text-white">{item.step}</p>
                        <p className="mt-0.5 text-[0.78rem] leading-relaxed text-white/55">{item.desc}</p>
                      </div>
                    </li>
                  ))}
                </ol>
                <div className="mt-6 border border-teal/30 bg-teal/10 px-5 py-3 text-center">
                  <p className="text-[0.75rem] font-semibold tracking-[0.1em] text-teal">
                    Science · Technology · Quality · Every Step · Every Batch
                  </p>
                </div>
              </div>
            </Reveal>

          </div>
        </div>
      </section>


      {/* ================================================================
          06. MANUFACTURING — "From R&D to Scalable Manufacturing"
          PDF section 06
          ================================================================ */}
      <Section>
        <Reveal>
          <p className="eyebrow">Manufacturing</p>
          {/* PDF: "From R&D to Scalable Manufacturing" */}
          <SectionHeading
            title="From R&D to Scalable Manufacturing"
            intro="Our integrated development approach connects research, formulation, production and quality control to support the transition from concept to commercial manufacturing."
          />
        </Reveal>

        {/* PDF: 4-step flow with images: R&D → Development → Production → Quality */}
        <Reveal delay={100}>
          <div className="mt-12 grid gap-px bg-hairline sm:grid-cols-2 lg:grid-cols-4">
            {[
              {
                num: "01",
                title: "R&D",
                body: "Exploring innovative biological materials and advanced technologies.",
                img: molecular,
                /* TODO: PDF IMAGE — upload/replace with R&D lab image from Manufacturing section */
              },
              {
                num: "02",
                title: "Development",
                body: "Optimizing formulations and processes for stability, efficacy and consistency.",
                img: koreanLabTeam,
                /* TODO: PDF IMAGE — upload/replace with development image from Manufacturing section */
              },
              {
                num: "03",
                title: "Production",
                body: "Advanced manufacturing facilities with controlled environments and precise processes.",
                img: cleanroom,
                /* TODO: PDF IMAGE — upload/replace with production facility image from Manufacturing section */
              },
              {
                num: "04",
                title: "Quality",
                body: "Rigorous testing, monitoring and documentation at every stage.",
                img: qcLab,
                /* TODO: PDF IMAGE — upload/replace with quality control lab image from Manufacturing section */
              },
            ].map((step, i, arr) => (
              <div key={step.num} className="relative bg-card overflow-hidden">
                <img
                  src={step.img}
                  alt={step.title}
                  loading="lazy"
                  className="aspect-[4/3] w-full object-cover opacity-80"
                />
                {/* Arrow connector between steps */}
                {i < arr.length - 1 && (
                  <div className="absolute top-[calc(37.5%-12px)] right-0 z-10 hidden h-7 w-7 items-center justify-center bg-teal text-[#05231f] text-xs font-bold lg:flex">
                    →
                  </div>
                )}
                <div className="p-5">
                  <span className="font-display text-[0.72rem] font-bold tracking-[0.18em] text-teal">
                    {step.num}
                  </span>
                  <h4 className="mt-2 text-[0.95rem] font-semibold text-navy">{step.title}</h4>
                  <p className="mt-1.5 text-[0.82rem] leading-relaxed text-muted-foreground">
                    {step.body}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </Reveal>

        <Reveal delay={160}>
          <div className="mt-10">
            {/* PDF: "Explore Manufacturing →" */}
            <TealButton to="/facility" variant="outline">
              Explore Manufacturing
            </TealButton>
          </div>
        </Reveal>
      </Section>

      {/* ================================================================
          07. QUALITY — "Quality Built Into Every Stage"
          PDF section 07 — light-blue/white section with scientist image
          ================================================================ */}
      <Section tone="white">
        <div className="grid gap-14 lg:grid-cols-[1fr_1.1fr] lg:items-start">
          {/* Left: text + 6 quality cards */}
          <Reveal>
            <div>
              <p className="eyebrow text-science">Quality &amp; Control</p>
              {/* PDF: "Quality Built Into Every Stage" */}
              <h2 className="mt-5 text-[clamp(1.75rem,3.4vw,2.85rem)] leading-[1.12] font-semibold text-navy">
                {t("quality.title")}
              </h2>
              <p className="mt-5 text-[1.0625rem] leading-relaxed text-muted-foreground">
                From raw materials to final distribution, quality is integrated throughout our development and manufacturing process.
              </p>

              {/* PDF: 6-point quality grid */}
              <div className="mt-10 grid gap-px bg-hairline sm:grid-cols-2 lg:grid-cols-3">
                {[
                  {
                    num: "01",
                    title: "Raw Material Control",
                    body: "Controlled evaluation of high-quality raw materials.",
                  },
                  {
                    num: "02",
                    title: "Process Control",
                    body: "Defined and monitored manufacturing processes.",
                  },
                  {
                    num: "03",
                    title: "Analytical Testing",
                    body: "Advanced analytical methods for reliable quality assessment.",
                  },
                  {
                    num: "04",
                    title: "Microbiological Testing",
                    body: "Relevant microbiological evaluation for product safety.",
                  },
                  {
                    num: "05",
                    title: "Batch Traceability",
                    body: "Complete documentation and traceability for every batch.",
                  },
                  {
                    num: "06",
                    title: "Storage & Distribution",
                    body: "Controlled storage and secure distribution worldwide.",
                  },
                ].map((item, i) => (
                  <Reveal key={item.num} delay={i * 60}>
                    <div className="bg-card p-5 outline outline-hairline h-full">
                      <span className="font-display text-[0.7rem] font-bold tracking-[0.18em] text-teal">
                        {item.num}
                      </span>
                      <h4 className="mt-2 text-[0.88rem] font-semibold text-navy">{item.title}</h4>
                      <p className="mt-1.5 text-[0.8rem] leading-relaxed text-muted-foreground">
                        {item.body}
                      </p>
                    </div>
                  </Reveal>
                ))}
              </div>

              {/* PDF: Quality lifecycle flow */}
              <div className="mt-6 border border-hairline bg-background p-4">
                <p className="text-[0.65rem] font-semibold uppercase tracking-[0.16em] text-science mb-3">
                  Quality Lifecycle
                </p>
                <div className="flex flex-wrap items-center gap-1.5">
                  {["Raw Materials", "Manufacturing", "Testing", "Quality Review", "Distribution"].map(
                    (step, i, arr) => (
                      <span key={step} className="flex items-center gap-1.5">
                        <span className="text-[0.75rem] font-medium text-navy">{step}</span>
                        {i < arr.length - 1 && (
                          <span className="text-teal font-bold text-[0.7rem]">›</span>
                        )}
                      </span>
                    ),
                  )}
                </div>
              </div>

              <div className="mt-8 flex flex-wrap gap-3">
                {/* PDF: "Our Quality System →" */}
                <TealButton to="/quality" variant="outline">
                  Our Quality System
                </TealButton>
              </div>
            </div>
          </Reveal>

          {/* Right: scientist image — matches PDF quality section visual */}
          <Reveal delay={120}>
            <div className="relative">
              {/* =========================================================
                  PDF IMAGE — HOME PAGE, QUALITY SECTION (Section 07)
                  The PDF shows a scientist at a microscope with blue lab
                  background and molecular graphics overlay.
                  Suggested filename: home-quality-scientist.jpg
                  Replace qcLab with your uploaded asset below.
                  ========================================================= */}
              <img
                src={qcLab}
                alt="Quality control scientist"
                loading="lazy"
                className="aspect-[3/4] w-full object-cover"
              />
              {/* TODO: PDF IMAGE — upload/replace with scientist microscope image from Quality section */}
            </div>
          </Reveal>
        </div>
      </Section>

      {/* ================================================================
          CAPABILITIES METRICS — existing section, preserved
          ================================================================ */}
      <Section>
        <Reveal>
          <SectionHeading eyebrow={t("capabilities.eyebrow")} title={t("capabilities.title")} />
        </Reveal>
        <Reveal delay={120}>
          <div className="mt-12 border border-hairline bg-card p-8 md:p-10">
            <h3 className="eyebrow">{t("capabilities.metricsTitle")}</h3>
            <div className="mt-8 grid gap-8 sm:grid-cols-2 lg:grid-cols-5">
              {metrics.map((m) => (
                <div key={m.label} className="border-t border-hairline pt-5">
                  <p className="text-[0.7rem] font-semibold tracking-[0.16em] uppercase text-science">
                    {m.label}
                  </p>
                  <p className="mt-2 text-[0.95rem] text-foreground">{m.value}</p>
                </div>
              ))}
            </div>
            <p className="mt-8 text-[0.8rem] text-muted-foreground">
              {t("capabilities.metricsNote")}
            </p>
          </div>
        </Reveal>
      </Section>

      {/* ================================================================
          PRODUCTS — parent category cards only
          ================================================================ */}
      <Section tone="white">
        <Reveal>
          <SectionHeading
            eyebrow={t("products.eyebrow")}
            title={t("products.title")}
            intro={t("products.intro")}
          />
        </Reveal>
        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-5">
          {productCats.map((cat, i) => {
            const descriptions: Record<string, string> = {
              exosome:
                "Lyophilized hUC-MSC exosomes, scalp & vital diluents, and branded exosome kits for regenerative applications.",
              "dermal-fillers":
                "Small and large-molecular HA fillers, Hyalique-X and Luminelle™ branded formats for aesthetic use.",
              "peptide-bio-remodeling":
                "Blue copper peptide platforms and BlueVive / CuveraX™ collaboration products for bio-remodeling.",
              "botulinum-toxin":
                "Botulinum toxin 50 U – 500 U plus Botivex and Toxexa branded collaboration formats.",
              "pdrn-pn":
                "PDRN and PN solutions including Nucelvia, POLYNEXA and DNAVIA™ branded regenerative injectables.",
            };
            return (
              <Reveal key={cat.key} delay={i * 80}>
                <Link
                  to="/products/$category"
                  params={{ category: cat.key }}
                  className="card-flat group flex h-full flex-col p-7 transition-shadow hover:shadow-md"
                >
                  <span className="font-display text-[0.7rem] font-bold tracking-[0.18em] text-teal">
                    {String(i + 1).padStart(2, "0")}
                  </span>
                  <h3 className="mt-4 text-[1.05rem] font-semibold text-navy transition-colors group-hover:text-science">
                    {cat.title}
                  </h3>
                  <p className="mt-3 flex-1 text-[0.84rem] leading-relaxed text-muted-foreground">
                    {descriptions[cat.key] ?? ""}
                  </p>
                  <div className="mt-5 flex items-center gap-2 text-[0.75rem] font-semibold tracking-[0.1em] uppercase text-teal">
                    View Products
                    <span className="h-px w-5 bg-teal transition-all duration-300 group-hover:w-8" />
                  </div>
                </Link>
              </Reveal>
            );
          })}
        </div>
        <Reveal delay={120}>
          <div className="mt-12">
            <TealButton to="/products" variant="outline">
              {t("common.viewAll")}
            </TealButton>
          </div>
        </Reveal>
      </Section>

      {/* ================================================================
          08. GLOBAL PARTNERSHIP — Vesco Science × EverCeutical
          PDF: exact layout with world map, logos, platform icons, EverCeutical link
          ================================================================ */}
      <GlobalPartnershipSection />

      {/* ================================================================
          R&D SECTION — existing, preserved
          ================================================================ */}
      <Section tone="white">
        <Reveal>
          <SectionHeading
            eyebrow={t("research.eyebrow")}
            title={t("research.title")}
            intro={t("research.intro")}
          />
        </Reveal>
        <div className="mt-12 grid gap-10 lg:grid-cols-[1.2fr_1fr]">
          <Reveal delay={80}>
            <div>
              <h3 className="eyebrow">{t("research.areasTitle")}</h3>
              <ul className="mt-6 grid gap-px sm:grid-cols-2">
                {researchAreas.map((area) => (
                  <li
                    key={area}
                    className="bg-background px-5 py-4 text-[0.92rem] text-navy outline outline-hairline"
                  >
                    {area}
                  </li>
                ))}
              </ul>
            </div>
          </Reveal>
          <Reveal delay={160}>
            <div>
              <h3 className="eyebrow">{t("research.teamTitle")}</h3>
              <div className="mt-6 flex flex-wrap gap-2">
                {researchTeamItems.map((item) => (
                  <span
                    key={item}
                    className="rounded-sm border border-hairline px-3.5 py-2 text-[0.85rem] text-muted-foreground"
                  >
                    {item}
                  </span>
                ))}
              </div>
              <div className="mt-10">
                <TealButton to="/research" variant="outline">
                  {t("common.learnMore")}
                </TealButton>
              </div>
            </div>
          </Reveal>
        </div>
      </Section>

      {/* ================================================================
          PARTNERSHIP MODELS — existing, preserved
          ================================================================ */}
      <Section>
        <Reveal>
          <SectionHeading
            eyebrow={t("partnership.eyebrow")}
            title={t("partnership.title")}
            intro={t("partnership.intro")}
          />
        </Reveal>
        <div className="mt-14 grid gap-px bg-hairline sm:grid-cols-2 lg:grid-cols-3">
          {partnershipModels.map((m, i) => (
            <Reveal key={m.title} delay={i * 60}>
              <article className="h-full bg-card p-8">
                <span className="font-display text-[0.72rem] font-bold tracking-[0.18em] text-teal">
                  {String(i + 1).padStart(2, "0")}
                </span>
                <h3 className="mt-5 text-[1.05rem] font-semibold text-navy">{m.title}</h3>
                <p className="mt-3 text-[0.93rem] leading-relaxed text-muted-foreground">
                  {m.body}
                </p>
              </article>
            </Reveal>
          ))}
        </div>
        <Reveal delay={120}>
          <div className="mt-12">
            <TealButton to="/about/network" variant="outline">
              {t("partnership.cta")}
            </TealButton>
          </div>
        </Reveal>
      </Section>

      {/* ================================================================
          SCIENTIFIC INSIGHTS — existing, preserved
          ================================================================ */}
      <Section tone="white">
        <Reveal>
          <SectionHeading
            eyebrow={t("insights.eyebrow")}
            title={t("insights.title")}
            intro={t("insights.intro")}
          />
        </Reveal>
        <div className="mt-14 grid gap-6 md:grid-cols-3">
          {featuredArticles.map((a, i) => (
            <Reveal key={a.slug} delay={i * 70}>
              <Link
                to="/insights/$slug"
                params={{ slug: a.slug }}
                className="card-flat group flex h-full flex-col p-8"
              >
                <span className="text-[0.7rem] font-semibold tracking-[0.16em] uppercase text-teal">
                  {a.category}
                </span>
                <h3 className="mt-5 text-[1.08rem] font-semibold text-navy transition-colors group-hover:text-science">
                  {a.title}
                </h3>
                <p className="mt-3 flex-1 text-[0.92rem] leading-relaxed text-muted-foreground">
                  {a.excerpt}
                </p>
              </Link>
            </Reveal>
          ))}
        </div>
        <Reveal delay={120}>
          <div className="mt-12">
            <TealButton to="/insights" variant="outline">
              {t("common.viewAll")}
            </TealButton>
          </div>
        </Reveal>
      </Section>

      {/* ================================================================
          09. FINAL CTA — "Let's Build the Future of Regenerative Biotechnology"
          PDF section 09
          ================================================================ */}
      <section className="relative isolate overflow-hidden bg-navy">
        <div className="absolute inset-0 navy-grid opacity-60" />
        <div
          className="absolute -top-24 -right-16 h-72 w-72 rounded-full blur-3xl"
          style={{ background: "radial-gradient(circle,rgba(53,184,176,0.28),transparent 70%)" }}
        />
        <div className="relative mx-auto w-full max-w-[1240px] px-6 py-20 md:px-10 md:py-28">
          <Reveal>
            <div className="grid gap-10 lg:grid-cols-[1.6fr_1fr] lg:items-end">
              <div>
                {/* PDF: "Let's Build the Future of Regenerative Biotechnology" */}
                <h2 className="max-w-2xl text-[clamp(1.6rem,3vw,2.5rem)] leading-[1.14] font-semibold text-white">
                  {t("cta.title")}
                </h2>
                {/* PDF: "Have a product concept, manufacturing requirement or partnership opportunity?" */}
                <p className="mt-5 max-w-xl text-[1rem] leading-relaxed text-white/65">
                  {t("cta.body")}
                </p>
              </div>
              <div className="flex flex-wrap gap-3 lg:justify-end">
                {/* PDF: "Talk to Our Team" */}
                <TealButton to="/contact">{t("cta.primary")}</TealButton>
                {/* PDF: "OEM / ODM Inquiry" */}
                <TealButton to="/oem" variant="ghost">
                  OEM / ODM Inquiry
                </TealButton>
              </div>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
