import { supabaseServer } from "@/lib/supabase/server";
import { rowsOf } from "@/lib/format";
import Table, { type Action } from "../Table";
import Link from "next/link";

export const dynamic = "force-dynamic";

const ACTIONS: Action[] = [
  { label: "Mark paid", rpc: "admin_mark_paid", prompt: "Enter the 12-digit UTR from the bank statement", args: { p_order: "$row.id", p_utr: "$input" }, show: [{ field: "status", not: "paid" }] },
  { label: "Confirm bank", rpc: "admin_confirm_bank", args: { p_order: "$row.id" }, show: [{ field: "status", is: "paid" }] },
  { label: "Reject", rpc: "admin_reject_order", prompt: "Reason / note", danger: true, args: { p_order: "$row.id", p_note: "$input" }, show: [{ field: "status", not: "paid" }, { field: "status", not: "rejected" }] },
  { label: "Revoke", rpc: "admin_revoke_order", prompt: "Reason / note", danger: true, args: { p_order: "$row.id", p_note: "$input" }, show: [{ field: "status", is: "paid" }] },
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
          <Link key={s} className={"btn-ghost " + ((searchParams.status ?? "") === s && searchParams.today !== "1" ? "border-primary bg-primary/15" : "")} href={s ? `/admin/payments?status=${s}` : "/admin/payments"}>{l}</Link>
        ))}
        <Link className={"btn-ghost " + (searchParams.today === "1" ? "border-primary bg-primary/15" : "")} href="/admin/payments?today=1">Verify against bank (today)</Link>
      </div>
      {error && <p className="text-danger text-sm">{error.message}</p>}
      <Table rows={rowsOf(data)} actions={ACTIONS} empty="No payments in this view." />
    </div>
  );
}
