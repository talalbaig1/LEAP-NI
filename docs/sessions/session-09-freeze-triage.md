# Session 09 — freeze triage (30 Aug 2026)

Implementer window. First message was the session-09 handover,
not a "capture is broken" packet. No PUT. No SQL write. No
migration. Architect accepted the stop (PR #70 read-back).
PR #69 merged. Phone prove landed. Incident closed.

## Verdict

**Capture is not broken.** Retired by owner phone at 06:26Z:
#146 stored and closed. Freeze from 00:00 Riyadh tonight.

## Draft vs published — 05:20 was not a PUT

Owner opened the WF-01 and WF-06 canvases to move nodes.
n8n autosaved a draft. Zero connections changed. No node
added or removed. GET top-level `versionId` is that draft.
Published id is `activeVersionId`.

| WF | draft `versionId` | published `activeVersionId` | updatedAt |
|---|---|---|---|
| 01 | `e454df40-cc92-4a06-ba52-31fc0d1594c8` | `4836ffd8-10e3-4d8c-963d-42bf0ccb9372` | 05:20:14Z |
| 06 | `76840a2a-3d4f-454e-86ff-0f70bca48ca1` | `356a2d1f-daf1-4560-a68f-4df82ff64ceb` | 05:21:01Z |

**Never publish either draft.** Autosave also stripped
explicit params that equal node defaults (`download:true`
on getFile vcard, `batchSize:1` on WF-06, …). None has
run on a device. If either draft id changes, STOP.

An unexpected top-level `versionId` on this build does
not imply an API write.

## GET / PUT

`sanitize_for_put` takes `nodes` / `connections` from
`activeVersion` when the workflow is active. Top-level
on an active workflow raises. Helper:
`/tmp/lni716/n8n_util.py`. Recipe also in
`cursor-handover-to-session-09.md` §1.

## Tool gap — WF-01 execution search

MCP `search_executions(workflowId=WF-01)` returns empty
despite known execs (279617). Architect confirmed and
withdrew a "no WF-01 execs today" read from that tool.
WF-01 liveness cannot be proven from execution search.
Phone only.

## SQL (read-only)

Same as 9.11: captures 80, max `#136`, people 30, assets 91,
follow_ups 30, open 0, queued 0, awaiting **2** (`5df341f8`,
`6f3c13b3`), sent 3, audit `followup_sent` 4.

## Standing

No workflow PUT unless a packet says so. Do not revert or
publish drafts `e454df40` (WF-01) / `76840a2a` (WF-06).
Do not PUT to make draft `versionId` match `activeVersionId`.
Freeze lifted 5 Sep. Event closed 2 Sep. Phase 10 packets
only.

## Incident closed — WF-01 trigger proven live (30 Aug 06:26Z)

Owner ran `/new` + photo + `/done` on his phone after the
05:20Z canvas autosave. Architect verified from live SQL.

- Capture **#146** `standard` / explicit / `ready`
  opened `06:26:04Z`, closed `06:26:19Z`
- 1 asset stored, 162,612 bytes, `storage_path` set
- `card_vision` succeeded → extraction succeeded →
  entity_resolution succeeded → enrichment queued
- assets 92, not-stored 0, people 30 → 31
- WF-01 / 02 / 03 / 04 / 05 ran on the **published**
  versions. Drafts `e454df40` / `76840a2a` stayed
  unpublished. Do not touch them.

**Locked evidence — never edit or delete:**

- capture **#146** and its asset
- person Talal Mirza M. Baig (owner's own card,
  deliberate test row)

This is the proof that capture survived the 30 Aug canvas
write. Not test pollution. Leave the queued enrichment
job to drain; 1 Apollo credit against the 60/day ceiling.

Freeze in force from 00:00 Riyadh tonight.

---

# September — contact "0 items" (2 Sep 2026)

Live-event diagnosis. Owner reported contact cards showing
"0 items". Architect authorised cause-only, then accepted
the diagnosis in full. No PUT. Freeze holds. Capture is
not broken. No data lost.

Architect error recorded: the contact-inside-an-open-block
hypothesis was wrong. #155 was an empty `/new`…`/done`
block (opened 15:46:22Z, closed 15:46:27Z, typed_note NULL,
0 assets). The contact 53s later landed on followup #156.

Verified independently: #160 person is Ahmad Alnasser
`<ahmad.alnasser@fathom.io>` `source_type=shared_contact`.
#161 typed_note `"He is from fathom.io"` retained.
Published WF-10 `97fd7181` contains zero `UPDATE captures`.

Stand down until 4 Sep.

## S1 — `/done` item_count is assets only

`Action done` `item_count = COUNT(assets)`. Contacts and
typed notes are not assets, so a note-only or contact-only
capture always reports "0 items" while holding real data.

Extends known issue #4.

Worked contacts #134 #135 #160 #172 never stored an asset.
They reached `ready` via `ingest_contact` → ER job →
WF-05 `Set capture status`. `close_reason` NULL.
`closed_at` NULL. Receipt on that path is
`Contact saved · #<n> · <name>`, not the `/done` line.

## S2 — NEW ROOT CAUSE. Stale `open_capture_id` after contact ready

`bot_state.open_capture_id` is not cleared when
`Action ingest_contact` creates a capture that WF-05 then
flips to `ready`. `Action resolve_target` `existing` CTE
requires `c.status = 'open'`, so the next message opens
and strands on a new empty capture.

This produced #161. It is what the owner experienced as
the contact "failing".

Live:

| t (Z) | exec | what |
|---|---|---|
| 13:26:19 | WF-01 **317924** Route type[6] contact → lastNode `Contact reply sent` | `Contact saved · #160 · Ahmad Alnasser` (msg 641) |
| 13:26:19 | WF-02 **317925** `Action ingest_contact` | `reused=false` `adopted=true` `should_resolve=true` lastNode `Ingest terminal` |
| 13:26:20 | WF-05 **317926** `Set capture status` | #160 `status=ready`. Does not clear `open_capture_id`. |
| 13:26:38 | WF-01 **317928** Route type[4] text → lastNode `Note done terminal` | `Opened capture #161 (nothing was open — adopted)` (msg 643) |
| 13:26:38 | WF-02 **317929** `Action resolve_target` | `adopted=true` — #160 was `ready`, not `open` |
| 13:26:41 | WF-01 **317931** Route type[0] `/done` → lastNode `Command sent terminal` | `✓ Capture #161 saved · 0 items` (msg 645) |
| 13:26:41 | WF-02 **317932** `Action done` | `item_count=0` `kick_wf10=false` lastNode `No jobs enqueued` |

Contact person stayed on #160. Typed note stranded on #161.

WF-01 contact/vcard path does not inspect an open capture.
`Route type` [6] → `Contact payload`. [9] →
`Telegram getFile vcard`. Open-capture reuse is only
WF-02 `Action ingest_contact` (`status='open'`).

## S3 — Typed-note-only captures never extract

Typed-note-only captures closed by `Action done` enqueue
0 jobs. WF-05 never runs. Note is retained on the row
and never extracted.

Affects **#161 #80 #11 #24 #44**. Predates the event.

## S4 — Audio-only followup stuck at `processing`

Audio in a followup block correctly gets no job:

```
AND NOT (c.capture_mode = 'followup' AND a.kind = 'audio')
```

Nothing then advances `captures.status`. WF-05 `Set capture
status` only runs after an `entity_resolution` job.
Published WF-10 `97fd7181` writes no capture status
(zero `UPDATE public.captures`).

#150 and #164: one stored audio, 0 jobs, `close_reason=
explicit`, stuck at `processing`.

#164 proven: WF-01 **320268** `/done` → `Kick WF-10?` TRUE
→ WF-02 **320269** `Followup done terminal` (`item_count=1`,
enqueue `{success:true}` empty) → WF-10 **320270**
`source=done` transcribed, picker "Multiple matches…",
lastNode `Return to caller`. WF-10 ran. It did not flip
the capture. Picker is not a terminal capture state.

Photos in a followup can still reach `ready` via ER
(#120, #156). Audio-only cannot.

## Execution store prune — standing constraint

n8n execution store is pruning at roughly **24–36 hours**.
The `2026-08-31T15:46Z` window is gone entirely.
`search_executions` empty with and without `workflowId`.
`get_execution` of audit ids 307806 / 307808 → not found
on WF-01 and WF-02.

`audit_log` was the only recovery path and it worked
(#155 = `capture_new` 307806 then `capture_done` 307808).

Execution forensics have a short window during the event.
Do not treat a missing execution search as "it never ran".
Read `audit_log.after.execution_id` first, then try
`get_execution`. If both miss, the SQL row is the proof.

The 30 Aug "MCP `search_executions(workflowId=WF-01)`
returns empty" tool gap is a different, earlier defect.
The 13:26Z window returned 317924 / 317928 / 317931 by
`workflowId`. Prune is the September constraint.

## Freeze

31 Aug 00:00 – 3 Sep 23:59 Riyadh. Capture is not broken.
No data lost. No fix. No PUT. Stand down until 4 Sep.

## S5 — Standing cleaned (10.2a)

`## Standing` is one paragraph: PUT/draft rules plus freeze
lifted. The spliced 30 Aug sentence and the 3 Sep stand-down
are gone.

## S6 — cause (10.2a). Do not fix. Do not INSERT.

Ahmed Alkaf `32c8efee-c0a9-4ef9-bac8-f645536d93af` is not
missing an interaction because WF-05 skipped the node.
`Insert interaction` ran on #153. It wrote **one** row,
`person_id` = Ali Abbas `4efe1828` (people[0], note, no
email). Ahmed is people[1] (`src=card`, blossommena).

Guard: `person_hit … LIMIT 1` plus
`WHERE NOT EXISTS (… i.capture_id = $2)`. One interaction
per capture. First join hit wins. Upsert people still
mints everyone else.

#153 is not the only case. **10** people have zero
`interactions` rows (67 people, 99 interactions):

| person | id | pattern |
|---|---|---|
| LNI No-Match Probe | `ad9c6cde` | probe |
| Faysal A. Ghauri | `a21a803f` | name-duplicate; interaction on earlier Faysal `c747ab72` |
| LNI Drain Prove 1/2/3 | `e9292eeb` `4a9f79af` `c2fb1ab7` | probes |
| **Ahmed Alkaf** | `32c8efee` | **#153 people[1]**; ix → Ali Abbas |
| Ali Abbas | `d887ab79` | #152 name-duplicate of `4efe1828` |
| أشرف | `39d9fffa` | **#170 people[1]**; ix → Ashraf Abu Elayyan |
| Mouaz Abdullah | `ac362f34` | **#171 people[1]**; ix → Muath Abuhilal |
| Mohamed Ousmane Fayaz | `412f5aa4` | **#176 people[1]**; ix → Muhammad Usman Fiaz |

Shared live pattern: second (or later) person on a
multi-person extraction, or a no-email name duplicate.
Probes are test rows. Cause only.

## 10.2c — STOP. No PUT.

Authorised: S7a WF-02 + S7b WF-04. Do not touch WF-05 /
WF-09 / WF-10 / WF-01. S3 completion and R4 clobber are
10.2d.

### New finding — `Set capture status` writes ready on `open`

Live WF-05 `68f47505` node `Set capture status`:

```
UPDATE public.captures
SET status = CASE
  WHEN COALESCE((
    SELECT count(*)
    FROM jsonb_array_elements_text(COALESCE($2::jsonb, '[]'::jsonb)) AS f(val)
    WHERE f.val IS DISTINCT FROM 'Non-Latin script present in the name field'
  ), 0) = 0 THEN 'ready'
  ELSE 'needs_review'
END
WHERE id = $1::uuid
RETURNING id, capture_no, status;
```

No `AND status = 'processing'`. No `AND status IS DISTINCT
FROM 'open'`. Packet said: if this can write ready on an
open capture, report it and **stop before building**.

This is how standalone contact already works (#134 #160:
ingest creates `open` → ER → `ready`, `close_reason` NULL).
It is fatal on a reused `/new` block: Call WF-05 mid-block
flips the still-open capture to ready; S2 then clears
`open_capture_id`; later photo / note / `/done` strand.

Logged as **S8**. Do not fix in this packet.

### Authorised 5 Sep — kick-split + WF-04 both-branch Call

### How the kick-split prevents it (built)

Do not touch WF-05. Split enqueue from kick:

- `should_resolve` = `(capture_mode IS DISTINCT FROM
  'followup') AND NOT EXISTS (entity_resolution job)`
  — drop `NOT reused`. This only **inserts** the ER job.
- `Call WF-05 contact` only when `should_resolve AND NOT
  reused` (T1 standalone). Open→ready stays the contact-only
  close.
- Reused (T2 / T3): enqueue, do not call. Capture stays
  `open`. `/done` with assets → WF-03 → WF-04 `wf04-v6`
  merge → existing `Call WF-05` claims the queued job
  **after** the new run exists. `/done` with no assets /
  no note → a WF-02 kick of WF-05 so contact-only reused
  still resolves.

T1 and T2 then do not double-create: one ER job, one
WF-05 run. T3 WF-05 reads latest = `wf04-v6`.

Contact-only reused `/done` with no assets does **not**
depend on 10.2d. `Gate: jobs enqueued` false →
`Call WF-05 done-er`. After 10.2d a typed note takes the
WF-04 path instead; that path now Calls WF-05 even when
the ER row already exists.

### WF-04 gate (proved before PUT, 28510930)

`Call WF-05` is **not** unconditional.

```
Enqueue entity_resolution  NOT EXISTS … RETURNING id
  → Gate: resolution enqueued
      id notEmpty → Call WF-05
      else        → Resolution already queued   (NoOp, no call)
```

A job already queued by ingest_contact makes NOT EXISTS
skip. Without a correction T3 creates nobody. Fix: both
gate branches → `Call WF-05`. WF-05 claims from Postgres.

### Merge rule (owner-confirmed)

WF-05 `ORDER BY created_at DESC LIMIT 1` stays.
WF-04 composes `wf04-v6` from asset jobs **plus** the
same-capture `contact-v1` run. Existing rows immutable.

| Field | Rule |
|---|---|
| email, phone | contact-v1 fills **NULL only**. Never overwrite. Never blank. |
| full_name | **never** overwritten by contact-v1. Differing contact name → `entity_candidates` suggestion `same_capture`, `contact_name_differs: "<contact>" vs "<asset>"`. Not a person. |
| title, company | fill NULL only. Same as email/phone. |
| no asset run | contact-v1 is the whole composition. S7a ER → WF-05 reads that only run. |

Telegram contact names are owner labels ("Fazal From
Bahrain…"). They become `full_name` only when they are
the only name. A cleaner asset-derived name is kept.

#156 owner-confirmed same man: v6 keeps asset/note name
`Rana Waleed`, fills `rana.waleed123@gmail.com` and
`0538584129` from contact-v1, suggests the contact label.

Replay of the 12 multi-run captures is a later authorised
step. Not this packet.

Rollback before PUT: WF-02 `201095c6`, WF-04 `28510930`.

### PUT 5 Sep (one each, from `activeVersion`)

| WF | rollback | new `versionId` = `activeVersionId` | nodes |
|---|---|---|---|
| 02 | `201095c6` | **`ce51e6f4-860e-4bc1-a640-a00c41e5c358`** | 95 → 97 |
| 04 | `28510930` | **`dafe9b02-4523-4936-9077-4bf975f998aa`** | 28 → 29 |

Settings unchanged. WF-05 still `68f47505`. T1–T4: owner's
phone. Not run from this VM. Do not replay the 12.
