# Packet 7.12-FIX — await-window candidates + unmatched on callback

**Date:** 28 August 2026
**Status:** TO APPLY. One WF-10 PUT. Rollback `5b3d2913-…`.
**WF-01 is not touched** (`864bcb8b-…`, 128 nodes).

Causes accepted from 7.12-R. Binding design is
`docs/plans/phase-07-6-voice.md` §4 (D1–D3). Do not apply from
memory.

## Causes (accepted)

Draft `ae2b9d7a` (19:44:53Z, `awaiting_confirm`,
`ahmed.eltohfa@veeam.com`): `attachment_asset_ids=[]`. Brief
named "attach this photo". Owner photographed during the await
window (asset `8cfa042b`, capture **#85**, `stored` photo). No
`interactions` row on #85 for person `9489be75`. Load candidate
assets (LIMIT 3, callback exec **272939**) returned zero.
Format candidates did not run. Extract returned
`selected_asset_ids: []` and
`unmatched_requests: ["photo from Leap event"]`. Parse extract
dropped unmatched because `source==='callback'`. Confirm card:
`Attachments: (none)`, no `Could not match:`. Failed **272935**
threw on `[Your Name]` (guard correct; signature line was empty).

## Change (WF-10 only)

**D1.** `Load candidate assets 20` SELECT is the UNION of
person-linked stored photo/selfie **and** stored photo/selfie
whose capture opened at or after the armed `follow_ups.created_at`
(via `bot_state.awaiting_followup_id`, `draft_state='awaiting_voice'`).
Deduplicate. Tag `source=linked` / `source=this_session`. LIMIT 20.
Send cap 3. `Need voice wait?` false → Load 20 (callback and
typed-with-brief). Format candidates always runs on extract.
Do not widen (b) to recent-by-clock.

**D2.** Parse extract copies `unmatched_requests` and honors
`selected_asset_ids` on every path, not only `source==='voice'`.

**D3.** Extract user message includes `Owner name: Talal`. Guard
unchanged.

## Prove

1. `/followup`, photo in the window, voice "attach this photo".
   Confirm card shows THAT filename. Asset id + capture_no.
2. Same flow naming something never photographed. Callback path.
   Card shows `Could not match:` AND still offers the draft.
3. No photo in the window, brief names nothing. `Attachments: (none)`,
   no `Could not match:`, no throw.
4. A person-linked asset is still in the candidate list
   (`source=linked`).
5. GET WF-01: `864bcb8b-…`, 128 nodes, unchanged.

Then cancel draft `ae2b9d7a`. Evidence; do not send.

TEST `LNI-TEST-WF10-voice-exec` `ygHqk6TGlXq7wJvd`: activate, curl,
deactivate. Snapshot/restore owner `bot_state`. Do not steal
`becb0e07-…`.

## Rollback

WF-10 `5b3d2913-fee6-4e5f-bc37-aa0a55d7cc08`.
