# rules.md

**LEAP Networking Intelligence (LNI)** · Operating Rules
Version 2.0 · 26 August 2026

These rules govern how the project is run. They override convenience, speed, and
enthusiasm. Where a rule and a deadline conflict, the rule wins — that is the
entire point of writing them down before the pressure arrives.

---

## 1. Documentation precedes implementation

**No code, migration, or workflow is written before the relevant document
reflects the change.**

The order is always:

1. Update the document.
2. Then implement the project, the phase, or the change.

| Change | Document to update first |
|---|---|
| New or changed table, column, index, policy | `architecture.md` |
| New or changed workflow, node behaviour, trigger | `workflows.md` |
| New or changed command, UX behaviour, acceptance criterion | `prd.md` |
| Scope moving between phases, gate change | `phases.md` |
| A locked decision reopened, new verified fact | `masterplan.md` |
| A change to how the project is run | `rules.md` |

**This applies to fixes and to "small" changes.** A schema tweak made during
troubleshooting and never documented is exactly how a document set rots into
fiction, and a fictional document set is worse than none — it produces confident
wrong decisions.

If implementation reveals the document was wrong, **stop, correct the document,
then continue.** Do not carry the divergence forward with an intention to
reconcile later.

---

## 2. One phase, one chat

**Each phase is built in its own new chat window**, to preserve context.

**Every chat ends with two artifacts:**

1. **A handover prompt** for the next chat — self-contained, assuming no memory
   of this conversation.
2. **A complete `session-NN-<name>.md`** logging:
   - everything **discovered** (including corrections to earlier assumptions)
   - everything **achieved**
   - everything **completed**
   - everything **remaining**, with owner actions called out separately

Both are added to the project.

The session log records *why*, not just *what*. A decision without its reasoning
gets reopened by whoever inherits it.

---

## 3. Roles

| Activity | Claude — architect / verifier | Cursor — implementer |
|---|---|---|
| Design, contracts, acceptance criteria | Defines | Clarifies conflicts before building |
| Code, migrations, n8n workflows | Reviews via independent read-back | Writes all of it |
| Troubleshooting | Asks for the cause first, then instructs | Diagnoses and explains before fixing |
| Verification | Reads live schema and workflows directly | Supplies evidence |
| Release | Recommends go / no-go | Executes approved steps |

### Claude does not implement

Claude has **write** access to the n8n instance via MCP and could build the
workflows directly, faster than instructing Cursor.

**It does not, deliberately.** If Claude authors a workflow and then verifies
it, the verification is theatre — the failures most likely to be missed are
precisely the ones Claude built in. Author and verifier must be different
parties or the check is decorative.

### Exception — tooling-shaped walls only

Claude may implement **only** when the blocker is tooling-shaped: an operation
Cursor's tools cannot perform at all, not one it is finding difficult.
Difficulty is not a wall. A wall is "the tool cannot do this."

All of the following are required:

1. The cause is understood and agreed first (§5). This is never a shortcut
   past diagnosis.
2. The handoff and its reason are recorded in the session log.
3. Cursor reviews Claude's work by independent read-back, **roles reversed**.
   The check is preserved, not dropped.
4. The next task reverts to normal: Claude architects and verifies, Cursor
   implements.

---

## 4. Verification is by read-back, never by report

Cursor's summary is an **input**, not evidence.

The architect independently:
- reads the **live** Supabase schema and compares it to `architecture.md`
- reads the **live** n8n workflow JSON and compares it to `workflows.md`
- confirms RLS via `pg_tables` / `pg_policies`, **not** by reading a migration
  file
- confirms schedules by **observed execution timestamps**, not by reading a cron
  expression

A migration file that says `ENABLE ROW LEVEL SECURITY` is not proof that RLS is
enabled. A cron expression that says `0 7 * * *` is not proof the briefing fires
at 7 AM in Riyadh.

Every task closes as **accepted**, **changes requested**, or **blocked**, with
concrete reasons and the specific object named. Only accepted work becomes the
base for the next task.

---

## 5. Troubleshooting protocol

**When something breaks, do not issue a fix.**

1. Ask Cursor to explain **the cause**.
2. Understand and agree the cause.
3. **Then** instruct a remediation.

A fix applied without understanding the cause either masks the real defect or
creates a second one. This rule costs one round trip and is not waived under
time pressure — especially not under time pressure, when the temptation to
paper over a symptom is strongest.

---

## 6. Cursor task packet template

Every implementation request must contain:

```text
Objective:      [one deliverable]
Context:        [document and section]
Scope:          [files / workflows allowed]
Non-goals:      [what must not change]
Requirements:   [specific behaviour and contracts]
Acceptance:     [commands and manual checks]
Evidence:       changed files, migration IDs, workflow IDs, test results,
                known limitations, rollback notes
Do not deploy to production or change secrets without explicit authorisation.
```

One task packet at a time. One vertical slice or bounded feature.

---

## 7. Technical standing rules

| # | Rule | Reason |
|---|---|---|
| 1 | **Never set `language` on a transcription node** | Forcing English on Arabic or code-switched audio yields confident garbage, not an error |
| 2 | **All cron schedules explicitly `Asia/Riyadh`** | A UTC container fires the 7 AM briefing at 10 AM — after the owner has left |
| 3 | **Store the raw asset before any processing** | Replayability is the entire architectural bet |
| 4 | **Idempotency on `telegram_file_unique_id`** | Telegram redelivery is normal, not exceptional |
| 5 | **No auto-merge on name similarity** | Shared family names would quietly corrupt the dataset |
| 6 | **User corrections are never overwritten by a re-run** | They are irreplaceable human input |
| 7 | **Never make the storage bucket public** | Short-lived signed URLs only |
| 8 | **Never log** tokens, keys, signed URLs, transcripts, emails, phone numbers | Request IDs and redacted errors only |
| 9 | **`errorWorkflow` set on every LNI workflow** | No silent failures |
| 10 | **Parameterised SQL only** | Never string-concatenate |
| 11 | **Explicit gate before any send node** | Postgres emits `{success:true}` on a zero-row UPDATE, which crashes sends |
| 12 | **Never touch the ElderWise project** (`<ELDERWISE_PROJECT_REF>`) | Live system, real users |
| 13 | **No facial recognition, ever** | A selfie is context, not identity |
| 14 | **Provider choices settled by benchmark, not reputation** | Including Claude's own recommendations |
| 15 | **Bind LNI credentials explicitly; verify by read-back before first execution** | n8n MCP auto-assignment reached for an ElderWise credential, and the creation response disagreed with the saved workflow |
| 16 | **First execution of any workflow must be self-identifying** | A bare `200` or `success` proves nothing about *which* system answered |
| 17 | **Postgres via the shared Supavisor pooler, SSL `Require`** | Direct and dedicated endpoints are IPv6-only; the n8n container has no IPv6 route |
| 18 | **Project documents override any installed skill** | A general n8n skill will recommend `$env` and `$getWorkflowStaticData`. Both are FORBIDDEN here: `$env` is blocked instance-wide, and configuration or state outside Postgres violates architecture.md §2 rule 2. Where a skill and this repo disagree, the repo wins, and you say so rather than silently following the skill. |
| 19 | **n8n activation: PUT `active=true` is 400 read-only on this build. Activation is `POST /api/v1/workflows/{id}/activate`.** Do not send `active` in a PUT to an already-active workflow. Strip `settings.binaryMode` from any PUT (public PUT of `binaryMode` is 400). GET name, then act. | Packet 4.8: WF-06 inactive, PUT with `"active": true` returned 400 `request/body/active is read-only`. `POST /activate` published it. Already-active workflows (WF-01) are PUT without `active`. |

### Traps already proven

**n8n Switch connections are INDEX-based and the fallback extra
output does NOT shift when a rule is appended.** Appending rule N
makes the fallback N+1, but the pre-existing wire at index N stays
attached to the old fallback target. After appending any Switch
rule, re-GET and verify `connection[i]` target for EVERY output,
not just the new one. Proven on WF-01 Route type, 28 Aug 2026,
execs 265428–265446: five `/flag` messages routed to a silent NoOp
with `reply_text` never set and every execution reporting success.

**Postgres COUNT/aggregate values arrive in n8n as STRINGS, not
numbers.** An IF node with a number operator and `typeValidation`
strict THROWS on them: `Wrong type: 1 is a string but was expecting
a number`. Cast at the SQL boundary — `count(*)::int` — rather than
loosening validation or wrapping in `Number()` at the node. The type
should be right where it is produced. Proven WF-01 Flag many?,
28 Aug 2026, execs 265548/265551/265553: three `/flag` messages
errored, no reply, no enqueue, WF-00 alerted on the second and third.

**PUT `active=true` is 400 on this n8n build.** Activation of an
inactive workflow is `POST /api/v1/workflows/{id}/activate`. Do not
send `active` in a PUT to an already-active workflow. Packet 4.8
proved it on WF-06. This is also rule 19 in the table above.

**Telegram `text` fields store a literal backslash-n when the JSON
string is written that way.** The node will send the two characters
`\` and `n`, not a newline. Real newlines in the stored parameter
are required. Proven WF-00 Telegram owner alert, packet 4.11: 0 real
newlines / 4 literal `\n` before the PUT; after, 4 real newlines /
0 literal `\n`. `timeSavedMode` is an additional property — strip it
from any public PUT the same way as `binaryMode`.

---

## 8. Scope discipline

**No phase may compete with capture reliability.** If later work threatens
Phase 1 stability, the later work loses. Always.

**The 29 August gate is binding.** If Phases 0–3 are not passing on the owner's
actual phone with real cards, all feature work stops and 30 August is spent
hardening.

**During event days (31 Aug – 3 Sep):** no schema refactors, no provider swaps,
no destructive migrations. Only a narrow, tested incident fix with a rollback
point.

**Deferring downstream work costs nothing.** Enrichment, RAG, dashboards, and
CRM all replay against retained raw assets. Capture does not — data never
captured cannot be recovered, and that asymmetry decides every scope argument.

---

## 9. Honesty rules

- **Correct the record when wrong.** Claude asserted that a WhatsApp Business
  API would need Meta approval unattainable in six days; inspection showed the
  owner already ran a live WABA. The correction was recorded in the session log
  rather than quietly dropped. Do this every time.
- **Verify before asserting.** Environment facts are checked against the live
  system, not recalled.
- **Do not quote figures that cannot be verified.** Credit counts derived from a
  documented per-match rule are quotable; vendor pricing that changes is not.
- **Name the risk before it lands**, not after. The 7 AM briefing being the
  most fragile high-value component was flagged at design time so it would be
  tested rather than assumed.
- **State when evidence is weak.** This applies to the system's `/ask` answers
  and to the architect's recommendations equally.

---

## 12. Instance-wide n8n API key

The n8n REST API key is **instance-wide**. It can write or delete all 52
workflows on the shared container, including ElderWise WhatsApp inbound with
real users.

**Allowed targets only:**

- workflows whose **name** begins with `LNI ` or `LNI-TEST-`
- archived orphans `kMozml08Q10ojVmx` and `bvXpsnMJ2FH7PE7X` — verify by
  **name** before any delete

**Hard constraints:**

- Never list-and-act in one step. Fetch, check the name, then act.
- Never call a destructive endpoint against an unprefixed workflow.
- Never restart, upgrade, or change instance settings.
- Never touch ElderWise.

If an operation would touch anything else: **STOP and report.** Do not
continue, guess, or "clean up" extras.
