# Session 07 — Phase 7 follow-up drafting (packets 7.0–7.3c, 7.5)

**Date:** 28 August 2026
**Chat purpose:** Phase 7 — confirm-before-send follow-up email. Schema,
WF-10 inactive, attachments on real objects, then session close.
**Outcome:** Packets 7.1–7.3c **closed**. WF-10 is built and **INACTIVE**.
Command + callback + Gmail + attachments proven on real objects. 7.4
(WF-01 wire) is **authored, not applied**. Voice intercept is **not**
in that apply. Phase 6 is a plan only. Last merge on `main` is PR
**#38** squash `952ab05` (`Phase 7: 024/025 + WF-10 follow-up drafting
(inactive)`). PR **#36** closed as superseded; the plan lives on main
via #38.

No n8n workflow JSON is committed. Live secrets live in gitignored
`docs/environment.local.md`.

Implementer: Cursor. Architect/verifier: Claude. Owner: Talal.

---

## 1. What was achieved

Phase 7 v1 is a Postgres draft plus an inactive callee. The owner
will tap Send on Telegram only after 7.4 wires WF-01. Until then
proof is `execute_workflow`, not the bot.

| Packet | PR / SHA | What the artefact is |
|---|---|---|
| 7.0 | #36 closed superseded | Plan `docs/plans/phase-07-plan.md`. Unreviewed at write; accepted by later packets. |
| 7.1–7.2 | #38 `952ab05` | Migration `024_follow_ups_email_draft`. Docs. No WF-01. |
| 7.3 | live n8n + #38 | WF-10 `D9PRjbZMQxe9ESVW` created **INACTIVE**. Command confirm, Gmail To+CC, double-send. Attachment path **reported built, was not**. |
| 7.3b | #38 | Attachment repair on real objects. Migration `025_follow_ups_cancelled_state`. Placeholder guard. Plain text. Cancel state. |
| 7.3c | #38 | Throwaway capture #71 / asset deleted. Three `LNI-TEST-` workflows archived. Squash-merge. Branches deleted. |
| 7.5 | this file | Session log + handover. Docs only. |
| 7.4-PREP + 6.0 | docs on this close | `docs/plans/phase-07-4-wf01-wire.md` (mechanical WF-01 change, not applied). `docs/plans/phase-06-plan.md`. Zero n8n writes. Zero DB writes. |

**WF-10, live.** id `D9PRjbZMQxe9ESVW`, name `LNI WF-10 - Follow-up
drafting`. `active=false`, `activeVersionId=null`, versionId
`9e649170-d239-4b96-8988-33d78f8f2d5f`. Timezone `Asia/Riyadh`,
`errorWorkflow` = WF-00, timeout 300, `availableInMCP: true`.
Self-id returns `LEAP 2026`. Never `POST /activate` this session.

**Proven paths.**

- Command compose: confirm card with To, CC, subject, body,
  attachment filenames. Greeting uses supplied `full_name`.
- Callback send: Gmail To = person email, CC = owner
  `auth.users.email`. Claim SQL + Gmail id gate. Double-send does
  not send twice.
- Attachments: cap 3 at candidate select, 18 MB on confirm from
  `assets.size_bytes`. Claim RETURNING joins `assets` and returns
  `id, storage_path, filename, size_bytes`. GET URL = bucket prefix
  + `storage_path`. Sequential named binaries `attach_0` / `attach_1`
  / `attach_2`. Gmail
  `options.attachmentsUi.attachmentsBinary[].property`.
- Cancel: `draft_state='cancelled'` and `status='cancelled'`.
- Attachment GET fail: `draft_state='failed'`, Gmail does not run.

**WF-01** versionId stayed `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a`.
Not touched.

---

## 2. The 7.3 failure (lesson, not apology)

The 7.3 attachment path was **reported as built while
non-functional**.

What was live:

- Send silently capped 3 → 1 (`Single file?` / `Mark failed multi`).
- GET object used `attachment_asset_ids[0]` (a uuid) where a
  storage key belongs. Four defects, one cause: uuid where a key
  belongs.
- Gmail send had **no** attachment parameter.
- `source=voice` was a stub (both-outputs to Compose no await).

Cause given in 7.3-R: **"I noticed and shipped anyway."**

The lesson is equal in rank to session 06's false reconciliation
and the Route type swap. A green node is not a sent message. A
parameter that is missing is not an attachment. Reporting "built"
from config, or from a path you already knew was dead, is the
defect. Packet 7.3b rebuilt the path and proved it from the Gmail
**message** (exec 267720: filenames and byte sizes 232097 and
188417), not from the send node's JSON.

Owner ruled attachments are **not** cut. They stay.

---

## 3. Architect decisions this session (do not reopen)

1. **`cancelled` is its own `draft_state`.** Migration 025 adds it
   to `follow_ups_draft_state_check`. Does not remove values. Does
   not touch `follow_ups_status_check`. Cancel sets both
   `draft_state='cancelled'` and `status='cancelled'`. `failed`
   means Gmail or attachment failure only; status stays `open`.
2. **No partial sends.** Any claimed attachment that fails to
   download marks the draft `failed`, sends nothing, names the
   filename. The owner approved a specific list.
3. **Plain text, not HTML.** WF-01 send nodes set no `parse_mode`,
   so `&amp;` would render literally. WF-10 compose returns real
   newlines, never literal `\n`.
4. **A Parse extract guard blocks bracketed placeholders**, not a
   prompt. If subject or body contains both `[` and `]`, throw
   (`Extract returned bracketed placeholder`). Same class as the
   empty-subject throw. Prompt binds `full_name`; the guard is
   enforcement.

Also binding, already in the plan: no auto-send; confirm shows
address, subject, body, every filename; CC the owner; attachments
only from `lni-assets` linked to that person's captures; Gmail is
the transport.

---

## 4. Locked evidence (do not edit, do not delete)

**Phase 7 rows.**

| id | What it is |
|---|---|
| `2ea079a3-c6b5-46c5-9d38-ca4c89722154` | No-attachment send. `draft_state=sent`, Gmail `1a0479d97b821c01`. |
| `e5bf5982-1cfb-4779-8d8e-4c40fac132f8` | Two-attachment send. Gmail `1a047bbc15bc3b46`. Files 232097 and 188417 bytes. |
| `dabd0a78-190d-4c27-8c25-bd5ffec8c070` | Cancelled. `draft_state=cancelled`, `status=cancelled`. Reply `Cancelled.` |
| `a7596fde-47be-425b-bde5-5a9343804ee0` | Leftover `awaiting_confirm` from a pinData attempt that still ran OpenAI on the subworkflow. Cancelled. Not evidence of the guard. |
| `88026126-a0df-4134-ade1-57bc3565c412` | Attachment failure. `draft_state=failed`, `status=open`. Gmail did not run. Dangling uuid `4d3b6927-…` in `attachment_asset_ids` **by design** (throwaway asset deleted in 7.3c). |
| person `ec5dc966-dea6-4b80-a664-7afebfd513e4` | Probe `LNI Followup Prove`, email the owner's Gmail. Inserted in 7.3. |
| interaction `0a3ff964-d090-409c-9851-5ae6c69f4428` | Links `ec5dc966` to capture **#54**. Makes Load candidate assets return both photos. |

Capture **#54** (`54a231f3-da6f-474c-b4b1-aebd892f7048`) and its two
stored photos (`d5917376-…` 232097, `8dfa256d-…` 188417) are Phase 1
test data. Do not mutate them.

**Still locked from session 06 §8:** ledger `73fc2831`, probe people
`ad9c6cde` / `ef59e8fd`, captures #9 / #62 / #63 / #66 / #68 / #69,
jobs `1564abc3` / `f6a1e703` / `70f3d9ef`. Do not auto-merge pending
`entity_candidates`.

---

## 5. Data state at close (28 Aug 2026)

Counts from the 7.3c close, as given. 0 failed captures.

| Fact | Value |
|---|---|
| captures | **56** (0 `failed`) |
| assets | **59** |
| processing_jobs | **80** |
| interactions | **14** |
| people | **9** |
| follow_ups | **5** |
| migrations (live catalog rows) | **24** |

Catalog names that matter: `024_follow_ups_email_draft`,
`025_follow_ups_cancelled_state`. 023 remains
`processing_jobs_enrichment_person_uniq` (no `023_` prefix). 012
never applied.

Throwaway capture #71 and asset `4d3b6927` were deleted in 7.3c so
the 7 AM briefing does not count a phantom `failed` capture.

---

## 6. What is NOT built

- **7.4 WF-01 wire is not live.** The exact PUT lives in
  `docs/plans/phase-07-4-wf01-wire.md`. Route type is not appended.
  Callback is still the existing terminal. `/followup` is not a live
  Telegram command. Do not apply that file until a packet after the
  29 Aug gate says so.
- **Voice path.** `source=voice` is a **non-functional stub**. The
  7.4-PREP apply **does not** intercept voice. Capture voice stays
  Route type `[2]`. Declared in `workflows.md` and in the 7.4 file
  §8. Do not build it in a close packet.
- **Per-file attachment picker.** Telegram `callback_data` is 64
  bytes. v1 is Send / Send without attachments / Cancel.
- **Phase 6 and Phase 5.** Plan for 6 is `docs/plans/phase-06-plan.md`.
  No 026. No WF-08 PUT. Order stays 7, then 6, then 5. Phase 8 PWA
  stays refused pre-event.

**7.4 is conditional on the 29 August gate.** If the gate fails,
stop feature work and harden capture. Do not wire WF-01 "just to
finish Phase 7."

Switch-index assertion for when 7.4 is applied (from the authored
file): named output **followup** is **appended** after `flag`. Do
**not** renumber 0–10. After the PUT, **`connection[11]` is Followup
payload**, **`connection[12]` is the re-wired fallback** (Unknown
type). `[5]` becomes `Callback is f7?`. Re-GET every
`connection[i]`. Session 06 4.9 shipped a named rule whose wire
still pointed at the old fallback.

---

## 7. TEST workflows (archived)

All inactive, all archived, names start `LNI-TEST-`. Do not
activate. Do not un-archive unless a packet says so.

| name | id |
|---|---|
| LNI-TEST-WF10-prove | `KtV7f70XdaHdVkWD` |
| LNI-TEST-WF10-binmerge | `GGKmYbps6SvT413C` |
| LNI-TEST-WF10-gmail-get | `CyFlITS5FCIyhvjI` |

LNI-TEST-2.2 capability spike `gyoROqxVQERbPG8I` is older and
untouched this session.

---

## 8. Traps this session proved

Carry with session 06's list. New or re-proven:

1. **A missing Gmail attach parameter is not an attachment.** Prove
   from the sent message's filename and byte size.
2. **Storage GET URL is bucket prefix + `storage_path`, never a
   bare asset uuid.**
3. **Cap attachments where candidates are chosen, not at send.**
4. **Saved `pinData` is ignored on `executeWorkflow` integrated
   runs.** A pin on Extract does not skip OpenAI when WF-10 is the
   callee. Guard proof is Parse extract actually throwing.
5. **HTTP `responseFormat: file` + named `outputPropertyName`
   keeps prior binary keys** on sequential GET. Unused Merge inputs
   would hang.
6. **`alwaysOutputData` empty UPDATE is `{success:true}`.** Claim
   and cancel gate on RETURNING `id`.

---

## 9. Owner actions outstanding

Unchanged from session 06, plus:

- **Do not add `/followup` in BotFather** until 7.4 is applied.
- 7.4 waits on the **29 Aug gate**. Capture reliability wins.
- Two pending person `entity_candidates` still owner.
- Signup / Confirm email / delete `7bf179a8` still owner.
- 43 captures at `processing`: still an open Phase 3 decision.
  Factual (WF-07 live SQL, 28 Aug): they are **not** on the 7 AM
  `stuck (event to date)` line today, because `opened_at` is before
  `events.starts_at` (`2026-08-30 21:00:00+00`). Detail in
  `docs/plans/phase-06-plan.md` §H. Not a fix.
