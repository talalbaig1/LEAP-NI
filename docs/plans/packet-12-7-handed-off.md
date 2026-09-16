# Packet 12.7 — `handed_off` + Driver ingest

**Date:** 16 Sep 2026
**Status:** applied (migration + WF-10). WF-01 PUT last, alone.

Order: 040, then WF-10, then WF-01. Lowest blast
radius last is wrong here — WF-01 is the capture
router.

## Rollbacks named before any change

| WF | published at GET | top-level versionId |
|---|---|---|
| WF-10 | `<WF10_ROLLBACK_12_7>` | same (no unpublished draft) |
| WF-01 | `<WF01_PUBLISHED>` | `<WF01_DRAFT>` unpublished |

## 040

`040_follow_ups_handed_off` catalog `20260916114531`.
Adds `handed_off` to `follow_ups_draft_state_check`.
Keeps every existing value. No backfill. Unique
`follow_ups_person_channel_live_uniq` unchanged
(`<> 'cancelled'` already treats `handed_off` as live).
030 stays embeddings.

## WF-10

PUT from `activeVersion` `<WF10_ROLLBACK_12_7>`.
`History copy insert` → `handed_off` (WA, LinkedIn,
mailbox-unlinked email). `History insert` keeps
`gmail_draft`. Published `<WF10_PUBLISHED_12_7>`.
No unpublished draft.

`gmail_draft` = a real Gmail Draft exists.
`handed_off` = composed-and-handed-to-the-owner,
channel-agnostic.

Reader sweep after PUT: no published WF-00…WF-09
node equals `'gmail_draft'`.

## WF-01 (last, alone)

PUT from published `<WF01_PUBLISHED>`, not draft
`<WF01_DRAFT>`. The PUT **discards** `<WF01_DRAFT>`.
Unavoidable and authorised. Guarded since Phase 10
because it must never be published. It was not
published. Remove `Driver ingest` and its
Allowlist connection. Nothing else.

## leftover_processing

Capture `#217` `6bcc2fe1` **spent** (`needs_review`).
Not replanted.
