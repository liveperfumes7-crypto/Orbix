import SiteShell from "@/components/SiteShell";

export const metadata = { title: "Download Orbix" };
const APK = process.env.NEXT_PUBLIC_APK_URL || "/downloads/Orbix.apk";

export default function Download() {
  return (
    <SiteShell>
      <main className="mx-auto max-w-md px-4 py-14 text-center space-y-4">
        <div className="mx-auto h-16 w-16 rounded-2xl bg-primary grid place-items-center text-xl font-bold">OB</div>
        <h1 className="text-2xl font-bold">Get Orbix for Android</h1>
        <a href={APK} className="btn px-8 py-3" download>Download APK</a>
        <p className="text-xs text-muted">Allow “install unknown apps” for your browser when asked. Android 7.0 or newer.</p>
      </main>
    </SiteShell>
  );
}
