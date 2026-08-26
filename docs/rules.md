# rules.md

**LEAP Networking Intelligence (LNI)** · Operating Rules
Version 2.0 · 25 August 2026

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
