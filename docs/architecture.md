# architecture.md

**LEAP Networking Intelligence (LNI)** · Version 2.0 · 25 August 2026

Companion to `masterplan.md`. Workflow-level detail lives in `workflows.md`.

> **Documentation precedes implementation.** Schema or architecture changes are
> recorded here *before* a migration is written. See `rules.md` §1.

---

## 1. System diagram

```text
Telegram (capture surface)
  camera · microphone · albums · offline outbox · automatic retry
        │
        ▼
n8n WF-01 Ingest Router
        │
        ├──► 1. Raw asset → Supabase Storage        ◄── ALWAYS FIRST
        └──► 2. Row → Postgres (captures, assets)
        │
        ▼
Supabase Postgres  ── source of truth
        │
        ├─► WF-03 Asset processors    vision (card→JSON) · Whisper (audio)
        ├─► WF-04 Structured extraction   strict JSON schema, temp 0
        ├─► WF-05 Entity resolution       suggest, never silently merge
        ├─► WF-06 Enrichment (Phase 4)    Apollo company-first · Tavily fallback
        ├─► WF-07 Digests                 10 PM close · 7 AM briefing · /digest
        ├─► WF-08 /ask                    natural-language query
        └─► WF-09 Watchdog                stuck-job detector
        │
        ▼
WF-00 Central error handler ── redacted diagnostics, owner alert
```

---

## 2. Architectural rules

These are invariants. Violating one is a defect regardless of test results.

1. **Store the raw asset before any processing.** Always. Durability precedes
   intelligence.
2. **Postgres is the source of truth.** n8n orchestrates; it never holds state
   between executions.
3. **Every worker call is idempotent** on `asset_id`, `job_id`, or Telegram
   `file_unique_id`.
4. **Provider-specific code sits behind adapters.** Swapping the OCR engine must
   be a configuration change, never a rewrite.
5. **Nothing is silently discarded.** Every capture reaches a visible terminal
   state: `ready`, `needs_review`, or `failed`.
6. **User corrections are canonical** and are never overwritten by a re-run.
7. **All cron schedules explicitly pinned to `Asia/Riyadh`.** Never inherit the
   container default.

---

## 3. Component responsibilities

| Component | Responsibility | Implementation |
|---|---|---|
| Capture surface | Camera, mic, albums, offline queue, retry | Telegram bot |
| Orchestration | Async media pipeline, retries, error routing | n8n (self-hosted) |
| Database | Canonical relational record | Supabase Postgres, new dedicated project |
| File storage | Immutable raw media | Supabase Storage, private bucket `lni-assets` |
| Vision / OCR | Card → structured JSON | Provider adapter; engine chosen by benchmark |
| STT | Voice note transcription | OpenAI Whisper, `language` **unset** |
| Extraction | Normalize into entities | OpenAI, strict JSON schema, `temperature: 0` |
| Enrichment | Company and person context | Apollo (primary) → Tavily (fallback) |
| Monitoring | Failures, stuck jobs, throughput | `processing_jobs` + WF-00 + WF-09 |
| Query | Natural-language recall | WF-08; pgvector added in Phase 6 |

---

## 4. Data model

UUID primary keys. `timestamptz` throughout. `owner_id` and RLS on every
user-owned table — single owner at launch, designed for multi-user.

### Tables

| Table | Purpose | Key columns |
|---|---|---|
| `events` | LEAP 2026 and future events | `name`, `starts_at`, `ends_at`, `location`, `timezone` |
| `bot_state` | Which capture is open; batch mode on/off; **WF-01 allowlist** | `telegram_user_id`, `open_capture_id`, `mode`, `last_activity_at` |
| `captures` | One `/new`…`/done` unit | `event_id`, `capture_no`, `status`, `capture_mode`, `opened_at`, `closed_at`, `close_reason`, `typed_note`, `flags` |
| `assets` | Immutable raw media | `capture_id`, `kind`, `storage_path`, `telegram_file_unique_id`, `sha256`, `mime_type`, `size_bytes`, `upload_status` |
| `processing_jobs` | Auditable async work | `capture_id`, `asset_id`, `job_type`, `status`, `attempt_count`, `last_transition_at`, `provider`, `provider_request_id`, `error_code`, `error_detail`, `output` |
| `extraction_runs` | Immutable model evidence | `capture_id`, `model`, `prompt_version`, `raw_vision_output`, `raw_transcript`, `structured_output`, `flag_reasons` |
| `people` | Canonical person | `full_name`, `name_original_script`, `title`, `email`, `phone`, `linkedin_url`, `review_status`, `source_type` |
| `companies` | Canonical company | `name`, `normalized_name`, `domain`, `industry`, `enrichment_status` |
| `person_companies` | Affiliation history | `person_id`, `company_id`, `role_title`, `is_current` |
| `interactions` | What was discussed | `capture_id`, `person_id`, `company_id`, `occurred_at`, `summary`, `topics`, `opportunities`, `importance` |
| `follow_ups` | Next actions | `interaction_id`, `person_id`, `title`, `due_at`, `priority`, `status` |
| `entity_candidates` | Duplicate suggestions | `entity_type`, `candidate_entity_id`, `score`, `reasons`, `decision` |
| `field_corrections` | User edits, never overwritten | `entity_type`, `entity_id`, `field`, `model_value`, `corrected_value`, `corrected_at` |
| `enrichment_records` | Sourced, timestamped enrichment | `entity_type`, `entity_id`, `provider`, `payload`, `confidence`, `fetched_at` |
| `credit_ledger` | Apollo spend guard | `provider`, `credits_spent`, `operation`, `entity_id`, `spent_at` |
| `audit_log` | Every AI write and user edit | `actor_type`, `action`, `entity_type`, `before`, `after`, `correlation_id` |

**Build the whole schema in Phase 0**, including tables belonging to later
phases. The schema is built once.

**`processing_jobs.last_transition_at`.** `timestamptz NOT NULL`, default
`now()`, maintained by a `BEFORE UPDATE` trigger whenever `status` or
`attempt_count` changes. WF-09 measures staleness from **this column, never
from `created_at`**. A job healthily in its third WF-03 retry (1/5/20 min) at
minute 25 is not stale; a `created_at` threshold under 20 minutes would
false-alarm. The trigger lives in the database so a workflow author cannot
forget to set the column.

**`processing_jobs.error_detail`.** `jsonb`. `audit_log` receives one row for
**every** handled error — that series is what the repeat counter reads. Where
a `job_id` also resolves, this column is updated **in addition**, not instead.
The UPDATE touches `error_detail` only, never `status` or `attempt_count`, so
the `last_transition_at` trigger does not fire and the watchdog clock is not
reset. Not a status vocabulary.

**Seed owner (`009`).** Migration 009 resolves `owner_id` by **explicit email
match**, never by creation order. "Earliest `auth.users` row" is an ordering
heuristic, not a rule: any throwaway account created before the owner silently
becomes the owner of every row in the database, and RLS then locks the real
owner out. Discovered 26 Aug 2026 before seeding.

The owner email is supplied at migration time via the setting
`lni.owner_email` and is **never committed** — the repo is public
(masterplan.md §5). Missing setting, unmatched email, or an unconfirmed
match are hard failures. There is no fallback to earliest row, row-count
heuristics, or a hardcoded UUID.

**`bot_state` is the WF-01 allowlist.** WF-01 admits a sender if and only
if a `bot_state` row exists for that `telegram_user_id`, and reads
`owner_id` from that same row. Unknown senders are ignored silently —
no reply, no row written anywhere. A row must exist before the bot will
respond to anyone. `$env` is denied instance-wide, so configuration
comes from Postgres; `bot_state` already carries `(owner_id,
telegram_user_id)` with UNIQUE, so no separate allowlist table is
justified. LNI WF-00 also resolves the Telegram alert `chat_id` from
this table. Migration `012` seeds the owner row.

### Constraints and indexes

| Constraint | Reason |
|---|---|
| `captures.capture_no` **UNIQUE**, `bigint GENERATED BY DEFAULT AS IDENTITY` | Human-facing number for receipts and `/fix`, `/flag`. Global identity, not per-owner: a per-owner counter would serialise ~30 concurrent `/batch` inserts on one row lock, on the write path that must never fail (`rules.md` §8). Identity gaps on rollback are acceptable; lock contention on capture is not. |
| `assets.telegram_file_unique_id` **UNIQUE** | Telegram's native dedup key — the ElderWise `media_id` pattern |
| Partial unique index on non-null normalized email per owner | Allows duplicates pending review |
| Trigram indexes on `people.full_name`, `companies.name`, `interactions.summary` | Search. **Requires `pg_trgm`.** |
| Index on `processing_jobs (status, last_transition_at)` | WF-09 watchdog query |
| `people.name_original_script` separate from `full_name` | **Never discard Arabic original script.** Transliteration is lossy and is the highest-error surface at this event |
| Merges never cascade-delete raw assets | Replayability |

**Extension prerequisite — verified 26 Aug 2026.** `pg_trgm` is **not**
installed on LEAP-NI. Migration `001` must run
`create extension if not exists pg_trgm` **before** any trigram index is
created. The trigram indexes in this section would fail as written without
that statement.

### Entity-resolution policy

Auto-link **only** on:
- exact normalized email, or
- exact LinkedIn profile URL.

Everything else becomes a scored suggestion in `entity_candidates`, with visible
reasons, awaiting owner approval.

**Name similarity never triggers an automatic merge.** At an event with a high
density of shared family names this would quietly corrupt the dataset —
and quiet corruption is worse than a visible gap.

All merges are reversible, preserve source captures, and write an audit event.

### Status vocabularies

Text columns with `CHECK` constraints. **Not** Postgres enums — enums require
`ALTER TYPE` to extend, and schema changes are forbidden during event week.
These values are cross-workflow contracts; WF-01 through WF-09 all read them.

| Column | Allowed values |
|---|---|
| `captures.status` | `open` \| `processing` \| `ready` \| `needs_review` \| `failed` |
| `captures.close_reason` | `explicit` \| `superseded` \| `auto` |
| `captures.capture_mode` | `standard` \| `batch` |
| `captures.card_only` | boolean, default `false` |
| `assets.kind` | `business_card` \| `audio` \| `photo` \| `selfie` \| `document` |
| `assets.upload_status` | `pending` \| `stored` \| `failed` |
| `processing_jobs.status` | `queued` \| `running` \| `succeeded` \| `failed` \| `needs_review` |
| `processing_jobs.job_type` | `card_vision` \| `transcription` \| `photo_description` \| `extraction` \| `entity_resolution` \| `enrichment` |
| `people.review_status` | `unreviewed` \| `approved` \| `needs_review` |
| `people.source_type` | `card` \| `voice_note` \| `typed_note` \| `photo` \| `enrichment` |
| `companies.enrichment_status` | `none` \| `pending` \| `enriched` \| `no_match` \| `failed` |
| `entity_candidates.decision` | `pending` \| `accepted` \| `rejected` |
| `bot_state.mode` | `normal` \| `batch` |
| `follow_ups.status` | `open` \| `done` \| `cancelled` |
| `follow_ups.priority` | `low` \| `medium` \| `high` |
| `enrichment_records.provider` | `apollo` \| `tavily` |
| `audit_log.actor_type` | `user` \| `ai` \| `system` |

### Asset kind is assigned in two stages

Phase 1 does **not** classify image content. Composition is unpredictable, and
the owner has one hand free — no caption convention, no inline prompt.

At capture time (WF-01) `assets.kind` is the Telegram media type:

- Telegram voice or audio → `audio`
- Telegram photo or image → `photo` (**unclassified** — contents not yet determined)
- Telegram document → `document`

`'photo'` in Phase 1 means "image, contents not yet determined". Phase 2 WF-03
looks at every image in its existing vision call; the output contract gains a
classification field and WF-03 writes the real kind back (`business_card`,
`selfie`, or `photo`). No extra provider call. The existing
`assets_kind_check` already permits all five values — no migration for this.

### RLS policy shape

`owner_id uuid NOT NULL REFERENCES auth.users(id)` is **denormalised onto every
table**, including child and junction tables. A policy predicate must never
require a join.

One policy per table, named `<table>_owner_all`:

```sql
FOR ALL TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid())
```

No policies for the `anon` role. `FORCE ROW LEVEL SECURITY` is **not** used —
n8n's `service_role` must continue to bypass RLS.

---

## 5. Storage design

- Private bucket `lni-assets`. Never public.
- Path convention: `{owner_id}/{capture_id}/{asset_id}-{original_name}`.
- Storage policy: an authenticated user may access only objects whose first path
  segment equals `auth.uid()`.
- Upload via raw REST with `httpHeaderAuth` and `x-upsert: true` — the pattern
  already proven in the owner's n8n instance.
- Downloads use short-lived signed URLs. Signed URLs are never logged.
- Estimated volume: ~2 GB at 350 captures (card ~2 MB + selfie ~3 MB + 30 s
  audio ~250 KB). Likely exceeds a free-tier allowance — verify on creation.

---

## 6. AI contracts

### Card extraction — single call, no OCR step

Card image → strict JSON directly. **No OCR-then-parse pipeline.**

Rationale: a business card is a layout puzzle, not a document. Which string is
the job title versus the company tagline is decided by font size, position, and
proximity to the logo. An OCR pass flattens exactly the signal needed, forcing a
second model to guess it back from a wall of text.

```json
{
  "people": [{
    "full_name": null,
    "name_original_script": null,
    "title": null,
    "email": null,
    "phone": null,
    "linkedin_url": null,
    "company_name": null,
    "evidence": [],
    "confidence": 0
  }],
  "company": { "name": null, "domain": null, "website": null },
  "uncertainties": []
}
```

Nullable fields, never guessed strings. The model must never invent an email,
phone number, domain, or date not present in the source.

### Transcription

OpenAI Whisper. **`language` left unset** — auto-detect. Arabic/English
code-switching is expected and normal. Raw transcript stored regardless of
extraction quality.

### Rule-based flagging

Replaces model self-reported confidence. A capture is flagged when **any** hold:

- No name extracted
- No email **and** no phone
- Non-Latin script present in the name field
- Empty transcript despite audio longer than 5 seconds
- Two or more people detected on one card
- Extraction output fails schema validation
- Capture contains nothing usable

**Rationale:** a vision model is often *most* confident exactly when it is
transliterating an Arabic name wrongly. Self-reported confidence is not a
reliable error filter; observable conditions are.

### Provider benchmark — a Phase 2 deliverable

8–10 representative cards (Arabic-only, bilingual, glossy, dark background,
embossed, bad angle) plus two code-switched voice notes. Score **field-level
accuracy** across GPT-4o vision, Gemini, and Mistral OCR.

The adapter makes the winner a config change. **No provider is chosen on
reputation.** If Mistral wins, Mistral ships.

---

## 7. Enrichment architecture (Phase 4)

**Company-first.** On capture, derive the domain from the card email and enrich
the *company*. One credit covers everyone from that organisation — six people
from stc costs one credit, not six. Company context also answers the question
that actually matters at an event: *is this organisation worth my time?*

**Person on demand only**, via `/flag`.

**Tavily fallback.** Startups and smaller Saudi firms are often absent from
Apollo's index. On a no-match, a web-search pass yields a description and
website — stored with `provider = 'tavily'` and clearly labelled web-sourced,
never conflated with provider data.

**Hard credit guard.** A daily spend ceiling enforced in-workflow, plus a
`credit_ledger` counter independent of Apollo's reporting. A retry loop burning
175 non-refundable credits at midnight is an entirely plausible failure.

---

## 8. Security and privacy

- **Voice notes are self-dictation only** — the owner describing the
  conversation afterward, never a recording of the other party. This removes the
  consent question almost entirely, and the owner's own summary of what mattered
  is more useful than raw small talk.
- **No facial recognition, ever.** A selfie is context and proof of meeting, not
  an identity lookup.
- **`source_type` records provenance.** A card handed over voluntarily is the
  strongest basis available; data obtained otherwise is a different category and
  the distinction must survive into the database.
- **Indefinite retention**, with genuine per-contact deletion (database rows +
  storage objects). Deletion capability is what makes indefinite defensible.
- RLS on every table. Service-role credentials confined to n8n; never in a
  client.
- **Never logged:** tokens, API keys, signed URLs, transcript content, email
  addresses, phone numbers. Request IDs and redacted errors only.
- Saudi PDPL applies. This is not legal advice; the posture is designed to be
  defensible by default.

---

## 9. Environments

| Environment | Purpose | Rules |
|---|---|---|
| Production | LEAP usage | Dedicated Supabase project `LEAP-NI`; n8n workflows activated manually after test |
| Test | Verification | Separate Telegram bot token against the same n8n instance; workflows prefixed `LNI-TEST-` |

No staging Supabase project. Given the timeline, the isolation that matters is
LNI-from-ElderWise, not prod-from-staging. Migrations are forward-only and are
proven against an empty project before production application.

### Production project configuration — created 25 Aug 2026

| Setting | Value | Reason |
|---|---|---|
| Project name | `LEAP-NI` | — |
| Project ref | see `docs/environment.local.md` | Public repo; never committed |
| Region | **Central EU (Frankfurt), `eu-central-1`** | Chosen for proximity to the **n8n host**, not to Riyadh. The phone talks to Telegram; n8n does every database round-trip. Latency that matters is n8n→Postgres. |
| Compute | **Micro (`t3a.micro`)** | Workload is one user and a few hundred rows. Compute is not the constraint; connections are. Changeable later with a restart. |
| Plan | Pro organisation | ~2 GB storage need exceeds free allowance |
| Data API | **Enabled** | Not used by LNI (n8n uses Postgres directly). Retained for the Phase 5 dashboard. Grants nothing while auto-expose is off. |
| Auto-expose new tables | **Disabled** | Numbered migrations (`001`–`010`) create the 16 tables, indexes, policies, bucket, seed, and the processing-job staleness column. Auto-expose plus one missed policy equals publicly readable contact data. |
| Automatic RLS | **Enabled** | Event trigger enables RLS on every new table in `public`. Structural safety net beneath the explicit policies. |

Phase 0 applies **numbered forward-only migrations**, not a single dump:

| # | File | Contents |
|---|---|---|
| 001 | `001_extensions` | `pg_trgm` |
| 002 | `002_events_bot_state` | `events`, `bot_state` |
| 003 | `003_capture_pipeline` | `captures`, `assets`, `processing_jobs` |
| 004 | `004_entities` | `extraction_runs`, `people`, `companies`, `person_companies`, `interactions`, `follow_ups` |
| 005 | `005_review_support` | `entity_candidates`, `field_corrections`, `enrichment_records`, `credit_ledger`, `audit_log` |
| 006 | `006_indexes` | indexes and constraints |
| 007 | `007_rls_policies` | RLS enable + one `<table>_owner_all` policy per table |
| 008 | `008_storage` | private bucket `lni-assets` + object path policies |
| 009 | `009_seed_leap_2026` | LEAP 2026 seed row; `owner_id` by `lni.owner_email` match |
| 010 | `010_processing_jobs_transition` | `last_transition_at` + trigger + watchdog index |
| 011 | `011_captures_capture_no` | `captures.capture_no` identity + UNIQUE |
| 012 | `012_seed_bot_state` | Seed owner `bot_state` row (WF-01 allowlist + WF-00 alert `chat_id`) from `lni.owner_telegram_user_id` |

### Connection policy — verified 25 Aug 2026

**n8n connects through the Supavisor *shared* transaction pooler** — not the
direct endpoint and not the dedicated pooler.

| Field | Value |
|---|---|
| Host | `aws-0-eu-central-1.pooler.supabase.com` |
| Port | `6543` (transaction mode) |
| Database | `postgres` |
| User | `postgres.<project-ref>` — tenant-qualified |
| SSL | `Require`. Never `Allow` — that permits a silent plaintext fallback, putting the database password on the wire unencrypted. |
| Max connections | `20` |

**Why not the direct or dedicated endpoint.** Both are **IPv6-only** unless the
paid dedicated-IPv4 add-on is purchased. The n8n container has no IPv6 route, so
those endpoints fail with `ENETUNREACH` — correct credentials, no connection.
The shared pooler is dual-stack and costs nothing.

**Why the pooler regardless of IP family.** `/batch` mode can fire ~30
near-simultaneous WF-01 executions, each opening a connection. Micro's
direct-connection ceiling would refuse some, and a refused connection during
evening reconciliation is silent data loss at peak volume. Upsizing compute
would not fix this.

**The IPv6 diagnosis, recorded so it is not repeated.** The VPS *host* has
working IPv6; the Docker bridge does not extend it to containers, so testing
from the host gives a false all-clear. Test from inside the container:

```bash
docker exec <n8n-container> node -e "
const dns=require('dns'),net=require('net');
const h='<host>';
dns.lookup(h,{all:true},(e,a)=>{console.log('DNS:',e?e.code:JSON.stringify(a));
const s=net.connect({host:h,port:6543},()=>{console.log('TCP: CONNECTED');process.exit(0)});
s.setTimeout(5000,()=>{console.log('TCP: TIMEOUT');process.exit(1)});
s.on('error',x=>console.log('TCP ERROR:',x.code));});"
```

`family: 6` plus `ENETUNREACH` is this failure. **Do not fix it by enabling IPv6
in the Docker daemon** — that needs a daemon restart, which bounces every
container on the host including ElderWise's live inbound router.

**Transaction-mode consequences.** No prepared statements, no session-level
state. A `prepared statement does not exist` error is this, not a bad query.
Also `current_user` returns plain `postgres`, not the tenant-qualified name —
the qualified form routes, the plain role authenticates. Never assert on the
qualified form.

**Cursor uses this same connection string** for migrations. Most laptops and CI
runners are IPv4-only and hit the identical wall.

### Credentials verified 25 Aug 2026

| Credential | n8n name | Proof |
|---|---|---|
| Postgres | `Leap-NI` | Query returned PostgreSQL 17.6 via the shared pooler |
| Supabase Storage | `Supabase_Leap-NI` | `GET /storage/v1/bucket` → `200`; response header `sb-project-ref` matched the LNI project |
| Telegram | `Leap-NI` | Unproven until a real-device capture in Phase 1. A bot token means nothing until a real chat exists. |

**Storage needs only `Authorization: Bearer <service_role>`** via Header Auth.
No separate `apikey` header was required, so no Custom Auth credential is
needed. **Scope the credential to the project domain** — unscoped, it would
attach service-role access to any host a workflow happens to call.

### Consequence for verification

Automatic RLS means `rowsecurity = true` **no longer proves the implementer did
the work** — the event trigger sets it regardless. Verification must therefore
confirm that **explicit policies exist per table** in `pg_policies`, not merely
that RLS is on. A table with RLS enabled and zero policies denies everything
except `service_role`, which looks like a broken migration and is in fact an
unfinished one. See `phases.md`, Phase 0 verification.

---

## 10. Failure and rollback

| Failure | Behaviour |
|---|---|
| Extraction provider down | Capture continues; jobs queue; replay later |
| Storage unavailable | Telegram retains the message in its outbox; bot does not acknowledge, so the owner sees no receipt |
| Bad workflow deployed | Deactivate, import previous versioned JSON |
| Bad migration | Forward-only fix; **no destructive migrations during event week** |
| Stuck jobs | WF-09 watchdog alerts independently of the digest |

**During event days: no schema refactors, no provider swaps.** Only a narrow,
tested incident fix with a rollback point.
