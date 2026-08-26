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
| Postgres queries | Parameterised via `queryReplacement` | Never string-concatenate SQL |
| Idempotency | `ON CONFLICT ... DO NOTHING` on the natural key | ElderWise `media_id` pattern |
| Terminal branches | Explicit NoOp nodes | Makes every path visibly terminal |
| Retries | `retryOnFail: true` on all provider and DB write nodes | — |
| Cron timezone | **Explicitly `Asia/Riyadh`** | Never inherit the container default |
| Empty result guard | Explicit gate before any send node | Postgres emits `{success:true}` when an UPDATE matches zero rows, which crashes downstream sends |

### Three traps already identified

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

---

## 2. Workflow inventory

| ID | Name | Phase | Trigger |
|---|---|---|---|
| WF-00 | Central error handler | 0 | Error trigger |
| WF-00b | Credential and connectivity probe | 0 | Manual trigger |
| WF-01 | Telegram ingest router | 1 | Telegram trigger |
| WF-02 | Capture lifecycle | 1 | Called by WF-01 |
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
3. Write redacted diagnostics. Every handled error **INSERT**s one
   `audit_log` row (`actor_type = system`, `action = workflow_error`). That
   row is the source of truth for repeat detection (architecture.md §2
   rule 2: Postgres holds state; n8n does not). Where a `job_id` is also
   resolvable, additionally **UPDATE** `processing_jobs.error_detail` only —
   do not change `status` or `attempt_count`, so the `last_transition_at`
   trigger does not fire. Recording a diagnostic is not a state transition
   and must not reset the watchdog clock.

   `audit_log.owner_id` is NOT NULL. WF-00 reads the owner UUID **only**
   from the n8n environment variable `LNI_OWNER_UUID` — never from a
   workflow-level constant, and never from a committed file (the repo is
   public, masterplan.md §5). If the value is missing or not a UUID, WF-00
   **throws** rather than skip the write. An error handler that silently
   drops errors is worse than no error handler. A constant fallback would
   mask an unset env var and defeat the throw.

4. Alert the owner via Telegram only on **repeated** failure of the same
   `workflow_name` + `node_name` within 15 minutes. The repeat count is a
   parameterised `SELECT count(*)` on `audit_log` for those keys in the
   window, **after** the current row is inserted. Count 1 = transient, no
   alert. Count ≥ 2 = alert. Do **not** use n8n static data — it is not
   shared across queue workers, is unreliable in manual runs, and is lost
   on reset.

   If the counter says an alert is owed but `LNI_TELEGRAM_CHAT_ID` is
   unset, INSERT a second `audit_log` row with
   `action = workflow_error_alert_undeliverable` before terminating. Do
   not route that case to a silent NoOp. The 10 PM digest must be able to
   see that an alert was owed and not delivered.

5. Retain enough correlation context to replay the job safely.

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

**Phase 1** · **Trigger:** Telegram Trigger

The entry point. Its single most important property: **the raw asset reaches
storage before anything else happens.**

1. **Allowlist check** on `telegram_user_id`. Unknown senders are ignored
   silently — no reply, no row.
2. Parse the update. Branch on type: command · photo · audio/voice · document ·
   text · album member (`media_group_id` present) · callback query.
3. **Commands** → WF-02 with the command name.
4. **Media:**
   a. Extract `file_unique_id`. **Early exit if it already exists in `assets`**
      — Telegram redelivery is normal.
   b. Get file path via `getFile`; download binary.
   c. **Upload to Supabase Storage** (`httpHeaderAuth`, `x-upsert: true`,
      deterministic path `{owner_id}/{capture_id}/{asset_id}-{name}`).
   d. **Only after upload succeeds**, insert the `assets` row with
      `ON CONFLICT (telegram_file_unique_id) DO NOTHING`.
   e. Resolve or create the target capture via WF-02.
5. **Album handling:** buffer members sharing a `media_group_id`. If more than
   two images, send an inline keyboard: *"N images — separate people, or one
   person?"* and hold the assets against a pending capture until answered.
6. **Text** → typed note on the open capture, or `/ask` if prefixed.

**Critical:** if step 4c fails, **no receipt is sent**. Silence must mean
failure. The owner is never falsely reassured.

---

## WF-02 — Capture lifecycle

**Phase 1** · **Trigger:** called by WF-01

Owns `bot_state` and `captures`. Implements the command surface in `prd.md` §4.

### `/new`
1. If an open capture exists, close it (`close_reason = superseded`).
2. Insert a new `captures` row, `status = open`, `event_id` = LEAP 2026.
3. Update `bot_state.open_capture_id`.
4. Reply with the new capture number.

### `/done`
1. Close the open capture (`close_reason = explicit`).
2. Count attached assets.
3. Reply `✓ Capture #47 saved · 2 items`.
4. Dispatch WF-03 for each unprocessed asset. **Do not wait** —
   `waitForSubWorkflow: false`.
5. If nothing is open, say so plainly.

### `/batch`
Sets `bot_state.mode = batch`. Every subsequent photo creates its own capture
with `capture_mode = batch`, marked `card_only`. **Suppresses per-capture
receipts.** `/done` exits batch and sends one closing summary:
*"28 cards processed · 24 clean · 3 need review · 1 failed"*.

### `/status`
Reports the open capture, its item count, and the current mode.

### Guardrails
- **Implicit close on `/new`** — see above.
- **Inactivity auto-close:** a scheduled sweep closes captures idle beyond the
  configured window, stamping `close_reason = auto`.
- **Orphan adoption:** media arriving with no open capture opens one silently
  and tells the owner. **Never reject.**
- **State echo:** every reply includes current state.

---

## WF-03 — Asset processors

**Phase 2** · **Trigger:** called by WF-02 · **Inputs:** `job_id`, `asset_id`,
`capture_id` — reject any other shape

1. Create or claim the `processing_jobs` row; increment `attempt_count`.
2. Generate a **short-lived signed URL**. Never make the bucket public. Never
   log the URL.
3. Branch on `assets.kind`:

   **`business_card`** — single vision call, image → structured JSON per the
   contract in `architecture.md` §6. **No OCR-then-parse step.** Store the raw
   provider response in `extraction_runs.raw_vision_output`.

   **`audio`** — Whisper transcription. **`language` unset.** Store the verbatim
   transcript in `extraction_runs.raw_transcript` regardless of quality.

   **`photo` / `selfie`** — contextual description only. **No facial
   recognition. No identification of people.** Scene and setting only.

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
