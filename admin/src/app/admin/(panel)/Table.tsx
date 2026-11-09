"use client";
import { useState } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";
import { cell } from "@/lib/format";

export type Action = {
  label: string;
  rpc: string;
  /** maps a row to rpc args */
  args: (row: Record<string, unknown>, input?: string) => Record<string, unknown>;
  prompt?: string; // ask for text input (UTR, note…)
  danger?: boolean;
  show?: (row: Record<string, unknown>) => boolean;
};

export default function Table({
  rows,
  columns,
  actions = [],
  empty = "Nothing here yet.",
}: {
  rows: Record<string, unknown>[];
  columns?: string[];
  actions?: Action[];
  empty?: string;
}) {
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState("");
  const cols = columns ?? (rows[0] ? Object.keys(rows[0]).filter((k) => typeof rows[0][k] !== "object") : []);

  async function run(a: Action, row: Record<string, unknown>, i: number) {
    let input: string | undefined;
    if (a.prompt) {
      input = window.prompt(a.prompt) ?? undefined;
      if (input === undefined) return;
    } else if (!window.confirm(`${a.label}?`)) return;
    setBusy(`${a.rpc}${i}`);
    const { error } = await supabaseBrowser().rpc(a.rpc, a.args(row, input));
    setBusy("");
    if (error) setMsg("Error: " + error.message);
    else window.location.reload();
  }

  if (!rows.length) return <p className="text-sm text-muted">{empty}</p>;
  return (
    <div className="card p-0 overflow-x-auto">
      {msg && <p className="p-3 text-sm text-danger" role="alert">{msg}</p>}
      <table className="w-full min-w-[640px]">
        <thead>
          <tr className="border-b border-border">
            {cols.map((c) => <th key={c} className="th">{c.replace(/_/g, " ")}</th>)}
            {actions.length > 0 && <th className="th">Actions</th>}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className="border-b border-border/60 last:border-0">
              {cols.map((c) => <td key={c} className="td">{cell(c, r[c])}</td>)}
              {actions.length > 0 && (
                <td className="td whitespace-nowrap space-x-2">
                  {actions.filter((a) => !a.show || a.show(r)).map((a) => (
                    <button key={a.label} className={a.danger ? "btn-danger" : "btn-ghost"} disabled={busy === `${a.rpc}${i}`} onClick={() => run(a, r, i)}>
                      {a.label}
                    </button>
                  ))}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
