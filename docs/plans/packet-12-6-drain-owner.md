# Packet 12.6 — Drain owner resolution

**Date:** 16 Sep 2026
**Status:** PART A only. No PUT. Architect agrees
the contract before PART B.
**Home:** this file. Stub in `phases.md` Phase 12.
Login surface previously numbered 12.6 stays
**after isolation**; it is not this packet.

WF-03, WF-04, WF-05, WF-06, WF-09. Last structural
piece before a second tenant’s captures are
processed. Today all five resolve the tenant from
`events WHERE name='LEAP 2026'` and claim with that
`owner_id`. A second tenant stores and starves.

Live read 16 Sep: processing_jobs one owner, zero
queued, zero running. WF-01 / WF-06 drafts
unchanged (`e454df40` / `76840a2a`). No WF-01,
WF-02, WF-07, WF-08, WF-10 change in this packet.
No test-tenant `bot_state`. 12.5b PART B waiting.

## A6 — Rollback (published, read now)

Use `activeVersionId`. WF-06 top-level
`versionId` is the unpublished draft — do not
roll back to it.

| WF | Published rollback |
|---|---|
| WF-09 | `<WF09_PUBLISHED>` |
| WF-06 | `<WF06_PUBLISHED>` |
| WF-04 | `<WF04_PUBLISHED>` |
| WF-03 | `<WF03_PUBLISHED>` |
| WF-05 | `<WF05_PUBLISHED>` |

WF-06 draft `<WF06_DRAFT>` untouched this packet.

---

## A1 — Published graphs (16 Sep GET)

### WF-03 Asset processors — `<WF03_PUBLISHED>`

**Self-identify LEAP-NI** (executeOnce, alwaysOutput):
`SELECT name, timezone, owner_id FROM public.events
WHERE name = 'LEAP 2026' LIMIT 1`.
Gate name equals `LEAP 2026`.

**queryReplacement from that node:** only
**Claim queued jobs**
`{{ [ $('Self-identify LEAP-NI').first().json.owner_id ] }}`.
Claim: `owner_id = $1`, `job_type IN
(card_vision, transcription)`, LIMIT 10.

**Writes using owner_id:** **Maybe enqueue
extraction** uses
`$('Join job to asset').item.json.owner_id`
(the claimed row). Job status writes key by
`job_id`, not owner.

**Callers:** Manual; When called (passthrough).
WF-02 Kick WF-03 **does** send
`owner_id` from Validate payload
(`wf02_done`, `wf02_followup_supersede`). Sweep
kick sends **no** `owner_id`. WF-09 Call WF-03
sends the requeue row or a reconcile Set with
Self identify `owner_id`. **WF-03 never reads
the caller payload.** Self-identify overwrites
it. Kick is a wake-up.

**Call WF-04** executeOnce, wait false. Wake-up.

### WF-04 Structured extraction — `<WF04_PUBLISHED>`

**Self-identify LEAP-NI:** same SQL, same gate.

**From that node:** only **Claim queued
extraction jobs** `.first().json.owner_id`.
LIMIT 10, `job_type='extraction'`.

**Writes:** Insert extraction_runs (both),
Enqueue entity_resolution, Insert contact name
suggestions all use
`$('Claim queued extraction jobs').item.json.owner_id`.
Good once the claimed row is the right tenant.

**Callers:** Manual; When called (ignored).
WF-02 Kick WF-04 note sends `owner_id`.
WF-03 Call WF-04 sends the WF-03 item.
WF-09 Call WF-04. **Claim ignores caller.**

**Call WF-05** executeOnce, wait true.

### WF-05 Entity resolution — `<WF05_PUBLISHED>`

**Self-identify LEAP-NI:** same SQL, same gate.

**From that node:**
- **Claim queued resolution jobs** `.first().json.owner_id` (LIMIT 10)
- **Enqueue enrichment** `.item.json.owner_id` plus capture_id from Mark resolution succeeded
- **Kick WF-10 deferred** Set:
  `owner_id: $('Self-identify LEAP-NI').item.json.owner_id`
  (12.5a C5)

**Other writes:** Prepare resolution sets
`owner_id: run.owner_id` from the extraction_runs
row (not Self-identify). Upsert people /
companies / links / interaction / candidates
use Prepare. Set capture status keys capture_id.

**Callers:** Manual; When called (ignored).
WF-02 Call WF-05 contact / done-er. WF-04 Call
WF-05. WF-09 Call WF-05. **Claim ignores caller.**

**Call WF-10 deferred** executeOnce, wait false.
True dispatch to WF-10. Today the events owner,
not the capture’s.

### WF-06 Enrichment — `<WF06_PUBLISHED>`

**Self identify** (executeOnce): same SQL, same
gate (`Row returned?` name equals `LEAP 2026`).

**No When called.** Cron `*/15` + Manual only.
DRAIN only.

**From that node (every one of these):**
Claim (LIMIT 4, `job_type='enrichment'`);
Load person `$2`; Load ceilings; Mark ceiling
reached `$2`; Insert ledger; Write HTTP failed /
no match / match; Cache check; Write cache skip;
Tavily eligible; Load tavily ceiling; Mark tavily
ceiling; Tavily cache check; Write tavily cache
skip; Insert tavily ledger; Write tavily HTTP
failed / no match / match.

**Each claimed job** splitInBatches **1**.

Ceilings are `lni_config` per `owner_id`, but
that id is the events owner. Missing key is
`NULL`, not `0`. `Ceiling ok?` is
`used < ceiling`. 12.3 F1 (missing = 0) is **not**
`COALESCE` on the value.

**Callers:** none (no executeWorkflow trigger).

### WF-09 Watchdog — `<WF09_PUBLISHED>`

**Self identify** (executeOnce): same SQL.

**From that node:** Scan findings `$1` **and**
the SQL itself joins `events.name = 'LEAP 2026'`;
Load last fingerprint; Write fingerprint; Mark
ceiling failed; Requeue stuck running; **Enqueue
orphan jobs** `a.owner_id = $1` (the events
owner — confirmed; was absent from 12.4d Class
C); Kick WF-03 (reconcile) Set `owner_id` from
Self identify.

**Scan findings** also returns `chat_id` from
`bot_state` for that owner and `owner_email`
from `auth.users`. Compose findings copies those.
Telegram `chatId` and Gmail `sendTo` use
`$('Compose findings').first()`.

**Callers:** Watchdog schedule; Manual prove
(passthrough, unused). Calls WF-03/04/05 as
wake-ups (executeOnce).

Sweep of `$('Self identify').owner_id` /
`$('Self-identify LEAP-NI').owner_id` on these
five: listed above. No other node on these
graphs.

---

## A2 — DISPATCH vs DRAIN

| WF | DRAIN | DISPATCH |
|---|---|---|
| WF-03 | Claim queued jobs (LIMIT 10). Manual and When called both run that claim. | When called exists but **does not consume** caller `owner_id`. Call WF-04 is a wake-up. |
| WF-04 | Claim extraction (LIMIT 10). Same. | When called ignored. Call WF-05 wake-up. |
| WF-05 | Claim resolution (LIMIT 10). Same. | When called ignored. **Kick WF-10 deferred is real dispatch** (capture_id + owner_id + source=deferred). |
| WF-06 | Cron + Manual claim (LIMIT 4, split 1). | None. |
| WF-09 | Cron scan / requeue / enqueue orphan. | Kick WF-03 reconcile (wake-up with events owner). Alert send is per-owner, not a job drain. |

WF-03 and WF-05 “have both” only as triggers.
**Dispatch today is a lie for 03/04/05 claim:**
the kick does not scope the claim.

---

## A3 — Contract (argue)

**Agree for WF-03, WF-04, WF-05 claim+writes,
WF-06, WF-09 Enqueue orphan:**

A drain does not need to know whose work it is.
`processing_jobs.owner_id` is already on the row.

- Claim drops `owner_id = $1`. Claim by
  status / type / backoff / SKIP LOCKED.
- Every downstream write sources `owner_id`
  from the **claimed job** (or Join job /
  Each claimed job / extraction_runs row).
- Self-identify becomes fingerprint only:
  `SELECT name FROM public.lni_instance LIMIT 1`,
  gate `NIS`. **Must not return `owner_id`.**
  WF-10 lesson.
- When called stays a **wake-up**. Do **not**
  bind claim to caller `owner_id`: WF-09
  reconcile and WF-02 sweep would keep starving
  tenant 2. Caller `owner_id` on 03/04/05 is
  vestigial after this packet.

**Does not fit — WF-09 scan / alert / fingerprint:**

Watchdog is not a job claimer as its main work.
Findings, fingerprint, `audit_log`, Telegram
`chat_id`, Gmail `owner_email` are **per owner**.
A finding for tenant 2 must not alert tenant 1.
**Per-owner fan-out (WF-07 shape) is required
here and only here.**

List owners that have work (captures / jobs /
assets), one Scan per owner, `event_id` from
**that** owner’s `events` row (not
`name='LEAP 2026'`). Alert only when that
owner’s `bot_state.telegram_user_id` is
non-empty. Test tenant has **no** `bot_state`:
jobs can be claimed; Telegram/Gmail must skip,
not fall back to the live chat.

**WF-05 Kick WF-10** is dispatch, not drain:
pass `$('Claim queued resolution jobs').item.json.owner_id`
(same as the capture). Never Self-identify.

**WF-06:** contract fits. Retarget every
Self identify `owner_id` to
`Each claimed job.owner_id`. Ceiling SELECT
`COALESCE(value, 0)` so missing = 0 (12.3 F1).

---

## A4 — Batch safety

**WF-06** already splitInBatches **1**. After
retarget, mixed-owner LIMIT 4 is safe.

**WF-03 / WF-04** LIMIT 10, **no split**. Job
writes use `.item`. Call WF-04 / Call WF-05
are executeOnce wake-ups — acceptable if those
callees also global-claim. Fetch/LLM pairing is
the existing single-tenant risk, not a new
cross-tenant one if owner comes from the job
row.

**WF-05** LIMIT 10, **no split**, mints people.
Upserts use Prepare `.item` (`run.owner_id`).
**Call WF-10 deferred executeOnce:true** would
fire once with one capture if two owners are
in the same run. **splitInBatches 1 on WF-05.**

**WF-09** Scan/Compose/Telegram/Gmail use
`.first()`. executeOnce on Scan, fingerprint,
mark, requeue. **Must not** scan two owners
into one item. Fan-out: one owner per
execution item, then `.item` not `.first()`
for chat_id / email, or keep `.first()` only
after a per-owner split of 1.

alwaysOutputData `{}` on zero-row claim is
already gated (`id` notEmpty → NoOp). Keep
that. Do not inherit `{}` into a write
(rule 26).

**Safe answer:** WF-05 and WF-06 batchSize 1
(WF-06 already). WF-09 one owner per item.
WF-03/04 may keep LIMIT 10 with `.item`
sourcing from the claimed row.

---

## A5 — Named specifics

- **Enqueue orphan jobs:** binds
  `a.owner_id = $1` to Self identify (events
  owner). Confirmed. Drop the predicate; INSERT
  already selects `a.owner_id`. Then kick WF-03
  once (wake).
- **WF-09 alert:** `chat_id` / `owner_email`
  from Scan for that owner. No Self identify
  fallback. Empty chat_id → skip Telegram.
- **WF-06 ceilings:** per-owner table, events
  owner on the bind. Missing value is NULL.
  COALESCE to 0 in PART B.
- **Kick WF-10 deferred:** events owner today.
  Fix here to claimed job / capture owner.
- **Callers:** WF-02 sends `owner_id` on done /
  followup / note kicks; sweep does not.
  WF-09 reconcile sends events owner.
  **Callees ignore all of it for claim.**

Zero `LEAP 2026` in the five published graphs
is PART B (B2). PART A records it is in every
self-identify SQL and in WF-09 Scan findings
SQL.

---

## PART B / C — not this turn

Order after agreement: WF-09, WF-06, WF-04,
WF-03, WF-05. One PUT each from activeVersion
`sanitize_for_put`. POST `/activate`. Prove C1–C5
then.
