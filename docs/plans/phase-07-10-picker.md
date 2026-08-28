# Packet 7.10 — picker email-first ordering

**Date:** 28 August 2026
**Status:** APPLIED. WF-10 `5b3d2913-…` (109 nodes). Rollback
`8722d214-…`. **WF-01 / WF-06 / WF-09 are not touched.**

## Reason

27 people, 7 with no email, 3 of those spawned by voice notes about
people already in the database. One physical Ahmed Eltohfa now has
four rows. A row with no email cannot receive a follow-up, so it
must never outrank one that can. Ahmed Al-Touhaf (0.368, no email)
sat above AHMED BASAWTEN and near the real Eltohfa row.

## Change

**Lookup people voice** `ORDER BY` becomes

```
(email_normalized IS NOT NULL) DESC, score DESC
```

`LIMIT 5` unchanged. Floor **0.25** unchanged. `GREATEST` scoring
unchanged. F3 unchanged (never auto-pick a fuzzy match). Typed
**Lookup people** (floor 0.4) is not this node.

## Prove (TEST caller only)

1. Ahmed voice picker: `9489be75` (has email) first; phantoms below.
2. A no-email person is still selectable; tap returns the 7.9
   no-email line.
3. GET WF-01: `864bcb8b-…`, 128 nodes, unchanged.

## OPEN post-event — TOP PRIORITY — do not fix now

WF-05 creates a new person from any voice-note extraction carrying a
`full_name` with no exact email match. Every voice note naming an
existing contact spawns a duplicate. Evidence: `9489be75` (card, #75),
`55ab6b1a` (voice, #82), `e84189e6` (voice, #83), possibly `73996fe0`
(voice, #73). No `entity_candidates` suggestion because the names
differ and none carry a company. Pairs with the Whisper wrong-script
item and the `verbose_json` item (`rules.md` rule 23).
