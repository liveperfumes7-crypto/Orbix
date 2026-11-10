import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { inr, rowsOf } from "@/lib/format";
import FlushMeta from "./FlushMeta";
import Table from "./Table";

export const dynamic = "force-dynamic";

const MONEY = new Set(["revenue_today", "revenue_month", "revenue_total"]);
const ALERT_LINK: Record<string, string> = {
  channel_requests: "/admin/channels",
  organic_buyers_waiting: "/admin/users",
  payments_to_verify: "/admin/payments?today=1",
  open_requests: "/admin/requests",
};
const num = (n: number) => new Intl.NumberFormat("en-IN").format(n);

function Tile({ k, v }: { k: string; v: unknown }) {
  const n = Number(v ?? 0);
  return (
    <div className="card">
      <div className="text-xs uppercase tracking-wide text-muted">{k.replace(/_/g, " ")}</div>
      <div className="mt-1 text-2xl font-semibold">{MONEY.has(k) ? inr(n) : isNaN(n) ? String(v) : num(n)}</div>
    </div>
  );
}

export default async function Dashboard() {
  const sb = supabaseServer();
  const [{ data: d, error: e1 }, { data: p }] = await Promise.all([sb.rpc("admin_dashboard"), sb.rpc("admin_payment_stats")]);
  const dash = (d ?? {}) as Record<string, unknown>;
  const pay = (p ?? {}) as Record<string, unknown>;
  const flat = (o: Record<string, unknown>) => Object.entries(o).filter(([, v]) => v === null || typeof v !== "object");
  const alerts = Object.entries((dash.alerts ?? {}) as Record<string, number>);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <h1 className="text-xl font-semibold">Dashboard</h1>
        <FlushMeta />
      </div>
      {e1 && <p className="text-sm text-danger">{e1.message}</p>}

      {alerts.length > 0 && (
        <section className="space-y-2">
          <h2 className="text-sm font-medium text-muted">Needs attention</h2>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
            {alerts.map(([k, v]) => {
              const n = Number(v ?? 0);
              return (
                <Link key={k} href={ALERT_LINK[k] ?? "/admin"} className={"card block hover:border-primary transition-colors " + (n > 0 ? "border-warning/60" : "")}>
                  <div className="text-xs uppercase tracking-wide text-muted">{k.replace(/_/g, " ")}</div>
                  <div className={"mt-1 text-2xl font-semibold " + (n > 0 ? "text-warning" : "")}>{num(n)}</div>
                </Link>
              );
            })}
          </div>
        </section>
      )}

      <section className="space-y-2">
        <h2 className="text-sm font-medium text-muted">Overview</h2>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">{flat(dash).map(([k, v]) => <Tile key={k} k={k} v={v} />)}</div>
      </section>

      {flat(pay).length > 0 && (
        <section className="space-y-2">
          <h2 className="text-sm font-medium text-muted">Payments</h2>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">{flat(pay).map(([k, v]) => <Tile key={k} k={k} v={v} />)}</div>
        </section>
      )}

      {([
        ["Sales per plan", pay.sales_per_plan, "No paid orders yet."],
        ["Repeat buyers", pay.repeat_buyers, "No repeat buyers yet."],
        ["Installs by campaign", dash.installs_by_campaign, "No installs recorded yet."],
      ] as [string, unknown, string][]).map(([title, data, empty]) => (
        <section key={title} className="space-y-2">
          <h2 className="text-sm font-medium text-muted">{title}</h2>
          <Table rows={rowsOf(data)} empty={empty} />
        </section>
      ))}
    </div>
  );
}
