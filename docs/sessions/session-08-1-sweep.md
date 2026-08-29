# Session 08.1 — sweep miss cause, WF-03 guard, overnight cleanup

**Date:** 29 August 2026
**Packet:** 8.1. Docs only on this branch. **No WF-01 PUT. No WF-10 PUT.**
**Do not merge** PR #54 or #55.

WF-01 stayed `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` (131, active).
Rollback still `864bcb8b-…`. Owner live regression was in progress;
no failure was reported to this run. No rollback.

---

## A. Sweep Draft insert miss — CAUSE (not fixed)

**Execs.** WF-02 Schedule sweep **274072** (success, 21:30:02–21:30:04Z,
`wait: false`) → WF-10 **274073** (error, 21:30:04–21:30:12Z).
Parent trigger: `Schedule sweep`. Last node: `Draft insert miss`
(`Draft insert returned no row`).

**Which write.** Not `Insert brief draft`. That node **succeeded**.

| node | when (Z) | result |
|---|---|---|
| Insert brief draft | 21:30:06 | row `1ea2c7b4`, `draft_state='draft'`, capture `#110` `70cdb25c` |
| Voice after parse? | 21:30:12 | true (brief id already on the item) |
| Claim await | 21:30:12 | SELECT found `1ea2c7b4` |
| **Update draft** | 21:30:12 | `{success:true}` and **no `id`** (zero-row UPDATE; `alwaysOutputData`) |
| Draft row returned? | 21:30:12 | `$json.id` empty → false |
| Draft insert miss | 21:30:12 | StopAndError |

Live `Update draft` WHERE:

```sql
WHERE id = $1::uuid
  AND owner_id = $8::uuid
  AND draft_state IN ('awaiting_voice', 'draft')
RETURNING id, to_email, cc_email, subject, body, attachment_asset_ids, person_id
```

**Why zero rows.** The overnight matrix **cancelled** `1ea2c7b4` at
**21:30:09Z** while extract was still running. Claim is a SELECT and
still saw the id. Update requires `draft_state IN ('awaiting_voice','draft')`.
`cancelled` does not match. n8n reports success with no RETURNING
columns. The shared gate is named for an insert miss; the failing
write is the **update**.

**How sweep differs from `/done`.** After Normalize, both use the same
WF-10 graph (`source='command'`). Three differences produce silence:

1. Sweep `Call WF-10` is **`wait: false`**. 274072 ended success
   (`Sweep followup dispatched`) two seconds after start, before
   extract finished.
2. WF-10 has **no Telegram send**. A StopAndError on sweep is not a
   card.
3. `/done` via WF-01 **waits** and can send a fail line or confirm
   card. Sweep cannot.

The 7.16 overnight note called this a second `Insert draft`. Live
274073 shows **Update draft**, not a second insert. Same gate, wrong
name.

**Product rule (third time).** A forgotten `/done` must leave a draft
or an explicit message. Never silence. On this tick the brief **was**
written, then cancelled by the matrix, then the update miss errored
with no owner-visible text.

**Authorised fix (not applied).** Packet D said report A+B then stop.
Suggested change, when re-authorised: if `capture_id` is set and
Update returns 0 rows, do not StopAndError into silence — keep the
existing brief or compose a durable reply. Optionally stop the sweep
path after Insert brief (draft only). **No live PUT this packet.**

---

## B. WF-03 enqueue guard — verified

Live WF-02 `BV0nukrQdOpDCPe4` versionId **`071a4794-4d2f-4c05-ac2b-9f482efde605`**
(76, active). Both **Enqueue asset jobs** and **Enqueue sweep jobs**:

```sql
INSERT INTO public.processing_jobs (owner_id, capture_id, asset_id, job_type, status)
SELECT a.owner_id, a.capture_id, a.id,
       CASE WHEN a.kind = 'audio' THEN 'transcription'
            ELSE 'card_vision' END,
       'queued'
FROM public.assets a
JOIN public.captures c ON c.id = a.capture_id
WHERE a.capture_id = ANY($1::uuid[])
  AND a.upload_status = 'stored'
  AND c.capture_mode IS DISTINCT FROM 'followup'
ON CONFLICT (asset_id, job_type) WHERE asset_id IS NOT NULL
  DO NOTHING
RETURNING id, capture_id, asset_id, job_type, status
```

**Enqueue closed standard** still has **no** `capture_mode` filter.
That node only runs on a standard close-then-open, not on a followup
sweep.

**Database after cleanup.**

```sql
SELECT count(*) FROM processing_jobs j
JOIN captures c ON c.id = j.capture_id
WHERE c.capture_mode = 'followup';
-- 0
```

Zero `followup` captures remain. Before cleanup there were **58**
`processing_jobs` on `capture_mode='followup'` (WF-03 continuing
leftover jobs from the overnight run, not a new guarded enqueue).
Those jobs were deleted with captures #88–#112.

---

## C. Overnight corpus — cleaned

**Before** (query immediately before delete):

| table / metric | n |
|---|---|
| captures | 97 |
| processing | 25 |
| max capture_no | 112 |
| people | 34 |
| processing_jobs | 296 |
| follow_ups | 46 |
| assets | 101 |
| interactions | 72 |
| jobs on followup captures | 58 |

**After** (read-back):

| table / metric | n |
|---|---|
| captures | 72 |
| processing | 17 |
| max capture_no | **87** |
| people | 29 |
| processing_jobs | 235 |
| follow_ups | 27 |
| assets | 78 |
| interactions | 55 |
| leftover #88–#112 | **0** |
| jobs on followup captures | **0** |
| captures / people / follow_ups created ≥ 21:00Z 28 Aug | **0** |
| bot_state rows | 1 |

Deleted: captures **#88–#112**, their assets, jobs, extraction_runs,
interactions, and overnight follow_ups (including sent test
`aad3457a` and leftover empty-block `5ea0a8ea`). Five phantom people
from the matrix (`efda17a2`, `af835722`, `d11a75b4`, `844b36aa`,
`13d10aae`).

**Left on purpose**

- Captures **#9 #62 #63 #66 #68 #69 #73 #75 #82 #83 #85 #86 #87**
  (all present; #86 is owner testing at 20:22Z, before 23:30 Riyadh).
- People `ec5dc966` (LNI Followup Prove), `9489be75` (Ahmed Eltohfa).
- follow_ups **`5df341f8`** — `draft_state='awaiting_confirm'`,
  `status='open'`. Not mutated.
- follow_ups **`becb0e07`** — pre-overnight, 19:21Z, already
  `cancelled`. Owner time before 23:30 Riyadh. Not deleted.
- Jobs `1564abc3`, `f6a1e703`. Ledger `73fc2831`.

**Unsure — left, not guessed**

- **audit_log** after 21:00Z: `capture_followup_open` 24,
  `capture_done` 23, `workflow_error` 7, `watchdog_alert` 2,
  `capture_new` 1, `followup_sent` 1. Packet did not list audit.
- **credit_ledger** four Apollo rows 22:00–22:15Z,
  `credits_spent=0` (`people_match` / `skipped_cached`). Two point at
  locked person `ec5dc966` and the person on `5df341f8`. Not in the
  delete list.

**Failed jobs — both stay**

| id | type | error | capture | why it stays |
|---|---|---|---|---|
| `f6a1e703` | transcription | `provider_error` | **#36** 26 Aug | R3 lock |
| `b4dbf8cf` | enrichment | `write_failed` | **#67** 27 Aug | owner data before the overnight run |

Neither is overnight corpus. Not resolved.

---

## D. Stop line

Cause for A and verification for B are above. Sweep fix is **not**
on the live graph. PRs **#54** and **#55** stay unmerged. Next
authorisation needed for any WF-10 PUT.
