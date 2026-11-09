import type { Metadata } from "next";
import "./globals.css";

const site = process.env.NEXT_PUBLIC_SITE_URL ?? "https://orbix-gray.vercel.app";

export const metadata: Metadata = {
  metadataBase: new URL(site),
  title: { default: "Orbix — Cloud storage & creator channels", template: "%s · Orbix" },
  description: "Orbix: private cloud storage and creator channels, made for India.",
  openGraph: { siteName: "Orbix", type: "website" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
