# architecture.md

**LEAP Networking Intelligence (LNI)** · Version 2.0 · 26 August 2026

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
8. **Telegram send paths are enumerated, not implied.** Inbound chat replies
   are WF-01 only. WF-00 alerts on repeated errors. Scheduled WF-07 / WF-09
   send operational messages because a cron tick has no parent WF-01
   execution. WF-02 never sends. On-demand `/digest` and `/ask` return
   `reply_text`; WF-01 sends. `chat_id` always from `bot_state`, never
   `$env`. Email copy is scheduled-only; recipient is `auth.users.email`
   for the events owner, never committed.

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

**§4 reconciled against live `information_schema.columns` / `pg_constraint`
on 27 August 2026.** Every column below exists on LEAP-NI with the type and
default stated. Types are Postgres (`uuid`, `timestamptz`, `jsonb`, `text[]`,
etc.), not application nicknames.

### Tables

Purpose, then every live column (`NULL` = nullable, no default unless shown).

**`events`** — LEAP 2026 and future events. UNIQUE `(owner_id, name)`.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `name` | text | — | NO |
| `starts_at` | timestamptz | — | NO |
| `ends_at` | timestamptz | — | NO |
| `location` | text | — | YES |
| `timezone` | text | — | NO |
| `created_at` | timestamptz | `now()` | NO |
| `target_sectors` | text[] | `'{}'` | NO |

**`events.target_sectors` (packet 3.1).** Owner-configured industry labels
the 7 AM briefing compares against `companies.industry`. Empty means
**not set** — the briefing says so; it does not invent a list. Do not
seed guessed sectors. `companies.industry` is filled by enrichment
(Phase 4); until then the mix is `unknown`.

**`bot_state`** — which capture is open; batch mode; **WF-01 allowlist**.
UNIQUE `(owner_id, telegram_user_id)`.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `telegram_user_id` | bigint | — | NO |
| `open_capture_id` | uuid → `captures` | — | YES |
| `mode` | text | `'normal'` | NO |
| `last_activity_at` | timestamptz | `now()` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`captures`** — one `/new`…`/done` unit. UNIQUE `capture_no`.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `event_id` | uuid → `events` | — | NO |
| `status` | text | `'open'` | NO |
| `capture_mode` | text | `'standard'` | NO |
| `opened_at` | timestamptz | `now()` | NO |
| `closed_at` | timestamptz | — | YES |
| `close_reason` | text | — | YES |
| `typed_note` | text | — | YES |
| `flags` | jsonb | `'{}'::jsonb` after 015; live before 015 was `'[]'::jsonb` | NO |
| `card_only` | boolean | `false` | NO |
| `created_at` | timestamptz | `now()` | NO |
| `capture_no` | bigint UNIQUE | `GENERATED BY DEFAULT AS IDENTITY` | NO |

**`card_only` is a column, not a flag.** Batch photos set it `true`. Do not
put it in `flags`.

**`assets`** — immutable raw media. UNIQUE `telegram_file_unique_id`.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `capture_id` | uuid → `captures` | — | NO |
| `kind` | text | — | NO |
| `storage_path` | text | — | YES |
| `telegram_file_unique_id` | text UNIQUE | — | YES |
| `sha256` | text | — | YES |
| `mime_type` | text | — | YES |
| `size_bytes` | bigint | — | YES |
| `upload_status` | text | `'pending'` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`processing_jobs`** — auditable async work. `asset_id` is nullable (jobs
that are capture-scoped, not asset-scoped).

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `capture_id` | uuid → `captures` | — | NO |
| `asset_id` | uuid → `assets` | — | YES |
| `job_type` | text | — | NO |
| `status` | text | `'queued'` | NO |
| `attempt_count` | integer | `0` | NO |
| `provider` | text | — | YES |
| `provider_request_id` | text | — | YES |
| `error_code` | text | — | YES |
| `error_detail` | jsonb | — | YES |
| `output` | jsonb | — | YES |
| `created_at` | timestamptz | `now()` | NO |
| `last_transition_at` | timestamptz | `now()` | NO |

`processing_jobs.output` is the **adapter envelope** defined in §6 — not a
raw provider blob. WF-04 reads `output.result`.

**Enqueue natural key.** Unique index `processing_jobs_asset_job_uniq` on
`(asset_id, job_type) WHERE asset_id IS NOT NULL` (migration `016`). WF-02
`/done` **and the inactivity sweep** `INSERT … ON CONFLICT DO NOTHING` on
this key so a re-run or a replay enqueues nothing twice. Capture-scoped
jobs (`asset_id` NULL) are outside the index.

**`extraction_runs`** — immutable **capture-level** model evidence.
Composed by **WF-04** from `processing_jobs.output.result`. WF-03 does not
write this table.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `capture_id` | uuid → `captures` | — | NO |
| `model` | text | — | YES |
| `prompt_version` | text | — | YES |
| `raw_vision_output` | jsonb | — | YES |
| `raw_transcript` | text | — | YES |
| `structured_output` | jsonb | — | YES |
| `flag_reasons` | text[] | `'{}'::text[]` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`people`** — canonical person. `email_normalized` and
`linkedin_url_normalized` are `GENERATED … STORED`.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `full_name` | text | — | YES |
| `name_original_script` | text | — | YES |
| `title` | text | — | YES |
| `email` | text | — | YES |
| `email_normalized` | text | `GENERATED ALWAYS AS (lower(TRIM(BOTH FROM email))) STORED` | YES |
| `phone` | text | — | YES |
| `linkedin_url` | text | — | YES |
| `linkedin_url_normalized` | text | `GENERATED ALWAYS AS (lower(regexp_replace(TRIM(BOTH FROM linkedin_url), '/+$', ''))) STORED` | YES |
| `review_status` | text | `'unreviewed'` | NO |
| `source_type` | text | — | YES |
| `created_at` | timestamptz | `now()` | NO |

**`companies`** — canonical company.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `name` | text | — | NO |
| `normalized_name` | text | — | YES |
| `domain` | text | — | YES |
| `industry` | text | — | YES |
| `enrichment_status` | text | `'none'` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`person_companies`** — affiliation history.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `person_id` | uuid → `people` | — | NO |
| `company_id` | uuid → `companies` | — | NO |
| `role_title` | text | — | YES |
| `is_current` | boolean | `true` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`interactions`** — what was discussed.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `capture_id` | uuid → `captures` | — | YES |
| `person_id` | uuid → `people` | — | YES |
| `company_id` | uuid → `companies` | — | YES |
| `occurred_at` | timestamptz | `now()` | NO |
| `summary` | text | — | YES |
| `topics` | text[] | `'{}'::text[]` | NO |
| `opportunities` | text[] | `'{}'::text[]` | NO |
| `importance` | smallint | — | YES |
| `created_at` | timestamptz | `now()` | NO |

**`follow_ups`** — next actions.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `interaction_id` | uuid → `interactions` | — | YES |
| `person_id` | uuid → `people` | — | YES |
| `title` | text | — | NO |
| `due_at` | timestamptz | — | YES |
| `priority` | text | `'medium'` | NO |
| `status` | text | `'open'` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`entity_candidates`** — duplicate suggestions.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `entity_type` | text | — | NO |
| `candidate_entity_id` | uuid | — | NO |
| `score` | numeric | — | YES |
| `reasons` | text[] | `'{}'::text[]` | NO |
| `decision` | text | `'pending'` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`field_corrections`** — user edits, never overwritten.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `entity_type` | text | — | NO |
| `entity_id` | uuid | — | NO |
| `field` | text | — | NO |
| `model_value` | text | — | YES |
| `corrected_value` | text | — | YES |
| `corrected_at` | timestamptz | `now()` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`enrichment_records`** — sourced, timestamped enrichment.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `entity_type` | text | — | YES |
| `entity_id` | uuid | — | YES |
| `provider` | text | — | NO |
| `payload` | jsonb | `'{}'::jsonb` | NO |
| `confidence` | numeric | — | YES |
| `fetched_at` | timestamptz | `now()` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`credit_ledger`** — Apollo spend guard.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `provider` | text | — | NO |
| `credits_spent` | integer | — | NO |
| `operation` | text | — | NO |
| `entity_id` | uuid | — | YES |
| `spent_at` | timestamptz | `now()` | NO |
| `created_at` | timestamptz | `now()` | NO |

**`audit_log`** — every AI write and user edit.

| Column | Type | Default | Null |
|---|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` | NO |
| `owner_id` | uuid → `auth.users` | — | NO |
| `actor_type` | text | — | NO |
| `action` | text | — | NO |
| `entity_type` | text | — | YES |
| `before` | jsonb | — | YES |
| `after` | jsonb | — | YES |
| `correlation_id` | uuid | — | YES |
| `created_at` | timestamptz | `now()` | NO |

**`audit_log.correlation_id` is uuid system-wide.** WF-01 mints one uuid
per inbound Telegram update and passes it down. n8n `$execution.id` is a
numeric string and belongs in `after`, not in this column. WF-00 correlates
an error to its capture through this uuid; writing NULL here hides the
real value.

**Build the whole schema in Phase 0**, including tables belonging to later
phases. The schema is built once.

**`processing_jobs.last_transition_at`.** `timestamptz NOT NULL`, default
`now()`, maintained by a `BEFORE UPDATE` trigger whenever `status` or
`attempt_count` changes. WF-09 measures staleness from **this column, never
from `created_at`**. A job healthily in its second WF-03 retry (1 then
5 min) is not stale; a `created_at` threshold would false-alarm.
The 20-minute backoff tier is deleted (packet 3.3). The trigger lives in the database so a workflow author cannot
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
this table. Migration `012` **never applied** (GUC without `missing_ok`,
26 Aug). The live allowlist row exists uncatalogued. Migration `014`
repairs the catalog without disturbing that row.

**`captures.flags` is a jsonb OBJECT.** Default `'{}'::jsonb`. CHECK
`jsonb_typeof(flags) = 'object'` (migration `015`). Reserved keys only:

- `media_group_id` (text) — Telegram album id
- `album_prompt_sent` (boolean) — the inline split prompt has been sent

`card_only` is a **column**, not a flag. Do not store it in `flags`.

**Why 015 exists.** Migration 013's partial unique index predicate
`flags ? 'media_group_id'` presumes **object** shape (`?` is a jsonb
*object* key test). Live on 27 Aug 2026: all 43 `captures` rows held
`'[]'` (jsonb **array**), the 003 default. `?` is always false on an
array, so the index could never match an album row written as `[]`.
015 converts existing arrays to `'{}'` and forbids arrays going forward.

**Album grouping uses `captures.flags`, not a new table.** Telegram delivers
each album member as its own update, so members cannot share n8n memory.
The first member to arrive creates the capture and stores the group id at
`flags->>'media_group_id'`. Later members find that row by the same key.
The race is the partial unique index below (migration `013`). When the
group exceeds two images, WF-01 sends one inline prompt after the assets
are stored — splitting cannot lose an asset. **Album auto-detect is
post-event** (packet 2.5). Live grouping is `/batch`. This design stays
so the post-event build does not invent a second buffer.

### Constraints and indexes

| Constraint | Reason |
|---|---|
| `captures.capture_no` **UNIQUE**, `bigint GENERATED BY DEFAULT AS IDENTITY` | Human-facing number for receipts and `/fix`, `/flag`. Global identity, not per-owner: a per-owner counter would serialise ~30 concurrent `/batch` inserts on one row lock, on the write path that must never fail (`rules.md` §8). Identity gaps on rollback are acceptable; lock contention on capture is not. |
| Partial unique index `captures_owner_media_group_uniq` on `(owner_id, (flags->>'media_group_id'))` `WHERE flags ? 'media_group_id'` | Concurrent Telegram album members are twenty separate WF-01 executions with no shared memory. The first INSERT wins; losers re-select. Partial, so non-album rows (`flags = '{}'` after 015; 003's `'[]'` was an array and never matched `?`) are unaffected. |
| `assets.telegram_file_unique_id` **UNIQUE** | Telegram's native dedup key — the ElderWise `media_id` pattern |
| Partial unique index on non-null normalized email per owner | Allows duplicates pending review |
| Trigram indexes on `people.full_name`, `companies.name`, `interactions.summary` | Search. **Requires `pg_trgm`.** |
| Partial unique index `processing_jobs_asset_job_uniq` on `(asset_id, job_type)` `WHERE asset_id IS NOT NULL` | Natural key for WF-02 `/done` enqueue. `ON CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL DO NOTHING` makes a re-run enqueue nothing twice. This uniqueness is a **partial unique index**, not a table constraint — `ON CONFLICT ON CONSTRAINT processing_jobs_asset_job_uniq` will not run. Partial because capture-scoped jobs (`extraction`, `entity_resolution`) carry `asset_id` NULL. Created by migration `016`. |
| `people.name_original_script` separate from `full_name` | **Never discard Arabic original script.** `name_original_script` is the verbatim original. `full_name` is identity and must be non-null. If the card prints a Latin name, `full_name` uses it **exactly as printed**. An Arabic-only (non-Latin) `full_name` is **accepted as identity** and does not force `needs_review` (packet 3.6; capture **#62** evidence, **not retro-fixed**). `name_original_script` alone is still not identity (trap 7 unchanged). Never invent a Latin name the card does not support. |
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

**Vision OCR is not reproducible on this card stock at `temperature: 0`
(packet 3.9).** Same physical card, two runs, disagreed on Latin
spelling and on phone. Exact email is the only stable join key. A
stored phone is the first read that landed, not verified truth.
Re-capturing a person raises a candidate per disagreeing field. Auto-link
on name stays banned.

**OCR-split emails (packet 2.7).** The same card captured twice can yield two
unequal `email_normalized` values (a transposition, a dropped letter). That is
the most likely duplicate-creation mechanism at this event. Exact-email auto-link
will not merge them; name-merge is forbidden. A scored `entity_candidates` row
**must** be written whenever another owner person shares **exact `full_name`
AND exact `company_id`**, even if both rows carry emails, when those emails are
**not equal**. `reasons` is visible and human-readable and **names the two
differing emails**. Still a suggestion — never an automatic link, never a
name-merge. A pair of silent unlinked people with `entity_candidates` empty is
a defect (`architecture.md` §4: everything that is not an exact match becomes
a scored suggestion).

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

At capture time (WF-01) `assets.kind` is the Telegram media type.
Live `assets_kind_check` (read 26 Aug 2026) permits
`business_card | audio | photo | selfie | document` only — there is no
`video` value. Map onto what exists; never invent a sixth kind:

- Telegram photo (largest size in the `photo[]` array) → `photo` (**unclassified** — contents not yet determined)
- Telegram voice or audio → `audio`
- Telegram document, video, or video_note → `document`

Live `assets_upload_status_check` permits `pending | stored | failed`.
WF-01 writes `stored` only after the Storage PUT succeeds.

`'photo'` at capture time means "image, contents not yet determined".
**Images are not classified at capture.** Telegram gives no signal.

Phase 2 WF-03 sends **every image asset** (live `kind='photo'`) to **one**
vision call. The strict response schema includes an `image_type`
discriminator: `business_card | scene | other`. WF-03 then `UPDATE`s
`assets.kind` from that result, mapped onto the live check (no sixth
kind, no `scene`/`other` column values):

| `image_type` | `assets.kind` written |
|---|---|
| `business_card` | `business_card` |
| `scene` | `photo` |
| `other` | `photo` |

Still **one call**, no OCR-then-parse. A `scene` (or `other`) image gets
contextual description only — **no facial recognition, no identification
of people** (`rules.md` §7 rule 13). `selfie` remains in the CHECK for
historical compatibility; this discriminator never assigns it.

**Why this replaced a `kind='business_card'` branch.** All 34 live image
assets sit at `kind='photo'`. A WF-03 branch that only ran vision on
`business_card` would never fire.

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
- Path convention: `{owner_id}/{capture_id}/{asset_id}-{name}`.
- `{name}` is **not** an original filename. Telegram photos carry none.
  `{name} = {telegram_file_unique_id}.{ext}` where `ext` derives from the
  Telegram media type / `mime_type` (`jpg`, `oga`, `mp4`, `pdf`, `bin` as
  the fallback). The path is then reproducible from the `assets` row
  alone, and `file_unique_id` is already the dedup key, so the path and
  the idempotency key cannot drift apart.
- **`asset_id` is minted before upload.** The `assets` row is inserted
  only AFTER upload succeeds, but the path contains `asset_id`. WF-01
  therefore generates the uuid in n8n (`crypto.randomUUID()`) **before**
  the upload and uses that same value in the later `INSERT`. Ordering:
  **mint → upload → insert**. That is what makes "storage first"
  implementable. Implied until 26 Aug 2026; now explicit.
- Storage policy: an authenticated user may access only objects whose first path
  segment equals `auth.uid()`.
- Upload via raw REST with `httpHeaderAuth` and `x-upsert: true` — the pattern
  already proven in the owner's n8n instance.
- Downloads: WF-03 fetches the private object with authenticated HTTP GET
  (`httpHeaderAuth`, `responseFormat: file`). That is the proven default
  (packet 2.2b C3). Short-lived signed URLs are a proven fallback (C2/C4),
  not the default. Signed URLs are never logged.
- Estimated volume: ~2 GB at 350 captures (card ~2 MB + selfie ~3 MB + 30 s
  audio ~250 KB). Likely exceeds a free-tier allowance — verify on creation.

---

## 6. AI contracts

### Image classification + card extraction — one vision call

WF-03 does **not** wait for `assets.kind = 'business_card'`. Capture-time
kind is Telegram media type only. Every image goes to **one** vision call
whose strict schema includes:

```json
{
  "image_type": "business_card | scene | other",
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
  "scene_description": null,
  "uncertainties": []
}
```

WF-03 feeds that vision call the **stored binary** (C3 path:
`imageType: base64` + named binary property). Signed URL (C4) is a
proven fallback only. **GPT-4o ships as the card engine** behind the
adapter, **without a benchmark** (packet 2.5 scope cut). The model id
lives in one named config node so a later post-event benchmark can still
flip it without hunting the graph. `rules.md` §7 rule 14 says provider
choices are settled by benchmark; we are **knowingly not honouring it
under deadline** (`phases.md` Phase 2).

WF-03 `UPDATE`s `assets.kind` from `image_type` (`architecture.md` §4).
When `image_type` is `business_card`, people/company fields are the card
extraction. When `scene` or `other`, `scene_description` is contextual
only — **no facial recognition, no identification of people**.

**Name fields on the card JSON (and later on `people`).**

| Field | Meaning |
|---|---|
| `full_name` | Identity field. Non-null required. Latin transliteration when the card prints Latin (copy **exactly as printed** — never re-transliterate a name that is already Latin). **An Arabic-only (non-Latin) `full_name` is accepted as identity** and does not force `needs_review` (packet 3.6; capture **#62** is the evidence and is **not retro-fixed**). Never invent a Latin name the card does not support. |
| `name_original_script` | **Verbatim original** as printed. Arabic stays Arabic. Latin-only cards may set this equal to the printed Latin, or null if there is no second script. **Never discard the original.** `name_original_script` alone is still not identity (trap 7 unchanged). |

**A person row requires a non-null `full_name`.** `name_original_script` alone is not identity (packet 2.6b, trap 7 unchanged). An Arabic-only (non-Latin) `full_name` is **accepted as identity** and does not force `needs_review` (packet 3.6). Capture **#62** is the evidence; it is **not retro-fixed**. Speech that names a real person: same (`full_name` present, row survives). Speech that only refers ("هذا الرجال", "this man", "some lady from Aramco"): `full_name` stays null, the person is **omitted**, not guessed. WF-04 drops any person with a null or empty `full_name` before write; "No name extracted" tests `full_name` only.

Live defect (packet 2.5): both fields were identical Arabic (`عمران خالد`). That is a lost transliteration, not preservation.

**No OCR-then-parse pipeline.** One call.

### Where per-asset provider output lives

**WF-03 writes one adapter envelope to `processing_jobs.output` for every
asset job** (`card_vision` and `transcription`). `extraction_runs` is
composed later by **WF-04** from those envelopes.

The envelope is the same shape for every `job_type`. Provider-specific
wrappers (OpenAI `output[0].content[0].text`, Whisper `{text, usage}`,
error objects) stay inside `raw`. WF-04 reads `result` only.

```json
{
  "provider":     "<engine id>",
  "model":        "<model id>",
  "job_type":     "card_vision | transcription",
  "result":       {},
  "raw":          {},
  "error":        null,
  "completed_at": "<timestamptz>"
}
```

| Field | Meaning |
|---|---|
| `provider` | Engine id behind the adapter (e.g. `openai`). Not a node type. |
| `model` | Model id from **Card engine config** (vision) or `whisper-1` (transcription). Changeable by config. |
| `job_type` | `card_vision` or `transcription`. |
| `result` | **Normalised payload.** `card_vision`: the strict card JSON itself (`image_type`, `people`, `company`, `scene_description`, `uncertainties`) — already unwrapped, not buried under `content[0].text`. `transcription`: `{ "text": "...", "duration_seconds": 0 }`. |
| `raw` | The provider response, unmodified, for replay and the benchmark. |
| `error` | `null` on success. On failure / `needs_review`: a **redacted** error object (message class only — no transcript, no signed URL, no payload). |
| `completed_at` | When this envelope was written (`timestamptz`). |

**Why:** Packet 2.3 wrote two shapes into `output` — the OpenAI Responses
envelope for vision, and a flat `{text, usage}` for Whisper. WF-04 would
need two unwrapping paths, one of which depends on a provider envelope
staying shaped exactly as today. That leaks a provider detail into the
data model and violates rule 4 (provider specifics sit behind an
adapter). The envelope is the adapter. WF-04 must not know the shape of
any provider's envelope.

Failed jobs write the same envelope: `result` may be null, `error` is
set, `raw` still holds what the provider returned.

WF-03 runs **per asset**. `extraction_runs` is **per capture**. Writing a
partial capture row from a per-asset worker produces a row that is
neither immutable nor complete — a second image on the same capture
would either overwrite evidence or invent a second "immutable" run
before the capture is finished. The queue row is the per-asset place;
the extraction run is the per-capture place.

Rationale: a business card is a layout puzzle, not a document. Which string is
the job title versus the company tagline is decided by font size, position, and
proximity to the logo. An OCR pass flattens exactly the signal needed, forcing a
second model to guess it back from a wall of text. A `kind='business_card'`
gate would skip every live image (34 of 34 are `photo`).

Nullable fields, never guessed strings. The model must never invent an email,
phone number, domain, or date not present in the source. A person referred to
but not named is omitted rather than guessed.

**`summary` and `topics` are required when a `[TRANSCRIPT]` or `[TYPED_NOTE]`
block has text** (packet 2.6b). `summary` is 1–3 sentences of what was said or
noted. `topics` are short sector or theme tags from that same text. Both may
be null / empty **only** when those labelled blocks are empty. These two
fields feed `interactions.summary` (WF-08 trigram `/ask`) and the 7 AM
briefing sector distribution (WF-07). Empty on a real conversation is a
defect, not conservatism.

### Transcription

OpenAI Whisper. **`language` left unset** — auto-detect. Arabic/English
code-switching is expected and normal. WF-03 writes the adapter envelope
(`result.text`, `result.duration_seconds`, `raw` = unmodified Whisper
response). WF-04 copies `result.text` into
`extraction_runs.raw_transcript` when composing the capture-level run.

### Rule-based flagging

Replaces model self-reported confidence. A capture is flagged when **any** hold:

- No name extracted
- No email **and** no phone
- Non-Latin script present in the name field (**informational only** as of packet 3.6 — does **not** force `needs_review`; an Arabic-only `full_name` is accepted identity. Capture **#62** is the evidence and is **not retro-fixed**. WF-04 / WF-05 status change is packet 3.7)
- Empty transcript despite audio longer than 5 seconds
- Two or more people detected on one card
- Extraction output fails schema validation
- Capture contains nothing usable

**Rationale:** a vision model is often *most* confident exactly when it is
transliterating an Arabic name wrongly. Self-reported confidence is not a
reliable error filter; observable conditions are.

### Provider benchmark — **post-event** (cut from Phase 2)

8–10 representative cards (Arabic-only, bilingual, glossy, dark background,
embossed, bad angle) plus two code-switched voice notes. Score **field-level
accuracy** across GPT-4o vision, Gemini, and Mistral OCR.

**Not run before LEAP.** Packet 2.5 cut this from Phase 2 under deadline.
GPT-4o ships. `rules.md` §7 rule 14 is knowingly not honoured. The adapter
still makes a later winner a config change.

The adapter makes the winner a config change. **No provider is chosen on
reputation** — except that deadline forced GPT-4o to ship on reputation
plus the spike (packet 2.2b C3), which rule 14 forbids. Recorded here so
the cut is visible.

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
| Auto-expose new tables | **Disabled** | Numbered migrations (`001`–`017`) create the 16 tables, indexes, policies, bucket, seed, the processing-job staleness column, catalog repair of `bot_state`, the `captures.flags` object CHECK, the `/done` enqueue natural key, and `events.target_sectors`. Auto-expose plus one missed policy equals publicly readable contact data. |
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
| 012 | `012_seed_bot_state` | **Never applied** (26 Aug 2026): `current_setting('lni.owner_telegram_user_id')` without `missing_ok` raised `unrecognized configuration parameter`. File kept as history. Live `bot_state` still has one row from that attempt. Superseded by 014. |
| 013 | `013_captures_media_group_unique` | Partial unique index `captures_owner_media_group_uniq` so concurrent album-member INSERTs are deterministic |
| 014 | `014_bot_state_seed_repair` | Catalog repair: idempotent `bot_state` seed using `current_setting(..., true)` (009 pattern). Does not disturb the live row. Asserts exactly one `bot_state` row, owner matches 009, `open_capture_id` consistent. |
| 015 | `015_captures_flags_object` | `captures.flags` default `'{}'::jsonb`; convert live jsonb arrays to `'{}'`; CHECK `jsonb_typeof(flags) = 'object'`. Does not drop `captures_owner_media_group_uniq`. |
| 016 | `016_processing_jobs_asset_job_uniq` | Partial unique index `processing_jobs_asset_job_uniq` on `(asset_id, job_type) WHERE asset_id IS NOT NULL`. Natural key for `/done` enqueue idempotency. |
| 017 | `017_events_target_sectors` | `events.target_sectors text[] NOT NULL DEFAULT '{}'` for the 7 AM coverage-gap list. Empty = not set. No guessed seed. |

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

**n8n `settings.binaryMode` is `"separate"`.** JSON and binary stay on
separate item properties. A default that is absent from the workflow JSON
cannot be verified by read-back (`workflows.md` §1). Every LNI workflow
sets it explicitly. WF-01 needs it for Telegram file download → sha256 →
Storage PUT.

**Cursor uses this same connection string** for migrations. Most laptops and CI
runners are IPv4-only and hit the identical wall.

### Credentials verified 25 Aug 2026

| Credential | n8n name | Proof |
|---|---|---|
| Postgres | `Leap-NI` | Query returned PostgreSQL 17.6 via the shared pooler |
| Supabase Storage | `Supabase_Leap-NI` | `GET /storage/v1/bucket` → `200`; response header `sb-project-ref` matched the LNI project |
| Telegram | `Leap-NI` | Unproven until a real-device capture on WF-01 (packet 1.3). A bot token means nothing until a real chat exists. |

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
| Storage unavailable | Telegram retains the message in its outbox; the bot does not acknowledge, so the owner sees no receipt. **The n8n execution MUST error** (`stopAndError`) so WF-00 writes `audit_log`. A success NoOp after media was received but not stored is a defect (rule 5). |
| Bad workflow deployed | Roll back with **n8n's own workflow version history** (`versionId` / `activeVersionId`). **Do not import workflow JSON from git** — this repo does not contain it and must not. Saved workflow JSON carries the project ref, credential names, and host identifiers; the repo is public. **How:** (1) n8n editor → the workflow → Versions → restore the `versionId` recorded before the change. (2) Confirm `activeVersionId` matches that id and the workflow is still Active. Record both version ids in the packet report; that pair is the rollback point. |
| Bad migration | Forward-only fix; **no destructive migrations during event week** |
| Stuck jobs | WF-09 watchdog alerts independently of the digest |

**During event days: no schema refactors, no provider swaps.** Only a narrow,
tested incident fix with a rollback point.
