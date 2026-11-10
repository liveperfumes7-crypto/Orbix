"use client";
import { useState } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";
import { cell } from "@/lib/format";

type Row = Record<string, unknown>;
/** A visibility rule: every rule in the list must hold for the button to show. */
export type Rule = { field: string; is?: unknown; not?: unknown; truthy?: boolean };

/**
 * Plain data only (no functions) so server pages can pass it to this client component.
 * args values: "$row.<field>" = a field of the row, "$input" = the text the admin typed, anything else = literal.
 */
export type Action = {
  label: string;
  rpc: string;
  args: Record<string, unknown>;
  prompt?: string; // ask for text input (UTR, note…)
  danger?: boolean;
  show?: Rule[];
};

const resolveArgs = (args: Record<string, unknown>, row: Row, input?: string) =>
  Object.fromEntries(
    Object.entries(args).map(([k, v]) => [
      k,
      v === "$input" ? input ?? "" : typeof v === "string" && v.startsWith("$row.") ? row[v.slice(5)] : v,
    ]),
  );

const visible = (rules: Rule[] | undefined, row: Row) =>
  !rules ||
  rules.every((r) => {
    const v = row[r.field];
    if ("is" in r && v !== r.is) return false;
    if ("not" in r && v === r.not) return false;
    if (r.truthy !== undefined && !!v !== r.truthy) return false;
    return true;
  });

/** Internal ids are needed by the action buttons but are noise on screen. */
const HIDDEN = new Set(["id", "user_id", "channel_id", "post_id", "plan_id", "created_by"]);
const BADGE_COLS = new Set(["status", "review_status", "ads_access_status", "activation_kind", "audience", "source", "kind"]);
const TONE: Record<string, string> = {
  paid: "bg-success/15 text-success", approved: "bg-success/15 text-success", published: "bg-success/15 text-success", auto: "bg-success/15 text-success",
  pending: "bg-warning/15 text-warning", review: "bg-warning/15 text-warning", submitted: "bg-warning/15 text-warning", open: "bg-warning/15 text-warning",
  failed: "bg-danger/15 text-danger", rejected: "bg-danger/15 text-danger", revoked: "bg-danger/15 text-danger", cancelled: "bg-white/10 text-muted",
};

function show(col: string, v: unknown) {
  if (typeof v === "boolean") return v ? <span className="text-success">Yes</span> : <span className="text-muted">No</span>;
  if (BADGE_COLS.has(col) && typeof v === "string" && v)
    return <span className={"inline-block rounded-full px-2 py-0.5 text-xs " + (TONE[v] ?? "bg-white/10 text-white")}>{v.replace(/_/g, " ")}</span>;
  return cell(col, v);
}

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
  const cols = columns ?? (rows[0] ? Object.keys(rows[0]).filter((k) => !HIDDEN.has(k) && (rows[0][k] === null || typeof rows[0][k] !== "object")) : []);

  async function run(a: Action, row: Record<string, unknown>, i: number) {
    let input: string | undefined;
    if (a.prompt) {
      input = window.prompt(a.prompt) ?? undefined;
      if (input === undefined) return;
    } else if (!window.confirm(`${a.label}?`)) return;
    setBusy(`${a.label}${i}`);
    setMsg("");
    const { error } = await supabaseBrowser().rpc(a.rpc, resolveArgs(a.args, row, input));
    setBusy("");
    if (error) setMsg("Error: " + error.message);
    else window.location.reload();
  }

  if (!rows.length) return <p className="card text-sm text-muted">{empty}</p>;
  return (
    <div className="card p-0 overflow-x-auto">
      {msg && <p className="p-3 text-sm text-danger" role="alert">{msg}</p>}
      <table className="w-full min-w-[640px]">
        <thead>
          <tr className="border-b border-border bg-white/[0.02]">
            {cols.map((c) => <th key={c} className="th">{c.replace(/_/g, " ")}</th>)}
            {actions.length > 0 && <th className="th">Actions</th>}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={(r.id as string) ?? i} className="border-b border-border/60 last:border-0 hover:bg-white/[0.02]">
              {cols.map((c) => <td key={c} className="td max-w-[280px] break-words">{show(c, r[c])}</td>)}
              {actions.length > 0 && (
                <td className="td">
                  <div className="flex flex-wrap gap-2">
                    {actions.filter((a) => visible(a.show, r)).map((a) => (
                      <button key={a.label} className={a.danger ? "btn-danger" : "btn-ghost"} disabled={busy !== ""} onClick={() => run(a, r, i)}>
                        {busy === `${a.label}${i}` ? "Working…" : a.label}
                      </button>
                    ))}
                  </div>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
