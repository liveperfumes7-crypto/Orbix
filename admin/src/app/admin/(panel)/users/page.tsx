import { supabaseServer } from "@/lib/supabase/server";
import { rowsOf } from "@/lib/format";
import Table, { type Action } from "../Table";

export const dynamic = "force-dynamic";

const ACTIONS: Action[] = [
  { label: "Approve full access", rpc: "set_ads_access", args: { p_user: "$row.id", p_status: "approved" }, show: [{ field: "ads_access_status", not: "approved" }, { field: "source", not: "ads" }] },
  { label: "Reject", rpc: "set_ads_access", danger: true, args: { p_user: "$row.id", p_status: "rejected" }, show: [{ field: "ads_access_status", is: "pending" }] },
];

export default async function Users({ searchParams }: { searchParams: { q?: string; source?: string } }) {
  const sb = supabaseServer();
  const { data, error } = await sb.rpc("admin_users", {
    p_search: searchParams.q ?? null,
    p_source: searchParams.source ?? null,
    p_plan: null,
    p_guest: null,
    p_access: null,
    p_limit: 100,
    p_offset: 0,
  });
  const total = (data as { total?: number } | null)?.total;
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Users {total != null && <span className="text-muted text-sm">({total})</span>}</h1>
      <form className="flex gap-2 flex-wrap">
        <input name="q" defaultValue={searchParams.q} placeholder="Search email or name" className="input max-w-xs" />
        <select name="source" defaultValue={searchParams.source ?? ""} className="input max-w-[160px]">
          <option value="">All sources</option>
          <option value="ads">Ads</option>
          <option value="organic">Organic</option>
        </select>
        <button className="btn">Filter</button>
      </form>
      {error && <p className="text-danger text-sm">{error.message}</p>}
      <Table rows={rowsOf(data)} actions={ACTIONS} empty="No users match this filter." />
    </div>
  );
}
