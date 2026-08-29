# Packet 9.1 — contact / vCard ingest (WF-02, WF-05, 029)

**Date:** 29 August 2026
**Status:** STEP 3 proven. WF-01 not touched.
**Branch:** `cursor/phase-09-1-contact-ce36` · PR **#61**

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
Open PRs still include #48–#60 plus this #61.

## STEP 2 — environment.local.md

Gitignored. Updated 29 Aug 2026 GET, then again after the 9.1 PUTs:

- WF-01 live `1d53c03d` (131). Rollback `864bcb8b`. **Not PUT.**
- WF-02 live `e491a9f0` (89). Rollback `071a4794`.
- WF-05 live `74b08d0f`. Rollback `181a4c32`.
- WF-10 live `ab21c10c`. Rollback `2b6580b8`. **Not PUT.**
- Every other rollback already in that file kept.

## STEP 3 — apply

| Object | After | Rollback |
|---|---|---|
| Migration `people_source_type_contact` (029) | applied `20260829054006`. `shared_contact`+`vcard` on people. `vcard` on assets.kind. Embeddings absent. | drop the two new check values |
| WF-02 `BV0nukrQdOpDCPe4` | `e491a9f0` 89 nodes ACTIVE. action `ingest_contact`. Parse in WF-02. Enqueue guards on `/done`, sweep, and close-standard. | `071a4794` |
| WF-05 `Iv0loGijYVH77OGh` | `74b08d0f` sourceMap includes `shared_contact`/`vcard` | `181a4c32` |
| WF-01 | `1d53c03d` 131. Unchanged. | — |
| WF-10 | `ab21c10c` 142. Unchanged. | — |
| TEST `iqAx0KwCsTbb32BY` | sql ops added. **Inactive** after prove. | — |

Settings on WF-02/05: `availableInMCP: true`, timezone `Asia/Riyadh`,
`errorWorkflow` = WF-00, timeout 300. No `$env`. Leap-NI Postgres
`zzFzIzjYqRw0dvoE`. `Call WF-05 contact` is `wait:false`,
`onError: continueRegularOutput`.

## Proofs

**Enqueue guard (live SQL + zero-row).** GET `Enqueue asset jobs` contains
`kind IS DISTINCT FROM 'vcard'`, mime `text/vcard`/`text/x-vcard`, and
`storage_path` ending `.vcf`, plus the existing followup clause. Planted
on #121: asset `kind=vcard` mime `text/vcard` path `…/a.vcf`, and
`kind=document` mime `text/vcard` path `…/b.vcf`, both `stored`. SELECT
matching the live enqueue predicate: **0 rows**. Same INSERT … RETURNING:
**0 rows**. `card_vision` count on that capture: **0**.

**Shared contact.** TEST → WF-02 `ingest_contact`. #122.
`Contact saved · #122 · LNI Contact Prove Nine`.
`extraction_runs.raw_vision_output` = raw contact JSON. `raw_transcript`
null. Person `c0f14acb` `source_type=shared_contact`. No `card_vision`.

**`.vcf` text.** #123. `Contact file saved · #123 · LNI Vcard Prove Nine`.
`raw_transcript` verbatim BEGIN:VCARD…END:VCARD. Person `5c322ece`
`source_type=vcard`.

**Auto-link.** #124 vCard EMAIL = drain prove 1. Linked
`e9292eeb`. Still one person with that email. No second row.
Queued enrichment on that capture deleted.

**Followup block.** `/followup` #125. Contact reused same
`capture_id`, `in_followup=true`, `should_resolve=false`. Extract written.
**0** `entity_resolution` jobs. **0** `card_vision`. Capture stayed
`open` / `followup`. `/done` → `Follow-up #125 closed` (`kick_wf10=true`).

**Cleanup.** Prove captures #121–#125, two prove people, prove companies,
planted assets, jobs, interactions, four name_trgm candidates deleted.
Drain-1 phone reverted. `5df341f8` untouched. Counts after:
captures 73 / people 25 / assets 81 / jobs 242 / follow_ups 28 /
interactions 56 / max_no 120 / open 0.

## Known hole (not this PUT)

WF-09 `Enqueue orphan jobs` is still audio→transcription else
`card_vision` with no vcard/mime/`.vcf` guard. Do not leave a stored
vcard asset on a **closed** capture until that node is guarded. 9.1
ingest_contact does not insert an asset row (replay is the extraction
run). WF-09 was not authorized this packet.

## STEP 4 — blocked

WF-01 PUT + `/ask` `/digest` `/flag` `/new+photo+/done` `/batch`
`/whatever` `/followup` + live contact + `.vcf` waits on the owner
phone test. If that test fails, stop and fix the redesign. If it
passes, one WF-01 PUT last. Any read-back failure rolls back WF-01
to `1d53c03d` immediately.
