# Packet 7.15-PLAN — Follow-up is a capture

**Date:** 28 August 2026
**Status:** PLAN ONLY. No PUT. No migration. No code. Wait for
architect review.
**Live GET this packet (name-checked, then read):**

| WF | id | versionId | nodes | active |
|---|---|---|---|---|
| WF-01 | `ZMYx19qEr72mJoCX` | `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd` | 128 | true |
| WF-02 | `BV0nukrQdOpDCPe4` | `8d56f518-cc8d-4543-bbf9-c3d577e0728a` | 50 | true |
| WF-10 | `D9PRjbZMQxe9ESVW` | `f1013395-c88b-4c6f-83dc-f2ef83844a12` | 109 | true |
| WF-03 | `k0bPD3GJBNN2EHDB` | `852f300b-069e-4763-b97b-3068fbf06a9b` | 38 | true |

Do **not** apply from memory. Do **not** touch WF-01 / WF-02 / WF-10
or the database in this packet. Leave draft `5df341f8` `awaiting_confirm`
as evidence. Cancel nothing.

---

## Why the await-window dies

Membership was inferred from ephemeral n8n/bot_state, not from rows
that survive a picker, a second tap, or a new `/followup`. Four
instances, one evening, same root:

| # | Exec / draft | What was inferred | What the row said |
|---|---|---|---|
| 1 | 272419 | `$('Transcribe').isExecuted` → brief | Callback execution had no Transcribe. Brief empty. Second `follow_ups` row. 7.8-FIX. |
| 2 | 272939 `ae2b9d7a` | `source==='voice'` → copy `unmatched_requests` | Callback. Parse dropped a named miss. 7.12-R / D2. |
| 3 | 273271 `55d2763a` | `bot_state.awaiting_followup_id` → Reload brief | Claim await had already nulled it. Reload `{}`. A5 wrote "recent discussion". 7.14-R B. |
| 4 | 273234 `601ae9f6` | `this_session` = capture opened after **this** await | Photo `#85` `opened_at` 19:45:05Z; new await `created_at` 20:21:37Z. TEST 273170 had backdated `created_at`. 7.14-R A. |

A capture is durable: `captures.id`, assets on that id, transcripts
on those assets. The block **is** that row with `capture_mode='followup'`.
Not a parallel await.

---

## 1. `/followup` opens a capture

### Live WF-02 open path (GET)

`Route action` `[0]` → **Action new** (`6bb4ec0e-…`).

Action new, live SQL, in order:

1. `closed`: UPDATE the capture at `bot_state.open_capture_id` if
   `status='open'` → `status='processing'`, `close_reason='superseded'`.
   **Does not enqueue. Does not Call WF-03.**
2. `ins`: INSERT `captures` `status='open'`,
   `capture_mode = CASE WHEN b.mode = 'batch' THEN 'batch' ELSE 'standard' END`,
   `card_only = (b.mode = 'batch')`.
3. `upd`: `bot_state.open_capture_id = ins.id`, bump
   `last_activity_at`.
4. Return `capture_id`, `capture_no`, `mode`, `item_count=0`.

**Compose new reply:** `Capture #<n> open`.

`Validate payload` allowlist (live):
`['new','done','batch','status','resolve_target','sweep']`.
`followup` is not an action.

`captures_capture_mode_check` (003, live):
`check (capture_mode in ('standard', 'batch'))`.
`'followup'` will not insert until 028.

### What changes

New action `followup` (allowlist + `Route action` append — re-GET
**every** Switch index after append, `rules.md` trap). Twin of
Action new that INSERTs `capture_mode='followup'`, `card_only=false`,
sets `open_capture_id`. Reply: `Follow-up #<n> open. Photo and voice stay in this block. /done drafts.`

Do **not** reuse Action new as-is: it writes `standard`/`batch` from
`bot_state.mode`, never `followup`.

### Open capture already there — recommend close-and-process, then open

Live `/new` supersedes without enqueue. That is a silent death for
whatever was in the previous capture (Phase 2 lesson). Do not copy it.

**Recommend:** if `open_capture_id` points at an `open` **standard**
capture, run the **Action done** close+enqueue+Call WF-03 path on
that id first (`close_reason='superseded'` is allowed by
`captures_close_reason_check`), then INSERT the followup capture.
Reason: booth flow is card photo then `/followup` without `/done`.
The card must still hit WF-03/04/05. Refuse would be a second
command at the worst moment.

**If `bot_state.mode='batch'`:** refuse.
`Follow-up cannot start while /batch is on. /done first.`
Batch is N independent card captures; folding them into a followup
block is a different product.

**If the open capture is already `capture_mode='followup'`:** refuse.
`Follow-up #<n> already open. /done to draft.`
Do not nest blocks.

---

## 2. Photo and voice inside the block — WF-01 media path

### Live (GET)

- `Route type` `[1]` photo, `[2]` voice, `[3]` document →
  **Duplicate check** → … → **Insert asset** → **Asset row returned?**
  `main[0]` → **Send adoption?** **and** **Voice kind?**
  (fan-out, 7.6).
- `Action resolve_target` (WF-02): if `mode IS DISTINCT FROM 'batch'`
  and `open_capture_id` is an `open` capture, **return that capture**.
  Never reject. A followup capture sitting in `open_capture_id`
  already receives every photo/voice/document/text note. **No media
  node change is required for landing.**

**Voice kind?** (live): IF `$('Insert asset').item.json.kind` equals
`audio` → **Load await** → eventually **Voice payload** → **Call WF-10**.
False → **Voice skip terminal**. This is the steal that made the
await-window a second program.

### Which WF-01 nodes are touched?

**Command branch (Classify + `/followup` routing):**

Live `Classify update`: `/followup` sets `branch='followup'` and
hits `Route type` **`[11]`** → **Followup payload** → **Call WF-10**.
`/new` `/done` `/batch` `/status` `/start` are `branch='command'`
`[0]` → **Command payload** (`action` from the map) → **Call WF-02**.

7.15: put `/followup` on that **command map** (`action: 'followup'`),
same as `/new`. Then `/followup` uses **Command payload** +
**Call WF-02 command**. `[11]` becomes unreachable. **Do not delete
the `[11]` rule** in the apply PUT (Switch index trap). Leave it
dead.

`/done` is already `[0]`. No Classify change for `/done`.

**LOUD — it is more than the command branch.**

Must **unwire** **Voice kind?** from `Asset row returned?` `main[0]`.
After 7.15 that array is **Send adoption? only**, same as pre-7.6.
Otherwise every in-block voice is stolen to WF-10 before `/done`.

That is a media-path connection edit. The Duplicate check → Insert
asset chain, Telegram getFile, upload, HEAD, size match: **not
touched**. Node list removed in §8.

Callback `Route type` `[5]` **Callback is f7?** stays. Confirm /
picker buttons still come back through WF-01 to WF-10.

---

## 3. `/done` on a followup capture — branch at WF-02, not WF-01

### Live close dispatch (GET)

```
Action done → Done row returned?
  true  → Compose done reply → Enqueue asset jobs
            → Gate: jobs enqueued
                 true  → Kick WF-03 → Call WF-03 (wait false, onError continueRegularOutput)
                         → Restore done reply
                 false → Restore done reply (no jobs)
  false → Compose nothing open
```

**The node to branch at:** **Compose done reply**'s outbound (today
sole target **Enqueue asset jobs**), **or** a new IF immediately
after **Done row returned?** true, reading `capture_mode` from
**Action done**.

Action done live RETURNING includes `c.capture_mode` inside `closed`
but the outer SELECT does **not** expose it. Add
`capture_mode` (and keep `closed_ids`) to the outer SELECT.

- `capture_mode='followup'` → **do not** Enqueue asset jobs, **do not**
  Call WF-03. **Call WF-10** with `source='command'` (or a new
  `source='done'`), `capture_id`, `owner_id`, `correlation_id`.
  `waitForSubWorkflow: true` so WF-01's existing **Followup has
  reply?** / send path can still fire — **see Disagreements D1**:
  `/done` today returns Compose done reply to WF-01, which sends the
  receipt. The confirm card is a **second** reply. Apply must not
  drop the receipt or the card.
- `standard` / `batch` → unchanged Enqueue → Call WF-03.

WF-01 `/done` stays **Call WF-02 command**. WF-01 does not learn
`capture_mode`.

---

## 4. Brief = every transcription in the block, in order

Durable: `assets` on `captures.id` where `kind='audio'` and
`upload_status='stored'`, `ORDER BY created_at ASC`, plus
`captures.typed_note` if nonempty. Concatenate. Write
`follow_ups.brief` before Extract (column already exists, 027).
**At Extract time the brief is that string. It is a row. It cannot
depend on which nodes ran in this execution.**

### How transcripts are produced — recommend WF-10, not WF-03

Live WF-03 `Call WF-03` is one kick that **claims queued jobs** and
continues into kind + the extraction chain (WF-04 → WF-05). That
chain is what spawned Eltohfa duplicates from voice notes
(masterplan open item 14). A followup voice is a brief, not a
person to insert.

Live WF-10 already has **Fetch audio bytes** + **Transcribe**
(`resource=audio`, `operation=transcribe`, **`language` key ABSENT**).
Reuse that pair in a split-in-batches over in-block audio, same
rules as WF-03 (no `language`). Do not Call WF-03. Do not enqueue
`card_vision` / `transcription` / `extraction` / `entity_resolution`
for a followup capture.

If the architect prefers WF-03: WF-03 needs a new "transcribe only"
exit before extraction. That is a WF-03 PUT plus a job_type. Heavier,
and it re-enters the duplicate-person path unless gated. Not the
recommendation.

No-audio block: brief may be only `typed_note` or empty. Extract
still runs; A5 cannot invent a date that was never spoken. That is
honest, not a 7.14-R empty-Reload.

---

## 5. Candidates

UNION of:

- **(a) in-block** — `assets` on **this** `capture_id`,
  `upload_status='stored'`, `kind IN ('photo','selfie')`. No
  `this_session`. No clock. No `interactions` requirement.
- **(b) linked** — existing person-linked stored photo/selfie
  (today's `(a)` in 7.12). Second source, after a person is chosen.

Deduplicate by asset id. LIMIT 20. Send cap 3. Tag
`source=in_block` / `source=linked`. Prompt: "this photo" /
"the photo I just took" = `in_block`.

`this_session` (await `created_at`) is deleted.

---

## 6. `/status` while a followup block is open

Live **Action status**: bump `bot_state.last_activity_at`, LEFT JOIN
open capture, return `capture_id`, `capture_no`, `mode`
(`bot_state.mode`), `item_count`. **Does not select `capture_mode`.**

Live **Compose status open:**
`Capture #<n> open · <k> items · mode <normal|batch>`

Live **Compose nothing open:** `nothing open`.

Keep `bot_state.mode` as `normal` | `batch` only. Do not add a third
bot mode. Status reads `captures.capture_mode`.

When the open capture is `followup`:
`Follow-up #<n> open · <k> items · /done to draft`

`/status` must **not** keep the capture alive by bumping
`bot_state.last_activity_at` into the sweep predicate — live sweep
uses `captures.last_activity_at` (026), so this is already correct.
Do not "fix" status to bump the capture clock.

---

## 7. Auto-close must dispatch to WF-10

Live sweep (GET):

```
Schedule sweep (5 min, Asia/Riyadh, minutesInterval: 5)
  → Action sweep (close open rows where last_activity_at < now()-10 min,
     close_reason='auto'; clear bot_state.open_capture_id if it matches)
  → Compose sweep result (reply_text '')
  → Enqueue sweep jobs (same INSERT as /done)
  → Gate: sweep jobs enqueued
       true  → Kick WF-03 (sweep) → Call WF-03 (sweep)
               (wait false, onError continueRegularOutput)
       false → Sweep terminal
```

Action sweep live RETURNING: `id, owner_id, capture_no`. **No
`capture_mode`.**

A followup capture idle 10 minutes **will** close. Today it would
then enqueue `card_vision`/`transcription` and Call WF-03 — extraction
on a follow-up voice, more phantom people, and **no confirm card**.

**Required:** expose `capture_mode` on Action sweep. Split
`closed_ids`: standard/batch → existing Enqueue + Call WF-03;
followup → **Call WF-10**, no WF-03 enqueue. Zero followup jobs
enqueued is not "silent death" if WF-10 still runs. Missed dispatch:
`onError: continueRegularOutput`, draft or jobs durable, WF-09
watches `queued` — same Phase 2 contract.

Sweep sends nothing today. Confirm card delivery on auto-close is
**Disagreements D1**.

---

## 8. What is DELETED (unwired / unused). No drop migration.

### WF-01 — unwire / stop using (media fan-out + await arm)

| Node | id (GET) | Fate |
|---|---|---|
| Voice kind? | `d79696e0-…` | Unwire from Asset row returned? `[0]` |
| Voice skip terminal | `2281977f-…` | Unreachable |
| Load await | `04c2ebcf-…` | Unreachable |
| Await flags | `d2fe4c21-…` | Unreachable |
| Await id set? | `91604a9f-…` | Unreachable |
| Await live? | `36fe7f29-…` | Unreachable |
| Compose voice expired | `74486308-…` | Unreachable |
| Send voice expired | `dd21141f-…` | Unreachable |
| Clear stale await | `027eec45-…` | Unreachable |
| Voice payload | `fb925711-…` | Unreachable |

Do not delete the nodes in the first apply PUT if a delete shifts
other connections. Unwire is enough. **Followup payload** `[11]`
left in place, unused.

**Not deleted:** Duplicate check chain, Call WF-02 command, Call WF-10
from callback / from WF-02-driven `/done` reply path, Callback is f7?.

### WF-10 — await-window program

Unwire / stop using: **Usage?** empty-command insert, **Insert awaiting
voice**, **Set bot await**, **Compose record now**, **Need voice wait?**
(empty-brief arm), **Load await**, **Await present?**, **Await live?**,
**Compose no await**, **Compose await expired**, **Claim await**,
**Claimed await?**, **Reload brief** (brief comes from in-block
transcripts + `follow_ups.brief` write-before-extract), **this_session**
half of Load candidate SQL. **Load candidate assets** LIMIT-3 node
already dead after 7.12; leave it.

**Keep:** picker (Lookup people voice, F1–F5, 7.9 no-email, 7.10
email-first), Extract / Parse extract / Compose confirm, send/cancel
claim, GET attach, Gmail.

### WF-02 — nothing deleted. Branch added.

### Columns — **leave unused, no DROP this close to the event**

| Column | Where | Recommend |
|---|---|---|
| `bot_state.awaiting_followup_id` | 024 | Leave. Stop writing. |
| `bot_state.awaiting_followup_until` | 024 | Leave. Stop writing. |
| `follow_ups.brief` / `has_arabic` / `has_latin` | 027 | **Keep and use.** |

A DROP now is a migration fight we do not need. Unused await columns
are not load-bearing if no node writes them.

---

## 9. Migration `028`

Next catalog number is **028**. Phase 6 embeddings moves to **029**
(`docs/plans/phase-06-plan.md` still says 028; apply packet updates
that file). 027 is `027_follow_ups_brief`.

**`028_captures_followup_mode`** (name must start `028_`), additive:

1. Drop `captures_capture_mode_check`; add
   `check (capture_mode in ('standard', 'batch', 'followup'))`.
2. `follow_ups.capture_id uuid NULL references public.captures(id)`.
   Bind the draft to the block. No GRANT SELECT.

No DROP of await columns. No `bot_state.mode` value `followup`.

---

## 10. Rollback

| WF | Rollback versionId (live now = rollback target) |
|---|---|
| WF-01 | `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd` |
| WF-02 | `8d56f518-cc8d-4543-bbf9-c3d577e0728a` |
| WF-10 | `f1013395-c88b-4c6f-83dc-f2ef83844a12` |

028 is additive; do not drop `followup` from the CHECK during the
event if a rollback PUT happens. Old Action new never writes
`followup`, so leftover followup rows stay `open` until `/done` or
sweep on the new code. After rollback, a live `followup` row is an
unknown mode to old Action done (it closes `open_capture_id`
regardless of mode — live SQL matches id, not mode). Old enqueue
would then Call WF-03 on it. **Apply order: 028 first, then WF-02,
then WF-10, then WF-01 Voice kind? unwire.** Rollback reverse:
WF-01 first (restore steal, or media still stores), WF-10, WF-02,
leave 028.

---

## 11. Read-back checklist (architect)

1. GET WF-01 name `LNI WF-01 - Telegram ingest router`. versionId
   moved only after the apply packet. `Route type` `[2]` still
   Duplicate check. Length still 13 outputs. `[11]` may be dead;
   indices `[0]`–`[10]` and `[12]` unchanged.
2. `Asset row returned?` `main[0]` **one** target: Send adoption?
   Voice kind? not in that array.
3. Classify: `/followup` → `branch=command`, `action=followup`.
4. GET WF-02. `Validate payload` allowlist contains `followup`.
   Route action: re-GET **every** index. `[1]` still Action done.
5. Action done outer SELECT includes `capture_mode`. Followup close
   does not Call WF-03. Standard close still does.
6. Action sweep RETURNING includes `capture_mode`. Followup auto-close
   Calls WF-10. Standard still Call WF-03 (sweep).
7. GET WF-10. Transcribe `language` absent. No `this_session` in
   candidate SQL. Extract brief from in-block transcripts / row,
   not `$('Transcribe').isExecuted`.
8. GET WF-03 versionId **unchanged** this packet
   (`852f300b-…`).
9. 028 catalogued. `capture_mode='followup'` inserts. `'standard'`
   / `'batch'` still insert.
10. `5df341f8` still `awaiting_confirm` unless the owner cancelled.

Live prove (apply packet, not this one): `/followup` → photo → voice
→ `/done` → confirm has **that** photo filename and spoken date.
Second `/followup` while block open refuses. Auto-close of an idle
followup capture produces a draft (and a card, per D1). WF-01
photo-without-followup unchanged.

---

## 12. Disagreements

**D1. Who sends the confirm card on `/done` and on sweep.**
WF-01 owns Telegram send. WF-02 owns the decision and returns
`reply_text`. WF-10 today returns the confirm card to **Call WF-10**
on WF-01 (`waitForSubWorkflow: true`). `/done` is **Call WF-02**,
which today returns the receipt, not a confirm card.

Apply must pick one:

- **Nested:** WF-02 Call WF-10 `waitForSubWorkflow: true`, then return
  WF-10's `reply_text` / `reply_markup` **instead of or in addition to**
  the `✓ Capture #n saved` receipt. WF-01 Followup send path does not
  run (that path is Call WF-10 on WF-01). Command send path
  (**Send command reply**) has **no** `reply_markup` map (7.4-B was
  followup-only). Confirm buttons would die unless Command send grows
  markup — that is a WF-01 command-send edit, **not** command-Classify
  only. Say it loudly if chosen.
- **Fan-out:** WF-02 returns the receipt; WF-02 also Call WF-10
  `wait false` and WF-10 sends Telegram itself. Breaks "WF-02 never
  sends / WF-10 has no Telegram". WF-07 is the existing exception
  (scheduled digest).
- **Sweep:** no WF-01 parent. Must use the WF-07-style send **or**
  write the draft and say so on next `/status`
  (`Follow-up draft ready`) plus morning digest. Silent
  `awaiting_confirm` is 7.14-R class. **Recommend write+WF-10 Telegram
  send on the sweep path only**, architect to confirm.

**D2. Close-and-process vs refuse when a standard capture is open.**
Recommend close-and-process (§1). Refuse is cleaner and slower on the
floor.

**D3. One-shot `/followup <name> <brief>`.** Live `[11]` still does
this. Owner direction is a block. Recommend: every `/followup` opens
a capture; extra tokens become `typed_note` on that insert (Action
followup UPDATE/INSERT). Do not keep a second one-shot path.

**D4. WF-03 reuse.** Recommend no (§4).

**D5. `/new` enqueue-less supersede** is unchanged by this packet.
Do not silently copy it into followup-open.

**D6. 10-minute idle** on a followup capture auto-drafts. The old
await was 20 min. Last photo/voice stamps `captures.last_activity_at`
(026 trigger), so a working block stays open. A walk-away drafts.
That is the forgotten-`/done` guardrail. Do not special-case 20 min
without a measured reason.

---

## 13. Generic-body / A5 — the fix is a nonempty durable brief

7.14-R B: A5 live lines (GET Extract system, `f1013395`):

> Carry concrete specifics from the brief into the body: dates,
> commitments, named next steps. If the owner named a meeting date,
> write that date. Do not replace it with a vague phrase such as our
> recent discussion.

Exec **273267** (brief on the row): `agreed="10th of September at 9 a.m."`
and the body contained that date. A5 held.

Exec **273271** (Reload brief `{}`): `agreed="none"`, body "our recent
discussion". A5 had nothing to carry.

**In this design the brief is a durable set of rows** (in-block
audio transcripts in order, plus typed_note), written to
`follow_ups.brief` before Extract. Extract does not read
`$('Transcribe').isExecuted` or Reload-from-bot_state. **It cannot
be empty at extract time because of a picker or a second tap.**
Empty only if the owner `/done`s a block with no voice and no note
— then A5 correctly has no date. That is the fix. Not a stronger
prompt.

---

## 14. WF-01 SPLIT — post-event, top structural, refused now

Live WF-01: **128 nodes**, `Route type` **13 outputs** (`[0]`–`[12]`):
command, photo, voice, document, text, callback, contact, ask,
digest, vcard, flag, followup, fallback.

A split (commands / media / callbacks) would re-prove **all twelve
named branches** on the only component whose deadline cannot move
(masterplan Corollary 1: capture reliability wins). This packet
touches Classify and one media fan-out wire. It does **not** split
WF-01.

Record as **open, post-event, top structural**, beside WF-05
duplicate-person (item 14). Do not start it before 4 September 2026.

---

## What this file is not

- Not an apply packet. Not a PUT. Not 028 applied.
- Not a WF-03 / WF-05 fix (item 14 stays).
- Not a drop of await columns.
- Not a sixth WF-01 PUT tonight.

Evidence draft `5df341f8` stays `awaiting_confirm`. Do not send.
Do not cancel.
