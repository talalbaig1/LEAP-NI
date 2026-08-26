---
name: lni-n8n-conventions
description: >-
  LNI n8n conventions that override any general n8n skill. Use when creating,
  editing, verifying, or calling n8n workflows, the n8n REST API, or n8n MCP
  for LEAP-NI. Forbids $env, $getWorkflowStaticData, ElderWise changes, instance
  restarts, and instance-wide API misuse.
---

# LNI n8n conventions

Project documents win over any installed n8n skill. A general skill will
recommend `$env` and `$getWorkflowStaticData`. Both are **FORBIDDEN** here
(`rules.md` §7 rule 18; `architecture.md` §2; `workflows.md` §1).

## 1. `$env` is denied instance-wide

`N8N_BLOCK_ENV_ACCESS_IN_NODE` is ENABLED on this instance. `$env` is denied
in every node type. Resolve **all** configuration from Postgres. Do not
design against `$env`. Do not request the block be removed — the container
is shared with ElderWise (`docs/environment.example.md`, `masterplan.md`).

## 2. Never `$getWorkflowStaticData`

Postgres is the source of truth. n8n static data is not shared across queue
workers, is unreliable in manual runs, and is lost on reset
(`workflows.md` WF-00; `architecture.md` §2 rule 2).

## 3. `availableInMCP: true` on every LNI workflow

A false value is a defect. Architect verification is by live JSON read-back
(`rules.md` §4; `workflows.md` §1; `phases.md` Phase 0).

## 4. `errorWorkflow` = LNI WF-00's ID

Never ElderWise's. Set per workflow; it is not inherited. WF-00 itself has
**no** `errorWorkflow` (self-pointing would recurse).

## 5. Never set `language` on a transcription node

Forcing English on Arabic or code-switched audio yields confident garbage,
not an error. ElderWise WF-5 hardcodes `language: "en"` — never copy that
(`rules.md` §7 rule 1; `workflows.md` §1 trap 1).

## 6. All cron schedules explicitly `Asia/Riyadh`

Never inherit the container default. A UTC container fires the 7 AM briefing
at 10 AM Riyadh (`rules.md` §7 rule 2; `workflows.md` §1).

## 7. Postgres only via Supavisor pooler, transaction mode

Shared pooler, port 6543, SSL `Require`. No prepared statements. A
`prepared statement does not exist` error is the pooler, not a bad query
(`architecture.md` §9; `rules.md` §7 rule 17).

## 8. MCP credential auto-assignment is not proof

MCP strips credential refs and auto-assigns the first credential of a type.
Observed: creation response named an ElderWise Postgres credential while
saved JSON had none. Bind explicitly in the n8n UI. Binding is proven
**only** by a self-identifying execution, never by the creation response
(`workflows.md` §1 trap 3; `rules.md` §7 rules 15–16).

## 9. Explicit gate before any send node

A zero-row Postgres `UPDATE` emits `{success:true}` and crashes downstream
sends (`rules.md` §7 rule 11; `workflows.md` §1).

## 10. Parameterised SQL via `queryReplacement` only

Never string-concatenate. n8n Postgres v2.5+: `queryReplacement` **must be
one expression that evaluates to an array** `{{ [a, b, c] }}`. Mixed CSV
literals are dropped; `.join()` binds as one `$1`. Verified 26 Aug 2026
(`workflows.md` §1; `rules.md` §7 rule 10).

## 11. Timeouts, retries, terminals

- `executionTimeout`: 300
- `retryOnFail: true` on provider and DB nodes
- Explicit NoOp terminals on correct outcomes
- `stopAndError` on received-but-not-stored media (and wrong-database), so WF-00 runs

## 12. Never read `$json` or `$item.binary` from the previous item after I/O

Never read `$json` or `$item.binary` from the immediately preceding node
when any Postgres, HTTP, Crypto, or Code node sits between you and the
data you need. Source every field from the NAMED node that produced it.
Postgres with `alwaysOutputData` emits an empty item on zero rows; Crypto
emits a json-only item. Both look like success and both blank the context.

Verified 26 Aug 2026 on WF-01:

- `Duplicate check` → `{}` → `Resolve payload` used `$json.owner_id` →
  WF-02 `malformed_payload` → success NoOp, assets lost.
- `Hash sha256` → json-only item → `Prep upload` forwarded empty binary →
  Storage PUT: no binary file `'data'`.

```
{{ $('Attach correlation').item.json.owner_id }}
$('Telegram getFile').item.binary
```

`$json` is only safe on the node that just produced those fields. Equal
in rank to `$env` and MCP auto-assign. Flags we depend on (`download`,
`minutesInterval`) must be explicit in the saved JSON.

**Binary and size — three standing rules (verified 26 Aug 2026).**

1. This instance stores binary as **filesystem-v2**. Code nodes can
   **create** filesystem binaries (`prepareBinaryData`,
   `setBinaryDataBuffer`) but **cannot read** them: `getBinaryStream`,
   `binaryToBuffer`, `getBinaryMetadata`, `getBinaryPath`,
   `createReadStream` all deny; `getBinaryDataBuffer` returns nothing
   usable. Never write Code that reads bytes. Proven by executions
   245200 / 245231 / 245237.
2. A **pinned** item is inline base64 and is a **different program** from
   a real download (`data: "filesystem-v2"` + filesystem `id`). Pinned
   fixtures are not evidence for anything touching binary. Three green
   fixtures preceded three real-device failures. Filesystem-shaped
   proof (HTTP `responseFormat: file`, not a pin): executions
   245307 / 245335 / 245341.
3. File size is **measured by reading the stored object back** (HEAD
   `Content-Length`), never from item metadata (`bin.bytes`,
   `bin.fileSize`) and never from a Code-computed buffer length (the
   sandbox cannot open the file). Telegram `getFile` `file_size` is **not**
   the stored value — it is an independent second opinion that must
   **agree** with HEAD. Two sources that disagree is a defect; one source
   you cannot check is a hope. Do not "fix" this back into trusting
   metadata as `size_bytes`.

**WF-02 owns every decision about what the owner is told; WF-01 owns only
the sending.** WF-01 never re-derives a condition WF-02 has already
evaluated. `reply_text` non-empty means send; empty means stay silent.
Do not add `adopted` (or any second field) that must stay in agreement
with `reply_text`.

## 13. Never log secrets or PII

Never log tokens, keys, signed URLs, transcripts, emails, or phone numbers.
Request IDs and redacted errors only (`rules.md` §7 rule 8; WF-00 redaction).

## 14. Never touch ElderWise or restart n8n

Never touch the ElderWise project or workflows. Never restart, upgrade, or
change settings on the shared n8n container (`rules.md` §7 rule 12; §12).

## 15. INSTANCE-WIDE n8n API key guard

The key (`N8N_API_KEY` in gitignored `docs/n8n.local.env`) is
**instance-wide**: write/delete all 52 workflows, including ElderWise
WhatsApp inbound with real users.

API may be used **ONLY** against workflows whose name begins with `LNI ` or
`LNI-TEST-`, plus archived orphans `kMozml08Q10ojVmx` and `bvXpsnMJ2FH7PE7X`
(verify by **NAME** before any delete).

- Never list-and-act in one step. Fetch, check name, then act.
- Never call a destructive endpoint against an unprefixed workflow.
- Never restart, upgrade, or change instance settings.
- If an operation would touch anything else: **STOP and report.**
  `rules.md` §12.
