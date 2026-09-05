# phases.md

**LEAP Networking Intelligence (LNI)** · Version 2.0 · 26 August 2026

Companion to `masterplan.md`. Each phase is built in **its own new chat window**
(`rules.md` §2).

> **Documentation precedes implementation.** A phase does not begin until this
> document reflects its scope. See `rules.md` §1.

---

## Timeline

Re-dated 26 August 2026 (`Asia/Riyadh`). Phase 0 did not start on 25 August.
The **29 August gate does not move.** Phases 0–3 compress into 26–29 August.
The lost day is absorbed by overlapping Phase 0 close-out with the Phase 1
start, not by sliding the gate.

| Date | Target |
|---|---|
| **26 Aug** | Phase 0 — foundation (schema, policies, bucket, WF-00, WF-00b) |
| 26–27 Aug | Phase 1 — capture (starts as soon as Phase 0 verification is accepted) |
| 27–28 Aug | Phase 2 — extraction |
| 28–29 Aug | Phase 3 — digests, `/ask`, watchdog |
| **29 Aug** | **GATE: 0–3 green on real phone with real cards — unchanged** |
| 30 Aug | Phase 4 if green, otherwise hardening |
| **31 Aug** | **LEAP day 1** |
| 31 Aug – 2 Sep | Event operations (owner attended) |
| 3 Sep | Official last day. Owner skipped — health. Zero-capture day closed. |
| **5 Sep** | Phase 10 documented (not built). Freeze lifted. |
| Sep onward | Phase 10 packets 10.1–10.4a–10.4, then Phases 5–8 |

**Honest schedule, 27 Aug 2026.** Phase 0 complete. Phase 1 complete. Phase
2 complete. Phase 3 closed (WF-07/08/09 ACTIVE). Owner opened Phase 4
on 27 Aug against the architect's gate recommendation; the **29 August
capture gate does not move**. Phases 5–8 stay post-LEAP.

**If Phase 2 threatens Phase 3, Phase 2 scope is cut first.** Phase 3
(digests, `/ask`, watchdog) is not squeezed to finish Phase 2 extras. The
watchdog is not cut (`workflows.md` WF-09).

**Scope cut, packet 2.5 (architect decision 26 Aug 2026).** `/fix`,
album auto-detect (packet 1.4), and the provider benchmark are **CUT
from Phase 2 and moved to post-event.** GPT-4o ships as the card engine
**WITHOUT a benchmark.** `rules.md` §7 rule 14 says provider choices are
settled by benchmark; we are **knowingly not honouring it under
deadline**, and this document says so in those words rather than quietly
dropping it. Album grouping stays on `/batch`, which is proven.

---

## Phase 0 — Foundation

**Timing:** 26 Aug · **Blocking:** everything

### Scope
- Supabase project `LEAP-NI` is **already provisioned**. Configuration is in
  `architecture.md` §9 — reference it; do not restate identifiers here.
- Full schema from `architecture.md` §4 — **all 16 tables**, including tables
  belonging to later phases — via numbered forward-only migrations.
- **Explicit RLS policies** on every user-owned table. The `ensure_rls` event
  trigger sets `rowsecurity` independently of any migration statement, so an
  enabled flag is **not** evidence that policy work was done.
- Private bucket `lni-assets`, path policy keyed on first segment =
  `auth.uid()`.
- n8n credentials: Postgres and Storage already proven per `architecture.md`
  §9. The Telegram credential exists but is **unproven**; proving it is a
  Phase 1 deliverable on a real device, not Phase 0.
- LNI WF-00 central error handler. Its ID is set as `errorWorkflow` on every
  LNI workflow — **never** ElderWise's.
- LNI WF-00b read-only credential and connectivity probe.

**Internal ordering.** WF-00b's Postgres branch self-identifies via the
LEAP 2026 seed row, so it **cannot** run before migrations and seed have
landed. The real Phase 0 order is: **migrations + seed → WF-00 → WF-00b**.
The build-order table in `workflows.md` §3 lists WF-00b second by workflow
sequence, not by execution readiness.

### Definition of done
- Migrations apply cleanly, in order, against the empty project.
- `pg_policies` returns **at least one explicit policy** for every user-owned
  table. RLS enabled with zero policies is an **unfinished** migration, not a
  finished one.
- A second authenticated test user reads zero rows from every table and can
  neither list nor download any object in `lni-assets`.
- A duplicate `telegram_file_unique_id` insert fails.
- LEAP 2026 seed row present, timezone `Asia/Riyadh`.
- Every LNI credential bound **explicitly in the n8n UI** and confirmed by
  read-back of the live workflow JSON **before** first execution. The creation
  response is not evidence — it has already been observed to disagree with
  saved state (`workflows.md` §1, trap 3).
- WF-00b's first execution is self-identifying on **both** branches.
- Nothing created or altered in the ElderWise project.

### Verification (architect, by read-back)
1. Read live schema — every table present with stated columns and types.
2. `pg_policies` returns at least one explicit policy per user-owned table,
   **not** by reading the migration file and **not** by checking
   `rowsecurity = true`. The `ensure_rls` event trigger sets that flag
   regardless. RLS enabled with zero policies is unfinished work.
3. Bucket confirmed private; policy references `auth.uid()` as first segment.
4. `assets.telegram_file_unique_id` carries a real UNIQUE constraint.
5. Seed row timezone correct (`Asia/Riyadh`).
6. Per LNI workflow, from live JSON: `settings.errorWorkflow` resolves to
   LNI WF-00's ID, **and** `availableInMCP` is `true`. The ElderWise
   credential-check workflow carries **no** `errorWorkflow` at all, so this
   setting is per-workflow and is **not inherited**. Check each LNI workflow
   individually.
7. WF-00b first execution is self-identifying on both the Postgres branch
   (LEAP 2026 seed row) and the Storage branch (`sb-project-ref` header).
8. ElderWise project untouched.

---

## Phase 1 — Capture path

**Timing:** 26–27 Aug · **Must be live 30 Aug** · **This is the launch release**

### Scope
- WF-01 ingest router: Telegram → Storage → Postgres
- Commands `/new`, `/done`, `/batch`, `/status`
- Four guardrails (`prd.md` §4)
- Bare receipt on `/done`
- Idempotency on `telegram_file_unique_id`

Album auto-detect (inline "separate people or one person?" prompt) was a
Phase 1 leftover. **Owner decision 27 Aug 2026: promoted into Phase 2
scope.** Phase 1 stores album members as ordinary photos; nothing is lost.

### Definition of done
- Photo, voice note, and typed note each capture independently
- `/new` implicitly closes a previously open capture
- Media arriving with no open capture opens one silently and says so
- Inactivity auto-close fires and stamps `close_reason = auto`
- **20 real-device captures with 100% asset preservation** and 100% visible
  outcome — no silent loss
- Resending the same media does not create a duplicate asset
- Storage failure results in **no** receipt, so the owner is never falsely
  reassured

### Verification
Read `assets` and `captures` directly; count rows against what was sent.
Confirm every storage object exists at its recorded path.

---

## Phase 2 — Extraction

**Timing:** 27–28 Aug · **Should be live 30 Aug**

### Scope
- WF-03 asset processors: **one** vision call per image (strict schema
  returns `image_type` `business_card | scene | other`; then `UPDATE
  assets.kind`). Whisper on audio. No OCR-then-parse.
- WF-02 `/done` enqueue: one `INSERT` into `processing_jobs`, then **one**
  fire of WF-03 (`waitForSubWorkflow: false`). Postgres is the queue.
- WF-04 structured extraction against the versioned contract
- WF-05 entity resolution — suggest only
- Normalized writes to `people`, `companies`, `person_companies`,
  `interactions`
- Rule-based flagging
- `field_corrections` on `/fix` — **CUT to post-event** (packet 2.5)
- **Provider benchmark** — **CUT to post-event** (packet 2.5). GPT-4o
  ships as the card engine without a benchmark. `rules.md` §7 rule 14
  says provider choices are settled by benchmark; we are knowingly not
  honouring it under deadline.
- **Album auto-detect** — **CUT to post-event** (packet 2.5). Album
  grouping stays on `/batch`, which is proven. Design remains in
  `workflows.md` WF-01 for the post-event build.

Phase 3 remains launch-blocking and untouched. If Phase 2 threatens
Phase 3, **cut Phase 2 scope first** (album prompt and benchmark extras
before digest/watchdog).

### Definition of done
- `language` unset on the transcription node — verified in the live JSON
- Arabic name preserved in `name_original_script`; `full_name` must be
  non-null. An Arabic-only `full_name` is accepted identity
  (`architecture.md` §6, packet 3.6 ruling). Packet 3.7: the
  informational flag `'Non-Latin script present in the name field'`
  no longer forces `captures.status = needs_review`; every other flag
  still does.
- A card plus a 30-second voice note produces a reviewable record within
  2 minutes
- Raw vision output, transcript, and structured output all traceable from one
  capture
- No auto-merge occurs on name similarity alone
- Failed provider calls retry, then land in a visible `failed` state without
  creating duplicate people
- Inactivity sweep enqueues and dispatches the same as `/done` (packet 2.5
  defect 1)

**Moved to post-event (not Phase 2 done):** album-of-20 prompt; provider
benchmark on GPT-4o / Gemini / Mistral; `/fix` → `field_corrections`.

### Named Phase 3 item — retry backoff
A requeued job returns to `queued` with **no Wait** inside WF-03/04/05
(300 s timeout). **The delay is the worker claim**, not WF-09. Delays
are 1 and 5 minutes from `last_transition_at`. Ceiling stays 3.
**The 20 minutes is deleted:** claim bumps `attempt_count`, so a job
is claimed at 1, 2, 3 and failed at 3 — exactly two waits. A third
delay is unreachable. A twice-failed job at a four-day event is
poison and belongs in the watchdog alert, not in a third retry
(`workflows.md` WF-03 / WF-09; same recording style as `rules.md`
§7 rule 14). WF-09 remains the kicker for missed initial dispatch,
stuck `running`, and post-event quiet.

---

## Phase 3 — Digests, query, watchdog

**Timing:** 28–29 Aug · **Should be live 30 Aug**

### Scope
- WF-07 digests: 10 PM close, 7 AM briefing, `/digest` on demand
- WF-08 `/ask` natural-language query
- WF-09 stuck-job watchdog. Claim predicate (1 and 5 minute delays,
  ceiling 3) lives on WF-03/04/05. WF-09 kicks; it does not delay.
  Measure from `last_transition_at`. Do not Wait inside WF-03/04/05.
  The 20-minute tier is deleted.

### Definition of done
- Both schedules fire at the correct **`Asia/Riyadh`** local time — verified by
  observed execution timestamps, not by reading the cron expression
- 10 PM close reports captured / clean / flagged / failed / stuck counts
- 7 AM briefing reports coverage: people met, companies, sector distribution,
  gaps against targets, follow-ups due today
- `/ask` answers over real captured data
- **Watchdog alerts independently of the digest**

### Why the watchdog is launch-blocking
The owner chose low-confidence-only notification, which makes the 10 PM digest
the single point of failure detection. If that digest does not fire on the 31st,
there is no signal at all until the owner goes looking. The watchdog exists
specifically to cover that gap and must not be cut when Phase 3 is squeezed.

### Highest-risk item
The 7 AM briefing depends on a cron timezone, a digest query, and extraction
having worked the night before — three things that can each fail silently. It is
also the highest-value output in the system, being the only thing that changes
how a day is spent while the event is still running. **Test with real data on
29 Aug; do not assume.**

---

## Phase 4 — Enrichment

**Timing:** Owner opened Phase 4 on 27 Aug 2026, before the 29 August gate
(decision 8 reversal; recorded). The **29 August capture gate does not
move.** If capture reliability is threatened, Phase 4 yields
(`rules.md` §8). WF-01 stays untouched until the 07:00 28 Aug briefing
is observed.

### Scope
- WF-06 drains an enrichment job queue on a **schedule**. WF-05
  **enqueues**; it does not dispatch per capture.
- Auto-enrich any person with a non-null `email_normalized` whose
  capture is not `needs_review`.
- `/flag` force-enriches a person the guard skipped.
- `organizations/enrich` fires only as a fallback for a company with no
  enriched person.
- Both provider ceilings read from `lni_config` (never `$env`).
  Keys: `apollo_daily_ceiling`, `apollo_lifetime_ceiling`,
  `tavily_lifetime_ceiling`.
- Credit guard with `credit_ledger`: ledger row **before** the provider
  call.
- Tavily company-website fallback only (`provider = 'tavily'`). Never
  people data. Never merged into an Apollo row.
- Writes land in `enrichment_records` only, except the LinkedIn-null
  fill documented in `architecture.md` §7.

### Definition of done
- Person enrichment fires automatically on non-null `email_normalized`
  when the capture is not `needs_review`
- `/flag` force-enriches a person the auto-guard skipped
- `organizations/enrich` runs only as the company fallback
- Credit ceiling proven to hold under a forced retry loop
- `credit_ledger` total reconciles against the DELTA in Apollo's
  `num_credits_remaining`. Do NOT reconcile against
  `num_lead_credits_used`: measured 27 Aug 2026, an
  `organizations/enrich` call moved `num_credits_remaining`
  2605 → 2604 while `num_lead_credits_used` stayed 0. The usage
  counter does not track API enrichment on this account.
- Tavily results labelled `provider = 'tavily'`, never conflated with
  Apollo data, never written as people fields
- Captured `people.email` / `full_name` / `title` / `phone` are never
  overwritten by enrichment

**Capture still wins.** Enrichment on a contact captured on 31 August
works identically on 5 September. The data is already in the building.
Do not let this phase compete with ingest.

---

## Phase 5 — Web dashboard

**Timing:** post-event. Not started.

Next.js on Vercel. Tables, filters, bulk review, merge tooling with visible
scores and reasons, per-contact delete, export.

Better for waiting: designing review queues against 350 real captured records
beats designing them against imagined ones.

---

## Phase 6 — RAG

**Timing:** post-event. Migration number **030**. Not applied.
Do not reuse 027–029 — those are follow-up brief, followup capture
mode, and contact `source_type`.

pgvector, hybrid keyword + vector retrieval, citations back to source
interactions, owner-scoped filters.

Embed **approved interaction summaries, notes, and approved entity data** — not
raw media. Answers must state when evidence is weak rather than confabulate.

Deferred deliberately: a few hundred rows fit comfortably in a model's context,
so `/ask` needs no vector store at launch. Vectors earn their place when the
corpus outgrows the context window.

---

## Phase 7 — Follow-up and prioritisation

**State:** built on the live instance. `/followup` opens a
`capture_mode='followup'` capture (028). `/done` tries WF-10
immediately. If the person is not in `people` yet, the draft stays
`draft` and WF-05 dispatches WF-10 `source='deferred'` when
entity_resolution succeeds. WF-10 sends the confirm card on
`sweep` and `deferred` (recorded exception to “WF-01 sends”).
Packet 9.10: followup `/done` enqueues on the same node as
standard (WF-02 `847cc3c7`). TEST: `/done` → card **21 s**
(WF-02 **280253** / WF-10 **280271**). WF-09 is the backstop.

The 15-minute `awaiting_voice` window is leftover, not the design.
A follow-up is a capture.

Prioritisation scoring with **visible factors** — no opaque AI scores.
Gmail send is still confirm-then-send. Reminders and due dates beyond
the draft card are post-event extras.

## Phase 9 — Contact ingest

**State:** Packet 9.6 applied and phone-proven 29 Aug 11:12–11:19
Riyadh. Contact #134, `.vcf` #135, HTML confirm `message_id` 512,
real send `bb3689d8`. WF-01 `4836ffd8` — do not PUT again.
Enqueue is asset-level: skip followup audio only. 9.6-B live:
#136 WF-09 **279752** enqueued 2 images, not the audio.

**Draft-only, enforced.** A mis-extracted address plus auto-send puts a warm,
specific message about a private conversation into the wrong inbox at the right
company. That is not a bug you fix; it is a relationship lost without knowing
why.

**LinkedIn:** store and resolve profile URLs only. Automating connection
requests or messages violates LinkedIn's terms and the realistic outcome of bulk
automation is a restricted account.

---

## Phase 10 — Post-event repair and history outreach

**Timing:** 5 Sep 2026 onward. **State:** documented. **Not built.**
Docs first (`rules.md` §1). No PUT, no migration, no SQL write
until a packet authorises it.

**Event close (architect, live SQL 5 Sep).** 39 event captures,
78 new assets, 169 total, 0 not stored. 36 new people, 44
companies, 0 queued, 0 orphans. 16 people have email; 3 already
emailed (DES RAJ Chauhan, Rana Waleed, Shahzad Jameel) → **13
to contact**. 7 of those 13 have a scene photo. 17 people have
neither email nor phone; 7 of those are LinkedIn screenshots —
**owner handles over LinkedIn, out of scope.** ~9 are
voice-note-only and in scope for enrichment. 16 captures at
`needs_review` — correctly flagged, single cause, see 10.1.
Person minted with no interaction is **S6** (Ahmed Alkaf),
not an extra 10.1 task.

**Locked:** D-A, D-B, D-C, D-D (`masterplan.md` §4). Decision 12
strengthened. WhatsApp is not designed.

### Packet 10.1 — Data repair

The 16 `needs_review` captures since 2026-08-30 21:00Z are
**correctly flagged**. One cause. Live `extraction_runs`
flags: `"No email and no phone"` ×16, `"No name extracted"`
×2, `"Non-Latin script present in the name field"` ×1.
These are the voice-note and LinkedIn people with no
contact details. Nothing to adjudicate. Route to **10.3**
(enrichment) or LinkedIn (owner, out of scope).

Merge duplicates **by suggestion only** — never auto-merge
on name (`rules.md` §7 rule 5):

- Ali Abbas ×2
- probable أشرف = Ashraf Abu Elayyan
- probable Imad = Imad Afyouni

Resolve leftover captures **#155 #161 #150 #164** (S2/S3/S4
rows; do not invent missing assets).

**Acceptance**

- Suggested merges are `entity_candidates` (or equivalent
  review rows), never silent `people` UPDATEs on name.
- #155 #161 #150 #164 have an explicit terminal note
  (leave / extract-note / close-ready). No silent DELETE.
- Architect verifies from live SQL, not the implementer report.

### Packet 10.2 — S1–S6 fixes + PR #71

Fix the September defects (`rules.md` known defects S1–S6).
Merge PR **#71** (`sanitize_for_put` uses `activeVersion`;
still OPEN/draft on `cursor/session-09-sanitize-put-364d`).
S5 (duplicated/spliced `## Standing` in
`session-09-freeze-triage.md`) is docs-only cleanup in this
packet. S6 is diagnosed in this packet **before** any fix.

**Acceptance**

- S1: `/done` `item_count` counts what the owner believes
  is in the capture (assets **and** contact/note), or the
  receipt text no longer says "0 items" when a person or
  note exists. Architect names the chosen wording.
- S2: after `ingest_contact` + WF-05 `ready`, the next
  typed note lands on **that** capture. `open_capture_id`
  is either cleared or `resolve_target` accepts `ready`
  when it still points at the last ingest. Prove with a
  contact then a note, 19-second class. No stranded empty
  capture.
- S3: a typed-note-only `/done` enqueues extraction (or
  an equivalent path). Note is extracted. WF-05 runs.
- S4: an audio-only followup `/done` leaves
  `captures.status` a terminal value (`ready` or
  `needs_review`), not `processing` forever. Enqueue skip
  for followup audio **stays**. WF-10 or a named sibling
  writes the status. Published WF-10 today has zero
  `UPDATE captures` — that is the gap.
- PR #71 squash-merged or closed with a reason. Rebase
  expected: its copy of `session-09-freeze-triage.md`
  predates #70/#72.
- S5 Standing block is one clean paragraph.
- S6: cause of Ahmed Alkaf (`32c8efee`, capture **#153**,
  `src=card`, 31 Aug 13:28Z) having no `interactions` row
  is written in the session log **before** any code change.
  #153 is `ready`; extraction succeeded (`blossommena` in
  `structured_output`); WF-05 minted the person; no
  interaction was written. Do **not** INSERT an interaction
  by hand. Fix only after the architect accepts the cause.
- No PUT on WF-01 unless a later packet says so.

### Packet 10.2c — S7a + S7b. STOP before PUT.

Identity loss only. WF-02 + WF-04. Do not touch WF-05 /
WF-09 / WF-10 / WF-01.

**Stopped 5 Sep.** WF-05 `Set capture status` (`68f47505`)
is `UPDATE captures SET status=ready|needs_review WHERE
id=$1` — no prior-status predicate. It writes `ready` on
`status='open'`. Packet required halt. No WF-02/WF-04 PUT
until the architect authorises the kick-split (enqueue ER
on reused, Call WF-05 only when not reused) or a later
WF-05 WHERE clause.

### Packet 10.3 — Apollo sweep, voice-note-only

Sweep the ~9 voice-note-only people. Measured reveal rate
on Saudi SME contacts is ~50%; expect 4–5 of 9. Budget
~9 credits against ~2,570 remaining (5 Sep). Person-by-email
unchanged (Decision 8). Do not invent emails.

**Acceptance**

- Named list of the ~9 before the sweep. Architect agrees
  the list.
- `credit_ledger` rows match calls. Ceiling holds.
- Reveal rate reported (matches / no_match / failed).
- Captured `people.email` / `full_name` / `title` / `phone`
  never overwritten.
- LinkedIn-screenshot people are **not** in this sweep.

### Packet 10.4a — Gmail draft+attach spike

**Before 10.4.** Disposable `LNI-TEST-` workflow. Prove on a
**real stored object** (not a pinned fixture) that Gmail
`typeVersion` 2.2 `resource=draft` `operation=create`
accepts `options.attachmentsUi.attachmentsBinary[].property`
and the draft lands in Drafts **with the file attached**.

GET name, then act. Do not touch ElderWise. Delete the test
draft after the owner has opened Drafts. If it fails, report
the failure. **Do not design a fallback** until the architect
sees it.

**Acceptance**

- One real Gmail draft, one real attachment, one execution
  id. Owner verifies by opening his Drafts folder.
- Test workflow name-checked `LNI-TEST-` and deleted (or
  archived) after the prove.
- No LNI production PUT. No pinData as evidence.

### Packet 10.4 — WF-10 `source='history'`

New source. Load stored interaction summary, transcript,
and card fields for a **named** person. Compose a tailored
draft by **reusing `Extract draft`**, not a second LLM
node. Auto-attach the scene photo when one exists (D-B).
Create a **Gmail Draft**. Telegram gets a receipt only.
No Send / approve button (D-C).

**Acceptance**

- `Normalize input` / `Route source` accept `history`.
  After appending the Switch rule, re-GET every
  `connection[i]` (standing trap).
- `Extract draft` is the same node (prompt version may
  gain a history preamble; no forked composer).
- For each of the 13: one `follow_ups` row,
  `draft_state` = the new Gmail-draft value (proposed
  `gmail_draft`; migration is 10.4, not this docs packet).
  `status` stays `open`. `gmail_message_id` holds the
  Gmail draft id.
- The 7 with a scene photo have that asset on
  `attachment_asset_ids` with no picker.
- Gmail Drafts folder contains the 13. Inbox does not.
- Telegram receipt names person + subject + "draft in
  Gmail". No inline keyboard.
- Voice path (`awaiting_confirm` + Send) is unchanged.
- WhatsApp is not referenced in the graph.
- Architect GET of published WF-10. No send node on the
  history branch.

---

## Phase 8 — PWA capture surface

**Timing:** post-LEAP

Next.js PWA sharing the Phase 0 backend. Camera, mic, IndexedDB offline queue,
review UI.

Built after the event on purpose: it will be designed against a database full of
real contacts and real failure patterns, rather than assumptions.

---

## Field operations during LEAP

- Verify Telegram permissions and bot responsiveness before leaving each day
- Capture immediately after each conversation: `/new`, card, voice note while
  context is fresh, `/done`
- `/batch` in the evening for cards collected without notes
- **Read the 7 AM briefing before leaving** — the only chance to act on coverage
  gaps while the event still runs
- Check the 10 PM close for `failed` and `stuck`. Non-zero on day one is
  investigated that night, not on day four
- No schema refactors or provider swaps during event days
