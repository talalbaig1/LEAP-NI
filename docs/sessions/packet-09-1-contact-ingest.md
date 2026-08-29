# Packet 9.1 — contact / vCard ingest (WF-02, WF-05, 029)

**Date:** 29 August 2026
**Status:** APPLY in progress. WF-01 not touched.
**Branch:** `cursor/phase-09-1-contact-ce36`

Architect decisions (binding):

- Skip WF-04. A vCard is already structured; vision-on-text is the 3.13 failure.
- Store raw `msg.contact` JSON and verbatim vCard text.
- Receipt: `Contact saved · #N` / `Contact file saved · #N`.
- Inside a followup block, a contact behaves like a photo.
- Migration 029. Embeddings moves to 030.
- WF-02 enqueue must not `card_vision` a `.vcf`. Prove by live SQL + zero-row check.
- No WF-01 PUT until the owner reports the phone test passed.
- Do not touch follow_ups `5df341f8`.

## STEP 1 — repo hygiene (stopped)

PRs #54–#60 were **not** unmarked-draft and **not** squash-merged.

Dry-run from `origin/main` `e9b7d6b`: #54 squash-OK; #55 is add/add on
`docs/plans/phase-07-15-followup-as-capture.md` (#55 is a superset of
#54). Packet said: if any two conflict, STOP rather than resolve blind.

`main` SHA remains `e9b7d6bbd7747ab83db5f27ea443170a06980a9a`.
Open PRs still include #48–#60.

## STEP 2 — environment.local.md

Gitignored. Updated 29 Aug 2026 GET:

- WF-01 live `1d53c03d` (131). Rollback `864bcb8b`.
- WF-02 live (pre-PUT) `071a4794`. Rollback that same id.
- WF-05 live (pre-PUT) `181a4c32`. Rollback that same id.
- WF-10 live `ab21c10c`. Rollback `2b6580b8`.
- Every other rollback already in that file kept.

## STEP 3 — apply (this packet)

See proof table below after live PUT.

## STEP 4 — blocked

WF-01 PUT + full regression wait on the owner phone test.

## Proofs

_Filled after PUT._
