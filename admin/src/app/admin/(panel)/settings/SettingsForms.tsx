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

  const done = (error: { message: string } | null) => setMsg(error ? "Error: " + error.message : "Saved ✓");
  const setPlan = (i: number, patch: Row) => setPl(pl.map((x, j) => (j === i ? { ...x, ...patch } : x)));

  return (
    <div className="space-y-6 max-w-3xl">
      <h1 className="text-xl font-semibold">Settings</h1>
      {msg && <p className="text-sm" role="status">{msg}</p>}

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
            <option value="manual">Manual — I verify each payment in my bank app (recommended)</option>
            <option value="instant">Instant — activate when the app reports success (can be faked)</option>
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
          <div key={r.id} className="grid grid-cols-2 md:grid-cols-6 gap-2 items-end">
            <label className="text-xs col-span-2 md:col-span-1">Name<input className="input" value={r.name} onChange={(e) => setPlan(i, { name: e.target.value })} /></label>
            <label className="text-xs">Price ₹<input className="input" type="number" min={0} value={r.price_inr} onChange={(e) => setPlan(i, { price_inr: Number(e.target.value) })} /></label>
            <label className="text-xs">Days<input className="input" type="number" min={1} value={r.duration_days} onChange={(e) => setPlan(i, { duration_days: Number(e.target.value) })} /></label>
            <label className="text-xs flex items-center gap-1"><input type="checkbox" checked={!!r.active} onChange={(e) => setPlan(i, { active: e.target.checked })} />Active</label>
            <label className="text-xs flex items-center gap-1"><input type="checkbox" checked={!!r.free_eligible} onChange={(e) => setPlan(i, { free_eligible: e.target.checked })} />Free-eligible</label>
            <button className="btn-ghost" onClick={async () => {
              const { error } = await sb.from("plans").update({ name: r.name, price_inr: r.price_inr, duration_days: r.duration_days, active: r.active, free_eligible: r.free_eligible }).eq("id", r.id);
              done(error);
            }}>Save</button>
          </div>
        ))}
        <p className="text-xs text-muted">Changing a price never affects orders already created; they keep their snapshot.</p>
      </section>
    </div>
  );
}
