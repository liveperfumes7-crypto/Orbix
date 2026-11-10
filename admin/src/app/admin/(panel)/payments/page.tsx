import Link from "next/link";
import { requireAdmin } from "@/lib/admin";
import { inr, ist, rowsOf } from "@/lib/format";
import { PageHeader, Card, Stat, Table, Th, Td, Empty, StatusBadge, Badge, Field, Input, Select, Button, Hidden, LinkButton, ErrorNote } from "@/components/admin/ui";
import { SubmitButton } from "@/components/admin/client";
import { savePaymentSettings, clearUpi, orderAction } from "../actions";

type Q = { status?: string; plan?: string; from?: string; to?: string; q?: string; sort?: string; verify?: string };
const STATUSES = ["pending", "submitted", "review", "paid", "failed", "cancelled", "rejected", "revoked"];
const LABEL: Record<string, string> = { payment_settings: "UPI settings", plans: "Plan", app_mode: "App mode" };
const n = (v: unknown) => new Intl.NumberFormat("en-IN").format(Number(v ?? 0));
const date = (s?: string) => (s && /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : null);

export default async function Payments({ searchParams: q }: { searchParams: Q }) {
  const { sb } = await requireAdmin(true);
  const [ps, stats, dash, orders, plans, audit] = await Promise.all([
    sb.from("payment_settings").select("*").eq("id", 1).single(),
    sb.rpc("admin_payment_stats"),
    sb.rpc("admin_dashboard"),
    sb.rpc("admin_payments", { p_status: q.status ?? null, p_plan: q.plan ?? null, p_from: date(q.from), p_to: date(q.to), p_search: q.q ?? null, p_sort: q.sort ?? "newest", p_verify: q.verify ?? null, p_limit: 200 }),
    sb.from("plans").select("code,name").order("position"),
    sb.rpc("admin_audit", { p_limit: 40 }),
  ]);
  const s = ps.data as Record<string, any> | null;
  const st = (stats.data ?? {}) as Record<string, unknown>;
  const rows = rowsOf(orders.data);
  const live = !!s?.enabled && !!s?.upi_id;
  const back = "/admin/payments?" + new URLSearchParams(Object.entries(q).filter(([, v]) => v) as [string, string][]).toString();
  const filtered = Object.values(q).some(Boolean);

  return (
    <>
      <PageHeader title="Payments" sub="UPI payments. Dates use India time (IST)." />
      <ErrorNote error={ps.error ?? orders.error ?? stats.error} />

      <Card title="UPI settings" className="mb-5">
        <div className="mb-3 flex flex-wrap items-center gap-2 text-sm">
          <Badge tone={live ? "green" : "red"}>{live ? "Payments live" : "Payments off"}</Badge>
          <span className="text-gray-700">Money goes to <strong className="text-gray-900">{s?.upi_id || "no UPI ID set"}</strong>{s?.payee_name ? <> · {s.payee_name}</> : null}</span>
        </div>
        <form action={savePaymentSettings} className="grid gap-3 md:grid-cols-2">
          <Field label="UPI ID" hint="Like name@bank"><Input name="upi_id" defaultValue={s?.upi_id ?? ""} placeholder="name@bank" /></Field>
          <Field label="Payee name" hint="Shown in the customer's UPI app"><Input name="payee_name" defaultValue={s?.payee_name ?? ""} /></Field>
          <Field label="Activation" hint="Automatic: the plan starts when the UPI app reports success; check your bank later. Manual: you check the bank first, then mark each order paid." className="md:col-span-2">
            <Select name="activation_mode" defaultValue={s?.activation_mode ?? "instant"}>
              <option value="instant">Automatic (instant)</option><option value="manual">Manual (verify bank first)</option>
            </Select>
          </Field>
          <label className="flex items-center gap-2 text-sm text-gray-800"><input type="checkbox" name="enabled" defaultChecked={!!s?.enabled} /> Enable payments</label>
          <div className="flex flex-wrap gap-2 md:col-span-2">
            <SubmitButton confirm="New payments will go to the UPI ID you entered. Continue?">Save UPI settings</SubmitButton>
          </div>
        </form>
        {s?.upi_id ? <form action={clearUpi} className="mt-2"><SubmitButton variant="danger" small confirm="Clear the UPI ID? This stops all new payments.">Clear UPI ID</SubmitButton></form> : null}
      </Card>

      <div className="mb-5 grid grid-cols-2 gap-3 lg:grid-cols-5">
        <Stat label="Revenue today" value={inr(Number(st.revenue_today ?? 0))} />
        <Stat label="This month" value={inr(Number((dash.data as Record<string, unknown> | null)?.revenue_month ?? 0))} />
        <Stat label="Successful orders" value={n(st.paid_orders)} />
        <Stat label="Pending orders" value={n(st.pending_orders)} />
        <Stat label="To verify" value={n(st.to_verify)} tone={Number(st.to_verify) > 0 ? "warn" : undefined} />
      </div>

      <div className="mb-3 flex flex-wrap gap-2">
        <LinkButton href="/admin/payments?verify=today" variant={q.verify === "today" ? "primary" : "secondary"} small>Activated today — check against bank</LinkButton>
        <LinkButton href="/admin/payments?verify=all" variant={q.verify === "all" ? "primary" : "secondary"} small>All bank checks outstanding</LinkButton>
        <LinkButton href="/admin/payments" variant={!filtered ? "primary" : "secondary"} small>All payments</LinkButton>
      </div>
      <form className="mb-4 grid grid-cols-2 gap-2 md:grid-cols-7">
        <Select name="status" defaultValue={q.status ?? ""} aria-label="Status"><option value="">Any status</option>{STATUSES.map((x) => <option key={x}>{x}</option>)}</Select>
        <Select name="plan" defaultValue={q.plan ?? ""} aria-label="Plan"><option value="">Any plan</option>{(plans.data ?? []).map((p) => <option key={p.code} value={p.code}>{p.name}</option>)}</Select>
        <Input type="date" name="from" defaultValue={q.from ?? ""} aria-label="From date" />
        <Input type="date" name="to" defaultValue={q.to ?? ""} aria-label="To date" />
        <Input name="q" defaultValue={q.q ?? ""} placeholder="Reference, UTR, email" aria-label="Search" />
        <Select name="sort" defaultValue={q.sort ?? "newest"} aria-label="Sort"><option value="newest">Newest first</option><option value="highest">Highest amount</option></Select>
        <Button variant="secondary">Filter</Button>
      </form>

      {rows.length === 0 ? <Empty>No payments in this view.</Empty> : (
        <Table min={900}>
          <thead><tr><Th>Date</Th><Th>User and plan</Th><Th>Amount</Th><Th>Reference</Th><Th>Status</Th><Th>Actions</Th></tr></thead>
          <tbody>
            {rows.map((o) => {
              const id = o.id as string;
              const paid = o.status === "paid";
              const needsBank = paid && o.activation_kind === "auto" && !o.bank_verified;
              const open = !paid && !["rejected", "revoked"].includes(o.status as string);
              return (
                <tr key={id}>
                  <Td className="whitespace-nowrap text-xs text-gray-600">{ist(o.created_at as string)}</Td>
                  <Td><div className="font-medium text-gray-900">{o.email ? String(o.email) : o.guest ? "Guest (no email yet)" : "Deleted account"}</div><div className="text-xs text-gray-500">{String(o.plan_name ?? "")}</div></Td>
                  <Td className="whitespace-nowrap font-medium">{inr(Number(o.amount_inr))}</Td>
                  <Td className="text-xs"><div className="font-mono">{String(o.reference ?? "—")}</div>{o.utr ? <div className="font-mono text-gray-500">UTR {String(o.utr)}</div> : null}</Td>
                  <Td><StatusBadge value={o.status as string} />{needsBank ? <div className="mt-1"><Badge tone="amber">Verify against bank</Badge></div> : null}{paid && o.bank_verified ? <div className="mt-1"><Badge tone="green">Bank verified</Badge></div> : null}</Td>
                  <Td>
                    <details>
                      <summary className="cursor-pointer text-sm font-medium text-violet-700">Details and actions</summary>
                      <dl className="mt-2 grid grid-cols-[auto,1fr] gap-x-3 gap-y-0.5 text-xs text-gray-600">
                        <dt>Txn id</dt><dd className="break-all font-mono">{String(o.txn_id ?? "—")}</dd>
                        <dt>Activated</dt><dd>{o.activated_at ? `${ist(o.activated_at as string)} (${o.activation_kind})` : "—"}</dd>
                        <dt>UPI ID used</dt><dd>{String(o.upi_id_used ?? "—")}</dd>
                        <dt>Updated</dt><dd>{ist(o.updated_at as string)}</dd>
                        <dt>Verified</dt><dd>{o.bank_verified ? ist(o.bank_verified_at as string) : "No"}</dd>
                        <dt>Note</dt><dd>{String(o.admin_note ?? "—")}</dd>
                        <dt>UPI reply</dt><dd className="break-all font-mono">{String(o.raw_result ?? "—")}</dd>
                      </dl>
                      <div className="mt-2 space-y-1.5">
                        {needsBank && <form action={orderAction}><Hidden name="id" value={id} /><Hidden name="kind" value="bank" /><Hidden name="back" value={back} /><SubmitButton small variant="success" confirm="Confirm you can see this payment in your bank statement?">Bank verified</SubmitButton></form>}
                        {open && (
                          <form action={orderAction} className="flex flex-wrap items-center gap-1.5">
                            <Hidden name="id" value={id} /><Hidden name="kind" value="paid" /><Hidden name="back" value={back} />
                            <Input name="note" placeholder="12-digit UTR" inputMode="numeric" pattern="\d{12}" required aria-label="12-digit UTR" className="!w-36 !py-1 !text-xs" />
                            <SubmitButton small variant="success" confirm="Mark this order paid and start the plan?">Mark paid</SubmitButton>
                          </form>
                        )}
                        {(open || paid) && (
                          <form action={orderAction} className="flex flex-wrap items-center gap-1.5">
                            <Hidden name="id" value={id} /><Hidden name="kind" value={paid ? "revoke" : "reject"} /><Hidden name="back" value={back} />
                            <Input name="note" placeholder="Reason" aria-label="Reason" className="!w-36 !py-1 !text-xs" />
                            <SubmitButton small variant="danger" confirm={paid ? "Revoke this payment? The user's plan ends now." : "Reject this payment?"}>{paid ? "Revoke" : "Reject"}</SubmitButton>
                          </form>
                        )}
                      </div>
                    </details>
                  </Td>
                </tr>
              );
            })}
          </tbody>
        </Table>
      )}

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <Card title="Sales per plan">
          {rowsOf(st.sales_per_plan).length === 0 ? <p className="text-sm text-gray-500">No paid orders yet.</p> : (
            <table className="w-full text-sm"><tbody>
              {rowsOf(st.sales_per_plan).map((r, i) => <tr key={i} className="border-b border-gray-100 last:border-0"><td className="py-1.5">{String(r.plan_name)}</td><td className="py-1.5 text-gray-500">{n(r.orders)} orders</td><td className="py-1.5 text-right font-medium">{inr(Number(r.revenue))}</td></tr>)}
            </tbody></table>
          )}
        </Card>
        <Card title="Repeat buyers">
          {rowsOf(st.repeat_buyers).length === 0 ? <p className="text-sm text-gray-500">No repeat buyers yet.</p> : (
            <table className="w-full text-sm"><tbody>
              {rowsOf(st.repeat_buyers).map((r, i) => <tr key={i} className="border-b border-gray-100 last:border-0"><td className="py-1.5">{r.email ? <Link className="text-violet-700 underline" href={`/admin/payments?q=${encodeURIComponent(String(r.email))}`}>{String(r.email)}</Link> : "Guest"}</td><td className="py-1.5 text-gray-500">{n(r.paid_orders)} orders</td><td className="py-1.5 text-right font-medium">{inr(Number(r.spent))}</td></tr>)}
            </tbody></table>
          )}
        </Card>
      </div>

      <Card title="Change history" sub="UPI settings, plans and app mode." className="mt-4">
        {rowsOf(audit.data).length === 0 ? <p className="text-sm text-gray-500">No changes recorded yet.</p> : (
          <div className="overflow-x-auto"><table className="w-full min-w-[560px] text-xs"><tbody>
            {rowsOf(audit.data).map((a, i) => (
              <tr key={i} className="border-b border-gray-100 last:border-0">
                <td className="whitespace-nowrap py-1.5 pr-3 text-gray-500">{ist(a.changed_at as string)}</td>
                <td className="py-1.5 pr-3">{LABEL[a.table_name as string] ?? String(a.table_name)} · {String(a.field).replace(/_/g, " ")}</td>
                <td className="py-1.5 pr-3"><span className="text-gray-500">{String(a.old_value ?? "—")}</span> → <span className="font-medium text-gray-900">{String(a.new_value ?? "—")}</span></td>
                <td className="py-1.5 text-gray-500">{String(a.changed_by ?? "system")}</td>
              </tr>
            ))}
          </tbody></table></div>
        )}
      </Card>
    </>
  );
}
