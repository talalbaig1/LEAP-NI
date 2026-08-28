# Cursor handover — Session 07

Paste this as the first message of a **new Cursor window**. Assume no
memory of session 06. You are the implementer. Architect/verifier is
Claude. Owner is Talal.

Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read, in order: `docs/rules.md` (including §13),
`.cursor/skills/lni-n8n-conventions/SKILL.md`, `docs/masterplan.md`,
`docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`, `docs/sessions/session-06-phase-4.md`,
`docs/sessions/handover-to-session-07.md`, this file.

Then read **PR #36 / `docs/plans/phase-07-plan.md`**. UNREVIEWED.
Do not build from it until the architect issues a packet.

Secrets and live ids: gitignored `docs/environment.local.md` (also
`docs/n8n.local.env`). Never commit them. Never copy values into
tracked files.

---

## What is true right now

- Phases 0–4 complete. `main` at session-06-close merge (see git).
- Remaining pre-event order, owner 28 Aug: **Phase 7, then 6, then
  5.** Phase 8 PWA is **refused** pre-event (`masterplan.md` §3
  Corollary 1). Phase 5 is last because GRANT SELECT finally
  exercises 16 unevaluated RLS policies (session 02).
- **WF-01 is FROZEN** until the 29 Aug gate.
- **PR #36 stays open** until the architect reads it. Do not merge
  it yourself unless a packet says so.
- Do not deactivate LNI workflows. Do not restart n8n. Do not touch
  ElderWise.

---

## Repo layout

| Path | What |
|---|---|
| `docs/rules.md` | How the project is run. Traps. Session-close rules §13. |
| `docs/architecture.md` | Schema, enrichment boundary, security. |
| `docs/workflows.md` | Live node contracts. No workflow JSON is committed. |
| `docs/prd.md` | Commands and UX. |
| `docs/phases.md` | Phase scopes. Pre-event 7/6/5 order is in session-06 §9, not yet rewritten here. |
| `docs/masterplan.md` | Locked decisions. Decision 8 reversed. Decision 12 = no auto-send. |
| `docs/plans/phase-07-plan.md` | Unreviewed Phase 7 plan (PR #36). |
| `docs/sessions/` | Session logs + handovers. |
| `docs/environment.local.md` | Gitignored live facts. Update at every session close. |
| `docs/environment.example.md` | Placeholders only. |
| `supabase/migrations/` | Numbered forward-only SQL. |
| `.cursor/skills/lni-n8n-conventions/SKILL.md` | Overrides any general n8n skill. |

---

## Migrations

Convention: file `NNN_snake_name.sql`. Catalog name must also start
`NNN_`. **023 failed that:** file is
`023_processing_jobs_enrichment_person_uniq.sql`; live catalog
version `20260828013026`, name **`processing_jobs_enrichment_person_uniq`**
(no prefix). Next file is **`024_…`** and the catalog name must
match.

Repo files: `001`–`023` (23 files). **012 never applied** (GUC unset;
do not re-apply). Live catalog: **22 rows** — `001`–`011`, `013`–`022`
prefixed, plus the unnamed 023 row. Apply order is the version
clock, not file order (`009` landed after `010`). Forward-only.
Never edit an applied file.

Event days 31 Aug – 3 Sep: no schema refactors.

---

## n8n API

Key lives in `docs/environment.local.md` as `N8N_API_KEY` (and/or
`docs/n8n.local.env`). Base URL `N8N_BASE_URL`. The key is
**instance-wide** (ElderWise + LNI). Allowed names only: `LNI ` or
`LNI-TEST-`. GET **name**, then act. Never list-and-act.

Patterns that work:

- GET `/api/v1/workflows/{id}` then check `name`.
- PUT body **without** `active` on an already-active workflow.
- Strip `settings.binaryMode` (public PUT is 400).
- Strip `settings.timeSavedMode` (additional property, 400).
- Settings that stick: `timezone`, `errorWorkflow`,
  `executionTimeout`, `availableInMCP`, `callerPolicy`,
  `executionOrder`.
- Activate an **inactive** workflow:
  `POST /api/v1/workflows/{id}/activate`.
- `queryReplacement` = **one** expression → one array
  `{{ [a, b, c] }}`.
- Postgres Leap-NI bind, then self-id
  `SELECT name FROM public.events WHERE name = 'LEAP 2026'`.
- MCP `create_workflow_from_code` is **not** evidence. REST PUT
  settings + credentials after every create.

Patterns that 400 or lie:

- PUT `"active": true` → 400 `request/body/active is read-only`.
- PUT `settings.binaryMode` → 400.
- PUT `settings.timeSavedMode` → 400 additional property.
- MCP create auto-binds ElderWise Postgres. Creation response
  disagrees with saved JSON. Self-identify or you are on the wrong
  database.

Do not deactivate to "test". Rollback WF-01 by PUT of a known prior
`versionId`, still without `active`.

---

## Credentials to keep bound (names + ids in environment.local)

Never ElderWise Postgres. LNI set: Leap-NI postgres, Leap-NI
Telegram, OpenAi account, Supabase_Leap-NI, Gmail, **Apollo
Leap-NI**, **Tavily Leap-NI**. Ids in the gitignored file.

---

## Trap list as this implementer applies it

1. `$env` and `$getWorkflowStaticData` — forbidden. Postgres is
   state.
2. Never `$json` after I/O. Named node.
3. `alwaysOutputData` empty item is not a zero-count row. Gate
   `id` notEmpty.
4. Zero-row UPDATE is `{success:true}`. RETURNING + gate before
   any send.
5. Postgres COUNT is a **string**. Cast `::int` at SQL. Strict
   number IF throws otherwise.
6. Switch connections are **index-based**. Append a rule → re-GET
   **every** `connection[i]`. Fallback does not shift.
7. `.first()` after a Merge, never `.item`.
8. REST jsCode: double backslashes, or write patterns with none.
9. Telegram `text`: real newlines, not literal `\n`.
10. `parse_mode` explicit HTML. Absent is Markdown. Escape `& < >`.
11. PUT without `active` on live workflows. `POST /activate` for
    inactive. Strip `binaryMode` and `timeSavedMode`.
12. filesystem-v2: Code cannot read binaries. HTTP `responseFormat:
    file`. Pins are not proof. Size = HEAD `Content-Length`.
13. `queryReplacement` one array. Mixed CSV drops literals.
14. Whisper: never set `language`.
15. stopAndError: no comma, quote, or apostrophe.
16. Never log emails, phones, transcripts, tokens, signed URLs.
17. Unchanged row counts do not prove a decline branch.
18. MCP create is not evidence.
19. Do not invent a second ledger UUID. `73fc2831` over-count of 1
    is cancelled by the **absent** 4.0 `organizations/enrich` row
    for huawei.com, not by a second written row.

Locked evidence rows: session-06 §8. Do not edit them.

---

## What you wait for

Architect packet after PR #36 read-back. Phase 7 build starts at
7.1 (schema) only when that packet lands. WF-01 is not in 7.1–7.3.
If the 29 Aug gate fails, stop feature work and harden capture.
