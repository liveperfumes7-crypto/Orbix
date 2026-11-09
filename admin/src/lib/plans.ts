import { createClient } from "@supabase/supabase-js";

export type Plan = {
  id: string; code: string; name: string; price_inr: number; duration_days: number;
  perks: string[] | null; badge: string | null; position: number;
};

export async function loadPlans(): Promise<Plan[]> {
  const sb = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!);
  const { data } = await sb.rpc("public_plans");
  return (data as Plan[]) ?? [];
}

export const durationLabel = (d: number) =>
  d >= 365 ? "1 year" : d >= 180 ? "6 months" : d >= 30 ? `${Math.round(d / 30)} month` : `${d} days`;
