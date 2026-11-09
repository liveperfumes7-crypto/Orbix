import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Terms of Service" };

export default function Terms() {
  return (
    <SiteShell>
      <article className="mx-auto max-w-2xl px-4 py-10 space-y-4 text-sm leading-relaxed">
        <h1 className="text-2xl font-bold">Terms of Service</h1>
        <p className="text-muted">Last updated: November 2026</p>
        <h2 className="font-semibold text-base">Your content</h2>
        <p>You own what you upload. You confirm you have the right to share it and that it follows our community rules: no sexual content involving minors, no non-consensual or explicit sexual content, no violence or hate, no copyright infringement, no spam or scams. We may hide or remove content and suspend accounts that break these rules.</p>
        <h2 className="font-semibold text-base">Premium plans</h2>
        <p>Plans are time-limited, priced in Indian Rupees and activate after payment is confirmed. Prices shown at purchase are final for that order. Plans do not auto-renew. Refunds are handled case by case; contact support with your payment reference.</p>
        <h2 className="font-semibold text-base">Storage</h2>
        <p>Free accounts get limited storage; guests get none. If a plan ends, existing files stay but new uploads may be blocked above the free quota.</p>
        <h2 className="font-semibold text-base">Changes</h2>
        <p>We may update these terms; continued use means you accept them.</p>
      </article>
    </SiteShell>
  );
}
