# Session 06 — Phase 4 enrichment, Tavily, /flag (packets 4.0–4.13)

**Date:** 28 August 2026
**Chat purpose:** Phase 4 — WF-06 enrichment, Tavily company fallback,
WF-05 enqueue, `/flag`, then close.
**Outcome:** Phase 4 **closed**. WF-06 is built, **ACTIVE**, and proven
with real data. `/flag` enqueues; WF-06 drains on `*/15`. Last merge
vehicle on `main` is PR **#33** squash `954fe29` (`Phase 4: /flag
command`). Packets 4.0–4.7 squash-merged as #24–#31. Packet 4.8
activation is live n8n (PR **#32** was left OPEN; the bound then the
unbound ceiling live on the instance). Packet 4.13 is this log.

No n8n workflow JSON is committed. Repo stays identifier-free except
where this file records live evidence already named in `workflows.md`.
Live secrets live in gitignored `docs/environment.local.md`.

Implementer: Cursor. Architect/verifier: Claude. Owner: Talal.

---

## 1. What was achieved

Phase 4 is person-by-email enrichment with a hard credit guard,
Tavily as a company-website fallback only, and `/flag` as the
owner's force-enqueue. WF-05 enqueues; WF-06 drains. WF-01 never
calls Apollo.

Live, WF-06 **ACTIVE**, `versionId` = `activeVersionId`.
`lni_config.apollo_daily_ceiling` = **60** (read 28 Aug 2026).
Claim is still `LIMIT 1`. Schedule `*/15` `Asia/Riyadh`.

Ten packets, with the merge SHA on `main`:

| Packet | PR / SHA | What the artefact is |
|---|---|---|
| 4.0 | #24 `3ae3f60` | Scope, Decision 8 reversal, enrichment data boundary |
| 4.1 | #25 `e9593d0` | `linkedin_source`, domain normalisation, ceilings, ledger `status` |
| 4.2 | #26 `fe60499` | WF-06 built, free-mail rule, credit guard. Inactive. |
| 4.3 | #27 `4f1c407` | No-match ceiling Q; probe `ad9c6cde` hollow, 0 credits |
| 4.4 | #28 `1ded22b` | Match test is `name`; measured `credits_spent`; Q closed |
| 4.5 | #29 `7d204b3` | LinkedIn fill + `linkedin_source='apollo'`; domain backfill |
| 4.6 | #30 `2a22e66` | 30-day re-enrichment cache (`skipped_cached`) |
| 4.7 | #31 `1074661` | Tavily company fallback; WF-05 enrichment enqueue |
| 4.8 | live n8n (PR #32 OPEN, not on `main`) | First activation **bounded** (ceiling 5, LIMIT 1, three unattended `*/15` cycles), then ceiling raised to **60** |
| 4.9–4.12 | #33 `954fe29` | `/flag` on WF-01; Route type swap; COUNT `::int`; capture_id anchor; `(no email)` |
| 4.13 | this file | Merge #33, session log, handover |

**Activation (4.8), live not git.** PUT `"active": true` on inactive
WF-06 returned 400 `request/body/active is read-only`. Activation is
`POST /api/v1/workflows/{id}/activate`. Bound existed because the
scheduled drain path had never executed. Raising to 60 was a later
act. Do not treat missing #32 on `main` as “WF-06 is inactive” —
GET says `active: true`.

**Tavily (4.7).** Company fallback only: Apollo hollow **and** a
non-null `companies.domain` not on `lni_free_email_domains`.
`provider='tavily'`, `entity_type='company'`. Never merged with an
Apollo row. Never written to `people.*`. `credits_spent` is 1 by
contract. Pay-as-you-go is ON with an **$8 / 1000-credit cap**.

**WF-05 enqueue (4.7).** After a successful person upsert, WF-05
inserts `job_type='enrichment'` when `email_normalized` is present
and the capture is not `needs_review`. Natural key
`processing_jobs_enrichment_person_uniq`. WF-05 does not call WF-06.

**`/flag` (4.9–4.12), proven webhook.** WF-01 resolves and enqueues
`force=true`. It does not dispatch WF-06 and does not call Apollo.

- 4.9 prove **void**: Route type `connection[10]` still on Unknown
  type terminal. Execs **265428–265446** silent success, no reply.
- 4.10 swap: `[10]` Flag arg empty?, `[11]` Unknown type. Re-prove
  265540 usage, 265544 no-match. Then Flag many? threw on COUNT
  string (265548 / 265551 / 265553).
- 4.11 cast `count(*) OVER() ::int`. Type-cast pass 265724; enqueue
  still failed NOT NULL on `capture_id` (265725 / 265729).
- 4.12 spec correction + `(no email)` render:
  - **265855** list with `(no email)` PASS
  - **265857** queued Ahmad, job `70f3d9ef-4a46-4a1d-affd-999a02d289a9`,
    `capture_id=edc7526c-d3d5-48b6-bb7d-7230b92f1f90` (= capture **#66**,
    most recent interaction of `68880196-…`)
  - **265858** already queued, no second row
  - WF-06 **265894** `mode=trigger` last **Match done**.
    `skip_cached=0`, Cached? false (force bypass). Ledger
    `a42a37be` apollo / `people_match` / `confirmed` / 1.
    Apollo 2599→2598, ledger sum 6→7, records 12→14, queued 0.

---

## 2. Locked decisions (do not reopen)

**Decision 8 REVERSED — owner decision, 27 Aug 2026.** Original:
company-first, because 1 company credit covered ~6 people. Apollo
Basic grants **2,500 credits/month**, so that economy argument no
longer binds. People Enrichment returns the organization block in
the **same** response. Person-by-email is auto; company is derived
from that payload. `organizations/enrich` is a fallback only.
Recorded in `masterplan.md` as a deliberate reversal, not a silent
change.

**Enrichment never overwrites captured identity.** `people.email` /
`full_name` / `title` / `phone` stay as captured. Single exception:
`people.linkedin_url` may fill when NULL **and** Apollo matched on
exact normalized email, with `linkedin_source='apollo'`. A
card-supplied URL stays `'card'`. WF-05 LinkedIn auto-link only
where `linkedin_source='card'`.

**`/flag` is enqueue, not a provider call.** `force=true` bypasses
the 30-day cache only. It never bypasses `apollo_daily_ceiling` or
`apollo_lifetime_ceiling`.

**Match test is `name` non-empty after trim, never `person.id`.**

Do not reopen Imran on `ikhalid@`, Arabic-only names, or `wf04-v5`
phone preference. Those are Phase 3 data.

---

## 3. What read-back found that Cursor reports did not

Rule 2 exists because the implementer report is not the artefact.
Architect read-back of live JSON, the migration catalog, Profile
GET, and executions found defects the Cursor report that claimed
the packet done did not name:

| Finding | What was live | Why the report missed it |
|---|---|---|
| **Probe cost 0, ledger wrote 1** | Row `73fc2831-2231-40f4-9013-8a67d5dc4074` is `confirmed` / `credits_spent=1` for the packet 4.3 probe that cost **0** (Profile remaining unchanged). Lifetime ledger over-counts by 1 from 4.3 onward. | The node wrote a conservative hold of 1 and confirmed it. The report treated the row as spend. |
| **False reconciliation** | Ledger vs Apollo remaining only *looked* matched. The extra +1 on `73fc2831` was offset by the ABSENCE of a ledger row: the packet 4.0 terminal probe called organizations/enrich for huawei.com and spent 1 credit before WF-06 existed, so it was never ledgered. That missing -1 cancels the +1 on 73fc2831. There is no second row to find. Every delta since the 2602 baseline (28 Aug) is exact. Two errors of one cancelled. | A matching pair of totals was quoted as proof. Read-back of Profile GET vs the ledger rows did not. Do not invent a second UUID. Do not edit `73fc2831`. |
| **Migration 023 applied without being named** | Live catalog version `20260828013026`, name **`processing_jobs_enrichment_person_uniq`** (no `023_` prefix). Repo file is `supabase/migrations/023_processing_jobs_enrichment_person_uniq.sql`. 012 remains the historical catalog gap; this is a second naming miss. | #31 landed the SQL. The catalog name was not the file prefix. Named in packet 4.8 so it does not become another 012. |
| **Route type index-based connection swap** | Appending named rule `flag` left `connection[10]` on Unknown type terminal. New fallback was `[11]`. Execs **265428–265446** success, `reply_text` never set. | The new rule was present in JSON. The wire at the old fallback index was not re-checked. 4.9 prove is void. |

Also on `/flag` after the swap: Postgres COUNT arrived as a string.
Flag many? strict number compare threw (265548 / 265551 / 265553).
That is a trap (section 5), not a Cursor-report miss of the same
class as the four above — the executions were errors, visible.

Say this plainly for session 07: **verification is by read-back of
the live artefact, never by the implementer report.**

---

## 4. Measured limitations (not defects to "fix")

- **Apollo reveal rate 2 of 4 real contacts** (28 Aug 2026).
  Enrichment covers roughly half the contact set, not a completion
  layer.
- **Of 2 reveals, 1 carried a `linkedin_url`.**
- **Apollo mints a `person.id` for hollow shells.** The match test
  is `name` non-empty after trim. Packet 4.3 `.example` probe
  returned an id and an empty name.
- **Apollo bills on reveal.** A hollow response costs **0**.
  Architect-measured: Huawei 2604→2603 (1); probe 2603→2603 (0).
- **`num_lead_credits_used` does not move on API enrichment.** Only
  `num_credits_remaining` does (measured 27 Aug: 2605→2604, lead
  used stayed 0). Reconcile against remaining, never the usage
  counter, never an assumed 1.
- **Tavily has no free balance endpoint.** `credits_spent` is **1
  by contract**, not measured. Pay-as-you-go is ON with an **$8
  cap**. An unguarded loop bills real money where Apollo would
  fail closed.

---

## 5. Traps this session proved (carry into `rules.md`)

All four are now in `docs/rules.md` traps (rule 19 already held
activation):

1. **Postgres COUNT arrives as a string.** Strict number compare
   throws. Cast at the SQL boundary (`count(*)::int`). Proven Flag
   many? 265548 / 265551 / 265553.
2. **Switch connections are index-based.** Appending a rule does
   not shift the fallback wire. Re-GET every `connection[i]`.
   Proven Route type 265428–265446.
3. **PUT `active=true` is 400.** Activation is
   `POST /api/v1/workflows/{id}/activate`. Proven packet 4.8 WF-06.
   Do not send `active` on an already-active PUT.
4. **Telegram `text` stores literal `\n` when written that way.**
   Real newlines in the stored parameter. Proven WF-00 Telegram
   owner alert, packet 4.11 (0 real / 4 literal, then 4 real / 0
   literal). Strip `timeSavedMode` from public PUT; it is an
   additional property.

Standing, still true: `$env` and `$getWorkflowStaticData` forbidden;
MCP create is not evidence; public PUT of `binaryMode` is 400;
`.first()` after a Merge; n8n API only on `LNI ` / `LNI-TEST-`.

---

## 6. Architect specification errors, caught by the implementer

Continue the tally. Author and verifier must stay different parties
(`rules.md` §3).

**Phase 0 (session 02 §4) — three:**

1. `$env` / `LNI_OWNER_UUID` as WF-00 owner source.
2. SQL CAST as the empty-owner throw (plan-time fold).
3. Diagnostic write as `error_detail` instead of always `audit_log`.

**Phase 2 (session 04) — none numbered as architect spec errors.**
What that session recorded (012 catalog gap, `image_type`, adapter
envelope) were discoveries against the live system, not a spec that
could not stand. The tally does not invent items.

**Phase 4 — one:**

4. **Packet 4.9 specified `processing_jobs.capture_id` NULL.** The
   column is NOT NULL by design (`architecture.md`; every job traces
   to a capture). Proven execs **265725** and **265729** (NOT NULL
   violation, no reply, no enqueue). Packet 4.12 corrected: anchor
   to the person's most recent `interactions.capture_id`. A person
   with no interaction gets a plain reply; the INSERT does not run.
   Column nullability was not changed.

---

## 7. Data state at close (28 Aug 2026, live read after #33 merge)

Self-identify still `LEAP 2026`. Counts are SQL, not a Cursor
report. Apollo is a free Profile GET
(`include_credit_usage=true`).

| Fact | Value |
|---|---|
| captures | **56** (9 `ready`, 4 `needs_review`, **43 `processing`**, 0 `failed`) |
| max `capture_no` | **70** |
| assets | 59 |
| processing_jobs | 80 |
| people / companies | 8 / 6 |
| interactions | 13 |
| extraction_runs | 22 |
| entity_candidates | 3 (1 accepted Imran merge, **2 pending**) |
| enrichment_records | 14 |
| credit_ledger | 17 rows; `sum(credits_spent)` where status IN (`attempted`,`confirmed`) = **8** (includes the known +1 over-count) |
| queued enrichment | 0 (job `70f3d9ef` succeeded) |
| `apollo_daily_ceiling` | **60** |
| `apollo_lifetime_ceiling` | 2200 |
| `tavily_lifetime_ceiling` | 1000 |
| Apollo `num_credits_remaining` | **2598** |
| Apollo `num_lead_credits_used` | **0** |

Session 05 close was 55 / max 69 / 59 assets / 61 jobs / 6 people.
Delta is Phase 4 (probes, enrichment jobs, capture 70).

**Migrations, live catalog.** `001`–`011`, `013`–`022` with `NNN_`
prefixes. Version `20260828013026` name
`processing_jobs_enrichment_person_uniq` (023 file, unnamed prefix).
012 never applied (history). Forward-only.

**Eleven LNI workflows, GET name-checked 28 Aug 2026.** WF-00b
equality is false because it is inactive (`activeVersionId` null).
That is expected, not a defect. LNI-TEST-2.2 is not in this table.

| WF | id | name | active | versionId | activeVersionId | eq |
|---|---|---|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | LNI WF-00 - Central error handler | true | `5ec180fd-3270-433d-9e03-d0f2ff9ecd44` | same | true |
| 00b | `Q1eMhUF67VAt3T8a` | LNI WF-00b - Credential and connectivity probe | false | `46330598-9abb-422e-817e-ec6ea620321a` | null | false |
| 01 | `ZMYx19qEr72mJoCX` | LNI WF-01 - Telegram ingest router | true | `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a` | same | true |
| 02 | `BV0nukrQdOpDCPe4` | LNI WF-02 - Capture lifecycle | true | `ddb4d858-b100-4a13-a567-b8528cb892c8` | same | true |
| 03 | `k0bPD3GJBNN2EHDB` | LNI WF-03 - Asset processors | true | `852f300b-069e-4763-b97b-3068fbf06a9b` | same | true |
| 04 | `cxyvgBJC1DD8LEbU` | LNI WF-04 - Structured extraction | true | `28510930-2a65-470d-9a29-f8359b0f46f2` | same | true |
| 05 | `Iv0loGijYVH77OGh` | LNI WF-05 - Entity resolution | true | `181a4c32-1406-440d-9f1c-b927d6cf80b1` | same | true |
| 06 | `eNlgt1wk9Z8Nefwy` | LNI WF-06 - Enrichment | **true** | `f6b39538-28ae-4946-ac81-504c9f004c36` | same | true |
| 07 | `AyPtkP8PMFeEdYU9` | LNI WF-07 - Digests | true | `fb9ee1c4-6b40-4064-af22-950b78a45544` | same | true |
| 08 | `QIioJBxuZYJh5R4W` | LNI WF-08 - Query (/ask) | true | `b699e7d6-ecd4-431d-86ff-d61bd1472390` | same | true |
| 09 | `m0lvc9dzpyxLj2hI` | LNI WF-09 - Watchdog | true | `4747cd4f-ea03-451b-bf76-f09e5a6544db` | same | true |

WF-06 is **ACTIVE**. Ceiling is **60**.

---

## 8. Evidence rows that must never be edited

These are proof, not leftovers.

- Ledger **`73fc2831-2231-40f4-9013-8a67d5dc4074`** (`confirmed` / 1
  for a 0-credit probe). Lifetime over-count of 1 starts here.
- Probe people **`ad9c6cde-29be-4909-bac1-f68ac565ff01`**
  (`LNI No-Match Probe`) and **`LNI LI Guard Probe`**
  (`ef59e8fd-bea7-4ebd-b07e-e2cb25039c18`, email null).
- Existing **`enrichment_records`** rows (14 at close). New rows
  from a future WF-06 drain are new evidence, not edits of these.
- Captures **#9** (processing / `close_reason=auto`), **#62**,
  **#63**, **#66**, **#68**, **#69**.
- Jobs **`1564abc3`** (vision) and **`f6a1e703`**.

**Capture #66** (`edc7526c-d3d5-48b6-bb7d-7230b92f1f90`) is now an
FK anchor on enrichment job **`70f3d9ef-4a46-4a1d-affd-999a02d289a9`**
(`force=true`, succeeded). Referenced, not modified.

Also do not auto-merge on name. Do not honour “just merge” on the
two pending `entity_candidates`. Owner decides.

---

## 9. Addendum — Phase 7 initiated (28 Aug)

Owner decision, 28 Aug 2026: remaining pre-event work is **Phase 7,
then 6, then 5**. Not the post-LEAP order in `phases.md` /
`masterplan.md` §6. Recorded here so the next session does not
treat those tables as current.

**Phase 8 (PWA capture surface) is REFUSED pre-event** by the
architect under `masterplan.md` §3 Corollary 1: no phase may
compete with capture reliability. Post-event. Recorded, not
silently dropped.

Packet 7.0 produced `docs/plans/phase-07-plan.md` as PR **#36**.
That PR is **UNREVIEWED** — the architect has not accepted the
plan. No WF-10, no migration, no WF-01 edit in 7.0.

Three items Cursor named as **unsafe before Monday** (plan §N),
not silently weakened:

1. **Pure-voice trigger with no command** — would steal capture
   voices (Corollary 1). `/followup` is the proposed prefix.
2. **Per-file attachment picker** — Telegram `callback_data` is 64
   bytes; two UUIDs do not fit. v1 is Send / Send without
   attachments / Cancel.
3. **WF-01 wire before the 29 Aug gate.** Highest blast radius.
   Frozen until the gate passes.

**Zero-risk owner action:** BotFather `/setcommands` on
`@Leap_NI_bot` for the live command set (`/new` `/done` `/batch`
`/status` `/digest` `/ask` `/flag`). Do **not** add `/followup`
until packet 7.4. Do **not** add `/fix` (silent NoOp, post-event).
Does not touch n8n or WF-01.
