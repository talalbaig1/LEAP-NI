# Packet 9.3 — WF-09 reconciler guards

**Date:** 29 August 2026
**Status:** APPLY. WF-01 not touched. Phase 9 contact ingest still paused.
**Branch:** `cursor/phase-09-3-reconciler-ce36`

Architect error (recorded): GATE-FIX specified the orphan reconciler
before `capture_mode='followup'` and the vCard rules existed. WF-02
gained those guards; WF-09 did not. Cause accepted from 9.2 items 3–4.

## Apply

One WF-09 PUT. Rollback `78c1e260`.

`Enqueue orphan jobs` keeps the reconciler predicate (`stored`,
capture not `open`, owner-scoped, `NOT EXISTS` a job on that asset).
The four exclusion lines are copied verbatim from live WF-02
`Enqueue asset jobs` (`e491a9f0`):

```
AND c.capture_mode IS DISTINCT FROM 'followup'
AND a.kind IS DISTINCT FROM 'vcard'
AND lower(coalesce(a.mime_type, '')) NOT IN ('text/vcard', 'text/x-vcard')
AND right(lower(coalesce(a.storage_path, '')), 4) IS DISTINCT FROM '.vcf'
```

Scan findings / Mark ceiling failed / Requeue stuck running / node
list (43) unchanged.

## Live SQL after PUT (read-back)

```
INSERT INTO public.processing_jobs (owner_id, capture_id, asset_id, job_type, status)
SELECT a.owner_id, a.capture_id, a.id,
       CASE WHEN a.kind = 'audio' THEN 'transcription'
            ELSE 'card_vision' END,
       'queued'
FROM public.assets a
JOIN public.captures c ON c.id = a.capture_id
WHERE a.upload_status = 'stored'
  AND c.status IS DISTINCT FROM 'open'
  AND a.owner_id = $1::uuid
  AND c.capture_mode IS DISTINCT FROM 'followup'
  AND a.kind IS DISTINCT FROM 'vcard'
  AND lower(coalesce(a.mime_type, '')) NOT IN ('text/vcard', 'text/x-vcard')
  AND right(lower(coalesce(a.storage_path, '')), 4) IS DISTINCT FROM '.vcf'
  AND NOT EXISTS (
    SELECT 1 FROM public.processing_jobs j
    WHERE j.asset_id = a.id
  )
ON CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL
  DO NOTHING
RETURNING id, capture_id, asset_id, job_type, status
```

Live version: `f3885d5a-4eb9-41d0-96ae-91115c69fcaf`. Active. 43 nodes.

## Proof

| # | Expect | Result |
|---|---|---|
| 1 | Live SQL pasted above | `f3885d5a` read-back |
| 2 | Followup + photo + audio, closed, no jobs → tick enqueues 0 | *pending* |
| 3 | Stored `.vcf` on closed standard → tick enqueues 0 `card_vision` | *pending* |
| 4 | Genuine standard orphan still enqueued (#77 class) | *pending* |
| 5 | Stuck / poison / alert SQL unchanged | Scan / ceiling / requeue byte-identical |
| 6 | Zero *new* jobs on followup / vcard | *pending* — #120 historical jobs stay |

## #120 (report only)

Capture #120 still has 6 succeeded jobs and Apollo credit
`001dd474` (1, `people_match`, confirmed, `d8b051cb`). Do not reverse
in this packet. Owner's call — see the turn report.