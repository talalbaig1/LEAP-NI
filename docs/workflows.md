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
| Empty result guard | Explicit gate before any send node | Postgres emits `{success:true}` when an UPDATE matches zero rows, which crashes downstream sends |
| Who decides what the owner is told | **WF-02 decides; WF-01 only sends** | WF-01 never re-derives a condition WF-02 has already evaluated. `reply_text` non-empty means send; empty means stay silent. Do not add a second field (`adopted`) that must stay in agreement with `reply_text` — that is the same bug waiting to recur. Verified 26 Aug 2026 (exec 245471: Compose dropped `adopted`; WF-01 tested a field that never arrived). |
| Configuration source | Postgres, never `$env` | `$env` is blocked instance-wide, and configuration outside Postgres violates architecture.md §2 rule 2 regardless. |
| Runtime identifiers | Postgres or gitignored local config | Repo is public. Never commit a Telegram user ID, project ref, owner UUID, key, or connection string. Placeholders in committed files; real values only in gitignored `docs/environment.local.md`. |
| `binaryMode` | `"separate"` (workflow `settings`) | JSON and binary stay on separate item properties. Required for Telegram download → sha256 → Storage PUT. Undocumented defaults cannot be verified by read-back. Set explicitly on every LNI workflow that handles files (WF-00 / WF-00b / WF-02 already have it; WF-01 must too). |

### Four traps already identified

**Never set `language` on a transcription node.** ElderWise WF-5 hardcodes
`language: "en"`. Forcing English decoding on Arabic or code-switched audio
produces confident garbage rather than an error.

**Never inherit cron timezone.** If the container runs UTC, a 7 AM briefing
fires at 10 AM Riyadh — after the owner has left for the venue, making it
worthless. One line, classic silent failure.

**Never trust MCP credential auto-assignment.** Observed 25 Aug 2026: creating
an LNI workflow through the n8n MCP interface returned
`autoAssignedCredentials: ElderWise Supabase (Postgres)` — n8n reached for an
existing credential by name similarity. Reading the live workflow JSON back
showed *no* credential bound at all, so the creation response and the saved
state disagreed outright.

Two consequences, both binding:

1. **Bind every LNI credential explicitly in the n8n UI**, then confirm by
   read-back before the first execution. Never accept the creation response as
   evidence.
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
| WF-03 | Asset processors | 2 | Called by WF-02 |
| WF-04 | Structured extraction | 2 | Called by WF-03 |
| WF-05 | Entity resolution | 2 | Called by WF-04 |
| WF-06 | Enrichment | 4 | Called by WF-05 / `/flag` |
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

**WF-01 is the only workflow that sends Telegram.** WF-02 never does.
If storage failed, WF-01 sends nothing — that invariant lives in one place.

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
5. **Branch:** command | photo | voice/audio | document/video | text | callback.
   Commands are `text` starting with `/` and win over the text branch.
6. **COMMANDS** (`/new`, `/done`, `/batch`, `/status`; `/start` maps to
   `status`). Strip a trailing `@botname`. Call WF-02 with the contract
   payload (`owner_id`, `telegram_user_id` from the allowlist row, `action`,
   `correlation_id`). Send `reply_text` (and `state_echo` only when
   `reply_text` is empty and `state_echo` is not). **Commands never touch
   Storage.** Gate: do not send if WF-02 `ok` is false or `reply_text` /
   `state_echo` is empty.
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
8. **TEXT:** if it starts with `/ask`, terminate as out-of-scope for Phase 1
   (WF-08 is Phase 3) — no reply. Otherwise `resolve_target`, then append to
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
| Unknown type terminal | Update is none of command/photo/voice/document/text/callback |
| Command sent / Media stored / Note done | Happy path |

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
Replaying the 41 already-captured assets later is **one INSERT**, not 41
workflow calls.

1. Close. `Action done` sets `status` to leave `open`,
   `close_reason = explicit`, and **RETURNs the `id` of every capture it
   closed**. Batch `/done` closes every open `capture_mode='batch'` row
   for the owner (many ids). Standard `/done` returns one. If nothing is
   open, zero rows → `reply_text` = `nothing open`. No crash, no phantom
   row. Batch also sets `bot_state.mode = normal`.
2. Enqueue — **one** statement:

   ```sql
   INSERT INTO processing_jobs (owner_id, capture_id, asset_id, job_type, status)
   SELECT a.owner_id, a.capture_id, a.id,
          CASE WHEN a.kind = 'audio' THEN 'transcription'
               ELSE 'card_vision' END,
          'queued'
   FROM assets a
   WHERE a.capture_id = ANY(<closed_ids>)
     AND a.upload_status = 'stored'
   ON CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL DO NOTHING;
   ```

   Natural key: unique index **`processing_jobs_asset_job_uniq`** on
   `(asset_id, job_type) WHERE asset_id IS NOT NULL`
   (`architecture.md` §4). Audio → `transcription`; everything else →
   `card_vision`. A re-run enqueues nothing twice. The index is created
   in the WF-02 enqueue packet, not in 014/015.
3. **Explicit gate on rows returned**, then **ONE** `executeWorkflow`
   call to WF-03 with `waitForSubWorkflow: false`. Replaces the NoOp
   node **"WF-03 dispatch (not yet)"**. Do not call WF-03 per asset. A
   re-run that enqueues nothing (all conflicts) does not fire WF-03
   again — the jobs are already in Postgres.
4. Receipt. Standard: `✓ Capture #<capture_no> saved · <n> items` using
   `captures.capture_no` and the Postgres asset count (`asset_count_hint`
   never populates `<n>`). Batch: **`N cards received · processing`**.
   Extraction has not run at this instant, so clean / need_review /
   failed **cannot** be true here — Compose currently hardcodes those as
   0. Real counts are deferred to the digest (`prd.md` §5).

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
- Close every capture with `status='open'` whose `bot_state.last_activity_at`
  is older than the inactivity window, stamping `close_reason='auto'`.
  `status` leaves `open` so a later sweep does not re-close. Clear
  `bot_state.open_capture_id`. Send nothing. No `reply_text`.
- **Inactivity window: 10 minutes** (`prd.md` §4 guardrail 2). Stored as a
  documented constant in the sweep SQL (`interval '10 minutes'`), **not**
  in `$env` (denied instance-wide) and not as a new `events` column (no
  extra migration in this packet).
- Schedule stays **inactive until WF-01 is published**. Packet 1.3 publishes
  WF-02 first because this n8n instance will not activate a parent that
  calls an unpublished sub-workflow.

### Guardrails
- **Implicit close on `/new`** — see above.
- **Inactivity auto-close** — sweep above.
- **Orphan adoption** — `resolve_target` above. **Never reject.**
- **State echo:** every non-sweep return includes current state, using
  `captures.capture_no`, never the uuid.

---

## WF-03 — Asset processors

**Phase 2** · **Trigger:** called **once** by WF-02 `/done` (`waitForSubWorkflow:
false`). Postgres is the queue — WF-03 claims `processing_jobs` rows with
`status='queued'`. Do not require a per-asset payload; a kick with
`owner_id` is enough. Reject unknown extra fields if a payload is sent.

WF-03 assigns `assets.kind` from **one** vision call per image. Capture-time
kind is Telegram media type only — live, all 34 image assets sit at
`kind='photo'`, so a `business_card` branch would never fire
(`architecture.md` §4).

1. Claim a `processing_jobs` row already enqueued by WF-02 `/done`
   (`status='queued'` → `running`); increment `attempt_count`. Do not
   INSERT a second job for the same `(asset_id, job_type)`.
2. Generate a **short-lived signed URL**. Never make the bucket public. Never
   log the URL.
3. Branch on capture-time `assets.kind`:

   **`audio`** — Whisper transcription. **`language` unset.** Store the
   verbatim transcript in `extraction_runs.raw_transcript` regardless of
   quality.

   **Everything else (image, including live `photo`)** — **one** vision
   call whose strict schema includes `image_type`:
   `business_card | scene | other` (`architecture.md` §6). **No
   OCR-then-parse step.** WF-03 then `UPDATE`s `assets.kind`
   (`business_card` → `business_card`; `scene`/`other` → `photo`). Store
   the raw provider response in `extraction_runs.raw_vision_output`. A
   `scene` image gets contextual description only — **no facial
   recognition, no identification of people** (`rules.md` §7 rule 13).

4. Validate against the versioned schema.
5. On transient error: exponential retry (1, 5, 20 min; max 3), then `failed`.
   On malformed content: `needs_review`. **Never silently drop.**
6. When all sibling jobs for the capture reach a terminal state — or a 15-minute
   timeout elapses — dispatch WF-04.

---

## WF-04 — Structured extraction

**Phase 2** · **Trigger:** called by WF-03

1. Compose explicit sources: typed note, card JSON, transcript, photo
   description. Label each so provenance survives.
2. Call the LLM with a **strict JSON schema**, `temperature: 0`. No free-form
   parsing of prose.
3. Extract: people, companies, roles, summary, topics, opportunities,
   follow-ups.
4. Validate. **Reject any invented email, phone, domain, or date not supported
   by source evidence.**
5. **Apply rule-based flagging** (`architecture.md` §6). Set
   `extraction_runs.flag_reasons`.
6. Write an `extraction_runs` row — immutable evidence.
7. Dispatch WF-05.

**Must not:** overwrite any field present in `field_corrections`. User
corrections are canonical.

---

## WF-05 — Entity resolution

**Phase 2** · **Trigger:** called by WF-04

1. **Candidate retrieval,** in order: exact normalized email → exact LinkedIn
   URL → exact phone → company domain → fuzzy name + company.
2. **Deterministic scoring.** Exact email or exact LinkedIn dominates. Matching
   company plus normalized name supports but does not decide.
3. **Auto-link only** on exact normalized email or exact LinkedIn URL.
   **Name similarity never auto-merges** — at an event with a high density of
   shared family names this would quietly corrupt the dataset, and quiet
   corruption is worse than a visible gap.
4. Otherwise write a scored suggestion to `entity_candidates` with **visible
   reasons**.
5. Upsert `people`, `companies`, `person_companies`, `interactions`. Preserve
   `name_original_script`.
6. Set capture status `ready` or `needs_review`.
7. **Notify the owner only if flagged.** Otherwise stay silent — the digest
   handles it.
8. If Phase 4 is live and a company domain is present, dispatch WF-06.

---

## WF-06 — Enrichment

**Phase 4** · **Trigger:** called by WF-05, or by `/flag`

### Credit guard — runs first, always
1. Sum today's `credit_ledger` spend.
2. **If at or above the daily ceiling, stop.** Log and alert. Do not call the
   provider.

A retry loop burning 175 non-refundable credits at midnight is an entirely
plausible failure, and this guard is the only thing standing in front of it.

### Company path (automatic)
3. Derive domain from the card email.
4. Skip if a fresh `enrichment_records` row already exists.
5. Apollo organization enrichment by domain. **One credit covers everyone from
   that organisation.**
6. On no-match: **Tavily fallback** — description and website, written with
   `provider = 'tavily'` and clearly labelled web-sourced. Never conflated with
   Apollo data.
7. Write `enrichment_records` with source, timestamp, confidence. Write
   `credit_ledger`.

### Person path (`/flag` only)
8. Apollo person match. Never automatic.

**Must not:** treat enrichment as user-provided fact. It is always sourced,
timestamped, and separately reviewable.

---

## WF-07 — Digests

**Phase 3** · **Trigger:** two schedules + on demand
**Both schedules explicitly `Asia/Riyadh`**

### 10:00 PM — Day close
Operational. Reports: captured today · clean · flagged · failed · **stuck**.
Plus a list of flagged captures with reasons.

Sent via Telegram **and copied to email** as a durable record independent of
Telegram history.

The **stuck** count is the figure that saves the project — it is how the owner
learns on day one that something is jammed rather than on day four.

### 7:00 AM — Morning briefing
Intelligence. Reports: people met to date · distinct companies · sector
distribution · coverage gaps against target sectors · follow-ups due today ·
unreviewed count.

**This is the highest-value output in the system** — the only thing that changes
how the next eight hours are spent while the event is still running.

It is also the **highest-risk item**, depending on a cron timezone, a query, and
extraction having worked overnight — three things that can each fail silently.
**Test with real data on 29 Aug.**

### `/digest`
Either report, on demand.

---

## WF-08 — Query (`/ask`)

**Phase 3** · **Trigger:** called by WF-01

1. Parse the question.
2. Retrieve owner-scoped candidate records — structured filters plus trigram
   search over `people.full_name`, `companies.name`, `interactions.summary`.
3. Compose context and answer with citations back to capture numbers.
4. **State plainly when evidence is weak.** Never confabulate a contact.

**No vector store at launch.** A few hundred rows fit comfortably in context.
pgvector hybrid retrieval arrives in Phase 6, when the corpus outgrows it.

---

## WF-09 — Watchdog

**Phase 3** · **Trigger:** Schedule, every 15 minutes, `Asia/Riyadh`

1. Find `processing_jobs` in a non-terminal state past a staleness threshold.
   Measure from `last_transition_at`, **never** from `created_at`. That column
   is maintained by a `BEFORE UPDATE` trigger on `status` or `attempt_count`
   changes (architecture.md §4). A job in a healthy WF-03 retry window must
   not trip the watchdog.
2. Find `captures` closed but with no `extraction_runs` after a grace period.
3. Find `assets` with `upload_status != 'stored'`.
4. Alert the owner via Telegram **and** email if any are found. Silent when
   clean.

### Why this is launch-blocking
The owner chose low-confidence-only notification, which makes the 10 PM digest
the single point of failure detection. If that digest does not fire on the 31st,
there is no signal at all until the owner goes looking. **This workflow exists
specifically to cover that gap and must not be cut when Phase 3 is squeezed.**

---

## 3. Build and verification order

| Order | Workflow | Verify by |
|---|---|---|
| 1 | WF-00 | Force an error; confirm redacted write, no secrets |
| 2 | WF-00b | Self-identifying execution on both branches; live JSON `errorWorkflow` + `availableInMCP` |
| 3 | WF-01, WF-02 | 20 real-device captures, 100% asset preservation |
| 4 | WF-03, WF-04, WF-05 | Benchmark; live JSON read-back for unset `language` |
| 5 | WF-07, WF-08, WF-09 | Observed execution timestamps in Riyadh local time |
| 6 | WF-06 | Forced retry loop must not breach the credit ceiling |

**Verification is by read-back, never by report.** The architect reads live
workflow JSON through MCP and compares against this document. Cursor's summary
is an input, not evidence.
