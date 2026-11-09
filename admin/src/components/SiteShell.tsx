import Link from "next/link";

export default function SiteShell({ children, bare = false }: { children: React.ReactNode; bare?: boolean }) {
  if (bare) return <div className="min-h-screen">{children}</div>;
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-border">
        <div className="mx-auto max-w-5xl px-4 h-14 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 font-semibold">
            <span className="h-8 w-8 rounded-lg bg-primary grid place-items-center text-sm font-bold">OB</span> Orbix
          </Link>
          <nav className="flex gap-4 text-sm text-muted">
            <Link href="/#plans">Plans</Link>
            <Link href="/d" className="text-white">Download</Link>
          </nav>
        </div>
      </header>
      <div className="flex-1">{children}</div>
      <footer className="border-t border-border text-xs text-muted">
        <div className="mx-auto max-w-5xl px-4 py-6 flex flex-wrap gap-x-5 gap-y-2">
          <span>© Orbix</span>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
          <Link href="/refund">Refund policy</Link>
          <Link href="/delete-account">Delete account</Link>
          <Link href="/report-content">Report content</Link>
        </div>
      </footer>
    </div>
  );
}
