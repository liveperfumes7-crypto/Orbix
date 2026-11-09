import Link from "next/link";

const email = process.env.NEXT_PUBLIC_SUPPORT_EMAIL || "help.orbix@gmail.com";

export function Logo() {
  return (
    <Link href="/" className="flex items-center gap-2 font-bold text-lg text-slate-900">
      <span className="h-8 w-8 rounded-lg bg-brand grid place-items-center text-sm font-bold text-white">OB</span> Orbix
    </Link>
  );
}

export default function SiteShell({ children, bare = false }: { children: React.ReactNode; bare?: boolean }) {
  if (bare) return <div className="min-h-screen">{children}</div>;
  return (
    <div className="site min-h-screen flex flex-col">
      <header className="sticky top-0 z-10 border-b border-slate-200 bg-white/95 backdrop-blur">
        <div className="mx-auto max-w-6xl px-4 h-14 flex items-center justify-between">
          <Logo />
          <nav className="flex items-center gap-4 text-sm text-slate-600">
            <Link href="/#features" className="hidden sm:inline">Features</Link>
            <Link href="/#security" className="hidden sm:inline">Security</Link>
            <Link href="/#pricing">Pricing</Link>
            <Link href="/report-content" className="hidden sm:inline">Help Center</Link>
            <Link href="/d" className="btn !py-1.5">Download</Link>
          </nav>
        </div>
      </header>
      <div className="flex-1">{children}</div>
      <footer className="bg-slate-900 text-slate-300 text-sm">
        <div className="mx-auto max-w-6xl px-4 py-12 grid gap-10 sm:grid-cols-2">
          <div>
            <h3 className="font-semibold text-white">About</h3>
            <p className="mt-2 text-lg italic text-white">Orbix by As Enterprice</p>
            <p className="mt-1">Private cloud storage and creator channels, made for India.</p>
            <p className="mt-1">Email: <a className="underline" href={`mailto:${email}`}>{email}</a></p>
          </div>
          <div>
            <h3 className="font-semibold text-white">Legals</h3>
            <ul className="mt-2 space-y-1.5">
              <li><Link href="/privacy">Privacy Policy</Link></li>
              <li><Link href="/refund">Refund Policy</Link></li>
              <li><Link href="/terms">Terms and Conditions</Link></li>
              <li><Link href="/community-guidelines">Community Guidelines</Link></li>
              <li><Link href="/delete-account">Delete Account</Link></li>
              <li><Link href="/report-content">Report Content</Link></li>
            </ul>
          </div>
        </div>
        <p className="border-t border-slate-700 py-5 text-center text-xs text-slate-400">Copyright © 2026 Orbix. All rights reserved.</p>
      </footer>
    </div>
  );
}
