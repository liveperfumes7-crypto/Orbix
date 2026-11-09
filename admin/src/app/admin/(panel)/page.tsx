import { supabaseServer } from "@/lib/supabase/server";
import { inr } from "@/lib/format";
import FlushMeta from "./FlushMeta";

export const dynamic = "force-dynamic";

const MONEY = new Set(["revenue_today", "revenue_month", "revenue_total"]);
const ALERT = new Set(["alerts", "channel_requests", "organic_buyers_waiting", "payments_to_verify", "open_requests"]);

export default async function Dashboard() {
  const sb = supabaseServer();
  const [{ data: d }, { data: p }] = await Promise.all([sb.rpc("admin_dashboard"), sb.rpc("admin_payment_stats")]);
  const flat = (o: Record<string, unknown> | null) =>
    Object.entries(o ?? {}).filter(([, v]) => typeof v !== "object" || v === null);
  const nested = Object.entries({ ...(d ?? {}), ...(p ?? {}) }).filter(([, v]) => v && typeof v === "object");

  const tile = ([k, v]: [string, unknown]) => {
    const n = Number(v ?? 0);
    const hot = ALERT.has(k) && n > 0;
    return (
      <div key={k} className="card">
        <div className="text-xs uppercase tracking-wide text-muted">{k.replace(/_/g, " ")}</div>
        <div className={"mt-1 text-2xl font-semibold " + (hot ? "text-danger" : "")}>
          {MONEY.has(k) ? inr(n) : isNaN(n) ? String(v) : new Intl.NumberFormat("en-IN").format(n)}
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <h1 className="text-xl font-semibold">Dashboard</h1>
        <FlushMeta />
      </div>
      <section className="grid grid-cols-2 lg:grid-cols-4 gap-3">{flat(d).map(tile)}</section>
      <h2 className="font-semibold">Payments</h2>
      <section className="grid grid-cols-2 lg:grid-cols-4 gap-3">{flat(p).map(tile)}</section>
      {nested.map(([k, v]) => (
        <section key={k} className="card">
          <h3 className="mb-2 text-sm font-medium capitalize">{k.replace(/_/g, " ")}</h3>
          <pre className="text-xs text-muted overflow-x-auto">{JSON.stringify(v, null, 2)}</pre>
        </section>
      ))}
    </div>
  );
}
