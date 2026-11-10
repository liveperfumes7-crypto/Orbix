"use client";
import { useState } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";

type Row = Record<string, any>;
const AUD = ["everyone", "ads", "organic", "none"];

export default function SettingsForms({ mode, pay, plans }: { mode: Row; pay: Row; plans: Row[] }) {
  const sb = supabaseBrowser();
  const [m, setM] = useState<Row>(mode);
  const [p, setP] = useState<Row>(pay);
  const [pl, setPl] = useState<Row[]>(plans);
  const [msg, setMsg] = useState("");
  const [np, setNp] = useState<Row>({ name: "", code: "", price_inr: 49, n: 1, unit: "d" });

  const done = (error: { message: string } | null) => setMsg(error ? "Error: " + error.message : "Saved ✓");
  const setPlan = (i: number, patch: Row) => setPl(pl.map((x, j) => (j === i ? { ...x, ...patch } : x)));

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold">Settings</h1>
      {msg && <p className={"text-sm rounded-xl border px-3 py-2 " + (msg.startsWith("Error") ? "border-danger/50 text-danger" : "border-success/50 text-success")} role="status">{msg}</p>}

      <section className="card space-y-3">
        <h2 className="font-semibold">App mode</h2>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={!!m.free_mode} onChange={(e) => setM({ ...m, free_mode: e.target.checked })} />
          Free mode (no prices anywhere; everyone gets 15 GB)
        </label>
        <label className="block text-sm">Plans visible for
          <select className="input mt-1" value={m.plans_visible_for} onChange={(e) => setM({ ...m, plans_visible_for: e.target.value })}>
            {AUD.map((a) => <option key={a}>{a}</option>)}
          </select>
        </label>
        <label className="block text-sm">Free plans for (promo)
          <select className="input mt-1" value={m.free_plans_for} onChange={(e) => setM({ ...m, free_plans_for: e.target.value })}>
            {AUD.map((a) => <option key={a}>{a}</option>)}
          </select>
        </label>
        <button className="btn" onClick={async () => {
          const { error } = await sb.from("app_mode").update({ free_mode: m.free_mode, plans_visible_for: m.plans_visible_for, free_plans_for: m.free_plans_for }).eq("id", 1);
          done(error);
        }}>Save mode</button>
      </section>

      <section className="card space-y-3">
        <h2 className="font-semibold">Payments (UPI)</h2>
        <label className="block text-sm">UPI ID
          <input className="input mt-1" value={p.upi_id ?? ""} onChange={(e) => setP({ ...p, upi_id: e.target.value.trim() })} />
        </label>
        <label className="block text-sm">Payee name
          <input className="input mt-1" value={p.payee_name ?? ""} onChange={(e) => setP({ ...p, payee_name: e.target.value })} />
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={!!p.enabled} onChange={(e) => setP({ ...p, enabled: e.target.checked })} /> Payments enabled
        </label>
        <label className="block text-sm">Activation
          <select className="input mt-1" value={p.activation_mode} onChange={(e) => setP({ ...p, activation_mode: e.target.value })}>
            <option value="instant">Automatic — the plan starts as soon as the UPI app reports success</option>
            <option value="manual">Manual — I check each payment in my bank app, then mark it paid</option>
          </select>
        </label>
        <button className="btn" onClick={async () => {
          const { error } = await sb.from("payment_settings").update({ upi_id: p.upi_id, payee_name: p.payee_name, enabled: p.enabled, activation_mode: p.activation_mode }).eq("id", 1);
          done(error);
        }}>Save payments</button>
      </section>

      <section className="card space-y-3">
        <h2 className="font-semibold">Plans</h2>
        {pl.map((r, i) => (
          <div key={r.id} className="grid grid-cols-2 md:grid-cols-12 gap-2 items-end border-b border-border/60 pb-3 last:border-0">
            <label className="text-xs col-span-2 md:col-span-3">Name<input className="input mt-1" value={r.name} onChange={(e) => setPlan(i, { name: e.target.value })} /></label>
            <label className="text-xs md:col-span-2">Price ₹<input className="input mt-1" type="number" min={1} value={r.price_inr} onChange={(e) => setPlan(i, { price_inr: Number(e.target.value) })} /></label>
            <label className="text-xs md:col-span-3">Duration
              <div className="mt-1 flex gap-1">
                <input className="input" type="number" min={1} value={r.duration_hours > 0 ? r.duration_hours : r.duration_days}
                  onChange={(e) => { const n = Math.max(1, Number(e.target.value) || 1); setPlan(i, r.duration_hours > 0 ? { duration_hours: n } : { duration_days: n }); }} />
                <select className="input max-w-[92px]" aria-label="Duration unit" value={r.duration_hours > 0 ? "h" : "d"}
                  onChange={(e) => setPlan(i, e.target.value === "h" ? { duration_hours: Math.max(1, r.duration_days) } : { duration_hours: 0 })}>
                  <option value="d">Days</option>
                  <option value="h">Hours</option>
                </select>
              </div>
            </label>
            <label className="text-xs md:col-span-2">Badge
              <select className="input mt-1" value={r.badge ?? ""} onChange={(e) => setPlan(i, { badge: e.target.value || null })}>
                <option value="">None</option>
                <option>Popular</option>
                <option>Best value</option>
              </select>
            </label>
            <div className="col-span-2 md:col-span-2 flex items-center gap-3 flex-wrap">
              <label className="text-xs flex items-center gap-1"><input type="checkbox" checked={!!r.active} onChange={(e) => setPlan(i, { active: e.target.checked })} />Active</label>
              <label className="text-xs flex items-center gap-1"><input type="checkbox" checked={!!r.free_eligible} onChange={(e) => setPlan(i, { free_eligible: e.target.checked })} />Free promo</label>
              <button className="btn-ghost" onClick={async () => {
                if (!String(r.name).trim() || !(Number(r.price_inr) >= 1)) return setMsg("Error: a plan needs a name and a price of at least ₹1");
                const { error } = await sb.from("plans").update({ name: String(r.name).trim(), price_inr: Number(r.price_inr), duration_days: Math.max(1, Number(r.duration_days) || 1), duration_hours: r.duration_hours ?? 0, badge: r.badge || null, active: r.active, free_eligible: r.free_eligible }).eq("id", r.id);
                done(error);
              }}>Save</button>
            </div>
          </div>
        ))}
        <div className="rounded-xl border border-dashed border-border p-3 space-y-2">
          <div className="text-sm font-medium">Add a plan</div>
          <div className="grid grid-cols-2 md:grid-cols-12 gap-2 items-end">
            <label className="text-xs col-span-2 md:col-span-4">Name<input className="input mt-1" placeholder="e.g. Day Pass" value={np.name} onChange={(e) => setNp({ ...np, name: e.target.value })} /></label>
            <label className="text-xs md:col-span-2">Price ₹<input className="input mt-1" type="number" min={1} value={np.price_inr} onChange={(e) => setNp({ ...np, price_inr: Number(e.target.value) })} /></label>
            <label className="text-xs md:col-span-4">Duration
              <div className="mt-1 flex gap-1">
                <input className="input" type="number" min={1} value={np.n} onChange={(e) => setNp({ ...np, n: Math.max(1, Number(e.target.value) || 1) })} />
                <select className="input max-w-[92px]" aria-label="Duration unit" value={np.unit} onChange={(e) => setNp({ ...np, unit: e.target.value })}>
                  <option value="d">Days</option>
                  <option value="h">Hours</option>
                </select>
              </div>
            </label>
            <button className="btn col-span-2 md:col-span-2" onClick={async () => {
              const name = String(np.name).trim();
              if (name.length < 2 || !(Number(np.price_inr) >= 1)) return setMsg("Error: a plan needs a name and a price of at least ₹1");
              const code = (name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "plan").slice(0, 20) + "-" + Date.now().toString(36).slice(-4);
              const position = pl.reduce((m, x) => Math.max(m, Number(x.position) || 0), 0) + 1;
              const { data, error } = await sb.from("plans").insert({ code, name, price_inr: Number(np.price_inr), duration_days: np.unit === "d" ? np.n : 1, duration_hours: np.unit === "h" ? np.n : 0, position }).select("*").single();
              if (!error && data) { setPl([...pl, data]); setNp({ name: "", code: "", price_inr: 49, n: 1, unit: "d" }); }
              done(error);
            }}>Add plan</button>
          </div>
        </div>
        <p className="text-xs text-muted">Changing a price never affects orders already created. To remove a plan, untick Active and save.</p>
      </section>
    </div>
  );
}
