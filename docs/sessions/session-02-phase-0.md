# Session 02 — Phase 0 Foundation

**Date:** 26 August 2026
**Chat purpose:** Phase 0 — schema, RLS, storage, seed, WF-00, WF-00b.
**Outcome:** Phase 0 complete. Merged to `main` at `4cd0347` (PR #3,
2026-08-26T06:17:37Z). This log is reconstructed from `git log` on `main`,
migration files, PR bodies, and a **read-only** inspection of live LNI WF-00.
No n8n workflow was created, edited, activated, or executed in the session
that wrote this file.

Phase 0 was three merged PRs: #1 packet 0.1 (spec reconcile), #2 packet 0.2
(schema/RLS/storage/seed), #3 packet 0.3 (WF-00 / WF-00b).

---

## 1. What was completed (with evidence)

### Schema, RLS, storage, seed — PR #2, merge `7331a63`

Numbered forward-only migrations `001`–`010` exist in
`supabase/migrations/` and are applied on LEAP-NI. Live
`supabase_migrations.schema_migrations` (read 26 Aug 2026 via LEAP-NI MCP,
self-identified by `SELECT name, timezone FROM public.events WHERE name =
'LEAP 2026'` → `LEAP 2026` / `Asia/Riyadh`), in apply order:

`001_extensions`, `002_events_bot_state`, `003_capture_pipeline`,
`004_entities`, `005_review_support`, `006_indexes`, `007_rls_policies`,
`008_storage`, `010_processing_jobs_transition`, then `009_seed_leap_2026`.

`009` applied **after** `010` (PR #2 body). Forward-only; the version clock
is apply order, not file order. `001`–`008` and `010` were not edited after
apply. `009` was rewritten **before** apply (`cc06900`) — legal because it
had never landed.

PR #2 proofs that are in the public PR body (do not copy identifiers from
it into this repo): unset-GUC `009` raised rather than falling back to
earliest `auth.users`; duplicate `telegram_file_unique_id` failed on
`assets_telegram_file_unique_id_key` (23505); second-user PostgREST returned
HTTP 403 on all 16 tables.

### WF-00 and WF-00b — PR #3, merge `4cd0347`

Live LNI WF-00 (name confirmed **before** any further read:
`LNI WF-00 - Central error handler`) was read via n8n MCP
`get_workflow_details` on 26 Aug 2026. Observed, not claimed:

- `availableInMCP: true`
- `executionTimeout: 300`
- `timezone: Asia/Riyadh`
- no `errorWorkflow` on WF-00 itself (self-pointing would recurse)
- `INSERT audit_log` is Postgres v2.6 `executeQuery` with
  `queryReplacement` as **one array expression**, `alwaysOutputData: true`,
  `retryOnFail: true`
- `Row returned?` IF → `Throw no audit row` (`stopAndError`) on empty
- `Chat id present?` sits immediately before `Telegram owner alert`
- owner and `chat_id` resolved in that same `INSERT audit_log` statement
  from `events` / `bot_state`, not `$env`
- MCP response contained **no credential refs** on the Postgres or Telegram
  nodes

WF-00b exists, name `LNI WF-00b - Credential and connectivity probe`,
`active: false`, `availableInMCP: true`. PR #3 body: first execution
self-identified — LEAP 2026 seed row on Postgres, `sb-project-ref` matched
LEAP-NI on Storage. Never activated.

No workflow JSON is committed. Repo stays identifier-free.

### ElderWise

No ElderWise project or non-`LNI ` workflow was modified in Phase 0
implementation. Archived orphans `kMozml08Q10ojVmx` and `bvXpsnMJ2FH7PE7X`
remain owner-delete items (`rules.md` §12; `workflows.md` §1).

---

## 2. What was discovered

**`$env` is denied instance-wide.** `N8N_BLOCK_ENV_ACCESS_IN_NODE` is
ENABLED. Verified 26 Aug 2026 by four failed WF-00 executions
(`masterplan.md` §5; `e4f2ba9`, `ec2084e`). Configuration is resolved from
Postgres instead. That is the correct design regardless: architecture.md §2
rule 2 says Postgres is the source of truth and n8n never holds state
between executions. Do not request the block be removed — the container is
shared with ElderWise.

**`availableInMCP: false` makes a workflow unreadable to the architect.**
Verification then degrades into accepting the implementer's report, which
`rules.md` §4 forbids. A false value is a defect (`workflows.md` §1;
`phases.md` Phase 0). Live WF-00 is `true`.

**n8n MCP strips credential refs and auto-assigns the first credential of a
type.** Observed 25–26 Aug 2026: creation response named an ElderWise
Postgres credential while saved JSON had none (`workflows.md` §1 trap 3).
A new Postgres node reached ElderWise and was caught only by
`relation "public.events" does not exist` (`c603b0a`, `1a7f347`). Binding
is proven **only** by a self-identifying execution, never by the creation
response (`rules.md` §7 rules 15–16). Restore-by-name on the existing
Leap-NI node is the bind that survived an MCP update. Do not add a
separate lookup node.

**`queryReplacement` on Postgres v2.5+ must be one expression evaluating to
an array.** Mixed CSV literals are silently dropped; `.join()` binds as one
`$1`. Verified 26 Aug 2026 (`8fe5aee`; `workflows.md` §1).

**A constant `CAST(... AS uuid)` is folded at plan time.** n8n inlines
`queryReplacement` as SQL literals under the transaction-mode pooler;
PostgreSQL constant-folds `CAST('…' AS uuid)` at **plan time**, so a
SQL-cast guard is not reliable protection — including unused `CASE ELSE`
branches (verified 26 Aug 2026: the CAST threw while `$1` was `'LEAP 2026'`).
`1f43fd8`, then `9fa5797`: the row-returned IF + `stopAndError` is
authoritative; CAST is defence in depth only.

**Neither `authenticated` nor `service_role` holds table privileges** on the
Data API path that was tested. The second-user 403s were GRANT denials, not
RLS denials (`80c6351`; masterplan.md open item 12). The 16 policies are
correct by inspection (`007_rls_policies.sql`) but inert until Phase 5
grants SELECT. `ensure_rls` setting `rowsecurity = true` does not prove
policy work.

**`bot_state` has zero rows** (live `count(*)` 26 Aug 2026, before
migration `012`). WF-00 therefore cannot resolve `chat_id`. Live
`audit_log` at that read: `workflow_error` × 2,
`workflow_error_alert_undeliverable` × 1. The undeliverable path is
working; alerts cannot deliver until `012` seeds the owner row.

---

## 3. Near-misses caught before production

**Migration 009 originally resolved the owner as the earliest `auth.users`
row** (`55859ac`: `order by created_at asc nulls last, id asc limit 1`).
That would have been a throwaway account created before the owner. Every
row would have been owned by a disposable user and RLS would have locked
the real owner out, surfacing around the first real capture on 31 August.
Rewritten in `cc06900` / documented `9544a55` to an explicit email match
via `lni.owner_email` with hard failures: missing setting, unmatched
email, unconfirmed match. No fallback to earliest row, row-count
heuristics, or a hardcoded UUID. **Never applied in the broken form.**

**A missing send-node gate meant WF-00 could exit silently.** Postgres
`{success:true}` on a zero-row write, plus `Number(undefined) >= 2` being
false, routes to `No alert` — silence, the outcome WF-00 exists to
prevent. `9fa5797` specified `Row returned?` → `stopAndError` as
authoritative, with `alwaysOutputData: true` on `INSERT audit_log` so a
zero-item result still reaches the gate. Live JSON has that gate.

**WF-00 originally held repeat-failure state in `$getWorkflowStaticData`.**
That violates architecture.md §2 rule 2 and is unreliable across queue
workers, in manual runs, and on reset. Replaced with a Postgres-backed
counter on `audit_log` (`700f901`). Live SQL counts `workflow_error` rows
for the same `workflow_name` + `node_name` in 15 minutes after insert.

---

## 4. Three architect specification errors, caught by the implementer

This is the empirical case for `rules.md` §3: author and verifier must be
different parties or the check is theatre. Claude specified; Cursor found
the spec could not stand; the document was corrected **before** the next
step, not papered over.

1. **`$env` / `LNI_OWNER_UUID` as WF-00's owner source.** Specified in
   `0894d5b`, `700f901`, `4deae61` (Set-node `$env` after Code was denied
   by the JS task runner). Implementer proved
   `N8N_BLOCK_ENV_ACCESS_IN_NODE` blocks `$env` in every node type.
   Corrected to Postgres `events` / `bot_state` (`ec2084e`). Dead env var
   names marked unused. The block stays; the container is shared.

2. **SQL CAST as the empty-owner throw.** Specified in `1f43fd8` as *the*
   throw. Implementer found plan-time constant-folding: the CAST fired
   even when the events lookup succeeded. Corrected in `9fa5797`: the
   row-returned gate is authoritative; CAST is defence in depth only.

3. **Diagnostic write as `error_detail` when `job_id` resolves, otherwise
   `audit_log`.** Original `architecture.md` text (pre-`6fd0fda`). The
   repeat counter needs a single complete series, so every handled error
   must INSERT `audit_log`; `error_detail` is additional, never instead,
   and must not touch `status` / `attempt_count`. Corrected `6fd0fda`.

---

## 5. What remains

### Owner actions
- Bind credentials in the n8n UI is already done for WF-00 / WF-00b;
  Telegram remains unproven until a real-device capture in Phase 1.
- Hard-delete archived orphans `kMozml08Q10ojVmx` and `bvXpsnMJ2FH7PE7X`
  in the UI. MCP has archive, not hard-delete.
- `LNI_OWNER_TELEGRAM_USER_ID` in gitignored `docs/environment.local.md`
  — required to apply migration `012`. Without it, WF-01 has no allowlist
  row and WF-00 alerts stay undeliverable.
- Open items 4, 5, 9, 10, 11, 12 in `masterplan.md` §8.

### Phase 1 (next)
Packet 1.1: `captures.capture_no`, `bot_state` seed, two-stage asset kind,
this session log. Then WF-01 / WF-02. Do not reopen Decisions A/B/C.

### Standing
Migrations `001`–`010` are immutable. Forward-only. Never touch ElderWise.
Never `$env`, never `$getWorkflowStaticData`. Repo is public — no literal
identifiers in commits.
