"use client";
import { useEffect, useState } from "react";
import { fromAd, loadPixel, recordClick } from "@/components/MetaPixel";

/** Download button. People who came from an ad get the ads build; the tap is sent to Meta as a Lead. */
export default function DownloadButton({ apk, adsApk }: { apk: string; adsApk: string }) {
  const [href, setHref] = useState(apk);
  useEffect(() => { if (fromAd()) setHref(adsApk); }, [adsApk]);
  const onClick = () => {
    const id = "lead-" + crypto.randomUUID();
    loadPixel().then((pixel) => {
      if (pixel) window.fbq!("track", "Lead", { content_name: "apk_download" }, { eventID: id });
      recordClick(id);
    });
  };
  return <a href={href} onClick={onClick} className="btn px-8 py-3" download>Download APK</a>;
}
