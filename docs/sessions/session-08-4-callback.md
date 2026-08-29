# Session 08.4 — callback capture_id from the follow_ups row

**Date:** 29 August 2026
**Packet:** 8.4. **WF-10 only.** Highest priority.
**WF-01 stayed `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` (131, active).**
**Do not merge** PRs #54, #55, #56, #57.
**Do not touch** `5df341f8-e39a-4924-9d96-a5acf599be11`.

This is the same failure as the 7.8 brief loss, the unmatched_requests
drop, and the Reload brief miss — state inferred from the execution
instead of read from the row. Fifth instance.

---

## Why the picker is broken on the phone

WF-01 Callback payload (028, live, re-GET) is:

```
{ owner_id, correlation_id, source: 'callback', callback_data, text: '' }
```

No `capture_id`. The owner's phone sends that shape. Packet 8.2 proof 2
already recorded it: `f7:p:` in that shape errors at **Load candidate
assets 20** `invalid input syntax for type uuid: ""`. That was marked
pre-existing. It is pre-existing **and live**.

No `follow_ups` row has `capture_id` set (27 rows, `with_cap=0`). The
picker path has never been exercised with real data under this design.

---

## PUT

One REST PUT on WF-10. Rollback `84bcbfdf-4728-401b-8152-2a3ebfa2f1ef`
(140 nodes). Live after PUT: `b9a5a890-7422-4537-92e8-42bfb0baf3cc`
(142 nodes, active). Postgres cred `zzFzIzjYqRw0dvoE` (Leap-NI) on the
new node. WF-01 was not PUT.

1. **Normalize input** — if `source==='callback'`, force `capture_id`,
   `asset_id`, `storage_path`, `file_id`, `kind`,
   `awaiting_followup_id` to `''`. The inbound payload is not a source
   of those fields on a callback.
2. **Load callback follow_up** (new Postgres, after Parse callback) —
   exact `id` for `s`/`n`/`x`; for `p`, latest
   `draft`/`awaiting_voice`. Does not match `5df341f8`
   (`awaiting_confirm`) on pick.
3. **Bind callback row** (new Code) — merge Parse fields with the row.
   `capture_id` / `follow_up_id` from the row only. NULL row
   `capture_id` becomes `''`.
4. Wire: Parse callback → Load callback follow_up → Bind callback row
   → Route callback. Route still reads `$json.cb_kind` (Bind copies
   Parse).
5. **Load candidate assets 20** — `a.capture_id = NULLIF($3::text,'')::uuid`
   behind `NULLIF($3::text,'') IS NOT NULL`. `$3` from Bind on
   callback, else Normalize (voice/command). Empty / NULL never
   reaches a bare uuid cast.
6. **Reload brief** — same `NULLIF` on `$2` (capture) and `$3`
   (follow_up id).
7. **Insert draft / Update draft** — `capture_id` from Bind on
   callback, else Normalize.

A follow_ups row with `capture_id` NULL falls back to the person-linked
candidate query only, and must not throw.

---

## Callback-path audit

Anything that could read `capture_id`, `person_id`, `brief`, `source`,
or asset ids from the inbound payload rather than from the row:

| Node | What it read | Action |
|---|---|---|
| Normalize input | `capture_id`, `asset_id`, `storage_path`, `file_id`, `kind` from payload | **CHANGED** — blank those on callback |
| Parse callback | copies Normalize (including `capture_id`) | Unchanged. Safe after the blank. `cb_target` is the uuid in `callback_data` (person for `p`, follow_up for `s`/`n`/`x`) |
| Load callback follow_up | — | **NEW** — row is source of truth |
| Bind callback row | — | **NEW** — `capture_id` from row only |
| Load picked person | `cb_target` as person id | Unchanged. Correct: `f7:p:` uuid is the person |
| Load candidate assets 20 | Normalize `capture_id` into `$3::uuid` | **CHANGED** — Bind/row + `NULLIF` |
| Reload brief | Normalize `capture_id` + bare uuid compares | **CHANGED** — Bind/row + `NULLIF` |
| Insert draft / Update draft | Normalize `capture_id` | **CHANGED** — Bind/row on callback |
| Resolve brief | Reload brief row (`brief`, `person_id`, id) | Unchanged. Already the row |
| Format candidates | assets query items | Unchanged |
| Voice source? | Normalize `source` | Unchanged. Call kind, not row state |
| Need voice wait? | Parse argument `brief` (absent → `'x'`) | Unchanged. Not payload capture_id |
| Claim send / Cancel draft / Load draft state | `cb_target` as follow_up id | Unchanged. Correct for `s`/`n`/`x` |
| Compose confirm | draft write + Parse extract | Unchanged |
| Has capture_id? / Load followup capture / Load block audio / Insert C3 draft / Insert brief draft | Normalize `capture_id` | Command / sweep only. **Not changed** |
| Compose no match | Normalize `capture_id` | Not on the callback pick path. **Not changed** |
| Map sweep markup / Send sweep * | sweep reply_markup | Sweep path. **Not changed** |

---

## Proofs (TEST driver, WF-01 callback shape, no `capture_id` in payload)

TEST driver `iqAx0KwCsTbb32BY` activated for proofs, then deactivated.
Window: after 07:10 Riyadh (WF-07 briefing).

| # | Result | Evidence |
|---|---|---|
| 1 `f7:p:` with row `capture_id` set | pending | confirm card + buttons |
| 2 `f7:p:` with row `capture_id` NULL | pending | no throw; person-linked only |
| 3 `f7:s:` / `f7:n:` / `f7:x:` | pending | same payload shape |
| 4 sweep-path card | pending | unchanged |
| 5 GET WF-01 | `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` | re-GET before PUT and after |

---

## Cleanup

Packet artefacts only. Locked R3 rows untouched. `5df341f8` untouched.
Counts after cleanup must match the 8.2 baseline:

| metric | before 8.4 | after cleanup |
|---|---|---|
| captures | 72 | pending |
| processing (captures.status) | 17 | pending |
| max capture_no | 87 | pending |
| people | 29 | pending |
| jobs | 236 | pending |
| follow_ups | 27 | pending |
| assets | 78 | pending |
| interactions | 55 | pending |
| fu with capture_id | 0 | pending |
