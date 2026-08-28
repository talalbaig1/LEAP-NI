# Packet 7.12-FIX — await-window candidates + unmatched on callback

**Date:** 28 August 2026
**Status:** APPLIED. WF-10 `f1013395-…` (109 nodes). Rollback
`5b3d2913-…`. **WF-01 is not touched** (`864bcb8b-…`, 128 nodes).

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

## Prove (TEST `ygHqk6TGlXq7wJvd`, then deactivated)

Owner `bot_state` was unset at start; restored unset. Prove drafts
cancelled. Temp interaction `0f3e6395` (prove 4) deleted.
`ae2b9d7a` cancelled (empty attachments, not sent).

1. **Callback + await-window photo.** Row `54764c7c` backdated
   `created_at` 19:44:53Z, brief "attach this photo". Exec
   **273170** `source=callback` `f7:p:9489be75`. Load 20: asset
   `8cfa042b` capture **#85** `source=this_session`. Extract
   `selected_asset_ids: ["8cfa042b-…"]`, signed Talal. Card
   `Attachments: 8cfa042b-…-AQADqxFrG_nwkVB-.jpg`. LIMIT-3 node
   did not run.
2. **Callback unmatched.** Row `c2ad40bc`, brief names "whiteboard
   video we never took", await armed after every stored photo.
   Exec **273179**. Card: `Attachments: (none)` and
   `Could not match: the whiteboard video we never took`. Send
   buttons present. `ok` true.
3. **No photo named.** Row `ce4af397`. Exec **273184**. Card:
   `Attachments: (none)`, no `Could not match:`, no throw,
   signed Talal.
4. **Linked still a candidate.** Temp interaction on prove person
   `ec5dc966` → capture **#68** photo `60574f89`. Exec **273190**.
   Load 20: `source=linked`. Card attached that filename. To =
   owner `talalbaig@gmail.com`. Interaction deleted after.
5. GET WF-01 `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd`, 128 nodes,
   unchanged. WF-10 `f1013395-…`, 109, active. Transcribe
   `language` still absent.

Owner phone (`/followup` → photo → voice on the bot) is the
store-first capture of the same path. TEST used the real #85
photo and the callback extract that 7.12-R failed. Await is
clear so the owner can run it.

## Rollback

WF-10 `5b3d2913-fee6-4e5f-bc37-aa0a55d7cc08`.
