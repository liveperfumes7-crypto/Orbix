import Link from "next/link";
import type { ReactNode } from "react";

const cx = (...a: (string | false | null | undefined)[]) => a.filter(Boolean).join(" ");

export function PageHeader({ title, sub, children }: { title: string; sub?: string; children?: ReactNode }) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-xl font-semibold text-gray-900">{title}</h1>
        {sub && <p className="mt-0.5 text-sm text-gray-500">{sub}</p>}
      </div>
      {children && <div className="flex flex-wrap items-center gap-2">{children}</div>}
    </div>
  );
}

export function Card({ title, sub, children, className }: { title?: string; sub?: string; children: ReactNode; className?: string }) {
  return (
    <section className={cx("rounded-xl border border-gray-200 bg-white p-4 shadow-sm", className)}>
      {title && <h2 className="text-sm font-semibold text-gray-900">{title}</h2>}
      {sub && <p className="mt-0.5 text-xs text-gray-500">{sub}</p>}
      <div className={title || sub ? "mt-3" : ""}>{children}</div>
    </section>
  );
}

const BTN = {
  primary: "bg-violet-600 text-white hover:bg-violet-700",
  secondary: "border border-gray-300 bg-white text-gray-700 hover:bg-gray-50",
  danger: "bg-red-600 text-white hover:bg-red-700",
  success: "bg-green-600 text-white hover:bg-green-700",
};
export type Variant = keyof typeof BTN;
export const btnClass = (v: Variant = "primary", small = false) =>
  cx("inline-flex items-center justify-center rounded-lg font-medium transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-400 disabled:opacity-50",
    small ? "px-2.5 py-1 text-xs" : "px-3.5 py-2 text-sm", BTN[v]);

export function Button({ variant = "primary", small, children, ...p }: { variant?: Variant; small?: boolean; children: ReactNode } & React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button {...p} className={cx(btnClass(variant, small), p.className)}>{children}</button>;
}
export function LinkButton({ href, variant = "secondary", small, children }: { href: string; variant?: Variant; small?: boolean; children: ReactNode }) {
  return <Link href={href} className={btnClass(variant, small)}>{children}</Link>;
}

export function Field({ label, hint, children, className }: { label: string; hint?: string; children: ReactNode; className?: string }) {
  return (
    <label className={cx("block text-sm", className)}>
      <span className="mb-1 block font-medium text-gray-700">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-gray-500">{hint}</span>}
    </label>
  );
}
const INPUT = "w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder:text-gray-400 focus:border-violet-500 focus:outline-none focus:ring-1 focus:ring-violet-500 disabled:bg-gray-100 read-only:bg-gray-100";
export const Input = (p: React.InputHTMLAttributes<HTMLInputElement>) => <input {...p} className={cx(INPUT, p.className)} />;
export const Textarea = (p: React.TextareaHTMLAttributes<HTMLTextAreaElement>) => <textarea {...p} className={cx(INPUT, p.className)} />;
export const Select = (p: React.SelectHTMLAttributes<HTMLSelectElement>) => <select {...p} className={cx(INPUT, p.className)} />;
export const Hidden = ({ name, value }: { name: string; value: string | number | null | undefined }) => <input type="hidden" name={name} value={value ?? ""} />;

const TONES = {
  gray: "bg-gray-100 text-gray-700", red: "bg-red-100 text-red-700", green: "bg-green-100 text-green-700",
  amber: "bg-amber-100 text-amber-800", blue: "bg-blue-100 text-blue-700", purple: "bg-violet-100 text-violet-700",
};
export type Tone = keyof typeof TONES;
export function Badge({ tone = "gray", children }: { tone?: Tone; children: ReactNode }) {
  return <span className={cx("inline-block whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium", TONES[tone])}>{children}</span>;
}
export function AudienceBadge({ value }: { value: string | null | undefined }) {
  if (value === "ads") return <Badge tone="blue">Ads only</Badge>;
  if (value === "organic") return <Badge tone="purple">Organic only</Badge>;
  return <Badge>Everyone</Badge>;
}
const STATUS: Record<string, Tone> = {
  paid: "green", approved: "green", published: "green", active: "green", sent: "green", closed: "gray",
  pending: "amber", review: "amber", submitted: "amber", open: "amber", scheduled: "blue", draft: "gray",
  failed: "red", rejected: "red", revoked: "red", cancelled: "gray", none: "gray",
};
export function StatusBadge({ value }: { value: string | null | undefined }) {
  const v = value ?? "none";
  return <Badge tone={STATUS[v] ?? "gray"}>{v.replace(/_/g, " ")}</Badge>;
}
export function SourceBadge({ value }: { value: string | null | undefined }) {
  return value === "ads" ? <Badge tone="blue">ads</Badge> : <Badge tone="purple">organic</Badge>;
}

export function Table({ children, min = 640 }: { children: ReactNode; min?: number }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
      <table className="w-full text-sm" style={{ minWidth: min }}>{children}</table>
    </div>
  );
}
export const Th = ({ children, className }: { children?: ReactNode; className?: string }) => (
  <th className={cx("border-b border-gray-200 bg-gray-50 px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-gray-500", className)}>{children}</th>
);
export const Td = ({ children, className, colSpan }: { children?: ReactNode; className?: string; colSpan?: number }) => (
  <td colSpan={colSpan} className={cx("border-b border-gray-100 px-3 py-2 align-top text-gray-800", className)}>{children}</td>
);
export function Empty({ children }: { children: ReactNode }) {
  return <div className="rounded-xl border border-dashed border-gray-300 bg-white p-8 text-center text-sm text-gray-500">{children}</div>;
}
export function Stat({ label, value, tone }: { label: string; value: ReactNode; tone?: "warn" }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs font-medium uppercase tracking-wide text-gray-500">{label}</div>
      <div className={cx("mt-1 text-2xl font-semibold", tone === "warn" ? "text-amber-600" : "text-gray-900")}>{value}</div>
    </div>
  );
}
export function Tabs({ items, current }: { items: { href: string; label: string; key: string; count?: number }[]; current: string }) {
  return (
    <div className="mb-4 flex gap-1 overflow-x-auto border-b border-gray-200">
      {items.map((t) => (
        <Link key={t.key} href={t.href} aria-current={t.key === current ? "page" : undefined}
          className={cx("whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium", t.key === current ? "border-violet-600 text-violet-700" : "border-transparent text-gray-500 hover:text-gray-800")}>
          {t.label}{t.count ? <span className="ml-1.5 rounded-full bg-red-500 px-1.5 py-0.5 text-[10px] text-white">{t.count}</span> : null}
        </Link>
      ))}
    </div>
  );
}
export function ErrorNote({ error }: { error?: { message: string } | null }) {
  return error ? <p role="alert" className="mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error.message}</p> : null;
}
