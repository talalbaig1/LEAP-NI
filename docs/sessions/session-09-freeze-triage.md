# Session 09 — freeze triage (30 Aug 2026)

Implementer window. First message was the session-09 handover,
not a "capture is broken" packet. No PUT. No SQL write. No
migration. Architect accepted the stop (PR #70 read-back).
PR #69 merged. Stand down except the owner's phone prove.

## Verdict

**Capture is not broken.** Last store is #136
`2026-08-29 08:19:06Z`. Counts match 9.11. No open capture.
WF-02 sweep and WF-09 watchdog ticking success.

## Draft vs published — 05:20 was not a PUT

Owner opened the WF-01 and WF-06 canvases to move nodes.
n8n autosaved a draft. Zero connections changed. No node
added or removed. GET top-level `versionId` is that draft.
Published id is `activeVersionId`.

| WF | draft `versionId` | published `activeVersionId` | updatedAt |
|---|---|---|---|
| 01 | `e454df40-cc92-4a06-ba52-31fc0d1594c8` | `4836ffd8-10e3-4d8c-963d-42bf0ccb9372` | 05:20:14Z |
| 06 | `76840a2a-3d4f-454e-86ff-0f70bca48ca1` | `356a2d1f-daf1-4560-a68f-4df82ff64ceb` | 05:21:01Z |

**Never publish either draft.** Autosave also stripped
explicit params that equal node defaults (`download:true`
on getFile vcard, `batchSize:1` on WF-06, …). None has
run on a device. If either draft id changes, STOP.

An unexpected top-level `versionId` on this build does
not imply an API write.

## GET / PUT

`sanitize_for_put` takes `nodes` / `connections` from
`activeVersion` when the workflow is active. Top-level
on an active workflow raises. Helper:
`/tmp/lni716/n8n_util.py`. Recipe also in
`cursor-handover-to-session-09.md` §1.

## Tool gap — WF-01 execution search

MCP `search_executions(workflowId=WF-01)` returns empty
despite known execs (279617). Architect confirmed and
withdrew a "no WF-01 execs today" read from that tool.
WF-01 liveness cannot be proven from execution search.
Phone only.

## SQL (read-only)

Same as 9.11: captures 80, max `#136`, people 30, assets 91,
follow_ups 30, open 0, queued 0, awaiting **2** (`5df341f8`,
`6f3c13b3`), sent 3, audit `followup_sent` 4.

## Standing

No workflow PUT. Do not revert drafts. Do not PUT to make
`versionId` match `activeVersionId`. Owner phone prove
(`/new` + photo + `/done`) is the next signal.
