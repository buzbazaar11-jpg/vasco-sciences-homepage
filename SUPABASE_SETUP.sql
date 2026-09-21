-- ============================================================
-- VESCO VISION — Complete Supabase Setup & Seed SQL Script
-- Run this ENTIRE script in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/_/sql
-- ============================================================

-- 1. ENABLE UUID EXTENSION
create extension if not exists "uuid-ossp";

-- ============================================================
-- 2. TABLES SCHEMA CREATION
-- ============================================================

-- Pages table (Visual Page Builder at /p/:slug)
create table if not exists public.pages (
  id             uuid primary key default uuid_generate_v4(),
  slug           text not null unique,
  title_en       text not null default '',
  title_ko       text not null default '',
  description_en text not null default '',
  description_ko text not null default '',
  blocks         jsonb not null default '[]'::jsonb,
  published      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Resources / Downloads table
create table if not exists public.resources (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  category    text not null default 'Other',
  file_url    text not null default '',
  file_path   text not null default '',
  restricted  boolean not null default false,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Site settings
create table if not exists public.site_settings (
  key        text primary key,
  value      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- User roles
create type if not exists public.app_role as enum ('admin', 'editor');

create table if not exists public.user_roles (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       public.app_role not null default 'admin',
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

-- PRODUCTS TABLE (Full Catalogue & Admin CRUD)
create table if not exists public.products (
  id          uuid primary key default uuid_generate_v4(),
  slug        text not null unique,
  category    text not null, -- 'exosome', 'dermal-fillers', 'peptide-bio-remodeling', 'botulinum-toxin', 'pdrn-pn'
  group_name  text not null default '',
  label       text not null default '',
  name        text not null,
  detail      text not null default '',
  specs       jsonb not null default '[]'::jsonb,
  image_url   text not null default '',
  sort_order  integer not null default 0,
  published   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ARTICLES / BLOGS TABLE (Full Science Insights & Admin CRUD)
create table if not exists public.articles (
  id              uuid primary key default uuid_generate_v4(),
  slug            text not null unique,
  category        text not null, -- 'Exosome Science', 'PDRN / PN', 'Manufacturing', 'Hyaluronic Acid', 'Industry Insights'
  title           text not null,
  excerpt         text not null default '',
  hero_image      text not null default '',
  sections        jsonb not null default '[]'::jsonb,
  references_list jsonb not null default '[]'::jsonb,
  published       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ============================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

alter table public.pages         enable row level security;
alter table public.resources     enable row level security;
alter table public.site_settings enable row level security;
alter table public.user_roles    enable row level security;
alter table public.products     enable row level security;
alter table public.articles     enable row level security;

-- Helper function: is_admin
create or replace function public.is_admin()
returns boolean
language sql stable security definer
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

-- RLS Policies for Pages
drop policy if exists "Public can read published pages" on public.pages;
create policy "Public can read published pages" on public.pages for select using (published = true);
drop policy if exists "Admins can do everything on pages" on public.pages;
create policy "Admins can do everything on pages" on public.pages for all using (public.is_admin()) with check (public.is_admin());

-- RLS Policies for Resources
drop policy if exists "Public can read unrestricted resources" on public.resources;
create policy "Public can read unrestricted resources" on public.resources for select using (restricted = false);
drop policy if exists "Admins can do everything on resources" on public.resources;
create policy "Admins can do everything on resources" on public.resources for all using (public.is_admin()) with check (public.is_admin());

-- RLS Policies for Site Settings
drop policy if exists "Admins can read site_settings" on public.site_settings;
create policy "Admins can read site_settings" on public.site_settings for select using (public.is_admin());
drop policy if exists "Admins can write site_settings" on public.site_settings;
create policy "Admins can write site_settings" on public.site_settings for all using (public.is_admin()) with check (public.is_admin());

-- RLS Policies for Products
drop policy if exists "Public can read published products" on public.products;
create policy "Public can read published products" on public.products for select using (published = true);
drop policy if exists "Admins can do everything on products" on public.products;
create policy "Admins can do everything on products" on public.products for all using (public.is_admin()) with check (public.is_admin());

-- RLS Policies for Articles
drop policy if exists "Public can read published articles" on public.articles;
create policy "Public can read published articles" on public.articles for select using (published = true);
drop policy if exists "Admins can do everything on articles" on public.articles;
create policy "Admins can do everything on articles" on public.articles for all using (public.is_admin()) with check (public.is_admin());

-- RLS Policies for User Roles
drop policy if exists "Users can read own role" on public.user_roles;
create policy "Users can read own role" on public.user_roles for select using (user_id = auth.uid());
drop policy if exists "Admins can manage user_roles" on public.user_roles;
create policy "Admins can manage user_roles" on public.user_roles for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- 4. STORAGE BUCKET SETUP
-- ============================================================
insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public read images" on storage.objects;
create policy "Public read images" on storage.objects for select using (bucket_id = 'images');
drop policy if exists "Authenticated users can upload images" on storage.objects;
create policy "Authenticated users can upload images" on storage.objects for insert with check (bucket_id = 'images' and auth.role() = 'authenticated');
drop policy if exists "Authenticated users can update images" on storage.objects;
create policy "Authenticated users can update images" on storage.objects for update using (bucket_id = 'images' and auth.role() = 'authenticated');
drop policy if exists "Authenticated users can delete images" on storage.objects;
create policy "Authenticated users can delete images" on storage.objects for delete using (bucket_id = 'images' and auth.role() = 'authenticated');

-- ============================================================
-- 5. SEED PRODUCTS DATA (79 Real Products)
-- ============================================================

insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('lyophilized-huc-msc-exosomes-5b', 'exosome', 'Lyophilized hUC-MSC Exosomes', '5B', 'Lyophilized hUC-MSC Exosomes 5B', 'Lyophilized hUC-MSC Exosomes 5B is a high-quality exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Formulated in a convenient lyophilized format, it provides 5 billion exosomes per vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs)", "Exosome Content: 5 Billion Exosomes", "Formulation: Lyophilized", "Format: Single-vial preparation", "Intended Users: Qualified medical and aesthetic professionals"]'::jsonb, '', 0, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('lyophilized-huc-msc-exosomes-10b', 'exosome', 'Lyophilized hUC-MSC Exosomes', '10B', 'Lyophilized hUC-MSC Exosomes 10B', 'Lyophilized hUC-MSC Exosomes 10B is a premium exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Supplied in a convenient lyophilized format, each vial contains 10 billion exosomes, developed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs)", "Exosome Content: 10 Billion Exosomes", "Formulation: Lyophilized", "Format: Single-vial preparation", "Intended Users: Qualified medical and aesthetic professionals"]'::jsonb, '', 1, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('lyophilized-huc-msc-exosomes-15b', 'exosome', 'Lyophilized hUC-MSC Exosomes', '15B', 'Lyophilized hUC-MSC Exosomes 15B', 'Lyophilized hUC-MSC Exosomes 15B is a premium exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Supplied in a convenient lyophilized format, each vial contains 15 billion exosomes, developed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs)", "Exosome Content: 15 Billion Exosomes", "Formulation: Lyophilized", "Format: Single-vial preparation", "Intended Users: Qualified medical and aesthetic professionals"]'::jsonb, '', 2, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('lyophilized-huc-msc-exosomes-20b', 'exosome', 'Lyophilized hUC-MSC Exosomes', '20B', 'Lyophilized hUC-MSC Exosomes 20B', 'Lyophilized hUC-MSC Exosomes 20B is a premium exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Supplied in a convenient lyophilized format, each vial contains 20 billion exosomes, developed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs)", "Exosome Content: 20 Billion Exosomes", "Formulation: Lyophilized", "Format: Single-vial preparation", "Intended Users: Qualified medical and aesthetic professionals"]'::jsonb, '', 3, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('lyophilized-huc-msc-exosomes-25b', 'exosome', 'Lyophilized hUC-MSC Exosomes', '25B', 'Lyophilized hUC-MSC Exosomes 25B', 'Lyophilized hUC-MSC Exosomes 25B is a premium exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Supplied in a convenient lyophilized format, each vial contains 25 billion exosomes, developed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs)", "Exosome Content: 25 Billion Exosomes", "Formulation: Lyophilized", "Format: Single-vial preparation", "Intended Users: Qualified medical and aesthetic professionals"]'::jsonb, '', 4, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('lyophilized-huc-msc-exosomes-40b', 'exosome', 'Lyophilized hUC-MSC Exosomes', '40B', 'Lyophilized hUC-MSC Exosomes 40B', 'Lyophilized hUC-MSC Exosomes 40B is a premium exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Supplied in a convenient lyophilized format, each vial contains 40 billion exosomes, developed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs)", "Exosome Content: 40 Billion Exosomes", "Formulation: Lyophilized", "Format: Single-vial preparation", "Intended Users: Qualified medical and aesthetic professionals"]'::jsonb, '', 5, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('scalp-exosome-diluent-9-bioactive-peptides', 'exosome', 'Scalp Exosome Diluent', '9 Bioactive Peptides', 'Scalp Exosome Diluent', '9 Bioactive Peptide Complex for Scalp & Hair Applications Scalp Exosome Diluent is a professionally formulated human-use peptide complex developed for scalp and hair applications. It combines nine complementary bioactive peptides designed to support the follicular microenvironment, scalp condition, extracellular matrix, and hair-root environment. The formulation is designed to complement professional exosome-based scalp protocols through a targeted multi-peptide approach. ________________', '["9 bioactive peptides in a targeted formulation", "Designed for scalp and hair applications", "Supports the follicular microenvironment", "Provides ECM, dermal, and vascular support", "Complements professional exosome-based protocols"]'::jsonb, '', 6, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('scalp-exosome-diluent-13-bioactive-peptides', 'exosome', 'Scalp Exosome Diluent', '13 Bioactive Peptides', 'Scalp Exosome Diluent', '13 Bioactive Peptide Complex for Scalp & Hair Applications Scalp Exosome Diluent is a professionally formulated human-use peptide complex developed for scalp and hair applications. It combines 13 bioactive peptides designed to provide complementary support for the follicular microenvironment, dermal regeneration, scalp condition, and hair-cycle processes. The formulation is designed to complement professional exosome-based scalp protocols through a comprehensive multi-peptide approach. ________________', '["13 bioactive peptides in a targeted formulation", "Designed for scalp and hair applications", "Supports the follicular microenvironment", "Supports dermal and extracellular matrix functions", "Supports follicle anchoring and hair-cycle processes"]'::jsonb, '', 7, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('scalp-exosome-diluent-16-bioactive-peptides', 'exosome', 'Scalp Exosome Diluent', '16 Bioactive Peptides', 'Scalp Exosome Diluent', '16 Bioactive Peptide Complex for Scalp & Hair Applications Scalp Exosome Diluent is a professionally formulated human-use peptide complex developed for scalp and hair applications. It combines 16 complementary bioactive peptides designed to support the follicular microenvironment, dermal structure, extracellular matrix, scalp condition, and hair-cycle processes. The formulation is designed to complement professional exosome-based scalp protocols through a comprehensive multi-peptide approach. ________________', '["16 bioactive peptides in a targeted formulation", "Designed for scalp and hair applications", "Supports the follicular microenvironment", "Supports dermal and extracellular matrix functions", "Supports follicle anchoring and hair-cycle processes"]'::jsonb, '', 8, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('vital-exosome-diluent-9-bioactive-peptides', 'exosome', 'Vital Exosome Diluent', '9 Bioactive Peptides', 'Vital Exosome Diluent', 'Vital Exosome Diluent is a professionally formulated 9-bioactive peptide complex designed to complement professional exosome-based protocols. The formulation combines peptides with complementary roles in skin regeneration, extracellular matrix support, firmness, elasticity, cellular turnover, and tissue repair. The multi-peptide formulation provides a broader functional approach rather than relying on a single active ingredient, making it suitable for integration into validated professional exosome applications. ________________', '["9 Bioactive Peptides in a targeted multi-peptide formulation", "Supports skin regeneration and cellular renewal", "Provides complementary ECM and collagen-related support", "Supports skin firmness and elasticity", "Helps support tissue repair and skin recovery"]'::jsonb, '', 9, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('vital-exosome-diluent-12-bioactive-peptides', 'exosome', 'Vital Exosome Diluent', '12 Bioactive Peptides', 'Vital Exosome Diluent', 'Vital Exosome Diluent is a professionally formulated 12-bioactive peptide complex developed for professional skin applications. It combines complementary peptides selected to support skin regeneration, extracellular matrix quality, collagen-related processes, firmness, elasticity, hydration, skin smoothness, and tissue recovery. The multi-peptide formulation is designed to provide broad functional support across different aspects of the skin microenvironment and can complement professional exosome-based protocols. ________________', '["12 Bioactive Peptides in a targeted multi-peptide formulation", "Supports skin regeneration and cellular renewal", "Provides complementary collagen and extracellular matrix support", "Supports skin firmness and elasticity", "Supports skin hydration and smoothness"]'::jsonb, '', 10, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('vital-exosome-diluent-16-bioactive-peptides', 'exosome', 'Vital Exosome Diluent', '16 Bioactive Peptides', 'Vital Exosome Diluent', 'Vital Exosome Diluent is a professionally formulated 16-bioactive peptide complex developed for professional skin applications. It combines complementary peptides selected to support skin regeneration, extracellular matrix quality, collagen-related processes, firmness, elasticity, hydration, skin smoothness, skin tone, and tissue recovery. The multi-peptide formulation provides broad functional support across key aspects of the skin microenvironment and is designed to complement professional exosome-based protocols. ________________', '["16 Bioactive Peptides in a targeted multi-peptide formulation", "Supports skin regeneration and cellular renewal", "Provides complementary collagen and extracellular matrix support", "Supports skin firmness and elasticity", "Supports hydration and skin smoothness"]'::jsonb, '', 11, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exogenesis-exogenesis-10b-scalp-kit-9-peptide-scalp-diluent', 'exosome', 'ExoGenesis™', 'ExoGenesis™ 10B Scalp kit (+ 9-Peptide Scalp Diluent)', 'Exosomes Scalp Kit (10 Billion)', 'Exosomes Scalp Kit (10 Billion) is a professional scalp-focused exosome system combining lyophilized hUC-MSC-derived exosomes with a complementary 9-bioactive-peptide diluent. Each kit contains 10 Billion+ exosome particles derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). The formulation is designed for professional aesthetic applications focused on the scalp, hair and follicular environment. The product is an official collaboration between Vesco Science and EverCeutical. ________________', '["The peptide diluent contains nine bioactive peptides with complementary functional roles:", "The combined exosome and peptide system is designed for professional protocols supporting:", "Scalp & Hair Health", "Follicular Environment", "Hair Density & Appearance"]'::jsonb, '', 12, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exogenesis-exogenesis-15b-scalp-kit-13-peptide-vital-diluent', 'exosome', 'ExoGenesis™', 'ExoGenesis™ 15B Scalp Kit (+ 13-Peptide Vital Diluent)', 'Exosomes Scalp Kit (15 Billion)', 'Exosomes Scalp Kit (15 Billion) is a professional scalp-focused exosome system combining lyophilized hUC-MSC-derived exosomes with a complementary 13-bioactive-peptide diluent. Each kit contains 15 Billion+ exosome particles (3 Billion/mL) derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). The formulation is designed for professional aesthetic applications focused on the scalp, hair and follicular environment. The product is an official collaborative offering between Vesco Science and EverCeutical. (EverCeutical) ________________', '["The combined exosome and peptide system is designed for professional protocols supporting:", "Cellular Renewal & Recovery", "Tissue & Skin Repair", "Collagen & Extracellular Matrix Support", "Hair Density & Follicular Support"]'::jsonb, '', 13, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exogenesis-exogenesis-25b-scalp-kit', 'exosome', 'ExoGenesis™', 'ExoGenesis™ 25B Scalp Kit', 'ExoGenesis™ Scalp Kit (25 Billion)', 'ExoGenesis™ Scalp Kit (25 Billion) is a professional scalp-focused exosome system containing lyophilized exosomes derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Each kit provides 25 Billion+ exosome particles formulated for professional aesthetic applications focused on the scalp, hair and follicular environment. The lyophilized exosome formulation is supplied with a complementary diluent for professional preparation and application. ExoGenesis™ Scalp Kit (25 Billion) is an official collaborative product between Vesco Science and EverCeutical. ________________', '["The exosome-based system is designed for professional protocols supporting:", "Cellular Renewal & Recovery", "Tissue & Skin Repair", "Collagen & Extracellular Matrix Support", "Hair Density & Follicular Support"]'::jsonb, '', 14, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exogenesis-exogenesis-10b-vital-kit-9-peptide-scalp-diluent', 'exosome', 'ExoGenesis™', 'ExoGenesis™ 10B Vital Kit (+ 9-Peptide Scalp Diluent)', 'Exosomes Vital Kit (10 Billion)', 'Exosomes Vital Kit (10 Billion) is a professional exosome-based system combining lyophilized exosomes with a complementary peptide-infused diluent containing 9 dermatology-grade anti-aging peptides. Each kit contains 10 Billion exosome particles supplied in a 5 mL vial at 2 Billion/mL. The formulation is designed for professional aesthetic applications focused on skin rejuvenation, cellular recovery, collagen support and overall skin vitality. The product is an official collaborative offering between Vesco Science and EverCeutical. (EverCeutical)', '["The combined exosome and peptide system is designed for professional protocols supporting:", "Cellular Renewal & Recovery", "Tissue & Skin Repair", "Collagen & Elastin Support", "Skin Brightening & Radiance"]'::jsonb, '', 15, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exogenesis-exogenesis-15b-vital-kit-13-peptide-vital-diluent', 'exosome', 'ExoGenesis™', 'ExoGenesis™ 15B Vital Kit (+ 13-Peptide Vital Diluent)', 'Exosomes Vital Kit (15 Billion)', 'Exosomes Vital Kit (15 Billion) is a professional exosome-based aesthetic system combining lyophilized exosomes with an advanced peptide-infused diluent formulated for skin rejuvenation and anti-aging applications. Each kit contains 15 Billion exosomes supplied in a 5 mL vial at 3 Billion/mL, together with a peptide-infused diluent containing 9 active peptides. The formulation is designed for professional applications focused on skin quality, cellular recovery, collagen support and aesthetic rejuvenation. (EverCeutical) The product is an official collaborative offering between Vesco Science and EverCeutical.', '["The combined exosome and peptide system is designed for professional protocols supporting:", "Cellular Renewal & Recovery", "Tissue & Skin Repair", "Collagen & Elastin Support", "Skin Brightening & Radiance"]'::jsonb, '', 16, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-3b', 'exosome', 'Exolyra™', 'Exolyra™ 3B', 'Exolyra™ 3B | 5 mL', 'Exolyra™ 3B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord MSCs. Formulated as a lyophilized powder, it provides 3 billion exosomes in a 5 mL vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 3 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 17, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-5b', 'exosome', 'Exolyra™', 'Exolyra™ 5B', 'Exolyra™ — Exolyra™ 5B', '', '[]'::jsonb, '', 18, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-7b', 'exosome', 'Exolyra™', 'Exolyra™ 7B', 'Exolyra™ 7B | 5 mL', 'Exolyra™ 7B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord MSCs. Formulated as a lyophilized powder, it provides 7 billion exosomes in a 5 mL vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 7 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 19, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-10b', 'exosome', 'Exolyra™', 'Exolyra™ 10B', 'Exolyra™ 10B | 5 mL', 'Exolyra™ 10B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord MSCs. Formulated as a lyophilized powder, it provides 10 billion exosomes in a 5 mL vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 10 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 20, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-12b', 'exosome', 'Exolyra™', 'Exolyra™ 12B', 'Exolyra™ 12B | 5 mL', 'Exolyra™ 12B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord MSCs. Formulated as a lyophilized powder, it provides 12 billion exosomes in a 5 mL vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 12 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 21, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-15b', 'exosome', 'Exolyra™', 'Exolyra™ 15B', 'Exolyra™ 15B | 5 mL', 'Exolyra™ 15B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord MSCs. Formulated as a lyophilized powder, it provides 15 billion exosomes in a 5 mL vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 15 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 22, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('exolyra-exolyra-20b', 'exosome', 'Exolyra™', 'Exolyra™ 20B', 'Exolyra™ 20B | 5 mL', 'Exolyra™ 20B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord MSCs. Formulated as a lyophilized powder, it provides 20 billion exosomes in a 5 mL vial and is designed for professional aesthetic and regenerative applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 20 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 23, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('derived-for-brain', 'exosome', 'Derived', 'For Brain', 'Derived™ hUC-MSCs Exosomes | 10B | 5 mL', 'Derived™ hUC-MSCs Exosomes | 10B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Formulated as a lyophilized powder, it provides 10 billion exosomes in a 5 mL vial and is designed for professional brain-focused and regenerative applications. ________________', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 10 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 24, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('derived-for-lungs', 'exosome', 'Derived', 'For Lungs', 'Derived™ hUC-MSCs Exosomes | 10B | 5 mL', 'Derived™ hUC-MSCs Exosomes | 10B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Formulated as a lyophilized powder, it provides 10 billion exosomes in a 5 mL vial and is developed for professional applications.', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 10 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 25, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('derived-for-bones', 'exosome', 'Derived', 'For Bones', 'Derived™ hUC-MSCs Exosomes | 10B | 5 mL', 'Derived™ hUC-MSCs Exosomes | 10B | 5 mL is a professional exosome preparation derived from Human Umbilical Cord Mesenchymal Stem Cells (hUC-MSCs). Formulated as a lyophilized powder, it provides 10 billion exosomes in a 5 mL vial and is designed for professional bone-focused and regenerative applications. ________________', '["Source: Human Umbilical Cord MSCs", "Exosome Content: 10 Billion Exosomes", "Formulation: Lyophilized Powder", "Volume: 5 mL", "Format: Single-vial preparation"]'::jsonb, '', 26, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('15-mg-1-ml', 'dermal-fillers', '15 mg', '1 mL', 'Small-Molecular Hyaluronic Acid 15 mg | 1 mL', 'Small-Molecular Hyaluronic Acid 15 mg | 1 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a smooth, refined HA gel profile. Its small-molecular HA composition is intended to provide hydration, tissue integration, and soft-volume enhancement when administered by qualified aesthetic professionals.', '["Small-molecular hyaluronic acid formulation", "15 mg HA in a 1 mL pre-filled syringe", "Designed for smooth and controlled aesthetic application", "Supports skin hydration and soft-tissue enhancement", "Convenient ready-to-use syringe presentation"]'::jsonb, '', 0, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('15-mg-2-ml', 'dermal-fillers', '15 mg', '2 mL', 'Small-Molecular Hyaluronic Acid 15 mg | 2 mL', 'Small-Molecular Hyaluronic Acid 15 mg | 2 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a smooth, refined HA gel profile. The formulation contains 15 mg of Small-Molecular Hyaluronic Acid in a 2 mL presentation, supporting hydration, tissue integration, and soft-tissue enhancement when administered by qualified aesthetic professionals.', '["Small-molecular hyaluronic acid formulation", "15 mg HA in 2 mL", "Designed for smooth and controlled aesthetic application", "Supports skin hydration and soft-tissue enhancement", "Ready-to-use syringe presentation"]'::jsonb, '', 1, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('18-mg-1-ml', 'dermal-fillers', '18 mg', '1 mL', 'Small-Molecular Hyaluronic Acid 18 mg | 1 mL', 'Small-Molecular Hyaluronic Acid 18 mg | 1 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a smooth, refined HA gel profile. The formulation contains 18 mg of Small-Molecular Hyaluronic Acid in a 1 mL presentation, supporting hydration, tissue integration, and soft-tissue enhancement when administered by qualified aesthetic professionals.', '["Small-molecular hyaluronic acid formulation", "18 mg HA in 1 mL", "Designed for smooth and controlled aesthetic application", "Supports skin hydration and soft-tissue enhancement", "Ready-to-use syringe presentation"]'::jsonb, '', 2, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('18-mg-2-ml', 'dermal-fillers', '18 mg', '2 mL', 'Small-Molecular Hyaluronic Acid 18 mg | 2 mL', 'Small-Molecular Hyaluronic Acid 18 mg | 2 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a smooth, refined HA gel profile. The formulation contains 18 mg of Small-Molecular Hyaluronic Acid in a 2 mL presentation, supporting hydration, tissue integration, and soft-tissue enhancement when administered by qualified aesthetic professionals.', '["Small-molecular hyaluronic acid formulation", "18 mg HA in 2 mL", "Designed for smooth and controlled aesthetic application", "Supports skin hydration and soft-tissue enhancement", "Ready-to-use syringe presentation"]'::jsonb, '', 3, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('20-mg-1-ml', 'dermal-fillers', '20 mg', '1 mL', 'Small-Molecular Hyaluronic Acid 20 mg | 1 mL', 'Small-Molecular Hyaluronic Acid 20 mg | 1 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a smooth, refined HA gel profile. The formulation contains 20 mg of Small-Molecular Hyaluronic Acid in a 1 mL presentation, supporting hydration, tissue integration, and soft-tissue enhancement when administered by qualified aesthetic professionals.', '["Small-molecular hyaluronic acid formulation", "20 mg HA in 1 mL", "Designed for smooth and controlled aesthetic application", "Supports skin hydration and soft-tissue enhancement", "Ready-to-use syringe presentation"]'::jsonb, '', 4, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('20-mg-2-ml', 'dermal-fillers', '20 mg', '2 mL', 'Small-Molecular Hyaluronic Acid 20 mg | 2 mL', 'Small-Molecular Hyaluronic Acid 20 mg | 2 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a smooth, refined HA gel profile. The formulation contains 20 mg of Small-Molecular Hyaluronic Acid in a 2 mL presentation, supporting hydration, tissue integration, and soft-tissue enhancement when administered by qualified aesthetic professionals.', '["Small-molecular hyaluronic acid formulation", "20 mg HA in 2 mL", "Designed for smooth and controlled aesthetic application", "Supports skin hydration and soft-tissue enhancement", "Ready-to-use syringe presentation"]'::jsonb, '', 5, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('24-mg-1-ml', 'dermal-fillers', '24 mg', '1 mL', 'Large-Molecular Hyaluronic Acid 24 mg | 1 mL', 'Large-Molecular Hyaluronic Acid 24 mg | 1 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a more substantial HA gel profile. The formulation contains 24 mg of Large-Molecular Hyaluronic Acid in a 1 mL presentation, supporting tissue hydration, structural support, and aesthetic volume enhancement when administered by qualified aesthetic professionals.', '["Large-molecular hyaluronic acid formulation", "24 mg HA in 1 mL", "Designed for controlled aesthetic application", "Supports hydration and structural tissue enhancement", "Suitable for applications requiring a more substantial HA profile"]'::jsonb, '', 6, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('24-mg-2-ml', 'dermal-fillers', '24 mg', '2 mL', 'Large-Molecular Hyaluronic Acid 24 mg | 2 mL', 'Large-Molecular Hyaluronic Acid 24 mg | 2 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a more substantial HA gel profile. The formulation contains 24 mg of Large-Molecular Hyaluronic Acid in a 2 mL presentation, supporting tissue hydration, structural support, and aesthetic volume enhancement when administered by qualified aesthetic professionals.', '["Large-molecular hyaluronic acid formulation", "24 mg HA in 2 mL", "Designed for controlled aesthetic application", "Supports hydration and structural tissue enhancement", "Suitable for applications requiring a more substantial HA profile"]'::jsonb, '', 7, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('26-mg-1-ml', 'dermal-fillers', '26 mg', '1 mL', 'Large-Molecular Hyaluronic Acid 26 mg | 1 mL', 'Large-Molecular Hyaluronic Acid 26 mg | 1 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a more substantial HA gel profile. The formulation contains 26 mg of Large-Molecular Hyaluronic Acid in a 1 mL presentation, supporting tissue hydration, structural support, and aesthetic volume enhancement when administered by qualified aesthetic professionals.', '["Large-molecular hyaluronic acid formulation", "26 mg HA in 1 mL", "Designed for controlled aesthetic application", "Supports hydration and structural tissue enhancement", "Suitable for applications requiring a more substantial HA profile"]'::jsonb, '', 8, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('26-mg-2-ml', 'dermal-fillers', '26 mg', '2 mL', 'Large-Molecular Hyaluronic Acid 26 mg | 2 mL', 'Large-Molecular Hyaluronic Acid 26 mg | 2 mL is a professionally formulated hyaluronic acid injectable designed for aesthetic applications requiring a more substantial HA gel profile. The formulation contains 26 mg of Large-Molecular Hyaluronic Acid in a 2 mL presentation, supporting tissue hydration, structural support, and aesthetic volume enhancement when administered by qualified aesthetic professionals.', '["Large-molecular hyaluronic acid formulation", "26 mg HA in 2 mL", "Designed for controlled aesthetic application", "Supports hydration and structural tissue enhancement", "Suitable for applications requiring a more substantial HA profile"]'::jsonb, '', 9, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('hyalique-x-soft-filler-1-ml', 'dermal-fillers', 'HYALIQUE-X (Soft Filler)', '1 mL', 'HYALIQUE-X™ 18 mg | 1 mL', 'HYALIQUE-X™ 18 mg | 1 mL is a Small Molecular Hyaluronic Acid dermal filler designed for professional aesthetic applications, particularly lip enhancement and fine-line correction.', '["Small Molecular HA — formulated for soft-filler aesthetic applications.", "18 mg / 1 mL — defined HA concentration in a 1 mL presentation.", "Soft Filler Profile — suitable for applications requiring a softer filler characteristic.", "Targeted Aesthetic Use — positioned for lip enhancement and fine-line applications.", "Lip enhancement"]'::jsonb, '', 10, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('hyalique-x-soft-filler-2-ml', 'dermal-fillers', 'HYALIQUE-X (Soft Filler)', '2 mL', 'HYALIQUE-X™ 18 mg | 2 mL', 'HYALIQUE-X™ 18 mg | 2 mL is a Small Molecular Hyaluronic Acid dermal filler designed for professional aesthetic applications focused on mid-face enhancement and volume restoration.', '["Small Molecular HA — formulated for soft-filler aesthetic applications.", "18 mg / 2 mL — defined HA concentration in a 2 mL presentation.", "Soft Filler Profile — designed for applications requiring a softer filler characteristic.", "Mid-Face Application — suitable for volume restoration and facial enhancement.", "Mid-face enhancement"]'::jsonb, '', 11, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('hyalique-x-hard-filler-1-ml', 'dermal-fillers', 'HYALIQUE-X (Hard Filler)', '1 mL', 'HYALIQUE-X™ 24 mg | 1 mL', 'HYALIQUE-X™ 24 mg | 1 mL is a Large Molecular Hyaluronic Acid dermal filler designed for professional aesthetic applications requiring structural support and defined contouring, particularly for the chin, nose and jawline.', '["Large Molecular HA — formulated for structural aesthetic applications.", "24 mg / 1 mL — defined HA concentration in a 1 mL presentation.", "Hard Filler Profile — designed for applications requiring enhanced structural support.", "Targeted Contouring — suitable for chin, nose and jawline applications.", "Chin contouring"]'::jsonb, '', 12, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('hyalique-x-hard-filler-2-ml', 'dermal-fillers', 'HYALIQUE-X (Hard Filler)', '2 mL', 'HYALIQUE-X™ 24 mg | 2 mL', 'HYALIQUE-X™ 24 mg | 2 mL is a Large Molecular Hyaluronic Acid dermal filler designed for professional aesthetic applications focused on facial contouring and structural volume support.', '["Large Molecular HA — formulated for structural aesthetic applications.", "24 mg / 2 mL — defined HA concentration in a 2 mL presentation.", "Hard Filler Profile — designed for applications requiring enhanced structural support.", "Facial Contouring — suitable for defined facial contouring applications.", "Facial contouring"]'::jsonb, '', 13, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('luminelle-luminelle-soft', 'dermal-fillers', 'Luminelle™', 'Luminelle™ Soft', 'Luminelle™ Soft 15 mg | 1 mL', 'Luminelle™ Soft 15 mg | 1 mL is a professional cross-linked Hyaluronic Acid dermal filler designed for aesthetic applications requiring natural volume, refined contour and smooth tissue integration.', '["Luminelle™ Soft is designed for professional aesthetic protocols supporting:"]'::jsonb, '', 14, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('luminelle-luminelle-volume', 'dermal-fillers', 'Luminelle™', 'Luminelle™ Volume', 'Luminelle™ Volume 20 mg | 1 mL', 'Luminelle™ Volume 20 mg | 1 mL is a professional cross-linked Hyaluronic Acid dermal filler designed for aesthetic applications requiring structural support, natural contouring and volume enhancement.', '["Luminelle™ Volume is designed for professional aesthetic protocols supporting:"]'::jsonb, '', 15, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('luminelle-luminelle-contour', 'dermal-fillers', 'Luminelle™', 'Luminelle™ Contour', 'Luminelle™ Contour 26 mg | 1 mL', 'Luminelle™ Contour 26 mg | 1 mL is a professional cross-linked Hyaluronic Acid dermal filler designed for aesthetic applications requiring enhanced structural support, defined shape and natural facial contouring.', '["Luminelle™ Contour is designed for professional aesthetic protocols supporting:"]'::jsonb, '', 16, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('blue-copper-pepetide-100-mg', 'peptide-bio-remodeling', 'Blue Copper Pepetide', '100 mg', 'Blue Copper Peptide 100 mg', 'Blue Copper Peptide 100 mg is a concentrated GHK-Cu (Copper Tripeptide-1) formulation presented as a lyophilized powder for professional aesthetic, dermatological, and regenerative applications. GHK-Cu is a naturally occurring copper-binding peptide studied for its role in skin conditioning, extracellular matrix support, and tissue-regenerative processes.', '["100 mg concentrated GHK-Cu", "Lyophilized powder presentation", "High-purity copper peptide active", "Designed for professional formulation and application", "Suitable for aesthetic and dermatological protocols"]'::jsonb, '', 0, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('blue-copper-pepetide-200-mg', 'peptide-bio-remodeling', 'Blue Copper Pepetide', '200 mg', 'Blue Copper Peptide 200 mg', 'Blue Copper Peptide 200 mg is a concentrated GHK-Cu (Copper Tripeptide-1) formulation presented as a lyophilized powder for professional aesthetic, dermatological, and regenerative applications. GHK-Cu is a naturally occurring copper-binding peptide studied for its role in skin conditioning, extracellular matrix support, and tissue-regenerative processes.', '["200 mg concentrated GHK-Cu", "Lyophilized powder presentation", "High-purity copper peptide active", "Designed for professional formulation and application", "Suitable for aesthetic and dermatological protocols"]'::jsonb, '', 1, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('blue-copper-pepetide-300-mg', 'peptide-bio-remodeling', 'Blue Copper Pepetide', '300 mg', 'Blue Copper Peptide 300 mg', 'Blue Copper Peptide 300 mg is a concentrated GHK-Cu (Copper Tripeptide-1) formulation presented as a lyophilized powder for professional aesthetic, dermatological, and regenerative applications. GHK-Cu is a naturally occurring copper-binding peptide studied for its role in skin conditioning, extracellular matrix support, and tissue-regenerative processes.', '["300 mg concentrated GHK-Cu", "Lyophilized powder presentation", "High-purity copper peptide active", "Designed for professional formulation and application", "Suitable for aesthetic and dermatological protocols"]'::jsonb, '', 2, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('ha-diluent-10-ml', 'peptide-bio-remodeling', 'HA Diluent', '10 mL', 'HA Diluent 10 mL', 'HA Diluent 10 mL is a sterile liquid Non-Crosslinked Hyaluronic Acid formulation designed as a supporting diluent component for professional aesthetic and dermatological preparations. It provides a hydrating hyaluronic acid base intended to facilitate the appropriate preparation and delivery of compatible peptide-based formulations.', '["10 mL liquid HA diluent", "Contains Non-Crosslinked Hyaluronic Acid", "Designed as a supporting component for professional formulations", "Provides a hydrating HA-based medium", "Suitable for compatible peptide-based preparations"]'::jsonb, '', 3, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('bluevive-booster-300-mg-ha-diluent-10ml', 'peptide-bio-remodeling', 'BlueVive Booster', '300 mg+ HA Diluent 10mL', 'BLUEVIVE™', 'BLUEVIVE™ is an advanced peptide bio-remodeling booster developed around a copper-activated regenerative peptide complex, combining GHK-Cu (Blue Copper Peptide) with Non-Crosslinked Hyaluronic Acid. The formulation is designed to provide a professional peptide-based approach to skin conditioning, extracellular matrix support, hydration, and regenerative skin-quality protocols. (EverCeutical)', '["Advanced peptide bio-remodeling formulation", "300 mg professional booster system", "Copper-activated regenerative peptide complex", "Contains GHK-Cu (Blue Copper Peptide)", "Supported by Non-Crosslinked Hyaluronic Acid"]'::jsonb, '', 4, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('cuvera-x-cuverax-100', 'peptide-bio-remodeling', 'Cuvera-X™', 'CuveraX™ 100', 'CuveraX™ 100 mg', 'CuveraX™ 100 mg is a concentrated Copper Tripeptide (GHK-Cu) formulation presented as a lyophilized powder for professional aesthetic, dermatological, and regenerative applications. GHK-Cu is a copper-binding peptide studied for its role in skin conditioning, extracellular matrix support, and regenerative processes. The lyophilized format provides a concentrated presentation designed for professional formulation and application protocols.', '["100 mg concentrated Copper Tripeptide (GHK-Cu)", "Lyophilized powder presentation", "High-purity copper peptide active", "Designed for professional formulation and application", "Suitable for aesthetic and dermatological protocols"]'::jsonb, '', 5, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('cuvera-x-cuverax-200', 'peptide-bio-remodeling', 'Cuvera-X™', 'CuveraX™ 200', 'CuveraX™ 200 mg', 'CuveraX™ 200 mg is a concentrated Copper Tripeptide (GHK-Cu) formulation presented as a lyophilized powder for professional aesthetic, dermatological, and regenerative applications. GHK-Cu is a copper-binding peptide studied for its role in skin conditioning, extracellular matrix support, and regenerative processes. The lyophilized format provides a concentrated presentation designed for professional formulation and application protocols.', '["200 mg concentrated Copper Tripeptide (GHK-Cu)", "Lyophilized powder presentation", "High-purity copper peptide active", "Designed for professional formulation and application", "Suitable for aesthetic and dermatological protocols"]'::jsonb, '', 6, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botulinum-toxin-type-a-50-u', 'botulinum-toxin', '', '50 U', 'Botulinum Toxin Type A 50 U', 'Botulinum Toxin Type A 50 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 50 Unit vial, the product is designed for professional preparation and administration by qualified healthcare professionals.', '["50 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 0, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botulinum-toxin-type-a-100-u', 'botulinum-toxin', '', '100 U', 'Botulinum Toxin Type A 100 U', 'Botulinum Toxin Type A 100 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 100 Unit vial, the product is designed for professional preparation and administration by qualified healthcare professionals.', '["100 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 1, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botulinum-toxin-type-a-200-u', 'botulinum-toxin', '', '200 U', 'Botulinum Toxin Type A 200 U', 'Botulinum Toxin Type A 200 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 200 Unit vial, the product is designed for professional preparation and administration by qualified healthcare professionals.', '["200 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 2, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botulinum-toxin-type-a-300-u', 'botulinum-toxin', '', '300 U', 'Botulinum Toxin Type A 300 U', 'Botulinum Toxin Type A 300 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 300 Unit vial, the product is designed for professional preparation and administration by qualified healthcare professionals.', '["300 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 3, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botulinum-toxin-type-a-500-u', 'botulinum-toxin', '', '500 U', 'Botulinum Toxin Type A 500 U', 'Botulinum Toxin Type A 500 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 500 Unit vial, the product is designed for professional preparation and administration by qualified healthcare professionals.', '["500 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 4, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botivex-botivex-lite', 'botulinum-toxin', 'Botivex', 'Botivex Lite', 'Botivex™ Lite 100 U', 'Botivex™ Lite 100 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 100 Unit vial, Botivex™ Lite is designed for professional preparation and administration by qualified healthcare professionals.', '["100 Units standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 5, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botivex-botivex-core', 'botulinum-toxin', 'Botivex', 'Botivex Core', 'Botivex™ Core 200 U', 'Botivex™ Core 200 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 200 Unit vial, Botivex™ Core is designed for professional preparation and administration by qualified healthcare professionals.', '["200 Units standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 6, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('botivex-botivex-plus', 'botulinum-toxin', 'Botivex', 'Botivex Plus', 'Botivex™ Plus 500 U', 'Botivex™ Plus 500 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 500 Unit vial, Botivex™ Plus is designed for professional preparation and administration by qualified healthcare professionals.', '["500 Units standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 7, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('toxexa-toxexa-100', 'botulinum-toxin', 'Toxexa', 'Toxexa 100', 'Toxexa™ 100 U', 'Toxexa™ 100 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 100 Unit vial, Toxexa™ is designed for professional preparation and administration by qualified healthcare professionals.', '["100 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 8, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('toxexa-toxexa-200', 'botulinum-toxin', 'Toxexa', 'Toxexa 200', 'Toxexa™ 200 U', 'Toxexa™ 200 U is a professional-grade Botulinum Neurotoxin Type A (BoNT/A) formulation developed for controlled neuromodulation in aesthetic and clinical applications. Presented in a 200 Unit vial, Toxexa™ is designed for professional preparation and administration by qualified healthcare professionals.', '["200 U standardized presentation", "Botulinum Neurotoxin Type A (BoNT/A)", "Professional-grade formulation", "Designed for controlled neuromodulation", "Convenient vial presentation"]'::jsonb, '', 9, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('pdrn-solutions-pdrn-2-mg-ml', 'pdrn-pn', 'PDRN Solutions', 'PDRN 2 mg/mL', 'PDRN 2 mg/mL', 'PDRN 2 mg/mL is a purified polynucleotide-based solution designed for professional aesthetic and regenerative applications. Formulated with 2 mg/mL of PDRN, it provides a concentrated polynucleotide platform intended to support skin-quality enhancement, tissue recovery, and regenerative-focused protocols. Its purified formulation makes it suitable for integration into professional treatment protocols where controlled delivery of polynucleotide actives is required.', '["2 mg/mL PDRN concentration", "Purified polynucleotide-based formulation", "Designed for professional aesthetic applications", "Supports regenerative-focused treatment protocols", "Suitable for skin-quality and tissue-repair applications"]'::jsonb, '', 0, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('pdrn-solutions-pdrn-5-mg-ml', 'pdrn-pn', 'PDRN Solutions', 'PDRN 5 mg/mL', 'PDRN 5 mg/mL', 'PDRN 5 mg/mL is a concentrated polynucleotide-based solution developed for professional aesthetic and regenerative applications. Formulated with 5 mg/mL of PDRN, it provides a higher-concentration polynucleotide platform designed to support skin regeneration, tissue recovery, and skin-quality enhancement. Its concentrated formulation is suitable for integration into professional treatment protocols requiring a higher level of PDRN activity.', '["5 mg/mL PDRN concentration", "Concentrated polynucleotide-based formulation", "Designed for professional aesthetic applications", "Supports regenerative-focused treatment protocols", "Suitable for skin-quality and tissue-recovery applications"]'::jsonb, '', 1, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('pn-solutions-pn-15-mg-ml', 'pdrn-pn', 'PN Solutions', 'PN 15 mg/mL', 'PN 15 mg/mL', 'PN 15 mg/mL is a concentrated polynucleotide-based solution developed for professional aesthetic and regenerative applications. Formulated with 15 mg/mL of polynucleotides (PN), it provides a high-concentration regenerative platform designed to support skin quality, tissue recovery, and structural skin rejuvenation. The formulation is intended for integration into professional treatment protocols requiring a concentrated PN-based solution.', '["15 mg/mL polynucleotide concentration", "High-concentration PN formulation", "Designed for professional aesthetic applications", "Supports regenerative-focused treatment protocols", "Suitable for skin-quality and tissue-recovery applications"]'::jsonb, '', 2, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('pn-solutions-pn-20-mg-ml', 'pdrn-pn', 'PN Solutions', 'PN 20 mg/mL', 'PN 20 mg/mL', 'PN 20 mg/mL is a high-concentration polynucleotide-based solution developed for professional aesthetic and regenerative applications. Formulated with 20 mg/mL of polynucleotides (PN), it provides a concentrated regenerative platform designed to support skin quality, tissue recovery, and skin rejuvenation. The formulation is intended for integration into professional treatment protocols requiring a high-concentration PN-based solution.', '["20 mg/mL polynucleotide concentration", "High-concentration PN formulation", "Designed for professional aesthetic applications", "Supports regenerative-focused treatment protocols", "Suitable for skin-quality and tissue-recovery applications"]'::jsonb, '', 3, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('pdrn-ha-solutions-pdrn-2-mg-ml-ha-20-mg-ml', 'pdrn-pn', 'PDRN + HA Solutions', 'PDRN  2 mg/mL + HA 20 mg/mL', 'PDRN 2 mg/mL + HA 20 mg/mL', 'PDRN 2 mg/mL + HA 20 mg/mL is a combined polynucleotide and hyaluronic acid formulation developed for professional aesthetic and regenerative applications. It combines PDRN at 2 mg/mL with hyaluronic acid (HA) at 20 mg/mL, providing complementary active components for skin-quality and rejuvenation-focused protocols. The formulation is designed to support professional applications where both polynucleotide-based regenerative activity and HA-based hydration and viscoelastic support are desired.', '["PDRN 2 mg/mL + HA 20 mg/mL", "Dual-active polynucleotide and hyaluronic acid formulation", "Combines regenerative-focused PDRN with HA-based hydration support", "Designed for professional aesthetic applications", "Suitable for skin-quality and rejuvenation-focused protocols"]'::jsonb, '', 4, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('pdrn-ha-solutions-pdrn-5-mg-ml-ha-15-mg-ml', 'pdrn-pn', 'PDRN + HA Solutions', 'PDRN 5 mg/mL + HA 15 mg/mL', 'PDRN 5 mg/mL + HA 15 mg/mL', 'PDRN 5 mg/mL + HA 15 mg/mL is a combined polynucleotide and hyaluronic acid formulation developed for professional aesthetic and regenerative applications. It combines PDRN at 5 mg/mL with hyaluronic acid (HA) at 15 mg/mL, providing complementary active components for skin regeneration, hydration, and skin-quality enhancement. The formulation is designed for professional protocols where a higher concentration of PDRN is combined with HA to provide regenerative and hydration-focused support.', '["PDRN 5 mg/mL + HA 15 mg/mL", "Concentrated polynucleotide and HA formulation", "Combines regenerative-focused PDRN with HA-based hydration support", "Designed for professional aesthetic applications", "Suitable for skin-quality and rejuvenation-focused protocols"]'::jsonb, '', 5, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('nucelvia-nucelvia-repair-2', 'pdrn-pn', 'Nucelvia', 'Nucelvia Repair  2', 'Nucelvia™ Repair 2', 'Nucelvia™ Repair 2 is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and Nucelvia™. Formulated at 2 mg/mL PDRN, it is designed for professional aesthetic protocols focused on skin rejuvenation, tissue repair, and cellular renewal. The formulation provides a purified PDRN-based platform intended to support regenerative processes and overall skin-quality improvement.', '["2 mg/mL PDRN concentration", "Polydeoxyribonucleotide-based regenerative formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin rejuvenation and tissue-recovery protocols"]'::jsonb, '', 6, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('nucelvia-nucelvia-repair-5', 'pdrn-pn', 'Nucelvia', 'Nucelvia Repair  5', 'Nucelvia™ Repair 5', 'Nucelvia™ Repair 5 is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and Nucelvia™. Formulated at 5 mg/mL PDRN, it provides a higher-concentration polynucleotide platform designed for professional aesthetic protocols focused on skin rejuvenation, tissue repair, and cellular renewal. The formulation is designed to support regenerative-focused treatment approaches while contributing to overall skin-quality enhancement.', '["5 mg/mL PDRN concentration", "High-concentration Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin rejuvenation and tissue-recovery protocols"]'::jsonb, '', 7, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('nucelvia-nucelvia-regen-15', 'pdrn-pn', 'Nucelvia', 'Nucelvia Regen  15', 'Nucelvia™ Regen 15', 'Nucelvia™ Regen 15 is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and Nucelvia™. Formulated at 15 mg/mL PDRN, it provides a high-concentration polynucleotide platform designed for professional aesthetic and regenerative applications. The formulation is intended to support skin regeneration, tissue repair, cellular renewal, and overall skin-quality enhancement within professional treatment protocols.', '["15 mg/mL PDRN concentration", "High-concentration Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin regeneration and tissue-recovery protocols"]'::jsonb, '', 8, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('nucelvia-nucelvia-regen-20', 'pdrn-pn', 'Nucelvia', 'Nucelvia Regen 20', 'Nucelvia™ Regen 20', 'Nucelvia™ Regen 20 is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and Nucelvia™. Formulated at 20 mg/mL PDRN, it provides a high-concentration polynucleotide platform designed for professional aesthetic and regenerative applications. The formulation is intended to support skin regeneration, tissue repair, cellular renewal, and overall skin-quality enhancement within professional treatment protocols.', '["20 mg/mL PDRN concentration", "High-concentration Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin regeneration and tissue-recovery protocols"]'::jsonb, '', 9, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('nucelvia-nucelvia-fusion', 'pdrn-pn', 'Nucelvia', 'Nucelvia Fusion', 'Nucelvia™ Fusion', 'Nucelvia™ Fusion is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and Nucelvia™. Designed as an Advanced Regeneration Complex, it provides a PDRN-based platform for professional aesthetic and regenerative applications. The formulation is intended to support skin regeneration, tissue repair, cellular renewal, and overall skin-quality enhancement within professional treatment protocols.', '["Advanced Regeneration Complex", "Polydeoxyribonucleotide (PDRN)-based formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin regeneration and tissue-recovery protocols"]'::jsonb, '', 10, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('polynexa-polynexa-nucleorx', 'pdrn-pn', 'Polynexa', 'POLYNEXA NucleoRx', 'POLYNEXA™ NucleoRx', 'POLYNEXA™ NucleoRx is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and POLYNEXA™. Formulated at 5 mg/mL PDRN, it is designed for professional aesthetic and regenerative applications focused on cellular repair, tissue regeneration, and skin revitalization. The formulation provides a concentrated PDRN-based platform intended to support regenerative-focused treatment protocols and overall skin-quality enhancement.', '["5 mg/mL PDRN concentration", "Concentrated Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports cellular repair and tissue-regeneration protocols"]'::jsonb, '', 11, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('polynexa-polynexa-polyrx', 'pdrn-pn', 'Polynexa', 'POLYNEXA PolyRx', 'POLYNEXA™ PolyRx', 'POLYNEXA™ PolyRx is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and POLYNEXA™. Formulated at 5 mg/mL PDRN, it is designed for professional aesthetic and regenerative applications focused on cellular repair, tissue regeneration, and skin revitalization. The formulation provides a concentrated PDRN-based platform intended to support regenerative-focused treatment protocols and overall skin-quality enhancement.', '["5 mg/mL PDRN concentration", "Concentrated Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports cellular repair and tissue-regeneration protocols"]'::jsonb, '', 12, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('polynexa-polynexa-nucleoprime', 'pdrn-pn', 'Polynexa', 'POLYNEXA NucleoPrime', 'POLYNEXA™ NucleoPrime', 'POLYNEXA™ NucleoPrime is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and POLYNEXA™. Formulated at 5 mg/mL PDRN, it is designed for professional aesthetic and regenerative applications focused on cellular repair, tissue regeneration, and skin revitalization. The formulation provides a concentrated PDRN-based platform intended to support regenerative-focused treatment protocols and overall skin-quality enhancement.', '["5 mg/mL PDRN concentration", "Concentrated Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports cellular repair and tissue-regeneration protocols"]'::jsonb, '', 13, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('dnavia-dnavia-pdrn-2', 'pdrn-pn', 'DNAVIA', 'DNAVIA™ PDRN 2', 'DNAVIA™ PDRN 2', 'DNAVIA™ PDRN 2 is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and DNAVIA™. Formulated with 2 mg/mL PDRN, it is designed for professional aesthetic and regenerative applications focused on skin rejuvenation, tissue recovery, and cellular renewal. The formulation provides a purified PDRN-based platform intended to support regenerative-focused treatment protocols and overall skin-quality enhancement.', '["2 mg/mL PDRN concentration", "Purified Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin-rejuvenation and tissue-recovery protocols"]'::jsonb, '', 14, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('dnavia-dnavia-pdrn-5', 'pdrn-pn', 'DNAVIA', 'DNAVIA™ PDRN 5', 'DNAVIA™ PDRN 5', 'DNAVIA™ PDRN 5 is a professional-grade Polydeoxyribonucleotide (PDRN) solution developed in official collaboration between Vesco Science Co., Ltd. and DNAVIA™. Formulated with 5 mg/mL PDRN, it provides a concentrated polynucleotide platform designed for professional aesthetic and regenerative applications focused on skin rejuvenation, tissue recovery, and cellular renewal. The formulation is designed to support regenerative-focused treatment protocols and overall skin-quality enhancement.', '["5 mg/mL PDRN concentration", "Concentrated Polydeoxyribonucleotide formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin-rejuvenation and tissue-recovery protocols"]'::jsonb, '', 15, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('dnavia-dnavia-pn-15', 'pdrn-pn', 'DNAVIA', 'DNAVIA™ PN 15', 'DNAVIA™ PN 15', 'DNAVIA™ PN 15 is a professional-grade Polynucleotide (PN) solution developed in official collaboration between Vesco Science Co., Ltd. and DNAVIA™. Formulated at 15 mg/mL polynucleotides, it is designed for professional aesthetic and regenerative applications focused on skin revitalization, tissue recovery, and skin-quality enhancement. The formulation provides a concentrated polynucleotide platform intended to support regenerative-focused treatment protocols and overall skin renewal.', '["15 mg/mL Polynucleotide concentration", "High-concentration PN formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin revitalization and tissue-recovery protocols"]'::jsonb, '', 16, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();
insert into public.products (slug, category, group_name, label, name, detail, specs, image_url, sort_order, published)
values ('dnavia-dnavia-pn-20', 'pdrn-pn', 'DNAVIA', 'DNAVIA™ PN 20', 'DNAVIA™ PN 20', 'DNAVIA™ PN 20 is a professional-grade Polynucleotide (PN) solution developed in official collaboration between Vesco Science Co., Ltd. and DNAVIA™. Formulated at 20 mg/mL polynucleotides, it provides a high-concentration regenerative platform designed for professional aesthetic and regenerative applications focused on skin revitalization, tissue recovery, and skin-quality enhancement. The formulation is intended to support regenerative-focused treatment protocols requiring a concentrated PN-based solution.', '["20 mg/mL Polynucleotide concentration", "High-concentration PN formulation", "5 mL sterile solution", "Designed for professional aesthetic applications", "Supports skin revitalization and tissue-recovery protocols"]'::jsonb, '', 17, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  image_url = case when excluded.image_url <> '' then excluded.image_url else public.products.image_url end,
  updated_at = now();

-- TOTAL PRODUCTS SEEDED: 79

-- ============================================================
-- 6. SEED ARTICLES / BLOGS DATA (10 Real Science Insights Articles)
-- ============================================================

insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('what-are-exosomes', 'Exosome Science', 'What Are Exosomes? Understanding Extracellular Vesicles and Their Biological Role', 'Cells communicate by releasing extracellular vesicles that carry proteins, lipids and nucleic acids. This article explains what exosomes are, how they form, and why their biology matters in regenerative science.', '', '[{"heading": "What Are Exosomes?", "body": "Cells do not communicate only through direct physical contact or soluble signaling molecules. They also communicate by releasing extracellular vesicles (EVs)—small, membrane-bound particles that can transport biologically active molecules from one cell to another.\n\nAmong the different types of extracellular vesicles, exosomes have attracted substantial scientific interest because of their role in intercellular communication and their ability to carry proteins, lipids and nucleic acids. Research into EVs has expanded rapidly across molecular biology, regenerative medicine, diagnostics, drug delivery and other areas of biomedical science.\n\nImportantly, the terminology surrounding EVs has evolved. According to the MISEV2023 guidelines, extracellular vesicles are lipid-bilayer-delimited particles that cannot replicate independently. The term exosome should ideally be reserved for vesicles whose endosomal origin has been experimentally demonstrated. When the exact biogenesis pathway cannot be established, researchers are encouraged to use broader terminology such as small extracellular vesicles (sEVs).\n\nThis distinction is important because EV preparations can contain heterogeneous populations of vesicles and other extracellular particles."}, {"heading": "Understanding Extracellular Vesicles", "body": "Extracellular vesicles are membrane-bound particles released by cells into the extracellular environment. They are found in biological fluids and tissues and participate in communication between cells.\n\nEVs are not simply cellular waste particles. They can contain a biologically complex cargo reflecting aspects of the cell from which they originated. This cargo may include:\n• Proteins\n• Lipids\n• Messenger RNA (mRNA)\n• MicroRNAs (miRNAs)\n• Other RNA species\n• Metabolites\n• Cell-surface molecules\n\nOnce released, EVs can interact with other cells through several mechanisms, including receptor-mediated interactions, membrane fusion and cellular uptake. These processes can influence the behavior and function of recipient cells."}, {"heading": "Exosomes and Other Extracellular Vesicles", "body": "One of the most important concepts in EV biology is that extracellular vesicles represent a broad and heterogeneous group of particles.\n\nHistorically, researchers commonly described EV populations using terms such as exosomes, microvesicles, ectosomes, and apoptotic bodies. However, modern EV research recognizes that classification based solely on size or presumed origin can be problematic. The current MISEV framework therefore encourages researchers to describe EV populations using measurable characteristics, such as physical properties, molecular markers, source and experimental isolation methods.\n\nIn simplified terms, exosomes are generally discussed as a type of small extracellular vesicle associated with the endosomal pathway, whereas other EV populations can originate through different cellular mechanisms."}, {"heading": "How Are Exosomes Generated?", "body": "The formation of exosomes is closely associated with the endosomal system of the cell.\n\nA simplified model begins when the plasma membrane undergoes endocytosis, creating intracellular compartments known as endosomes. These compartments can mature and develop into multivesicular bodies (MVBs).\n\nWithin an MVB, portions of the endosomal membrane bud inward to form small intraluminal vesicles. When the MVB subsequently fuses with the plasma membrane, these vesicles can be released into the extracellular environment.\n\nThese released vesicles are commonly referred to as exosomes when their endosomal origin has been demonstrated. The process involves complex cellular machinery and molecular sorting mechanisms that influence which molecules become associated with the vesicles."}, {"heading": "What Do Exosomes Carry?", "body": "One of the most scientifically interesting properties of EVs is their molecular cargo.\n\nRather than acting as empty lipid particles, EVs can carry combinations of biological molecules. Their molecular composition can vary depending on the cell type, cellular state and surrounding biological environment.\n\n1. Proteins\nEVs may contain membrane-associated and intravesicular proteins involved in cell signaling, membrane trafficking, adhesion, cellular interactions, and regulation of recipient-cell activity.\n\n2. Lipids\nBecause EVs are surrounded by lipid membranes, lipids are an important structural and functional component of these particles.\n\n3. RNA\nEVs can also transport different RNA species, including mRNA and non-coding RNAs such as microRNAs. These RNA molecules have attracted significant research interest because they can potentially influence gene expression and cellular pathways in recipient cells.\n\nThe composition of EV cargo is not necessarily random. Cellular sorting mechanisms can influence which molecules become enriched within particular vesicle populations."}, {"heading": "How Do Extracellular Vesicles Communicate With Other Cells?", "body": "After release, extracellular vesicles can travel through the extracellular environment and interact with recipient cells.\n\nSeveral mechanisms may contribute to this interaction.\n\nReceptor-Mediated Interaction: Molecules on the surface of an EV can interact with receptors or adhesion molecules on a recipient cell.\n\nEndocytic Uptake: A recipient cell may internalize extracellular vesicles through cellular uptake mechanisms, bringing the vesicle into the cell.\n\nMembrane Fusion: Under certain biological conditions, vesicle and cellular membranes can interact or fuse, potentially allowing cargo to enter the recipient cell.\n\nCargo Delivery: Once internalized or otherwise delivered, EV-associated molecules can participate in signaling pathways within the recipient cell.\n\nThese mechanisms form part of a broader biological communication network through which cells can influence one another without direct cell-to-cell contact."}, {"heading": "Why Is Exosome Biology Important?", "body": "The importance of extracellular vesicles extends beyond basic cell biology.\n\nBecause EVs can carry molecular information from their cells of origin, researchers are investigating their potential roles in several areas.\n\n1. Biomarker Research\nEV-associated molecules can reflect aspects of the physiological or pathological state of their source cells. This has made EVs an area of interest for biomarker discovery and liquid biopsy research. Researchers are investigating EV-associated proteins and nucleic acids as potential indicators of disease processes and cellular changes.\n\n2. Regenerative and Tissue Research\nExtracellular vesicles derived from certain cell types, particularly mesenchymal stromal/stem cell systems, are being investigated for their cell-free biological effects. Rather than transferring an entire living cell, EV-based approaches focus on the molecular signals and cargo associated with vesicles. This has generated significant interest in areas such as tissue repair, immune modulation and regenerative biology. However, much of this field remains under active investigation, and clinical translation requires rigorous characterization and controlled clinical evidence."}, {"heading": "Exosomes in Diagnostics and Biomedical Research", "body": "The molecular cargo of EVs has made them particularly interesting for diagnostic research.\n\nEVs can be detected in biological fluids, and researchers are exploring whether their molecular signatures can provide information about disease states.\n\nResearch has investigated EV-associated biomarkers in areas including: oncology, cardiovascular disease, neurological disorders, inflammatory conditions, metabolic diseases, and infectious diseases.\n\nA major advantage of EV research is that the vesicles can provide a molecular snapshot associated with their cellular source. At the same time, isolating specific EV populations from complex biological samples remains technically challenging."}, {"heading": "The Future of Extracellular Vesicle Research", "body": "Extracellular vesicle research is moving toward increasingly precise characterization of individual EV populations, their molecular cargo and their biological functions.\n\nEmerging research is exploring: more precise EV subpopulation analysis, advanced nanoparticle characterization, molecular profiling of EV cargo, EV-based biomarker platforms, targeted delivery systems, cell-free regenerative strategies, scalable manufacturing technologies, and improved quality-control frameworks.\n\nAs the field advances, the terminology and methodology are also becoming more rigorous. Modern EV science increasingly emphasizes what can be experimentally demonstrated rather than relying solely on assumptions about vesicle origin or function."}]'::jsonb, '[{"phrase": "MISEV2023 guidelines", "url": "https://isevjournals.onlinelibrary.wiley.com/doi/10.1002/jev2.12404"}, {"phrase": "endosomal pathway", "url": "https://pubmed.ncbi.nlm.nih.gov/34012517/"}, {"phrase": "proteins, lipids and nucleic acids", "url": "https://pubmed.ncbi.nlm.nih.gov/33506022/"}, {"phrase": "liquid biopsy", "url": "https://pubmed.ncbi.nlm.nih.gov/42238597/"}, {"phrase": "clinical translation", "url": "https://pubmed.ncbi.nlm.nih.gov/39330928/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('lyophilized-vs-frozen-exosomes', 'Exosome Science', 'Lyophilized vs. Frozen Exosomes: Understanding the Key Differences', 'Two commonly encountered exosome formats — lyophilized and frozen — differ significantly in processing, handling, transportation, and reconstitution. Understanding these differences helps select the right format for your workflow.', '', '[{"body": "Exosomes are nanoscale extracellular vesicles that participate in intercellular communication by carrying a complex biological cargo, including proteins, lipids, nucleic acids, and signaling molecules. As interest in exosome-based research and advanced biological applications continues to grow, the way exosomes are formulated and stored has become an important consideration.\n\nTwo commonly encountered formats are lyophilized (freeze-dried) and frozen exosomes. While both approaches are designed to maintain exosome quality during storage, they differ significantly in processing, handling, transportation, and reconstitution requirements.\n\nUnderstanding these differences helps researchers, laboratories, and biotechnology professionals select the most appropriate format for their specific workflow."}, {"heading": "What Are Lyophilized Exosomes?", "body": "Lyophilization, commonly known as freeze-drying, is a controlled dehydration process in which a biological preparation is frozen and then subjected to reduced pressure to remove water through sublimation.\n\nFor exosome preparations, the process generally involves:\nFreezing → Primary Drying → Secondary Drying → Sealed Dry Storage\n\nThe objective is to reduce water activity while maintaining important characteristics of the extracellular vesicle preparation.\n\nA properly developed lyophilization process may provide advantages in storage convenience, transportation, and formulation stability, particularly when a product is designed for handling without continuous frozen conditions.\n\nHowever, lyophilization is not simply a matter of removing water. Exosomes are structurally delicate biological nanoparticles, and the formulation must be carefully optimized. Parameters such as freezing rate, drying conditions, excipients, residual moisture, and reconstitution conditions can influence particle recovery and biological properties."}, {"heading": "What Are Frozen Exosomes?", "body": "Frozen exosome preparations are maintained in a hydrated state under controlled low-temperature conditions. Depending on the formulation and manufacturer, storage may require temperatures such as −20°C or lower.\n\nThe primary advantage of the frozen format is that the exosomes remain in a liquid formulation without undergoing the dehydration and reconstitution steps associated with lyophilization.\n\nFor research applications, maintaining a controlled frozen environment can help preserve the physical and biochemical characteristics of an exosome preparation. Nevertheless, temperature fluctuations and repeated freeze–thaw cycles should be minimized, as they can potentially affect vesicle integrity, aggregation, particle recovery, and cargo stability.\n\nTherefore, cold-chain management is an important part of frozen exosome handling."}, {"heading": "Lyophilized vs. Frozen Exosomes: Key Differences", "body": "Physical state: Lyophilized = Dry powder / dehydrated preparation. Frozen = Liquid suspension.\n\nWater content: Lyophilized = Significantly reduced. Frozen = Maintained.\n\nStorage: Lyophilized = Designed for dry, controlled storage depending on formulation. Frozen = Requires controlled frozen conditions.\n\nTransportation: Lyophilized = Can simplify logistics when validated for the specified conditions. Frozen = Requires appropriate cold-chain management.\n\nBefore use: Lyophilized = Requires reconstitution. Frozen = Generally ready after controlled thawing.\n\nFreeze–thaw concern: Lyophilized = Reconstitution-related stress must be controlled. Frozen = Repeated freeze–thaw cycles should be avoided.\n\nThe most important point is that format alone does not determine exosome quality. A high-quality exosome preparation requires appropriate manufacturing controls and analytical characterization regardless of whether it is supplied frozen or lyophilized."}, {"heading": "Does Lyophilization Make Exosomes More Stable?", "body": "Not automatically.\n\nLyophilization can offer significant logistical advantages, but the process itself introduces physical stresses that may affect extracellular vesicles. Protective excipients may be incorporated to reduce damage during freezing and drying.\n\nA scientifically validated lyophilized formulation should therefore be evaluated after reconstitution for parameters such as: particle concentration and recovery, particle-size distribution, vesicle morphology, aggregation, relevant exosome-associated markers, protein and cargo integrity, and functional or biological activity, where applicable.\n\nSimilarly, frozen preparations should be evaluated following storage and thawing to confirm that the intended quality attributes remain within specification."}, {"heading": "Which Format Is Better?", "body": "There is no universal winner between lyophilized and frozen exosomes. The appropriate format depends on the intended application, formulation, validated storage conditions, transportation requirements, and quality specifications.\n\nLyophilized format may be advantageous when: simplified storage logistics are important, transportation without continuous deep-freeze conditions is desired, a dry reconstitutable formulation fits the workflow, or the formulation has been specifically validated for long-term stability.\n\nFrozen format may be advantageous when: a ready-to-use liquid preparation is preferred, maintaining the preparation in a hydrated state is desirable, established cold-chain infrastructure is available, or the product has validated frozen-storage stability."}, {"heading": "Quality Matters More Than Format", "body": "For researchers and biotechnology professionals, the critical question should not simply be \"lyophilized or frozen?\" but rather: How well does the manufacturing and storage process preserve the defined quality attributes of the exosome preparation?\n\nReliable exosome products should be supported by appropriate analytical characterization, controlled manufacturing processes, and clearly defined storage and handling conditions.\n\nAt Vesco Science, the development of extracellular vesicle technologies requires attention to the relationship between manufacturing process, formulation, storage conditions, and measurable quality attributes. This approach helps ensure that exosome preparations are characterized scientifically rather than evaluated solely by their physical format."}]'::jsonb, '[{"phrase": "lyophilization / freeze-drying", "url": "https://pubmed.ncbi.nlm.nih.gov/34310074/"}, {"phrase": "freeze–thaw cycles", "url": "https://pubmed.ncbi.nlm.nih.gov/39593194/"}, {"phrase": "storage stability", "url": "https://pubmed.ncbi.nlm.nih.gov/34259095/"}, {"phrase": "trehalose / cryoprotectants", "url": "https://pubmed.ncbi.nlm.nih.gov/30316791/"}, {"phrase": "particle-size distribution & morphology", "url": "https://pubmed.ncbi.nlm.nih.gov/35102719/"}, {"phrase": "NTA / electron microscopy", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('exosome-purification-methods', 'Exosome Science', 'Exosome Purification Methods: TFF, SEC and Ultrafiltration Explained', 'Exosome purification is critical for high-quality extracellular vesicle products. This article explains Tangential Flow Filtration (TFF), Size-Exclusion Chromatography (SEC), and Ultrafiltration — when to use each and how they complement one another.', '', '[{"body": "Exosome purification is a critical step in the development and manufacturing of high-quality extracellular vesicle (EV) products. Because biological starting materials contain proteins, nucleic acids, lipoproteins, cell debris, and other extracellular components, an effective purification strategy is essential for obtaining an enriched exosome preparation while preserving particle integrity and biological characteristics.\n\nAt VESCO Science, understanding the principles behind purification technologies such as Tangential Flow Filtration (TFF), Size-Exclusion Chromatography (SEC), and Ultrafiltration is fundamental to developing consistent and research-grade extracellular vesicle preparations."}, {"heading": "Why Is Exosome Purification Important?", "body": "Exosomes are nanoscale extracellular vesicles, generally within the approximately 30–150 nm range, released by cells and surrounded by a lipid bilayer. During isolation, exosomes are accompanied by numerous other biological components.\n\nThe purification process therefore aims to:\n• Enrich extracellular vesicles from the starting material\n• Reduce soluble protein and unwanted contaminants\n• Remove cellular debris and larger particles\n• Maintain vesicle structure and integrity\n• Improve batch-to-batch consistency\n• Produce material suitable for downstream characterization and research\n\nImportantly, no single purification method is universally optimal. The appropriate approach depends on the source material, desired purity, processing scale, recovery requirements, and intended application."}, {"heading": "1. Ultrafiltration: Membrane-Based Separation", "body": "Ultrafiltration (UF) uses a semipermeable membrane to separate components according to their size and molecular properties. Smaller molecules and soluble components can pass through the membrane, while larger particles such as extracellular vesicles are retained.\n\nA major advantage of ultrafiltration is its relative simplicity and scalability. It can be incorporated into workflows where concentration of extracellular vesicle preparations is required.\n\nHowever, conventional ultrafiltration can expose vesicles to membrane interactions and concentration-related stresses. Therefore, membrane selection, pressure, processing conditions, and recovery optimization are important for maintaining product quality."}, {"heading": "2. Tangential Flow Filtration (TFF): Scalable Processing", "body": "Tangential Flow Filtration (TFF) is a membrane-based technology widely used for scalable bioprocessing.\n\nUnlike conventional dead-end filtration, where the sample flows directly toward the membrane, TFF directs the feed parallel to the membrane surface. A portion of the fluid passes through the membrane as permeate, while larger particles are retained in the retentate.\n\nThis configuration can provide several advantages:\n• Efficient concentration of extracellular vesicles\n• Diafiltration for buffer exchange\n• Reduced membrane fouling compared with conventional filtration\n• Continuous processing capability\n• Better suitability for scale-up\n\nTFF can therefore play an important role in moving from laboratory-scale EV isolation toward controlled and scalable manufacturing workflows."}, {"heading": "3. Size-Exclusion Chromatography (SEC): Separation by Size", "body": "Size-Exclusion Chromatography (SEC) separates components according to their hydrodynamic size using a porous stationary phase.\n\nWhen an extracellular vesicle-containing sample passes through an SEC column, smaller molecules can enter the pores of the stationary phase and therefore take a longer pathway through the column. Larger particles, including extracellular vesicles, are preferentially excluded from these pores and can elute earlier.\n\nSEC is particularly useful for reducing soluble protein and other small molecular contaminants while operating under relatively gentle conditions.\n\nOne limitation is that SEC typically provides lower concentration capacity than membrane-based concentration techniques. For this reason, SEC may be incorporated as part of a multi-step purification workflow rather than used as the only processing step."}, {"heading": "TFF vs. SEC vs. Ultrafiltration", "body": "Ultrafiltration — Primary Principle: Membrane-based size separation. Major Advantage: Simple concentration. Key Consideration: Membrane interaction and fouling.\n\nTFF — Primary Principle: Tangential membrane filtration. Major Advantage: Scalable concentration & buffer exchange. Key Consideration: Requires process optimization.\n\nSEC — Primary Principle: Size-based chromatography. Major Advantage: Effective removal of soluble contaminants. Key Consideration: Limited loading capacity.\n\nIn advanced workflows, these technologies can be complementary rather than competing. For example, membrane-based processing may be used for concentration and buffer exchange, followed by chromatographic purification to improve separation from soluble contaminants."}, {"heading": "Purification Is Only One Part of Exosome Quality", "body": "A purified preparation should not be evaluated solely by its appearance or particle concentration. Comprehensive characterization is required to understand the identity, purity, size distribution, and overall quality of an extracellular vesicle preparation.\n\nCommon analytical approaches include:\n• Nanoparticle Tracking Analysis (NTA) for particle concentration and size distribution\n• Transmission Electron Microscopy (TEM) or cryo-TEM for morphological assessment\n• Protein and contaminant assessment\n• Appropriate sterility and safety testing depending on the intended application\n\nThese complementary analyses help establish whether a purification process consistently produces the intended extracellular vesicle population."}, {"heading": "From Purification to Reproducible Manufacturing", "body": "The objective of modern exosome processing is not simply to isolate more particles, but to establish a controlled process that delivers consistent and well-characterized extracellular vesicle preparations.\n\nThe integration of ultrafiltration, TFF, SEC, and analytical characterization provides a framework for developing scalable purification strategies. Process parameters such as membrane characteristics, flow conditions, concentration factors, buffer composition, and recovery should be carefully optimized and documented.\n\nFor a research-focused organization such as VESCO Science, purification technology forms an important component of a broader quality strategy—connecting upstream cell culture, downstream processing, analytical characterization, and batch consistency into a controlled manufacturing workflow."}]'::jsonb, '[{"phrase": "Ultrafiltration (UF)", "url": "https://pubmed.ncbi.nlm.nih.gov/35093414/"}, {"phrase": "Tangential Flow Filtration (TFF)", "url": "https://pubmed.ncbi.nlm.nih.gov/35430957/"}, {"phrase": "Size-Exclusion Chromatography (SEC)", "url": "https://pubmed.ncbi.nlm.nih.gov/34038565/"}, {"phrase": "NTA for particle concentration and size", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "TEM / cryo-TEM", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "exosome purification", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('exosome-quality-attributes', 'Exosome Science', 'What Determines Exosome Quality? Understanding Critical Quality Attributes', 'Exosome quality cannot be reduced to a single particle count. This article explains the multi-attribute approach — covering particle size, morphology, identity, purity, biological activity, and stability — that defines a scientifically robust preparation.', '', '[{"body": "Exosomes are increasingly investigated for applications in regenerative medicine, drug delivery, dermatology, and biomedical research. However, not all exosome preparations are equivalent. Their quality depends on multiple biological, physicochemical, manufacturing, and analytical parameters.\n\nFor research and translational applications, evaluating exosome quality requires a multi-attribute approach rather than relying on a single measurement such as particle concentration or one surface marker."}, {"heading": "What Are Critical Quality Attributes?", "body": "Critical Quality Attributes (CQAs) are measurable characteristics that can influence the identity, purity, consistency, safety, stability, or biological performance of a product.\n\nFor exosome-based preparations, important CQAs can include:\n• Particle size and size distribution\n• Particle concentration\n• Morphological characteristics\n• Exosome or extracellular-vesicle identity\n• Protein and biomolecular composition\n• Purity and removal of unwanted contaminants\n• Biological activity or potency\n• Microbiological safety\n• Stability during storage and transportation\n\nNo single attribute provides a complete picture of quality. Instead, these parameters should be considered together."}, {"heading": "1. Particle Size and Distribution", "body": "Exosomes are nanoscale extracellular vesicles, generally characterized within a small vesicular size range. However, an apparently appropriate particle size does not automatically confirm exosome identity.\n\nTechniques such as Nanoparticle Tracking Analysis (NTA) can provide information about particle concentration and size distribution. A consistent distribution can help establish batch-to-batch comparability and detect significant changes in the preparation."}, {"heading": "2. Morphological Characteristics", "body": "Particle morphology provides another layer of characterization. Imaging techniques such as Transmission Electron Microscopy (TEM) or cryogenic electron microscopy can be used to visualize vesicular structures.\n\nMorphological assessment can support the presence of vesicle-like particles, but imaging should be interpreted alongside complementary analytical methods rather than used as a standalone identity test."}, {"heading": "3. Identity and Molecular Characteristics", "body": "A high-quality exosome preparation should demonstrate characteristics consistent with its intended biological source and product definition.\n\nCharacterization may include assessment of vesicle-associated proteins, membrane components, cargo profiles, and source-specific biological characteristics. Depending on the intended application, techniques such as immunoassays, western blotting, flow-based analysis, proteomics, or other molecular methods may contribute to identity characterization.\n\nThe important principle is that identity should be established through multiple complementary attributes, not through a single biomarker."}, {"heading": "4. Purity and Process-Related Impurities", "body": "Exosome preparations can contain other extracellular particles, soluble proteins, nucleic acids, cellular debris, or process-related contaminants.\n\nTherefore, purification is a critical component of quality. Depending on the manufacturing strategy, methods may include ultrafiltration, size-exclusion chromatography, tangential flow filtration, density-based approaches, or combinations of purification technologies.\n\nThe objective is to obtain a preparation with a controlled impurity profile while maintaining the desired vesicle population and biological characteristics."}, {"heading": "5. Particle Concentration Is Not the Same as Quality", "body": "A common misconception is that a higher particle count automatically represents a better exosome product.\n\nParticle concentration is an important quantitative attribute, but quantity alone does not establish purity, identity, biological activity, or safety.\n\nFor example, two preparations may contain similar particle concentrations while having substantially different impurity profiles or functional characteristics. Therefore, concentration should always be interpreted together with other CQAs."}, {"heading": "6. Biological Activity and Potency", "body": "For research and translational development, one of the most important questions is whether the preparation demonstrates the intended biological function.\n\nPotency-related assays can be designed according to the proposed mechanism of action and intended application. These may evaluate cellular responses, signaling pathways, migration, immunomodulatory effects, or other relevant biological endpoints.\n\nA well-designed potency strategy connects product characteristics → biological mechanism → measurable functional response."}, {"heading": "7. Stability and Storage", "body": "Exosome quality can change during manufacturing, freezing, thawing, lyophilization, transportation, and long-term storage.\n\nA robust quality program therefore evaluates relevant attributes over the product''s intended storage period. Stability studies can monitor changes in particle characteristics, concentration, aggregation, morphology, molecular properties, and biological activity.\n\nThis is particularly important when establishing appropriate storage conditions, shelf life, and transportation requirements."}, {"heading": "Vesco Science: Quality Through QC + QbD", "body": "At Vesco Science, the concept of exosome quality can be positioned around two complementary principles: Quality Control (QC) and Quality by Design (QbD).\n\nQC focuses on measuring predefined quality attributes and verifying that each batch meets established specifications.\n\nQbD, in contrast, begins earlier—by understanding how the biological source, upstream processing, purification, formulation, storage, and other process parameters can influence the final product''s CQAs.\n\nTogether, QC and QbD provide a more systematic framework for developing consistent, characterized, and scientifically defined extracellular-vesicle preparations."}, {"heading": "A Multi-Attribute Definition of Exosome Quality", "body": "Ultimately, exosome quality should not be reduced to a single number, image, or laboratory test. A scientifically robust characterization strategy considers identity, purity, particle characteristics, concentration, biological activity, safety, and stability as interconnected quality attributes.\n\nThis multi-attribute perspective is essential for improving batch consistency, supporting reproducible research, and advancing extracellular-vesicle technologies toward increasingly well-defined applications.\n\nVesco Science''s QC + QbD approach reflects this broader principle: quality is not simply tested at the end—it is built into the understanding and control of the product and its manufacturing process."}]'::jsonb, '[{"phrase": "Critical Quality Attributes (CQAs)", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}, {"phrase": "Nanoparticle Tracking Analysis (NTA)", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "TEM / cryogenic electron microscopy", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "Purity and process-related impurities", "url": "https://pubmed.ncbi.nlm.nih.gov/34012565/"}, {"phrase": "Biological activity and potency", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}, {"phrase": "Stability and storage", "url": "https://pubmed.ncbi.nlm.nih.gov/34259095/"}, {"phrase": "Quality by Design (QbD)", "url": "https://www.fda.gov/media/71021/download"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('how-exosomes-are-characterized', 'Exosome Science', 'How Are Exosomes Characterized? A Guide to Vesicle Morphology, Particle Size & Endotoxin Testing', 'Reliable exosome characterization requires more than a single measurement. This guide covers vesicle morphology, particle-size analysis, endotoxin testing, and the product-specific quality reports that support scientific transparency.', '', '[{"body": "Exosomes and other extracellular vesicles (EVs) are nanoscale biological particles that require appropriate analytical characterization to understand their physical properties, concentration, morphology, and quality. Because biological nanoparticle preparations can vary according to their source and manufacturing process, systematic characterization is an essential part of exosome research and quality assessment.\n\nAt Vesco Science, characterization and quality evaluation are important components of the research process. Product-specific analytical and research reports can provide documented information about key parameters such as vesicle morphology, particle size, and endotoxin levels, helping researchers evaluate the consistency and quality profile of each product."}, {"heading": "Why Is Exosome Characterization Important?", "body": "Exosome preparations are complex biological materials. Their characteristics can be influenced by the cell source, culture conditions, isolation technology, purification process, concentration, formulation, and storage conditions.\n\nA comprehensive characterization approach helps establish measurable information about the final preparation, including:\n• Vesicle morphology\n• Particle-size distribution\n• Particle concentration\n• Endotoxin levels\n• Batch-to-batch consistency\n• Overall product quality\n\nRather than depending on a single analytical measurement, multiple complementary tests provide a more informative characterization profile."}, {"heading": "1. Vesicle Morphology — Visual Analytics", "body": "Vesicle morphology refers to the physical appearance and structural characteristics of vesicles observed through high-resolution imaging techniques.\n\nMicroscopic visualization can help researchers assess whether the preparation contains structures consistent with nanoscale extracellular vesicles and evaluate their general morphology. Imaging is particularly useful as a visual component of a broader characterization strategy.\n\nMorphological analysis should be interpreted together with quantitative particle analysis because visual appearance alone cannot establish the complete identity or purity of an exosome preparation."}, {"heading": "2. Particle Size Analysis — Technical Data", "body": "Particle size analysis provides quantitative information about the size distribution of particles present in an exosome preparation.\n\nFor nanoscale biological particles, Nanoparticle Tracking Analysis (NTA) is one commonly used analytical technique. NTA tracks the Brownian motion of individual particles in suspension and uses this information to estimate particle size and concentration.\n\nParticle-size analysis can help researchers evaluate: nanoscale particle distribution, particle concentration, sample consistency, differences between batches, and changes associated with processing or storage.\n\nImportantly, particle size alone cannot establish that all measured particles are exosomes. Other nanoscale particles and extracellular-vesicle populations may have overlapping size ranges. Therefore, size data should be considered as one component of a comprehensive characterization profile."}, {"heading": "3. Endotoxin Testing — Safety Report", "body": "Endotoxin testing is an important quality-control parameter for biologically derived materials.\n\nEndotoxins are components of the outer membrane of Gram-negative bacteria and can produce significant biological responses when present above appropriate levels. Testing for endotoxin helps evaluate the microbiological quality and safety profile of a preparation, particularly when the material is intended for research or advanced biomedical applications.\n\nEndotoxin results provide an additional layer of quality information beyond particle concentration and morphology. A comprehensive product assessment therefore considers both physical characterization and relevant safety-related analytical parameters."}, {"heading": "Vesco Science: Product-Specific Research & Quality Reports", "body": "At Vesco Science, characterization is not limited to general information about exosomes. Product-specific research and quality reports are generated to document relevant analytical characteristics of individual products.\n\nDepending on the product and its intended research application, characterization data can include:\n\nVesicle Morphology — Visual assessment of nanoscale vesicle structures.\nParticle Size Analysis — Quantitative evaluation of particle-size distribution.\nParticle Concentration — Measurement of particle abundance.\nEndotoxin Testing — Evaluation of endotoxin levels as a quality parameter.\nResearch / QC Report — Documentation of product-specific analytical findings.\n\nThis product-level documentation supports traceability, quality assessment, and scientific transparency, allowing researchers and professional users to review analytical information associated with the material they are working with."}, {"heading": "A Multi-Parameter Approach to Exosome Characterization", "body": "Reliable exosome characterization requires more than a single measurement. Morphology provides visual information, particle-size analysis provides quantitative data, and endotoxin testing provides an important quality and safety parameter.\n\nTogether, these analytical categories create a more comprehensive profile of an exosome preparation:\n\nVesicle Morphology → Particle Size & Concentration → Endotoxin Testing → Product-Specific Research/QC Report\n\nThis structured approach allows each product to be evaluated using measurable analytical parameters rather than relying solely on descriptive claims.\n\nFor researchers working with extracellular vesicles, access to documented characterization data is an important part of selecting, comparing, and evaluating exosome preparations."}]'::jsonb, '[{"phrase": "exosome characterization", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}, {"phrase": "vesicle morphology", "url": "https://isevjournals.onlinelibrary.wiley.com/doi/10.1002/jev2.12404"}, {"phrase": "Nanoparticle Tracking Analysis (NTA)", "url": "https://pubmed.ncbi.nlm.nih.gov/39407601/"}, {"phrase": "particle size and concentration", "url": "https://pubmed.ncbi.nlm.nih.gov/35737250/"}, {"phrase": "endotoxin testing", "url": "https://pubmed.ncbi.nlm.nih.gov/36876926/"}, {"phrase": "batch-to-batch consistency", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('huc-msc-exosomes', 'Exosome Science', 'Human Umbilical Cord MSC-Derived Exosomes: What Makes Them Different?', 'HUC-MSC-derived exosomes are studied for their biologically active molecular cargo. This article explains their cell source, molecular composition, manufacturing workflow, and what makes a high-quality preparation.', '', '[{"body": "Human umbilical cord mesenchymal stem/stromal cell (HUC-MSC)-derived exosomes are increasingly studied as a promising class of extracellular vesicles for advanced biomedical and regenerative research. Their interest comes not from the presence of living stem cells, but from the biologically active molecular cargo carried within extracellular vesicles released by cultured HUC-MSCs.\n\nAt Vesco Science, understanding the relationship between cell source, extracellular vesicle biology, purification, and characterization is essential for developing scientifically consistent exosome-based research materials."}, {"heading": "What Are HUC-MSC-Derived Exosomes?", "body": "Mesenchymal stromal cells obtained from human umbilical cord tissue can release various extracellular vesicles (EVs), including small EV populations commonly referred to as exosomes. These nanoscale vesicles are surrounded by a lipid bilayer and contain a complex biological cargo.\n\nTheir cargo can include:\n• Proteins and peptides\n• Lipids\n• Messenger RNA (mRNA)\n• MicroRNAs (miRNAs)\n• Other regulatory RNA molecules\n• Cell-signaling molecules\n\nRather than functioning as living cells, exosomes can act as intercellular communication vehicles, transferring molecular information between cells.\n\nImportantly, the term exosome should be used carefully because extracellular vesicles are heterogeneous and different EV subpopulations can overlap in size and biological characteristics."}, {"heading": "Why Does the Cell Source Matter?", "body": "The biological properties of extracellular vesicles can be influenced by the characteristics of their parent cells.\n\nHUC-MSCs are particularly interesting because they originate from human umbilical cord tissue, a relatively accessible source of mesenchymal stromal cells used extensively in research.\n\nCompared with adult tissue sources, umbilical cord-derived MSCs are often investigated for their distinctive biological characteristics, including their proliferative capacity and secretory profile.\n\nThe cellular environment can also influence the composition of the extracellular vesicles released by MSCs. Factors such as cell passage and culture conditions, cell density, culture medium, oxygen conditions, cellular health, and harvesting strategy may influence EV yield and molecular composition."}, {"heading": "The Importance of Molecular Cargo", "body": "One of the defining scientific interests of HUC-MSC-derived exosomes is their molecular cargo.\n\nExosomes can carry proteins, lipids and nucleic acids that participate in cell-to-cell communication. MicroRNAs are particularly important because they can influence gene expression and cellular signaling pathways.\n\nHowever, exosome cargo is not a fixed molecular formula. It can vary according to the source cells and manufacturing conditions.\n\nTherefore, simply stating that a product contains \"billions of exosomes\" does not fully describe its biological characteristics. Understanding the source, identity, purity, concentration and molecular profile is equally important."}, {"heading": "From Cell Culture to Exosome Isolation", "body": "Producing HUC-MSC-derived extracellular vesicles involves several critical stages.\n\nA simplified workflow includes:\nHUC-MSC expansion → controlled culture → conditioned-medium collection → clarification → extracellular-vesicle enrichment → purification → concentration → characterization\n\nMultiple technologies may be used during downstream processing, including filtration-based approaches, ultrafiltration, tangential flow filtration (TFF), size-exclusion chromatography (SEC), or combinations of different techniques.\n\nThe objective is to obtain an EV preparation with an appropriate balance between recovery, purity and reproducibility."}, {"heading": "What Makes a High-Quality HUC-MSC-Derived EV Preparation?", "body": "The source of the MSCs is only one part of the equation. Quality depends on the complete manufacturing and characterization process.\n\nKey considerations include:\n\n1. Defined cellular source — Traceable and well-characterized HUC-MSCs provide the foundation for reproducible production.\n\n2. Controlled manufacturing conditions — Consistent cell culture and harvesting conditions can help minimize batch-to-batch variation.\n\n3. Appropriate purification — Purification should be designed to balance particle recovery with removal of unwanted components.\n\n4. Comprehensive characterization — Particle concentration, size distribution, morphology, EV-associated markers and purity parameters should be evaluated using appropriate analytical methods.\n\n5. Stability and storage — Processing, formulation, temperature and storage conditions can influence extracellular-vesicle integrity and should therefore be controlled and documented."}, {"heading": "Vesco Science Perspective", "body": "HUC-MSC-derived exosomes represent a sophisticated intersection of cell biology, extracellular-vesicle science, bioprocessing and analytical characterization.\n\nFor research-grade EV development, the goal is not simply to achieve a high particle count. A scientifically meaningful product profile requires attention to source-cell quality, controlled production, purification, characterization, reproducibility and stability.\n\nThis integrated approach helps transform extracellular-vesicle research from a simple particle-isolation process into a controlled and scientifically measurable biotechnology platform."}]'::jsonb, '[{"phrase": "HUC-MSC-derived exosomes", "url": "https://pubmed.ncbi.nlm.nih.gov/34944535/"}, {"phrase": "molecular cargo", "url": "https://pubmed.ncbi.nlm.nih.gov/33506022/"}, {"phrase": "microRNAs (miRNAs)", "url": "https://pubmed.ncbi.nlm.nih.gov/33758102/"}, {"phrase": "cell-to-cell communication", "url": "https://pubmed.ncbi.nlm.nih.gov/33506022/"}, {"phrase": "Nanoparticle Tracking Analysis (NTA)", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "TEM / cryo-TEM", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "tissue repair and regeneration", "url": "https://pubmed.ncbi.nlm.nih.gov/34944535/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('exosome-concentration-explained', 'Exosome Science', 'Exosome Concentration Explained: What Does "10 Billion" or "20 Billion" Really Mean?', 'Billion-count labels on exosome products are widely misunderstood. This article explains what particle numbers actually represent, how they are measured, and why concentration alone does not determine product quality.', '', '[{"body": "Exosome-based products are increasingly described using terms such as \"10 Billion Exosomes,\" \"20 Billion Exosomes,\" or \"60 Billion Exosomes.\" While these numbers appear straightforward, their scientific meaning is often misunderstood.\n\nA billion-count specification generally refers to the estimated number of extracellular vesicle (EV)-sized particles present in a defined product volume. However, particle count alone does not describe the complete quality, purity, biological activity, or composition of an exosome preparation.\n\nUnderstanding what these numbers actually represent is essential for researchers, clinicians, and professionals working with extracellular vesicle technologies."}, {"heading": "What Does \"10 Billion Exosomes\" Mean?", "body": "When a product is labeled 10 Billion Exosomes, the intended meaning is generally that the preparation contains approximately 10 billion particles within the specified product volume, based on the manufacturer''s particle-counting method.\n\nFor example, if a 5 mL preparation contains 10 billion particles:\n10 billion particles ÷ 5 mL = 2 billion particles/mL\n\nSimilarly, a 20-billion-particle preparation in the same 5 mL volume would correspond to approximately:\n20 billion particles ÷ 5 mL = 4 billion particles/mL\n\nTherefore, total particle number and concentration are related but not identical terms.\n• Total particle count: Number of particles in the entire vial or preparation.\n• Particle concentration: Number of particles per unit volume, commonly particles/mL.\n\nThis distinction becomes particularly important when comparing products with different vial volumes."}, {"heading": "Are \"10 Billion\" Particles All Exosomes?", "body": "Not necessarily.\n\nThe term exosome technically refers to a specific class of extracellular vesicles originating from the endosomal pathway. In many commercial and research settings, however, particle-count specifications may represent extracellular vesicle-sized particles rather than exclusively purified exosomes.\n\nTechniques such as Nanoparticle Tracking Analysis (NTA) measure particles according to characteristics such as size and Brownian motion. NTA can provide an estimate of particle concentration and size distribution, but it does not automatically prove that every detected particle is a biologically defined exosome.\n\nTherefore, a scientifically responsible specification should ideally identify: the particle-counting method, particle concentration, size distribution, source of the vesicles, purification methodology, relevant EV markers, protein or contaminant assessment, and product characterization data."}, {"heading": "Why Particle Count Matters", "body": "Particle concentration is an important quantitative parameter because it provides an indication of the amount of vesicular material present in a preparation.\n\n10 Billion — Approximate Total Particles: 10 × 10⁹ particles. If Volume = 5 mL: 2 × 10⁹ particles/mL\n20 Billion — Approximate Total Particles: 20 × 10⁹ particles. If Volume = 5 mL: 4 × 10⁹ particles/mL\n60 Billion — Approximate Total Particles: 60 × 10⁹ particles. If Volume = 5 mL: 12 × 10⁹ particles/mL\n\nThese calculations demonstrate why vial volume must always be considered alongside the billion-count specification.\n\nA product containing 20 billion particles in 10 mL is not equivalent in concentration to a product containing 20 billion particles in 2 mL."}, {"heading": "Billion Count Does Not Equal Product Quality", "body": "One of the most important scientific principles in exosome characterization is that a higher particle number does not automatically mean a better product.\n\nTwo preparations may both contain 20 billion particles but have substantially different characteristics.\n\nQuality assessment may also consider:\n\n1. Particle Size Distribution — Extracellular vesicles exist across a range of nanoscale sizes. A size distribution can provide useful information about the particle population.\n\n2. Purity — The preparation should be assessed for unwanted proteins, cellular components, aggregates, or other non-vesicular materials.\n\n3. Source and Manufacturing Process — The biological source and downstream processing—including isolation, purification, concentration, and storage—can influence the characteristics of the final preparation.\n\n4. Stability — Storage conditions and handling can affect particle integrity, aggregation, and measurable particle concentration."}, {"heading": "Understanding the Number: A Practical Perspective", "body": "The terms 10B, 20B, or 60B should therefore be viewed as a quantitative particle specification—not a standalone measure of exosome quality or biological performance.\n\nWhen evaluating an extracellular vesicle preparation, the particle count should be considered together with source, purification, particle concentration, size distribution, EV-associated markers, purity, stability, and appropriate quality-control testing.\n\nFor researchers and professionals, this broader characterization approach provides a more scientifically meaningful understanding of what is actually present in an exosome preparation."}]'::jsonb, '[{"phrase": "particle concentration", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "Nanoparticle Tracking Analysis (NTA)", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "size distribution", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}, {"phrase": "EV-associated markers", "url": "https://isevjournals.onlinelibrary.wiley.com/doi/10.1002/jev2.12404"}, {"phrase": "purification methodology", "url": "https://pubmed.ncbi.nlm.nih.gov/34038565/"}, {"phrase": "particle count alone", "url": "https://pubmed.ncbi.nlm.nih.gov/38326288/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('pdrn-vs-pn', 'PDRN / PN', 'PDRN vs. PN: Understanding the Differences, Properties and Applications', 'PDRN and PN are related but distinct nucleic-acid-based biomaterials. This article explains their molecular differences, mechanistic profiles, and what makes them each relevant in regenerative aesthetics.', '', '[{"body": "PDRN and PN are two important nucleic-acid-based biomaterials increasingly used in regenerative aesthetics, dermatology, and tissue-repair research. Although the terms are sometimes used interchangeably in the aesthetic industry, they describe materials with different molecular characteristics, processing profiles, and functional properties.\n\nUnderstanding the distinction between Polydeoxyribonucleotide (PDRN) and Polynucleotide (PN) is important when evaluating their scientific basis, formulation, and potential applications."}, {"heading": "What Is PDRN?", "body": "Polydeoxyribonucleotide (PDRN) refers to a mixture of DNA fragments composed of deoxyribonucleotides. In many commercially developed products, PDRN is produced from highly purified DNA sources, commonly associated with salmonid species.\n\nPDRN generally contains relatively short DNA fragments, with molecular size depending on the manufacturing and purification process. Its biological activity has been investigated particularly in relation to tissue repair, cellular signaling, angiogenesis, and inflammatory modulation.\n\nOne proposed mechanism involves the adenosine A2A receptor pathway, while another is the nucleotide salvage pathway, through which nucleotide components can contribute to cellular processes involved in tissue regeneration."}, {"heading": "What Is PN?", "body": "Polynucleotide (PN) refers to purified polymeric DNA chains with comparatively higher molecular weight and longer nucleotide sequences than the fragmented DNA typically associated with PDRN.\n\nIn aesthetic and regenerative applications, PN formulations are often designed to provide a combination of biocompatibility, water-retention capacity, viscoelastic behavior, and tissue-supporting properties.\n\nBecause PN molecules are longer and more polymeric, their physicochemical behavior can differ substantially from shorter DNA fragments. Depending on formulation and concentration, PN may form a hydrated polymeric environment that contributes to the material''s structural and rheological characteristics."}, {"heading": "PDRN vs. PN: Key Differences", "body": "Full name: PDRN = Polydeoxyribonucleotide. PN = Polynucleotide.\n\nMolecular structure: PDRN = Mixture of DNA fragments. PN = Longer polymeric DNA chains.\n\nTypical molecular size: PDRN = Generally lower. PN = Generally higher.\n\nPrimary scientific interest: PDRN = Cellular signaling and tissue repair. PN = Biophysical support and tissue remodeling.\n\nMaterial behavior: PDRN = More associated with bioactive nucleotide fragments. PN = Greater polymeric and viscoelastic characteristics.\n\nCommon research areas: PDRN = Wound healing, tissue regeneration. PN = Skin quality, tissue support, regenerative aesthetics.\n\nImportant: There is no single universal molecular-weight boundary that separates PDRN from PN across every manufacturer or scientific publication. Product terminology and specifications can vary according to source material, purification, molecular-weight distribution, and manufacturing methodology."}, {"heading": "Different Mechanistic Profiles", "body": "PDRN and PN may overlap in their biological relevance, but their proposed mechanisms and material characteristics should not be treated as identical.\n\nPDRN: Research surrounding PDRN has focused on pathways associated with tissue repair and cellular recovery. The adenosine A2A receptor pathway and nucleotide salvage pathway are among the mechanisms investigated in preclinical and clinical research. This has made PDRN particularly interesting in areas such as wound healing and tissue regeneration.\n\nPN: PN is additionally characterized by its polymeric nature and physicochemical properties. Depending on formulation, hydrated PN chains can contribute to a supportive matrix-like environment and influence properties such as viscosity, elasticity, and water retention. In aesthetic applications, these characteristics have generated interest in skin quality, hydration, elasticity, and tissue remodeling."}, {"heading": "Applications in Regenerative Aesthetics", "body": "Both PDRN and PN have attracted attention in aesthetic medicine, but they should be evaluated according to their specific composition and evidence base rather than their category name alone.\n\nPDRN has been investigated extensively in regenerative and wound-healing contexts, while PN-based injectable materials have become increasingly prominent in skin-focused applications.\n\nPotential areas of investigation include: skin hydration and quality, tissue repair, support of regenerative processes, improvement of skin texture and elasticity, post-procedural tissue recovery, and dermatological and aesthetic applications.\n\nThe clinical performance of any individual product depends on factors including molecular composition, concentration, purification, formulation, administration technique, and product quality."}, {"heading": "PDRN and PN: Related, but Not Identical", "body": "PDRN and PN belong to the broader family of DNA-derived biomaterials, but they should not automatically be considered the same material.\n\nThe most meaningful distinction lies in their molecular characteristics, polymer length, physicochemical behavior, manufacturing specifications, and intended biological function. PDRN is generally associated with shorter DNA fragments and regenerative signaling research, whereas PN commonly refers to longer polymeric DNA chains with additional material and tissue-supporting characteristics.\n\nFor researchers, clinicians, and product developers, understanding these differences provides a more scientific framework for assessing quality, formulation, mechanism, and application rather than relying solely on marketing terminology."}]'::jsonb, '[{"phrase": "Polydeoxyribonucleotide (PDRN)", "url": "https://pubmed.ncbi.nlm.nih.gov/29946250/"}, {"phrase": "Polynucleotide (PN)", "url": "https://pubmed.ncbi.nlm.nih.gov/34393271/"}, {"phrase": "adenosine A2A receptor pathway", "url": "https://pubmed.ncbi.nlm.nih.gov/29946250/"}, {"phrase": "nucleotide salvage pathway", "url": "https://pubmed.ncbi.nlm.nih.gov/29946250/"}, {"phrase": "skin hydration, elasticity and tissue remodeling", "url": "https://pubmed.ncbi.nlm.nih.gov/34393271/"}, {"phrase": "molecular-weight distribution", "url": "https://pubmed.ncbi.nlm.nih.gov/34393271/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('hyaluronic-acid-molecular-weight', 'Hyaluronic Acid', 'How Molecular Weight Influences Hyaluronic Acid: From Molecular Structure to Application', 'Molecular weight is one of the most important factors determining how hyaluronic acid behaves — affecting viscosity, water-binding, tissue distribution, and formulation performance. This article explains the science.', '', '[{"body": "Hyaluronic acid (HA) is a naturally occurring polysaccharide found throughout the extracellular matrix of the skin, connective tissues, and other biological systems. Because of its excellent biocompatibility, water-binding capacity, and versatile physicochemical properties, HA has become an important material in dermal fillers, skin rejuvenation, tissue engineering, ophthalmic products, and pharmaceutical formulations.\n\nOne of the most important factors determining how HA behaves is its molecular weight (MW). The molecular size of HA chains can significantly influence viscosity, water interaction, tissue distribution, residence time, and the overall performance of an HA-based formulation."}, {"heading": "What Is Molecular Weight in Hyaluronic Acid?", "body": "HA is a linear, non-sulfated glycosaminoglycan composed of repeating disaccharide units of D-glucuronic acid and N-acetyl-D-glucosamine.\n\nUnlike small molecules with one defined molecular mass, HA consists of polymer chains with different lengths. Therefore, HA is generally described according to molecular-weight ranges rather than a single molecular-weight value.\n\nHA can broadly be categorized as:\n• Low-molecular-weight HA (LMW-HA)\n• Medium-molecular-weight HA\n• High-molecular-weight HA (HMW-HA)\n\nThe exact molecular-weight boundaries can vary between scientific studies and manufacturers, so the terminology should always be interpreted in relation to the specific formulation."}, {"heading": "Why Molecular Weight Matters", "body": "The length of an HA polymer chain affects how the molecule interacts with water, surrounding biomolecules, and tissue structures.\n\n1. Water-Binding Capacity\nHA has a strong ability to interact with water because of its numerous hydrophilic functional groups. Longer polymer chains can form an extensive hydrated network, contributing to the characteristic viscoelastic and water-retaining properties of HA formulations.\n\nThis property is particularly relevant in aesthetic applications, where hydration and tissue integration are important formulation characteristics. However, hydration does not depend exclusively on molecular weight. HA concentration, chemical modification, crosslinking, formulation composition, and rheological properties also play major roles.\n\n2. Viscosity and Rheology\nMolecular weight strongly influences the rheological behavior of HA solutions. As polymer-chain length increases, HA solutions generally show greater hydrodynamic volume and entanglement, which can increase viscosity at comparable concentrations."}, {"heading": "Molecular Weight and HA in Aesthetic Applications", "body": "In aesthetic medicine, molecular weight is only one component of HA product design. The final clinical and physical characteristics depend on the entire formulation architecture.\n\nFor dermal fillers, important parameters include: HA molecular-weight distribution, HA concentration, degree and type of crosslinking, crosslinking agent and manufacturing process, particle or gel structure, elastic modulus (G′), viscous modulus (G″), cohesivity, swelling behavior, and injection characteristics.\n\nCrosslinking is particularly important because chemically crosslinked HA forms a three-dimensional network that can substantially increase its resistance to enzymatic degradation and modify its mechanical properties.\n\nTherefore, two products containing HA with similar molecular-weight ranges may still demonstrate very different rheological and clinical behaviors."}, {"heading": "Molecular Weight vs. Crosslinking: Two Different Concepts", "body": "A common misconception is that molecular weight and crosslinking are interchangeable. They are not.\n\nMolecular weight describes the length or mass characteristics of individual HA polymer chains.\n\nCrosslinking describes chemical bonds formed between polymer chains to create a network structure.\n\nA product can therefore contain relatively high-MW HA while also being crosslinked, producing a material with substantially different rheological and degradation characteristics from uncrosslinked HA."}, {"heading": "Designing HA Products Through Molecular Engineering", "body": "Modern HA development increasingly relies on controlling multiple parameters simultaneously rather than selecting molecular weight alone.\n\nFor example, a formulation designed for hydration and skin quality may prioritize a different molecular-weight distribution and rheological profile from a formulation designed to provide structural volume and tissue support.\n\nThis is where pharmaceutical and biomaterial engineering becomes important. By controlling molecular weight, concentration, crosslink density, gel architecture, and rheological characteristics, manufacturers can develop HA systems tailored to specific applications.\n\nAt Vesco Science, understanding these relationships is essential for translating HA polymer science into reproducible, application-specific biomaterial formulations."}, {"heading": "The Key Takeaway", "body": "Molecular weight provides an important foundation for understanding how hyaluronic acid behaves, but it does not independently determine product performance. Polymer-chain length, molecular-weight distribution, concentration, crosslinking, gel architecture, and rheological properties work together to define the characteristics of an HA-based product.\n\nFrom molecular structure to final application, careful control of these parameters allows HA formulations to be engineered for specific scientific and aesthetic objectives."}]'::jsonb, '[{"phrase": "hyaluronic acid (HA)", "url": "https://pubmed.ncbi.nlm.nih.gov/31101992/"}, {"phrase": "molecular weight", "url": "https://pubmed.ncbi.nlm.nih.gov/33177231/"}, {"phrase": "water-binding capacity", "url": "https://pubmed.ncbi.nlm.nih.gov/31101992/"}, {"phrase": "viscosity and rheology", "url": "https://pubmed.ncbi.nlm.nih.gov/24795511/"}, {"phrase": "crosslinking", "url": "https://pubmed.ncbi.nlm.nih.gov/31101992/"}, {"phrase": "molecular-weight distribution", "url": "https://pubmed.ncbi.nlm.nih.gov/33177231/"}, {"phrase": "elastic modulus (G′)", "url": "https://pubmed.ncbi.nlm.nih.gov/24795511/"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();
insert into public.articles (slug, category, title, excerpt, hero_image, sections, references_list, published)
values ('cell-culture-to-final-product', 'Manufacturing', 'From Cell Culture to Final Product: How Vesco Science Develops High-Quality Biologics', 'Modern biologics are the result of a controlled, multi-stage process connecting cell biology, bioprocessing, purification, analytical science, formulation, and quality control. This article walks through each stage.', '', '[{"body": "Modern biologics are not created through a single manufacturing step. They are the result of a controlled, multi-stage process that connects cell biology, process development, purification, analytical science, formulation, and quality control. At Vesco Science, this integrated approach provides a framework for transforming biological starting materials into consistent, research-driven final products.\n\nFrom early-stage cell culture to final product characterization, each stage is designed to protect product quality, reproducibility, and scientific integrity."}, {"heading": "1. Cell Source Selection and Characterization", "body": "The development of a biologic begins with the selection of an appropriate biological source. Depending on the intended product, this may involve specific cell types, cell banks, or other biological starting materials.\n\nFor cell-derived products, the source must be carefully characterized and maintained under controlled conditions. Parameters such as cell identity, morphology, viability, growth characteristics, and microbiological status are important considerations during development.\n\nEstablishing a well-controlled starting material helps create a reliable foundation for subsequent manufacturing stages."}, {"heading": "2. Controlled Cell Culture and Upstream Processing", "body": "Once the appropriate cell source has been established, cells are expanded under defined culture conditions. This stage is commonly referred to as upstream processing.\n\nImportant process variables can include:\n• Culture medium composition\n• Temperature and pH\n• Dissolved oxygen\n• Cell density\n• Incubation time\n• Nutrient availability\n• Culture vessel or bioreactor conditions\n\nFor biologically derived products such as extracellular vesicles and exosome preparations, upstream conditions can influence the characteristics and composition of the resulting biological material."}, {"heading": "3. Harvesting and Recovery of Biological Material", "body": "Following the appropriate culture period, the biological material is harvested. Depending on the product platform, the harvested material may contain cells, conditioned media, proteins, extracellular vesicles, or other biological components.\n\nThe objective at this stage is to efficiently recover the desired material while minimizing contamination and unnecessary processing stress.\n\nFor extracellular-vesicle-based products, for example, the harvested conditioned medium can undergo clarification and subsequent purification to separate vesicles from unwanted cellular debris and soluble components."}, {"heading": "4. Purification and Downstream Processing", "body": "Downstream processing is one of the most critical stages in biologics manufacturing. It focuses on concentrating and purifying the target biological component while controlling impurities.\n\nDifferent purification technologies may be selected according to the characteristics of the product. These can include: ultrafiltration, tangential flow filtration (TFF), size-exclusion chromatography (SEC), chromatographic purification, and controlled concentration and buffer exchange.\n\nThe process must be developed to balance purity, recovery, biological integrity, and reproducibility.\n\nFor complex biological products, purification is not simply about removing impurities; it is about establishing a controlled process capable of consistently producing material with defined characteristics."}, {"heading": "5. Analytical Characterization and Quality Control", "body": "A biologic cannot be considered adequately characterized based on appearance alone. Analytical testing provides scientific evidence about its identity, purity, concentration, and other critical quality attributes.\n\nDepending on the product, analytical approaches may include: particle concentration and size analysis, protein characterization, marker analysis, sterility and microbiological testing, endotoxin assessment, pH and physicochemical testing, and stability evaluation.\n\nFor exosome and extracellular-vesicle preparations, techniques such as Nanoparticle Tracking Analysis (NTA) can be used to evaluate particle concentration and size distribution.\n\nThese analytical measurements support batch-to-batch consistency and help establish scientifically defined product specifications."}, {"heading": "6. Formulation and Final Product Development", "body": "After purification and characterization, the biological material must be converted into a suitable final formulation.\n\nFormulation development considers factors such as: product concentration, buffer composition, pH, osmolality, stability, container compatibility, and storage requirements.\n\nFor products requiring long-term storage, formulation and packaging are particularly important because biological materials can be sensitive to temperature, oxidation, aggregation, and other environmental factors.\n\nThe goal is to establish a final product format that maintains the required quality characteristics throughout its defined storage period."}, {"heading": "7. Fill-Finish, Packaging, and Batch Release", "body": "The final manufacturing stage involves controlled filling into appropriate containers, labeling, packaging, and documentation.\n\nBefore a batch is released, predefined quality specifications must be evaluated against the available analytical and manufacturing records. Proper documentation creates traceability from the original biological material through manufacturing and final product release."}, {"heading": "An Integrated R&D and Manufacturing Approach", "body": "The development of high-quality biologics requires more than advanced equipment. It requires an integrated understanding of cell biology, bioprocess engineering, purification science, analytical characterization, formulation, and quality systems.\n\nVesco Science''s development philosophy connects these disciplines across the product lifecycle—from cell culture and process optimization to purification, characterization, formulation, and final product development.\n\nThis integrated model enables biological products to be developed through a structured and scientifically controlled workflow, supporting greater consistency, reproducibility, and confidence in the final product.\n\nFrom cell culture to final product, every stage matters—because quality in biologics is built through the entire process, not added at the end."}]'::jsonb, '[{"phrase": "cell culture and upstream processing", "url": "https://www.ncbi.nlm.nih.gov/books/NBK26936/"}, {"phrase": "bioprocessing", "url": "https://pubmed.ncbi.nlm.nih.gov/35710955/"}, {"phrase": "downstream processing", "url": "https://pubmed.ncbi.nlm.nih.gov/34038565/"}, {"phrase": "Tangential Flow Filtration (TFF)", "url": "https://pubmed.ncbi.nlm.nih.gov/35430957/"}, {"phrase": "analytical characterization", "url": "https://isevjournals.onlinelibrary.wiley.com/doi/10.1002/jev2.12404"}, {"phrase": "Nanoparticle Tracking Analysis (NTA)", "url": "https://pubmed.ncbi.nlm.nih.gov/26563735/"}, {"phrase": "formulation and stability", "url": "https://pubmed.ncbi.nlm.nih.gov/34259095/"}, {"phrase": "fill-finish and batch release", "url": "https://www.fda.gov/drugs/pharmaceutical-quality-resources/fill-finish-manufacturing"}]'::jsonb, true)
on conflict (slug) do update set
  category = excluded.category,
  title = excluded.title,
  excerpt = excluded.excerpt,
  hero_image = case when excluded.hero_image <> '' then excluded.hero_image else public.articles.hero_image end,
  sections = excluded.sections,
  references_list = excluded.references_list,
  updated_at = now();

-- TOTAL ARTICLES SEEDED: 10
