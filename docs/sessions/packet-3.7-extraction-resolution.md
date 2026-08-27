# Packet 3.7 — extraction and resolution

**Date:** 27 August 2026
**Branch:** `cursor/packet-3.7-extraction-resolution-1424`
**PR:** #19

WF-07 and WF-09 left **active**. Capture #9, jobs `1564abc3` and
`f6a1e703` untouched. Captures 62 and 63 not retro-fixed. WF-08 not
created. n8n not restarted.

---

## Step 0 merge

`main` was `b65d22b` (Packet 3.3). Squash-merged in dependency order:

| Order | PR | squash on main |
|---|---|---|
| 1 | #15 briefing stuck | `b127d4b` |
| 2 | #16 send-path diagnosis | `e38638a` |
| 3 | #17 send-path + `.first()` | `c53abaa` |
| 4 | #18 WF-09 | `2994d86` |

#18 whole-branch squash vs main-with-#15+#17 conflicted in
`docs/workflows.md`. Did **not** guess. Cherry-picked unique #18
commits, then soft-squashed to `2994d86`.

**main HEAD after merge:** `2994d86a474c634d0bead7b5a3caf5405ba95e02`

Present on that HEAD: WF-07 send-path standard, briefing stuck line,
MCP create trap, paired-item `.first()` trap, full WF-09 design.

Remote and local branches deleted:
`cursor/packet-3.4-briefing-stuck-1424`,
`cursor/packet-3.5-send-path-1424`,
`cursor/packet-3.8-wf09-1424`,
`phase-3/wf07-sendpath`.

---

## Step 1 docs

Commit `f464270d83434ca7beece64b36ae2167d07cb4c5` — D1–D4 in
`docs/workflows.md`, `docs/architecture.md`, `docs/phases.md`. Before
any n8n change.

---

## Step 2 / 3 live PUT (GET name-check, no `active`, strip `binaryMode`)

| WF | id | versionId = activeVersionId | creds |
|---|---|---|---|
| WF-04 | `cxyvgBJC1DD8LEbU` | `7ea4404b-4ea4-4132-b7e4-91b85c7f1b87` | Leap-NI postgres `zzFzIzjYqRw0dvoE`, OpenAI `ouWVjrmc8Ia4SRD2` |
| WF-05 | `Iv0loGijYVH77OGh` | `b4be6046-6c49-42d6-94d1-9832dfa3275d` | Leap-NI postgres `zzFzIzjYqRw0dvoE` |

Settings both: `availableInMCP`, `errorWorkflow` WF-00, timeout 300,
`Asia/Riyadh`, `callerPolicy: workflowsFromSameOwner`. No `binaryMode`.

`prompt_version` `'wf04-v3'` in both Insert extraction_runs
queryReplacements.

WF-07 `509570b1-11a8-4844-85cb-5fd5b0c64164` and WF-09
`5e7affbe-1a02-42f2-9f0b-889b4fbd9ca0` still active, versions unchanged.

---

## P4 baseline (before capture 64; 62/63 not rewritten)

Captures 62 and 63 remain `needs_review`, `wf04-v2`. Companies (5):
Qatar Airways, BTGroup, Huawei (orphan), Arabic Huawei legal, English
Huawei legal with domain `huawei.com`. Person `وانغ (بوب)` /
`نائب المدير` / `zhangwenwu3@huawei.com` linked to all three Huawei
rows. Do not reconcile (packet 3.9).

---

## Packet 3.8 leftover answers

**Execution 254927 Telegram error (verbatim):**
`Bad Request: can't parse entities: Can't find end of the entity starting at byte offset 121`

Cause: default Markdown treated `_` in `failed_24h` as an unclosed
italic. Gmail still delivered. Then PUT `parse_mode: HTML`.

**Write fingerprint having no `onError` — deliberate?** Yes. Spec: do
not write the fingerprint if both channels fail, so the next tick
retries. `Write fingerprint` sits only on Any delivered? **true**. If
the INSERT throws, no fingerprint row, next tick retries.
`onError: continueRegularOutput` here would mark the tick “sent”
without a durable fingerprint and could re-storm.
