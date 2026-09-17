# Packet 13.0 — WF-01 / WF-10 isolation leftovers

**Date:** 17 Sep 2026
**Status:** P1 in flight. No canvas. Rollback named
before each PUT.
**Home:** this file. Also `phases.md`.

034's composite unique on assets is live. Published
WF-01 still checks and conflicts on the column alone.
038 restored the column unique TEMPORARY so capture
could infer. This packet makes 034 real, then the
other leftovers.

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

Do not drop `assets_telegram_file_unique_id_key` yet.
038 still infers if we roll back.

**STOP for 1d.** Owner phone. Both cases separately.
Then 043. Then P2.

### Prove (1d) — both cases, separately

**Same owner, photo already stored.** Duplicate check
finds the row (`owner_id` match). Duplicate terminal.
Not a second asset.

**Same file_unique_id, different owner.** Duplicate
check misses (other tenant's row). Insert proceeds.
While 038 column unique still exists this INSERT
raises unique_violation — that is why 043 waits.
After 043: stores under the caller `owner_id`.

A **new** photo (fresh `file_unique_id`) must store
under the caller before 043. That is the inference
prove for the composite `ON CONFLICT`.

## P1c — 043

Drop `assets_telegram_file_unique_id_key` only.
Keep `assets_owner_id_telegram_file_unique_id_key`.
Dependents check (034 shape). 030 stays Phase 6.
Not applied in P1.

## P2 / P3 / P4

Not this PUT.
