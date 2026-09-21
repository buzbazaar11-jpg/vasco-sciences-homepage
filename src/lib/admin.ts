import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import type { Session } from "@supabase/supabase-js";

export type TextAlign = "left" | "center" | "right";
export type ColSize = 1 | 2 | 3 | 4 | 6 | 12;

export type Block =
  | { id: string; type: "heading"; text: string; align?: TextAlign; level?: 1 | 2 | 3 | 4; color?: string; fontSize?: string }
  | { id: string; type: "text"; text: string; align?: TextAlign; color?: string; fontSize?: string }
  | { id: string; type: "richtext"; html: string }
  | { id: string; type: "image"; url: string; alt?: string; width?: string; radius?: string; caption?: string }
  | { id: string; type: "button"; label: string; href: string; variant?: "solid" | "outline" | "ghost"; align?: TextAlign }
  | { id: string; type: "divider"; style?: "line" | "dots" | "space"; spacing?: string }
  | { id: string; type: "spacer"; height: string }
  | { id: string; type: "columns"; cols: Block[][]; gap?: string; colSizes?: string[] }
  | { id: string; type: "card"; title: string; body: string; num?: string; icon?: string }
  | { id: string; type: "hero"; heading: string; subheading?: string; body?: string; imageUrl?: string; ctaLabel?: string; ctaHref?: string }
  | { id: string; type: "stats"; items: { label: string; value: string }[] }
  | { id: string; type: "list"; items: string[]; style?: "bullet" | "numbered" | "check" }
  | { id: string; type: "video"; url: string; caption?: string }
  | { id: string; type: "embed"; html: string; caption?: string }
  | { id: string; type: "quote"; text: string; author?: string }
  | { id: string; type: "badge"; items: string[]; color?: string }
  | { id: string; type: "accordion"; items: { q: string; a: string }[] }
  | { id: string; type: "gallery"; images: { url: string; alt?: string }[]; cols?: 2 | 3 | 4 }
  | { id: string; type: "cta"; heading: string; body?: string; primaryLabel: string; primaryHref: string; secondaryLabel?: string; secondaryHref?: string; dark?: boolean }
  | { id: string; type: "section_header"; eyebrow?: string; title: string; intro?: string; align?: TextAlign }
  | { id: string; type: "raw_html"; html: string };

/** All available block type keys */
export const BLOCK_TYPES = [
  "heading", "text", "richtext", "image", "button", "divider", "spacer",
  "columns", "card", "hero", "stats", "list", "video", "quote", "badge",
  "accordion", "gallery", "cta", "section_header", "raw_html",
] as const;

export type BlockType = (typeof BLOCK_TYPES)[number];

export type PageRow = {
  id: string;
  slug: string;
  title_en: string;
  title_ko: string;
  description_en: string;
  description_ko: string;
  blocks: Block[];
  published: boolean;
  updated_at: string;
};

// SiteSettings is defined in src/lib/siteSettings.ts — re-export here for
// backward-compat so existing imports of SiteSettings from @/lib/admin still work.
export type { SiteSettings } from "@/lib/siteSettings";

export type ResourceRow = {
  id: string;
  title: string;
  category: string;
  file_url: string;
  file_path: string;
  restricted: boolean;
  sort_order: number;
};

export const newId = () => Math.random().toString(36).slice(2, 10);

/** Auth session + admin-role state for the admin panel. */
export function useAdminAuth() {
  const [session, setSession] = useState<Session | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => {
      setSession(s);
      if (!s) {
        setIsAdmin(false);
        setLoading(false);
      }
    });
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (!data.session) setLoading(false);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) return;
    let active = true;
    setLoading(true);
    supabase
      .from("user_roles")
      .select("role")
      .eq("user_id", session.user.id)
      .eq("role", "admin")
      .maybeSingle()
      .then(({ data, error }) => {
        if (!active) return;
        // If table doesn't exist yet (new Supabase project), treat as admin
        // so the user can complete setup. Remove this fallback after setup.
        if (error?.code === "42P01") {
          setIsAdmin(true);
        } else {
          setIsAdmin(Boolean(data));
        }
        setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [session]);

  return { session, isAdmin, loading };
}

/**
 * The public Supabase Storage bucket for all site images/files.
 * Bucket name: "images" — must be set to PUBLIC in Supabase dashboard.
 * Public URL never expires and works on the live site without authentication.
 */
export const STORAGE_BUCKET = "images";

/**
 * Upload a file to the public "images" bucket.
 * Returns a permanent public URL (no expiry, works on the live site).
 * Requires the bucket to be set to PUBLIC in Supabase Storage settings.
 */
export async function uploadSiteFile(file: File, folder = "uploads") {
  const safeName = `${Date.now()}-${file.name.replace(/[^\w.\-]+/g, "_")}`;
  const path = folder ? `${folder}/${safeName}` : safeName;

  const { error } = await supabase.storage.from(STORAGE_BUCKET).upload(path, file, {
    cacheControl: "31536000", // 1 year cache
    upsert: false,
  });
  if (error) throw error;

  // getPublicUrl() returns a permanent URL — no expiry, no auth needed.
  // This is what makes images show on the public site.
  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return { path, url: data.publicUrl };
}

/**
 * Upload an image from user's PC directly to Supabase Storage bucket.
 * Returns public image URL or DataURL fallback for instant visibility.
 */
export async function uploadAdminImage(file: File, folder = "uploads"): Promise<string> {
  try {
    const safeName = `${Date.now()}-${file.name.replace(/[^\w.\-]+/g, "_")}`;
    const path = folder ? `${folder}/${safeName}` : safeName;

    const { error } = await supabase.storage.from(STORAGE_BUCKET).upload(path, file, {
      cacheControl: "31536000",
      upsert: true,
    });

    if (!error) {
      const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
      if (data?.publicUrl) {
        return data.publicUrl;
      }
    } else {
      console.warn("Supabase storage upload error:", error.message);
    }
  } catch (err) {
    console.warn("Storage upload exception:", err);
  }

  // Fallback to DataURL so local PC images work immediately even offline
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      resolve(reader.result as string);
    };
    reader.readAsDataURL(file);
  });
}

/**
 * Get a permanent public URL for a file already in the images bucket.
 */
export function getPublicUrl(path: string): string {
  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}
