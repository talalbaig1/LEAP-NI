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

## 12.7b RESULT — traces retrieved 17 Sep ~04:46Z (before prune)

None of 487322 / 487324 / 490614 / 494770 were
pruned. `audit_log` since plant is empty (no
`watchdog_alert` write — Alert no destination does
not insert; Silent clean does not insert).

SQL still: `af6c0217` `succeeded` 12:15:05.834871Z
owner `<TEST_TENANT_ID>` attempt 1 `image_type=other`.

Live-owner counts still match the 12:02 plant:
199 / 540 / 74 / 128 / 153 / 83 / 111.
Live owner: 0 new assets / jobs / people /
interactions / extraction_runs / entity_candidates /
follow_ups. 0 job transitions.

### WF-07 first per-owner fan-out since 12.4b

Hourly tick, timezone `Asia/Riyadh`. `List due
owners` returns **only** `<OWNER_ID>` (test tenant
has no `bot_state` — invisible). Test tenant: no
chat, no mail.

| Exec | Local | kind | Telegram | Gmail |
|---|---|---|---|---|
| **490614** 19:00:00Z | 22:00 close | `kind=close` | `message_id` 1053 | id `1a0ab971b896e3ea` SENT |
| **494770** 04:00:00Z | 07:00 brief | `kind=brief` | `message_id` 1054 | id `1a0ad857e3ee1751` SENT |

Close body: captured 5 · clean 3 · flagged 2
(#213 #218 `needs_review`). Brief: people 43 ·
companies 26 · unreviewed 73 · stuck 4.

### WF-09 overnight

67 ticks 12:15Z–04:45Z inclusive, all `success`,
none pruned. Only WF-03 after the plant is
**487324**. Sampled 12:45 **487551**, 19:00
**490615**, 04:00 **494768**, 04:45 **495112**:
test tenant `failed_24h` 1 (`7c72371f`)
`kick_needed=false` → Alert no destination (no
send). Live owner `finding_count=0` Silent clean.
No alerts sent. Silence recorded.

E1 owner phone after the WF-01 PUT is still owed.
C1 still owed. No test-tenant `bot_state`.
