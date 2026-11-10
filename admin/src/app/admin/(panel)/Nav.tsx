"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

type Item = { href: string; label: string; count?: string; owner?: boolean };
const NAV: Item[] = [
  { href: "/admin", label: "Dashboard" },
  { href: "/admin/channels", label: "Channels", count: "channels" },
  { href: "/admin/posts", label: "Posts" },
  { href: "/admin/approvals", label: "Approvals", count: "approvals", owner: true },
  { href: "/admin/payments", label: "Payments", count: "payments", owner: true },
  { href: "/admin/meta", label: "Meta Pixel", owner: true },
  { href: "/admin/users", label: "Users", owner: true },
  { href: "/admin/requests", label: "Requests", count: "requests", owner: true },
  { href: "/admin/plans", label: "Plans", owner: true },
  { href: "/admin/admins", label: "Admins", owner: true },
];

export default function Nav({ owner, counts }: { owner: boolean; counts: Record<string, number> }) {
  const path = usePathname();
  return (
    <nav className="flex gap-1 overflow-x-auto md:flex-col md:overflow-visible" aria-label="Admin sections">
      {NAV.filter((n) => owner || !n.owner).map((n) => {
        const active = n.href === "/admin" ? path === "/admin" : path.startsWith(n.href);
        const c = n.count ? counts[n.count] ?? 0 : 0;
        return (
          <Link key={n.href} href={n.href} aria-current={active ? "page" : undefined}
            className={"flex items-center justify-between gap-2 whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium transition-colors " + (active ? "bg-violet-50 text-violet-700" : "text-gray-600 hover:bg-gray-100 hover:text-gray-900")}>
            {n.label}
            {c > 0 && <span className="rounded-full bg-red-500 px-1.5 py-0.5 text-[10px] font-semibold leading-none text-white" aria-label={`${c} waiting`}>{c}</span>}
          </Link>
        );
      })}
    </nav>
  );
}
