# Packet 14.0 — remainder (not Phase 13)

**Date:** 17 Sep 2026
**Status:** applied except A3 owner voice prove.
No canvas. Rollback named before each PUT.
**Home:** this file. Also `phases.md`, `docs/sessions/session-12-multitenancy.md`.

Phase 13 (enrichment read path) is **out**. `person_emails`
(12.3), `entity_candidates` review (12.4), and the login
surface (12.6) stay architect-design. C2 is cause +
proposed fix only — not built.

## A — B5 fixture

**A1.** Root cause: Extract recipient returns nothing on
brief "Follow up with Probe about the demo." Whisper was
fine. Tenant 2's two people (`de10f49f` D3probe,
`7cee0027` NIS mailbox prove) are not name-shaped, so
the extractor cannot yield a `recipient_ref` and Lookup
people never runs. **Fixture defect, not code.** Extract
recipient was not changed.

**A2.** Catalog **044_tenant2_name_shaped_person**
(`20260917093452`). One person on the tenant that owns
`events.name = 'NIS test tenant'` AND has `bot_state`.
`full_name` Sara Alharbi. Email on `example.invalid`.
`typed_note` / `approved` / `linkedin_source=card`.
Idempotent on `full_name`. Does not touch `de10f49f` or
`7cee0027`. 030 stays Phase 6. Owner uuid is resolved,
never hardcoded.

**A3.** Owner prove on account 2: `/followup`, voice
"follow up with Sara about the demo", `/done`. EXPECT
the keyboard. **Not run this pass** — implementer cannot
speak on the device.

SQL simulation of Lookup people voice (`recipient_ref` =
`sara`, threshold 0.25, owner = NIS test tenant):
one row, Sara Alharbi `d62b48f7`. No other tenant-2
name. Live-owner names are not in that result.

Lookup people predicate: `JOIN p.owner_id = norm.owner_id`.
Bound owner is `$2` (typed) / `$3` (voice) =
`$('Normalize input').first().json.owner_id`.

If a live-owner name appears on the keyboard: delete the
tenant-2 `bot_state` row first, then STOP.

## B — copy and config

### B1 sweep (Telegram / Gmail strings, before PUT)

User-facing product strings found. Internal identifiers
(`LNI WF-*` names, `cachedResultName`, `lni_instance`,
bucket `lni-assets`, SQL identifiers) stay LNI (D-N).

| WF | Node | String | Action |
|---|---|---|---|
| 00 | Telegram owner alert | `LNI repeated failure` | → NIS |
| 01 | all Telegram senders | `reply_text` expressions only | none |
| 02 | (no Telegram/Gmail send) | — | none |
| 07 | Compose digest | `LNI day close` / `LNI morning briefing` | → NIS |
| 07 | Gmail digest subject | same two titles | → NIS |
| 09 | Compose findings | `LNI watchdog` | → NIS |
| 09 | Gmail alert subject | `LNI watchdog` | → NIS |
| 10 | History evidence | `LNI does not send on this channel.` | → NIS |
| 10 | Compose no person / no match | see B2 | B2 |

### B2 — F3 typed `/followup` lie

WF-01 discards the `/followup` argument and opens a
block. "Try `/followup` with a name or email" is false.
**Copy changed, wiring not.** Capture-block model stays.

Applied wording:

`No person matches that note. Inside /followup, send a voice note that names the person, then /done.`

On `Compose no person` and the voice/cap branch of
`Compose no match`.

### B3 — Followup payload orphan

Deleted on WF-01. Rollback `0c9c5a5d`. `Call WF-10`
kept (Callback payload / Followup done payload).
129 → 128 nodes. Reachable 128/128.

### B4 — Supabase project ref (record only)

Literal project host is concatenated in:

- WF-01 `Upload to Storage`
- WF-01 `HEAD object`
- WF-10 `GET attach 0/1/2`, `Fetch audio bytes`,
  `Fetch block audio`, `History GET photo`

Not moved. Phase 14 needs a design decision (config vs
`lni_instance` vs credential URL).

## C — deferred defects

**C1.** Note-only `UNION ALL` extraction (already on
`Enqueue asset jobs`) added to `Enqueue sweep jobs`,
`Enqueue closed standard`, WF-09 `Enqueue orphan jobs`.
Six closed note-only captures had no extraction job
(#11 #24 #44 #70 #80 #161). Next orphan tick will
enqueue them. Capture-mode `followup` still skipped.

**C2. STOP — not built.** See below.

**C3.** WF-05 `Set capture status` now
`AND status IS DISTINCT FROM 'open'`. Writes ready /
needs_review only when the capture is not open.
`Mark resolution succeeded` still keys off Prepare
resolution (not the RETURNING), so a guarded zero-row
update does not flip an open capture.

**C4.** `interactions.person_id` NULL: **15** (drifted
from session-10's 8). All have a `capture_id`.
`person_hit` joined nobody. Do not backfill.

| capture | prefix | when | event |
|---|---|---|---|
| #42 | `08935b2f` | 28 Aug | live |
| #53 | `15495ba8` | 28 Aug | live |
| #59 | `fd7d1dba` | 27 Aug | live |
| #68 | `d3c3dde5` | 27 Aug | live |
| #84 | `18d0c63c` | 28 Aug | live |
| #151 | `2015bd72` | 31 Aug | live |
| #167 | `5b35f568` | 1 Sep | live |
| #202 | `3fd98690` | 5 Sep | live |
| #213 | `05e7a78d` | 16 Sep | live |
| #217 | `dcb5bc7c` | 16 Sep | tenant 2 |
| #218 | `af0c66e9` | 16 Sep | live |
| #219 | `efb62ff1` | 17 Sep | live |
| #220 | `2746f5cf` | 17 Sep | live |
| #221 | `f0e9049b` | 17 Sep | tenant 2 |
| #223 | `72bb9f2e` | 17 Sep | tenant 2 |

Recoverable if `extraction_runs.structured_output` still
names a person that `people` now holds. Several are
empty-summary contact/note leftovers. Propose: after C2
is designed, a **named** backfill packet joins extraction
JSON to `people` and updates only rows whose capture has
exactly one minted person and `summary` empty-or-present
as recorded. Not this packet.

`follow_ups.person_id` NULL: **14** (drifted from 7).
Six `cancelled` 28 Aug (no capture, channel NULL) —
dead command-path leftovers, not recoverable as people.
One live-owner `draft` on #204. Seven tenant-2
incomplete `/followup` drafts (#223 #225 #226 #227
#231 #233 #234) — B5 retries with no recipient; drop
or leave as abandoned drafts after A3. Do not backfill.

**C5.** Six `sent` follow_ups with `channel` NULL, all
pre-031, all with a Gmail message id, all live owner:

`2ea079a3` `e5bf5982` `bb3689d8` `18a40724` `a8dc84ea`
`4c58b08a`.

They sit outside `follow_ups_person_channel_live_uniq`
because that unique is on `(person_id, channel)` where
channel is NOT NULL. Propose (do not run):

```
UPDATE follow_ups
SET channel = 'email'
WHERE draft_state = 'sent'
  AND channel IS NULL
  AND coalesce(gmail_message_id, '') <> '';
```

## C2 — S6 cause (STOP, do not build)

**Cause.** WF-05 `Insert interaction`:

1. `person_hit` joins `jsonb_to_recordset($3)` to
   `people` and **`LIMIT 1`**.
2. INSERT is `WHERE NOT EXISTS (interactions for this
   capture_id)`.

One interaction per capture. First join hit wins.
`Upsert people` still mints everyone else. Second and
later people on a multi-person extraction get a `people`
row and no `interactions` row. Session-09 #153 is that
family. S9 is the same guard firing on replay: a NULL
`person_id` interaction already occupies the capture, so
the later minted person never links.

**Proposed fix (not built).** Drop capture-level
`NOT EXISTS`. Insert one interaction per extracted
person (`INSERT … SELECT` from the recordset, no
`LIMIT 1`), unique on `(capture_id, person_id)`. Add
that unique before the INSERT. `company_hit` must move
inside the per-person loop. Downstream that assumes
one interaction per capture (digest joins, `/ask`,
deferred follow-up load) must be re-read first.

This is entity resolution on the capture path. Architect
reads the design before it is built.

## D — handed_off backfill (do not run)

61 rows `draft_state='gmail_draft'`:

| bucket | n |
|---|---|
| email + `gmail_message_id` present | 22 |
| email, no gmail id | 1 |
| whatsapp | 29 |
| linkedin | 9 |

The 22 are real mailbox drafts. The other **39** are
composed-not-in-a-mailbox and are mislabelled.

**Predicate (architect approves first):**

```
UPDATE follow_ups
SET draft_state = 'handed_off'
WHERE draft_state = 'gmail_draft'
  AND (
    channel IN ('whatsapp', 'linkedin')
    OR (channel = 'email' AND coalesce(gmail_message_id, '') = '')
  );
```

Leaves the 22 Gmail drafts alone. 29+9+1 = 39.

## PUTs

| WF | rollback | published | what |
|---|---|---|---|
| 00 | `be1e7b71` | `86b51053` | B1 Telegram |
| 07 | `ca2f3d35` | `b9bd519c` | B1 digest titles |
| 09 | `ffbb20e4` | `b3dedb40` | B1 watchdog + C1 orphan UNION |
| 02 | `d7205734` | `f35f1b3d` | C1 sweep + closed standard UNION |
| 01 | `0c9c5a5d` | `a1738536` | B3 delete Followup payload |
| 10 | `8e170e68` | `465a037a` | B1 History evidence + B2 copy |
| 05 | `12b9e2bc` | `743c7c78` | C3 status guard |

GET name first. `sanitize_for_put` from `activeVersion`.
No canvas. Survival: `errorWorkflow` WF-00 (except WF-00
itself), timezone `Asia/Riyadh`, `availableInMCP` true,
`LEAP 2026` count 0, no `language` on Transcribe.

## Not in this packet

- Phase 13 enrichment read path
- 12.3 `person_emails`
- 12.4 `entity_candidates` review
- 12.6 login surface (first exercise of the 20 RLS policies)
