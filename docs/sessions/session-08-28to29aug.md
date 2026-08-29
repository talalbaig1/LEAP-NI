# Session 08-28to29 Aug 2026

One session. Live system is authoritative. Closed PRs #49–#63
and #54 are not a source. This file replaces the per-packet
fragments those PRs would have added.

Read 29 Aug 2026: n8n GET name-checked, live SQL on LEAP-NI
(`information_schema`, `pg_constraint`, `supabase_migrations.schema_migrations`).

## What this session did

Phase 7 follow-up went from a 15-minute await window to
followup-as-capture. Phase 8.1–8.6 built unmatched + confirm
on that model. Phase 9 contact ingest was built on WF-02 / WF-05
/ 029 and paused before the WF-01 PUT. Two capture-path defects
were found by the owner's gate. The WF-09 reconciler shipped
without followup/vCard guards — architect error, fixed on
`f3885d5a`. Capture #120 is a recorded exception. Invariant A
was re-baselined.

## Two capture-path defects (owner's gate)

Found on the owner's phone. Not in a lab.

**1. `/done` enqueue raced the last upload.** Owner sent a
card, tapped `/done` ~16ms later. WF-01 `/done` enqueued
from `capture_assets` at that instant. The last asset was
not in the table yet. Card never processed. Fix: do not
make `/done` wait. WF-09 orphan reconciler
(`m0lvc9dzpyxLj2hI`, every 15 min) finds stored assets on
a non-open capture with no `processing_jobs` row and
enqueues. Live after the guard copy: versionId
`f3885d5a-4eb9-41d0-96ae-91115c69fcaf`, rollback
`78c1e260-7ada-46aa-8d42-968ead2595ac`.

**2. `/done` receipt counts closed captures, not enqueued
jobs.** Cosmetic. Owner sees a count that can disagree with
what actually queued. Still open (`masterplan.md` item 13).
The reconciler makes the data correct within 15 minutes.
Do not block `/done` on it.

Gate-fix commit on main: `6e4c3c0` / PR #36.

## Follow-up redesign — why the await model was abandoned

7.1 started a 15-minute `awaiting_voice` window at
`/followup`. Voice `file_id`s expire; the window was the
life of the file. That assumed the person already existed
and that the brief would still be in the execution when
WF-10 ran.

Live proved the opposite:

- `/followup` before `/done` → people do not exist yet.
  Voice-only resolution against an empty capture returns
  zero candidates (7.4b, recorded).
- `/done` can take as long as the event. Waiting for
  `/done` to start the window makes follow-up unusable
  on the floor.
- Starting the window at `/done` (7.6 / 7.8) still dies
  the moment a picker, callback, or second await runs.
  The brief is an expression, not a row.

**Live model.** `/followup` is a capture.
`captures.capture_mode = 'followup'` (028). Brief, photos,
and voice are assets and columns on that capture and on
`follow_ups` (`brief`, `capture_id`, `has_arabic`,
`has_latin`). WF-05 after ER, if the capture is followup
and `follow_ups.draft_state = 'draft'`, kicks WF-10
`source = 'deferred'` (`wait: false`). WF-10 completes
that row and sends Telegram (`Sweep source?` is true for
`sweep` or `deferred`). Immediate `/done` still returns
to WF-01. WF-10 never waits on `/done` for the person to
exist.

The await model is abandoned. Do not put it back. The
15-minute path still exists in the WF-01 / WF-10 graph.
It is leftover, not the design.

## WF-09 reconciler guard gap — architect error

GATE-FIX predated followup captures and vCard ingest.
WF-02 `Enqueue asset jobs` grew exclusions: skip
`capture_mode = 'followup'` and skip
`kind IN ('vcard')` / vCard mime / `.vcf`. WF-09
`Enqueue orphan jobs` did not get the same predicate.

Result: a followup capture with photos looked like an
orphan to the 15-minute scan. WF-09 enqueued
`card_vision` / `transcription`. Entity resolution
ran. Enrichment ran. Apollo was consumed.

That is how capture #120 produced six succeeded jobs and
Apollo credit `001dd474` on Faisal (`d8b051cb`). Not WF-02.

**Fix.** Copied the WF-02 exclusions onto
`Enqueue orphan jobs`. One PUT. Scan / ceiling / requeue
unchanged. Live SQL on WF-09 matches WF-02 on those four
lines.

## Capture #120 — recorded exception

Live SQL, 29 Aug 2026.

| Object | Value |
|---|---|
| Capture | `#120` `b3847b47-45ac-4f3c-a295-1c935be44506` |
| Mode / status | `followup` / `ready` |
| Capture opened | `2026-08-29 05:27:37+00` |
| Draft | `6f3c13b3-f11d-4c67-8016-73c91d8775f6` |
| Draft written | `2026-08-29 05:28:29+00` |
| Draft state | `draft`, `person_id` NULL |
| Person | `d8b051cb-9325-4a43-9c6c-c0cbf286b404` Engr. Faisal Baksh |
| Person created | `2026-08-29 05:30:13+00` (`source_type='card'`) |
| Gap | **103 seconds.** The draft named him before he existed. |

Jobs on #120 (leave as history; owner's call to delete):

| id | job_type | status | created_at |
|---|---|---|---|
| `330e1923-a149-4294-98e9-dc832502254d` | transcription | succeeded | 05:30:00 |
| `09be0d19-5e3e-401f-8597-f79aad18a0a0` | card_vision | succeeded | 05:30:00 |
| `7361e59a-2060-44ae-92ad-51dfcd191aa0` | card_vision | succeeded | 05:30:00 |
| `cd3f4232-6bdf-477a-bf12-3cb06b59c534` | extraction | succeeded | 05:30:09 |
| `d72b05bc-bfaf-4312-88eb-1c0b6b37ba8f` | entity_resolution | succeeded | 05:30:12 |
| `297e993d-005c-4df6-9d33-6aaa11e8e894` | enrichment | succeeded | 05:30:13 |

Apollo ledger `001dd474-e098-4ecc-b9cb-de37e3412681`
`people_match` / `confirmed` / 1 credit, `spent_at`
`2026-08-29 05:45:01+00`, `entity_id` = Faisal.

Do not treat #120 as a clean follow-up. Do not replay it
as a proof. Draft `6f3c13b3` stays as evidence. Do not
delete it from a packet. Do not delete Faisal `d8b051cb`.

## Phantom merge

Trigram / `hit_count > 1` → picker. Never a silent pick.
Voice ladder floor is 0.25. If two people can match, the
owner picks. The Ahmed confusion class (8.3) is this rule
under a real name collision. Do not "just pick the first."

## Invariant A — re-baselined

Was: `audit_log.followup_sent` count = `follow_ups` rows
with `draft_state = 'sent'`.

Live SQL 29 Aug 2026: `follow_ups` sent = **2**,
`audit_log` `followup_sent` = **3**.

**Re-baseline: audit = sent + 1.** The extra audit row is
history from this session. Do not "fix" it by deleting
audit. Do not fail a packet because the counts are not
equal.

## Six times the brief (or the id) was not in a row

Rule 23 exists because of these, in one session:

1. Brief lost across the picker execution.
2. `unmatched_requests` dropped on callback.
3. Reload brief empty after Claim await.
4. `this_session` scoped photos to the wrong await row.
5. Callback `capture_id` absent from the WF-01 payload.
6. Person resolved 103 seconds before he existed (#120).

If it must survive a follow-up, it is a Postgres column.
Read the row.

## Live versionIds and rollback targets

GET 29 Aug 2026, name-checked. Closed-PR docs that
disagree are wrong.

| WF | id | active | nodes | versionId | rollback |
|---|---|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | true | 15 | `5ec180fd-3270-433d-9e03-d0f2ff9ecd44` | — |
| 00b | `Q1eMhUF67VAt3T8a` | false | 6 | `46330598-9abb-422e-817e-ec6ea620321a` | — |
| 01 | `ZMYx19qEr72mJoCX` | true | 131 | `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` | `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd` |
| 02 | `BV0nukrQdOpDCPe4` | true | 89 | `e491a9f0-d213-434c-9da1-5c9372c0ab15` | `071a4794-4d2f-4c05-ac2b-9f482efde605` |
| 03 | `k0bPD3GJBNN2EHDB` | true | 38 | `852f300b-069e-4763-b97b-3068fbf06a9b` | — |
| 04 | `cxyvgBJC1DD8LEbU` | true | 28 | `28510930-2a65-470d-9a29-f8359b0f46f2` | — |
| 05 | `Iv0loGijYVH77OGh` | true | 29 | `68f47505-36b6-4843-98e1-16892a098aa2` | `74b08d0f-9f9d-44ca-aee2-1324f6e24a7f` |
| 06 | `eNlgt1wk9Z8Nefwy` | true | 53 | `356a2d1f-daf1-4560-a68f-4df82ff64ceb` | `f6b39538-28ae-4946-ac81-504c9f004c36` |
| 07 | `AyPtkP8PMFeEdYU9` | true | 25 | `fb9ee1c4-6b40-4064-af22-950b78a45544` | — |
| 08 | `QIioJBxuZYJh5R4W` | true | 19 | `b699e7d6-ecd4-431d-86ff-d61bd1472390` | — |
| 09 | `m0lvc9dzpyxLj2hI` | true | 43 | `f3885d5a-4eb9-41d0-96ae-91115c69fcaf` | `78c1e260-7ada-46aa-8d42-968ead2595ac` |
| 10 | `D9PRjbZMQxe9ESVW` | true | 146 | `7f021c99-1beb-4fd5-8b53-f769a10a2b0c` | `ab21c10c-6d04-44eb-a97b-c4409ec38c90` |

WF-01 PUT is paused (Phase 9). Do not change `1d53c03d`.

## Schema at close of session

Migrations through `people_source_type_contact` (029).
No 030. Phase 6 embeddings are 030, post-event.

Live CHECKs:

- `captures.capture_mode`: `standard` \| `batch` \| `followup`
- `captures.last_activity_at`: `timestamptz NOT NULL DEFAULT now()`
- `follow_ups`: `brief`, `has_arabic`, `has_latin`, `capture_id`
- `people.source_type`: `card` \| `voice_note` \| `typed_note` \| `photo` \| `enrichment` \| `shared_contact` \| `vcard`
- `assets.kind`: `business_card` \| `audio` \| `photo` \| `selfie` \| `document` \| `vcard`

## Phase state at close of session

- Phase 5: post-event. Built later. Not the next packet.
- Phase 6: post-event. Next build is migration 030
  (pgvector embeddings). Not started.
- Phase 7: live. Followup-as-capture. Deferred completion.
  WF-10 sends Telegram on sweep and deferred. 9.8 TEST:
  WF-05 **279835** / WF-10 **279850**, 64 s to card.
- Phase 8: unmatched + confirm live on that model.
- Phase 9: Packet 9.6 PUT is live (`4836ffd8`). Owner
  phone 11:12–11:19: #134 / #135 / send `bb3689d8`.
  9.6-B: #136 photos on WF-09 **279752**, audio not.
  Do not PUT WF-01 again.
- Phase 10+: not started.

## Standing constraints that survived the session

- No `$env`. No `$getWorkflowStaticData`.
- Do not restart n8n.
- Do not touch ElderWise.
- Do not email real contacts.
- Do not delete Faisal `d8b051cb`.
- Do not delete draft `6f3c13b3` (#120 evidence).
- Do not touch follow_ups `5df341f8`.
- LNI-TEST-7.16-driver `iqAx0KwCsTbb32BY` stays inactive
  unless a packet activates it.
- Do not PUT WF-01 again (9.6 already applied).

## Closed, not merged (documentation reconciliation)

#49 #50 #51 #52 #53 #54 #55 #56 #57 #58 #59 #60 #61 #62 #63.
Reason: every open PR edited the same docs from a stale
base. Sequential conflict resolution would have produced a
document set matching no real version. Live JSON and live
SQL are the source. This file and
`workflows.md` / `architecture.md` / `phases.md` /
`masterplan.md` / `rules.md` are the replacement.

Main at reconciliation start: `d0f4eb0` (#48 only).

## Packet 9.8 (29 Aug 2026)

Squash-merged #64 (docs reconcile; 029 catalog name
`people_source_type_contact`, no `029_` prefix, same class
as 023) and #65 (9.6 parse_mode + contact ingest + owner
regression). Main `97ce010`.

Then TEST-driver deferred prove, no phone, no WF-01 PUT:

- Immediate miss: WF-10 **279830**. Draft without recipient.
- WF-05 **279835** created Zayd `2446d3fa`, kicked deferred.
- WF-10 **279850** `source=deferred` sent confirm
  `message_id` 518. Elapsed `/done` → card: **64 seconds**.
  Phone wait is the next WF-09 15-min tick + vision + ER.
- #136 9.6-B: WF-09 cron **279752** enqueued 2 images, not
  the audio. Live is 2 photos + 1 audio, not three photos.

Driver unpublished after (`d69aa9d0`, `active=false`).
Draft `c884eb5d` cancelled, not sent.

## Packet 9.10 (29 Aug 2026)

Cause (9.9): followup `/done` skipped `Enqueue asset jobs`.
One WF-02 PUT `847cc3c7` (rollback `bc87f636`). Both
`Followup close?` outputs enter the same enqueue node.
Zero-row audio-only still reaches `Followup done terminal`
and still kicks WF-10. WF-01 `4836ffd8`. WF-09 backstop.

TEST: unknown card `/done` → card **21 s** (WF-02 **280253**,
WF-10 **280271** `message_id` 531). Audio-only: enqueue no
`id`, no throw, WF-10 **280118**. Known person: confirm then
WF-05 **280225** `No deferred draft`. Standard #142 and
`/batch` unchanged. Driver unpublished.
