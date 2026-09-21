import { createFileRoute, Link, Outlet, useRouterState } from "@tanstack/react-router";
import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAuth } from "@/lib/admin";

export const Route = createFileRoute("/admin")({
  head: () => ({
    meta: [
      { title: "Admin Panel — Vesco Science" },
      { name: "description", content: "Manage Vesco Science pages, settings and resources." },
      { name: "robots", content: "noindex" },
      { property: "og:title", content: "Admin Panel — Vesco Science" },
      { property: "og:description", content: "Internal content management for Vesco Science." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AdminLayout,
});

type NavItem = {
  to:
    | "/admin"
    | "/admin/products"
    | "/admin/articles"
    | "/admin/site-editor"
    | "/admin/pages"
    | "/admin/media"
    | "/admin/resources"
    | "/admin/settings"
    | "/admin/ai-assistant";
  label: string;
  icon: string;
  exact?: boolean;
  group: string;
};

const NAV: NavItem[] = [
  // Overview
  { to: "/admin",             label: "Dashboard",        icon: "⊞", exact: true, group: "Overview" },
  // Content
  { to: "/admin/products",    label: "Products (79)",    icon: "🧪", group: "Content" },
  { to: "/admin/articles",    label: "Articles & Blogs",  icon: "📰", group: "Content" },
  { to: "/admin/site-editor", label: "Page Editor",       icon: "✏️", group: "Content" },
  { to: "/admin/pages",       label: "Visual Builder",    icon: "🏗", group: "Content" },
  { to: "/admin/media",       label: "Media Manager",     icon: "🖼", group: "Content" },
  // Settings & Tools
  { to: "/admin/resources",   label: "Resources & Files", icon: "📁", group: "Tools" },
  { to: "/admin/settings",    label: "Site Settings",     icon: "⚙️", group: "Tools" },
  { to: "/admin/ai-assistant",label: "AI Assistant",      icon: "🤖", group: "Tools" },
];

const NAV_GROUPS = ["Overview", "Content", "Tools"] as const;

function AdminLayout() {
  const { session, isAdmin, loading } = useAdminAuth();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const [collapsed, setCollapsed] = useState(false);

  if (loading) {
    return <div className="p-16 text-center text-sm text-muted-foreground">Loading…</div>;
  }
  if (!session) return <LoginCard />;
  if (!isAdmin) {
    return (
      <div className="p-16 text-center">
        <p className="text-sm text-muted-foreground">
          This account has no admin access. Ask an existing admin to grant it.
        </p>
        <button
          onClick={() => supabase.auth.signOut()}
          className="mt-6 rounded-sm border border-navy/20 px-5 py-2 text-xs font-semibold uppercase tracking-[0.12em]"
        >
          Sign out
        </button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="flex">
        {/* ── Sidebar ── */}
        <aside className={`sticky top-0 h-screen flex-shrink-0 border-r border-hairline bg-card transition-all duration-200 ${collapsed ? "w-14" : "w-56"}`}>
          <div className="flex h-full flex-col">
            {/* Logo area */}
            <div className="flex items-center justify-between border-b border-hairline px-3 py-4">
              {!collapsed && (
                <div>
                  <p className="text-[0.62rem] font-semibold uppercase tracking-[0.18em] text-science">Vesco</p>
                  <p className="text-[0.72rem] font-bold text-navy">Admin Panel</p>
                </div>
              )}
              <button
                onClick={() => setCollapsed(!collapsed)}
                className="rounded-sm p-1.5 text-muted-foreground hover:bg-navy/5 hover:text-navy"
                title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
              >
                {collapsed ? "→" : "←"}
              </button>
            </div>

            {/* Nav */}
            <nav className="flex-1 overflow-y-auto px-2 py-3 space-y-4">
              {NAV_GROUPS.map((group) => {
                const items = NAV.filter((n) => n.group === group);
                return (
                  <div key={group}>
                    {!collapsed && (
                      <p className="mb-1 px-2 text-[0.6rem] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
                        {group}
                      </p>
                    )}
                    <div className="space-y-0.5">
                      {items.map((n) => {
                        const active = n.exact ? pathname === n.to : pathname.startsWith(n.to);
                        return (
                          <Link
                            key={n.to}
                            to={n.to}
                            title={collapsed ? n.label : undefined}
                            className={`flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium transition-colors ${
                              active ? "bg-navy text-white" : "text-navy hover:bg-navy/5"
                            } ${collapsed ? "justify-center" : ""}`}
                          >
                            <span className="text-base leading-none flex-shrink-0">{n.icon}</span>
                            {!collapsed && <span className="truncate">{n.label}</span>}
                          </Link>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </nav>

            {/* User info */}
            <div className="border-t border-hairline p-3">
              {!collapsed && (
                <p className="mb-2 break-all text-[0.65rem] text-muted-foreground">{session.user.email}</p>
              )}
              <div className="flex items-center gap-2">
                <a href="/" target="_blank" rel="noreferrer"
                   className={`rounded-sm border border-hairline px-2 py-1.5 text-[0.62rem] font-semibold uppercase tracking-[0.1em] text-navy hover:bg-navy/5 ${collapsed ? "w-full text-center" : ""}`}
                   title="View site">
                  {collapsed ? "🌐" : "View Site ↗"}
                </a>
                {!collapsed && (
                  <button
                    onClick={() => supabase.auth.signOut()}
                    className="text-[0.62rem] font-semibold uppercase tracking-[0.1em] text-navy hover:text-science"
                  >
                    Sign out
                  </button>
                )}
              </div>
            </div>
          </div>
        </aside>

        {/* ── Main content ── */}
        <div className="min-w-0 flex-1 overflow-auto">
          <div className="min-h-screen px-6 py-8 lg:px-10">
            <Outlet />
          </div>
        </div>
      </div>
    </div>
  );
}

function LoginCard() {
  const [mode, setMode] = useState<"in" | "up">("in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const fn =
      mode === "in"
        ? supabase.auth.signInWithPassword({ email, password })
        : supabase.auth.signUp({
            email,
            password,
            options: { emailRedirectTo: `${window.location.origin}/admin` },
          });
    const { error } = await fn;
    setBusy(false);
    if (error) setMsg(error.message);
    else if (mode === "up") setMsg("Account created. You can sign in now.");
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-6">
      <form
        onSubmit={submit}
        className="w-full max-w-sm border border-hairline bg-card p-8 shadow-sm"
      >
        <p className="text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-science">
          Vesco Science
        </p>
        <h1 className="mt-2 text-2xl font-semibold text-navy">Admin Panel</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {mode === "in" ? "Sign in to manage the website." : "Create the first admin account."}
        </p>
        <label className="mt-6 grid gap-2">
          <span className="text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-navy/70">Email</span>
          <input
            required type="email" value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="border border-hairline bg-background px-4 py-3 text-sm outline-none focus:border-teal"
          />
        </label>
        <label className="mt-4 grid gap-2">
          <span className="text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-navy/70">Password</span>
          <input
            required minLength={6} type="password" value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="border border-hairline bg-background px-4 py-3 text-sm outline-none focus:border-teal"
          />
        </label>
        {msg ? <p className="mt-4 text-sm text-science">{msg}</p> : null}
        <button
          disabled={busy}
          className="mt-6 w-full rounded-sm bg-teal px-6 py-3 text-[0.78rem] font-semibold uppercase tracking-[0.14em] text-[#05231f] disabled:opacity-60"
        >
          {busy ? "Please wait…" : mode === "in" ? "Sign in" : "Create account"}
        </button>
        <button
          type="button"
          onClick={() => setMode(mode === "in" ? "up" : "in")}
          className="mt-4 w-full text-xs font-semibold uppercase tracking-[0.12em] text-navy hover:text-science"
        >
          {mode === "in" ? "Create first admin account" : "Back to sign in"}
        </button>
      </form>
    </div>
  );
}
