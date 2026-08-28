# Handover prompt — Session 08 (29 Aug gate; 7.4 is conditional)

Paste this as the first message of the next chat. Assume **no memory** of
session 07.

---

You are the **implementer** (Cursor) for **LEAP-NI**. Architect/verifier is
Claude. Owner is Talal. Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read first, in order: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`, `docs/masterplan.md`,
`docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`, `docs/sessions/session-06-phase-4.md`,
`docs/sessions/session-07-phase-7.md`,
`docs/plans/phase-07-plan.md`.

The Phase 7 plan is on `main` (squash-merge PR **#38** `952ab05`).
PR **#36** is closed as superseded. Do not reopen it.

## Role and hard stops

- Docs before implementation (`rules.md` §1). Cause before fix (`§5`).
- **Verification is by read-back of the live artefact, never by the
  implementer report** (`rules.md` §4 / rule 2). Session 07 recorded
  an attachment path **reported as built while non-functional**. Cause
  in 7.3-R: "I noticed and shipped anyway." A green node is not a
  sent message.
- **Do not deactivate** any LNI workflow. **Do not restart n8n.**
  **Do not touch ElderWise.** `$env` and `$getWorkflowStaticData` are
  forbidden.
- n8n API only on names starting `LNI ` or `LNI-TEST-`. GET name, then
  act. Never list-and-act.
- Never commit Telegram IDs, project refs, owner UUIDs, keys, or
  connection strings. Real values only in gitignored
  `docs/environment.local.md`.
- Public PUT of `settings.binaryMode` is 400. Strip it. Also strip
  `timeSavedMode`. PUT without `active` on an already-active workflow.
  Activation of an inactive workflow is
  `POST /api/v1/workflows/{id}/activate` — PUT `active=true` is 400.
- Postgres Leap-NI credential must stay bound. Proof = self-identifying
  execution (`SELECT name FROM public.events WHERE name = 'LEAP 2026'`),
  never the MCP creation response.
- stopAndError messages: no comma, quote, or apostrophe (WF-00 redact).
- Owner is CCIE: short, to the point. User-facing replies are **one**
  copy-pasteable fenced block.

## 7.4 is conditional on the 29 August gate

**Hard statement:** do **not** wire WF-01, do **not** activate WF-10,
do **not** build the voice path, unless a packet issued **after** the
29 Aug gate says so. If the gate fails, stop feature work and harden
capture. Finishing Phase 7 is not a reason to touch the hottest path.

Until that packet:

- **WF-10 stays INACTIVE.** id `D9PRjbZMQxe9ESVW`. Never
  `POST /activate`.
- **WF-01 stays FROZEN.** id `ZMYx19qEr72mJoCX`. versionId at 7.3c
  close: `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a`. Unexpected change
  means someone PUT without a packet.

When 7.4 **is** issued, Switch-index assertion (session 06 trap, 4.9
void prove):

- Named Route type output **followup** is **appended** after `flag`.
- Do **not** renumber outputs 0–10.
- After the PUT, **`connection[11]` is followup**.
- **`connection[12]` is the re-wired fallback** (Unknown type).
- Re-GET **every** `connection[i]`. Appending a named rule does not
  move the old fallback wire.

`source=voice` is a **non-functional stub** pending 7.4. Declared in
`workflows.md`. Do not build it in a different packet.

## Schema (024 / 025)

- `024_follow_ups_email_draft` — additive email-draft columns on
  `follow_ups` + `bot_state` awaiting-followup columns. Does not
  alter `follow_ups_status_check`.
- `025_follow_ups_cancelled_state` — adds `cancelled` to
  `follow_ups_draft_state_check`. Does not remove values. Does not
  alter `follow_ups_status_check`.
- `draft_state`: `draft` \| `awaiting_voice` \| `awaiting_confirm` \|
  `sending` \| `sent` \| `failed` \| `cancelled`.
- `status` stays `open` \| `done` \| `cancelled`. Mapping: awaiting
  confirm = `open`; sent = `done`; cancel = both `cancelled`; Gmail
  or attachment fail = `open` + `draft_state='failed'`.
- Catalog 023 is still `processing_jobs_enrichment_person_uniq` (no
  `023_` prefix). 012 never applied. Forward-only.

## Pre-event remaining work (owner decision, 28 Aug 2026)

Build order is **fixed: Phase 7 (7.4 only, gate-conditional), then 6,
then 5.** Phase 8 PWA is REFUSED pre-event (`masterplan.md` §3
Corollary 1). Phase 5 last (GRANT SELECT exercises 16 RLS policies
never evaluated).

Phase 7 constraints still binding (`masterplan.md` §4 decision 12):

1. No auto-send. The system drafts; the owner taps Send.
2. Confirm shows full recipient address, subject, body, every
   attachment filename.
3. CC the owner's own address on every send.
4. Attachments only from `lni-assets` already linked to that
   person's captures.
5. No partial send. Any claimed attachment GET failure fails the
   draft. Gmail does not run.

## Do not touch (locked evidence)

**Phase 7 — none of these are to be edited or deleted.**

- follow_ups **`2ea079a3-c6b5-46c5-9d38-ca4c89722154`** (no-attach
  send, Gmail `1a0479d97b821c01`).
- follow_ups **`e5bf5982-1cfb-4779-8d8e-4c40fac132f8`** (2-attachment
  send, Gmail `1a047bbc15bc3b46`, sizes 232097 and 188417).
- follow_ups **`dabd0a78-190d-4c27-8c25-bd5ffec8c070`** (cancelled).
- follow_ups **`a7596fde-47be-425b-bde5-5a9343804ee0`** (cancelled
  leftover; pinData on subworkflow still ran OpenAI).
- follow_ups **`88026126-a0df-4134-ade1-57bc3565c412`** (failed;
  dangling uuid in `attachment_asset_ids` by design).
- Probe person **`ec5dc966-dea6-4b80-a664-7afebfd513e4`**.
- Fixture interaction **`0a3ff964-d090-409c-9851-5ae6c69f4428`**
  linking that person to capture **#54**.
- Capture **#54** and its two stored photos. Do not mutate.

**Session 06, still locked.**

- Ledger **`73fc2831-2231-40f4-9013-8a67d5dc4074`**.
- Probe people **`ad9c6cde-…`** (LNI No-Match Probe) and **LNI LI
  Guard Probe**.
- Existing **`enrichment_records`**. Do not rewrite payloads.
- Capture **#9** (`processing` / `close_reason=auto`).
- Vision job `1564abc3`. Job `f6a1e703`.
- Captures **#62** / **#63** / **#66** / **#68** / **#69**.
- Capture **#66** is the FK on enrichment job `70f3d9ef-…`.
- Do **not** auto-merge on name. Owner decides pending
  `entity_candidates`.

## Phase 4 is closed. Phase 7 7.1–7.3c is closed.

WF-06 is **ACTIVE**, ceiling **60**, proven. `/flag` enqueues
`force=true`; WF-06 drains `*/15`.

WF-10 is **INACTIVE**, proven by `execute_workflow` (command,
callback, Gmail, two real attachments). It is not a Telegram
command until 7.4.

Do **not** build `/fix`, album auto-detect, a provider benchmark,
contact/vcard ingest, an `/ask` relevance floor, or a per-file
attachment picker. Those stay CUT.

Do not invent scope. Wait for an architect packet.

## Live workflows (read-back 28 Aug 2026, after #38 merge)

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
| 10 | `D9PRjbZMQxe9ESVW` | **false** | `9e649170-d239-4b96-8988-33d78f8f2d5f` | **null** | **false** (expected) |

Settings on 01–10: `availableInMCP: true`, `errorWorkflow` = WF-00
(except WF-00 itself; WF-10 has it), `executionTimeout: 300`,
timezone `Asia/Riyadh`. Whisper `language` is **absent** on WF-03.
Keep it absent.

WF-04 live prompt_version **`wf04-v5`**. Do not bump it without a
packet.

Archived TEST (inactive, do not activate):

| name | id |
|---|---|
| LNI-TEST-WF10-prove | `KtV7f70XdaHdVkWD` |
| LNI-TEST-WF10-binmerge | `GGKmYbps6SvT413C` |
| LNI-TEST-WF10-gmail-get | `CyFlITS5FCIyhvjI` |

WF-01 is the **only** Telegram sender for owner commands. WF-10
returns `reply_text` (and markup, after 7.4). Scheduled WF-07/09
stay the parallel Telegram + Gmail standard (`.first()` after Merge).

## Current data state (28 Aug 2026, session 07 close)

| Fact | Value |
|---|---|
| captures | 56 (0 `failed`) |
| assets | 59 |
| processing_jobs | 80 |
| people | 9 |
| interactions | 14 |
| follow_ups | 5 |
| live catalog rows | 24 |

Older `processing` captures have **no** `entity_resolution` job.
Leave them unless the architect orders a backfill.

## Operating rules (do not re-learn)

- Postgres is state. Never `$env`, never `$getWorkflowStaticData`.
- MCP create binds ElderWise Postgres. Self-identify, then REST PUT
  of settings and credentials. Create response is not evidence.
- n8n API only against `LNI ` / `LNI-TEST-`. Never restart the
  shared container. Never deactivate to "test".
- Zero-row UPDATE is `{success:true}`. Gate RETURNING `id` before
  any send.
- Storage GET URL = bucket prefix + `assets.storage_path`. Never a
  bare uuid.
- Gmail attachments: `options.attachmentsUi.attachmentsBinary[]`
  `{ property }`. Prove from the **message**, not the node config.
- No partial attachment send.
- Parse extract throws if subject or body contains `[` and `]`.
- WF-10 compose is plain text. WF-01 sets no `parse_mode`.
- `credits_spent` for Apollo is the measured delta in
  `num_credits_remaining`.
- Switch connections are index-based. Re-GET every `connection[i]`.

## Hard-won traps (full list)

Session 06 1–16 still hold. Session 07 adds:

17. **Reported-built is not built.** 7.3 shipped a 1-file cap, a
    uuid as a storage key, and Gmail with no attach parameter after
    noticing. Prove attachments from the sent message.
18. **Saved pinData does not apply to executeWorkflow callees.**
19. **Sequential HTTP file GET with distinct `outputPropertyName`
    keeps prior binary keys.** Unused Merge inputs hang.

## What remains (state it plainly)

- **7.4**, only if the 29 Aug gate passes: WF-01 Route type append,
  callback `f7:`, `reply_markup` on the shared send, voice intercept
  while awaiting. Prove `/ask` `/digest` `/flag` still send after
  the PUT.
- **43 captures at `processing`.** Replay or exclude from digest.
  Still open.
- **2 pending `entity_candidates`.** Owner.
- **WF-03 requeue has no backoff.**
- **Supabase hardening.** Disable public signup, delete
  `7bf179a8`, re-enable Confirm email. Owner.
- **RLS re-proof when Phase 5 grants SELECT.**
- **Deliberately CUT:** `/fix`, album auto-detect, provider
  benchmark, contact/vcard ingest, `/ask` relevance floor, per-file
  attachment picker.

## Owner actions outstanding

- 29 Aug gate: capture reliability. Feature work stops if it fails.
- Decide the two pending person `entity_candidates`.
- Signup / Confirm email / delete `7bf179a8`.
- **BotFather `/setcommands`:** live set only `/new` `/done`
  `/batch` `/status` `/digest` `/ask` `/flag`. **Not `/followup`
  until 7.4.** Not `/fix`.
- Keep the production bot on.

## What you build next

Nothing until the architect issues a packet. If that packet is 7.4,
the 29 Aug gate has passed and the Switch-index assertion above is
binding. If it is capture hardening, do not touch WF-10 or WF-01.
Phase 6 and Phase 5 are September.
