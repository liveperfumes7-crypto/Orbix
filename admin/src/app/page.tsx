import Link from "next/link";
import SiteShell from "@/components/SiteShell";
import PlanPicker from "@/components/PlanPicker";
import { loadPlans, durationLabel } from "@/lib/plans";
import { inr } from "@/lib/format";

export const revalidate = 60;

const CloudIcon = () => (
  <svg viewBox="0 0 120 120" className="h-40 w-40" aria-hidden>
    <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#6A5CFF" /><stop offset=".5" stopColor="#9B5CFF" /><stop offset="1" stopColor="#FF5CA8" /></linearGradient></defs>
    <path d="M34 88a22 22 0 0 1-2-43.9A28 28 0 0 1 86 40a24 24 0 0 1 2 48z" fill="url(#g)" />
    <path d="M60 80V52m0 0-10 10m10-10 10 10" stroke="#fff" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" fill="none" />
  </svg>
);
const ShieldIcon = () => (
  <svg viewBox="0 0 120 120" className="h-40 w-40" aria-hidden>
    <path d="M60 10 100 24v30c0 28-17 46-40 56C37 100 20 82 20 54V24z" fill="#7C5CFF" opacity=".15" />
    <path d="M60 18 92 29v25c0 22-13 37-32 46-19-9-32-24-32-46V29z" fill="#7C5CFF" />
    <path d="m44 60 12 12 22-24" stroke="#fff" strokeWidth="7" strokeLinecap="round" strokeLinejoin="round" fill="none" />
  </svg>
);

const FAQ = [
  ["Is Orbix free?", "Creating an account gives you 15 GB of cloud storage. Premium plans give you 2 TB, full-length premium videos and downloads."],
  ["How do I pay?", "Inside the Orbix Android app, with the UPI app you already use. We never see your UPI PIN."],
  ["Is my data private?", "Yes. Your files are private to your account and are opened only through short-lived secure links."],
  ["How do I delete my account?", "In the app: Profile → Delete account. Or on this website at Delete Account."],
];

export default async function Home() {
  const plans = await loadPlans();
  const picker = plans.map((p) => ({ id: p.id, name: p.name, price: inr(p.price_inr), label: durationLabel(p.duration_days, p.duration_hours), badge: p.badge }));
  return (
    <SiteShell>
      <section className="bg-gradient-to-b from-violet-100 to-white">
        <div className="mx-auto max-w-4xl px-4 py-20 text-center">
          <h1 className="text-4xl md:text-6xl font-bold text-slate-900 leading-tight">15 GB free cloud storage for everyone</h1>
          <p className="mt-4 text-slate-600">Simple, secure and swift. Your digital life, organised. Up to 2 TB with Premium.</p>
          <Link href="/d" className="btn mt-8 px-8 py-3">Download for Android</Link>
        </div>
      </section>

      <section id="features" className="mx-auto max-w-5xl px-4 py-20 grid gap-10 md:grid-cols-2 items-center">
        <div className="mx-auto"><CloudIcon /></div>
        <div>
          <h2 className="text-3xl font-semibold text-slate-900">Backup and share with ease</h2>
          <p className="mt-3 text-slate-600">Back up your photos, videos and documents. Open them from your phone any time. Rename, organise and delete in a tap, and watch your storage meter fill as you go.</p>
        </div>
      </section>

      <section id="security" className="bg-slate-50">
        <div className="mx-auto max-w-5xl px-4 py-20 grid gap-10 md:grid-cols-2 items-center">
          <div>
            <h2 className="text-3xl font-semibold text-slate-900">Orbix protects your data</h2>
            <p className="mt-3 text-slate-600">Your files are private to your account. They are opened only through short-lived secure links, and our access rules are enforced on the server, not just in the app.</p>
            <div className="mt-5 flex items-start gap-3">
              <span className="mt-1 text-primary">✔</span>
              <div><div className="font-medium text-slate-900">Keep your data safe</div><div className="text-xs text-slate-500">Encrypted in transit · Private by default · Delete your account any time</div></div>
            </div>
            <Link href="/privacy" className="btn-ghost mt-6 inline-flex">View more details →</Link>
          </div>
          <div className="mx-auto"><ShieldIcon /></div>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-4 py-20 text-center">
        <h2 className="text-3xl font-semibold text-slate-900">Channels from creators you will love</h2>
        <p className="mt-3 text-slate-600 max-w-2xl mx-auto">Discover channels, join the ones you like and share your own. Every channel is reviewed, and you can report or block anything in one tap. See our <Link className="text-primary underline" href="/community-guidelines">Community Guidelines</Link>.</p>
      </section>

      <section id="pricing" className="bg-slate-50">
        <div className="mx-auto max-w-5xl px-4 py-20">
          <h2 className="text-center text-3xl font-semibold text-slate-900">Choose your best Orbix plan</h2>
          <p className="mt-2 text-center text-sm text-slate-500">Unlock premium privileges and supercharge your cloud storage.</p>
          <div className="mt-10 grid gap-6 md:grid-cols-2">
            <div className="card p-6">
              <h3 className="text-2xl font-semibold text-slate-900">Premium <span className="ml-1 align-middle rounded bg-primary px-2 py-0.5 text-xs text-white">Popular</span></h3>
              <p className="mt-2 text-sm text-slate-600">For individuals and power users who want more space and features.</p>
              <ul className="mt-6 space-y-2 text-sm">
                {["2 TB large space", "Full-length premium videos", "Offline downloads", "Priority support on longer plans"].map((x) => (
                  <li key={x} className="flex gap-2"><span className="text-primary">✔</span>{x}</li>
                ))}
              </ul>
              <Link href="/d" className="btn mt-8 w-full py-3">Choose Premium</Link>
            </div>
            <PlanPicker plans={picker} />
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-3xl px-4 py-20">
        <h2 className="text-center text-3xl font-semibold text-slate-900">Questions</h2>
        <div className="mt-8 space-y-3">
          {FAQ.map(([q, a]) => (
            <details key={q} className="card group">
              <summary className="cursor-pointer font-medium text-slate-900">{q}</summary>
              <p className="mt-2 text-sm text-slate-600">{a}</p>
            </details>
          ))}
        </div>
      </section>
    </SiteShell>
  );
}
