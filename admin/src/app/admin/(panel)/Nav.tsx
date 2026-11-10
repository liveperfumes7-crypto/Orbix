"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV: [string, string][] = [
  ["/admin", "Dashboard"],
  ["/admin/payments", "Payments"],
  ["/admin/users", "Users"],
  ["/admin/channels", "Channels & posts"],
  ["/admin/requests", "Requests"],
  ["/admin/settings", "Settings"],
];

export default function Nav() {
  const path = usePathname();
  return (
    <nav className="flex md:flex-col gap-1 overflow-x-auto" aria-label="Admin sections">
      {NAV.map(([href, label]) => {
        const active = href === "/admin" ? path === "/admin" : path.startsWith(href);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? "page" : undefined}
            className={
              "whitespace-nowrap rounded-lg px-3 py-2 text-sm transition-colors " +
              (active ? "bg-primary/20 text-white font-medium" : "text-muted hover:bg-white/5 hover:text-white")
            }
          >
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
