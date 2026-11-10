"use client";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase/client";

function LoginForm() {
  const q = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState(q.get("error") ?? "");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    const sb = supabaseBrowser();
    const { error } = await sb.auth.signInWithPassword({ email: email.trim(), password });
    if (error) { setBusy(false); return setErr(error.message === "Invalid login credentials" ? "Wrong email or password." : error.message); }
    const { data: isAdmin } = await sb.rpc("is_admin");
    if (!isAdmin) { await sb.auth.signOut(); setBusy(false); return setErr("This account is not an admin."); }
    window.location.href = "/admin";
  }

  const input = "w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:border-violet-500 focus:outline-none focus:ring-1 focus:ring-violet-500";
  return (
    <form onSubmit={submit} className="w-full max-w-sm space-y-4 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="flex items-center gap-3">
        <div className="grid h-10 w-10 place-items-center rounded-lg bg-violet-600 font-bold text-white">OB</div>
        <div>
          <div className="font-semibold text-gray-900">Orbix Admin</div>
          <div className="text-xs text-gray-500">Sign in with your admin account</div>
        </div>
      </div>
      <label className="block text-sm"><span className="mb-1 block font-medium text-gray-700">Email</span>
        <input className={input} type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
      </label>
      <label className="block text-sm"><span className="mb-1 block font-medium text-gray-700">Password</span>
        <input className={input} type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" />
      </label>
      {err && <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700" role="alert">{err}</p>}
      <button className="w-full rounded-lg bg-violet-600 px-4 py-2 text-sm font-semibold text-white hover:bg-violet-700 disabled:opacity-50" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</button>
    </form>
  );
}

export default function Login() {
  return (
    <main className="grid min-h-screen place-items-center bg-gray-50 px-4">
      <Suspense fallback={null}><LoginForm /></Suspense>
    </main>
  );
}
