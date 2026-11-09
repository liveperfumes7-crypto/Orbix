"use client";
import { useState } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";

export default function FlushMeta() {
  const [msg, setMsg] = useState("");
  return (
    <div className="flex items-center gap-3">
      {msg && <span className="text-xs text-muted">{msg}</span>}
      <button
        className="btn-ghost"
        onClick={async () => {
          setMsg("Sending…");
          const { data, error } = await supabaseBrowser().functions.invoke("meta-send", { body: { action: "flush" } });
          setMsg(error ? "Failed: " + error.message : "Done: " + JSON.stringify(data));
        }}
      >
        Send queued events now
      </button>
    </div>
  );
}
