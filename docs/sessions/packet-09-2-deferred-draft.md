# Packet 9.2 — complete follow-up draft when the person appears

**Date:** 29 August 2026
**Status:** APPLY. WF-01 not touched. Phase 9 contact ingest still paused.
**Branch:** `cursor/phase-09-2-deferred-ce36`

Draft `6f3c13b3-f11d-4c67-8016-73c91d8775f6` is evidence. Do not delete.

## Confirm / disagree

### 1. Timeline — CONFIRM

| Clock (UTC 29 Aug) | Fact |
|---|---|
| 05:27:37 | Capture #120 `b3847b47` opened, `capture_mode=followup` |
| 05:27:52 | Card asset `4d2f4b8f` stored |
| 05:28:00 | Photo `2e1b4dd5` stored |
| 05:28:23 | Audio `ff34f1ce` stored |
| 05:28:28.073 | #120 closed `explicit` |
| 05:28:28.171–05:28:31.144 | WF-10 **278157** (parent WF-01 **278155**) |
| 05:28:29.996 | follow_ups `6f3c13b3` created, `draft_state=draft`, `person_id` NULL, brief names Faisal |
| 05:30:00.231–00.856 | WF-09 **278172** `Enqueue orphan jobs` |
| 05:30:00.792 | transcription + 2× card_vision queued on #120 |
| 05:30:09.766 | extraction queued |
| 05:30:12.895 | entity_resolution queued |
| 05:30:13.059 | people `d8b051cb` Engr. Faisal Baksh created (`source_type=card`) |
| 05:30:13.192 | enrichment queued |
| 05:45:01 | Apollo `people_match` 1 credit confirmed |

Person created **103 seconds after** the draft. WF-10 resolved against a
table that did not yet contain him. Similarity 0.524 is not the defect.

### 2. Loop / double-send — no loop. Guard stated.

WF-10 does not call WF-05. No loop.

Double-send risk exists only if deferred runs after the immediate
`/done` path already wrote `awaiting_confirm` and sent a card.

**Guard (both sides):**

- WF-05 dispatches only when `capture_mode='followup'` **and** a
  `follow_ups` row for that capture has `draft_state='draft'`.
  `awaiting_confirm` / `awaiting_voice` / `sent` / `cancelled` → no call.
- WF-10 deferred loads that same `draft` row. Zero-row →
  `Deferred already complete`, no send.
- `Update draft` is `WHERE draft_state IN ('draft','awaiting_voice')`.
  An `awaiting_confirm` row is a zero-row UPDATE. No confirm card.
- Sweep send cluster runs only after Compose confirm from a returned
  draft row. `source='deferred'` is an extra true on the existing
  `Sweep source?` OR-gate (with `sweep`). No second sender.

Immediate `/done` that already found the person (earlier capture, exact
email) writes `awaiting_confirm` and WF-01 sends. Deferred is a no-op.

### 3. Enrichment on #120 — not intended by 9.1. Do not fix here.

9.1 did not change the followup enqueue guard on WF-02 `/done`.
#120 had **no** processing_jobs at close (05:28:28). Jobs appear at
05:30:00.792 from WF-09 **278172** `Enqueue orphan jobs` (no followup
/ vcard predicate). Then ER → enrichment → Apollo 1 credit
`001dd474` at 05:45:01 on `d8b051cb`. Report only.

### 4. Audio transcription — path reopened via WF-09, not WF-02.

Job `330e1923` transcription on audio `ff34f1ce`, created 05:30:00.792,
same WF-09 execution. WF-02 sweep **278174** started 05:30:02 (after
the insert) and still has the followup enqueue guard.

This person is `source_type=card` with a card email — not a phantom
from the owner's speech. A **voice-only** followup would still be at
risk: WF-09 would transcribe, WF-04 could extract a person from the
owner talking about someone. Same hole as the 9.1 vcard note. Not
this packet.

## Apply

- WF-05: after `Mark resolution succeeded`, if followup + `draft`,
  `Call WF-10 deferred` (`wait:false`, `onError: continueRegularOutput`).
- WF-10: `source='deferred'` routes as command, skips a second brief
  insert, completes the existing draft, sends via the 8.2 sweep cluster.

WF-01 unchanged. `5df341f8` excluded from both SELECTs.
