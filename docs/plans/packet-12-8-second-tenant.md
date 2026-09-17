# Packet 12.8 — second tenant `bot_state`

**Date:** 17 Sep 2026
**Status:** gated. PART 0 recorded. 041 **not
applied**. `bot_state` count still 1.

IRREVERSIBLE. A cross-tenant leak cannot be
un-shown. No PUT. No canvas. No fixture cleanup.
No backfill.

This is slipped **12.2b**. Gate: job `7c72371f`
`last_transition_at + 24h` =
`2026-09-17 11:07:59Z`. Do not start early.

## 12.8-pre (agreed keep-list)

Keep every row. Resolve the alert by **waiting**,
not by mutating `7c72371f`.

| Row | Decision |
|---|---|
| job `7c72371f` | KEEP. Wait until aged out of `failed_24h`. |
| job `78371b74` | KEEP. `needs_review` is not a finding. |
| job `af6c0217` | KEEP. Terminal. |
| job `b47ddee0` | KEEP. Terminal. |
| capture `#217` | KEEP. `needs_review`, not leftover_processing. |
| assets `ed29a4a0` `daabf581` | KEEP. `stored`. |
| people `de10f49f` `7cee0027` | KEEP. |
| follow_ups `03928fb8` `574a78ba` | KEEP. |

## PART 0 — pre-flight 17 Sep 05:41Z

**0a. FAIL — do not start.** `now()` 05:41Z.
`ages_out_at` 11:07:59Z. `aged_out=false`.

**0b. PASS.** WF-01 **495534** (`/start`) and
**495535** (`Hi`) lastNode `Not allowlisted
terminal`. Allowlist returned `{}`. No send.
`audit_log` names no sender for those runs.

**0c. Control snapshot** (per `owner_id`):

| owner | cap | assets | jobs | people | inter | ER | FU | EC |
|---|---|---|---|---|---|---|---|---|
| live `<OWNER_ID>` | 153 | 201 | 544 | 74 | 129 | 154 | 111 | 83 |
| test `<TEST_TENANT_ID>` | 1 | 2 | 6 | 2 | 1 | 1 | 2 | 0 |

Live owner moved since 12.7b plant (#218 #219).
This table is the 12.8 control, not the 12:02
plant.

**0d. PASS.** `bot_state` count **1**. Owner
`<OWNER_ID>`, `mode=normal`, `open_capture_id`
NULL. Test tenant still 0.

## PART A — 041 (not applied)

`041_tenant2_bot_state`. GUC
`lni.tenant2_telegram_user_id` via
`current_setting(..., true)`. RAISE missing /
empty. Owner from `events.name = 'NIS test
tenant'`. Failed_24h guard inside the INSERT
path. Assert 034 unique still holds. After
apply: 2 rows, distinct owners, distinct
telegram ids. No `digest_email`.

Apply only after 0a. Same-session `SET LOCAL`
then the file. Telegram id is not in git.

## PART B — not started

B1 `/ask` from account 2 after the door exists.
B2 waits for architect wording. STOP at the
first leak → PART C (delete the tenant
`bot_state` row first).
