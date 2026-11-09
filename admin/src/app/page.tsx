import Link from "next/link";
import SiteShell from "@/components/SiteShell";
import { loadPlans, durationLabel } from "@/lib/plans";
import { inr } from "@/lib/format";

export const revalidate = 60;

const FEATURES = [
  ["Private cloud", "Photos, videos and files in your own space — up to 2 TB on Premium."],
  ["Creator channels", "Follow creators, join channels and share your own."],
  ["Made for India", "Pay with UPI. Prices in ₹. Support that understands you."],
  ["Safe by design", "Signed links, server-side rules, one-tap reporting and blocking."],
];

export default async function Home() {
  const plans = await loadPlans();
  return (
    <SiteShell>
      <section className="mx-auto max-w-5xl px-4 py-16 text-center">
        <h1 className="text-4xl md:text-5xl font-bold leading-tight">
          Your cloud. Your <span className="bg-brand bg-clip-text text-transparent">channels.</span>
        </h1>
        <p className="mt-4 text-muted max-w-xl mx-auto">Store everything safely and discover creators — in one app.</p>
        <Link href="/d" className="btn mt-8 px-8 py-3">Download for Android</Link>
      </section>
      <section className="mx-auto max-w-5xl px-4 grid sm:grid-cols-2 lg:grid-cols-4 gap-3">
        {FEATURES.map(([t, d]) => (
          <div key={t} className="card"><h3 className="font-semibold">{t}</h3><p className="mt-1 text-sm text-muted">{d}</p></div>
        ))}
      </section>
      <section id="plans" className="mx-auto max-w-5xl px-4 py-16">
        <h2 className="text-2xl font-semibold text-center mb-6">Premium plans</h2>
        <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-3">
          {plans.map((p) => (
            <div key={p.id} className="card text-center">
              <div className="font-semibold">{p.name}</div>
              <div className="mt-2 text-2xl font-bold text-gold">{inr(p.price_inr)}</div>
              <div className="text-xs text-muted">{durationLabel(p.duration_days)}</div>
            </div>
          ))}
        </div>
        <p className="mt-4 text-center text-xs text-muted">Buy inside the Orbix app on Android.</p>
      </section>
    </SiteShell>
  );
}
