# Packet 7.9 — Compose no email return

**Date:** 28 August 2026
**Status:** APPLIED. WF-10 `8722d214-…` (109 nodes). Rollback
`45f1fdd4-…`. **WF-01 / WF-06 / WF-09 are not touched.**

## Cause (accepted)

Exec **272708**: unique voice match, no email. **Compose no email**
read `$('Lookup people').first()` (unexecuted). Voice resolves via
**Load voice person** / **Load picked person** / **Lookup people
voice**. Ternary last branch threw. `ok` never returned.

## Change

**Load no-email person** (Postgres) sits immediately before
**Compose no email**. Prefer the durable row
(`follow_ups.person_id` on `bot_state.awaiting_followup_id`), else
the incoming match id (`$json.id` from Has email? / Voice person
has email?). Named-node read after that I/O.

**Compose no email** is a RETURN, not an error:

- `ok: true`
- `reply_text`: `<full name> has no email address. Send /followup with an email to draft one.`
- `reply_markup`: null

Do **not** Claim await. Do **not** cancel the row. `draft_state`
stays `awaiting_voice`. `bot_state` stays armed so the owner can
speak again with an email.

## Prove (TEST caller, not the phone)

1. Ahmed Al-Touhaf `55ab6b1a` on awaiting_voice `83201e2b`. Exec
   **272806** success. Reply: `Ahmed Al-Touhaf has no email address.
   Send /followup with an email to draft one.` `ok` true. Row stayed
   `awaiting_voice`. `bot_state` still `83201e2b`. No throw.
2. Ahmed Eltohfa `9489be75` on `f42de454`. Exec **272812**. Confirm
   card to `ahmed.eltohfa@veeam.com`. Date in body.
3. GET WF-01 `864bcb8b-…`, 128 nodes, unchanged. WF-06/09 versionIds
   unchanged. TEST deactivated after.

Prove rows cancelled after. Owner `bot_state` restored to
`becb0e07`.

## Report only (do not fix)

Three people rows for the one physical Ahmed Eltohfa (Veeam):

| id | full_name | created_at | source | capture |
|---|---|---|---|---|
| `9489be75-312f-47ac-b6d0-96d14fa6bd17` | Ahmed Eltohfa | 28 Aug 15:57Z | card | **#75** `bc2c3318-…` |
| `55ab6b1a-6ade-4da6-b360-30f3d902fad3` | Ahmed Al-Touhaf | 28 Aug 18:25Z | voice_note | **#82** `79803bd6-…` |
| `e84189e6-f565-4e0b-9a25-9a5f214e3b69` | Ahmed Tufa | 28 Aug 19:00Z | voice_note | **#83** `bb5d133f-…` |

Card has the email. Each later voice transcript spawned a new
no-email row. **Ahmad** `73996fe0-…` (voice, **#73**, first name
only) is a fourth possible split; less certain it is the same
person. Not merged in this packet.
