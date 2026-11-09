import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Report content" };
const email = process.env.NEXT_PUBLIC_SUPPORT_EMAIL;

export default function Report() {
  return (
    <SiteShell>
      <main className="mx-auto max-w-xl px-4 py-10 space-y-4 text-sm leading-relaxed">
        <h1 className="text-2xl font-bold">Report content</h1>
        <p>The fastest way: open the post in Orbix, tap <b>⋮ → Report</b> and choose a reason (Sexual/nude, Violence, Hate/harassment, Copyright, Spam/scam, Other). You can also block a channel from the same menu.</p>
        <p>Reports are reviewed by our team; content that breaks the rules is hidden.</p>
        <p>Cannot use the app? Email us the post link (orbix.vercel.app/p/…) and the reason{email ? <>: <a className="underline" href={`mailto:${email}`}>{email}</a></> : "."}</p>
      </main>
    </SiteShell>
  );
}
