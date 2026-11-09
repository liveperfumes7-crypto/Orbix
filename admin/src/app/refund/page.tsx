import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Refund Policy" };
const email = process.env.NEXT_PUBLIC_SUPPORT_EMAIL || "the support address shown in the app";

export default function Refund() {
  return (
    <SiteShell>
      <article className="mx-auto max-w-2xl px-4 py-10 space-y-4 text-sm leading-relaxed">
        <h1 className="text-2xl font-bold">Refund Policy</h1>
        <p className="text-muted">Last updated: November 2026</p>
        <h2 className="font-semibold text-base">Digital service</h2>
        <p>Orbix plans give you cloud storage and premium access for a fixed period. Because access starts as soon as your payment is confirmed, plans are generally non-refundable once activated.</p>
        <h2 className="font-semibold text-base">When we refund</h2>
        <p>We will refund or correct the following, after checking our records and your payment reference:</p>
        <ul className="list-disc pl-5 space-y-1">
          <li>You were charged but your plan was not activated within 24 hours.</li>
          <li>You were charged more than once for the same order.</li>
          <li>You were charged an amount different from the price shown at purchase.</li>
        </ul>
        <h2 className="font-semibold text-base">How to ask</h2>
        <p>Email {email} with your order reference (starts with OB), the UPI transaction ID or UTR, the date and the amount. Approved refunds are returned to the original UPI account, normally within 7 working days.</p>
        <h2 className="font-semibold text-base">Cancelling</h2>
        <p>Plans do not auto-renew, so there is nothing to cancel. Your plan simply ends on its end date. If an administrator revokes a plan for a violation of the community rules, no refund is due.</p>
        <p>See also our <a className="underline" href="/terms">Terms</a> and <a className="underline" href="/privacy">Privacy Policy</a>.</p>
      </article>
    </SiteShell>
  );
}
