import Link from "next/link";
import { redirect } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import SignOut from "./SignOut";

const NAV = [
  ["/admin", "Dashboard"],
  ["/admin/payments", "Payments"],
  ["/admin/users", "Users"],
  ["/admin/channels", "Channel requests"],
  ["/admin/requests", "Requests"],
  ["/admin/settings", "Settings"],
];

export const dynamic = "force-dynamic";

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const sb = supabaseServer();
  const { data: u } = await sb.auth.getUser();
  if (!u.user) redirect("/admin/login");
  const { data: isAdmin } = await sb.rpc("is_admin");
  if (!isAdmin) {
    return (
      <main className="min-h-screen grid place-items-center px-4">
        <div className="card max-w-sm text-center space-y-3">
          <p className="font-semibold">Not an admin account</p>
          <p className="text-sm text-muted">{u.user.email} does not have admin access.</p>
          <SignOut />
        </div>
      </main>
    );
  }
  return (
    <div className="min-h-screen md:flex">
      <aside className="md:w-60 md:min-h-screen bg-[#0E0E1C] border-b md:border-b-0 md:border-r border-border p-4">
        <div className="flex items-center gap-3 mb-4">
          <div className="h-9 w-9 rounded-xl bg-primary grid place-items-center font-bold">OB</div>
          <span className="font-semibold">Orbix Admin</span>
        </div>
        <nav className="flex md:flex-col gap-1 overflow-x-auto">
          {NAV.map(([href, label]) => (
            <Link key={href} href={href} className="whitespace-nowrap rounded-lg px-3 py-2 text-sm text-muted hover:bg-white/5 hover:text-white">
              {label}
            </Link>
          ))}
        </nav>
        <div className="mt-4 text-xs text-muted truncate">{u.user.email}</div>
        <SignOut />
      </aside>
      <main className="flex-1 p-4 md:p-6 min-w-0">{children}</main>
    </div>
  );
}
