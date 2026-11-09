import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Privacy Policy" };
const email = process.env.NEXT_PUBLIC_SUPPORT_EMAIL || "help.orbix@gmail.com";

export default function Privacy() {
  return (
    <SiteShell>
      <article className="prose-doc mx-auto max-w-3xl px-4 py-12 text-sm">
        <h1>Privacy Policy</h1>
        <p className="text-slate-500">Last updated: November 2026</p>

        <h2>1. Introduction</h2>
        <p>Orbix (“we”, “us”) provides private cloud storage and creator channels through our Android app and this website. This policy explains what we collect, why, who handles it, and the choices you have. By using Orbix you agree to this policy and to our <a href="/terms">Terms and Conditions</a>.</p>

        <h2>2. What we collect</h2>
        <h3>2.1 Account information</h3>
        <ul>
          <li>Email address and password (stored only as a secure hash) if you create an account.</li>
          <li>Display name and profile picture, if you add them.</li>
          <li>A random user ID. If you use the app without an account, we create an anonymous guest ID.</li>
        </ul>
        <h3>2.2 Content you add</h3>
        <ul>
          <li>Files you upload to your cloud storage (photos, videos, documents).</li>
          <li>Channels, posts, comments of yours and the channels you join.</li>
          <li>Reports you send us and the content you block.</li>
        </ul>
        <h3>2.3 Device and install information</h3>
        <ul>
          <li>A random install identifier created by the app, the app version and basic device type.</li>
          <li>How the app was installed (for example from an advertisement link or directly) so that we can tell whether our own advertising works. This is decided once and does not change.</li>
        </ul>
        <h3>2.4 Payment records</h3>
        <ul>
          <li>Plan, amount, order reference, UPI transaction ID or UTR, status and timestamps.</li>
          <li>We never see or store your UPI PIN, card details or bank login. UPI payments are made in the UPI app you choose.</li>
        </ul>
        <h3>2.5 What we do not collect</h3>
        <ul>
          <li>We do not use the Android advertising ID and do not include advertising SDKs in the app.</li>
          <li>We do not read your contacts, messages or location.</li>
        </ul>

        <h2>3. How we use information</h2>
        <ul>
          <li>To provide the service: sign-in, storage, channels, playing and downloading content.</li>
          <li>To activate and verify purchases and to prevent fraud and abuse.</li>
          <li>To enforce our <a href="/community-guidelines">Community Guidelines</a>, review reports and protect other users.</li>
          <li>To measure our own advertising. Where permitted, an anonymised purchase event may be sent to Meta (Facebook) for users who arrived through our ads.</li>
          <li>To contact you about your account, payments or support requests.</li>
        </ul>

        <h2>4. Who handles your data</h2>
        <p>We do not sell your personal data. We use these service providers, who process data only to run Orbix:</p>
        <ul>
          <li><b>Supabase</b>: database, sign-in and file storage.</li>
          <li><b>Vercel</b>: hosting for this website.</li>
          <li><b>Meta</b>: only the anonymised purchase events described above, for users who came from our ads.</li>
          <li><b>Google Play</b>: if you install from Google Play, Google provides installation and, if enabled, billing services under its own policies.</li>
        </ul>
        <p>We may disclose information when the law requires it or to protect people from harm.</p>

        <h2>5. Security</h2>
        <p>Data is encrypted in transit. Your files are private and are opened only through secure links that expire quickly. Access rules are enforced on our servers. No system is perfectly secure, so please keep your password private.</p>

        <h2>6. How long we keep data</h2>
        <ul>
          <li>Account and content: until you delete them or delete your account.</li>
          <li>Payment records: up to 8 years, as required for tax and accounting. After you delete your account these are kept without any link to your profile.</li>
          <li>Reports and abuse records: as long as needed to protect the service.</li>
        </ul>

        <h2>7. Your choices and rights</h2>
        <ul>
          <li><b>Delete your account</b> in the app (Profile → Delete account) or on the <a href="/delete-account">Delete Account</a> page. You can also ask us to delete only some of your data.</li>
          <li><b>Access or correct</b> your information by writing to us.</li>
          <li><b>Notifications</b> can be turned off in your phone settings at any time.</li>
          <li><b>Report content</b> in the app or on the <a href="/report-content">Report Content</a> page.</li>
        </ul>

        <h2>8. Children</h2>
        <p>Orbix is for people aged 18 and over. We do not knowingly collect information from children. If you believe a child has used Orbix, contact us and we will remove the account.</p>

        <h2>9. Changes to this policy</h2>
        <p>We may update this policy. The date above shows the latest version, and continued use means you accept the update.</p>

        <h2>10. Contact</h2>
        <p>Questions or requests: <a href={`mailto:${email}`}>{email}</a>.</p>
      </article>
    </SiteShell>
  );
}
