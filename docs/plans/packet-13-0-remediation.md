# Packet 13.0 — WF-01 / WF-10 isolation leftovers

**Date:** 17 Sep 2026
**Status:** P1 + P1c applied. STOP for cross-tenant
photo. No canvas. Rollback named before each PUT.
**Home:** this file. Also `phases.md`.

034's composite unique on assets is live. P1 published
owner-scoped Duplicate check + composite ON CONFLICT
(`bf28621a`). P1c dropped 038's TEMPORARY column unique.
Cross-tenant STORE is now testable. Then P2/P3/P4.

## Order (locked)

1. P1 alone (Duplicate check + Insert asset). Named
   rollback. Real photo before anything else.
2. P1c migration 043 — drop TEMPORARY column unique.
   Only after 1b is published **and** a real photo
   stored.
3. P2 same workflow (dead await, Flag owner, Route
   type rule 11).
4. P3 WF-10.
5. P4 last.

## Architect-read (published GET, name first)

WF-01 published `16760629`. WF-10 published `f5f3852c`.

### Agree

- **1a.** `Duplicate check`:
  `WHERE telegram_file_unique_id = $1 LIMIT 1`.
  No owner. Cross-tenant Duplicate terminal.
- **1b.** `Insert asset`
  `ON CONFLICT (telegram_file_unique_id) DO NOTHING`.
- **2b.** `Flag capture lookup` / Flag enqueue
  subquery: `interactions` by `person_id` only.
- **2c.** Route type index 11 `followup`. Classify
  sets `branch=command` `action=followup`. Dead.
- **3a.** `History load` name blocklist + person uuid.
- **3b.** `Load incomplete draft` `$3` is a follow-up
  uuid literal.
- **3d.** Block path: `Transcribe block` 429 →
  `Assemble brief` empty → `Compose no person`.
- **4b.** Upload to Storage and HEAD object URLs
  concatenate `<SUPABASE_PROJECT_REF>`. Do not change
  this packet.

### Disagree (node, before any delete)

**2a.** Architect: "No incoming edges; unreachable."
`Voice kind?` has **zero** incoming. The other nine
only hang off that root (`Load await` ← `Voice kind?`
true, … `Voice payload` ← `Await live?` true →
`Call WF-10`). Live `Route type` voice (index 2) goes
to `Duplicate check`, not `Voice kind?`. The chain is
unreachable as a unit. Count to delete: **10**. Not
"each node has no incoming."

**3c.** `Load candidate assets` has no incoming.
Attachments still work: live loader is
`Load candidate assets 20` (Need voice wait? /
Voice person has email? / Voice source?). Send-path
GET attach 0 hangs off `Need files?`. Dead node is
the 7.4 await/typed leftover, not the live attach
path.

`Compose usage` — dead leftover of typed
`/followup` usage (session 08 / 028). Feature lost
its wiring (F3), not "dead by design" of the product.

`Load owner cc` / `Whisper?` — only fed by the dead
loader. Live siblings: `Load owner cc voice`,
`Transcribe` / `Transcribe block`.

`Followup status written` / `Followup status skipped`
— no in, no out. Leftover terminals.
`Gate: followup status written` is the live gate.

**4a.** "LNI watchdog" / "LNI morning briefing" are
not in WF-01. They sit on WF-09 / WF-07. P4 last.

## P1 PUT

Rollback **before** PUT: WF-01 `16760629`.
Published **after** PUT: `bf28621a` (17 Sep).

- Duplicate check: `AND owner_id = $2::uuid`.
  `$2` = `$('Attach correlation').item.json.owner_id`.
  `queryReplacement` one array.
- Insert asset:
  `ON CONFLICT (owner_id, telegram_file_unique_id)`.

GET name `LNI WF-01 - Telegram ingest router`.
`LEAP 2026` count 0. vcard `download:true` survived.
Trigger `download:false` survived. Main getFile still
has no `download` key (same as `16760629`).

**1d PASS** (architect-verified, 17 Sep):

- **B** new photos: capture **#228** asset `38bf7e95`
  (167588 B) and **#229** asset `557c665a` (165401 B).
  Stored. Composite ON CONFLICT inferred. No 42P10.
- **A** same-owner resend: ZERO new assets, ZERO new
  captures. Duplicate terminal. `/done` "nothing open".

## P1c — 043 (applied)

Catalog **043_drop_assets_column_unique**
(`20260917084212`). Forward-only. Idempotent.

GET name `LNI WF-01 - Telegram ingest router` first.
Published `bf28621a` Insert asset contains
`ON CONFLICT (owner_id, telegram_file_unique_id)`
and does **not** contain the single-column form.
Then DROP.

Read-back:

- `assets_telegram_file_unique_id_key` — **gone**
- `assets_owner_id_telegram_file_unique_id_key` —
  UNIQUE `(owner_id, telegram_file_unique_id)` **kept**

030 stays Phase 6.

**STOP for cross-tenant prove.** Same photo from the
MAIN phone into tenant 2's chat. Must STORE, not
Duplicate terminal. First time the 034 capture-loss
defect is testable.

Then P2 (same WF-01). Then main-phone photo + voice
+ `/done`. Then P3.

## P2 / P3 / P4

Not this step.
