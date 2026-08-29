# workflows.md

**LEAP Networking Intelligence (LNI)** · n8n Workflow Specifications
Version 2.0 · 26 August 2026

**Instance:** `<N8N_HOST>`
**Naming:** all LNI workflows prefixed `LNI WF-nn - <name>`
**Test variants:** prefixed `LNI-TEST-`

> **Documentation precedes implementation.** A workflow is specified here
> *before* it is built. See `rules.md` §1.

---

## 1. Instance conventions

Copy the discipline already proven in the owner's ElderWise workflows.

| Convention | Value | Reason |
|---|---|---|
| `errorWorkflow` | LNI WF-00's own ID | Pointing an LNI workflow at ElderWise's error workflow is a defect. Set per workflow; it is not inherited. |
| `availableInMCP` | `true` on every LNI workflow | A workflow with MCP access off cannot be read back by the architect. Verification then degrades to accepting the implementer's report, which `rules.md` §4 forbids. A false value is a defect, not a preference. |
| `executionTimeout` | 300 | Matches proven ElderWise setting |
| Postgres queries | Parameterised via `queryReplacement` | Never string-concatenate SQL. On this instance (Postgres node v2.5+) the replacement **must be one expression that evaluates to an array**: `{{ [a, b, c] }}` (n8n docs). A CSV that mixes a literal with `{{ }}` drops the literal, so `$1` is the first expression. `.join()` on that array binds as a single `$1`. Verified 26 Aug 2026. |
| Idempotency | `ON CONFLICT ... DO NOTHING` on the natural key | ElderWise `media_id` pattern |
| Terminal branches | Explicit NoOp **or** `stopAndError` | Makes every path visibly terminal. Correct outcomes are silent NoOps. A received-but-not-stored asset is a failure: `stopAndError` so WF-00 runs. |
| Retries | `retryOnFail: true` on all provider and DB write nodes | — |
| Cron timezone | **Explicitly `Asia/Riyadh`** | Never inherit the container default |
| Empty result guard | Explicit gate before any send node | Postgres emits `{success:true}` when an UPDATE matches zero rows, which crashes downstream sends. A real SQL row with `captured = 0` is a valid report and SHOULD send. An empty item from `alwaysOutputData` on zero rows is NOT a report and must NOT send. These are different things and the gate exists to tell them apart. Never gate on `captured > 0`. |
| Scheduled send | Parallel Telegram + Gmail; Merge after both attempts | Delivery is proven by Telegram `message_id` or Gmail `id` via `$('Node').first()` — never `.item` across the Merge, never by "the node ran". `stopAndError` only when both channels are empty or both failed. Email exists to survive a Telegram-specific death (revoked token, blocked bot, outage). Serial Gmail-behind-Telegram makes email depend on the thing it insures against. **This is the standard for every scheduled LNI send (WF-07, WF-09).** WF-09 MUST use this topology and must not copy WF-07's old serial graph. |
| Who decides what the owner is told | **Callee decides; WF-01 sends inbound replies** | WF-02 / on-demand WF-07 / WF-08 return `reply_text`. WF-01 never re-derives a condition the callee already evaluated. `reply_text` non-empty means send; empty means stay silent. Do not add a second field that must stay in agreement with `reply_text`. Scheduled WF-07 / WF-09 send on their own execution (`chat_id` from `bot_state`, same as WF-00) because a cron tick has no parent WF-01. WF-02 never sends. Verified 26 Aug 2026 (exec 245471). |
| Configuration source | Postgres, never `$env` | `$env` is blocked instance-wide, and configuration outside Postgres violates architecture.md §2 rule 2 regardless. |
| Runtime identifiers | Postgres or gitignored local config | Repo is public. Never commit a Telegram user ID, project ref, owner UUID, key, or connection string. Placeholders in committed files; real values only in gitignored `docs/environment.local.md`. |
| `binaryMode` | `"separate"` (workflow `settings`) | JSON and binary stay on separate item properties. Required for Telegram download → sha256 → Storage PUT. Undocumented defaults cannot be verified by read-back. Set explicitly on every LNI workflow that handles files (WF-00 / WF-00b / WF-02 already have it; WF-01 must too). |

### Traps already identified

**Never set `language` on a transcription node.** ElderWise WF-5 hardcodes
`language: "en"`. Forcing English decoding on Arabic or code-switched audio
produces confident garbage rather than an error.

**Never inherit cron timezone.** If the container runs UTC, a 7 AM briefing
fires at 10 AM Riyadh — after the owner has left for the venue, making it
worthless. One line, classic silent failure.

`n8n-nodes-base.scheduleTrigger` **v1.3** on this build has **no
node-level timezone property**. The TypeScript schema is only
`rule.interval` (field / cron expression / minutesInterval / …).
**`settings.timezone` is the only lever.** Corroborated 27 Aug 2026
against live WF-02 `Schedule sweep` (minutes interval, no timezone on
the node; workflow `settings.timezone` = `Asia/Riyadh`). Proof of
timezone is an **observed execution `startedAt`**, never the cron
string and never a node parameter.

**MCP `create_workflow_from_code` persists NEITHER settings NOR
credentials.** It injects `availableInMCP` and platform-default
`executionOrder`, drops `timezone` / `errorWorkflow` /
`executionTimeout`, and auto-binds the FIRST credential of each type
on the instance — which is ElderWise Postgres (`WH9oLDfKfOX6KW5F`) and
an unrelated Telegram bot. Proven on WF-07, 27 Aug 2026. Every
MCP-created LNI workflow REQUIRES a REST PUT of settings and an
explicit credential rebind before first execution. The create response
is not evidence. Self-identify is what caught it — keep that node on
every workflow that reads Postgres.

This supersedes the 25 Aug observation (creation response named
ElderWise Postgres while saved JSON had no credential). The 27 Aug
read-back is stronger: REST GET showed ElderWise Postgres and
`Laila_neversleeps_bot` actually bound. Same procedure for WF-08 and
WF-09.

Two consequences, both binding:

1. **REST PUT settings and credentials** (GET-name-check first; no
   `active`; strip `binaryMode`), then confirm by read-back before the
   first execution. Never accept the creation response as evidence.
   The n8n UI bind is an equivalent if a human does it.
2. **Make the first execution self-identifying.** A read-only probe that returns
   *which* system it reached beats one that returns success. The Storage probe
   proved the project via the `sb-project-ref` response header; a bare `200`
   would have proved nothing. An LNI workflow silently bound to ElderWise
   credentials would go green against the wrong database. **WF-00b is the
   workflow specified to carry this principle.**

   With an n8n API key present, auto-assign on a WRITE is dangerous — a
   failed SELECT is harmless; a WRITE would not fail politely. New Postgres
   nodes auto-assign ElderWise. Before any node that WRITES, verify the bound
   credential with a self-identifying READ first. Never trust the MCP
   creation response. Never act on a workflow whose name does not begin with
   `LNI ` (`LNI-TEST-` allowed for disposable tests). Owner handles deletion
   of archived `kMozml08Q10ojVmx` and `bvXpsnMJ2FH7PE7X` — implementer must
   not spend time on them.

**Unchanged row counts are not a branch prove.** Contact and vcard
both store nothing, so captures/assets/jobs staying at 55 / 59 / 61
does not tell them apart. Exec 256611 was `branch=contact`; the
vcard named rule first executed on **256753**. Architect accepted
B7 on counts, then reversed on execution read-back. Rule 2
(read-back of the live artefact, not the report) cuts both ways.

**Backslash escapes in jsCode written through the n8n REST API must be
DOUBLED in the JSON payload.** Single `\b` is valid JSON for backspace, so
it succeeds silently with the wrong value - a regex word boundary
becomes a control character and the pattern never matches. Single `\d`
`\w` `\s` are invalid JSON escapes and are mangled differently. Proven on
WF-08 'Guard extra fields', 27 Aug 2026, where want_contact could
never be true for an English question. WF-01 'Classify update' has
split(/\\s+/) correctly doubled - the failure is inconsistent
authoring, which is why it will recur. Prefer patterns with no
backslash escapes in any jsCode written via REST.

**Never read `$json` or `$item.binary` from the immediately preceding node
when any Postgres, HTTP, Crypto, or Code node sits between you and the
data you need. Source every field from the NAMED node that produced it.
Postgres with `alwaysOutputData` emits an empty item on zero rows; Crypto
emits a json-only item. Both look like success and both blank the context.**

Two failures, one pattern (verified 26 Aug 2026 on WF-01):

1. `Duplicate check` → `{}` → `Resolve payload` read `$json` → dropped
   `owner_id` / `telegram_user_id` / `correlation_id` → WF-02
   `malformed_payload` → success NoOp, three assets lost.
2. `Hash sha256` hashed `binary.data` into `json.sha256` and emitted a
   json-only item → `Prep upload` forwarded `$input.binary` (empty) →
   Storage PUT looked for `'data'` and failed. Capture opened, 0 assets.

`$json` / `$item.binary` are only safe on the node that just produced
those fields. Behaviour we depend on (Telegram `download`, sweep
`minutesInterval`) must be **explicit in the saved JSON** — defaults
cannot be verified by read-back.

`$('Node').item` resolves through the paired-item chain and throws
when that node is not an ancestor of the current item. Across a
Merge with useDataOfInput, the discarded branch is NOT an ancestor.
Use `$('Node').first()` for cross-branch reads after a Merge. Named-
node sourcing is necessary but not sufficient - `.item` still carries
a lineage dependency that `.first()` does not.

**Absent Telegram `parse_mode` is NOT plain text on this build.**
Execution **254927** (WF-09, before `parse_mode` was set) returned
verbatim: `Bad Request: can't parse entities: Can't find end of the
entity starting at byte offset 121`. Default Markdown treated `_` in
`failed_24h` as an unclosed italic. WF-07 `Telegram digest` had
`parse_mode` **absent** — the day-close line `#n needs_review: …`
would hit the same failure the first time any capture is flagged
(first real event day). Packet 3.7b: both scheduled Telegram sends
set `parse_mode: HTML` explicitly. Compose must HTML-escape `&`,
then `<`, then `>` **before** the string reaches a Telegram node
(`telegram_text`). Do not feed that escaped string to Gmail
(`emailType: text`) — Gmail keeps `reply_text` plain. An ampersand
in a company name under HTML is the same class of send-break as `_`
under implicit Markdown.

**Empty item vs zero counts (packet 3.6).** A real SQL row with
captured = 0 is a valid report and SHOULD send.
An empty item from alwaysOutputData on zero rows is NOT a report and
must NOT send. These are different things and the gate exists to tell
them apart. Never gate on captured > 0.

**Scheduled send topology (packet 3.6) — STANDARD for every scheduled
LNI workflow.** Fan-out from the scheduled-send gate. Send Telegram and
Gmail in parallel. Merge **after** both attempts, never before (a
Telegram `retryOnFail` must not delay mail). Delivery is proven by
Telegram `message_id` or Gmail `id` via `$('Node').first()` — never
`.item` across the Merge, never by "the node ran".
`stopAndError` only when both channels are empty or both failed.
Empty `chat_id` is not fatal by itself if email is present.

Email exists to survive a Telegram-specific death, and serial wiring
makes email depend on the thing it insures against. **WF-09 MUST use
this and must not copy WF-07's old serial graph** (`Telegram digest` →
`Email present?` → `Gmail digest`).

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
   fixtures preceded three real-device failures.
3. File size is **measured by reading the stored object back** (HEAD
   `Content-Length`), never from item metadata (`bin.bytes`,
   `bin.fileSize`) and never from a Code-computed buffer length (the
   sandbox cannot open the file). Telegram `getFile` `file_size` is **not**
   the stored value — it is an independent second opinion that must
   **agree** with HEAD. Two sources that disagree is a defect; one source
   you cannot check is a hope. Do not "fix" this back into trusting
   metadata as `size_bytes`.

**Filesystem-shaped proof (packet 1.3e, 26 Aug 2026).** Pins were not used.
`LNI-TEST-13e-filesystem` fetched a real JPEG via HTTP Request
`responseFormat: file` (picsum 1200×800, source `Content-Length` 117383).
Item shape: `data: "filesystem-v2"`, `id: filesystem-v2:workflows/…/binary_data/…`
— not inline base64. Same Prep (copy only) / PUT / HEAD / size-match / Insert
as live WF-01.

| Proof | Exec | Result |
|---|---|---|
| A shape | 245307 | filesystem-v2, not inline |
| B numbers | 245307 | source CL **117383**, PUT **200**, HEAD CL **117383**, `assets.size_bytes` **117383** — they match |
| C truncation | 245335 | declared `file_size=1`, HEAD 117383 → `stopAndError`; Insert did not run; no row |
| D missing object | 245341 | PUT 200 to one path, HEAD another → 400 → `stopAndError`; Insert did not run; no row |
| E cleanup | 245354 | Storage DELETE 200 ×3; asset `lni13efsB` deleted; throwaway capture 20 deleted; GET-name then DELETE both TEST workflows (404 after). Capture **#9** left `processing` / `close_reason=auto`. |

**WF-02 owns every decision about what the owner is told; WF-01 owns only
the sending.** WF-01 never re-derives a condition WF-02 has already
evaluated. `reply_text` non-empty means send; empty means stay silent.
Batch and non-adopted `resolve_target` already return empty `reply_text`.
Do **not** add `adopted` to the return contract so WF-01 can re-test it
(defect 10, exec 245471: Compose dropped `adopted`; the photo IF and the
text IF tested that absent field through different operators and could
disagree).

**`capture_no` is a number.** The contract field is numeric (`0`). n8n
Postgres returns bigint as a **string** (`"23"` on exec 245471). Compose
**must** `Number()` it before returning. Cosmetic today; `/fix <n>` in
Phase 2 will parse it.

**Packet 1.3f proof (exec 245685, `LNI-TEST-13f-reply-text`, then deleted).**
`resolve_target` with nothing open: `reply_text` =
`Opened capture #32 (nothing was open — adopted)` (non-empty);
`capture_no` type **number**. Same call with that capture open:
`reply_text` = `""`. Batch `resolve_target`: `reply_text` = `""`.
Throwaway captures 32/33 deleted; #9 and #21–#31 kept. `bot_state` restored
to `normal` / nothing open.

---

## 2. Workflow inventory

| ID | Name | Phase | Trigger |
|---|---|---|---|
| WF-00 | Central error handler | 0 | Error trigger |
| WF-00b | Credential and connectivity probe | 0 | Manual trigger |
| WF-01 | Telegram ingest router | 1 | Telegram trigger |
| WF-02 | Capture lifecycle | 1 | Called by WF-01 + Schedule (sweep, every 5 min, Asia/Riyadh) |
| WF-03 | Asset processors | 2 | Manual + Execute Workflow Trigger. Called **once** per kick by WF-02 `/done` **and** the inactivity sweep (`waitForSubWorkflow: false`, `onError: continueRegularOutput`) |
| WF-04 | Structured extraction | 2 | Manual + Execute Workflow Trigger. Claims `job_type='extraction'` from Postgres. Called **once** per kick by WF-03 (`waitForSubWorkflow: false`, `onError: continueRegularOutput`) |
| WF-05 | Entity resolution | 2 | Manual + Execute Workflow Trigger. Claims `job_type='entity_resolution'` from Postgres. Called **once** per kick by WF-04 (`waitForSubWorkflow: false`, `onError: continueRegularOutput`) |
| WF-06 | Enrichment | 4 | Manual + Schedule (built **INACTIVE**; packet 4.7 does not publish). Drains `job_type='enrichment'`. WF-05 **enqueues** only; it does not dispatch. Enqueued jobs wait. That is intended. |
| WF-07 | Digests | 3 | Schedule + on demand |
| WF-08 | Query (`/ask`) | 3 | Called by WF-01 |
| WF-09 | Watchdog | 3 | Schedule, every 15 min |

---

## WF-00 — Central error handler

**Phase 0** · **Trigger:** n8n Error Trigger

Receives errors from every LNI workflow.

1. Extract workflow name, node name, execution ID, error message.
2. **Redact** before doing anything else: no secrets, no signed URLs, no media
   bytes, no transcript content, no email addresses, no phone numbers.

   **Known limitation.** The redact function also strips every comma and every
   quote from extracted fields. That is a workaround for n8n Postgres v2.5+
   `queryReplacement` (CSV-split / `stringToArray`). It works; it permanently
   degrades diagnostics (error text cannot contain `,` `'` `"`). The better
   fix is a **single `jsonb` parameter** for the whole payload. Do that
   post-event; do not change the workaround during LEAP.

3. Write redacted diagnostics. Every handled error **INSERT**s one
   `audit_log` row (`actor_type = system`, `action = workflow_error`). That
   row is the source of truth for repeat detection (architecture.md §2
   rule 2: Postgres holds state; n8n does not). This is **every** error,
   not an otherwise-only write: the hit counter needs a single complete
   series. A **lost asset MUST produce an error execution** so this handler
   runs. A success NoOp after media was received but not stored is a defect
   (`architecture.md` §2 rule 5). Silence to the owner (`prd.md` §5) is not
   silence to the operator. Where a `job_id` is also resolvable,
   **additionally UPDATE**
   `processing_jobs.error_detail` only — do not change `status` or
   `attempt_count`, so the `last_transition_at` trigger does not fire.
   Recording a diagnostic is not a state transition and must not reset
   the watchdog clock.

   `audit_log.owner_id` is NOT NULL. Resolve both runtime values from
   Postgres — never `$env`, never a workflow-level constant, never a
   committed file (the repo is public; masterplan.md §5; architecture.md
   §2 rule 2):

   - `owner_id` ← parameterised
     `SELECT owner_id FROM public.events WHERE name = $1 LIMIT 1`
     with `$1` bound from the Code node field `event_name` (`'LEAP 2026'`,
     the public 009 seed). `queryReplacement` is the array expression
     `{{ [event_name, workflow_name, node_name, execution_id,
     redacted_message, request_id] }}` — not a CSV, not `.join()`.
   - `chat_id` ← parameterised
     `SELECT telegram_user_id FROM public.bot_state WHERE owner_id = $1 LIMIT 1`
     using the resolved owner.

   If the events lookup returns no `owner_id`, **THROW** rather than skip
   the write. An error handler that silently drops errors is worse than
   no error handler.

   **Primary protection — row-returned gate (authoritative).** Immediately
   after `INSERT audit_log`, IF `id` is present. Non-empty continues to
   the job-id test. Empty — including Postgres `{success:true}` on zero
   rows, a missing `id`, or a zero-item output — does **not** proceed and
   does **not** fail quietly: `stopAndError` throws so the execution is
   visible as failed. `INSERT audit_log` has `alwaysOutputData: true` so
   a zero-item result still reaches the gate. Without this gate,
   `Number(undefined) >= 2` is false and the run exits through `No alert`
   — silence, the outcome WF-00 exists to prevent. This gate does **not**
   depend on the query planner.

   **Secondary — SQL CAST (defence in depth only).** A runtime `CAST` of
   `events lookup returned no owner_id; refusing to drop the error write`
   to `uuid` remains in the statement. It is **not** the primary guard. A
   constant `CAST('…' AS uuid)` is folded at **plan time** (verified 26
   Aug 2026: unused `CASE ELSE` still threw while `$1` was `'LEAP 2026'`).
   The volatile subquery (`WHERE clock_timestamp() IS NOT NULL`) and
   `FROM guard CROSS JOIN hits` reduce that, but a planner or version
   change can disable it silently. The row-returned gate above is what
   must hold.

   If `bot_state` returns no row, `chat_id` is empty and repeated failures
   take the undeliverable path. Migration `012` seeds the owner `bot_state`
   row (the same row WF-01 uses as the allowlist), so alerts should deliver
   once it is applied. The undeliverable INSERT remains if that row is
   missing: visible, not silent.

   Implement the two lookups **and** the undeliverable INSERT in the
   **same** parameterised `executeQuery` as the `workflow_error` INSERT
   (node name `INSERT audit_log`). A *new* Postgres node is auto-assigned
   ElderWise — verified 26 Aug 2026: `relation "public.events" does
   not exist`. Restore-by-name on the existing Leap-NI node is the
   only bind that survives an MCP update. Do not add a separate
   lookup node. The undeliverable row is written in that same statement
   when `hit_count >= 2` and `chat_id` is empty; the undeliverable
   branch remains an explicit NoOp terminal.

4. **Send-node gate.** `Chat id present?` sits immediately before
   `Telegram owner alert`. Combined with step 3's row-returned gate, an
   empty write cannot reach Telegram or `No alert`.

5. Alert the owner via Telegram only on **repeated** failure of the same
   `workflow_name` + `node_name` within 15 minutes. The repeat count is a
   parameterised `SELECT count(*)` on `audit_log` for those keys in the
   window, **after** the current row is inserted. Count 1 = transient, no
   alert. Count ≥ 2 = alert. Do **not** use n8n static data — it is not
   shared across queue workers, is unreliable in manual runs, and is lost
   on reset.

   If the counter says an alert is owed but `chat_id` is empty, INSERT a
   second `audit_log` row with
   `action = workflow_error_alert_undeliverable` before terminating. Do
   not route that case to a silent NoOp. The 10 PM digest must be able to
   see that an alert was owed and not delivered.

6. Retain enough correlation context to replay the job safely.

**Must not:** place secrets, signed URLs, media, or personal data in a
notification.

**`errorWorkflow` on WF-00 itself:** none. Pointing WF-00 at itself would
recurse if the handler fails. Other LNI workflows point at WF-00's ID.
Never ElderWise's.

---

## WF-00b — Credential and connectivity probe

**Phase 0** · **Trigger:** Manual only · **Never activated**

READ-ONLY. No `INSERT`, `UPDATE`, `DELETE`, or DDL on any branch.
`errorWorkflow` set to LNI WF-00. `availableInMCP` true.

Retained after Phase 0, deactivated. It is the standing re-check after any
credential change.

### Postgres branch
Self-identifies by returning the LEAP 2026 seed row (`name`, `timezone`) from
`public.events` — a row that exists **only** in the LNI project. A credential
misbound to ElderWise fails loudly with `relation does not exist` instead of
returning success.

**Do not** self-identify via `current_user`. Under transaction-mode pooling it
returns plain `postgres`, not the tenant-qualified name (`architecture.md` §9).
Asserting on it produces a false negative.

### Storage branch
- The HTTP Request node **must** enable full-response mode so response
  **headers** are returned, not the body alone. The default discards them.
  Verified 26 Aug 2026 against the ElderWise credential-check workflow, whose
  HTTP node has `options: {}` and therefore cannot see `sb-project-ref`.
  Copying that template verbatim produces a probe that returns `200` and proves
  nothing.
- Bind `nodeCredentialType` `httpHeaderAuth` with the LNI Storage credential.
  The ElderWise template uses `supabaseApi` and is **not** a drop-in copy.
- Surface the `sb-project-ref` value in the workflow output where a human can
  read it. A green execution is not the deliverable; the project identifier is.

---

## WF-01 — Telegram ingest router

**Phase 1** · **Trigger:** Telegram Trigger (`updates`: `message`,
`edited_message`, `callback_query`)

The entry point. Its single most important property: **the raw asset reaches
storage before anything else happens.** The **order below is the invariant.**
A capture that never happened cannot be recovered.

**Inbound chat replies: WF-01 is the only sender.** WF-02 never sends.
On-demand `/digest` and `/ask` return `reply_text`; WF-01 sends.
If storage failed, WF-01 sends nothing — that inbound invariant lives in
one place.

**Scheduled operational messages (packet 3.1):** WF-07 (10 PM / 7 AM) and
WF-09 (watchdog) send Telegram themselves. A cron tick has no parent
WF-01 execution. `chat_id` is resolved from `bot_state` the same way
WF-00 does. Gate on non-empty `chat_id` before any send. Email copy is
scheduled-only.

Do not activate until the real-device checklist in packet 1.3 Step 3. This
is the first Telegram webhook on this instance: it must register against the
LNI bot only and must not disturb any ElderWise webhook.

### Exact sequence

1. **Telegram Trigger.** Updates: `message`, `edited_message`, `callback_query`.
   Treat `edited_message` as `message`. Do not restrict the trigger by
   hardcoded chat/user IDs (allowlist is Postgres). `settings.binaryMode` =
   `"separate"`.
2. **Allowlist.** Parameterised
   `SELECT owner_id, telegram_user_id, mode FROM public.bot_state WHERE telegram_user_id = $1::bigint`.
   `$1` is the sender id from the update. **No row → silent NoOp terminal.**
   No reply, no row written anywhere, **no log entry naming the user.**
   The allowlist **is** `bot_state`; there is no separate table and no `$env`.
3. **Mint `correlation_id`** once per update via the n8n **Crypto** node
   (`action=generate`, `encodingType=uuid`). Carry it on every WF-02 call.
   Do not use `$execution.id` (numeric string; belongs in `after`, not
   `audit_log.correlation_id`). Do not call `crypto.randomUUID()` in a
   Code node: this instance's task-runner sandbox has no `crypto` global
   and `require('crypto')` is disallowed (verified 26 Aug 2026).
4. **Self-identify LEAP-NI** (`SELECT name, timezone FROM public.events WHERE name = 'LEAP 2026'`)
   before any write. No matching row → **stopAndError** (`Wrong database terminal`).
5. **Branch:** command | photo | voice/audio | document/video | text | callback | **contact** | **vcard** | **flag**.
   Commands are `text` starting with `/` and win over the text branch.
   `/flag` is a named Route type output **appended** after `vcard`.
   Do not renumber existing outputs. Unknown commands still fall through
   to `Unknown type terminal` (silent NoOp).

   **Telegram `contact` (packet 3.9) — reply only, no ingest.**
   Live `Classify update` previously had no `msg.contact` branch;
   those updates died at `Unknown type terminal` with no reply.
   Now: detect `msg.contact`, set `branch = 'contact'`, read nothing
   else from the payload. Do **not** store, do **not** create an
   asset, do **not** call WF-02. Route to a WF-01 Telegram send
   (the only inbound sender) with exact text:
   `Contact cards are not supported yet. Send a photo of the card or
   a voice note instead.`
   Explicit notEmpty gate before the send. Full contact ingestion is
   **deferred post-event**: it needs a new `people.source_type`,
   touches two **ACTIVE** workflows (WF-01 and WF-02), and the event
   is four days away.

   **Telegram `.vcf` / vCard document (packet 3.13) — reply only, no
   ingest. Do not change WF-02.**
   WF-02 enqueue is still
   `CASE WHEN a.kind = 'audio' THEN 'transcription' ELSE 'card_vision' END`
   with no mime filter. A stored `.vcf` would get a vision call on a
   text file, fail three times, and leave the capture at `processing`.
   Decline at WF-01 instead, same pattern as contact: detect **before**
   `branch = 'document'`. Match `mime_type` `text/vcard` or
   `text/x-vcard`, **or** `file_name` ending `.vcf` (case-insensitive).
   Set `branch = 'vcard'`. Read nothing else from the file. No asset,
   no capture, no WF-02 call. Route to a WF-01 Telegram send with
   exact text:
   `Contact files are not supported. Send a photo of the card or a
   voice note instead.`
   Explicit notEmpty gate before the send. PDFs, videos, and other
   documents keep the existing document branch.
   **Proved packet 3.14, exec 256753** (not 256611 / 256687). Route
   type named rule `vcard`, last node `Vcard reply sent`. Incoming
   `mime_type` `text/vcard`, `file_name` `.vcf`. Reply verbatim:
   `Contact files are not supported. Send a photo of the card or a
   voice note instead.` Captures/assets/jobs stayed 55 / 59 / 61.
   No asset row. No `card_vision` job. Execs 256611 and 256687 were
   `branch=contact` (shared Telegram contact) and do not count.
   Unchanged row counts do not discriminate: contact and vcard both
   store nothing.

6. **COMMANDS.** Strip a trailing `@botname`. First token, lowercased,
   without the leading `/`, is `action`. **Commands never touch Storage.**
   Publish-order: activate the callee before adding the Call on WF-01.

   | `action` | Callee | Payload |
   |---|---|---|
   | `new` `done` `batch` `status` (`start` → `status`) | WF-02 | existing contract (`owner_id`, `telegram_user_id`, `action`, `correlation_id`) |
   | `digest` | WF-07 | `owner_id`, `correlation_id`, `source='call'` |
   | `ask` | WF-08 | `owner_id`, `correlation_id`, `question` = remainder of the text after `/ask` |
   | `flag` | **none — WF-01 owns the branch** | See **/flag** below. Enqueue only. Do not call WF-06. Do not call Apollo. |
   | `fix` | none | post-event; silent NoOp, no reply |

   **`waitForSubWorkflow: true` on `/ask` and `/digest` (packet 3.10).**
   These are request/response for text the owner is waiting on, not a
   durable enqueue. Explicit in the saved JSON. WF-08 / WF-07 return
   `{ ok, reply_text }`; WF-01 sends. Gate: `ok` true AND `reply_text`
   notEmpty. Empty `reply_text` is a defect in the callee, not a
   silent WF-01 success.

   **`Ask out of scope terminal` is now dead code (packet 3.11).**
   `is_ask` is hard-coded `false` in `Classify update`. The live `/ask`
   path is `branch = 'ask'` → Call WF-08. Harmless Phase 1 scaffolding.
   Leave it.

   **`/flag <text>` (packet 4.9).** Named route `flag`, appended. WF-01
   resolves and **enqueues**. It does not dispatch WF-06 and does not
   call Apollo. The enqueue is the durable act. WF-06 drains on `*/15`.
   A slow Apollo call must not cost the owner his Telegram reply.

   1. **Parse argument.** Empty → reply `Usage: /flag <name or email>`.
      No lookup.
   2. **Lookup** (Postgres, `alwaysOutputData: true`, at most 5 rows).
      Stop at the first step that yields a match: exact
      `email_normalized`; exact `full_name` case-insensitive; trigram
      similarity on `full_name`, threshold 0.4.
   3. **Row-count gate.** Zero rows from `alwaysOutputData` is an empty
      item, not a zero-count report. Gate before every send.
   4. Outcomes, all reply-only except the single-match insert:
      - 0 matches → `No person matches <text>.` Nothing enqueued.
      - 2+ matches → list name + email for each, max 5. A person
        with no email renders as `<name> (no email)` — never a bare
        `null`, never a dangling separator. Nothing enqueued. The
        owner re-issues `/flag` with an email. NEVER guess.
      - 1 match with no linked interaction → reply
        `<name> has no linked capture and cannot be flagged.`
        Nothing enqueued. Do not throw.
      - 1 match with a linked capture → `INSERT INTO processing_jobs`
        `capture_id` = the person's **most recent** interaction
        `capture_id` (subquery in the same INSERT),
        `job_type='enrichment'`, `status='queued'`,
        `output = jsonb_build_object('person_id', <id>, 'force', true)`
        `ON CONFLICT` inferring `processing_jobs_enrichment_person_uniq`
        `DO NOTHING RETURNING id`. Zero-row insert →
        `Already queued for enrichment.` One row →
        `Queued <name> for enrichment. Result within 15 minutes.`
        Gate the INSERT: if the subquery would be NULL, do not run
        it. `processing_jobs.capture_id` is NOT NULL by design.
   5. Reply text escaped for the parse_mode WF-01 already uses.
      Absent `parse_mode` is not plain text on this build (default
      Markdown; `_` in an email will break an unescaped send).

   **`/flag` capture_id (packet 4.12).** A `/flag` enrichment job
   anchors to the `capture_id` of the person's MOST RECENT
   interaction. `processing_jobs.capture_id` is NOT NULL by design:
   every job traces to a capture. The 4.9 spec said `capture_id`
   NULL and was wrong — proven by execs 265725 and 265729, NOT NULL
   violation, no reply, no enqueue. A person with NO interaction
   cannot be flagged. Reply plainly rather than throwing.

   `force=true` bypasses the 30-day cache **only**. It **never**
   bypasses the daily or lifetime credit ceiling. WF-06 node order
   (live): Load ceilings → Ceiling ok? → Cache check → Cached? →
   (skip) Write cache skip / (continue) Read credits before. The
   cache SQL returns `skip_cached=0` when `output.force` is true.
   Ceiling sits before cache, so force cannot reach a provider past
   the ceiling.

   **Packet 4.9 publish (28 Aug 2026).** WF-01 PUT without `active`,
   `binaryMode` stripped. Re-GET: `active` true, `versionId` =
   `activeVersionId` = `01bbecf1-6c4a-4db7-96e5-337629a53dce`.
   Route type named outputs unchanged then **appended** `flag`.
   Fallback still `unknown` → `Unknown type terminal`. Postgres
   Leap-NI on Flag lookup / Flag enqueue. `errorWorkflow` =
   `X7zKL3wTFPIhwyaN`. WF-06 cache SQL already honours `force`;
   no WF-06 edit.

   **Packet 4.10 measured (28 Aug 2026).** Route type `connection[10]`
   / `[11]` swapped. Re-GET `versionId` = `activeVersionId` =
   `1e23405f-4010-4e9b-a1a4-c3df1e1ce904`. Outputs 0–9 unchanged.
   `flag` → Flag arg empty?. Fallback → Unknown type terminal.
   Void 4.9 execs 265428–265446.

   Re-prove (webhook, after the swap):
   1. **265540** last **Flag sent terminal**. Reply
      `Usage: /flag <name or email>`. Pass.
   2. **265544** last **Flag sent terminal**. Reply
      `No person matches zzzznotaperson.` Pass.
   3. **265548** error at **Flag many?**.
      `Wrong type: '2' is a string but was expecting a number`.
      Lookup returned two probe rows (`hit_count` as text `2`).
      `LNI LI Guard Probe` `email_normalized` null;
      `LNI No-Match Probe` has an email. Flag list reply never
      ran. `reply_text` never set. Fail.
   4. **265551** error at **Flag many?**. `'1'` is a string.
      No enqueue. Fail.
   5. **265553** same as 4. Fail.
   New enrichment jobs: none. WF-06 **265527** (05:15Z, before
   the five messages) last **Empty queue**. Apollo 2599,
   ledger 6, records 12 — no force cycle. The 05:15 drain is
   not evidence for `/flag` force.

   **Packet 4.11 publish (28 Aug 2026).** Cause: Flag many? compared
   Postgres COUNT (string) to a number operator under strict
   validation. Fix is at the SQL boundary only.
   WF-01 PUT without `active`, `binaryMode` stripped. Re-GET:
   `active` true, `versionId` = `activeVersionId` =
   `3f4e8fb2-55ab-447c-abce-d4dc2d420f94`. Flag lookup projection
   `count(*) OVER() ::int AS hit_count`. Flag many? unchanged:
   number / gt / 1 / `typeValidation` strict. Route type `[10]`
   Flag arg empty?, `[11]` Unknown type terminal.
   WF-00 PUT without `active`; `binaryMode` and `timeSavedMode`
   stripped (`timeSavedMode` is an additional property the public
   PUT rejects). Re-GET: `active` true, `versionId` =
   `activeVersionId` = `5ec180fd-3270-433d-9e03-d0f2ff9ecd44`.
   Telegram owner alert text: 4 real newlines, 0 literal `\n`.
   Logic otherwise unchanged.

   **Packet 4.11 measured (28 Aug 2026, after the cast).** Messages
   1–2 stay 265540 / 265544. Re-prove 3–5 only, webhook, 05:39Z:
   3. **265724** success last **Flag sent terminal**. `hit_count`
      arrived as integer `2`. Reply (verbatim, including the
      trailing space after the first name):
      `LNI LI Guard Probe \nLNI No-Match Probe lni-nomatch-probe@lni-probe-8f3a2c.example`
      `LNI LI Guard Probe` email is NULL. Render is name + space +
      empty — dangling separator, not a bare `null`. Defect on
      render. Type-cast itself: pass.
   4. **265725** error last **Flag enqueue**. `hit_count` integer
      `1`. `null value in column "capture_id" of relation
      "processing_jobs" violates not-null constraint`. No reply.
      Fail. Live column `processing_jobs.capture_id` is NOT NULL
      (architecture.md § processing_jobs). Spec INSERT uses NULL.
   5. **265729** same as 4. Fail.
   New enrichment jobs: none. queued 0. Apollo 2599, ledger 6,
   records 12 — still no force cycle. Do not treat 05:30 **265649**
   or the 05:45 Empty-queue drain as force evidence.

   **Packet 4.11 Part F (28 Aug 2026).** WF-06 **265777**
   `mode=trigger` 05:45:00Z last **Empty queue**. Cached? did not
   run (no job claimed). No new ledger row. Apollo 2599→2599.
   ledger 6→6. records 12→12. queued 0. Architect 2599→2598 /
   6→7 / 12→14: **not met** — enqueue never landed (capture_id
   NOT NULL). Not skipped_cached; force was never tested.

   **Packet 4.12 publish (28 Aug 2026).** Spec correction: `/flag`
   jobs anchor `capture_id` to the person's most recent interaction.
   Column stays NOT NULL. WF-01 PUT without `active`, `binaryMode`
   stripped. Re-GET: `active` true, `versionId` = `activeVersionId`
   = `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a`. Flag enqueue INSERT
   subquery `ORDER BY i.created_at DESC LIMIT 1`. Gate: Flag
   capture lookup → Flag has capture? → enqueue / no-capture reply.
   Null email renders `(no email)`. Flag lookup still
   `count(*) OVER() ::int AS hit_count`. Flag many? still number /
   gt / 1 / strict. Route type `[10]` Flag arg empty?, `[11]`
   Unknown type terminal.

   **Packet 4.12 measured Part E (28 Aug 2026, 05:55Z).** Messages
   1–2 stay 265540 / 265544. Re-prove 3–5 only, webhook, none
   `status=error`:
   3. **265855** success last **Flag sent terminal**. Reply
      `LNI LI Guard Probe (no email)\nLNI No-Match Probe lni-nomatch-probe@lni-probe-8f3a2c.example`
      Pass.
   4. **265857** success last **Flag sent terminal**. Reply
      `Queued Ahmad Mohamed Fouad for enrichment. Result within 15 minutes.`
      ONE `processing_jobs` row `70f3d9ef-4a46-4a1d-affd-999a02d289a9`
      `capture_id=edc7526c-d3d5-48b6-bb7d-7230b92f1f90` (most recent
      interaction of person `68880196-f5d2-4f5a-a8a4-0c0d9788cdde`),
      `output.person_id` that id, `force=true`. Pass.
   5. **265858** success last **Flag sent terminal**. Reply
      `Already queued for enrichment.` No second row. Pass.

   **Packet 4.12 Part F (28 Aug 2026).** WF-06 **265894**
   `mode=trigger` 06:00:00Z last **Match done**. Cache check
   `skip_cached=0`. Cached? false branch (continue, not skip).
   Force bypassed the 30-day cache and spent. Ledger
   `a42a37be-b596-4e89-b40b-5c046fd8bdb0` apollo /
   `people_match` / `confirmed` / `credits_spent=1`. Apollo
   2599→2598. ledger sum 6→7. enrichment_records 12→14
   (person `9bbaf6ce` + company `110fa72e`). queued after: 0.
   Job `70f3d9ef` `succeeded`. Architect baseline: met.

   Send `reply_text` (and `state_echo` only when `reply_text` is empty and
   `state_echo` is not). Gate: do not send if the callee `ok` is false or
   `reply_text` / `state_echo` is empty. Do not re-test a second field.
7. **MEDIA**, in exactly this order — this ordering **is** the invariant:
   a. Extract `file_unique_id` (photo: largest size in the array). `SELECT id FROM public.assets WHERE telegram_file_unique_id = $1`. If a row exists, **silent duplicate terminal**. Telegram redelivery is normal.
   b. Call WF-02 `action=resolve_target` to obtain `capture_id`. Orphan adoption may open a capture here — **do not send its message yet.** Hold `reply_text` only. Do not re-test `adopted` or `mode`.
   c. Mint `asset_id` via the n8n Crypto node (`generate` / `uuid`) — same
      sandbox restriction as `correlation_id`.
   d. Telegram `getFile`, then download the binary. Saved parameters must
      include `download: true` (and `operation: get`) — do not rely on the
      node default. Verified 26 Aug 2026: the draft JSON had no `download`
      flag while runtime still fetched bytes; that is not verified behaviour.
   e. Compute `sha256` (Crypto node) over those same bytes. `Prep upload`
      takes **binary from `$('Telegram getFile').item.binary`** and
      `json.sha256` from the Hash node — never from `$input` after Hash
      (Crypto emits json-only). Prep **does not measure length**. Do not
      put `bin.bytes`, Telegram `file_size`, or a Code-decoded buffer
      length into `size_bytes` (Code cannot open filesystem-v2; metadata
      is the disease). There is **no** pre-PUT byte gate — it only fired
      on pinned fixtures.
   f. Upload to Supabase Storage: raw HTTP PUT, `httpHeaderAuth`, header `x-upsert: true`, path `{owner_id}/{capture_id}/{asset_id}-{file_unique_id}.{ext}` where `{ext}` derives from media type / mime (`jpg`, `oga`, `mp4`, `pdf`, `bin` fallback). Bucket `lni-assets`. The PUT body is the getFile bytes, still named `data`.
   f2. **After PUT 200/201 and before the assets INSERT:** HEAD the object.
      HEAD `Content-Length` **is** `assets.size_bytes` — the only number
      measured from the artifact that survives. Require: HEAD 200/201/204,
      `Content-Length > 0`, **and** `Content-Length` equals Telegram
      `getFile` `file_size` (second opinion, not the stored value).
      Missing object, zero length, failed HEAD, or disagreement with
      Telegram → `stopAndError` (`Storage mismatch terminal`). Do **not**
      write the assets row. PUT `{Key, Id}` is not a size. Verified
      26 Aug 2026: this Supabase build returns `Content-Length` on HEAD.
   g. **ONLY IF** the HEAD measurement passes: `INSERT` the `assets` row with the **same** `asset_id` minted in (c), `size_bytes` = HEAD `Content-Length`, `upload_status = 'stored'`, `ON CONFLICT (telegram_file_unique_id) DO NOTHING`.
   h. **ONLY NOW** send if `reply_text` is a non-empty string. Nothing else.
      WF-02 already returned empty `reply_text` for batch and for
      non-adopted resolves. An `adopted` or `mode != batch` test here
      duplicates a decision already encoded in that string (defect 10,
      exec 245471).
   i. If (f) fails: send **NOTHING**. Silence must mean failure. Do not send the adoption message either — telling the owner a capture opened when nothing was stored is the false reassurance `prd.md` §5 forbids.
8. **TEXT:** commands already won in step 5 (text starting with `/`).
   Remaining text is a typed note: `resolve_target`, then append to
   `captures.typed_note` on that capture. **ONLY AFTER** the note write
   succeeds: send if `reply_text` is a non-empty string. Same rule as media.
   Do not re-test `adopted` through a different operator than the photo path.
9. **CALLBACK:** album split prompt is answered on this existing
   `callback_query` branch (today a silent NoOp — `Callback terminal`).
   Design in **Album auto-detect** below. Packet 2.1 does not implement it.
10. **Every path ends in an explicit terminal.** Failure terminals are
    `stopAndError` (WF-00 runs). Correct outcomes are silent NoOps.

Contract payloads for WF-02 (`Command payload`, `Resolve payload`,
`Text resolve payload`) are built from **named-node** references
(`$('Attach correlation').item.json.*`), never `$json`. A Postgres node
with `alwaysOutputData` sits on the media path (`Duplicate check`) and
emits `{}` on zero rows.

**Named-node audit (packet 1.3c, both workflows).** Every remaining
expression that reads `$json`, `$input`, or the previous item's `binary`
rather than a named node. Listed even where currently safe.

| Location | What it reads | Verdict |
|---|---|---|
| WF-01 `Prep upload` | `$('Telegram getFile').item.binary` + `$('Hash sha256').item.json.sha256` | **Fixed** — copies only; does not measure length |
| WF-01 `Telegram getFile` | `download: true` + `operation: get` explicit; `fileId` from `$('Mint asset')` | **Fixed** |
| WF-01 `Object size matches?` | HEAD `Content-Length` vs `$('Telegram getFile').item.json.result.file_size` | **1.3e** — HEAD is the stored size; Telegram is the agree-check |
| WF-01 `Insert asset` `size_bytes` | `$('HEAD object')` `Content-Length` | **1.3e** — not Prep, not metadata |
| WF-01 `Upload to Storage` URL / content-type | `$('Prep upload')` | Named. PUT *body* is the incoming item field `data` (HTTP node has no named-binary expression). That item is Prep's copy of getFile binary. Safe today; inserting Crypto/Code/HTTP between Prep and PUT would drop it again. |
| WF-01 `Hash sha256` | incoming `binary.data` from getFile | Intended — this node consumes those bytes. It emits json-only; callers must not use its binary. |
| WF-01 `Mint asset` | `$input.first().json` for the uuid | Currently safe — `Mint asset uuid` (Crypto) sits immediately upstream. Named `$('Mint asset uuid')` would match the rule. |
| WF-01 `Attach correlation` | `$input.first().json.data` for the uuid | Same as Mint asset, with `Mint correlation`. |
| WF-01 `Allowlist` `$json.message?.from?.id` | Telegram Trigger item | Safe — first I/O |
| WF-01 `Allowlisted?` `$json.owner_id`, `Reached LEAP-NI?` `$json.name` | the Postgres node it sits on | Safe |
| WF-01 `Route type` `$json.branch` | `Attach correlation` item | Safe |
| WF-01 `Already stored?` / `Asset row returned?` / `Note row returned?` `$json.id` | that Postgres output | Safe — empty `{}` means miss |
| WF-01 `Media/Text capture present?` `$json.capture_id` | Execute Workflow result | Safe |
| WF-01 `Upload succeeded?` `$json.statusCode` | the HTTP response | Safe |
| WF-01 `Send adoption?` | `$('Call WF-02 resolve media').item.json.reply_text` notEmpty only | **1.3f** — no `adopted`, no `mode` |
| WF-01 `Send note adoption?` | `$('Call WF-02 resolve text').item.json.reply_text` notEmpty only | **1.3f** — same rule, same operator as photo |
| WF-01 `Command has reply?` / `Send command reply` | Call WF-02 item | Safe |
| WF-01 `Text is ask?` `$json.is_ask` | `Attach correlation` | Safe |
| WF-01 `Duplicate check` / `Insert asset` `queryReplacement` | already named | Safe |
| WF-01 `Append typed note` `$json.capture_id` | Call WF-02; note/owner already named | Safe |
| WF-02 Action SQL `queryReplacement` | `$('Validate payload')` | Safe |
| WF-02 compose / row-returned gates `$json` | the Action Postgres row just produced | Safe |

### Terminals — silence to the owner, alarm to the operator

The owner still gets **no Telegram receipt** on storage failure
(`prd.md` §5). That is not the same as a successful n8n execution.
WF-00 is the operator alarm.

**`stopAndError` (error execution → WF-00).** Message includes
`correlation_id` and `file_unique_id` only. Never bot token, signed URL,
file bytes, or message text.

| Terminal | When |
|---|---|
| Resolve failed terminal | WF-02 did not return a `capture_id` after media was received |
| Upload failed terminal | Storage rejected the object |
| Storage mismatch terminal | PUT succeeded but HEAD missing/zero, or HEAD `Content-Length` ≠ Telegram `file_size` |
| Insert miss terminal | Upload succeeded, `assets` row did not |
| Text resolve failed terminal | `resolve_target` failed on the typed-note path |
| Note miss terminal | Typed-note UPDATE returned no row |
| Wrong database terminal | Self-identify did not return LEAP 2026 |

**Silent NoOp (correct, not a failure).**

| Terminal | When |
|---|---|
| Duplicate terminal | Telegram redelivery; `file_unique_id` already stored |
| Not allowlisted terminal | Unknown sender; no reply, no row, no log naming the user |
| Command no-send terminal | WF-02 returned no `reply_text` / `state_echo` |
| Adoption skipped terminal | Stored; `reply_text` empty (already-open or batch) |
| Callback terminal | Album callback not yet implemented (packet 2.1 design only). Today a silent NoOp. |
| Unknown type terminal | Update is none of command/photo/voice/document/text/callback/contact/vcard |
| Command sent / Media stored / Note done / Contact reply sent / Vcard reply sent | Happy path (contact and vcard send the unsupported text; nothing stored) |

### Kind mapping (live constraints, 26 Aug 2026)

`assets_kind_check` =
`business_card | audio | photo | selfie | document`.
`assets_upload_status_check` = `pending | stored | failed`.
Phase 1 never classifies content (`architecture.md` §4 two-stage kind):

| Telegram update | `assets.kind` |
|---|---|
| photo (largest size in the array) | `photo` |
| voice, audio | `audio` |
| document, video, video_note | `document` |

### Album auto-detect — Postgres buffer (design only; Phase 2)

Telegram delivers each album member as a **separate update**. Twenty members
are twenty WF-01 executions with **no shared n8n memory**. The buffer is a
`captures` row keyed on `flags->>'media_group_id'` (object shape after
migration `015`). Implementation is Phase 2 (promoted from packet 1.4,
owner decision 27 Aug 2026). This packet documents the design only.

1. **First INSERT wins.** Attempt `INSERT` of a capture with
   `flags = jsonb_build_object('media_group_id', <id>)`. Partial unique
   index `captures_owner_media_group_uniq` (`013`) makes the first writer
   succeed.
2. **Losers catch `unique_violation` and re-SELECT** the winning row by
   `(owner_id, flags->>'media_group_id')`. Do not retry INSERT in a loop.
3. **Store the asset first** (existing WF-01 mint → PUT → HEAD → INSERT
   `assets`). Every member is durable before any prompt is considered.
4. **Count** assets on that `media_group_id` (join `assets` to the capture
   found in 1–2). If the count is **> 2**, run **one** parameterised
   `UPDATE` that sets `album_prompt_sent` **guarded by**
   `NOT (flags ? 'album_prompt_sent')` and `RETURNING` a row. First
   execution that sees > 2 wins the prompt; later members get zero rows.
5. **Explicit gate on the returned row** before the inline keyboard is
   sent (*"N images — separate people, or one person?"*). A zero-row
   UPDATE must not send.
6. **Callback is answered on the existing `callback_query` branch**, which
   is a silent NoOp today (`Callback terminal`). Packet 2.1 does not wire
   it.

**Assets are already stored before any prompt**, so an unanswered callback
can never drop a file. The only missing behaviour until this ships is the
grouping question; members still land as ordinary photos on the resolved
capture.

### Must not log

Never log: the bot token, signed URLs, file bytes, the sender's numeric id,
or message text. Request ids and redacted errors only.

**Critical:** if step 7f fails, **no receipt is sent**. Silence must mean
failure. The owner is never falsely reassured.

---


## WF-02 — Capture lifecycle

**Phase 1** · **Triggers:** Execute Sub-workflow (called by WF-01) **and**
Schedule (inactivity sweep). A sub-workflow cannot hold a schedule, so both
live on WF-02.

**Packet 1.3 activates WF-01.** This n8n instance refuses to publish a parent
that calls an unpublished sub-workflow (`Call WF-02 *` → `BV0nukrQdOpDCPe4`).
WF-02 must be published first so WF-01 can go live. The Schedule Trigger then
fires every 5 minutes (`minutesInterval: 5`, `Asia/Riyadh`) — correct once
ingest exists. Do not activate anything else.

Owns `bot_state` and `captures`. Implements the command surface in `prd.md` §4.
**WF-02 never sends a Telegram message.** Every send happens in WF-01, so the
rule "if storage fails, no receipt is sent" is enforced in one place. A
second send point is how that invariant rots.

### Call contract (WF-01 → WF-02)

Execute Sub-workflow Trigger. Accepts **exactly** this shape; any other is
rejected with `ok=false`, `error_code=malformed_payload`, and **no row
written anywhere**:

```json
{
  "owner_id":         "uuid",
  "telegram_user_id": 0,
  "action":           "new | done | batch | status | resolve_target | sweep",
  "asset_count_hint": 0,
  "correlation_id":   "uuid"
}
```

`owner_id`, `telegram_user_id`, `action`, and `correlation_id` are required
on the WF-01 path. `correlation_id` is a uuid, minted per inbound Telegram
update by WF-01. Reject with `error_code=malformed_payload` if it is not a
uuid. n8n `$execution.id` is a numeric string and belongs in `after`, not
in `audit_log.correlation_id`.

`asset_count_hint` is optional and **advisory only** — usable for logging,
never used for the receipt (`prd.md` §5: the receipt is the sole proof the
pipeline is alive; a receipt that can claim more items than Storage holds
is a false reassurance).

`action=sweep` is produced by the Schedule Trigger, not by WF-01, and does
not require `owner_id`. Reject `action=sweep` unless `$('Schedule sweep').isExecuted`
is true; return `error_code=sweep_not_externally_invokable`. A same-owner
passthrough must not be able to close every open capture. On the Execute
Sub-workflow path, `$('Schedule sweep').isExecuted` evaluates to `false`
and does not throw (verified packet 1.2b). Validate payload still wraps
the access in try/catch and treats a throw as not-executed, so a `$()`
miss cannot crash every WF-01 call.

### Return contract

```json
{
  "ok":            true,
  "capture_id":    "uuid | null",
  "capture_no":    0,
  "mode":          "normal | batch",
  "item_count":    0,
  "reply_text":    "WF-01 sends this; WF-02 never does",
  "state_echo":    "uses capture_no, never the uuid",
  "error_code":    "text | null"
}
```

There is **no** `adopted` field. Adoption is encoded in `reply_text`
(non-empty vs empty). Do not add a second field that must stay in
agreement with `reply_text`.

`capture_no` is a **number**. n8n Postgres emits bigint as a string;
Compose `Number()`s it (packet 1.3f).

The sweep branch produces no `reply_text` and sends nothing. The stamp is
the signal; it is visible in review.

### `/new`
1. If an open capture exists, close it (`status` leaves `open`,
   `close_reason = superseded`).
2. Insert a new `captures` row, `status = open`, `event_id` = LEAP 2026.
   `capture_mode` / `card_only` follow current `bot_state.mode`.
3. Update `bot_state.open_capture_id` and `last_activity_at`. `RETURNING`
   `id`, `capture_no`.
4. `reply_text` uses `captures.capture_no`, never the uuid:
   `Capture #<n> open`.

### `/done`

Postgres is the queue. `/done` enqueues work, then fires WF-03 **once**.
**Enqueue-and-dispatch is implemented in this packet (2.4).** Replaying
already-captured assets is **one INSERT**, not N workflow calls.

WF-03's live workflow ID lives on the instance only. In this document it
is **`<WF-03_WORKFLOW_ID>`**. Never commit the literal.

1. Close. `Action done` sets `status` to leave `open`,
   `close_reason = explicit`, and **RETURNs every capture it closed**
   (ids as `closed_ids uuid[]`, plus the first `capture_id` /
   `capture_no` for the standard receipt). Batch `/done` closes every
   open `capture_mode='batch'` row for the owner (many ids). Standard
   `/done` returns one. If nothing is
   open, zero rows → `reply_text` = `nothing open`. No crash, no phantom
   row. Batch also sets `bot_state.mode = normal`.
2. Enqueue — **one** statement, after Compose has already decided
   `reply_text` (WF-01 return contract must not become the enqueue
   row). `closed_ids` comes from the **named** `Action done` node,
   never `$json` after Compose.

   ```sql
   INSERT INTO processing_jobs (owner_id, capture_id, asset_id, job_type, status)
   SELECT a.owner_id, a.capture_id, a.id,
          CASE WHEN a.kind = 'audio' THEN 'transcription'
               ELSE 'card_vision' END,
          'queued'
   FROM assets a
   WHERE a.capture_id = ANY($1::uuid[])
     AND a.upload_status = 'stored'
   ON CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL
     DO NOTHING
   RETURNING id, capture_id, asset_id, job_type, status;
   ```

   Natural key: unique index **`processing_jobs_asset_job_uniq`** on
   `(asset_id, job_type) WHERE asset_id IS NOT NULL`
   (`architecture.md` §4). That object is a **partial unique index**,
   not a table constraint — do not write
   `ON CONFLICT ON CONSTRAINT processing_jobs_asset_job_uniq`.
   Audio → `transcription`; everything else → `card_vision`. A re-run
   enqueues nothing twice.
3. **Explicit gate on rows returned.** Zero rows enqueued (all conflicts,
   or a capture with no stored assets) is a **normal, silent, terminal**
   path — not an error, and not a send. `reply_text` from Compose is
   restored from the named Compose node so WF-01 still receives the
   receipt.
4. **ONE** `executeWorkflow` call to WF-03 (`<WF-03_WORKFLOW_ID>`),
   `waitForSubWorkflow: false`. Replaces the NoOp **"WF-03 dispatch
   (not yet)"**. Do not call WF-03 per asset. A re-run that enqueues
   nothing does not fire WF-03 again — the jobs are already in Postgres.

   **Dispatch is best-effort.** The `Call WF-03` node MUST set
   `onError: continueRegularOutput` **explicitly in the saved JSON**
   (not an undocumented default). A throw in that node must take the
   same regular output as success and continue to **Restore done reply**,
   so WF-01 still receives the Compose contract and still sends the
   receipt. Why: enqueue is the durable act — the jobs are already in
   Postgres and are replayable. Dispatch is not durable. WF-01 waits on
   WF-02 with `waitForSubWorkflow: true`; an erroring dispatch would
   cost the owner his receipt. Silence must mean a **storage** failure,
   never a dispatch failure. A missed dispatch leaves rows in
   `processing_jobs` at `status='queued'`, which is exactly what
   **WF-09** (watchdog, Phase 3) is specified to catch
   (`last_transition_at` staleness, not `created_at`).
5. Receipt. Standard: `✓ Capture #<capture_no> saved · <n> items` using
   `captures.capture_no` and the Postgres asset count (`asset_count_hint`
   never populates `<n>`). Batch: **`N cards received · processing`**.
   `N` is the number of batch captures closed. Extraction has not run at
   this instant, so clean / need_review / failed **cannot** be true here
   — do **not** emit hardcoded zeros for those. Real counts are deferred
   to the digest (`prd.md` §5).

   **Open defect (GATE-FIX, receipt):** `N` is `processed` (closed
   capture count), not the enqueue `RETURNING` count. Exec 270954:
   `processed=4`, `Enqueue asset jobs` n=3, capture #77 had no job.
   Lying receipt. Do not change Compose in this packet. WF-09
   orphan-asset reconciler enqueues the missing row on the next
   `*/15` tick.

The last node on every `/done` path that WF-01 waits on must emit the
Compose contract (`ok`, `reply_text`, …), sourced from the **named**
Compose node. Enqueue and executeWorkflow sit between Compose and that
terminal; they must not become the sub-workflow return. A failed
dispatch is not a failed `/done`.

### `/batch`
Sets `bot_state.mode = batch` and bumps `last_activity_at`. Every subsequent
photo creates its own capture with `capture_mode = batch`, marked `card_only`
(`prd.md` §4: "every subsequent photo becomes its own independent capture" —
that sentence remains true; the implementation is `resolve_target` below).
**Suppresses per-capture receipts** by returning empty `reply_text` from
`resolve_target`. WF-01 does not re-check `mode`. `/done` exits
batch by closing **all** open batch captures for the owner.

### `/status`
Reports the open capture (`capture_no`), its item count, and the current
mode. If nothing is open, `reply_text` = `nothing open`.

### `resolve_target`
**Never reject.** Media with no open capture must still land somewhere
(`prd.md` §4 guardrail 3).

- **`bot_state.mode = 'normal'`:** return the existing open capture (empty
  `reply_text`), or insert one (orphan adoption) and put the tell in
  `reply_text` / `state_echo`.
  Update `bot_state.open_capture_id` and `last_activity_at`.
- **`bot_state.mode = 'batch'`:** **always** insert a new capture
  (`capture_mode='batch'`, `card_only=true`, `status='open'`). Do **not**
  return an existing open capture. Do **not** set `bot_state.open_capture_id`
  (each photo is independent; `/done` finds them by `capture_mode='batch'`
  and `status='open'`). Still bump `last_activity_at`. Empty
  `reply_text` (WF-01 stays silent).

### Sweep (Schedule Trigger)
- Every 5 minutes. Timezone **explicitly `Asia/Riyadh`** (workflow setting;
  never inherit the container default). Schedule node JSON must include
  `minutesInterval: 5` — not an implicit default.
- Close every capture with `status='open'` whose **own**
  `captures.last_activity_at` is older than the inactivity window
  (`< now() - interval '10 minutes'`), stamping `close_reason='auto'`.
  **Do not** use `bot_state.last_activity_at`. That clock is global
  owner activity (`/status`, `/ask`, a new card for the next person)
  and never goes idle during a 1–9 PM event. Per-capture idle is the
  guardrail that actually fires. `status` leaves `open` so a later
  sweep does not re-close. Clear `bot_state.open_capture_id` **only
  when that id is a capture this tick closed**. Send nothing. No
  `reply_text`.
- **`Action sweep` RETURNs the closed capture ids** as `closed_ids uuid[]`
  (plus counts). Counts-only is a defect: the enqueue cannot see what
  closed.
- **Then enqueue**, using the **same** single `INSERT … SELECT` and the
  **same** `ON CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL
  DO NOTHING` as the `/done` path (`architecture.md` §4). Source
  `closed_ids` from the **named** `Action sweep` node, never `$json`
  after Compose. Audio → `transcription`; else → `card_vision`. Zero
  rows enqueued is a normal silent terminal — not an error, not a send.
- **Then dispatch WF-03 once**, best-effort: `waitForSubWorkflow: false`,
  `onError: continueRegularOutput` **explicit in the saved JSON**. Same
  reason as `/done`: enqueue is durable; dispatch is not; a throw must
  not fail the sweep execution. A missed dispatch leaves `queued` jobs
  for WF-09 (Phase 3).
- **Inactivity window: 10 minutes** (`prd.md` §4 guardrail 2). Stored as a
  documented constant in the sweep SQL (`interval '10 minutes'`), **not**
  in `$env` (denied instance-wide). Clock column:
  `captures.last_activity_at` (migration `026_captures_last_activity`).
- Live defect (packet 2.5): capture #59 sat `open` with a stored audio
  asset; the sweep closed other captures `close_reason='auto'` and never
  enqueued. Guardrail 2 exists because forgetting `/done` WILL happen.
- Live defect (GATE-R, 28 Aug 2026): capture #78 stayed `open` past 10
  minutes because `/status` kept bumping `bot_state.last_activity_at`.
  Predicate is now per-capture. `/status` must not keep a capture open.

### Guardrails
- **Implicit close on `/new`** — see above.
- **Inactivity auto-close** — sweep above.
- **Orphan adoption** — `resolve_target` above. **Never reject.**
- **State echo:** every non-sweep return includes current state, using
  `captures.capture_no`, never the uuid.

---

## WF-03 — Asset processors

**Phase 2** · **Triggers:** Manual (standalone / prove) **and** Execute
Workflow Trigger (called **once** per kick by WF-02 `/done` **and** by
the inactivity sweep, `waitForSubWorkflow: false`,
`onError: continueRegularOutput`). Workflow ID on the instance:
`<WF-03_WORKFLOW_ID>`. Never commit the literal.

**Input contract:** `owner_id` and `correlation_id`. WF-03 is **not**
handed an asset. It **claims queued jobs from Postgres itself**. Postgres
is the queue. Reject unknown extra fields if a payload is sent. A kick
with `owner_id` is enough; `correlation_id` is for trace only.

WF-03 assigns `assets.kind` from **one** vision call per image.
Capture-time kind is Telegram media type only — live image assets sit at
`kind='photo'`, so a `business_card` branch would never fire
(`architecture.md` §4).

Provisional card engine: **GPT-4o**, behind the adapter, **shipping
without a benchmark** (packet 2.5; `phases.md`; `rules.md` §7 rule 14
knowingly not honoured). The model id is set in **one** named config
node (`Card engine config`) and read from there. Do not scatter it.

1. **Self-identify** before any write: `SELECT name, timezone, owner_id
   FROM public.events WHERE name = 'LEAP 2026' LIMIT 1`. Explicit gate.
   Wrong database → `stopAndError`.
2. **Claim** queued jobs (not a payload of assets):

   ```sql
   UPDATE public.processing_jobs AS j
   SET status = 'running',
       attempt_count = j.attempt_count + 1,
       last_transition_at = now()
   WHERE j.id IN (
     SELECT p.id
     FROM public.processing_jobs p
     WHERE p.status = 'queued'
       AND p.owner_id = $1
       AND p.attempt_count < 3
       AND (p.attempt_count = 0
            OR p.last_transition_at < now() - (CASE p.attempt_count
                 WHEN 1 THEN interval '1 minute'
                 ELSE interval '5 minutes' END))
     ORDER BY p.created_at ASC
     LIMIT 10
     FOR UPDATE SKIP LOCKED
   )
   RETURNING j.*;
   ```

   Concurrent executions never claim the same job. **Explicit gate on
   rows returned** — zero claimed is a **normal, silent, terminal**
   NoOp (`No queued jobs`). Do not INSERT a second job for the same
   `(asset_id, job_type)`.
3. **Object fetch:** HTTP Request, `httpHeaderAuth`, `responseFormat:
   file`, named output property (e.g. `asset`). Never read bytes in a
   Code node. Source `storage_path` from the **named** Load-asset node,
   never `$json` after HTTP.
4. **Branch on `job_type`:** `card_vision` | `transcription`. Unhandled
   `job_type` → `status='failed'`, visible `stopAndError` after the
   write. Never drop.

   **`card_vision`** — **one** OpenAI vision call. `imageType: base64`
   from the named binary property (the proven **C3** path).
   `temperature: 0`. Strict `json_schema` exactly as proven in the spike,
   including the `image_type` discriminator
   `business_card | scene | other` (`architecture.md` §6). **No
   OCR-then-parse.** Then `UPDATE assets.kind` from `image_type`:
   `business_card` → `'business_card'`; `scene` → `'photo'`; `other` →
   `'photo'`. A `scene` (or `other`) image gets contextual
   `scene_description` only — **no facial recognition, no identification
   of people** (`rules.md` §7 rule 13).

   **Name contract in the vision system prompt** (packet 2.5 defect 2,
   packet 3.6 identity ruling):
   `full_name` is identity and must be non-null. If the card prints a
   Latin name, `full_name` uses it **exactly as printed** and is never
   re-transliterated. If the card is Arabic-only, **transliterate into
   `full_name`** and put the original in `name_original_script`. An
   Arabic-only stored `full_name` (transliteration failed) is still
   **accepted as identity** and does not force `needs_review`.
   `name_original_script` alone is still not identity (trap 7
   unchanged). Never discard the original. Never invent a Latin name
   the card does not support.
   A prove re-run INSERTs a **new** `card_vision` row; the original
   succeeded row is not updated (it is evidence).

   **QR / screen contact-share (packet 3.7b, measured packet 3.13).**
   A QR contact-share screen is captured exactly as well as the app
   prints it. GPT-4o cannot decode the pattern, so only readable text is
   recoverable - but that text often includes the email and phone.
   Two measured points, 27 Aug 2026:
     Capture 68 - screen showed the code and the app brand `wave` only.
     `image_type` `other`, zero people, `needs_review`, nothing recoverable.
     Capture 69 - screen printed name, title, company, email and phone.
     `image_type` `business_card`, full contact captured, status `ready`,
     `flag_reasons` empty.
   Operational rule: if the person's details are readable on the screen,
   photograph it. If only a code is visible, scan it and screenshot the
   contact page it opens, or record a voice note.
   Captures **#68** and **#69** stay as evidence and are **not
   retro-fixed**. Live prompt unchanged: `business_card` only when a
   proper name is printed; never decode the QR; never invent unprinted
   contact details.

   **`transcription`** — Whisper on the named binary property.
   **`language` ABSENT** from the saved JSON (not `"auto"`, not `"en"`).

   Signed URL (C2/C4) is a **proven fallback, not the default**. A signed
   URL is **never logged**.
5. Write **one adapter envelope** to `processing_jobs.output` (same
   shape for every `job_type` — `architecture.md` §6). Set `status` to
   `succeeded` | `failed` | `needs_review` and
   `last_transition_at = now()`. `result` is the unwrapped card JSON or
   `{text, duration_seconds}`. `raw` is the unmodified provider
   response. `error` is null or a redacted object. **Do not write
   `extraction_runs`.** WF-03 is per asset; `extraction_runs` is per
   capture. WF-04 must not know any provider's envelope.
6. **Retry:** transient errors leave the job `queued` (if
   `attempt_count < 3`) so a later execution retries. After 3 attempts
   → `failed`. Malformed content (schema missing, empty transcript) →
   `needs_review`. **Never silently drop.**

   **Backoff lives on the worker claim, not in this execution and not
   in WF-09.** A requeued job returns to `queued` with no Wait (300 s
   timeout). Do not add a Wait here. Every kick routes through claim
   (`/done`, sweep, watchdog, manual), so the claim is the only
   chokepoint all four paths share. WF-09-only backoff is bypassed by
   WF-02 dispatch. WF-09 remains the **kicker** for missed initial
   dispatch, stuck `running`, and post-event quiet. It is not the delay.

   Delays are **1 and 5 minutes**. The **20 minutes is deleted.** Claim
   bumps `attempt_count`, so a job is claimed at 1, 2, 3 and failed at
   3 — exactly two waits. A third delay is unreachable under a
   3-attempt ceiling. The ceiling stays 3 because a job that has failed
   twice at a four-day event is a poison job and belongs in the
   watchdog alert, not in a third retry. Recorded the same way
   `rules.md` §7 rule 14 was recorded, not quietly dropped.
7. When **every sibling job for that capture** is in a terminal state
   (`succeeded` | `failed` | `needs_review`), enqueue **ONE**
   capture-level job: `job_type='extraction'`, `asset_id` NULL,
   `status='queued'`. Insert once (guard on existing `extraction` row
   for that `capture_id`). Then **ONE** `executeWorkflow` call to WF-04
   (`<WF-04_WORKFLOW_ID>`), named **`Call WF-04`**, replacing the NoOp
   **"WF-04 dispatch (not yet)"**. `waitForSubWorkflow: false`.
   `onError: continueRegularOutput` **explicit in the saved JSON**.
   Dispatch is best-effort — enqueue is the durable act (same reasoning
   as WF-02 → WF-03). A throw must not fail WF-03. Zero rows enqueued
   (siblings still running, or extraction already exists) is a silent
   terminal, not an error, and does not fire WF-04.

Every path ends in a visible NoOp or `stopAndError`. Every flag the
workflow depends on is explicit in the saved JSON.

---

## WF-04 — Structured extraction

**Phase 2** · **Triggers:** Manual **and** Execute Workflow Trigger.
Claims capture-level `processing_jobs` rows (`job_type='extraction'`,
`asset_id` NULL) the same way WF-03 claims asset jobs. Enqueued by
WF-03 when every sibling asset job is terminal. Workflow ID on the
instance: `<WF-04_WORKFLOW_ID>`. Never commit the literal.

Settings: `availableInMCP: true`, `errorWorkflow` = LNI WF-00,
`executionTimeout: 300`, timezone **explicitly `Asia/Riyadh`**,
`callerPolicy: workflowsFromSameOwner`.

WF-04 composes `extraction_runs` from `processing_jobs.output.result` of
that capture's asset jobs. It does not unwrap a provider envelope. It
does not call the card/Whisper providers. GPT-4o is the extract engine
(same "ships without a benchmark" cut as WF-03).

**Input contract:** a kick with `owner_id` / `correlation_id` is enough
and optional — WF-04 **claims from Postgres itself**.

1. **Self-identify** before any write: `SELECT name, timezone, owner_id
   FROM public.events WHERE name = 'LEAP 2026' LIMIT 1`. Explicit gate.
   Wrong database → `stopAndError`.
2. **Claim** queued extraction jobs:

   ```sql
   UPDATE public.processing_jobs AS j
   SET status = 'running',
       attempt_count = j.attempt_count + 1,
       last_transition_at = now()
   WHERE j.id IN (
     SELECT p.id FROM public.processing_jobs p
     WHERE p.status = 'queued'
       AND p.owner_id = $1::uuid
       AND p.asset_id IS NULL
       AND p.job_type = 'extraction'
       AND p.attempt_count < 3
       AND (p.attempt_count = 0
            OR p.last_transition_at < now() - (CASE p.attempt_count
                 WHEN 1 THEN interval '1 minute'
                 ELSE interval '5 minutes' END))
     ORDER BY p.created_at ASC
     LIMIT 10
     FOR UPDATE SKIP LOCKED
   )
   RETURNING j.*;
   ```

   Explicit gate on rows returned. Zero claimed → silent NoOp
   (`No queued extraction jobs`). Not an error.
3. **Compose labelled sources** for the capture, in one Postgres read.
   Provenance must survive into the prompt — the model must know which
   text came from a card and which from speech:

   - `[TYPED_NOTE]` from `captures.typed_note` (may be empty)
   - `[CARD <asset_id>]` — each sibling `card_vision` job's
     `output.result` (the unwrapped card JSON)
   - `[TRANSCRIPT <asset_id>]` — each sibling `transcription` job's
     `output.result.text`
   - `[SCENE <asset_id>]` — `output.result.scene_description` when
     `image_type` is `scene` or `other`

   Source every field from the **named** node that produced it. Never
   `$json` after I/O.
4. **ONE LLM call**, strict `json_schema`, `temperature: 0`. Extract
   people, companies, roles, summary, topics, opportunities, follow_ups.
   Nullable beats guessed **except** where this contract requires a
   value. Reject any email, phone, domain, or date not present in the
   labelled source evidence. Preserve `name_original_script`; apply the
   same `full_name` transliteration contract as WF-03
   (`architecture.md` §6). Prompt contract (packet 2.6b `wf04-v2`,
   packet 3.7 `wf04-v3`, packet 3.7b `wf04-v4`, packet 3.10 `wf04-v5`):
   - **`summary`:** 1–3 sentences of what was said or noted. **Required**
     when a `[TRANSCRIPT]` or `[TYPED_NOTE]` block has text. Null **only**
     when both blocks are empty.
   - **`topics`:** short sector or theme tags from that same text. Empty
     array only when both blocks are empty.
   - **People** must be proper names present in the sources. A person row
     requires a non-null `full_name`. An Arabic-only (non-Latin)
     `full_name` is **accepted as identity** and does not force
     identity (trap 7 unchanged). A person referred to but not named is
     omitted.
   - **Two-sided card (packet 3.7, `wf04-v3`).** Multiple `[CARD]` blocks
     may be two sides or two photographs of the **same physical card**.
     The `[CARD]` label carries only an `asset_id`; it conveys nothing
     about side or language. A person appearing in more than one block is
     **one** entry in `people[]`, not two. When merging blocks for one
     person: prefer a printed Latin `full_name` over a transliteration;
     keep the original script in `name_original_script`; **union** the
     contact fields rather than choosing one block. The same applies to
     `companies[]`: one physical card is one company. Evidence: capture
     **#63** — one physical card, English front and Arabic back, sent as
     two images; `wf04-v2` emitted **two** `people[]` and **two**
     `companies[]` for one human. The prompt previously had **no** dedup
     instruction. Captures **#62** and **#63** are **not retro-fixed**.
     Live `wf04-v4` system prompt (packet 3.7b): `full_name` is **not**
     required to be Latin (requiring Latin would discard people the
     transliteration fails on). Arabic-only: **transliterate into
     `full_name`** and keep the verbatim original in
     `name_original_script`. Reason: `full_name == name_original_script`
     makes `name_original_script` the identity, which trap 7 forbids.
     The owner needs a searchable Latin name in the briefing and in
     `/ask`. Capture **#61** is the target shape. The Non-Latin flag
     never forces `needs_review` (D4 unchanged) and will now rarely
     fire — that is success, not a failed test. Do not tune the prompt
     to make a flag fire.
   - **Phone when several are printed (packet 3.10, `wf04-v5`).**
     Capture **#66** (Jeraisy two-sided, `wf04-v4`) stored `phone` null
     while evidence listed four distinct numbers (6839333 / 6915840 /
     562650565 / 6183933). Nullable-beats-guessed was working as
     designed, but a first capture of a multi-phone card stored no
     number at all. Live prompt: prefer the number labelled mobile or
     جوال or cell; else the first printed. Do not return null merely
     because more than one number is present. Nullable beats guessed
     still applies when no number is legible. Both `Insert
     extraction_runs` nodes write `prompt_version='wf04-v5'`. Do not
     rewrite capture 66.
5. **Validate in a Code node** (no binary read). Drop or null any
   email / phone / domain / date that does not appear as a substring of
   the labelled sources. **Drop any person with a null or empty
   `full_name`.** Schema-invalid → `needs_review`.
6. **Apply RULE-BASED flagging** (`architecture.md` §6) in that same
   Code node — the **observable conditions**, never model
   self-confidence. Set `flag_reasons` to the matching reason strings
   (empty array if none). Conditions: no name extracted (**`full_name`
   only** — `name_original_script` alone does not count); no email AND
   no phone; non-Latin script present in `full_name` (**informational
   only** — packet 3.6 ruling, packet 3.7 status: this flag alone does
   **not** force `needs_review`; every other flag still does); empty
   transcript despite audio longer than 5 seconds; two or more people
   detected on one card; extraction output fails schema validation;
   capture contains nothing usable.
7. **Write ONE `extraction_runs` row per (`capture_id`,
   `prompt_version`)** (immutable evidence). Never UPDATE an existing
   row. `INSERT … WHERE NOT EXISTS` that pair so a bumped prompt
   (e.g. `wf04-v4`) inserts **beside** `wf04-v3`, it does not overwrite.
   Columns: `model`, `prompt_version`, `raw_vision_output` (jsonb of the
   labelled card/scene results), `raw_transcript` (concatenated
   `[TRANSCRIPT]` texts), `structured_output`, `flag_reasons`. Then set
   the job `succeeded` | `failed` | `needs_review` with the adapter-free
   job row (extraction `output` may hold the structured_output +
   flag_reasons). `last_transition_at = now()`.
8. Enqueue **ONE** capture-level `job_type='entity_resolution'` row
   (`asset_id` NULL, `status='queued'`). Insert once (guard on an
   existing `entity_resolution` row for that `capture_id`). Then **ONE**
   `executeWorkflow` call to WF-05 (`<WF-05_WORKFLOW_ID>`), named
   **`Call WF-05`**, replacing the NoOp **"WF-05 dispatch (not yet)"**.
   `waitForSubWorkflow: false`. `onError: continueRegularOutput`
   **explicit in the saved JSON**. Dispatch is best-effort — enqueue is
   the durable act. Do this on both the `succeeded` and `needs_review`
   extraction paths (a flagged capture still needs a person/interaction
   row and a terminal capture status). Do **not** enqueue or call WF-05
   on the extraction failed/requeue path.

   **Publish order:** WF-05 must be active before WF-04 may reference it;
   WF-04 must be active before WF-03 may reference it. A parent cannot
   be published while it references an unpublished child.

Same failure discipline as WF-03: `succeeded` / `failed` / `needs_review`,
never silent, every branch visibly terminal. `retryOnFail: true` on
provider and DB nodes. Transient provider error → requeue if
`attempt_count < 3`, else `failed`. Backoff is the **claim predicate**
(same as WF-03): delays 1 and 5 minutes, ceiling 3. The 20 minutes is
deleted (unreachable under a 3-attempt ceiling; a twice-failed job is
poison and belongs in the watchdog alert). WF-09 is the kicker, not
the delay. Do not add a Wait here.

**Must not:** unwrap `output.raw`; overwrite any field present in
`field_corrections` (table exists; `/fix` is post-event); log
transcripts, emails, phones, or signed URLs.

**`language` is not set on any node.** There is no transcription node
in WF-04.

---

## WF-05 — Entity resolution

**Phase 2** · **Triggers:** Manual **and** Execute Workflow Trigger.
Claims capture-level `processing_jobs` rows (`job_type='entity_resolution'`,
`asset_id` NULL) the same way WF-04 claims extraction. Enqueued by WF-04
when an extraction job reaches `succeeded` or `needs_review`. Called by
WF-04 (`Call WF-05`, best-effort). Workflow ID on the instance:
`<WF-05_WORKFLOW_ID>`. Never commit the literal.

Settings: `availableInMCP: true`, `errorWorkflow` = LNI WF-00,
`executionTimeout: 300`, timezone **explicitly `Asia/Riyadh`**,
`callerPolicy: workflowsFromSameOwner`.

**Input contract:** a kick is optional — WF-05 **claims from Postgres
itself**. Reads the **latest** `extraction_runs` row for the capture
(`ORDER BY created_at DESC LIMIT 1`) so a `wf04-v4` re-proof is used
without touching `wf04-v3`.

1. **Self-identify** before any write: `SELECT name, timezone, owner_id
   FROM public.events WHERE name = 'LEAP 2026' LIMIT 1`. Explicit gate.
   Wrong database → `stopAndError`.
2. **Claim** queued entity-resolution jobs (same shape as WF-04, with
   `job_type = 'entity_resolution'`):

   ```sql
   UPDATE public.processing_jobs AS j
   SET status = 'running',
       attempt_count = j.attempt_count + 1,
       last_transition_at = now()
   WHERE j.id IN (
     SELECT p.id FROM public.processing_jobs p
     WHERE p.status = 'queued'
       AND p.owner_id = $1::uuid
       AND p.asset_id IS NULL
       AND p.job_type = 'entity_resolution'
       AND p.attempt_count < 3
       AND (p.attempt_count = 0
            OR p.last_transition_at < now() - (CASE p.attempt_count
                 WHEN 1 THEN interval '1 minute'
                 ELSE interval '5 minutes' END))
     ORDER BY p.created_at ASC
     LIMIT 10
     FOR UPDATE SKIP LOCKED
   )
   RETURNING j.*;
   ```

   Zero claimed → silent NoOp (`No queued resolution jobs`). Not an
   error. The claim carries the same backoff predicate as WF-03/04
   (attempt 0 immediate; attempt 1 waits 1 minute; attempt 2 waits 5;
   ceiling 3). WF-09 kicks; it does not delay. **This query does not pick up the older captures sitting at
   `status='processing'`.** Those have no `entity_resolution` job. They
   stay `processing` until a later packet enqueues one (or WF-04 dispatch
   is wired). WF-05 will not sweep them.
3. Load the latest `extraction_runs` row + `captures.capture_no` for
   `j.capture_id`. Missing run or missing capture → `stopAndError`.
   Source every field from the **named** node. Never `$json` after I/O.
4. **Auto-link ONLY** on exact `people.email_normalized` or exact
   `people.linkedin_url_normalized` **where
   `people.linkedin_source = 'card'`** (both URL columns
   `GENERATED … STORED`). An apollo-sourced LinkedIn URL must never
   auto-link two people (packet 4.5). Live node: **Upsert people**
   (`li_match` + insert `NOT EXISTS`). **Name similarity NEVER
   auto-merges**, at any score, for any reason.
   Skip any extracted person with a null/empty `full_name` (defence in
   depth; WF-04 already dropped them).

   **Packet 4.5 measured.** Capture 70 probe (same LinkedIn URL as
   Ahmad's apollo-sourced row, no email): WF-05 exec **263511**, last
   node **WF-06 dispatch (not yet)**. **Upsert people**
   `li_linked=0`, `inserted=1`. Ahmad stayed `linkedin_source=apollo`.
   Two people now share that URL and were not merged.

   **Vision OCR is not reproducible on this card stock at
   `temperature: 0` (packet 3.9, architect).** Same physical cards,
   two runs: capture 65 vs 67 disagreed on Latin spelling and on the
   phone; capture 64 vs 66 disagreed on whether a phone was present
   (four distinct numbers in evidence, stored phone null on the
   second run). Consequences: exact email is the **only** stable join
   key; a stored phone is the first read that landed, not verified
   truth; re-capturing a person will raise a candidate per disagreeing
   field. This is why auto-link on name is banned and **stays banned**.
5. **Upsert** `people`, `companies`, `person_companies`, `interactions`.
   Preserve `name_original_script` verbatim — never overwrite a stored
   original with null. Write `interactions.summary` and
   `interactions.topics` from `structured_output`. One interaction per
   capture. A capture with zero people still gets an interaction
   (`person_id` NULL) so the summary is not lost, and still gets a
   terminal capture status.

   **Company matcher (packet 3.7).** Cause of the live orphans (accepted):
   Prepare resolution unioned `companies[].name` and `people[].company_name`
   by exact lowercase with **no precedence**. Link `person_companies` and
   Insert interaction join **only** `people[].company_name`. Result: a
   `companies[]` name that no person uses becomes an orphan row. Live
   proof — three rows for one company, **not retro-fixed**:

   - `'شركة هواوي تك انفستمنت العربية السعودية المحدودة'` (capture 62, linked)
   - `'Huawei'` (capture 62, orphan — `companies[]` only)
   - `'Huawei Tech. Investment Saudi Arabia Co., Ltd.'` (capture 63, has domain)

   Required properties:

   - A company row is created **only when a person links to it**. No row
     from `companies[]` that no person references.
   - `companies[]` **enriches** the linked row (domain; website maps to
     `companies.domain` when domain is empty). It does **not** create a
     parallel row.
   - **No fuzzy auto-merge on name alone.** Substring matching is
     **banned** — `'BT'` inside `'BTGroup'` is exactly the failure this
     project already knows about. Match key is **exact**
     `lower(trim(name))` only.
   - When you cannot match confidently, write an `entity_candidates` row.
     **Never** a second silent company.

   Matcher:

   1. Person-linked key = exact `lower(trim(people[].company_name))`.
      Empty `company_name` → that person does not create a company.
   2. If the person **auto-links** (exact email or exact LinkedIn) and
      already has a current `person_companies` row: **reuse that
      `company_id`**. Do not INSERT from a disagreeing incoming
      `company_name`. If the incoming key differs from the stored
      company name, write `entity_candidates` (`entity_type='company'`,
      `candidate_entity_id` = stored company) with visible reasons
      naming both strings. Packet 3.9 reconciles aliases.
   3. Else lookup an owner company by that exact key. Found → reuse id.
      Not found → INSERT from `people[].company_name` only.
   4. Enrichment: apply `companies[]` domain (and website-as-domain)
      **only** when `lower(trim(companies[].name))` equals the **linked**
      company's exact key. Upgrade null domain; never overwrite
      non-null. A `companies[]` entry whose exact key is **not** the
      linked key is **not inserted**. Write `entity_candidates` on the
      person (`unlinked_company_payload`, name visible in `reasons`).
   5. `roles[]` is ignored (unchanged).

   **Person field precedence (packet 3.7) on an email or LinkedIn
   auto-link.** Cause: first-write-wins. Capture 62 (Arabic only)
   created the person. Capture 63 arrived with a clean English card
   carrying the same email and could not improve it. Stored record is
   still `full_name` `'وانغ (بوب)'` with title `'نائب المدير'` while
   `'Zhang Wenwu (Kyle)'` / `'Deputy Director'` were available and
   discarded. The quality of a contact record currently depends on
   which side of the card arrived first. That is the defect. Captures
   **#62** and **#63** are **not retro-fixed**.

   On match to an existing person:

   - A Latin `full_name` **upgrades** a stored non-Latin one.
   - A non-null value **upgrades** a stored null (`title`, `phone`,
     `linkedin_url`). Incoming email does not overwrite a stored email
     on the email-match path; LinkedIn-match may fill a null email.
   - A non-null stored value is **never** overwritten by null.
   - When two non-null **Latin** values disagree, keep the stored one
     and write an `entity_candidates` row (`entity_type='person'`). Do
     not silently pick.
   - `name_original_script`: `COALESCE(stored, incoming)` — never
     overwrite a stored original with null.

   Auto-link still requires exact `email_normalized` or exact
   `linkedin_url_normalized`. That rule does not move. Latin detection
   is the same test WF-04 uses: a name is non-Latin when it matches
   `/[^\u0000-\u024F\u1E00-\u1EFF\s]/`.
6. **Non-exact match** writes a scored `entity_candidates` row with
   **visible `reasons`**. Never a merge, at any score.

   - **OCR-split (packet 2.7, primary):** whenever another owner person
     shares **exact `full_name` AND exact `company_id`**, even if both
     rows carry emails, when those emails are **not equal**. `reasons`
     is human-readable and **names the two differing emails** (e.g.
     `same_full_name`, `same_company`,
     `emails_differ: a@x vs b@x`). `score = 1`. This is the visibility
     for the most likely duplicate-creation mechanism at the event
     (same card, two OCR readings).
   - **No auto-link key (secondary):** if the extracted person has no
     email and no LinkedIn, and another owner person has a
     trigram-similar `full_name`, write a suggestion with
     `reasons = {name_trgm}` and `score = similarity(...)`. No
     threshold tuning.

   Do not skip the OCR-split path just because both rows have emails.
   A pair of silent unlinked people with `entity_candidates` empty is
   a defect.
   **Packet 3.9 C** applied an **owner-confirmed** merge of the Imran
   OCR-split pair (survivor = the `ikhalid@` row; absorbed title
   carried) and collapsed three Huawei company rows onto the
   `huawei.com` survivor. That is data. WF-05 still never auto-merges.
   MDS transliteration and phone candidates stay `pending`.
7. **Capture status (packet 3.7):** set `needs_review` when
   `flag_reasons` contains any flag **other than** `'Non-Latin script
   present in the name field'`. That flag **alone** no longer blocks
   `ready`. Every other flag still does. (`failed` is not set here.)
   Packet 3.6 / 3.7 owner ruling: a non-Latin `full_name` is accepted
   as identity. `'Non-Latin script present in the name field'` stays in
   `flag_reasons` as information only. An Arabic-only `full_name` is
   accepted identity. `full_name` must still be non-null. `name_original_script`
   alone is still not identity (trap 7 unchanged). Captures **#62** and
   **#63** are evidence and are **not retro-fixed**.
   Packet 3.9 C merge of Imran / Huawei is data, not a WF-05 auto-merge.
8. **Notify:** WF-01 is the only workflow that sends Telegram
   (`workflows.md` WF-01). WF-05 does **not** add a second send point.
   Flagged → `needs_review` (visible). Unflagged → `ready` and **silent**.
   The digest (WF-07) is the owner-facing list of flagged captures until
   a later packet wires notify through WF-01.
9. Mark the `entity_resolution` job `succeeded` | `failed` |
   `needs_review`. Same failure discipline as WF-03/WF-04.
   `retryOnFail: true` on DB nodes.
10. **Enqueue enrichment** (replaces the NoOp `WF-06 dispatch (not yet)`).
    `INSERT INTO processing_jobs` `job_type='enrichment'` `status='queued'`
    for each person on this capture with a non-null `email_normalized`
    whose capture is **not** `needs_review`.
    `ON CONFLICT ((output->>'person_id'), job_type) WHERE job_type =
    'enrichment' AND (output->>'person_id') IS NOT NULL AND status =
    'queued' DO NOTHING`.
    `force` is absent, so the cache guard applies. **Do not call WF-06.
    Do not dispatch.** Enqueue is the durable act. `alwaysOutputData:
    true`. Explicit row-returned gate (`id` notEmpty) — a zero-row
    write returns `{success:true}`. False → **No enrichment to enqueue**
    NoOp. True → **Enrichment queued** NoOp. WF-06 stays INACTIVE;
    queued jobs wait.

    **Packet 4.7 measured.** Capture 64 re-run of entity resolution:
    WF-05 exec **263857**, last node **Enrichment queued**. Job
    `6b21fbf5` `job_type='enrichment'` `status='queued'`. WF-06 did
    not run (`activeVersionId` null; zero WF-06 executions after
    that timestamp).

**Must not:** auto-merge on name; overwrite `field_corrections`; unwrap
`extraction_runs` provider envelopes (there are none — read
`structured_output`); log emails, phones, transcripts, or signed URLs;
send Telegram; sweep `captures.status='processing'` that have no
resolution job.

**`language` is not set on any node.** There is no transcription node
in WF-05.

---

## WF-06 — Enrichment

**Phase 4** · **Triggers:** Manual + Schedule `*/15 * * * *`.
**Live:** built **INACTIVE**. Packet 4.7 does not publish. Timezone is
`settings.timezone: Asia/Riyadh` only. `availableInMCP: true`,
`errorWorkflow` = LNI WF-00, `executionTimeout: 300`,
`callerPolicy: workflowsFromSameOwner`. MCP create does not persist
settings or credentials — REST PUT after create, then re-GET. Postgres
**Leap-NI**. HTTP **Apollo Leap-NI** and **Tavily Leap-NI**
(`httpHeaderAuth`). First httpHeaderAuth on this instance is Storage;
MCP will bind the wrong one. Bind by REST PUT; prove by re-GET, then a
self-identifying execution (`SELECT name FROM public.events WHERE
name = 'LEAP 2026'`).

WF-05 **enqueues** `job_type='enrichment'` in this packet. It does
**not** dispatch. `/flag` is still later. WF-06 remains INACTIVE, so
enqueued jobs wait. That is intended and safe. This workflow drains
the queue on schedule once published; until then, prove runs are
manual.

Queued job `output.person_id` is the person uuid (no new column).
`force` absent means false. Packet 4.5: **Write match** may fill
`people.linkedin_url` when it is NULL, with `linkedin_source =
'apollo'`. Never overwrite a non-null URL. Never touch email /
full_name / title / phone.

**Tavily company fallback.** Off the **Write no match** path only.
Fires only when Apollo returned hollow (`name` empty) AND the person's
company has a non-null domain not on `lni_free_email_domains`. Enriches
the company, never the person. Rows: `provider='tavily'`,
`entity_type='company'`. Never merged with an Apollo row. Never written
to `people.*`. Ceiling `tavily_lifetime_ceiling` checked **before** the
call (`sum(credits_spent)` where `provider='tavily'` and `status IN
('attempted','confirmed')`). Ledger `operation='tavily_search'`, row
inserted `attempted` before the HTTP call. Success → `confirmed`,
`credits_spent=1` **by contract** (Tavily has no free balance endpoint
equivalent to Apollo's profile). Empty/no useful result → `no_match`,
no enrichment row. HTTP error → ledger `failed`, job `failed`. Over
ceiling → job `needs_review`, `error_code='ceiling_reached'`, no call.
The 30-day cache applies to company/tavily rows too. Tavily
pay-as-you-go is ENABLED with an $8 / 1000-credit cap; an unguarded
loop would bill real money.

### Node graph (as built)

1. **Manual Trigger** and **Schedule drain** (`*/15`) both feed
   **Self identify**.
2. **Self identify** — Postgres `SELECT name, timezone, owner_id FROM
   public.events WHERE name = 'LEAP 2026' LIMIT 1`.
   `alwaysOutputData: true`, `executeOnce: true`, `retryOnFail: true`,
   `replaceEmptyStrings: false`.
3. **Row returned?** — `name` equals `LEAP 2026`, `typeValidation:
   strict`. False → **Wrong database terminal** (`stopAndError`, no
   comma/quote/apostrophe).
4. **Claim enrichment job** — one row, oldest first:
   `UPDATE … WHERE id = (SELECT … job_type='enrichment' AND
   status='queued' … ORDER BY created_at ASC LIMIT 1 FOR UPDATE SKIP
   LOCKED) RETURNING`. `alwaysOutputData: true`. `queryReplacement` is
   one array: owner_id from **Self identify**.
5. **Job returned?** — claimed `id` notEmpty, strict. False →
   **Empty queue** NoOp (not an error).
6. **Load person** — `people` by `output.person_id`, plus current
   `company_id`, `companies.domain` as `company_domain`, and
   `split_part(email_normalized, '@', 2)` as `email_domain`.
   Named-node sourcing after this I/O.
7. **Person has email?** — `email_normalized` notEmpty. False →
   **No email terminal** (`stopAndError`).
8. **Load ceilings** — `lni_config` keys `apollo_daily_ceiling` and
   `apollo_lifetime_ceiling`; `sum(credits_spent)` of `credit_ledger`
   rows with `provider='apollo'` and `status IN
   ('attempted','confirmed')` for today Riyadh and lifetime. Not
   `count(*)`. `'no_match'` stays off the IN list.
9. **Ceiling ok?** — `daily_used < daily_ceiling` AND
   `lifetime_used < lifetime_ceiling`. False → **Mark ceiling
   reached** (job `needs_review`, `error_code='ceiling_reached'`,
   envelope error class `ceiling_reached`) → **Ceiling stop** NoOp.
   **No HTTP. No ledger row.**
10. **Cache check** — after the ceiling gate, before **Read credits
    before**. Never reaches the provider. A person is not re-enriched
    while a person/apollo `enrichment_records` row younger than 30
    days exists. Hollow results are cached on the same terms. `force`
    is read from the job `output` payload; absent means false. Only
    `force=true` bypasses; `/flag` is the only producer of
    `force=true`. True → **Write cache skip** (`credit_ledger`
    `operation='skipped_cached'`, `status='no_match'`,
    `credits_spent=0`, job `'succeeded'`, no new
    `enrichment_records`) → **Cache skip** NoOp. False → continue.
11. **Read credits before** — GET
    `https://api.apollo.io/api/v1/users/api_profile?include_credit_usage=true`.
    Official Apollo docs: Get Current User Profile, 0 credits.
    `httpHeaderAuth` **Apollo Leap-NI** (REST PUT bind; re-GET proof).
    `neverError: true`, `fullResponse: true`. **No** `retryOnFail`.
    Placed **before Insert ledger**. Named-node sourcing:
    `body.num_credits_remaining`. Do not log the profile email.
12. **Insert ledger** — `credit_ledger` `provider='apollo'`,
    `credits_spent=1` (conservative hold), `operation='people_match'`,
    `status='attempted'`, `entity_id` = person. **Before the enrich
    HTTP call.** `alwaysOutputData: true`. `retryOnFail: true`.
13. **Apollo people match** — POST
    `https://api.apollo.io/api/v1/people/match` JSON `{email}` from
    **Load person**. `httpHeaderAuth` **Apollo Leap-NI**.
    `neverError: true`, `fullResponse: true`. **No** `retryOnFail`.
    `onError: continueRegularOutput`. Do not reveal personal emails
    or phones (`reveal_*` absent / false).
14. **Read credits after** — same GET as **Read credits before**,
    after the Apollo call, before the write nodes.
15. **HTTP ok?** — `statusCode` of **Apollo people match** >= 200 AND
    < 300. False → **Write HTTP failed** (ledger `'failed'`, job
    `'failed'`, envelope error class `http`) → **HTTP failed** NoOp.
16. **Person matched?** — Apollo `body.person.name` non-empty after
    trim, coerced to string. **Never `person.id`.** Apollo mints an
    id for a hollow shell (packet 4.3, `.example` domain).
    `typeValidation: strict`. True → **Write match**. False →
    **Write no match**.
17. **Write match** — `credits_spent` = measured delta (`Read credits
    before` minus `Read credits after`, floored at 0). Status
    `'confirmed'` when the name is non-empty — including
    `'confirmed'` / `credits_spent=0` when a named reveal cost
    nothing. That is honest. `enrichment_records`
    `entity_type='person'` `provider='apollo'` payload = person
    object; **second** row `entity_type='company'` only when
    `person.organization` is present AND `email_domain` is **not**
    in `lni_free_email_domains`. Job `'succeeded'`. Envelope
    `result` = person. **LinkedIn write-back (packet 4.5):**
    `UPDATE people SET linkedin_url = <apollo value>,
    linkedin_source = 'apollo' WHERE id = <person> AND
    linkedin_url IS NULL AND the Apollo value is non-empty`.
    Never overwrite a non-null `linkedin_url`. Never touch email,
    full_name, title, or phone. → **Match done** NoOp.
18. **Write no match** — hollow response. Ledger `'no_match'`,
    `credits_spent=0` (overwrite the attempted hold). Envelope
    `result` null. **No `enrichment_records` row** for the person.
    Then **Tavily eligible?** — `company_id` not null AND
    `companies.domain` not null AND domain not in
    `lni_free_email_domains`. False → **No match** NoOp (finish as
    today, no Tavily call). True → continue. Job status is updated
    again by the Tavily writers.
19. **Tavily ceiling** — `tavily_lifetime_ceiling` vs
    `sum(credits_spent)` where `provider='tavily'` and `status IN
    ('attempted','confirmed')`. False → **Mark tavily ceiling**
    (job `needs_review`, `error_code='ceiling_reached'`, envelope
    provider `tavily`) → **Tavily ceiling stop** NoOp. **No HTTP.
    No ledger row.**
20. **Tavily cache check** — company/tavily `enrichment_records`
    row younger than 30 days. `force=true` bypasses. True →
    **Write tavily cache skip** (`skipped_cached` / `no_match` / 0,
    job `'succeeded'`, no new enrichment row) → **Tavily cache skip**
    NoOp. False → continue.
21. **Insert tavily ledger** — `provider='tavily'`,
    `credits_spent=1` (contract hold), `operation='tavily_search'`,
    `status='attempted'`, `entity_id` = company. **Before the HTTP
    call.**
22. **Tavily search** — POST `https://api.tavily.com/search` JSON
    `{query: company_domain}`. `httpHeaderAuth` **Tavily Leap-NI**
    (REST PUT bind; re-GET proof). `neverError: true`,
    `fullResponse: true`. **No** `retryOnFail`. Do not log payloads.
23. **Tavily HTTP ok?** — `statusCode` >= 200 AND < 300. False →
    **Write tavily HTTP failed** (ledger `'failed'`, job `'failed'`)
    → **Tavily HTTP failed** NoOp.
24. **Tavily useful?** — `body.answer` non-empty after trim, or
    `body.results` length > 0. False → **Write tavily no match**
    (ledger `'no_match'`, `credits_spent=0`, job `'succeeded'`, no
    enrichment row) → **Tavily no match** NoOp.
25. **Write tavily match** — ledger `'confirmed'`, `credits_spent=1`
    by contract (not measured). `enrichment_records`
    `entity_type='company'` `provider='tavily'` payload = Tavily
    body. Job `'succeeded'`. Never touch `people.*`. → **Tavily
    done** NoOp.

Adapter envelope on `processing_jobs.output` (Phase 2 shape):
`provider`, `model` (`people/match`), `job_type` (`enrichment`),
`result`, `raw`, `error`, `completed_at`.

**Match test is `name` non-empty after trim, never `person.id`.**
Apollo bills on reveal. A hollow response costs 0 credits.
`credits_spent` is **measured** from the delta in
`num_credits_remaining`, not assumed to be 1.

**Re-enrichment cache.** A person is not re-enriched while a
person/apollo `enrichment_records` row younger than 30 days exists.
The job completes as succeeded with a `credit_ledger` row
`operation='skipped_cached'`, `status='no_match'`, `credits_spent=0`,
and NO new `enrichment_records` row. Hollow results are cached on
the same terms. Only a job carrying `force=true` bypasses the
cache; `/flag` is the only producer of `force=true`.
Measured 28 Aug 2026: two runs on the same person spent two
credits and wrote duplicate enrichment rows. That is why. The
cache check sits after the ceiling gate and before **Read credits
before**, so a skip never calls Apollo.

**Ceiling OPEN QUESTION from packet 4.3: closed.** `'no_match'` does
not join the IN list, because a no-match costs nothing. Keep
`status IN ('attempted','confirmed')`. Sum `credits_spent`, do not
`count(*)`.

**Known discrepancy (evidence, not edited).** Ledger row
`73fc2831-2231-40f4-9013-8a67d5dc4074` is `confirmed` / 1 for a call
that cost 0. Lifetime ledger over-counts by 1 from packet 4.3
onward. Do not edit or delete that row, the three existing
`enrichment_records` rows, or the probe person.

**Packet 4.4 measured (27 Aug 2026).** Profile GET
`https://api.apollo.io/api/v1/users/api_profile?include_credit_usage=true`
twice in a row: both `num_credits_remaining` = 2603 (read is free).
Probe person re-enqueue exec **261870**, last node **No match**,
ledger `b1705c4b` `no_match` / 0, workflow balances 2603 → 2603,
`enrichment_records` stayed 3. Real match: Ahmad (`jccs.com.sa`,
capture 64 ready) exec **261890**, last node **Match done**, ledger
`3cbde4e5` `confirmed` / 1, workflow balances 2603 → 2602,
`enrichment_records` 3 → 5 (person + company). Two other original-6
people (Amer, Imran) were also hollow `name` / 0-credit `no_match`
before Ahmad revealed. Ledger `73fc2831` untouched. WF-06 still
inactive.

**Packet 4.5 measured.** Ahmad re-enqueue exec **263494**, last node
**Match done**. `people.linkedin_url` filled, `linkedin_source=apollo`.
Ledger `472336d7` `confirmed` / 1. Workflow balances 2602 → 2601.
Second run exec **263502**: `linkedin_written` null (no overwrite,
md5 unchanged). Did **re-enrich and spend**: 2601 → 2600, ledger
`64b45415` `confirmed` / 1. No skip-if-already-enriched yet.

**Packet 4.6 measured (28 Aug 2026).** WF-06 still inactive
(`active: false`, `activeVersionId: null`). Self identify:
`LEAP 2026`. Ledger `73fc2831` untouched.

1. Ahmad, `force` absent. Exec **263628**, last node **Cache skip**.
   Ledger `575e488b` `skipped_cached` / `no_match` / 0. Job
   `8889c9ec` succeeded. `enrichment_records` 9 → 9. **Read credits
   before** and **Apollo people match** did not run (no in-workflow
   balance; skip never reached the provider).
2. Ahmad, `force=true`. Exec **263634**, last node **Match done**.
   Cache check `skip_cached=0`. Ledger `543315cc` `people_match` /
   `confirmed` / 1. Workflow balances 2600 → 2599. `enrichment_records`
   9 → 11 (new person + company rows). `linkedin_written` null.
3. Hollow probe `ad9c6cde`, `force` absent. Exec **263638**, last
   node **Cache skip**. Ledger `32b13a09` `skipped_cached` /
   `no_match` / 0. Job `5cfd9e94` succeeded. `enrichment_records`
   11 → 11. Profile / Apollo nodes did not run. Probe person not
   edited.

**Packet 4.7 measured (28 Aug 2026).** WF-06 still inactive
(`active: false`, `activeVersionId: null`). Self identify:
`LEAP 2026`. Ledger `73fc2831` untouched. Apollo
`num_credits_remaining` 2599 → 2599 (moved only on the two hollow
Apollo calls which cost 0; no reveal).

1. Tavily hit, Amer / BTGroup `hasoub.com`. Exec **263839**, last
   node **Tavily done**. Apollo ledger `b7027914` `people_match` /
   `no_match` / 0. Tavily ledger `24a93ea3` `tavily` /
   `tavily_search` / `confirmed` / 1 (contract). Job `d69c89ee`
   succeeded. `enrichment_records` 11 → 12. New row
   `0ac1fe43` `entity_type='company'` `provider='tavily'`.
   Workflow Apollo balances 2599 → 2599.
2. Tavily ceiling. `tavily_lifetime_ceiling=0`. Imran / Qatar
   Airways. Exec **263849**, last node **Tavily ceiling stop**.
   Job `4b345fa7` `needs_review` `error_code='ceiling_reached'`.
   **Tavily search** and **Insert tavily ledger** did not run.
   Only Apollo ledger `4c8a15cc` `no_match` / 0. No tavily
   `attempted` row. `enrichment_records` stayed 12. Restored
   ceiling to 1000. Live `lni_config`: `apollo_daily_ceiling=60`,
   `apollo_lifetime_ceiling=2200`, `tavily_lifetime_ceiling=1000`.
3. WF-05 enqueue, capture 64. Exec **263857**, last node
   **Enrichment queued**. Created enrichment job `6b21fbf5`
   `status='queued'` `force` absent. WF-06 executions after that
   timestamp: none. WF-06 `activeVersionId` null.

**Tavily credits_spent is 1 by contract**, not measured. Tavily has
no profile-equivalent remaining-credit read. Pay-as-you-go is ENABLED
with an $8 / 1000-credit cap.

**Must not:** publish/activate this workflow in packet 4.7; touch
WF-01; overwrite captured email / full_name / title / phone; `$env`;
`$getWorkflowStaticData`; retry-loop the HTTP node; log emails,
phones, or payloads; treat enrichment as card evidence; call
`organizations/enrich`; edit ledger `73fc2831`. WF-05 enqueues
only — it does not dispatch WF-06. LinkedIn write-back is NULL-fill
only. Cache skip must not reach the provider.

---


## WF-07 — Digests

**Phase 3** · **Triggers:** two Schedule Triggers + Execute Workflow Trigger.

`scheduleTrigger` v1.3 has **no node-level timezone**. Both crons are
bare expressions (`0 22 * * *`, `0 7 * * *`). Timezone is
**`settings.timezone: Asia/Riyadh` only.** A UTC container with no
workflow timezone fires 7 AM at 10 AM Riyadh. Proof of timezone is an
**observed execution `startedAt`**, never the cron string.

Workflow ID on the instance: `<WF-07_WORKFLOW_ID>`. Never commit the
literal. Settings: `availableInMCP: true`, `errorWorkflow` = LNI WF-00,
`executionTimeout: 300`, timezone `Asia/Riyadh`,
`callerPolicy: workflowsFromSameOwner`. MCP create does not persist
these — REST PUT after create, then read-back. Postgres credential
**Leap-NI**. First execution self-identifies
(`SELECT name FROM public.events WHERE name = 'LEAP 2026'`). Gate
`Row returned?`: `name` **equals** `LEAP 2026`, `typeValidation:
strict` (same as WF-03/04/05). Wrong database → `stopAndError`
(`Wrong database terminal`). Message: no comma, quote, or apostrophe.
Self identify: `executeOnce: true` and `options.replaceEmptyStrings:
false` explicit in saved JSON.

After **Load digest** (`alwaysOutputData: true` kept): IF named Load
`kind` equals `close` or `brief` (`typeValidation: strict`) AND
`riyadh_date` notEmpty. False → `stopAndError`. Do not compose. Do not
send. Do not return to WF-01.

A real SQL row with captured = 0 is a valid report and SHOULD send.
An empty item from alwaysOutputData on zero rows is NOT a report and
must NOT send. These are different things and the gate exists to tell
them apart. Never gate on captured > 0.

### Triggers

| Trigger | `kind` | `source` | Sends? |
|---|---|---|---|
| Cron `0 22 * * *` Asia/Riyadh | `close` | `schedule` | Telegram + email |
| Cron `0 7 * * *` Asia/Riyadh | `brief` | `schedule` | Telegram + email |
| Execute Workflow (WF-01 `/digest`) | hour < 12 Riyadh → `brief`, else `close`; optional `kind` override | `call` | no — return `reply_text` |

Each trigger feeds a named Set (`kind`, `source`) then the shared
self-identify node. Source every later field from the **named** node
that produced it, never `$json` after Postgres.

Optional Execute Workflow inputs (call path only; production `/digest`
omits them):

- `since` — timestamptz text. Empty → `events.starts_at` for LEAP 2026
  (read at runtime). Never hardcode a date. The 29 Aug gate test
  passes `since` so counts are non-zero before the event window
  opens.
- `kind` — `close` or `brief`. Empty → hour rule above.

### Day (`today`) is Riyadh

```sql
(opened_at AT TIME ZONE 'Asia/Riyadh')::date
  = (now() AT TIME ZONE 'Asia/Riyadh')::date
```

Same pattern for `due_at`, `closed_at`. Never `::date` on timestamptz
without the zone (that is UTC date).

### 10:00 PM — Day close (deterministic, no model)

One parameterised query, owner-scoped from the self-id `owner_id`.
**Scope lower bound** = `COALESCE($since::timestamptz, events.starts_at)`.
Counts for **today Riyadh** that also satisfy `opened_at >= scope`:

| Key | Definition |
|---|---|
| `captured` | captures opened today |
| `clean` | those with `status = 'ready'` |
| `flagged` | those with `status = 'needs_review'` |
| `failed` | those with `status = 'failed'` |
| `stuck` | those with `status = 'processing'` AND `closed_at` not null |

Plus a flagged list: `capture_no` and `flag_reasons` from the latest
`extraction_runs` row per capture. Cap 20 lines. No emails, phones,
transcripts. `queryReplacement` is one array expression.

Compose text in a Code node from that named query. Shape:

```
LNI day close (Riyadh date)
captured N · clean N · flagged N · failed N · stuck N
#12 needs_review: No name extracted
#59 needs_review: No email and no phone
```

Zero captured is still a real report (not silent). The **stuck** count
is the figure that saves the project.

A real SQL row with captured = 0 is a valid report and SHOULD send.
An empty item from alwaysOutputData on zero rows is NOT a report and
must NOT send. These are different things and the gate exists to tell
them apart. Never gate on captured > 0.

### 7:00 AM — Morning briefing (deterministic, no model)

Highest-value output. Highest-risk item. Counts **to date** (event
scope, not today-only). Same scope lower bound as the day close
(`COALESCE($since::timestamptz, events.starts_at)`). Rows with
`created_at` / `opened_at` before the bound are out of the briefing.

| Key | Definition |
|---|---|
| people | `count(*)` on `people` |
| companies | `count(*)` on `companies` |
| sectors | `coalesce(nullif(btrim(industry), ''), 'unknown')` grouped |
| gaps | `events.target_sectors` minus observed sector keys. Empty array → print `Target sectors not set` — do not invent a list |
| follow-ups due today | `follow_ups.status = 'open'` AND due date = today Riyadh |
| unreviewed | `people.review_status = 'unreviewed'` plus `captures.status = 'needs_review'` plus `entity_candidates.decision = 'pending'` |
| stuck (event to date) | captures with `status='processing'` AND `closed_at IS NOT NULL`, bounded below by the digest `since` |

Day close is today-only, so a capture that jams and stays jammed is
invisible to that report. Until WF-09 exists, the briefing stuck
line is the digest's only view of leftover `processing` rows.

**Launch facts (inert, not defects).** `follow_ups` has zero rows.
Nothing in WF-01 through WF-05 writes one, so "follow-ups due today"
reads 0 at launch. Both sector lines are also inert by design:
`companies.industry` is null on every row until Phase 4, so the mix
reads `unknown`; `events.target_sectors` is the empty array, so the
gaps line prints `Target sectors not set`. Do not invent a list. Do
not treat either line as a bug.

Compose. No LLM. `Compose digest` emits `reply_text` (plain, for Gmail
and the `/digest` return) and `telegram_text` (HTML-escaped `&` then
`<` then `>`). `Telegram digest` sends `telegram_text` with
`additionalFields.parse_mode: HTML`. Gmail stays `emailType: text` on
`reply_text`. Absent `parse_mode` is not plain text on this build
(`workflows.md` §1 trap; exec 254927).

### `/digest` return contract (source = call)

```json
{ "ok": true, "reply_text": "<composed report>" }
```

`reply_text` is a string. `capture_no` is not required. Empty
`reply_text` is a defect (a digest always has counts). WF-01 sends.

### Scheduled send

Standard LNI scheduled-send topology (packet 3.6). Email exists to
survive a Telegram-specific death, and serial wiring makes email
depend on the thing it insures against. **WF-09 MUST use this and
must not copy WF-07's old serial graph.**

1. After compose: IF `source = schedule` AND `reply_text` notEmpty.
   Call path (`source = call`) returns `reply_text` and does **not**
   send.
2. Resolve `chat_id` and owner email in the **same** Leap-NI Postgres
   node as the counts if possible; otherwise a second Leap-NI node
   (restore-by-name — a *new* node auto-assigns ElderWise).
   `chat_id` ← `bot_state.telegram_user_id`. Email ←
   `auth.users.email` for `events.owner_id`. Never `$env`.
3. Fan-out from `Scheduled send?` **true**. Send in **parallel**. Merge
   **after** both attempts, never before (Telegram `retryOnFail` must
   not delay mail).
   - `Chat id present?` true → Telegram (`sendMessage`,
     `appendAttribution: false`, `retryOnFail: true`,
     `onError: continueRegularOutput`). False → skip Telegram (not
     `stopAndError`).
   - `Email present?` true → Gmail (`continueOnFail: true`,
     `onError: continueRegularOutput`). False → skip email.
4. After Merge: IF at least one delivered. Delivery is Telegram
   `message_id` or Gmail `id` from the **named** send node via
   `$('Node').first()` — never `.item` (the discarded Merge branch
   is not an ancestor) and never "the node ran". Keep `isExecuted`
   guards. A `continueOnFail` item with an `error` is not delivered.
   True → NoOp `Scheduled done`. False → `stopAndError`
   (both channels empty or both failed) so WF-00 runs.
5. Empty-item Load digest must not reach compose or send (gate on
   named Load `kind` + `riyadh_date`, not on `captured > 0`).

**Must not:** log emails, phones, transcripts, signed URLs; call WF-06;
deactivate WF-01–05; send on the `call` path (WF-01 owns that send);
deactivate WF-07 (22:00 timezone proof).

---

## WF-08 — Query (`/ask`)

**Phase 3** · **Trigger:** Execute Workflow Trigger (called by WF-01)
Workflow ID: `<WF-08_WORKFLOW_ID>`. Never commit the literal.
Settings: `availableInMCP: true`, `errorWorkflow` = LNI WF-00,
`executionTimeout: 300`, timezone `Asia/Riyadh`. Postgres **Leap-NI**.
OpenAI: same instance credential WF-03/04 already use. `temperature: 0`.
Self-identify: `executeOnce: true`, `replaceEmptyStrings: false`.
Empty `reply_text` after compose is a **defect** (`stopAndError`), not
a silent success.

**Input:** `owner_id`, `correlation_id`, `question` (string). Reject
unknown extra fields if present. Empty / missing `question` →
`ok: true`, `reply_text` = `Usage: /ask <question>` (non-empty, so
WF-01 sends the hint).

1. **Self-identify** before any read that is not the events probe.
   Wrong database → `stopAndError`.
2. **Retrieve** owner-scoped rows. Parameterised. Trigram plus
   structured filters:
   - `people.full_name % $q` OR `companies.name % $q` OR
     `interactions.summary % $q` (pg_trgm, already indexed)
   - Always also load recent interactions with `capture_no`, person
     `full_name` / `name_original_script` / `title`, company `name`,
     `summary`, `topics`, follow-up titles. Cap 80 interaction rows
     by `occurred_at DESC`. A few hundred rows fit; this cap is the
     launch ceiling.
   - Do **not** select `email`, `phone`, transcripts, or signed URLs
     into the model context if a name+company+capture_no answer will
     do. If the question is clearly about an email or phone, include
     those fields for the matched rows only.
3. **Compose context** in Code from the **named** retrieve node.
   If zero rows: context is the empty-corpus sentence, not a guessed
   contact.
4. **Answer** with one OpenAI call (`gpt-4o-mini`, `temperature: 0`).
   System instructions: cite capture numbers; state plainly when
   evidence is weak; never invent a person, company, or meeting;
   Arabic names in `name_original_script` may be quoted; no facial
   identification.
5. Return `{ ok: true, reply_text: "<answer>" }`. WF-01 sends.
   WF-08 has **no** Telegram node. WF-01 calls WF-08 with
   `waitForSubWorkflow: true` — this is request/response for text the
   owner is waiting on, not a durable enqueue. Same for `/digest` →
   WF-07.

1. **Self-identify** before any read that is not the events probe.
   Wrong database → `stopAndError`.
2. **Retrieve** owner-scoped rows. Parameterised. Trigram plus
   structured filters:
   - `people.full_name % $q` OR `companies.name % $q` OR
     `interactions.summary % $q` (pg_trgm, already indexed)
   - Always also load recent interactions with `capture_no`, person
     `full_name` / `name_original_script` / `title`, company `name`,
     `summary`, `topics`, follow-up titles. Cap 80 interaction rows
     by `occurred_at DESC`. A few hundred rows fit; this cap is the
     launch ceiling.
   - Do **not** select `email`, `phone`, transcripts, or signed URLs
     into the model context if a name+company+capture_no answer will
     do. If the question is clearly about an email or phone, include
     those fields for the matched rows only.
3. **Compose context** in Code from the **named** retrieve node.
   If zero rows: context is the empty-corpus sentence, not a guessed
   contact.
4. **Answer** with one OpenAI call (`gpt-4o-mini`, `temperature: 0`).
   System instructions: cite capture numbers; state plainly when
   evidence is weak; never invent a person, company, or meeting;
   Arabic names in `name_original_script` may be quoted; no facial
   identification.
5. Return `{ ok: true, reply_text: "<answer>" }`. WF-01 sends.
   WF-08 has **no** Telegram node.

**Known characteristic (packet 3.11) — no relevance floor.**
`Retrieve corpus` orders by trigram-hit DESC then `occurred_at` DESC
with LIMIT 80, and has no relevance floor. While any interaction exists
the corpus is never empty, so the `The corpus has nothing. Do not guess.`
sentinel can never fire, and an off-topic question still ships 80 real
rows to the model. Acceptable at launch scale and within the merged spec.
A confident answer to an unsupported question is not a retrieval success.
Observed 27 Aug 2026: Compose context `row_count` was **10** on every
WF-01 `/ask` that retrieved (255773, 255781, 255786, 255800, 255806) —
the full interaction corpus, not a filtered subset.

**`want_contact` (packet 3.11).** `Guard extra fields` uses
`/(email|e-mail|phone|mobile|cell|tel|جوال|هاتف)/i` — no backslash
escapes in the stored jsCode. Over-matching (`telephone` matching `tel`)
is a phone question and is acceptable. Under-matching was the defect.

**No vector store at launch.** pgvector is Phase 6.

**Must not:** log the raw question if it contains an email or phone
(redact before any audit write; audit is optional and not required
for `/ask`); confabulate; auto-merge; call WF-06.

---

## WF-09 — Watchdog

**Phase 3** · **Triggers:** Schedule `*/15 * * * *` `Asia/Riyadh` +
Execute Workflow Trigger (manual prove)
Workflow ID: `<WF-09_WORKFLOW_ID>`. Never commit the literal.
Settings: `availableInMCP: true`, `errorWorkflow` = LNI WF-00,
`executionTimeout: 300`, timezone `Asia/Riyadh`. Postgres **Leap-NI**.

Launch-blocking. Independent of WF-07. Silent when clean.

### Why this is launch-blocking
The owner chose low-confidence-only notification, which makes the 10 PM digest
the single point of failure detection. If that digest does not fire on the 31st,
there is no signal at all until the owner goes looking. **This workflow exists
specifically to cover that gap and must not be cut when Phase 3 is squeezed.**

### Staleness clock

Measure from `processing_jobs.last_transition_at`, **never**
`created_at` (migration `010`, architecture.md §4). A job healthily
in a retry window is not stale.

### Backoff (named Phase 3 item)

WF-03/04/05 requeue to `queued` with **no Wait** inside the 300 s
execution. **The delay is the worker claim**, not WF-09. Do not
tight-loop. Do not add a Wait inside the workers.

**The 20 minutes is deleted.** Claim bumps `attempt_count`, so a job
is claimed at 1, 2, 3 and failed at 3 — exactly two waits. A third
delay is unreachable under a 3-attempt ceiling. The ceiling stays 3
because a job that has failed twice at a four-day event is a poison
job and belongs in the watchdog alert, not in a third retry. Delays
are 1 and 5. Recorded the same way `rules.md` §7 rule 14 was
recorded, not quietly dropped.

WF-09 is the **kicker** for missed initial dispatch (attempt 0 sitting
`queued` because Call WF-03 never ran), stuck `running`, and
post-event quiet. It is not the delay. WF-09-only backoff is
bypassed by WF-02 `/done` and sweep, which claim through the worker.

### Orphan-asset reconciler (GATE-FIX)

Store-first vs `/done` is a race: Action done can close a capture
while Insert asset has not committed. The asset lands `stored`, the
capture is already `processing`, and no `processing_jobs` row exists.
Capture #77 is that row. **Do not** try to make `/done` win the race.

On every WF-09 tick, **in parallel with Scan findings** (fan-out
from Mint correlation — existing stuck-job / poison-job / alert
paths stay untouched):

1. **Enqueue orphan jobs** — the **same** `INSERT … SELECT … ON
   CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL DO
   NOTHING` natural key as WF-02 `Enqueue asset jobs`. Audio →
   `transcription`; else → `card_vision`. The SELECT is the
   backstop predicate, not `closed_ids`:

   ```
   assets.upload_status = 'stored'
   AND captures.status IS DISTINCT FROM 'open'
   AND NOT EXISTS (processing_jobs row for that asset_id)
   ```

   Owner-scoped. `alwaysOutputData: true`. Zero rows is a normal
   silent terminal — not an error, not an alert.
2. **Gate** on `RETURNING id` notEmpty (same shape as WF-02
   `Gate: jobs enqueued`).
3. **Call WF-03 once** if any row inserted. `waitForSubWorkflow:
   false`, `onError: continueRegularOutput` explicit. Enqueue is
   durable; dispatch is not. A throw must not fail the watchdog.

Do not INSERT jobs from SQL outside this node. Proof is capture
#77 going `jobs=0` → a `card_vision` row on a WF-09 execution,
then `processing` → `ready`. A later clean tick must enqueue
nothing.

Worker claim predicate (implement on WF-03/04/05 in packet 3.4; do
not edit those workflows in packet 3.3):

```
status = 'queued'
AND attempt_count < 3
AND (attempt_count = 0
     OR last_transition_at < now() - (CASE attempt_count
          WHEN 1 THEN interval '1 minute'
          ELSE interval '5 minutes' END))
```

WF-09 dispatch eligibility (so it does not waste kicks):

| `attempt_count` | When WF-09 may kick |
|---|---|
| 0 | `last_transition_at` older than 1 minute (missed initial dispatch) |
| 1 | older than 1 minute |
| 2 | older than 5 minutes |
| ≥ 3 | **do not dispatch.** If still `queued` or `running`, `UPDATE` to `failed` and include in the alert |

`running` older than **10 minutes** (2× `executionTimeout` 300 s) and
`attempt_count < 3`: `UPDATE` status back to `queued` (status change
refreshes `last_transition_at`; do not bump `attempt_count` here —
the worker claim does that). Then it is eligible on the next tick
after the delay for its count.

### Scan (one Leap-NI query)

Owner from self-id. Return json counts + sample ids (job `id`,
`job_type`, `status`, `attempt_count`, capture `capture_no` only —
no PII):

1. Non-terminal jobs (`queued` / `running`) past the backoff (or the
   10-minute running rule).
2. Closed captures (`closed_at` not null, older than 15 minutes,
   `status = 'processing'`) with **at least one** `processing_jobs`
   row and **no** `extraction_runs` row. **Zero-job Phase 1 leftovers
   (including capture #9) are out of scope.** Do not alert on them.
   Do not backfill. Do not delete #9.
3. `assets.upload_status != 'stored'`.
4. `processing_jobs.status = 'failed'` with `last_transition_at`
   in the last 24 hours (surface poison jobs).

Zero findings → silent NoOp terminal. Do not send. Do not email.

### Dispatch (best-effort, not the alert)

If any `queued` row is eligible under backoff:

- `job_type` in (`card_vision`, `transcription`, `photo_description`)
  → **one** `Call WF-03`.
  The CHECK constraint allows `photo_description`. No job of that
  type has ever been created. Absence in live data is not a bug.
  WF-09 still lists it so a future enqueue is dispatchable; WF-01–05
  do not write it.
- `extraction` → **one** `Call WF-04`
- `entity_resolution` → **one** `Call WF-05`
- `enrichment` → **do not call WF-06**

Input contract matches the workers: `owner_id`, `correlation_id`
(Crypto uuid on this execution). `waitForSubWorkflow: false`.
`onError: continueRegularOutput` explicit. Workers claim from
Postgres. One call per worker, not per job.

Publish-order: WF-03/04/05 are already active. Do not deactivate them.

### Alert (independent of digest)

If any finding is non-zero: compose a short text (counts + up to 10
`capture_no` / `job_type` lines). Telegram `parse_mode` is **HTML**
explicit — default Markdown treats `_` in `failed_24h` as an unclosed
italic (`can't parse entities`). Email still delivers in that case;
set HTML anyway so Telegram is not a paper tiger. `Compose findings`
HTML-escapes `&` then `<` then `>` into `telegram_text`; Gmail keeps
plain `reply_text`. Then the **standard scheduled-send
topology** (packet 3.6, same as WF-07): fan-out, parallel Telegram +
Gmail, Merge after both attempts, delivery proven by Telegram
`message_id` or Gmail `id` — never by "the node ran". `stopAndError`
only when both channels are empty or both failed. Empty `chat_id` is
not fatal if email is present.

**WF-09 MUST use this and must not copy WF-07's old serial graph.**
Email exists to survive a Telegram-specific death, and serial wiring
makes email depend on the thing it insures against. WF-09's whole job
is to speak when the normal path has gone quiet.

`source` is always schedule or manual prove — WF-09 is never called
by WF-01, so it always sends itself when dirty.

### A2. `needs_review` is not a watchdog finding

The scan list above is exhaustive. `processing_jobs.status = 'needs_review'`
is **not** a finding. The digest's unreviewed count already covers it.
Live entity_resolution rows at `needs_review` (captures 59, 62, 63) must
not make the first tick loud. Do not add a fifth kind. Do not "helpfully"
include them.

### A1. Alert-storm suppression (fingerprint, not n8n state)

The Phase 2 deliberate forced-failure job (`transcription` / `failed` /
`attempt_count` 3 / capture #36) sits inside the 24-hour failed window
until `last_transition_at + 24h`. Do **not** touch that row, requeue it,
or retarget it. Under the scan alone, a 15-minute cron would re-alert
that unchanged set until it ages out (~56 messages). The owner would
mute the watchdog and it would protect nothing.

**Mechanism.** Fingerprint the finding set in the **same** Leap-NI scan
query. Canonical identity tuples, sorted, `md5` of the joined string —
not counts. A different job with the same counts is a different set.

Tuple format (no PII):

```
kind|capture_no|id|job_type|status|attempt_count
```

`kind` is one of `stuck_queued`, `stuck_running`, `ceiling_failed`,
`failed_24h`, `leftover_processing`, `asset_not_stored`. Job findings
use `processing_jobs.id`. Leftover uses `captures.id`. Assets use
`assets.id`. `needs_review` is never in the set.

On **successful** delivery (Any delivered? true), INSERT `audit_log`:

- `actor_type = 'system'`
- `action = 'watchdog_alert'` (no CHECK on `action`; do not invent a
  migration)
- `entity_type = 'watchdog'`
- `after = { fingerprint, finding_count }` — no chat_id, no email, no
  names, no transcripts
- `correlation_id` = this tick's Crypto uuid (`$execution.id` is not a
  uuid)

Lookup the latest `watchdog_alert` for this `owner_id` (named Postgres
node, `ORDER BY created_at DESC LIMIT 1`). Suppress the send when:

1. `finding_count > 0`, and
2. `after.fingerprint` equals this tick's fingerprint, and
3. that row's `created_at` is within **N = 6 hours**

Escalate immediately when the set **changes** (a new tuple appears, one
drops, or a field in a tuple changes) even inside N. Empty findings do
not write an "all clear" row — zero findings → Silent clean NoOp, no
audit write.

Do **not** write the fingerprint if both channels fail. The next tick
must retry the send.

**N = 6 hours.** 15-minute ticks × 6 h = 24 suppressed repeats of an
unchanged set, so at most four identical reminders per day. 24 h would
go quiet until the next calendar day — too long for a watchdog whose
job is to speak when the digest is silent. 1 h is still ~10 overnight
messages of the same poison job. 6 h leaves a midday reminder and
keeps packet C3 (two dirty runs minutes apart) suppressed. State lives
in Postgres. Never `$getWorkflowStaticData`. Never n8n staticData.

Dispatch is independent of suppression. A suppressed tick still kicks
eligible `queued` workers and still marks `attempt_count >= 3` failed.
The alert is what is suppressed, not the kicker.

**Must not:** log PII; rewrite vision job `1564abc3`; auto-merge;
delete capture #9; call WF-06; tight-loop dispatch of `attempt_count
>= 3`; mutate the Phase 2 forced-failure transcription job.

---

## WF-10 — Follow-up drafting

**Phase 7** · **Triggers:** Manual + Execute Workflow Trigger **only**.
No Telegram trigger. No Schedule. **INACTIVE** for packets 7.1–7.3.
Do not `POST /activate`. Do not send `active` on a PUT. WF-01 is
**not** called and **not** edited in this packet.

Settings (REST PUT after MCP create — create is not evidence):
`availableInMCP: true`, `errorWorkflow` = LNI WF-00
(`X7zKL3wTFPIhwyaN`), `executionTimeout: 300`,
`timezone: Asia/Riyadh`, `callerPolicy: workflowsFromSameOwner`.
Strip `binaryMode` and `timeSavedMode` from any public PUT.

Credentials (REST PUT, never ElderWise): Postgres **Leap-NI**,
Gmail (same OAuth as WF-07/09), OpenAI **OpenAi account**, HTTP
**Supabase_Leap-NI** on the attachment GET (bucket prefix +
`storage_path`). First execution is self-identifying:
`SELECT name FROM public.events WHERE name = 'LEAP 2026'`.

**Input** (Execute Workflow Trigger): `owner_id`, `correlation_id`,
`source` (`command` \| `voice` \| `callback`), `text` (command),
`callback_data` (callback, `f7:` prefix), `file_id` (voice).
**Return contract:** `{ ok, reply_text, reply_text_2?, reply_markup? }`.
Empty `reply_text` is a defect.

**Packet 8.5 — confirm card order.** Compose confirm is
To / CC / Subject, blank, body, blank, Attachments, then
`Could not match:` only when unmatched is non-empty. Rollback
`b9a5a890`. Live `2b6580b8`. The unmatched `photo` line on the
owner card (exec **276473**) is Parse extract, not the model;
that cause is reported, not fixed in this PUT.

**Does not Call WF-03.** Whisper (language **absent**) lives on
WF-10 so a follow-up brief never claims a capture transcription
job. Does not rewrite `interactions.summary`. Does not alter
WF-07 SQL. Does not GRANT SELECT.

Every Postgres node: `alwaysOutputData: true`, `retryOnFail: true`,
`replaceEmptyStrings: false`, `queryReplacement` = **one** array
expression. Gate `id` notEmpty after every INSERT/UPDATE/lookup.
`count(*) OVER()::int AS hit_count`. `.first()` after any Merge.
`stopAndError` messages: no comma, quote, or apostrophe.

### Node graph (as built, packet 7.3b)

The 7.3 attachment path was reported as built while
non-functional (uuid URL, Gmail with no attach parameter, silent
1-file cap). 7.3b rebuilds that path on real objects. WF-10 stays
INACTIVE. `source=voice` is a non-functional stub pending 7.4.
`follow_ups` `a7596fde-47be-425b-bde5-5a9343804ee0` was a leftover `awaiting_confirm` draft from a pinData attempt that still ran OpenAI on the subworkflow; cancelled, not evidence.

**Shared head**

1. **Manual Trigger** and **When called** (executeWorkflow) both
   feed **Self identify**.
2. **Self identify** — Postgres
   `SELECT name, owner_id FROM public.events WHERE name = 'LEAP 2026' LIMIT 1`.
   `executeOnce: true`.
3. **Row returned?** — `name` equals `LEAP 2026`, strict. False →
   **Wrong database terminal** (`stopAndError`:
   `Wrong database LEAP 2026 row missing`).
4. **Normalize input** — Code. Named-node source. Copies
   `source`, `text`, `callback_data`, `file_id`, `owner_id`,
   `correlation_id` from **When called** when executed, else from
   the manual item. No backslash regex.
5. **Route source** Switch: `command` \| `voice` \| `callback`.
   Fallback → **Unknown source terminal** (`stopAndError`:
   `Unknown followup source`). After any append, re-GET every
   connection index.

**Command path**

6. **Parse argument** — Code. Strips a leading `/followup` token
   (and an `@bot` suffix on that token) by `split(' ')`. `name` =
   first remaining token; `brief` = the rest joined. No `\\`
   regex.
7. **Usage?** — `name` empty AND `brief` empty. True →
   **Compose usage** (`Usage: /followup <name or email>`) →
   **Return to caller**.
8. **Lookup people** — same ladder as WF-01 Flag lookup: exact
   `email_normalized`, then exact `full_name` case-insensitive,
   then trigram `similarity >= 0.4`. Max 5.
   `count(*) OVER()::int AS hit_count`.
9. **Lookup returned?** — named `id` notEmpty. False →
   **Compose no match** → Return.
10. **Flag many?** — `hit_count` number `gt` 1, **strict**. True →
    **Compose many** (inline buttons `f7:p:<person uuid>`,
    `<name> (no email)` when email is null) → Return. NEVER guess.
11. **Has email?** — `email_normalized` notEmpty. False →
    **Compose no email**
    (`<name> has no email. Capture a card with an address first.`)
    → Return.
12. **Need voice wait?** — `brief` empty AND `source` equals
    `command`. True → **Insert awaiting voice** (`draft_state='awaiting_voice'`,
    `status='open'`, `title='Follow-up'`, `person_id` set when
    known) → **Set bot await** (`awaiting_followup_id`,
    `awaiting_followup_until = now() + 15 minutes`) →
    **Compose record now**
    (`Record a voice note now (15 min). A photo still goes to capture.`)
    → Return. `person_id` may be non-null here; the PARTIAL CHECK
    only requires it on `awaiting_confirm`.
13. **Load candidate assets** — owner-scoped, `upload_status='stored'`,
    `kind IN ('photo','selfie')`, capture linked via
    `interactions` for this person, newest first, cap 3. Size cap
    18 MB: drop largest first; omitted names travel as
    `omitted_names`. Live finding 28 Aug: the set was **empty**
    for every person until packet 7.3b linked capture #54 to the
    prove person. Cap 3 here, not at send.
14. **Load owner cc** — `auth.users.email` for the events owner
    (same join WF-07 uses). Named node.
15. **Whisper?** — `source` equals `voice`. True → **Transcribe**
    OpenAI audio, `language` **absent**. False → skip.
16. **Extract draft** — OpenAI `gpt-4o-mini`, `temperature: 0`,
    Responses JSON schema `wf10-v1`. Fields: `recipient_ref`,
    `agreed`, `send_what`, `deadline`, `subject`, `body`. All
    strings; no “return null”. System prompt: address the person
    by the supplied `full_name`; never bracketed placeholders.
    Do not write the transcript to `audit_log`.
17. **Parse extract** — Code. Unwraps the live OpenAI Responses
    envelope (`output[0].content[0].text` object). Empty
    `subject` or `body` → `stopAndError`
    (`Extract returned empty subject or body`). If subject or
    body contains both `[` and `]` →
    `Extract returned bracketed placeholder`. System prompt
    binds supplied `full_name` in the salutation and forbids
    bracketed placeholders; the guard is enforcement.
    Sentinel `deadline = none mentioned` maps to SQL NULL in the
    write, not in the model.
18. **Insert draft** — `draft_state='awaiting_confirm'`,
    `status='open'`, freeze `to_email` (person
    `email_normalized`), `cc_email` (owner `auth.users.email`),
    `subject`, `body`, `attachment_asset_ids`, `confirm_expires_at`,
    `prompt_version='wf10-v1'`, `title` = subject.
    `due_at = NULLIF($4::text, '')::timestamptz` (empty string
    cannot be bound as timestamptz). `RETURNING id`.
19. **Draft row returned?** False → `stopAndError`
    (`Draft insert returned no row`). True →
20. **Compose confirm** — plain text, owner-read order (packet 8.5):
    To / CC / Subject, blank line, body, blank line,
    `Attachments: <filenames or (none)>`, then
    `Could not match:` only when unmatched is non-empty, then
    `Omitted (too large):` only if a size drop happened.
    `reply_markup` buttons: `f7:s:<id>` Send,
    `f7:n:<id>` Send without attachments, `f7:x:<id>` Cancel.
    → **Return to caller**.
    `parse_mode` is absent on WF-01 sends; WF-10 returns **plain
    text** (no HTML entity escaping). Real newlines.

**Voice path** (`source=voice` is a non-functional stub pending 7.4)

21. **Load await** — both IF outputs compose no-await. Do not
    treat this as a voice-path proof. Transcribe is not reachable
    from `source=voice`. Nothing fetches a Telegram file.
22. Then **Transcribe** → **Extract draft**. If the awaiting row
    has `person_id`, skip the ladder and continue from **Has
    email?** using that id. If not, ladder on `recipient_ref`.
    `"none named"` and empty →
    **Compose nobody named** (`No person named. Try /followup <name or email>.`)
    → Return.

**Callback path**

23. **Parse callback** — Code. `f7:` prefix. Kinds: `p` pick,
    `s` send, `n` send-none, `x` cancel. No backslash regex.
24. **Route callback** Switch. Fallback →
    **Unknown callback terminal**.
25. **Pick person?** `f7:p:` → **Load picked person** by id
    (no re-guess) → **Has email?** (same gate as command). A
    no-email pick composes the no-email text and does not draft.
26. **Cancel?** `f7:x:` → UPDATE `draft_state='cancelled'`,
    `status='cancelled'` WHERE `awaiting_confirm` RETURNING.
    Gate. **Clear await**. Reply `Cancelled.`
    Compose already: `cancelled` → `Cancelled.`; `failed` →
    failed text (Gmail or attachment failure only).
27. **Claim send** — `f7:s:` keeps listed attachments; `f7:n:`
    sets `attachment_asset_ids='{}'` on the claim. SQL:

    ```
    UPDATE follow_ups
    SET draft_state = 'sending'
    WHERE id = $1
      AND owner_id = $2
      AND draft_state = 'awaiting_confirm'
      AND confirm_expires_at > now()
      AND to_email IS NOT NULL
    RETURNING id, to_email, cc_email, subject, body,
              attachment_asset_ids,
              coalesce(array_length(attachment_asset_ids, 1), 0)::int
                AS attachment_count,
              person_id,
              attachments json (each: id, storage_path, filename,
                size_bytes) joined from public.assets in array order.
    ```

    `alwaysOutputData: true`. Gate RETURNING `id` notEmpty.
    Zero-row UPDATE is `{success:true}` — without the gate Gmail
    fires on a stale or double tap.
28. **Claimed?** False → **Load draft state** → compose
    `Already sent.` / `Cancelled.` /
    `This draft expired. /followup again.` /
    `Send already in progress.` → Return.
29. **Need files?** `attachment_count` number `gt` 0, strict.
    True → **GET attach 0/1/2** HTTP Storage `responseFormat: file`,
    `outputPropertyName` `attach_0` / `attach_1` / `attach_2`,
    URL = bucket prefix + that row's `storage_path`. `neverError`
    absent. `fullResponse` true. Gate statusCode 200 and
    Content-Length > 0. Any fail → **Mark failed**, Gmail does
    **not** run, reply
    `Could not attach <filename>. Draft kept. Try again or Cancel.`
    No 1-file cap. Cap 3 is on **Load candidate assets**.
    False → Gmail with no attachments (send-none or empty set).
30. **Gmail send** — To = frozen `to_email`, CC = frozen
    `cc_email`, subject, body.
    `options.attachmentsUi.attachmentsBinary[0].property` =
    comma-separated `attach_0`… keys actually downloaded.
    `retryOnFail: true` once. Do **not**
    set `onError: continueRegularOutput`. Credential = WF-07 Gmail.
31. **Gmail id present?** `.first()` `id` notEmpty. False →
    **Mark failed** (`draft_state='failed'`, `status` stays
    `open`) → compose
    `Gmail refused the send. Draft kept. Try later or Cancel.`
    → Return.
32. **Mark sent** — UPDATE `draft_state='sent'`, `status='done'`,
    `gmail_message_id`, `sent_at=now()` WHERE
    `draft_state='sending'` RETURNING.
33. **Sent row returned?** False → `stopAndError`
    (`Sent mark returned no row`) — Gmail may have sent; do **not**
    send again; WF-00. True →
34. **Write audit** — `actor_type='user'`, `action='followup_sent'`,
    `entity_type='follow_up'`,
    `after = {follow_up_id, person_id, gmail_message_id, attachment_count}`.
    **No email, no body, no transcript.**
35. **Clear await** — `bot_state.awaiting_followup_id` / `_until`
    null where they point at this draft.
36. **Compose sent** — plain text
    `Sent to <name> <email>. Subject: … Files: …`
    → **Return to caller**.

**Must not:** activate this workflow; Call WF-01; Call WF-03;
touch WF-01 Route type; send to a production contact during
prove (To = owner address); auto-send without the claim SQL;
log PII; alter `follow_ups_status_check`.

---

## 3. Build and verification order

| Order | Workflow | Verify by |
|---|---|---|
| 1 | WF-00 | Force an error; confirm redacted write, no secrets |
| 2 | WF-00b | Self-identifying execution on both branches; live JSON `errorWorkflow` + `availableInMCP` |
| 3 | WF-01, WF-02 | 20 real-device captures, 100% asset preservation |
| 4 | WF-03, WF-04 | Live JSON read-back for unset `language`; envelope keys; extraction_runs row |
| 5 | WF-07, WF-08, WF-09 | Observed execution `startedAt` in Riyadh; `/digest` and `/ask` on the production bot; watchdog silent when clean and loud when a TEST-stuck job is planted then restored |
| 6 | WF-06 | Forced retry loop must not breach the credit ceiling |
| 7 | WF-10 | Inactive. Self-id LEAP 2026. Command confirm `(none)` attachments. Gmail To+CC owner address. Double send does not send twice. WF-01 versionId unchanged. |

**Verification is by read-back, never by report.** The architect reads live
workflow JSON through MCP and compares against this document. Cursor's summary
is an input, not evidence.
