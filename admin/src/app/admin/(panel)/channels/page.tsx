import { supabaseServer } from "@/lib/supabase/server";
import { rowsOf } from "@/lib/format";
import Table, { type Action } from "../Table";

export const dynamic = "force-dynamic";

const ACTIONS: Action[] = [
  { label: "Approve (all)", rpc: "review_channel", args: (r) => ({ p_channel: r.id, p_approve: true, p_audience: "all" }) },
  { label: "Approve (ads only)", rpc: "review_channel", args: (r) => ({ p_channel: r.id, p_approve: true, p_audience: "ads" }) },
  { label: "Approve (organic only)", rpc: "review_channel", args: (r) => ({ p_channel: r.id, p_approve: true, p_audience: "organic" }) },
  { label: "Reject", rpc: "review_channel", danger: true, args: (r) => ({ p_channel: r.id, p_approve: false, p_audience: "all" }) },
];

export default async function Channels() {
  const sb = supabaseServer();
  const { data, error } = await sb.rpc("admin_channel_requests");
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Channel requests</h1>
      {error && <p className="text-danger text-sm">{error.message}</p>}
      <Table rows={rowsOf(data)} actions={ACTIONS} empty="No channels are waiting for approval." />
    </div>
  );
}
