# Session 09 — freeze triage (30 Aug 2026)

Implementer window. First message was the session-09 handover,
not a "capture is broken" packet. No PUT. No SQL write. No
migration.

Read-back: n8n GET by known id (name-checked), live SQL on
LEAP-NI. MCP `search_executions` with `workflowId` = WF-01
returns empty even for dates that have known execs (279617).
That is a tool gap, not a capture fact.

## Verdict

**Capture is not broken.** Last store is #136
`2026-08-29 08:19:06Z`. Counts match 9.11. No open capture.
WF-02 sweep and WF-09 watchdog are ticking success after the
unexpected PUTs. If not sure, it is not broken. Stop.

## Unexpected versionIds — STOP, do not revert

Handover table was GET 29 Aug after 9.10. Live GET 30 Aug
06:08Z:

| WF | expected | live | nodes | updatedAt (UTC) |
|---|---|---|---|---|
| 01 | `4836ffd8` | **`e454df40-cc92-4a06-ba52-31fc0d1594c8`** | 137 | `2026-08-30T05:20:14Z` |
| 06 | `356a2d1f` | **`76840a2a-3d4f-454e-86ff-0f70bca48ca1`** | 53 | `2026-08-30T05:21:01Z` |

Someone PUT without a packet on this handover. Do not "fix"
it. Do not PUT WF-01. Architect owns the next packet.

Still match: 00 `5ec180fd`, 00b `46330598`, 02 `847cc3c7`,
03 `852f300b`, 04 `28510930`, 05 `68f47505`, 07 `fb9ee1c4`,
08 `b699e7d6`, 09 `fdd6fe67`, 10 `97fd7181`. Settings on
01–10: `availableInMCP` true, `errorWorkflow` = WF-00,
timeout 300, `Asia/Riyadh`, `callerPolicy`
`workflowsFromSameOwner`. WF-01 name unchanged. Followup
senders still `parse_mode: HTML`. WF-10 Whisper `language`
absent.

## SQL (read-only)

Same as 9.11: captures 80, max `#136`, people 30, assets 91,
follow_ups 30, open 0, queued 0, awaiting **2** (`5df341f8`,
`6f3c13b3`), sent 3, audit `followup_sent` 4. `f210d77d`
cancelled. `bb3689d8` sent. Last activity 29 Aug 08:18Z.
Migrations through `people_source_type_contact`. No 030.

No `workflow_error` after 29 Aug 06:58Z (278965, already
the 9.6 HTML fix).

## Crons (observed `startedAt`)

WF-02 sweep `*/5` success through **290419** `06:05:02Z`.
WF-09 `*/15` success through **290379** `06:00:00Z`.
WF-06 `*/15` success through **290380** `06:00:00Z`
(after the unexpected PUT).

LNI-TEST-7.16-driver still archived.

## This VM

`docs/environment.local.md` and `/tmp/lni716/n8n_util.py`
are not on this checkout. 9.14 (PR #69, draft) has the
implementer craft file. Not merged. Not applied here.

## What was not done

No workflow PUT. No revert of `e454df40` / `76840a2a`.
No TEST un-archive. No phone prove (none asked; freeze).
Waiting for a packet that says capture is broken, or for
the architect to name the 05:20 PUTs.
