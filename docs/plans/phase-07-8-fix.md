# Packet 7.8-FIX — brief persistence + enrichment drain

**Date:** 28 August 2026
**Status:** APPLIED. WF-10 `45f1fdd4-…` (108 nodes). WF-06
`356a2d1f-…` (53 nodes). WF-09 `78c1e260-…`. 027 catalogued.
Rollbacks: WF-10 `6f3dcfb5-…`, WF-06 `f6b39538-…`, WF-09 `23d0972e-…`.
**WF-01 is not touched** (`864bcb8b-…`, 128 nodes).

## Causes (accepted)

Voice brief died at the execution boundary: 272417 transcribed the
10 September meeting, Compose many, no Extract. 272419 `f7:p:`
callback had empty Brief (`Transcribe.isExecuted` false) and
**Insert draft** because Voice after parse? requires `source=voice`.
Second row `b2c91be3`; `457905d5` stayed `awaiting_voice`.

Drain: LIMIT 1 × `*/15` = 32 jobs / 8-hour day vs 40–80 inflow.
Apollo 0.7–2.7 s, tick 3–7 s, timeout 300 s, ceiling 60 (12 used).
The schedule was the constraint. FIFO wait is not a stuck job.

## A. Brief survives the execution boundary

**A1. Migration `027_follow_ups_brief`.** Additive. Catalog name
must start `027_`. Phase 6 embeddings moves to **028**
(`docs/plans/phase-06-plan.md`).

| Column | Type | Null |
|---|---|---|
| `brief` | text | YES |
| `has_arabic` | boolean | YES |
| `has_latin` | boolean | YES |

Backfill flags from `prompt_version` strings that contain
`has_arabic=` / `has_latin=`. Then strip those suffixes so
`prompt_version` is a version again (`wf10-v2`). No jsonb. No
GRANT SELECT. No change to `follow_ups_status_check`.

**A2.** Voice path **Record script** (before any picker) UPDATEs
the `awaiting_voice` row: `brief` = Transcribe.text, `has_arabic`,
`has_latin`, `prompt_version='wf10-v2'`. Durable before Compose many.

**A3.** `f7:p:` callback_data stays `f7:p:<person uuid>` (41 bytes).
Do not add a follow-up id. Resolve the row from
`bot_state.awaiting_followup_id` (still set; Claim await has not
run). **UPDATE that row.** Do not INSERT a second follow_ups row.

**A4.** Before Extract: **Reload brief** from
`bot_state.awaiting_followup_id`, then **Resolve brief** (row.brief
first, else Transcribe.text, else Parse argument.brief). Extract
reads `$('Resolve brief').first().json.brief`. Row first.

**A5.** wf10-v2 system prompt: carry concrete specifics from the
brief into the body (dates, commitments, named next steps). Keep
no invented facts, no phones not in the brief, the sentinels.
Schema `agreed` / `send_what` / `deadline` stay.

**A6.** Cancel leftover `awaiting_voice` rows `457905d5`,
`fbe0429b`, `f9ba0b14`.

Voice after parse? becomes: Reload brief `draft_state` equals
`awaiting_voice` → Claim await → Update draft. Typed with no await
row still Insert draft.

## B. Enrichment drain

**B1.** Claim `LIMIT 1` → `LIMIT 4`, sequential (Split In Batches
batchSize 1). Schedule stays `*/15`. Ceiling stays 60. ~16/hour,
~20–30 s/tick vs timeout 300. Ceiling binds at 60/day first.

**B2.** WF-09 Scan findings: `stuck_queued` for
`job_type='enrichment'` only is **60 minutes**. Every other job
type stays 1 / 5 minutes. WF-09 still does not Call WF-06.

**B3. Job `b4dbf8cf-5199-4cb7-9686-51932a4d0b37` (cap 67) — report
only, do not retry.** `enrichment` `failed`, `attempt_count` 1,
`error_code='write_failed'`, `error_detail` null, last_transition
2026-08-27 21:15:51Z. Person `ad9c6cde-…` **LNI No-Match Probe**
(`lni-nomatch-probe@lni-probe-8f3a2c.example`). A person/apollo
`enrichment_records` row already existed at 20:50Z. Live WF-06 JSON
contains no `write_failed` string — this code is from an older write
path (second INSERT into `enrichment_records` without ON CONFLICT,
or a removed handler). Apollo on `.example` is the hollow-shell
case (packet 4.3). Blind retry would hit the existing record.
`failed_24h` keeps it in WF-09 alerts until last_transition+24h
(~21:15Z 28 Aug). Do not requeue.

## Prove

1. **027 catalogued.** MCP `list_migrations` name `027_follow_ups_brief`.
   Columns `brief` / `has_arabic` / `has_latin` exist, nullable.

2. **Voice + picker/callback.** Asset `8402c99a-…`. Record script on
   exec **272708** wrote brief on `a3e22fb5-…` **before** the next
   owner-visible node (`Compose no email`). Full Whisper text includes
   `10th of September`. English auto-detect exact-matched person
   `Ahmed Tufa` (no email, created 19:00Z) so `Voice disambiguate?`
   was false and Compose many did not run. `f7:p:` stayed 41 bytes.
   Callback exec **272726** UPDATEd **the same row** to
   `awaiting_confirm` / `ahmed.eltohfa@veeam.com`. Body: `meeting on
   the 10th of September`. No second `follow_ups` insert. Prove drafts
   cancelled after. Owner `bot_state` restored to `becb0e07-…`.

3. **No-picker (person already on the row).** `5e4fc08a-…` with
   `person_id` = Ahmed Eltohfa. Exec **272733**. Confirm card, same
   row, body has `10th of September`. No `f7:p:` buttons.

4. **WF-06 LIMIT 4.** Exec **272743** `19:24:00.041Z`–`19:24:00.910Z`
   (**869 ms**). Claimed 4 jobs. `Load person` / `Cache skip` ran 4
   times. Last node `Drain done`. All four `succeeded` /
   `skipped_cached`. Schedule still `*/15`. Ceiling unchanged.

5. **WF-09 silent for young enrichment.** Four queued enrichment jobs
   aged 2 min: Scan CASE `kind_78` null; old 1-min rule would have
   been `stuck_queued`. Did **not** run WF-09 Telegram (`failed_24h`
   on `b4dbf8cf` would still alert).

6. **GET WF-01** `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd`, 128 nodes,
   unchanged after all PUTs.

Leftover (not this PUT): `Compose no email` still reads
`$('Lookup people')` and throws on a unique voice match with no
email (272708).

## Rollback

WF-10 `6f3dcfb5-6f36-4166-9864-d603ee374906`.
WF-06 `f6b39538-28ae-4946-ac81-504c9f004c36`.
WF-09 `23d0972e-9e2b-4548-8c58-a663bde290da`.
Migration 027 is additive; do not drop columns during the event.
