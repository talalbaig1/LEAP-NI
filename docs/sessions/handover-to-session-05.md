# Handover prompt — Session 05 (Phase 3: digests, /ask, watchdog)

Paste this as the first message of the next chat. Assume **no memory** of
session 04.

---

You are the **implementer** (Cursor) for **LEAP-NI**. Architect/verifier is
Claude. Owner is Talal. Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read first, in order: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`, `docs/masterplan.md`,
`docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`, `docs/sessions/session-04-phase-2.md`.

## Role and hard stops

- Docs before implementation (`rules.md` §1). Cause before fix (`§5`).
- **Do not deactivate** WF-01 through WF-05. **Do not restart n8n.**
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
  never the MCP creation response (it auto-assigns ElderWise Postgres).
- stopAndError messages: no comma, quote, or apostrophe (WF-00 redact).
- Do **not** delete capture **#9** (`processing` / `close_reason=auto`).
- Do **not** rewrite vision job `1564abc3`
  (`output_md5=9f830bbd14826866c12ee38b0f50fa5a`,
  `last_transition_at=2026-08-26 21:10:09.478715+00`).
- Do **not** auto-merge on name. Exact `email_normalized` or exact
  `linkedin_url_normalized` only.
- Do **not** honour a request to “just merge the two Imrans”. There is a
  pending `entity_candidates` row for the owner.
- Owner is CCIE: short, to the point.

## This is Phase 3

**Timing:** 28–29 Aug. **Should be live 30 Aug.** The **29 August gate
does not move.** If Phases 0–3 are not passing on the owner’s actual
phone on 29 Aug, Phase 4 (enrichment) is dropped post-event and Phase 3
is still launch-blocking.

Build, in order, only what `phases.md` Phase 3 names:

1. **WF-07 digests** — 10 PM close, 7 AM briefing, `/digest` on demand.
   Both schedules **explicitly `Asia/Riyadh`**. Prove by observed
   execution timestamps, not by reading the cron string. A UTC container
   fires 7 AM at 10 AM Riyadh.
2. **WF-08 `/ask`** — natural-language query over real captured data.
3. **WF-09 watchdog** — stuck-job alerts **independent of the digest**.
   Launch-blocking. The owner chose low-confidence-only notification, so
   if the 10 PM digest does not fire on the 31st there is otherwise no
   signal at all.

Do **not** start WF-06 enrichment, `/fix`, album auto-detect, or a
provider benchmark. Those are post-event. GPT-4o already ships without a
benchmark — `rules.md` §7 rule 14 is knowingly not honoured; do not
reopen it.

**WF-06 position today:** WF-05 ends at a NoOp named
**`WF-06 dispatch (not yet)`**. Leave it. Do not call WF-06.

## Live workflows (read-back 27 Aug 2026 05:15Z)

versionId = activeVersionId on every active workflow. Do not PUT these
unless Phase 3 requires it, and then GET-name-check first.

| WF | id | active | versionId |
|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | true | `6eb149ae-296d-4e1a-833a-d0c5ab01c085` |
| 00b | `Q1eMhUF67VAt3T8a` | false | `46330598-9abb-422e-817e-ec6ea620321a` |
| 01 | `ZMYx19qEr72mJoCX` | true | `b4694083-b89c-4786-a37a-20686427574c` |
| 02 | `BV0nukrQdOpDCPe4` | true | `ddb4d858-b100-4a13-a567-b8528cb892c8` |
| 03 | `k0bPD3GJBNN2EHDB` | true | `fe7f3262-a4ab-4fa9-b0d4-f804a7c2679d` |
| 04 | `cxyvgBJC1DD8LEbU` | true | `ad545cea-74ef-4145-afc5-efcffb8e17e9` |
| 05 | `Iv0loGijYVH77OGh` | true | `46e5cc1d-b056-4956-acdd-9d4b78e19e24` |

Settings on 01–05: `availableInMCP: true`, `errorWorkflow` = WF-00,
`executionTimeout: 300`, timezone `Asia/Riyadh`. Whisper `language` is
**absent** on WF-03 `OpenAI transcribe`. Keep it absent.

Dispatch already wired, best-effort:
`WF-02 Call WF-03` → `WF-03 Call WF-04` → `WF-04 Call WF-05`.
`waitForSubWorkflow: false`, `onError: continueRegularOutput`.
This n8n build will not publish a parent that references an unpublished
child — activate the child first.

WF-01 is the **only** Telegram sender. WF-07/09 must not add a second
send path without an explicit architect decision; if they need to tell
the owner, they should return a contract WF-01 already understands, or
the architect will specify.

## Current data state (27 Aug 2026, after #61)

| Fact | Value |
|---|---|
| assets / distinct `telegram_file_unique_id` / `stored` | 47 / 47 / 47 |
| captures | 47 (43 `processing`, 3 `ready` #58 #60 #61, 1 `needs_review` #59) |
| capture #9 | `processing`, `close_reason=auto` — do not delete |
| people | 3 |
| companies | 2 (Qatar Airways, BTGroup) |
| interactions | 4 |
| entity_candidates | 1, `decision=pending` |
| extraction_runs | 13 (`wf04-v1` = 8, `wf04-v2` = 5) |

People: two **Imran Khalid** / **عمران خالد** rows (architect-accepted
OCR split) and **Amer Mohamed Saadi Khater** / **عامر محمد سعدي خاطر**
(#61). #61 company printed **BTGroup**; email domain is hasoub.com;
`companies.domain` is null. **Not a defect.** Enrichment (September)
may care. Do not “fix” it in Phase 3.

Pending candidate `affab30d-ef9c-4236-b610-bbcedf76c680` points at one
Imran row; reasons include `same_full_name`, `same_company`, and
`emails_differ: ikhaild@… vs ikhalid@…`. Owner decides. Do not auto-accept.

Older `processing` captures have **no** `entity_resolution` job. WF-05
will not sweep them. Leave them unless the architect orders a backfill.

## Named Phase 3 item — requeue has no backoff

A failed provider call with `attempt_count < 3` returns the job to
`queued` **immediately**. Packet 3.3 moved the delay onto the worker
claim (1 and 5 minutes; ceiling 3). **The 20 minutes is deleted.**
There is no Wait in the 300 s execution, by design.

This was safe in Phase 2 because workflows ran on dispatch. WF-09 is
the kicker, not the delay. Measure staleness from
`processing_jobs.last_transition_at`, never `created_at` (migration
`010`). A twice-failed job is poison — surface it, do not spend a
third retry.

## Hard-won traps (do not re-learn)

1. **Filesystem-v2.** Code can create binaries, **cannot read** them
   (`getBinaryStream` et al. deny). Pins are inline base64 — a different
   program. Size is HEAD `Content-Length`; Telegram `file_size` must
   agree.
2. **Never `$json` after I/O.** Source every field from the **named**
   node that produced it. Postgres `alwaysOutputData` emits `{}` on zero
   rows.
3. **`queryReplacement`** is one expression → one array. Mixed CSV /
   `.join()` binds as a single `$1`.
4. **Zero-row UPDATE is `{success:true}`.** Gate before any send.
5. **WF-02 owns what the owner is told; WF-01 only sends.**
   `reply_text` non-empty means send; empty means silent. Do not add a
   second field that must stay in agreement.
6. **`processing_jobs_asset_job_uniq`** is a **partial unique index**,
   not a table constraint. `ON CONFLICT ON CONSTRAINT` will not run.
   Capture-level jobs (`extraction`, `entity_resolution`) have
   `asset_id` NULL and are outside that index.
7. **Person requires non-null `full_name`.** `name_original_script`
   alone is not identity. Do not bring back a demonstrative wordlist as
   the primary defence.
8. **Summary is required** when `[TRANSCRIPT]` or `[TYPED_NOTE]` has
   text. “Nullable beats guessed” plus a nullable schema produced
   obedient nulls while the transcript sat in the prompt.
9. **OCR-split emails** (transposition) create two people. Exact-email
   auto-link will not merge them. `entity_candidates` must still fire
   when `full_name` and `company_id` match and emails differ.
10. **MCP `apply_migration` writes no `schema_migrations` row on
    failure.** `012` never catalogued because `current_setting` without
    `missing_ok` raised. Do not treat file count as catalog count.
11. **Images are not classified at capture.** `kind='photo'` means
    unclassified. WF-03’s `image_type` discriminator is the only
    classifier. A `business_card`-only vision branch would never fire.
12. **Provider envelopes stay in `output.raw`.** WF-04 reads
    `output.result` only.

## E2E reference (accepted)

Capture **#61**, 27 Aug 2026. Card + Arabic voice + `/done`. Receipt
`✓ Capture #61 saved · 2 items`. Executions: WF-01 `253931` → WF-02
`253932` → WF-03 `253933` → WF-04 `253936` → WF-05 `253937`. Four jobs
succeeded. `prompt_version=wf04-v2`. `flag_reasons={}`. Capture
`ready`, `close_reason=explicit`. Wall clock **20.15 s**.

## Owner actions outstanding

- Decide the pending Imran Khalid `entity_candidates` row.
- Keep the production bot on. Do not rotate n8n or Telegram credentials
  during Phase 3 unless the architect says so.

## What you build next

Only after you have read the documents above: Phase 3 spec in
`workflows.md` for WF-07, WF-08, WF-09, then implement in a new packet
the architect issues. Do not invent scope. The 29 August gate does not
move.
