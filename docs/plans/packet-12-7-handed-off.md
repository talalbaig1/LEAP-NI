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
published. Removed `Driver ingest` and its
Allowlist connection. Nothing else. DIFF: exactly
one node + one connection. TriggerCount 2 → 1.
Still ACTIVE. Published `<WF01_PUBLISHED_12_7>`.
No unpublished draft. POST old URL 404.

E2: TEST caller `<TEST_127_HIST_CALLER_WF_ID>`
(archived after). WF-10 **487150** History copy
insert `574a78ba` `draft_state=handed_off`
channel linkedin. G4 email row `03928fb8` stays
`gmail_draft` (no backfill; unique blocked a
second email).

E1 owner phone after the PUT is owed.

## leftover_processing

Capture `#217` `6bcc2fe1` **spent** (`needs_review`).
Not replanted.

## 12.7b — destination-less WF-09 kick (no PUT)

Planted a second `#217` `card_vision` fixture the
same way as 12.6 C2 (synthetic bytes, owner-prefixed
path, `queued`, `attempt_count` 0). Then nothing:
no `/done`, no MCP execute, no TEST caller. Two
WF-09 ticks waited.

**PASS. Not a 12.8 blocker.** Kick and alert are
independent. Destination-less did not skip the kick.

| What | Live |
|---|---|
| Plant | 12:02:41Z. Job `af6c0217` `queued` 0. Asset `daabf581` `kind=photo` `stored` 7111 B. TEST `<TEST_127B_PUT_WF_ID>` exec **487227** archived. |
| WF-09 **487322** | 12:15:00Z Watchdog schedule. Test-tenant Compose: `finding_count=2` (`failed_24h` `7c72371f` + `stuck_queued` `af6c0217`), `kick_needed=true`, `call_wf03=true`, `chat_id=''`, `owner_email=''`. **Kick needed?** TRUE. **Call WF-03** subExecution **487324**. Then **Any destination?** FALSE → **Alert no destination**. |
| WF-03 **487324** | When called. Parent WF-09 **487322** (Watchdog schedule), **not** WF-02. `Claim queued jobs` `af6c0217` owner `<TEST_TENANT_ID>`. lastNode `Siblings still running`. `image_type=other` — no extraction. |
| WF-02 **487325** | 12:15:02Z, after the kick 12:15:00.891Z. Did not claim this job. |
| WF-09 **487437** | 12:30:00Z second tick. `stuck_queued` 0, `kick_needed=false`, no Call WF-03. **Alert no destination** still (`failed_24h` only). |
| Rows | Inserts: asset `daabf581` + job `af6c0217`, both `<TEST_TENANT_ID>`. Job then `succeeded` attempt 1 at 12:15:05Z. No extraction / ER / people / interactions / follow_ups / audit_log. Live owner **0** new rows. |
| Live owner | Unchanged 199 / 540 / 74 / 128 / 153 / 83 / 111. |
| Test tenant | `bot_state` 0. `lni_settings` 0. |

E1 owner phone after the WF-01 PUT is still owed.
C1 still owed. No test-tenant `bot_state`.
