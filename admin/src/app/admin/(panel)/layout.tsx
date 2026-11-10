import { redirect } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import SignOut from "./SignOut";
import Nav from "./Nav";

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
      <aside className="md:w-60 md:min-h-screen md:sticky md:top-0 md:h-screen bg-[#0E0E1C] border-b md:border-b-0 md:border-r border-border p-4 md:flex md:flex-col">
        <div className="flex items-center gap-3 mb-4">
          <div className="h-9 w-9 rounded-xl bg-brand grid place-items-center font-bold text-sm">OB</div>
          <span className="font-semibold">Orbix Admin</span>
        </div>
        <Nav />
        <div className="mt-4 md:mt-auto text-xs text-muted truncate" title={u.user.email ?? ""}>{u.user.email}</div>
        <SignOut />
      </aside>
      <main className="flex-1 p-4 md:p-8 min-w-0"><div className="mx-auto max-w-6xl">{children}</div></main>
    </div>
  );
}
