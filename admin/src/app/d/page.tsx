import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Download Orbix" };
const APK = process.env.NEXT_PUBLIC_APK_URL || "/downloads/Orbix.apk";

export default function Download() {
  return (
    <SiteShell>
      <main className="mx-auto max-w-md px-4 py-16 text-center space-y-4">
        <div className="mx-auto h-20 w-20 rounded-3xl bg-brand grid place-items-center text-2xl font-bold text-white">OB</div>
        <h1 className="text-3xl font-bold text-slate-900">Get Orbix for Android</h1>
        <p className="text-slate-600">15 GB free cloud storage, creator channels and Premium plans.</p>
        <a href={APK} className="btn px-8 py-3" download>Download APK</a>
        <p className="text-xs text-slate-500">If your phone asks, allow “install unknown apps” for your browser. Android 7.0 or newer.</p>
      </main>
    </SiteShell>
  );
}
