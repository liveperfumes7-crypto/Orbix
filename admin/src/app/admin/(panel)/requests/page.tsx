import { supabaseServer } from "@/lib/supabase/server";
import { rowsOf } from "@/lib/format";
import Table, { type Action } from "../Table";

export const dynamic = "force-dynamic";

const ACTIONS: Action[] = [
  { label: "Close", rpc: "admin_close_request", args: { p_id: "$row.id" }, show: [{ field: "status", not: "closed" }] },
  { label: "Grant full access", rpc: "set_ads_access", args: { p_user: "$row.user_id", p_status: "approved" }, show: [{ field: "kind", is: "full_access" }, { field: "user_id", truthy: true }] },
];

export default async function Requests() {
  const sb = supabaseServer();
  const { data, error } = await sb.rpc("admin_requests", { p_status: "open" });
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Requests &amp; reports</h1>
      {error && <p className="text-danger text-sm">{error.message}</p>}
      <Table rows={rowsOf(data)} actions={ACTIONS} empty="No open requests." />
    </div>
  );
}
