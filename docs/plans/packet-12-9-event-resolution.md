# Packet 12.9 — WF-01 / WF-02 event resolution

**Date:** 17 Sep 2026
**Status:** BUILD applied. No canvas. E1–E5
waiting on the owner’s main phone first.
Rollback: WF-02 `<WF02_ROLLBACK>` = `eddb0f11`.
WF-01 `<WF01_ROLLBACK>` = `4160647a`.

12.4d Class C looked for "owner derived from
`events`" and called the rest fingerprint.
B5 proved that wrong: `name = 'LEAP 2026'
AND owner_id = $1` fails closed for any
other tenant. This packet splits the two.

Published GET (name first, then id):

| WF | published | `LEAP 2026` sites |
|---|---|---|
| WF-01 | `4160647a` | 2 nodes (blob 4 = nested copy) |
| WF-02 | `eddb0f11` | 7 nodes (blob 14 = nested copy) |
| WF-03…10 | — | **0** |

WF-00 also 0. WF-00b description mentions
the seed row; it is inactive, not a path.

## A1 — can tenant 2 capture a PHOTO?

**No. Not a first photo. Not `/new`. That is
the product.** Answer from the published
graph. Owner was not asked to send one.

`captures.event_id` is `NOT NULL`. A new
capture cannot land without an `events` row.

### Photo graph (WF-01 `4160647a` → WF-02)

1. Telegram Trigger
2. Allowlist: `bot_state` by
   `telegram_user_id`. Binds `owner_id`.
   Tenant 2 works after 041.
3. Self-identify: `SELECT name, timezone
   FROM public.events WHERE name = 'LEAP 2026'
   LIMIT 1`. **No `owner_id`.** Returns the
   live owner's row. Binds no capture.
4. Reached LEAP-NI?: `$json.name` equals
   `LEAP 2026`. True because that row exists
   on this database. Tenant 2 still passes.
5. Classify update: `branch = photo`
6. Duplicate check: `assets` by
   `telegram_file_unique_id` only (no owner)
7. Resolve payload: `action = resolve_target`,
   `owner_id` from Allowlist
8. Call WF-02

WF-02 `Action resolve_target`:

```
existing = open capture for this owner
           (skipped when mode = batch)
ev = events
     WHERE name = 'LEAP 2026'
       AND owner_id = $1
     LIMIT 1
ins = INSERT captures … FROM ev
      WHERE batch OR no existing
capture_id = COALESCE(existing, ins)
```

Tenant 2 `$1` has event `NIS test tenant`,
not `LEAP 2026`. `ev` empty. No open
capture (`open_capture_id` NULL). `ins` 0
rows. `capture_id` NULL.

9. Media capture present? false
10. Resolve failed terminal (`stopAndError`)
11. **Insert asset never runs.** Storage
    path is never minted.

Same `ev` CTE sits on **Action new**,
**Insert followup capture**, **Action
ingest_contact**. `/new`, first photo,
first voice, first vCard, `/followup`
all die the same way.

**Reuse caveat (not a save).** If an open
capture already existed, `existing` would
win and `ev` would not run. Tenant 2 cannot
create that open row through this graph.
#217 was planted, `needs_review`, not open.

Live owner still captures because their
event **is** named `LEAP 2026`.

## B1 — every `LEAP 2026`, classified

FINGERPRINT = proves which database, binds
no tenant row. DATA PATH = resolves or
filters a row a tenant depends on.

### WF-01 `4160647a`

| Node | Verbatim | Class |
|---|---|---|
| Self-identify LEAP-NI | `SELECT name, timezone FROM public.events WHERE name = 'LEAP 2026' LIMIT 1` | **FINGERPRINT.** No `owner_id` in the SELECT. Gate only. |
| Reached LEAP-NI? | `$json.name` equals `LEAP 2026` | **FINGERPRINT.** False → Wrong database terminal. |

### WF-02 `eddb0f11`

| Node | Verbatim | Class |
|---|---|---|
| Self-identify LEAP-NI | `SELECT name, timezone FROM public.events WHERE name = $1 LIMIT 1` with `queryReplacement` `['LEAP 2026']` | **FINGERPRINT.** No caller `owner_id`. |
| Reached LEAP-NI? | name equals `LEAP 2026` **AND** timezone equals `Asia/Riyadh` | **FINGERPRINT**, but the TZ arm is the live event's zone, not `lni_instance`. |
| Wrong database | error `Self-identifying read did not return LEAP 2026 / Asia/Riyadh; refusing to write` | **FINGERPRINT** message. |
| Action new | `ev AS (SELECT e.id … WHERE e.name = 'LEAP 2026' AND e.owner_id = $1::uuid LIMIT 1)` then `INSERT … FROM ev` | **DATA PATH.** `/new`. |
| Action resolve_target | same `ev` CTE, `INSERT … FROM ev` when no open capture (or batch) | **DATA PATH.** First photo / voice / document. B5 voice. |
| Insert followup capture | same `ev` CTE, `INSERT … FROM ev` | **DATA PATH.** `/followup`. B5. |
| Action ingest_contact | same `ev` CTE, `INSERT … FROM ev` when no open capture | **DATA PATH.** vCard / shared contact. |

12.4d Class C would have called the four
INSERT CTEs fingerprint because `$1` is
already the caller. They are not. The name
literal is an extra filter on the caller's
events. Miss → 0 rows, not "wrong database".

## B2 — every `events` / `event_id` resolve

Only the seven nodes in B1. No other
join, subquery, or `LIMIT 1` on `events`
in either workflow.

WF-02 Action done / batch / status /
sweep / Inspect open followup / Close
standard: `bot_state` + `captures` only.
No `event_id`.

WF-01 Allowlist / Duplicate check /
Insert asset / notes / flag / await:
no `events`. Insert asset receives
`capture_id` from WF-02; it does not
pick an event.

## B3 — other single-owner assumptions

| Where | What | Notes |
|---|---|---|
| WF-02 Reached LEAP-NI? | timezone equals `Asia/Riyadh` | Live event TZ. Tenant 2 event is `Pacific/Auckland`. Gate still passes today because Self-identify returns the **live** row, not the caller's. |
| WF-01 + WF-02 `settings.timezone` | `Asia/Riyadh` | Instance cron TZ (rule 2). Not a tenant row. WF-02 Schedule sweep uses it. Keep. |
| WF-01 Duplicate check | `assets.telegram_file_unique_id = $1` no owner | Already 12.1: second tenant can Duplicate-terminal on the live owner's file. Not this packet. |
| WF-01 Insert asset | `ON CONFLICT (telegram_file_unique_id)` | 12.2 remainder / 12.4e. Not this packet. |
| Telegram `chatId` | `$('Allowlist').item.json.telegram_user_id` on every send | **Not** hardcoded. Owner-scoped. |
| Flag lookup | `people.owner_id = $2` | Owner-scoped. OK. |
| Load await | `bot_state.owner_id = $1` | Owner-scoped. OK. |

No hardcoded chat id. No hardcoded owner
uuid in either published JSON.

## C — design. Do not build.

### C1. Which event when a tenant has two?

Today each owner has exactly one.
`LIMIT 1` is an accident.

Schema (002): `starts_at`, `ends_at`,
`timezone`, UNIQUE `(owner_id, name)`.
**No** `is_current`. `captures.event_id`
NOT NULL.

Live event `LEAP 2026` `ends_at`
2026-09-03. Today is 17 Sep. Date-bounded
`now() BETWEEN starts_at AND ends_at`
would **refuse the live owner too**.
Capture still works for them only because
the name literal ignores dates.

| Option | Rule | Cost | Risk |
|---|---|---|---|
| A. Owner-scoped `LIMIT 1` (newest `created_at`) | cheapest PUT | silent wrong event when they add a second | fail-open on the wrong conference |
| B. Date-bounded | uses columns we have | live owner already outside the window; gap between events = C2 | broken on day one if `starts_at` is future |
| C. Explicit current | `events.is_current` (one per owner) or `bot_state.current_event_id` | migration + a way to switch | honest; miss can message |
| D. Name equals a per-owner setting | another string to keep in sync | same class of bug as today | do not |

**Recommend C.** NIS is conference-shaped;
the owner must pick which event a capture
belongs to. Date-bounded is a digest filter,
not an INSERT key (the live window is
already closed). A is a landmine: it works
until the second event, then writes the
wrong `event_id` with no error.

A 12.9 PUT can still be A as a **bridge**
(unblocks tenant 2, both owners have one
row). That is not the product rule. Do not
ship A as if C were decided.

### C2. Tenant with zero `events` rows

Today: `/followup` silence (D1). First
photo/voice: `write_returned_no_row` +
WF-00, still nothing in Telegram (D2).
A new tenant on day one is this case.

12.6 E1 already: no `events` → `/digest`
`Empty digest terminal`. Same class.

**Contract:** seed `events` at tenant
creation (12.6 E1), **and** the runtime
must reply, not go silent, not page
WF-00 for a setup miss. Copy is a product
line ("not set up yet"), not this packet.

### C3. Fingerprint still on `events`

Confirmed. WF-02 Self-identify + Reached
LEAP-NI? still gate `events` `LEAP 2026`
**and** `Asia/Riyadh`. Not `lni_instance`
name `NIS`. WF-01 same name gate, no TZ
arm. Q4 is **not** met on WF-01 / WF-02.
WF-00 / 07 / 08 already moved.

The fingerprint gate is why tenant 2
**enters** WF-02 at all (B5 495988 passed
Reached LEAP-NI?). The DATA PATH is why
the INSERT then returns `{}`.

## D — record

**D1.** `/followup` tenant 2: WF-01
**495987** Command no-send. WF-02
**495988** Followup missing terminal.
Insert OUTPUT `{}`. `reply_text` empty.
User got nothing. Unresolvable event
must produce a message, not silence.

**D2.** Voice **495994** ERROR
`write_returned_no_row` (`corr=ea80c282`).
WF-00 **495996** lastNode No alert
(below repeat threshold). The error was
real and invisible to the tenant.

**D3.** Fail-closed is the **right**
property. The INSERT did not stamp the
live owner's `event_id` on a tenant-2
capture. That would have been an
incident. Zero rows is why this is a
**defect** (tenant 2 cannot capture)
and not an incident (no leak). Do not
"fix" it by dropping `AND owner_id = $1`
and keeping the name.

0c unchanged by this audit.

## BUILD — 17 Sep 2026. E1 not run yet.

### PART A — before any change

GET by name first.

| WF | name | `activeVersionId` |
|---|---|---|
| WF-01 | LNI WF-01 - Telegram ingest router | `4160647a` |
| WF-02 | LNI WF-02 - Capture lifecycle | `eddb0f11` |

Matches expect. Named rollbacks are those ids.

### PART B — 042 applied `20260917065325`

B1. `bot_state.current_event_id` uuid NULLABLE
`REFERENCES events(id)`.
B2. `events_owner_id_id_key` UNIQUE `(owner_id, id)`.
`bot_state_owner_current_event_fk`
`(owner_id, current_event_id) → events(owner_id, id)`.
B3. Backfill by owner, not by name. Read-back:

| owner8 | event8 | same_owner | event |
|---|---|---|---|
| `2678f157` | `042e02b7` | true | `NIS test tenant` |
| `a79b744e` | `389ed098` | true | `LEAP 2026` |

B4. Cross-tenant UPDATE caught in a PL/pgSQL
inner block (rolled back). SQLSTATE `23503`:
`insert or update on table "bot_state" violates
foreign key constraint "bot_state_owner_current_event_fk"`.
Read-back after prove: both rows unchanged.

### PART C — WF-02 PUT

Rollback `eddb0f11`. New published `d7205734`.
Active. `sanitize_for_put` from `activeVersion`.
`LEAP 2026` count in published graph: **0**.
Self-identify `SELECT name FROM public.lni_instance
LIMIT 1`. Gate name equals `NIS`. No timezone,
no `owner_id`. Four INSERT CTEs read
`bot_state.current_event_id` JOIN `events`
`AND e.owner_id = $1`. Owner predicate kept.
NULL `current_event_id` →
`reply_text` `No active event is set. Contact support.`
(`error_code` `no_active_event`). Settings
unchanged (`Asia/Riyadh`, WF-00 errorWorkflow,
`availableInMCP` true, timeout 300).

### PART D — WF-01 PUT

Rollback `4160647a`. New published `16760629`.
Active. `LEAP 2026` count: **0**.

DIFF vs `4160647a` (every difference):

| Kind | What |
|---|---|
| CHANGE | Self-identify query → `lni_instance` name only |
| CHANGE | Reached LEAP-NI? `rightValue` `NIS` |
| CHANGE | Allowlist SELECT adds `current_event_id` |
| CONN | Media capture present? false → `Resolve has reply?` (was Resolve failed terminal) |
| ADD | `Resolve has reply?`, `Send resolve reply`, `Resolve no-capture sent terminal` (C4/E4: photo with no event must message, not `stopAndError`) |
| POS | Resolve failed terminal `[3136,688]` → `[3360,800]` |
| REMOVED | none |

Survival: Telegram getFile vcard `download: true`
`operation: get`. Telegram Trigger
`additionalFields.download: false`. Upload
`responseFormat: json`. HEAD `responseFormat:
text`. Allowlist `operation: executeQuery`.
Main Telegram getFile still has no `download`
key (same as `4160647a` — not invented).
No `batchSize` and no top-level `responseMode`
on this workflow before or after. Settings
unchanged.

### PART E — STOP

Do not send tenant-2 traffic until **E1**
(live owner photo + voice + `/done`) completes
on the working product. If E1 regresses, PUT
WF-01 `4160647a` and WF-02 `eddb0f11` before
anything else. E2–E5 wait.
