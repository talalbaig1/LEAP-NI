# Session 08 overnight — cleanup manifest

Record artefacts **as they are created**. Delete at end of matrix.
Never touch R3 locked rows.

Apollo credits at start (28 Aug 2026 ~21:00Z): **15** spent all-time
(`credit_ledger.provider='apollo'`, `sum(credits_spent)`).
Stop if delta > 5.

`follow_ups.draft_state='sent'` at start: **2**.
`audit_log.action='followup_sent'` at start: **2**.

Locked (do not mutate): captures #9 #62 #63 #66 #68 #69 #73 #75 #82
#83 #85 #87; jobs `1564abc3` `f6a1e703`; credit_ledger `73fc2831`;
people `ec5dc966` `9489be75`; follow_ups `5df341f8` (leave
`awaiting_confirm`).

| when_utc | kind | id | scenario | deleted |
|---|---|---|---|---|
