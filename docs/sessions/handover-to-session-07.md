# Handover prompt — Session 07 (event hardening; Phase 4 closed)

Paste this as the first message of the next chat. Assume **no memory** of
session 06.

---

You are the **implementer** (Cursor) for **LEAP-NI**. Architect/verifier is
Claude. Owner is Talal. Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read first, in order: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`, `docs/masterplan.md`,
`docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`, `docs/sessions/session-06-phase-4.md`,
`docs/sessions/cursor-handover-session-07.md`.

Then read **PR #36 / `docs/plans/phase-07-plan.md`**. That plan is
**UNREVIEWED**. The architect has not accepted it. Session 07 reads
it **before any Phase 7 build packet is issued**. Do not implement
from it until a packet says so.

## Role and hard stops

- Docs before implementation (`rules.md` §1). Cause before fix (`§5`).
- **Verification is by read-back of the live artefact, never by the
  implementer report** (`rules.md` §4 / rule 2). Session 06 recorded
  a 0-credit probe whose ledger wrote 1, a false reconciliation where
  two off-by-ones cancelled, migration 023 applied without the `023_`
  catalog name, and a Switch connection swap that made `/flag` a
  silent success. Indirect evidence is not a finished branch.
- **Do not deactivate** any LNI workflow. **Do not restart n8n.**
  **Do not touch ElderWise.** `$env` and `$getWorkflowStaticData` are
  forbidden.
- n8n API only on names starting `LNI ` or `LNI-TEST-`. GET name, then
  act. Never list-and-act.
- Never commit Telegram IDs, project refs, owner UUIDs, keys, or
  connection strings. Real values only in gitignored
  `docs/environment.local.md`.
- Public PUT of `settings.binaryMode` is 400. Strip it. Also strip
  `timeSavedMode` (additional property). PUT without `active` on an
  already-active workflow. Activation of an inactive workflow is
  `POST /api/v1/workflows/{id}/activate` — PUT `active=true` is 400.
- Postgres Leap-NI credential must stay bound. Proof = self-identifying
  execution (`SELECT name FROM public.events WHERE name = 'LEAP 2026'`),
  never the MCP creation response.
- stopAndError messages: no comma, quote, or apostrophe (WF-00 redact).
- **WF-01 is FROZEN until the 29 Aug gate passes.** No Route type
  append, no callback wire, no `reply_markup` on the shared send.
- Owner is CCIE: short, to the point.

## Pre-event remaining work (owner decision, 28 Aug 2026)

Build order is **fixed: Phase 7, then 6, then 5.**

- **Phase 8 (PWA capture surface) is REFUSED pre-event** by the
  architect under `masterplan.md` §3 Corollary 1: no phase may
  compete with capture reliability. Post-event. Recorded, not
  silently dropped.
- **Phase 5 goes LAST** of the three. It requires GRANT SELECT to
  `authenticated`, which finally exercises 16 RLS policies that
  have never been evaluated (session 02). It gets its own
  verification pass. Do not GRANT early.
- **Phase 7 constraints are binding** (`masterplan.md` §4 decision
  12 and packet 7.0):
  1. No auto-send. The system drafts; the owner taps Send.
  2. Confirm message shows the full recipient address, the subject,
     the body, and every attachment filename.
  3. CC the owner's own address on every send.
  4. Attachments only from `lni-assets` assets already linked to
     that person's captures.
- **PR #36 is an UNREVIEWED plan.** Do not treat it as accepted
  spec. Wait for the architect's packet after read-back.

## Do not touch (locked evidence)

- Ledger **`73fc2831-2231-40f4-9013-8a67d5dc4074`** (`confirmed` / 1
  for a 0-credit call). Do not “fix” the over-count.
- Probe people **`ad9c6cde-…`** (LNI No-Match Probe) and **LNI LI
  Guard Probe**. Do not edit them.
- Existing **`enrichment_records`**. Do not rewrite payloads.
- Capture **#9** (`processing` / `close_reason=auto`).
- Vision job `1564abc3`. Job `f6a1e703`.
- Captures **#62** / **#63** (Arabic-only / two-sided).
- Capture **#66** (`edc7526c-…`). Multi-phone evidence, **and** now
  the FK on enrichment job `70f3d9ef-…`. Referenced, not modified.
- Captures **#68** / **#69** (QR ceiling). Do not change the WF-03
  vision prompt on the back of #68.
- Do **not** auto-merge on name. Exact `email_normalized` or exact
  `linkedin_url_normalized` where `linkedin_source='card'` only.
- Do **not** honour a request to “just merge” pending
  `entity_candidates`. Two person rows are `pending`. Owner decides.

## Phase 4 is closed. Do not start new enrichment features.

WF-06 is **ACTIVE**, ceiling **60**, proven. `/flag` enqueues
`force=true`; WF-06 drains `*/15`. Tavily is the company fallback
only. Decision 8 is reversed (person-by-email auto; company from the
same Apollo response) — owner decision, 2,500/mo credits removed the
economy argument. Do not reopen it.

Session 07 continues from PR **#36** (unreviewed Phase 7 plan) after
the architect reads it. Do not invent Phase 7 nodes before that
packet. **WF-01 stays frozen** until the 29 Aug gate.

Do **not** build `/fix`, album auto-detect, a provider benchmark,
contact/vcard ingest, or an `/ask` relevance floor. Those stay CUT
(see What remains). GPT-4o already ships without a benchmark —
`rules.md` §7 rule 14 is knowingly not honoured; do not reopen it.

Do not invent scope. Wait for an architect packet.

## Live workflows (read-back 28 Aug 2026, after #33 merge)

versionId = activeVersionId on every **active** workflow. GET-name-check
before any PUT. Do not PUT unless a packet requires it.

| WF | id | active | versionId | activeVersionId | eq |
|---|---|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | true | `5ec180fd-3270-433d-9e03-d0f2ff9ecd44` | same | true |
| 00b | `Q1eMhUF67VAt3T8a` | **false** | `46330598-9abb-422e-817e-ec6ea620321a` | **null** | **false** (expected) |
| 01 | `ZMYx19qEr72mJoCX` | true | `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a` | same | true |
| 02 | `BV0nukrQdOpDCPe4` | true | `ddb4d858-b100-4a13-a567-b8528cb892c8` | same | true |
| 03 | `k0bPD3GJBNN2EHDB` | true | `852f300b-069e-4763-b97b-3068fbf06a9b` | same | true |
| 04 | `cxyvgBJC1DD8LEbU` | true | `28510930-2a65-470d-9a29-f8359b0f46f2` | same | true |
| 05 | `Iv0loGijYVH77OGh` | true | `181a4c32-1406-440d-9f1c-b927d6cf80b1` | same | true |
| 06 | `eNlgt1wk9Z8Nefwy` | **true** | `f6b39538-28ae-4946-ac81-504c9f004c36` | same | true |
| 07 | `AyPtkP8PMFeEdYU9` | true | `fb9ee1c4-6b40-4064-af22-950b78a45544` | same | true |
| 08 | `QIioJBxuZYJh5R4W` | true | `b699e7d6-ecd4-431d-86ff-d61bd1472390` | same | true |
| 09 | `m0lvc9dzpyxLj2hI` | true | `4747cd4f-ea03-451b-bf76-f09e5a6544db` | same | true |

Settings on 01–09: `availableInMCP: true`, `errorWorkflow` = WF-00
(except WF-00 itself), `executionTimeout: 300`, timezone
`Asia/Riyadh`. Whisper `language` is **absent** on WF-03 `OpenAI
transcribe`. Keep it absent.

WF-04 live prompt_version **`wf04-v5`**. Do not bump it without a
packet.

`lni_config.apollo_daily_ceiling` = **60**. Lifetime Apollo 2200,
Tavily 1000.

Dispatch already wired, best-effort:
`WF-02 Call WF-03` → `WF-03 Call WF-04` → `WF-04 Call WF-05`.
`waitForSubWorkflow: false`, `onError: continueRegularOutput`.
`/ask` and `/digest` use `waitForSubWorkflow: true`.
WF-05 **enqueues** enrichment; it does not call WF-06.
WF-06 drains `*/15`. `/flag` enqueues `force=true` on WF-01 only.

WF-01 is the **only** Telegram sender for owner commands. WF-07/09
scheduled sends are the parallel Telegram + Gmail standard
(`.first()` after Merge).

WF-02 enqueue is unchanged:
`CASE WHEN a.kind = 'audio' THEN 'transcription' ELSE 'card_vision' END`
with no mime filter. That is why `.vcf` is declined at WF-01.

## Current data state (28 Aug 2026, live SQL + free Apollo Profile GET)

| Fact | Value |
|---|---|
| captures | 56 (9 `ready`, 4 `needs_review`, 43 `processing`, 0 `failed`) |
| assets | 59 |
| processing_jobs | 80 |
| people / companies | 8 / 6 |
| interactions | 13 |
| extraction_runs | 22 |
| entity_candidates | 3 (1 accepted Imran merge, 2 pending person) |
| enrichment_records | 14 |
| credit_ledger | 17 rows |
| queued enrichment | 0 |
| max `capture_no` | 70 |
| Apollo `num_credits_remaining` | 2598 |
| Apollo `num_lead_credits_used` | 0 |

Older `processing` captures have **no** `entity_resolution` job.
WF-05 will not sweep them. Leave them unless the architect orders a
backfill or an exclude-from-digest decision.

Live catalog: `001`–`011`, `013`–`022` prefixed; 023 applied as
`processing_jobs_enrichment_person_uniq` (no `023_` in the catalog
name). Do not re-apply 012.

## Operating rules (do not re-learn)

- Postgres is state. Never `$env`, never `$getWorkflowStaticData`.
- MCP create binds ElderWise Postgres. Self-identify, then REST PUT
  of settings and credentials. Create response is not evidence.
- n8n API only against `LNI ` / `LNI-TEST-`. Never restart the
  shared container. Never deactivate to "test".
- `credits_spent` for Apollo is the measured delta in
  `num_credits_remaining`. Never `num_lead_credits_used`. Never an
  assumed 1. Tavily is 1 by contract.
- Match test is `name`, never Apollo `person.id`.
- Enrichment writes `enrichment_records` only, plus the LinkedIn-null
  fill. Never overwrite captured email / name / title / phone.
- `/flag` is enqueue. Capture_id = most recent interaction. Column
  stays NOT NULL.

## Hard-won traps (full list)

1. **Filesystem-v2.** Code can create binaries, **cannot read** them.
2. **Never `$json` after I/O.** Named node. Postgres `alwaysOutputData`
   emits `{}` on zero rows.
3. **`queryReplacement`** is one expression → one array.
4. **Zero-row UPDATE is `{success:true}`.** Gate before any send.
   Empty-item Load digest is not a zero-count report.
5. **WF-02 owns what the owner is told; WF-01 only sends** (except
   `/flag` / contact / vcard replies that live on WF-01).
6. **`.first()` after a Merge, never `.item`.**
7. **REST jsCode backslashes must be doubled**, or write patterns with
   none. Single `\b` is a backspace.
8. **Person requires non-null `full_name`.** Arabic-only `full_name` is
   accepted identity. `name_original_script` alone is not.
9. **OCR-split emails create two people.** Exact-email will not merge
   them. Name similarity never auto-merges.
10. **Unchanged row counts do not prove a decline branch.** Prove from
    the execution (`branch`, last node, reply text, mime).
11. **Parse the envelope that WF-01 sends**, not provider text on an
    errored node. Responses `content` is an array.
12. **MCP create is not evidence.** REST PUT of settings and
    credentials, then self-identifying execution.
13. **Postgres COUNT arrives as a string.** Cast at the SQL boundary
    (`count(*)::int`). Strict number IF throws otherwise.
14. **Switch connections are index-based.** Appending a rule does not
    move the fallback wire. Re-GET every `connection[i]`.
15. **PUT `active=true` is 400.** `POST /activate`. Do not send
    `active` on an already-active PUT. Strip `binaryMode` and
    `timeSavedMode`.
16. **Telegram `text` stores literal `\n`** unless the stored
    parameter contains real newlines.

## Phase 4 reference (accepted)

- WF-06 built, bound to Leap-NI Postgres + Apollo Leap-NI (+ Tavily
  Leap-NI on the fallback path), self-identifying, **ACTIVE**,
  ceiling 60.
- Person-by-email auto (Decision 8 reversed, owner, 27 Aug 2026).
- Tavily company fallback only. $8 pay-as-you-go cap.
- `/flag` proven: 265855 `(no email)`, 265857 queue job `70f3d9ef`
  on capture **#66**, 265858 already queued, WF-06 265894 force
  drain Match done, ledger `a42a37be`, Apollo 2599→2598.
- Reveal rate 2 of 4. Hollow costs 0. `person.id` is not a match.

## What remains (state it plainly)

- **43 captures at `processing`.** Replay them, or exclude them from
  digest counts. Phase 3 decision, **still open**.
- **2 pending `entity_candidates`** (Joudeh spelling, phone). Owner.
  The system will not decide.
- **WF-03 requeue has no backoff.** WF-06 has it; WF-03 does not.
  Named since Phase 2; still true.
- **Supabase hardening.** Disable public signup, delete unconfirmed
  auth user `7bf179a8`, re-enable Confirm email. Owner.
  (`masterplan.md` items 9–11.)
- **RLS re-proof when Phase 5 grants SELECT.** Phase 5. Policies are
  correct by inspection and inert until grants exist.
- **Deliberately CUT and staying cut:** `/fix`, album auto-detect,
  provider benchmark, contact/vcard ingest, `/ask` relevance floor.

## Owner actions outstanding

- Decide the two pending person `entity_candidates`.
- Signup / Confirm email / delete `7bf179a8`.
- **BotFather `/setcommands`** on `@Leap_NI_bot` (zero-risk; does
  not touch n8n). Live set only: `/new` `/done` `/batch` `/status`
  `/digest` `/ask` `/flag`. Not `/followup` until 7.4. Not `/fix`.
- Keep the production bot on. Do not rotate n8n or Telegram
  credentials unless the architect says so.
- Ingest path at the event: photo of the card, or a voice note.
  Shared contacts and `.vcf` files are declined. QR: photograph if
  details are readable; otherwise scan and screenshot the contact
  page, or record a voice note.
- Enrichment covers roughly half the contact set. `/flag` a person
  the auto-guard skipped. Result within 15 minutes. Do not expect
  every hollow Apollo shell to become a reveal.

## What you build next

Nothing until the architect issues a packet after reading PR #36.
Phase 4 is closed. Remaining pre-event order is **7, then 6, then
5**. Phase 8 is refused pre-event. WF-01 is frozen until the 29 Aug
gate.
