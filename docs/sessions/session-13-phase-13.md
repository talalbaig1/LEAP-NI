# Session 13 — Phase 13 (packet 13.3-R)

**Window:** 17 Sep 2026.
**Home:** `docs/plans/phase-13-plan.md`. PR **#98**.
**Rule 6 phone-prove SUSPENDED** this packet. Phone batch
T1–T4 / P1–P3 deferred.

PR **#97** closed (superseded). Remote branch gone.
Rule-25 scan of that diff was clean.

Do not requeue `7c72371f`. Do not write fixtures into
the live owner. Do not repair #46 / #208.

## F13 fixture register (permanent, §12)

All rows are on the NIS test tenant (`events.name =
'NIS test tenant'`). 8-char prefixes are evidence keys.

| Name | Row | Kind |
|---|---|---|
| F13-STUCK | job `57ef70fe` | enrichment, parked `needs_review` / `watchdog_stuck_enrichment`. Capture **#235** `08a53f48`. Person `bd5a7350` |
| F13-STUCK-NONENRICH | job `81d54521` | extraction, requeued then parked `needs_review` / `f13_requeue_proved` so a later watchdog tick does not kick WF-04 |
| F13 No Email | person `bd5a7350` | `full_name` F13 No Email, email NULL, `source_type=card` |
| F13 No Email Two | person `15e4a633` | email NULL. Second claimed job in the no-email drain |
| F13-NOEMAIL-A | job `9c6dc3a1` | enrichment → `needs_review` / `no_email` (person `bd5a7350`) |
| F13-NOEMAIL-B | job `99b6d526` | enrichment → `needs_review` / `no_email` (person `15e4a633`) |
| F13 Credits Unreachable | person `18f7a0af` | email present (`example.invalid` probe). No Apollo row |
| F13-CREDITS | job `33add9a9` | clone proof: released `credit_read_failed`, then parked `needs_review` so live WF-06 cannot spend |

Clone `LNI-TEST-13.1-credits` was archived after proof (a).

`7c72371f` remains `failed` / `packet_126_c3` /
`last_transition_at` 16 Sep 11:07Z. Not in `failed_24h`.
Not requeued.
