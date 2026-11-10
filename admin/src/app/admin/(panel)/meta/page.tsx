import { requireAdmin } from "@/lib/admin";
import { ist, gb } from "@/lib/format";
import { PageHeader, Card, Field, Input, Hidden, Badge, Stat, ErrorNote } from "@/components/admin/ui";
import { SubmitButton } from "@/components/admin/client";
import { saveMeta, metaSend } from "../actions";
import ApkUpload from "./ApkUpload";

export default async function Meta() {
  const { sb } = await requireAdmin(true);
  const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const [ms, last, failed, pending, files] = await Promise.all([
    sb.from("meta_settings").select("pixel_id,test_event_code,enabled,updated_at,capi_token").eq("id", 1).single(),
    sb.from("meta_events").select("sent_at").eq("status", "sent").order("sent_at", { ascending: false }).limit(1),
    sb.from("meta_events").select("id", { count: "exact", head: true }).not("last_error", "is", null).gte("created_at", since),
    sb.from("meta_events").select("id", { count: "exact", head: true }).eq("status", "pending"),
    sb.storage.from("downloads").list("", { limit: 20, sortBy: { column: "created_at", order: "desc" } }),
  ]);
  const m = ms.data;
  const hasToken = !!m?.capi_token; // only a yes/no is ever sent to the browser
  const apk = (files.data ?? []).find((f) => f.name.toLowerCase().endsWith(".apk"));
  const steps: [boolean, string][] = [
    [!!m?.pixel_id, "Pixel ID saved"],
    [hasToken, "Conversions API token saved"],
    [!!m?.enabled, "Sending enabled"],
    [(last.data ?? []).length > 0, "At least one event delivered"],
  ];
  return (
    <>
      <PageHeader title="Meta Pixel" sub="Sends Lead, CompleteRegistration and Purchase events to Meta's Conversions API from the server." />
      <ErrorNote error={ms.error} />
      <div className="grid gap-4 lg:grid-cols-3">
        <Card title="Setup checklist">
          <ul className="space-y-1.5 text-sm">
            {steps.map(([ok, label]) => <li key={label} className="flex items-center gap-2"><span className={ok ? "text-green-600" : "text-gray-300"} aria-hidden>{ok ? "✔" : "○"}</span><span className={ok ? "text-gray-900" : "text-gray-500"}>{label}</span></li>)}
          </ul>
        </Card>
        <Card title="Settings" className="lg:col-span-2">
          <form action={saveMeta} className="grid gap-3 sm:grid-cols-2">
            <Field label="Pixel ID"><Input name="pixel_id" defaultValue={m?.pixel_id ?? ""} inputMode="numeric" /></Field>
            <Field label="Test event code" hint="Optional. Remove it when you finish testing."><Input name="test_event_code" defaultValue={m?.test_event_code ?? ""} placeholder="TEST12345" /></Field>
            <Field label="Conversions API token" hint={hasToken ? "A token is saved (hidden). Leave empty to keep it." : "Paste the token from Events Manager."} className="sm:col-span-2">
              <Input name="capi_token" type="password" autoComplete="off" placeholder={hasToken ? "••••••••••••" : ""} />
            </Field>
            <label className="flex items-center gap-2 text-sm text-gray-800"><input type="checkbox" name="enabled" defaultChecked={!!m?.enabled} /> Enabled</label>
            {hasToken && <label className="flex items-center gap-2 text-sm text-gray-800"><input type="checkbox" name="clear_token" /> Remove the saved token</label>}
            <div className="sm:col-span-2"><SubmitButton>Save Meta settings</SubmitButton></div>
          </form>
        </Card>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="Last sent" value={<span className="text-base">{last.data?.[0]?.sent_at ? ist(last.data[0].sent_at) : "Never"}</span>} />
        <Stat label="Failures in 24 h" value={failed.count ?? 0} tone={(failed.count ?? 0) > 0 ? "warn" : undefined} />
        <Stat label="Waiting to send" value={pending.count ?? 0} />
        <div className="flex flex-col justify-center gap-2 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <form action={metaSend}><Hidden name="kind" value="test" /><SubmitButton small variant="secondary">Send test event</SubmitButton></form>
          <form action={metaSend}><Hidden name="kind" value="flush" /><SubmitButton small variant="secondary">Send waiting events now</SubmitButton></form>
        </div>
      </div>
      <Card title="Ads APK" sub="The app file for people coming from ads. Stored in the public downloads bucket." className="mt-4">
        <p className="mb-3 text-sm text-gray-700">
          {apk ? <>Current file: <strong>{apk.name}</strong> · {gb(Number((apk.metadata as { size?: number } | null)?.size ?? 0))} · {ist(apk.created_at)} <Badge tone="green">uploaded</Badge></> : "No APK uploaded here yet."}
        </p>
        <ApkUpload />
      </Card>
    </>
  );
}
