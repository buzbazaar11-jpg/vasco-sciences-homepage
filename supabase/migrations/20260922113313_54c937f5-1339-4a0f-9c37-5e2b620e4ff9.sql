CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = private, public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;
REVOKE ALL ON FUNCTION private.has_role(uuid, public.app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_role(uuid, public.app_role) TO authenticated;

DROP POLICY "admins manage pages" ON public.pages;
CREATE POLICY "admins manage pages" ON public.pages FOR ALL TO authenticated
  USING (private.has_role(auth.uid(),'admin')) WITH CHECK (private.has_role(auth.uid(),'admin'));

DROP POLICY "admins manage settings" ON public.site_settings;
CREATE POLICY "admins manage settings" ON public.site_settings FOR ALL TO authenticated
  USING (private.has_role(auth.uid(),'admin')) WITH CHECK (private.has_role(auth.uid(),'admin'));

DROP POLICY "admins manage resources" ON public.resources;
CREATE POLICY "admins manage resources" ON public.resources FOR ALL TO authenticated
  USING (private.has_role(auth.uid(),'admin')) WITH CHECK (private.has_role(auth.uid(),'admin'));

DROP POLICY "admins upload site files" ON storage.objects;
CREATE POLICY "admins upload site files" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'site-files' AND private.has_role(auth.uid(),'admin'));
DROP POLICY "admins update site files" ON storage.objects;
CREATE POLICY "admins update site files" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'site-files' AND private.has_role(auth.uid(),'admin'));
DROP POLICY "admins delete site files" ON storage.objects;
CREATE POLICY "admins delete site files" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'site-files' AND private.has_role(auth.uid(),'admin'));

DROP FUNCTION public.has_role(uuid, public.app_role);

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  category text NOT NULL DEFAULT '',
  group_name text NOT NULL DEFAULT '',
  label text NOT NULL DEFAULT '',
  name text NOT NULL DEFAULT '',
  detail text NOT NULL DEFAULT '',
  specs jsonb NOT NULL DEFAULT '[]'::jsonb,
  image_url text NOT NULL DEFAULT '',
  sort_order int NOT NULL DEFAULT 0,
  published boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.products TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO authenticated;
GRANT ALL ON public.products TO service_role;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "published products public" ON public.products FOR SELECT TO anon USING (published = true);
CREATE POLICY "products readable by authed" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "admins manage products" ON public.products FOR ALL TO authenticated
  USING (private.has_role(auth.uid(),'admin')) WITH CHECK (private.has_role(auth.uid(),'admin'));
CREATE TRIGGER products_touch BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TABLE public.articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  category text NOT NULL DEFAULT '',
  title text NOT NULL DEFAULT '',
  excerpt text NOT NULL DEFAULT '',
  hero_image text NOT NULL DEFAULT '',
  sections jsonb NOT NULL DEFAULT '[]'::jsonb,
  references_list jsonb NOT NULL DEFAULT '[]'::jsonb,
  published boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.articles TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.articles TO authenticated;
GRANT ALL ON public.articles TO service_role;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "published articles public" ON public.articles FOR SELECT TO anon USING (published = true);
CREATE POLICY "articles readable by authed" ON public.articles FOR SELECT TO authenticated USING (true);
CREATE POLICY "admins manage articles" ON public.articles FOR ALL TO authenticated
  USING (private.has_role(auth.uid(),'admin')) WITH CHECK (private.has_role(auth.uid(),'admin'));
CREATE TRIGGER articles_touch BEFORE UPDATE ON public.articles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "images public read" ON storage.objects FOR SELECT USING (bucket_id = 'images');
CREATE POLICY "admins upload images" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'images' AND private.has_role(auth.uid(),'admin'));
CREATE POLICY "admins update images" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'images' AND private.has_role(auth.uid(),'admin'));
CREATE POLICY "admins delete images" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'images' AND private.has_role(auth.uid(),'admin'));