import { supabaseServer } from "@/lib/supabase/server";
import SettingsForms from "./SettingsForms";

export const dynamic = "force-dynamic";

export default async function Settings() {
  const sb = supabaseServer();
  const { data: owner } = await sb.rpc("is_owner");
  if (!owner) return <p className="text-sm text-muted">Only the owner can change settings.</p>;
  const [mode, pay, plans] = await Promise.all([
    sb.from("app_mode").select("*").eq("id", 1).single(),
    sb.from("payment_settings").select("*").eq("id", 1).single(),
    sb.from("plans").select("*").order("position"),
  ]);
  const err = mode.error ?? pay.error ?? plans.error;
  if (err || !mode.data || !pay.data) return <p className="text-sm text-danger">Could not load settings{err ? `: ${err.message}` : ""}. Reload the page to try again.</p>;
  return <SettingsForms mode={mode.data} pay={pay.data} plans={plans.data ?? []} />;
}
