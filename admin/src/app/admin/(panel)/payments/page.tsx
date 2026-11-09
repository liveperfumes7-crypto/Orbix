import { supabaseServer } from "@/lib/supabase/server";
import { rowsOf } from "@/lib/format";
import Table, { type Action } from "../Table";
import Link from "next/link";

export const dynamic = "force-dynamic";

const ACTIONS: Action[] = [
  { label: "Mark paid", rpc: "admin_mark_paid", prompt: "Enter the 12-digit UTR from the bank statement", args: (r, i) => ({ p_order: r.id, p_utr: i }), show: (r) => r.status !== "paid" },
  { label: "Confirm bank", rpc: "admin_confirm_bank", args: (r) => ({ p_order: r.id }), show: (r) => r.status === "paid" },
  { label: "Reject", rpc: "admin_reject_order", prompt: "Reason / note", danger: true, args: (r, i) => ({ p_order: r.id, p_note: i ?? "" }), show: (r) => r.status !== "paid" && r.status !== "rejected" },
  { label: "Revoke", rpc: "admin_revoke_order", prompt: "Reason / note", danger: true, args: (r, i) => ({ p_order: r.id, p_note: i ?? "" }), show: (r) => r.status === "paid" },
];

export default async function Payments({ searchParams }: { searchParams: { status?: string; today?: string } }) {
  const sb = supabaseServer();
  const { data, error } = await sb.rpc("admin_orders", {
    p_status: searchParams.status ?? null,
    p_verify_today: searchParams.today === "1",
    p_limit: 100,
    p_offset: 0,
  });
  const tabs = [["", "All"], ["pending", "Pending"], ["review", "In review"], ["paid", "Paid"], ["failed", "Failed"], ["cancelled", "Cancelled"]];
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Payments</h1>
      <div className="flex gap-2 flex-wrap">
        {tabs.map(([s, l]) => (
          <Link key={s} className="btn-ghost" href={s ? `/admin/payments?status=${s}` : "/admin/payments"}>{l}</Link>
        ))}
        <Link className="btn-ghost" href="/admin/payments?today=1">Verify against bank (today)</Link>
      </div>
      {error && <p className="text-danger text-sm">{error.message}</p>}
      <Table rows={rowsOf(data)} actions={ACTIONS} />
    </div>
  );
}
