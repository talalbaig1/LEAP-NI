# Packet 12.8 — second tenant `bot_state`

**Date:** 17 Sep 2026
**Status:** PART A applied. B1/B2a/B7 verified
from executions. B2b waiting on account 2.
No PUT. No fixture cleanup.

IRREVERSIBLE. A cross-tenant leak cannot be
un-shown. No PUT. No canvas. No fixture cleanup.
No backfill.

This is slipped **12.2b**. 0a wait **withdrawn**:
job `7c72371f` is a real `failed_24h` finding and
is the B7 probe. Do not age it out.

## 12.8-pre (agreed keep-list)

Keep every row. Do not mutate `7c72371f`. It is
the B7 `failed_24h` finding.

| Row | Decision |
|---|---|
| job `7c72371f` | KEEP. B7 finding. Do not mutate. |
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
Owner confirmed the sender is his own second
personal Telegram account
(`<TENANT2_TELEGRAM_USER_ID>`). Telegram
`first_name` at 0b was ElderWise — that is the
**account label**, not the ElderWise project
reaching LNI. Renamed after 0b to
`<TENANT2_DISPLAY_NAME>`. 0b/0c/0d accepted.

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

## PART A — 041 applied 17 Sep 06:01:42Z

Catalog `041_tenant2_bot_state` `20260917060142`.
GUC `lni.tenant2_telegram_user_id` via
`current_setting(..., true)` in the same session.
Owner from `events.name = 'NIS test tenant'`.
Telegram id is not in git.

**A3.** `bot_state_telegram_user_id_key` and
`bot_state_owner_id_telegram_user_id_key` both
present.

**A4.** 2 rows. Distinct owners. Distinct telegram
ids. Test `<TEST_TENANT_ID>` `mode=normal`
`open_capture_id` NULL. Live `<OWNER_ID>` unchanged.
No `digest_email` on the test tenant.

Post-A 0c = pre-A 0c. Live owner did not move.

## PART B — B1 / B2a / B7 verified. B2b next.

Replies are not the artefact. `row_count` is.

**Bare `/ask` (not B1).** WF-01 **495787** → WF-08
**495788** 06:12:03Z. Empty question. Retrieve
corpus did not run. Guard `owner_id`
`<TEST_TENANT_ID>` `want_contact=false`.
Self-identify `{name: NIS}` only. Usage hint sent
to account 2.

**B1 PASS (predicate, not lucky decline).**
WF-01 **495790** → WF-08 **495791** 06:12:21Z.
Question: people count. Retrieve corpus `$1` =
`<TEST_TENANT_ID>` (`WHERE i.owner_id = $1::uuid`).
Compose `row_count=1` (tenant 2 has 1
interaction). Not 10. Guard `owner_id`
`<TEST_TENANT_ID>` `want_contact=false`.
Self-identify `{name: NIS}` only. lastNode
`Ask sent terminal` / `Return answer to WF-01`.

**B2a PASS (same).** WF-01 **495817** → WF-08
**495818** 06:15:15Z. Question: a live-owner
company. `$1` = `<TEST_TENANT_ID>`.
`row_count=1`. Guard `want_contact=false`.
Self-identify `{name: NIS}` only. Corpus was
capture `#217` (tenant 2), not the live owner's
meetings.

**B7 PASS.** WF-09 **495812** 06:15:00Z
(`Asia/Riyadh` 09:15). Self identify `{name: NIS}`
only. List owners = both tenants.

| branch | findings | send |
|---|---|---|
| `<TEST_TENANT_ID>` | `failed_24h=1` job `7c72371f` capture `#217` | Telegram alert `message_id` 1066 to account 2. Email skipped (D2d). Fingerprint `audit_log` `bbeb5e57`. |
| `<OWNER_ID>` | `finding_count=0` | Silent clean. Telegram alert node did not run. Nothing to the live chat. |

`Alert no destination` did not run. 06:00
**495695** was before 041 — not B7.

Post-B 0c = post-A 0c. Live owner did not move.

**Copy pass (do not fix now).** User-facing text is
still `LNI watchdog`. D-N: product name is NIS.
Every tenant sees this string.

**B2b waiting.** One `/ask` from account 2 for a
live-owner person's email (gated `want_contact`
path). A leak looks like an email address. STOP
after B2b. Architect reviews before B3
(`/digest`).
