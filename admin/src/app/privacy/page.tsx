import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Privacy Policy" };
const email = process.env.NEXT_PUBLIC_SUPPORT_EMAIL || "the support address shown in the app";

export default function Privacy() {
  return (
    <SiteShell>
      <article className="mx-auto max-w-2xl px-4 py-10 space-y-4 text-sm leading-relaxed">
        <h1 className="text-2xl font-bold">Privacy Policy</h1>
        <p className="text-muted">Last updated: November 2026</p>
        <h2 className="font-semibold text-base">What we collect</h2>
        <p>Account details (email, display name, avatar), content you upload (cloud files, posts, channel details), device install identifier and install source (to know whether you came from an advertisement), and payment records (plan, amount, UPI reference/UTR, timestamps). We do not use advertising identifiers and include no advertising SDKs.</p>
        <h2 className="font-semibold text-base">How we use it</h2>
        <p>To run the service, enforce community rules, activate and verify purchases, prevent abuse, and measure the effectiveness of our own advertising. Where permitted, anonymised purchase events may be sent to Meta for ad measurement.</p>
        <h2 className="font-semibold text-base">Payments</h2>
        <p>UPI payments are made to our UPI ID through the UPI app of your choice. We never see your UPI PIN or bank credentials. Payment records are retained for up to 8 years for accounting and legal purposes, even after account deletion (kept without your profile link).</p>
        <h2 className="font-semibold text-base">Storage and security</h2>
        <p>Data is stored with Supabase. Files are private and served through short-lived signed links. Access rules are enforced on the server.</p>
        <h2 className="font-semibold text-base">Your choices</h2>
        <p>You can delete your account in the app or at <a className="underline" href="/delete-account">/delete-account</a>. You can report content in the app or on <a className="underline" href="/report-content">/report-content</a>.</p>
        <h2 className="font-semibold text-base">Contact</h2>
        <p>Questions: {email}.</p>
      </article>
    </SiteShell>
  );
}
