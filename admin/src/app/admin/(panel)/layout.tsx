import type { Metadata } from "next";
import { Suspense } from "react";
import { requireAdmin } from "@/lib/admin";
import { Flash, SignOut } from "@/components/admin/client";
import Nav from "./Nav";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Orbix Admin", robots: { index: false, follow: false } };

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const { sb, user, role } = await requireAdmin();
  const { data: counts } = await sb.rpc("admin_nav_counts");
  return (
    <div className="min-h-screen bg-gray-50 text-gray-900 md:flex">
      <aside className="border-b border-gray-200 bg-white p-3 md:fixed md:inset-y-0 md:left-0 md:flex md:w-60 md:flex-col md:border-b-0 md:border-r md:p-4">
        <div className="mb-3 flex items-center gap-3 md:mb-5">
          <div className="grid h-9 w-9 place-items-center rounded-lg bg-violet-600 text-sm font-bold text-white">OB</div>
          <span className="font-semibold">Orbix</span>
          <div className="ml-auto text-right text-xs text-gray-500 md:hidden">{role}</div>
        </div>
        <Nav owner={role === "owner"} counts={(counts ?? {}) as Record<string, number>} />
        <div className="mt-3 hidden border-t border-gray-200 pt-3 md:mt-auto md:block">
          <div className="truncate text-xs text-gray-700" title={user.email ?? ""}>{user.email}</div>
          <div className="text-xs capitalize text-gray-500">{role} admin</div>
          <SignOut />
        </div>
      </aside>
      <main className="min-w-0 flex-1 p-4 md:ml-60 md:p-8">
        <div className="mx-auto max-w-6xl">
          <Suspense fallback={null}><Flash /></Suspense>
          {children}
          <div className="mt-8 md:hidden"><SignOut /></div>
        </div>
      </main>
    </div>
  );
}
