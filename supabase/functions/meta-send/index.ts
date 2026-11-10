// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";

// Sends queued events (Lead, AppInstall, CompleteRegistration, InitiateCheckout, Purchase) to the Meta Conversions API.
// The Pixel ID and token are read from meta_settings on every run, so changing them in the admin panel is all it takes.
// Callers: the database (header x-cron-key, checked against private.meta_cron) or the signed-in owner (admin panel).
const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SITE = (Deno.env.get("SITE_URL") ?? "https://orbix-gray.vercel.app").replace(/\/$/, "");
const GRAPH = "https://graph.facebook.com/v25.0";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-key", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

async function sha256(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s.trim().toLowerCase()));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
const metaError = (b: any) => String(b?.error?.error_user_msg || b?.error?.message || JSON.stringify(b)).slice(0, 500);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const admin = createClient(URL_, SERVICE, { auth: { persistSession: false } });

  let allowed = false;
  const cronKey = req.headers.get("x-cron-key") ?? "";
  if (cronKey) {
    const { data } = await admin.rpc("meta_cron_ok", { p_key: cronKey });
    allowed = data === true;
  }
  if (!allowed) {
    const user = createClient(URL_, ANON, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } }, auth: { persistSession: false } });
    const { data } = await user.rpc("is_owner");
    allowed = data === true;
  }
  if (!allowed) return json({ error: "forbidden" }, 403);

  let body: any = {};
  try { body = await req.json(); } catch { /* empty = flush */ }
  const { data: ms } = await admin.from("meta_settings").select("*").eq("id", 1).single();

  // Checks the Pixel ID and token with Meta without creating an event. Works even while sending is switched off.
  if (body.action === "verify") {
    if (!ms?.pixel_id || !ms?.capi_token) return json({ verify: true, ok: false, message: "Save a Pixel ID and a token first." });
    const res = await fetch(`${GRAPH}/${encodeURIComponent(ms.pixel_id)}?fields=id,name&access_token=${encodeURIComponent(ms.capi_token)}`);
    const b = await res.json().catch(() => ({}));
    return json({ verify: true, ok: res.ok, name: b?.name ?? null, message: res.ok ? null : metaError(b) });
  }

  if (!ms?.enabled || !ms.pixel_id || !ms.capi_token) return json({ skipped: true, reason: "meta is not configured/enabled" });

  const send = async (events: any[]) => {
    const payload: any = { data: events, access_token: ms.capi_token };
    if (ms.test_event_code) payload.test_event_code = ms.test_event_code;
    const res = await fetch(`${GRAPH}/${encodeURIComponent(ms.pixel_id)}/events`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload),
    });
    return { ok: res.ok, status: res.status, body: await res.json().catch(() => ({})) };
  };
  const country = await sha256("in");

  if (body.action === "test") {
    if (!ms.test_event_code) return json({ test: true, ok: false, message: "Add a test event code first, so the test does not count as a real event." });
    const r = await send([{
      event_name: "Purchase", event_time: Math.floor(Date.now() / 1000), event_id: `test-${crypto.randomUUID()}`,
      action_source: "website", event_source_url: `${SITE}/d`,
      user_data: { em: [await sha256("test@example.com")], country: [country], client_user_agent: req.headers.get("user-agent") ?? "Orbix", client_ip_address: (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || undefined },
      custom_data: { currency: "INR", value: 1, content_name: "Test plan", content_type: "product" },
    }]);
    return json({ test: true, ok: r.ok, meta_status: r.status, message: r.ok ? null : metaError(r.body) });
  }

  const { data: events } = await admin.from("meta_events").select("*").eq("status", "pending").lt("attempts", 5).order("created_at").limit(100);
  let sent = 0, failed = 0;
  for (const ev of events ?? []) {
    // Meta refuses events older than 7 days.
    if (Date.now() - new Date(ev.created_at).getTime() > 6.5 * 86400_000) {
      await admin.from("meta_events").update({ status: "failed", last_error: "Too old to send (Meta accepts events up to 7 days old)." }).eq("id", ev.id);
      failed++;
      continue;
    }
    const ud: any = { country: [country], client_user_agent: ev.client_ua || "Orbix-Android" };
    if (ev.user_id) {
      ud.external_id = [await sha256(ev.user_id)];
      const { data: usr } = await admin.auth.admin.getUserById(ev.user_id);
      if (usr?.user?.email) ud.em = [await sha256(usr.user.email)];
    }
    if (ev.fbc) ud.fbc = ev.fbc;
    if (ev.fbp) ud.fbp = ev.fbp;
    if (ev.client_ip) ud.client_ip_address = ev.client_ip;
    const data: any = {
      event_name: ev.event_name, event_time: Math.floor(new Date(ev.created_at).getTime() / 1000), event_id: ev.event_id,
      action_source: "website", event_source_url: ev.source_url || `${SITE}/d`, user_data: ud,
    };
    if (ev.event_name === "Purchase" || ev.event_name === "InitiateCheckout") {
      data.custom_data = { currency: "INR", value: Number(ev.value_inr ?? 0), content_type: "product", num_items: 1 };
      if (ev.content_name) data.custom_data.content_name = ev.content_name;
      if (ev.order_id) { data.custom_data.order_id = ev.order_id; data.custom_data.content_ids = [ev.content_name || "plan"]; }
    } else if (ev.content_name) {
      data.custom_data = { content_name: ev.content_name };
    }
    const r = await send([data]);
    if (r.ok) {
      await admin.from("meta_events").update({ status: "sent", sent_at: new Date().toISOString(), attempts: ev.attempts + 1, last_error: null }).eq("id", ev.id);
      sent++;
    } else {
      const attempts = ev.attempts + 1;
      await admin.from("meta_events").update({ attempts, status: attempts >= 5 ? "failed" : "pending", last_error: metaError(r.body) }).eq("id", ev.id);
      failed++;
    }
  }
  const { count: pending } = await admin.from("meta_events").select("id", { count: "exact", head: true }).eq("status", "pending");
  return json({ ok: true, sent, failed, pending: pending ?? 0 });
});
