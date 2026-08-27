# Handover prompt — Session 06 (event hardening; Phase 3 closed)

Paste this as the first message of the next chat. Assume **no memory** of
session 05.

---

You are the **implementer** (Cursor) for **LEAP-NI**. Architect/verifier is
Claude. Owner is Talal. Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read first, in order: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`, `docs/masterplan.md`,
`docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`, `docs/sessions/session-05-phase-3.md`.

## Role and hard stops

- Docs before implementation (`rules.md` §1). Cause before fix (`§5`).
- **Verification is by read-back of the live artefact, never by the
  implementer report** (`rules.md` §4 / rule 2). Session 05 recorded
  defects the report missed, and an architect pass that execution
  read-back reversed. Indirect evidence (unchanged row counts, provider
  text on an errored node) is not a finished branch.
- **Do not deactivate** any LNI workflow. **Do not restart n8n.**
  **Do not touch ElderWise.** `$env` and `$getWorkflowStaticData` are
  forbidden.
- n8n API only on names starting `LNI ` or `LNI-TEST-`. GET name, then
  act. Never list-and-act.
- Never commit Telegram IDs, project refs, owner UUIDs, keys, or
  connection strings. Real values only in gitignored
  `docs/environment.local.md`.
- Public PUT of `settings.binaryMode` is 400. Strip it. PUT without
  `active` on an already-active workflow.
- Postgres Leap-NI credential must stay bound. Proof = self-identifying
  execution (`SELECT name FROM public.events WHERE name = 'LEAP 2026'`),
  never the MCP creation response.
- stopAndError messages: no comma, quote, or apostrophe (WF-00 redact).
- Owner is CCIE: short, to the point.

## Do not touch (locked evidence)

- Capture **#9** (`processing` / `close_reason=auto`).
- Vision job `1564abc3`
  (`output_md5=9f830bbd14826866c12ee38b0f50fa5a`,
  `last_transition_at=2026-08-26 21:10:09.478715+00`).
- Job `f6a1e703`.
- Captures **#62** / **#63** (Arabic-only / two-sided evidence).
- Capture **#66** (multi-phone, `wf04-v4` stored phone null).
- Captures **#68** / **#69** (QR ceiling: nameless `wave` vs printed
  details). Do not change the WF-03 vision prompt on the back of #68.
- Do **not** auto-merge on name. Exact `email_normalized` or exact
  `linkedin_url_normalized` only.
- Do **not** honour a request to “just merge” pending
  `entity_candidates`. Two person rows are `pending` (latin field
  disagreement; phone). Owner decides.

## Phase 3 is closed. Do not start Phase 4.

**Timing:** 29 August gate **does not move.** Event `starts_at` is
30 Aug. Session 06 is hardening and operations, not enrichment.

Do **not** start WF-06, `/fix`, `/flag`, album auto-detect, or a
provider benchmark. Those are post-event. GPT-4o already ships
without a benchmark — `rules.md` §7 rule 14 is knowingly not
honoured; do not reopen it.

**WF-06 position:** WF-05 ends at a NoOp named
**`WF-06 dispatch (not yet)`**. Leave it. Do not call WF-06.

Contact and vcard ingest are deferred post-event (new
`people.source_type`; WF-01 and WF-02 both ACTIVE).

Do not invent scope. Wait for an architect packet.

## Live workflows (read-back 27 Aug 2026 10:51Z)

versionId = activeVersionId on every active workflow. GET-name-check
before any PUT. Do not PUT unless a packet requires it.

| WF | id | active | versionId |
|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | true | `6eb149ae-296d-4e1a-833a-d0c5ab01c085` |
| 00b | `Q1eMhUF67VAt3T8a` | false | `46330598-9abb-422e-817e-ec6ea620321a` |
| 01 | `ZMYx19qEr72mJoCX` | true | `a5789a7e-d07e-4462-b309-ff225061209e` |
| 02 | `BV0nukrQdOpDCPe4` | true | `ddb4d858-b100-4a13-a567-b8528cb892c8` |
| 03 | `k0bPD3GJBNN2EHDB` | true | `852f300b-069e-4763-b97b-3068fbf06a9b` |
| 04 | `cxyvgBJC1DD8LEbU` | true | `28510930-2a65-470d-9a29-f8359b0f46f2` |
| 05 | `Iv0loGijYVH77OGh` | true | `b4be6046-6c49-42d6-94d1-9832dfa3275d` |
| 07 | `AyPtkP8PMFeEdYU9` | true | `fb9ee1c4-6b40-4064-af22-950b78a45544` |
| 08 | `QIioJBxuZYJh5R4W` | true | `b699e7d6-ecd4-431d-86ff-d61bd1472390` |
| 09 | `m0lvc9dzpyxLj2hI` | true | `4747cd4f-ea03-451b-bf76-f09e5a6544db` |

Settings on 01–05 and 07–09: `availableInMCP: true`, `errorWorkflow` =
WF-00, `executionTimeout: 300`, timezone `Asia/Riyadh`. Whisper
`language` is **absent** on WF-03 `OpenAI transcribe`. Keep it absent.

WF-04 live prompt_version **`wf04-v5`** (phone preference). Do not
bump it without a packet.

Dispatch already wired, best-effort:
`WF-02 Call WF-03` → `WF-03 Call WF-04` → `WF-04 Call WF-05`.
`waitForSubWorkflow: false`, `onError: continueRegularOutput`.
`/ask` and `/digest` use `waitForSubWorkflow: true`.

WF-01 is the **only** Telegram sender. Contact and vcard replies live
on WF-01. WF-07/09 scheduled sends are the parallel Telegram + Gmail
standard (`.first()` after Merge).

WF-02 enqueue is unchanged:
`CASE WHEN a.kind = 'audio' THEN 'transcription' ELSE 'card_vision' END`
with no mime filter. That is why `.vcf` is declined at WF-01.

## Current data state (27 Aug 2026, after vcard exec 256753)

| Fact | Value |
|---|---|
| captures | 55 (8 `ready`, 4 `needs_review`, 43 `processing`, 0 `failed`) |
| assets | 59 |
| processing_jobs | 61 |
| people / companies | 6 / 6 |
| interactions | 12 |
| extraction_runs | 21 |
| entity_candidates | 3 (1 accepted Imran merge, 2 pending person) |
| max `capture_no` | 69 |

Older `processing` captures have **no** `entity_resolution` job.
WF-05 will not sweep them. Leave them unless the architect orders a
backfill.

## Hard-won traps (do not re-learn)

1. **Filesystem-v2.** Code can create binaries, **cannot read** them.
2. **Never `$json` after I/O.** Named node. Postgres `alwaysOutputData`
   emits `{}` on zero rows.
3. **`queryReplacement`** is one expression → one array.
4. **Zero-row UPDATE is `{success:true}`.** Gate before any send.
   Empty-item Load digest is not a zero-count report.
5. **WF-02 owns what the owner is told; WF-01 only sends.**
6. **`.first()` after a Merge, never `.item`.**
7. **REST jsCode backslashes must be doubled**, or write patterns with
   none. Single `\b` is a backspace.
8. **Person requires non-null `full_name`.** Arabic-only `full_name` is
   accepted identity. `name_original_script` alone is not.
9. **OCR-split emails create two people.** Exact-email will not merge
   them. Name similarity never auto-merges.
10. **Unchanged row counts do not prove a decline branch.** Contact
    and vcard both store nothing. Prove from the execution (`branch`,
    last node, reply text, mime).
11. **Parse the envelope that WF-01 sends**, not provider text on an
    errored node. Responses `content` is an array.
12. **MCP create is not evidence.** REST PUT of settings and
    credentials, then self-identifying execution.

## Phase 3 reference (accepted)

- WF-07 / WF-08 / WF-09 built, ACTIVE, proven with real data.
- Vcard: exec **256753**, `branch=vcard`, `mime_type` `text/vcard`,
  `.vcf`, reply `Contact files are not supported. Send a photo of the
  card or a voice note instead.` Counts 55 / 59 / 61.
- QR: #68 `other` / #69 `business_card`. Operational rule in
  `workflows.md` / `architecture.md`.
- Locked decisions: pre-event scope; Imran on `ikhalid@`; Arabic-only
  names accepted; `wf04-v5` phone preference.

## Overnight clocks (report, do not "fix" zeros)

| Local (Riyadh) | UTC | What |
|---|---|---|
| 22:00 27 Aug | 19:00Z | WF-07 day close — observe `startedAt` |
| 23:41 27 Aug | 20:41Z | WF-09 Silent clean — poison ages out |
| 07:00 28 Aug | 04:00Z | WF-07 briefing — observe `startedAt` |

Counts reading zero is expected (`events.starts_at` 30 Aug). The
**clock** is what is being proved. Confirm both workflows still
ACTIVE. Do not deactivate.

## Owner actions outstanding

- Decide the two pending person `entity_candidates` rows. The system
  will not decide.
- Keep the production bot on. Do not rotate n8n or Telegram
  credentials unless the architect says so.
- Ingest path at the event: photo of the card, or a voice note.
  Shared contacts and `.vcf` files are declined. QR: photograph if
  details are readable; otherwise scan and screenshot the contact
  page, or record a voice note.

## What you build next

Nothing unless the architect issues a packet. The 29 August gate
does not move. Phase 4 is post-event.
