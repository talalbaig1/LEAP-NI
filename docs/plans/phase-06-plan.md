# Phase 6 plan — pgvector RAG

**Date:** 28 August 2026
**Status:** PLAN ONLY. No migration. No workflow. No WF-08 PUT.
**Order:** 7 (7.4 only, gate-conditional), then 6, then 5. Phase 8
PWA stays post-event (`masterplan.md` §3 Corollary 1).
**Main at plan time:** `952ab05`.

**Catalog correction 28 Aug 2026 (packet 7.16, binding):**
027 is taken (`027_follow_ups_brief`, applied). 028 is
`028_captures_followup_mode` (follow-up-as-capture). Embeddings
catalog is **`029_embeddings`**, file `supabase/migrations/029_embeddings.sql`.
Every embeddings "027" / `027_embeddings` reference below means **029**.
This packet still does not apply embeddings.

Owner intent (paraphrase): `/ask` should retrieve what was actually
said, not the entire interaction table ranked by a trigram boolean.

Architect constraints accepted. Disagreements, physical limits, and
cuts are in §L, not buried in a node list.

This packet answers one live question from the query, not from
memory: whether the 43 `processing` captures with no
`entity_resolution` job appear on the 7 AM briefing. See §H.

---

## Binding rules this plan will not violate

- Docs before implementation. Cause before fix.
- Verification is live artefact read-back.
- Do not deactivate any LNI workflow. Do not restart n8n. Do not
  touch ElderWise.
- Never `$env`. Never `$getWorkflowStaticData`.
- Additive schema only. Forward-only migrations. Catalog **name**
  starts `027_`. **026 is taken:** GATE-FIX
  `026_captures_last_activity` (`captures.last_activity_at`).
  Embeddings is **027**, not 026.
- WF-08 is **ACTIVE**. Changing it is blast radius. That step is
  its own packet, after the event, unless the architect says
  otherwise.
- Do not compete with capture during 31 Aug – 3 Sep.
- Do not GRANT SELECT (Phase 5).
- Do not PUT WF-01 in Phase 6.

---

## A. pgvector availability (read-only verification)

Verified 28 August 2026, read-only, no CREATE.

| Check | Result |
|---|---|
| `select version()` | `PostgreSQL 17.6 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit` |
| Supabase `list_extensions` row `vector` | `default_version` **0.8.2**, `installed_version` **null** |
| `pg_trgm` (already in use by `/ask` `/flag`) | `installed_version` **1.6**, schema `public` |
| Comment on `vector` | `vector data type and ivfflat and hnsw access methods` |

**Available, not installed.** Same class as `pg_trgm` before
migration `001_extensions`. Migration 027 must
`create extension if not exists vector;` (additive). This packet
does not run that.

Project: Postgres 17.6 on this Supabase project. Extension exists
on the image. It is not in `pg_extension` until 027.

---

## B. Schema — migration 027, additive

**File:** `supabase/migrations/027_embeddings.sql`
**Catalog name:** `027_embeddings` (must start `027_`; 026 is
`026_captures_last_activity`; 023 is still the unnamed
`processing_jobs_enrichment_person_uniq`; 012 never applied).

027 does four things and nothing else:

1. `create extension if not exists vector;`
2. `create table public.embeddings (…);`
3. Unique index + HNSW index.
4. `enable row level security` + one `FOR ALL` policy
   `owner_id = auth.uid()`, same family as `007_rls_policies`.
   No FORCE RLS. No GRANT SELECT. No policies for `anon`.

No `ALTER` of `interactions`, `captures`, `extraction_runs`,
`processing_jobs`, or `follow_ups`. No new `job_type` value.

### Table

| Column | Type | Null | Why |
|---|---|---|---|
| `id` | uuid PK `gen_random_uuid()` | NO | |
| `owner_id` | uuid → `auth.users` | NO | owner-scoped, same as every user table |
| `source_table` | text | NO | `interactions` \| `captures` \| `extraction_runs` |
| `source_id` | uuid | NO | PK of that row |
| `source_field` | text | NO | `summary` \| `typed_note` \| `raw_transcript` \| `structured_output` |
| `content_hash` | text | NO | sha256 of the exact string that was embedded; skip re-embed when equal |
| `model` | text | NO | `'text-embedding-3-small'` |
| `dims` | integer | NO | `1536` |
| `embedding` | `vector(1536)` | NO | |
| `created_at` | timestamptz `now()` | NO | |

Checks (named, additive):

- `embeddings_source_table_check` — the three table names above.
- `embeddings_source_field_check` — the four fields above.
- `embeddings_dims_check` — `dims = 1536`.

Unique: `(source_table, source_id, source_field, model)`.
Re-backfill is upsert, not a second row.

### Index type: HNSW, cosine

```sql
create index embeddings_embedding_hnsw
  on public.embeddings
  using hnsw (embedding vector_cosine_ops);
```

**Why HNSW, not IVFFlat.** IVFFlat needs a trained list count and a
non-empty table before it is useful; an untrained IVFFlat is a seq
scan with extra ceremony. HNSW works on first insert. pgvector
0.8.2 ships both (verified from the extension comment). Corpus at
plan time is tens of rows, not millions. Rebuild later if the table
crosses tens of thousands — that is a later packet, not 027.

Also btree `(owner_id, source_table, source_id)` for the owner
filter that every retrieve must keep.

### How it stays additive

- New table. New extension. New indexes. New RLS policy on the new
  table only.
- Dropping 027 is `drop table embeddings; drop extension vector;`
  if nothing else depends on it. Do not plan to drop it.
- WF-08 is unchanged by 027. Retrieve still works on trigram if
  027 lands and the WF-08 packet never does.

---

## C. What gets embedded — and what does not

Packet list, mapped onto live columns (read-only 28 Aug):

| Source | Live column | Rows with text now | Chars now |
|---|---|---|---|
| `interactions.summary` | `public.interactions.summary` | **6** of 14 | **664** |
| `captures.typed_note` | `public.captures.typed_note` | **7** of 56 | **112** |
| transcripts | `public.extraction_runs.raw_transcript` | **9** nonempty | **916** |
| extraction output | `public.extraction_runs.structured_output` | **22** of 22 | **12380** (json text) |

There is no `transcripts` table. `assets` has no transcript column.
Whisper output lives on `extraction_runs.raw_transcript`.

Embed the string that will be retrieved, owner-scoped, skip blanks.
`structured_output` is jsonb: embed `structured_output::text` after
stripping trivial `{}` / `[]`. Do not embed `raw_vision_output` as
well — it is the same card, noisier, and duplicates extraction.

### NOT embedded, and why

| Thing | Why not |
|---|---|
| Raw photos / binaries / `assets` bytes | Not text. Vision already ran. A vector of pixels is not `/ask`. |
| `people` / `companies` rows as a substitute for interactions | Identity, not what was said. WF-08 already JOINs name and company onto the interaction at retrieve time. Trigram on `full_name` already works. |
| `people.email` / `phone` | WF-08 gates those behind `want_contact`. Putting them in a vector leaks them into every answer. |
| `follow_ups.body` / `to_email` | Email drafts. Not the meeting record. PII. |
| `audit_log`, `credit_ledger`, `bot_state`, `processing_jobs.error_detail` | Ops, not recall. |
| `enrichment_records.payload` | Apollo dump. Phase 4 already stored it. Do not teach `/ask` to recite enrichment JSON. |
| Empty summaries / empty notes | Skip. Hash of empty is not a retrieval unit. |

`phases.md` Phase 6 also said "approved entity data". v1 does **not**
embed people/companies as their own rows. Names arrive via the JOIN
on the interaction (or via typed_note / extraction JSON that already
contains them). If the architect wants a separate person embedding,
that is a later packet, after we see `/ask` miss a name that trigram
would have hit.

---

## D. Provider, model, cost

| Item | Choice |
|---|---|
| Provider | OpenAI (same credential `ouWVjrmc8Ia4SRD2` already on WF-04/08/10) |
| Model | `text-embedding-3-small` |
| Dimensions | **1536** (default; do not pass `dimensions` to shrink) |
| List price used | **$0.020 per 1M tokens** (OpenAI public price for this model at plan time) |
| Why not `text-embedding-3-large` | 3× the dims, 6.5× the price, no retrieval proof yet that `/ask` needs it. Rule 14 still waived; this is the cheap default, named as such. |
| Why not a local model | No GPU on this n8n host. Do not add a provider. |

Token estimate: chars/3 (conservative for mixed Arabic/English).

| Bucket | chars | ~tokens |
|---|---|---|
| summaries | 664 | 221 |
| typed notes | 112 | 37 |
| transcripts | 916 | 305 |
| extraction JSON | 12380 | 4127 |
| **current corpus** | **14072** | **~4.7k** |

**Backfill of the current corpus: ~4.7e3 / 1e6 × $0.02 ≈ $0.00009.
Under one cent. Round up in the owner's head to $0.01 and move on.**

Event envelope (not a forecast, a ceiling): 500 captures × 4k
chars of extract+transcript+note ≈ 2e6 chars ≈ 0.7M tokens ≈
**$0.014**. A thousand-dollar RAG bill is not a real number on this
project.

Incremental embed after backfill is per new row, same price, cents
per day at event scale.

Do not log the embedded text to `audit_log`. The OpenAI node sees
it; Postgres stores the vector and the hash.

---

## E. Backfill — new workflow, not a WF-03 job type

**Recommend: a new workflow `LNI WF-11 - Embeddings backfill`,
created INACTIVE, after the event (or off-hours with the architect's
packet). Do not add a `processing_jobs.job_type`.**

Why not WF-03:

- WF-03 is the capture hot path. It claims `card_vision` /
  `transcription` / `photo_description` jobs. A new job type
  competes for the same claim SQL during 31 Aug – 3 Sep.
- `processing_jobs_job_type_check` is a closed list
  (`card_vision`, `transcription`, `photo_description`,
  `extraction`, `entity_resolution`, `enrichment`). Adding
  `embed` is an ALTER CHECK on a live table. That is not "027 is
  additive" in spirit, and it is a capture-adjacent schema change.
- Embeddings are not a per-asset capture job. They are a corpus
  maintenance job. Wrong queue.

WF-11 sketch (not built in this packet):

- Manual Trigger + Schedule `0 3 * * *` `Asia/Riyadh` (03:00, after
  day-close, before 7 AM). Schedule **off** until a packet turns it
  on. First run is executeWorkflow / manual.
- Self-identify `LEAP 2026`. Leap-NI Postgres. OpenAI credential.
- Select owner-scoped source rows whose hash is missing or differs.
  Cap N per execution (start **20**) so a catch-up cannot run for
  300 s against a growing event corpus.
- Embed, upsert on `(source_table, source_id, source_field, model)`.
- No Telegram. No Gmail. Empty `reply_text` is fine; this is not a
  callee of WF-01.
- `availableInMCP: true`, `errorWorkflow` = WF-00, timeout 300,
  timezone `Asia/Riyadh`. Never `$env`.
- **Do not run 31 Aug – 3 Sep** unless the architect issues an
  off-hours packet. Capture wins.

Incremental path post-event: WF-04 / WF-05 success can later insert
an embed job, still on WF-11, still not on WF-03. Not v1.

---

## F. WF-08 retrieval change — the only Phase 6 blast radius

WF-08 id `QIioJBxuZYJh5R4W` is **ACTIVE**. versionId
`b699e7d6-ecd4-431d-86ff-d61bd1472390`. Live `Retrieve corpus` is:

```
ORDER BY (full_name % q OR company % q OR summary % q) DESC,
         occurred_at DESC
LIMIT 80
```

No numeric floor. Observed 27 Aug: Compose context `row_count` was
**10** on every retrieving `/ask` (**255773, 255781, 255786, 255800,
255806**) — the full interaction corpus, not a filtered subset. The
sentinel `The corpus has nothing. Do not guess.` cannot fire while
any interaction exists.

**State plainly: swapping that SQL for a vector query is the only
Phase 6 step that can break `/ask` for the owner during or after
the event. It must be its own packet. After the event, unless the
architect says otherwise.**

027 can land without touching WF-08. Backfill can land without
touching WF-08. `/ask` stays the trigram path until the WF-08
packet.

That later packet (sketch, not this PR):

1. Keep the trigram SELECT as a **fallback** named node.
2. New node: embed the question (`text-embedding-3-small`), then
   kNN on `embeddings` filtered `owner_id = $1`, cosine distance,
   join back to interactions/captures so citations remain `#N`.
3. Hybrid: union of (vector rows passing the floor) and
   (trigram_hit true). Cap 20 to the model, not 80.
4. Prove against the same five `/ask` executions' questions. A
   Huawei-class question must still cite `#N`. An off-topic
   question must be allowed to return the sentinel.
5. PUT WF-08 without `active`. Strip `binaryMode` /
   `timeSavedMode`. Rollback = restore version
   `b699e7d6-ecd4-431d-86ff-d61bd1472390`. Do not deactivate.

Do not combine 027, WF-11, and the WF-08 PUT in one packet.

---

## G. The relevance floor

Phase 3 **CUT** a relevance floor. Reason then: launch-scale corpus
was 10 interactions; a floor on a boolean trigram-hit either
dropped everything or dropped nothing. Measured `row_count` was 10
on every live retrieve. Changing retrieval mid-event was a new
failure mode.

Vector retrieval changes that because cosine distance is a real
score, not a boolean. `embedding <=> query_embedding` is in `[0, 2]`
for cosine ops; similarity `1 - distance` is the number to floor.

**Recommended floor for the later WF-08 packet (not 027):** keep a
row if **either**

- trigram_hit is true (name / company / summary `%` question), or
- cosine similarity `>= 0.30` (distance `<= 0.70`)

then `ORDER BY distance ASC, occurred_at DESC` `LIMIT 20`.

If zero rows survive: Compose context uses the existing sentinel
and `row_count = 0`. That is the point of the floor. Tune 0.30 on
the 255773-class questions after backfill — it is a starting
value, not a religion. Do not ship a floor on trigram-only
retrieve; that is the cut that Phase 3 already made, and it still
holds until vectors exist.

A confident answer to an unsupported question is still not a
retrieval success. The floor is how `/ask` is allowed to say
nothing.

---

## H. The 43 `processing` captures and the 7 AM briefing

**Question:** are the 43 captures at `status='processing'` with no
`entity_resolution` job counted on the 7 AM briefing?

**Answer from the live WF-07 `Load digest` SQL, not from memory.
No fix in this packet.**

Live WF-07 (`AyPtkP8PMFeEdYU9`, versionId
`fb9ee1c4-6b40-4064-af22-950b78a45544`), node `Load digest`.
Morning briefing line is composed as
`stuck (event to date) ` + `stuck_event`.

`stuck_event` predicate (brief CTE):

```sql
c.status = 'processing'
AND c.closed_at IS NOT NULL
AND c.opened_at >= p.scope_start
```

`scope_start` for a scheduled 7 AM tick is `events.starts_at`
(`On demand digest` is not executed; `$4` is `''`).

Live `events.starts_at` for `LEAP 2026`: **`2026-08-30 21:00:00+00`**
(31 Aug 00:00 Riyadh).

Live counts, same moment as this plan (read-only):

| Count | Value |
|---|---|
| captures | 56 |
| `status='processing'` | **43** |
| of those, `closed_at IS NOT NULL` | **43** |
| of those, `closed_at IS NULL` | **0** |
| `status='failed'` | **0** |
| processing with no `entity_resolution` job | **43** (all of them) |
| brief predicate `processing AND closed_at NOT NULL AND opened_at >= starts_at` | **0** |
| day-close `stuck` (today Riyadh ∩ same predicate) | **0** |

So: the 43 match the **status** half of the briefing line (they are
closed-but-still-processing). They do **not** match the **window**.
They opened before `starts_at`, which is still in the future.
**They are not on the 7 AM `stuck (event to date)` number today,
and they will not appear on it after the event opens unless a new
capture opened at or after `starts_at` sits in `processing` with
`closed_at` set.**

They are not in `people` / `companies` (those count those tables,
`created_at >= scope_start`). They are not in day-close `captured`
/ `clean` unless opened today Riyadh **and** `opened_at >= scope_start`.

Day-close `stuck` is the same status predicate restricted to
`today_caps` (today Riyadh **and** `opened_at >= scope_start`). The
43 are not there either.

The missing `entity_resolution` job is **not** in the SQL. The
briefing does not know or care that the job is absent. It only
counts `processing` + `closed_at` + window.

Highest-value open item, still open: replay those 43, or exclude
them, or leave them. This plan does not choose. It records what the
query does.

---

## I. Packet breakdown

| Packet | Artefact | When | Architect read-back |
|---|---|---|---|
| **6.0 Plan** | this file | now | Docs only. No `vector` in `pg_extension`. WF-08 GET unchanged. |
| **6.1 Schema** | migration `027_embeddings` applied | after the event, or when the architect says | `pg_extension` has `vector` 0.8.2. `embeddings` exists, 0 rows, HNSW present. Catalog name starts `027_`. No ALTER of `processing_jobs_job_type_check`. WF-08 GET unchanged. |
| **6.2 Backfill** | WF-11 created **INACTIVE**, then one manual/execute run | after 6.1, not 31 Aug–3 Sep | GET name `LNI WF-11 - Embeddings backfill`. `active: false`. Self-id `LEAP 2026`. `embeddings` row count equals the nonempty sources above (hash skip). Cost in the OpenAI dashboard is cents. |
| **6.3 WF-08 retrieve** | **Own packet.** PUT WF-08 hybrid retrieve + floor | after 6.2, after the event unless architect says otherwise | GET versionId moved. `Retrieve` uses `embeddings` and still JOINs capture_no. Off-topic `/ask` can yield `row_count = 0` and the sentinel. On-topic matches 255773-class citations. Rollback version `b699e7d6-…`. PUT without `active`. |

If 7.4 is in flight, Phase 6 waits. Capture wins.

---

## J. Risk

| Surface | Touch? | Blast |
|---|---|---|
| WF-01 | No | None by design |
| WF-03 | No | A job_type embed would have been the capture collision. Cut. |
| WF-07 | No | Digest SQL unchanged. §H is read-only. |
| **WF-08** | Packet 6.3 only | **Only Phase 6 blast.** Bad kNN → `/ask` invents or goes silent. Rollback the versionId. |
| WF-11 | New, inactive first | If accidentally ACTIVE and looping at 03:00 during the event, it spends OpenAI pennies and pooler slots. Keep inactive until a packet. |
| `embeddings` | Additive | Empty table cannot break `/ask`. A bad HNSW op class is caught at CREATE INDEX, not at retrieve. |
| `vector` extension | Additive | `CREATE EXTENSION` is cluster-safe on this image (list_extensions showed 0.8.2 available). |

**During 31 Aug – 3 Sep:** no 027, no WF-11 schedule, no WF-08 PUT.

---

## K. Traps

| Trap | How avoided |
|---|---|
| `installed_version` null mistaken for "pgvector missing" | It is available, not installed. 027 CREATE EXTENSION. |
| IVFFlat untrained | HNSW. |
| Embedding people as a substitute for what was said | Not in v1. JOIN at retrieve. |
| WF-03 job type | Cut. New workflow. |
| WF-08 PUT in the same packet as 027 | Forbidden. §F. |
| Floor on trigram-only retrieve | Still cut. Floor only when a vector score exists. |
| Postgres COUNT string | `count(*)::int` / `OVER()::int` if WF-11 reports counts. |
| PUT `active=true` is 400 | WF-11 activate via `POST /activate` when the time comes. WF-08 PUT without `active`. Strip `binaryMode` / `timeSavedMode`. |
| MCP create binds ElderWise | REST PUT credentials + self-id. |
| Logging PII | No email/body/transcript in `audit_log`. |
| 023 unnamed catalog | File **and** catalog `027_…`. 026 is last_activity. |

---

## L. Disagreements, physical limits, cuts

### Disagreements

1. **`phases.md` "approved entity data"** — v1 does not embed
   `people` / `companies` as rows. The packet named four text
   sources. Entity names stay a JOIN. Reopen only if `/ask` misses
   a name that trigram hits and vector misses.
2. **Backfill as a WF-03 job type** — refused. Capture queue during
   the event is the reason Phase 6 exists after LEAP, not inside
   WF-03.
3. **Relevance floor as part of 027** — refused. A table cannot
   fire the sentinel. Only a WF-08 SQL change can, and that is
   packet 6.3.

### Physical limits

- Question embed adds one OpenAI call to every `/ask` in 6.3.
  Latency + a second failure mode. Named so 6.3 can choose
  "embed the question" vs "trigram-only until corpus > N".
- n8n OpenAI embeddings node vs HTTP: pick in 6.2 from live node
  types; do not guess a parameter name in this plan.
- `vector(1536)` is a fixed width. Changing model later is a new
  column or a new table, not an ALTER TYPE in place.

### Cuts (deliberate)

- Hybrid retrieve **before** the event.
- `text-embedding-3-large`.
- Shrinking dims below 1536.
- Per-file / per-chunk embeddings of a single transcript.
- Reranker model.
- Embedding `follow_ups.body`.
- GRANT SELECT / Phase 5 dashboard over `embeddings`.
- Replay of the 43 `processing` captures (Phase 3 open item, not
  Phase 6).
- `/ask` floor on the current trigram retrieve.

---

## M. What cannot be met safely before / during the event

- Packet 6.3 (WF-08 PUT).
- A backfill that shares WF-03's claim queue.
- Using the 43 `processing` rows as a retrieval corpus (they have
  no `entity_resolution` and mostly no interaction summary).
- Phase 8 PWA.

If Phase 6 slips past September, the owner still has `/ask` over
trigram + 10 (soon: hundreds) interaction rows in the context
window. That is the reason vectors were deferred in Phase 3. It
remains acceptable. A broken `/ask` during the event is not.
