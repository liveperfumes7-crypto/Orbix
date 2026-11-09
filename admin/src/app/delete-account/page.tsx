"use client";
import { useState } from "react";
import SiteShell from "@/components/SiteShell";

export default function DeleteAccount() {
  const [email, setEmail] = useState("");
  const [partial, setPartial] = useState(false);
  const [details, setDetails] = useState("");
  const [website, setWebsite] = useState(""); // honeypot
  const [state, setState] = useState<"idle" | "busy" | "ok" | "err">("idle");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setState("busy");
    try {
      const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/deletion-request`, {
        method: "POST",
        headers: { "Content-Type": "application/json", apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY! },
        body: JSON.stringify({ email, partial, details, website }),
      });
      setState(r.ok ? "ok" : "err");
    } catch {
      setState("err");
    }
  }

  return (
    <SiteShell>
      <main className="mx-auto max-w-xl px-4 py-10 space-y-4">
        <h1 className="text-2xl font-bold">Delete your Orbix account</h1>
        <p className="text-sm text-muted">
          In the app: Profile → Settings → Delete account (instant). Or send a request here using the email on your account.
          Deleting removes your profile, cloud files and posts. Payment records are kept in anonymised form for up to 8 years as
          required for tax and accounting.
        </p>
        {state === "ok" ? (
          <p className="card text-success" role="status">Request received. We will process it within 30 days.</p>
        ) : (
          <form onSubmit={submit} className="card space-y-3">
            <input className="input" type="email" required placeholder="Account email" value={email} onChange={(e) => setEmail(e.target.value)} />
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={partial} onChange={(e) => setPartial(e.target.checked)} /> Delete only some data (describe below)
            </label>
            <textarea className="input" rows={4} maxLength={2000} placeholder="Details (optional)" value={details} onChange={(e) => setDetails(e.target.value)} />
            <input className="hidden" tabIndex={-1} autoComplete="off" aria-hidden value={website} onChange={(e) => setWebsite(e.target.value)} name="website" />
            {state === "err" && <p className="text-sm text-danger" role="alert">Could not send. Please try again.</p>}
            <button className="btn" disabled={state === "busy"}>Submit request</button>
          </form>
        )}
      </main>
    </SiteShell>
  );
}
