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

1. Voice, person with no email (Ahmad `73996fe0` or Ahmed
   Al-Touhaf `55ab6b1a`): no-email line, `ok` true, no throw,
   await still set, row still `awaiting_voice`.
2. Voice naming Ahmed Eltohfa still drafts.
3. GET WF-01: `864bcb8b-…`, 128 nodes, unchanged.

## Report only (do not fix)

Distinct people rows for the one physical Ahmed Eltohfa
(wrong-script / phonetic splits). List `id`, `full_name`,
`created_at`, source capture.
