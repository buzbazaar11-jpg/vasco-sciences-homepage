import json
import re

# Read formatted products
with open("formatted_products.json", "r", encoding="utf-8") as f:
    all_products = json.load(f)

# Read articles from TS file using regex parsing
with open("src/data/articles.ts", "r", encoding="utf-8") as f:
    articles_ts = f.read()

def sql_quote(val):
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, (dict, list)):
        json_str = json.dumps(val, ensure_ascii=False)
        # Escape single quotes for SQL string literal
        escaped = json_str.replace("'", "''")
        return f"'{escaped}'::jsonb"
    # String
    escaped = str(val).replace("'", "''")
    return f"'{escaped}'"

sql_lines = []

sql_lines.append("""-- ============================================================
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
-- 5. SEED PRODUCTS DATA (All 79 Real Products)
-- ============================================================
""")

product_count = 0
for cat, p_list in all_products.items():
    for idx, p in enumerate(p_list):
        product_count += 1
        slug = p["slug"]
        name = p["name"]
        group = p.get("group", "")
        label = p.get("label", "")
        detail = p.get("detail", "")
        specs = p.get("specs", [])
        
        sql_lines.append(f"""insert into public.products (slug, category, group_name, label, name, detail, specs, sort_order, published)
values ({sql_quote(slug)}, {sql_quote(cat)}, {sql_quote(group)}, {sql_quote(label)}, {sql_quote(name)}, {sql_quote(detail)}, {sql_quote(specs)}, {idx}, true)
on conflict (slug) do update set
  category = excluded.category,
  group_name = excluded.group_name,
  label = excluded.label,
  name = excluded.name,
  detail = excluded.detail,
  specs = excluded.specs,
  updated_at = now();""")

sql_lines.append(f"\n-- TOTAL PRODUCTS SEEDED: {product_count}\n")

# Parse ARTICLES from articles.ts using node or python script
# We can use node script to load articles.ts and output JSON for python
print(f"Products formatted: {product_count}")

with open("SUPABASE_SETUP_PART1.sql", "w", encoding="utf-8") as f:
    f.write("\n".join(sql_lines))
