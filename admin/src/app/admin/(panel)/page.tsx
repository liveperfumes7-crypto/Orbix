import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { inr, rowsOf } from "@/lib/format";
import { PageHeader, Stat, Table, Th, Td, Empty, SourceBadge } from "@/components/admin/ui";

const n = (v: unknown) => new Intl.NumberFormat("en-IN").format(Number(v ?? 0));

function Alert({ count, text, href }: { count: number; text: string; href: string }) {
  if (!count) return null;
  return (
    <Link href={href} className="flex items-center justify-between gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-medium text-amber-900 hover:bg-amber-100">
      <span>{n(count)} {text}</span><span aria-hidden>→</span>
    </Link>
  );
}

export default async function Dashboard() {
  const { sb, role } = await requireAdmin();
  const owner = role === "owner";
  const [{ data: d }, camp] = await Promise.all([sb.rpc("admin_dashboard"), owner ? sb.rpc("admin_campaigns") : Promise.resolve({ data: [] })]);
  const s = (d ?? {}) as Record<string, unknown>;
  const a = (s.alerts ?? {}) as Record<string, number>;
  const rows = rowsOf(camp.data);
  return (
    <>
      <PageHeader title="Dashboard" sub="Dates and totals use India time (IST)." />
      {owner && (
        <div className="mb-5 space-y-2">
          <Alert count={a.channel_requests ?? 0} text="new channel requests to review" href="/admin/channels" />
          <Alert count={a.organic_buyers_waiting ?? 0} text="organic users waiting for approval" href="/admin/approvals" />
          <Alert count={a.payments_to_verify ?? 0} text="payments to verify against bank today" href="/admin/payments?verify=today" />
          <Alert count={a.open_requests ?? 0} text="open requests and reports" href="/admin/requests" />
        </div>
      )}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        {owner && <>
          <Stat label="Installs from ads" value={n(s.ads_installs)} />
          <Stat label="Organic installs" value={n(s.organic_installs)} />
          <Stat label="App users" value={n(s.users)} />
          <Stat label="Logged-in users" value={n(s.logged_in)} />
          <Stat label="Premium users" value={n(s.premium_users)} />
        </>}
        <Stat label="Channels" value={n(s.channels)} />
        <Stat label="Posts" value={n(s.posts)} />
        {owner && <>
          <Stat label="Revenue today" value={inr(Number(s.revenue_today ?? 0))} />
          <Stat label="Revenue this month" value={inr(Number(s.revenue_month ?? 0))} />
          <Stat label="Free plans claimed" value={n(s.free_claims)} />
        </>}
      </div>
      {owner && (
        <div className="mt-6">
          <h2 className="mb-2 text-sm font-semibold text-gray-900">Installs by source and campaign</h2>
          {rows.length === 0 ? <Empty>No installs recorded yet.</Empty> : (
            <Table>
              <thead><tr><Th>Source</Th><Th>Campaign</Th><Th>Installs</Th><Th>Registrations</Th><Th>Buyers</Th></tr></thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={i}><Td><SourceBadge value={r.source as string} /></Td><Td>{String(r.campaign)}</Td><Td>{n(r.installs)}</Td><Td>{n(r.registrations)}</Td><Td>{n(r.buyers)}</Td></tr>
                ))}
              </tbody>
            </Table>
          )}
        </div>
      )}
    </>
  );
}
