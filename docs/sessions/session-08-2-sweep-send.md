# Session 08.2 — WF-10 sweep send + zero-row gate

**Date:** 29 August 2026
**Packet:** 8.2. **WF-10 only.** WF-01 stayed `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240`.
**Rollback:** WF-10 `fde7f832-63f8-45bb-8f2f-624b081be8b7`.
**Live WF-10:** `84bcbfdf-4728-401b-8152-2a3ebfa2f1ef` (140 nodes, active).
**WF-02 `Call WF-10 sweep`:** still `waitForSubWorkflow: false`.

TEST driver `iqAx0KwCsTbb32BY` was activated for proofs, then **deactivated**.

---

## Architect exception (workflows.md)

WF-01 is no longer the only Telegram sender. WF-10 sends when the
call is a forgotten `/done` sweep. WF-02 cannot send, and Call WF-10
sweep is `wait:false`, so WF-01 is not in the loop. A silent success
on a forgotten `/done` is worse than an error.
`command` / `callback` / `voice` still return to WF-01 only.

Live WF-02 Expand still passes `source:'done'`. Sweep notify also
fires when `source='done'` **and** `close_reason='auto'`. `/done`
uses `close_reason='explicit'` and does not send from WF-10.

---

## PUT

Two REST PUTs on WF-10 (second was forced by Telegram 400 on `_` in
an attachment filename). Rollback remains `fde7f832`.

1. `1f975891-…` — sweep send cluster, miss path, keep raw `source`,
   `route` for Switch, Reload-by-insert-brief-id.
2. `84bcbfdf-…` — `additionalFields.parse_mode='HTML'` on all
   `Send sweep *` nodes. Picker `message_id` 449 proved send without
   it; confirm card with `_` in the filename 400'd until this.

Credential on every send node (re-GET): `telegramApi.id =
hHCehaaqdJIzsuUu` (Leap-NI). Keyboard: fixed collection rows, scalar
`text` / `callback_data` from `Map sweep markup` `t*`/`d*` (rules.md 20).

### F1 source gate (re-GET verbatim)

`Sweep source?`:

```json
{
  "id": "swsrc1",
  "leftValue": "={{ $('Normalize input').first().json.source }}",
  "operator": { "type": "string", "operation": "equals", "singleValue": true },
  "rightValue": "sweep"
}
```

True → `Load sweep chat` → send. False → `Sweep auto-done?`
(`source='done'` AND `close_reason='auto'`). That false →
`Return to caller`. `command` / `callback` / `voice` cannot satisfy
either IF. Proved: exec **276398** (`source='done'`, explicit close)
`Load sweep chat` did not run; exec **276475** (`source='callback'`)
send nodes empty.

### F2

`Draft insert miss` StopAndError removed. Zero-row Update →
`Load miss state` → `Compose miss`:
- `cancelled`: tell the owner, do not resurrect.
- other: keep the brief, tell the owner.
`ok` true, non-empty `reply_text`, sweep send.

---

## Proofs (TEST driver, no phone)

| # | Result | Evidence |
|---|---|---|
| 1 forgotten `/done` | PASS | WF-02 **276375** (Schedule sweep) → WF-10 **276376**. `source=done`, `close_reason=auto`. Telegram **message_id 449**, five `f7:p:` buttons. Transcript had Leap / 10 September / 9 a.m. Confirm card (unique email) **276473**, **message_id 457**, Send / Send without attachments / Cancel, attachment filename + 10 September in the body. |
| 2 tap | PASS as callback | **276475** `f7:x:b19a5aff-…` → `Compose cancelled` `Cancelled.` Sweep send nodes **empty**. WF-01 still `1d53c03d`. Driver `f7:p:` without `capture_id` (the WF-01 payload shape) errors at `Load candidate assets 20` `invalid input syntax for type uuid: ""` — pre-existing, not this PUT. |
| 3 cancelled row | PASS | **276485**. Compose miss. Telegram **458**: `Block closed automatically. The draft had been cancelled. Nothing was sent.` Update returned no id. Row stayed `cancelled`. No throw. |
| 4 `/done` one send | PASS | **276398** `source=done` explicit. Sweep send nodes empty. `Load sweep chat` did not run. New node cannot double-send; WF-01 still the inbound sender. |
| 5 GET WF-10 gate | above | |
| 6 GET WF-01 | `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` | |

---

## Invariant A re-baseline

`audit_log.action='followup_sent'` **=** `follow_ups.draft_state='sent'`
**+ 1**.

Read-back now: `fu_sent=2`, `audit_sent=3`.

Reason: packet 8.1 deleted overnight sent test `aad3457a` and left
its `audit_log` row (audit was not in the delete list). Do not treat
`audit = sent` as the live invariant until that extra row is decided.

---

## Cleanup

Packet artefacts: captures **#113–#117**, 11 assets, 11 follow_ups.
bot_state open/await cleared.

| metric | before 8.2 | after cleanup |
|---|---|---|
| captures | 72 | 72 |
| processing | 17 | 17 |
| max capture_no | 87 | 87 |
| people | 29 | 29 |
| jobs | 236 | 236 |
| follow_ups | 27 | 27 |
| assets | 78 | 78 |
| interactions | 55 | 55 |
| leftover ≥ #113 | — | 0 |

Left: overnight `audit_log` (invariant A +1). Locked R3 rows untouched.
`5df341f8` untouched.
