"use client";
import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase/client";

type Fbq = ((...args: unknown[]) => void) & { queue?: unknown[]; loaded?: boolean; version?: string; push?: unknown; callMethod?: (...a: unknown[]) => void };
declare global {
  interface Window { fbq?: Fbq; _fbq?: Fbq; __orbixPixel?: Promise<string | null> }
}

const cookie = (name: string) => {
  const m = document.cookie.match(new RegExp("(?:^|; )" + name + "=([^;]*)"));
  return m ? decodeURIComponent(m[1]) : "";
};

/** True when the visitor arrived from a Meta ad (Meta adds fbclid to the link). */
export function fromAd() {
  const q = new URLSearchParams(window.location.search);
  if (q.get("fbclid")) return true;
  if (/^(meta|facebook|instagram|ig|fb)$/i.test(q.get("utm_source") ?? "")) return true;
  try { return sessionStorage.getItem("orbix_ad") === "1"; } catch { return false; }
}

/** Loads the Meta Pixel with the ID saved in the admin panel. Resolves to null when Meta is off. */
export function loadPixel(): Promise<string | null> {
  if (window.__orbixPixel) return window.__orbixPixel;
  window.__orbixPixel = (async () => {
    try {
      const { data } = await supabaseBrowser().rpc("meta_public");
      const id = String((data as { pixel_id?: string } | null)?.pixel_id ?? "");
      if (!/^\d{5,20}$/.test(id)) return null;
      if (!window.fbq) {
        const n: Fbq = function (...args: unknown[]) { if (n.callMethod) n.callMethod(...args); else n.queue!.push(args); } as Fbq;
        n.push = n; n.loaded = true; n.version = "2.0"; n.queue = [];
        window.fbq = n; window._fbq = n;
        const s = document.createElement("script");
        s.async = true; s.src = "https://connect.facebook.net/en_US/fbevents.js";
        document.head.appendChild(s);
      }
      window.fbq!("init", id);
      return id;
    } catch { return null; }
  })();
  return window.__orbixPixel;
}

/** Saves the ad click (fbclid / _fbc / _fbp) so a later install and purchase can be matched to it. */
export async function recordClick(leadEventId?: string) {
  try {
    const q = new URLSearchParams(window.location.search);
    let fbclid = q.get("fbclid") ?? "";
    try {
      if (fbclid) { sessionStorage.setItem("orbix_fbclid", fbclid); sessionStorage.setItem("orbix_ad", "1"); }
      else fbclid = sessionStorage.getItem("orbix_fbclid") ?? "";
    } catch { /* storage blocked */ }
    await supabaseBrowser().rpc("record_ad_click", {
      p_fbclid: fbclid, p_fbc: cookie("_fbc"), p_fbp: cookie("_fbp"),
      p_url: window.location.origin + window.location.pathname, p_lead_event_id: leadEventId ?? null,
    });
  } catch { /* tracking must never break the page */ }
}

export default function MetaPixel() {
  const path = usePathname();
  useEffect(() => {
    let live = true;
    loadPixel().then((id) => {
      if (!live || !id) return;
      window.fbq!("track", "PageView");
      // Give the pixel a moment to write its cookies, then remember the click.
      if (fromAd() && new URLSearchParams(window.location.search).get("fbclid")) setTimeout(() => recordClick(), 1200);
    });
    return () => { live = false; };
  }, [path]);
  return null;
}
