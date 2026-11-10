import { supabaseServer } from "@/lib/supabase/server";
import { rowsOf } from "@/lib/format";
import Table, { type Action } from "../Table";

export const dynamic = "force-dynamic";

const REQUEST_ACTIONS: Action[] = [
  { label: "Approve (all)", rpc: "review_channel", args: { p_channel: "$row.id", p_approve: true, p_audience: "all" } },
  { label: "Approve (ads only)", rpc: "review_channel", args: { p_channel: "$row.id", p_approve: true, p_audience: "ads" } },
  { label: "Approve (organic only)", rpc: "review_channel", args: { p_channel: "$row.id", p_approve: true, p_audience: "organic" } },
  { label: "Reject", rpc: "review_channel", danger: true, args: { p_channel: "$row.id", p_approve: false, p_audience: "all" } },
];

const CHANNEL_ACTIONS: Action[] = [
  { label: "Show to all", rpc: "review_channel", args: { p_channel: "$row.id", p_approve: true, p_audience: "all" }, show: [{ field: "audience", not: "all" }] },
  { label: "Ads only", rpc: "review_channel", args: { p_channel: "$row.id", p_approve: true, p_audience: "ads" }, show: [{ field: "audience", not: "ads" }] },
  { label: "Organic only", rpc: "review_channel", args: { p_channel: "$row.id", p_approve: true, p_audience: "organic" }, show: [{ field: "audience", not: "organic" }] },
  { label: "Hide", rpc: "set_content_hidden", danger: true, args: { p_type: "channel", p_id: "$row.id", p_hidden: true }, show: [{ field: "hidden", is: false }] },
  { label: "Unhide", rpc: "set_content_hidden", args: { p_type: "channel", p_id: "$row.id", p_hidden: false }, show: [{ field: "hidden", is: true }] },
];

const POST_ACTIONS: Action[] = [
  { label: "Hide", rpc: "set_content_hidden", danger: true, args: { p_type: "post", p_id: "$row.id", p_hidden: true }, show: [{ field: "hidden", is: false }] },
  { label: "Unhide", rpc: "set_content_hidden", args: { p_type: "post", p_id: "$row.id", p_hidden: false }, show: [{ field: "hidden", is: true }] },
];

export default async function Channels() {
  const sb = supabaseServer();
  const [req, chans, posts] = await Promise.all([
    sb.rpc("admin_channel_requests"),
    sb.from("channels").select("id,name,audience,review_status,hidden,members_count,created_at").neq("review_status", "pending").order("created_at", { ascending: false }).limit(200),
    sb.from("posts").select("id,title,status,hidden,created_at,channels(name)").order("created_at", { ascending: false }).limit(100),
  ]);
  const postRows = (posts.data ?? []).map((p) => {
    const ch = p.channels as unknown as { name?: string } | { name?: string }[] | null;
    return { id: p.id, title: p.title, channel: (Array.isArray(ch) ? ch[0]?.name : ch?.name) ?? "", status: p.status, hidden: p.hidden, created_at: p.created_at };
  });
  const err = req.error ?? chans.error ?? posts.error;
  return (
    <div className="space-y-8">
      <h1 className="text-xl font-semibold">Channels &amp; posts</h1>
      {err && <p className="text-danger text-sm">{err.message}</p>}
      <section className="space-y-2">
        <h2 className="text-sm font-medium text-muted">Waiting for approval</h2>
        <Table rows={rowsOf(req.data)} actions={REQUEST_ACTIONS} empty="No channels are waiting for approval." />
      </section>
      <section className="space-y-2">
        <h2 className="text-sm font-medium text-muted">All channels</h2>
        <Table rows={(chans.data ?? []) as Record<string, unknown>[]} actions={CHANNEL_ACTIONS} empty="No reviewed channels yet." />
      </section>
      <section className="space-y-2">
        <h2 className="text-sm font-medium text-muted">Latest posts</h2>
        <Table rows={postRows} actions={POST_ACTIONS} empty="No posts yet." />
      </section>
    </div>
  );
}
