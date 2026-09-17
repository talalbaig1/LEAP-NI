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
| **14 Sep** | Phase 10 closed. Packet 12.0 docs (multi-tenancy). No migration. |
| Sep onward | Phase 12 packets after Q1–Q5 lock, then Phases 5–8 |

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
standard (WF-02 `<WF02_PUBLISHED>`). TEST: `/done` → card **21 s**
(WF-02 **280253** / WF-10 **280271**). WF-09 is the backstop.

The 15-minute `awaiting_voice` window is leftover, not the design.
A follow-up is a capture.

Prioritisation scoring with **visible factors** — no opaque AI scores.
Gmail send is still confirm-then-send. Reminders and due dates beyond
the draft card are post-event extras.

## Phase 9 — Contact ingest

**State:** Packet 9.6 applied and phone-proven 29 Aug 11:12–11:19
Riyadh. Contact #134, `.vcf` #135, HTML confirm `message_id` 512,
real send `bb3689d8`. WF-01 `<WF01_PUBLISHED>` — do not PUT again.
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
emailed (<CONTACT_14_NAME>, <CONTACT_11_NAME>, <CONTACT_15_NAME>) → **13
to contact**. 7 of those 13 have a scene photo. 17 people have
neither email nor phone; 7 of those are LinkedIn screenshots —
**owner handles over LinkedIn, out of scope.** ~9 are
voice-note-only and in scope for enrichment. 16 captures at
`needs_review` — correctly flagged, single cause, see 10.1.
Person minted with no interaction is **S6** (<CONTACT_16_NAME>),
not an extra 10.1 task.

**Locked:** D-A…D-K (`masterplan.md` §4). Decision 12
strengthened. WhatsApp **API** is not designed (D-D). Copy-text
to Telegram is (D-E).

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

- <CONTACT_13_NAME> ×2
- Arabic single-token name `<CONTACT_44_NAME>` matched Latin full name
  `<CONTACT_44_NAME>` (script pair, same human; the proof is
  the pair of scripts, not string-equal)
- Short given name `<CONTACT_27_NAME>` matched Latin full name `<CONTACT_27_NAME>`
  (given vs full, same human)
- Telegram label `<CONTACT_43_NAME>` (#210, tel
  +966554936765) = person name `<CONTACT_43_NAME>` (#174). Same man, two
  rows, label vs name. No email on either so nothing
  auto-linked. Logged 7 Sep after T2. Do **not** replay #174.

Telegram contact labels that became `people.full_name`
because they were the only name (correct 10.2c behaviour)
need cleaning here, not in capture: e.g. "<CONTACT_38_NAME>", "<CONTACT_43_NAME>".

**S7b replay.** 10.2c-fix PUT landed (`6fa41bc4`).
**#151 PASS** (WF-04 `383289`, person minted). Remaining
six replayed 7 Sep (WF-04 `383365`, WF-05 `383367` +
`383381`). **Do not replay #167 or #174** — owner
re-shared those contacts by hand on 7 Sep; a replay
would mint a third row.

Resolve leftover captures **#155 #161 #150 #164** (S2/S3/S4
rows; do not invent missing assets).

**Acceptance**

- Suggested merges are `entity_candidates` (or equivalent
  review rows), never silent `people` UPDATEs on name.
- #155 #161 #150 #164 have an explicit terminal note
  (leave / extract-note / close-ready). No silent DELETE.
- Architect verifies from live SQL, not the implementer report.

**Executed 14 Sep (owner-authorised Part A–D).** Architect
verifies from live SQL. Implementer report is not evidence.

Part A (record, not a scoring fix): 77 pending
`entity_candidates`. **37** score=1 hardcoded
(OCR-split / unlinked_company_payload /
`field_latin_disagrees` / company alias). **40**
`name_trgm` computed `similarity()` 0.3–0.6875. Do not
fix scoring in 10.1.

Part B — ten owner-decided merges. Survivor =
interactions win. Never overwrite a non-null field.
Never delete a people row that still holds an
interaction, follow_up, or person_companies link.
`person_companies` has **no** UNIQUE `(person_id,
company_id)` — two current employers are allowed.

| # | Survivor | Absorb | Copied | Moved | Notes |
|---|---|---|---|---|---|
| 1 | <CONTACT_6_NAME> `49d75705` | `58ea7ec0` | email+phone | 2 drafts | leftover absorb deleted after children moved |
| 2 | <CONTACT_39_NAME> `ee8f8242` | `94f6d2b2` | phone | WA draft | |
| 3 | <CONTACT_42_NAME> `bc1a347f` | `4e51b68d` | phone | WA draft | |
| 4 | <CONTACT_37_NAME> `ae02af5e` | `8ae2ea22` | phone | WA draft | dropped dup IVY link |
| 5 | Rana `fc2ba74f` | `4ef3824c` | **phone only** | WA draft | name stays <CONTACT_11_NAME> |
| 6 | <CONTACT_43_NAME> `f60aebe7` | `3be1d85e` | phone | WA + 1 interaction | renamed <CONTACT_43_NAME> → **<CONTACT_43_NAME>** (spelling of the same name) |
| 7 | <CONTACT_14_NAME> `61b14e31` | `1905fff3` | none (Aliph kept) | cancelled LI + 1 interaction | Utopian added as **second** `person_companies`; live channels stay email+WA |
| 8 | <CONTACT_44_NAME> `10cf0540` | `39d9fffa` | SEED link | cancelled LI | one live LinkedIn remains |
| 9 | <CONTACT_13_NAME> `4efe1828` | `d887ab79` | — | — | empty duplicate; dropped dup Blossom |
| 11 | <CONTACT_1_NAME> `9f91fb97` | `9292bc7e` | **never email** | 1 interaction | dropped dup <CONTACT_2_COMPANY>; survivor email stays `<CONTACT_2_EMAIL>` |

**#10 <CONTACT_3_NAME> — not merged.** `d2335783`
(<CONTACT_4_COMPANY>) and `ba037ac0` (<CONTACT_2_COMPANY>) both kept. Two
employers with two emails is a normal networking
case. Needs `person_emails` (or equivalent). See
packet **12.3**. Outreach already dual-To: on the <CONTACT_4_COMPANY>
draft.

Part C — rename: `"<CONTACT_38_NAME>"` `fab486c2` → **<CONTACT_38_NAME>**.
<CONTACT_43_NAME> label handled by merge 6. <CONTACT_11_NAME>
moot (merge 5). **<CONTACT_20_NAME>: not touched**
(two test rows remain).

Part D — **do nothing** to 61 pre-window pending
candidates (`created_at < 2026-08-30 21:00Z`: 2 on
27 Aug, 57 on 28 Aug, 2 on 29 Aug).
`decision='rejected'` would claim a review nobody
did. 10.1 wrote no 034. 16 in-window pending also
left pending (table reworked in packet **12.4**).
034 is packet 12.1 (`lni_settings` +
`lni_instance` + uniques + platform owner, applied
16 Sep), not this table.

Live counts (SQL 14 Sep):

| | people | interactions | follow_ups | person_companies |
|---|---|---|---|---|
| Before leftover <CONTACT_6_NAME> delete | 84 | 125 | 108 | 58 |
| After 10 deletes + <CONTACT_38_NAME> rename | 74 | 125 | 108 | 55 |

Missing-person orphans: interactions 0, follow_ups 0,
person_companies 0. Pre-existing NULL `person_id`
(S9, not this packet): interactions 8, follow_ups 7.
Pending candidates still 77 (61+16). Absorbed ids
gone. <CONTACT_3_NAME> both rows unchanged.

WF-10 History skip list PUT after the merges: published
`<WF10_ROLLBACK>`. Rollback
`<WF10_PUBLISHED_CH5>`. Removed
obsolete skip ids (<CONTACT_6_NAME> / <CONTACT_37_NAME> / <CONTACT_39_NAME> / <CONTACT_42_NAME> /
<CONTACT_43_NAME> survivors). Kept `ba037ac0` (<CONTACT_3_NAME> <CONTACT_2_COMPANY>) and
the name skips (`<CONTACT_12_NAME>`, `<CONTACT_13_NAME>`,
`<CONTACT_11_NAME>`, `<CONTACT_51_NAME>`, `<CONTACT_20_NAME>`).

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
- S6: cause of <CONTACT_16_NAME> (`32c8efee`, capture **#153**,
  `src=card`, 31 Aug 13:28Z) having no `interactions` row
  is written in the session log **before** any code change.
  #153 is `ready`; extraction succeeded (`blossommena` in
  `structured_output`); WF-05 minted the person; no
  interaction was written. Do **not** INSERT an interaction
  by hand. Fix only after the architect accepts the cause.
- No PUT on WF-01 unless a later packet says so.

### Packet 10.2c — S7a + S7b. PUT landed.

Identity loss only. WF-02 `ce51e6f4` + WF-04 `dafe9b02`.
WF-05 `<WF05_PUBLISHED>` not touched. S8 logged; not fixed.

**7 Sep phone.** T1, T2 (×2: #209 #210), T4 PASS. S7a
proven. T3 first attempt hit Rule 4 duplicate of #174.
**#212 PARTIAL:** composition path proven (wf04-v6 kept
card name; no duplicate). GAP 2 was a defect: Build
dropped `contact_run`. **10.2c-fix PUT:** WF-04
`6fa41bc4-175f-4787-8b91-458e502e4a62` (equals
`activeVersionId`). Rollback `dafe9b02`. Prompt
`wf04-v6`. #151 replay **PASS** — WF-04 exec `383289`.
Person <CONTACT_36_NAME> minted. **S9** logged: replayed
person has no interaction (null-`person_id` row already
on the capture; S6 NOT EXISTS). Remaining six replayed
7 Sep.

### Packet 10.2e — repo hygiene + remaining six

**Part A closed.** Squash-merged in order, branches
deleted. Zero open PRs after the three merges.

| PR | squash SHA | what |
|---|---|---|
| #74 | `af7f22251bc1f468c15c34c7710af851ecfae869` | 10.2b S1–S4 |
| #75 | `61ec55ccf97d363841ab096137d913f3c1602e7a` | 10.2c S7/S8 |
| #76 | `6fa17b65ede4ab2384fb44a1e8e300f4af2a3d95` | 10.2c-fix + S9 + #151 |

**Part B replayed** 7 Sep. Authorised six only. Not
#167 #174. Mechanism: enqueue `extraction` (then ER),
backdate `last_transition_at`, kick WF-09 production.

| kick | parent WF-09 | child |
|---|---|---|
| six extractions | `383364` | WF-04 `383365` (all six `wf04-v6`) |
| #203 ER (executeOnce first hit) | (from `383365`) | WF-05 `383367` |
| other five ER | `383379` | WF-05 `383381` |

Minted people (architect reads SQL):

| cap | person | email | phone | note |
|---|---|---|---|---|
| 157 | <CONTACT_6_NAME> `58ea7ec0` | <CONTACT_6_EMAIL> | +966 55 667 7268 | second row; old `49d75705` still null |
| 156 | <CONTACT_11_NAME> `4ef3824c` | — | 0538584129 | **not** fill onto Rana. 0 named asset people → Parse adopted contact-v1 wholesale. Rana `fc2ba74f` unchanged |
| 165 | <CONTACT_39_NAME> `94f6d2b2` | — | 0509609942 | second row (speech spelling **<CONTACT_39_NAME>**, not Khizar) |
| 184 | <CONTACT_42_NAME> `4e51b68d` | — | +923000334560 | second row |
| 185 | <CONTACT_37_NAME> `8ae2ea22` | — | +447545222169 | second row |
| 203 | <CONTACT_51_NAME> `60ff201e` | — | 966501690331 | first mint; interaction linked |

WF-05 name auto-link is email/LinkedIn only, so
#156 #157 #165 #184 #185 each minted a **second**
person. Do not merge by hand.

**S9 proven** on #151 and #156–#185: replay-minted
person has no `interactions` row (prior row exists).
#203 had no prior row, so Insert ran. Do not fix.
10.4 is **docs first** (`docs/plans/packet-10-4-history-outreach.md`).
No build until the architect authorises.

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

### Packet 10.4 — WF-10 `source='history'` (docs 7 Sep)

**Docs only.** Design:
`docs/plans/packet-10-4-history-outreach.md`. No PUT, no
migration, no SQL write until authorised.

**Measured (architect SQL, 7 Sep).** 37 reachable. 20 have
email (all 20 also have a phone). 10 phone-only. 18 no
channel. Of the 20 emails: 8 usable transcript, 12 general
letter. Transcripts are unreliable (wrong-script, garbled
entities, one factually wrong summary). Whisper defect.

**Locked here:** D-E…D-K. D-A restated (20 drafts, not a
blast). D-D narrowed to WhatsApp **API** only.

Three channels, one sender (D-E): email → Gmail Draft,
never sent; whatsapp / linkedin → TEXT on Telegram to
copy. Evidence beside every draft (D-F). Tone by
`source_type` (D-G). Ask from the voice note only (D-H);
four manuals stay off the SELECT. Signature from proposed
`sender_profile`, not `lni_config` (D-I). <CONTACT_3_NAME>: one email
to both addresses, do not merge rows (D-J). Exclude
`<CONTACT_1_EMAIL>` (D-K).

Reuse `Extract draft`. Scene photo auto-attach on email
only (D-B). Voice path untouched (D-C).

**Q1–Q3 LOCKED 14 Sep.** Q1 reversed: evidence on
Telegram only, never in the Gmail body. Q2: three-draft
dry run first, then the rest. Q3: `follow_ups.channel` +
`gmail_draft` + partial unique `(person_id, channel)`.
Migration 031 applied. WF-10 `source=history` is the
build. Do not generate the remaining seventeen without
authorisation.

**Acceptance (docs packet)**

- D-E…D-K written in `masterplan.md`, this packet, the
  plan, `architecture.md`, `workflows.md`, `prd.md` §8b.
- `sender_profile` proposed as 031. 030 stays Phase 6.
  No migration file in this PR.
- Architect answers Q1 Q2 Q3 before the build.

**Acceptance (later build — do not execute here)**

- `Route source` accepts `history`. Re-GET every
  `connection[i]`.
- `Extract draft` is the same node.
- 20 Gmail Drafts, Inbox empty. 10 WhatsApp copy-texts
  on Telegram. No send API.
- Four D-H names absent from the SELECT. `<CONTACT_1_DOMAIN>`
  absent. <CONTACT_3_NAME> one draft, two To: addresses.
- Voice path unchanged. Architect GET of published WF-10.

### Packet 10.4b — BUILD (14 Sep)

Q1–Q3 locked (Q1 reversed: Telegram evidence only).
Migration `031_sender_profile_history` catalog
`20260914060746`. WF-10 history published
`966950f1` accepted; composer `0799a8dd`; C1–C5 now
`<WF10_PUBLISHED_HIST_V4>` (rollback `<WF10_ROLLBACK_DESRAJ>`). 032 HTML signature.
Email batch accepted. <CONTACT_14_NAME> second-touch email
**462598**. Unique index unchanged (sent row
`channel` NULL). CH1–CH5 close Phase 10: <CONTACT_15_NAME> +
<CONTACT_6_NAME> second-channel drafts; `wa.me` from Meta click-
to-chat; LinkedIn people-search + paste note; 
`second_touch` is `draft_state='sent'` only;
033 channel signatures. WF-10 **`<WF10_PUBLISHED_CH5>`**.
Phase 10 closed.

---

## Phase 8 — PWA capture surface

**Timing:** post-LEAP

Next.js PWA sharing the Phase 0 backend. Camera, mic, IndexedDB offline queue,
review UI.

Built after the event on purpose: it will be designed against a database full of
real contacts and real failure patterns, rather than assumptions.

---

## Phase 12 — Multi-tenancy

**Timing:** post-Phase 10. Docs 14 Sep (`docs/plans/phase-12-plan.md`).
Packet **12.0a** locked Q1–Q5. No migration in 12.0 / 12.0a.
030 stays Phase 6. Product name **NIS**; `LNI` is the
legacy internal prefix (D-N).

Launch used one owner. Every user-owned table already
has `owner_id` + RLS. Workflows still resolve that owner
from `events.name = 'LEAP 2026'`. Cron therefore serves
one person. `lni_config.value` is integer — no display
name. **Tenant = `owner_id` (D-L ACCEPTED).** No
`tenants` table. No `tenant_id` column. No `value_text`
on `lni_config`.

`person_emails` and `entity_candidates` rework stay
**inside this phase**, deferred to 12.3 / 12.4. They are
not a reason to start with a migration. Isolation proven
with two real accounts is **12.5**. Login surface is
**12.6**, after that. Permanent test tenant **inert** row is **12.2b-i**
(037, no `bot_state`). Full `bot_state` is still
**12.2b**. Fan-out N>1 is **12.4b**, before 12.5.

### Packet 12.0 / 12.0a — Docs

Plan, D-L…D-O, Q1–Q5 LOCKED. No SQL file. No PUT.

**Acceptance**

- Q1–Q5 locked in the plan. D-L ACCEPTED. D-M D-N D-O
  in `masterplan.md`.
- 034 named, not written. 030 untouched.

### Packet 12.1 — Isolation schema (applied 16 Sep)

Catalog **034_multitenancy_foundation**
(`20260916022806`). 030 still absent. No PUT.

- `lni_settings` live. UNIQUE `(owner_id, key)`. RLS
  `lni_settings_owner_all`. Seed `display_name` for the
  live owner only. Not the platform owner (D-O).
- `lni_instance` live. Not owner-scoped. Singleton
  boolean PK. `name` = NIS. `platform_owner_id` resolved
  by exact email `<PLATFORM_EMAIL>` (009 RAISE
  pattern). SELECT policy `lni_instance_select`.
- `UNIQUE (telegram_user_id)` on `bot_state` added.
  Existing `(owner_id, telegram_user_id)` unique stays.
- assets UNIQUE `(owner_id, telegram_file_unique_id)`
  replaced `assets_telegram_file_unique_id_key`. Counts
  191/191 unchanged. No FK/index dependents on the
  dropped constraint (internal backing index only).
- `lni_config` untouched (integer-only).

WF-01 still `ON CONFLICT (telegram_file_unique_id)`
until 12.2. Do not publish unpublished drafts.

### Packet 12.2 — Owner resolution (applied 16 Sep)

Catalog **035_operator_chat** (`20260916024816`).
WF-00 / WF-07 / WF-08 PUT. WF-01 published still
`<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`. WF-06 published still
`<WF06_PUBLISHED>` / draft `<WF06_DRAFT>`. WF-00 `be1e7b71` (rollback
`<WF00_PUBLISHED>`). WF-07 `9197f7a3` (rollback `<WF07_PUBLISHED_9_14>`).
WF-08 `8b835659` (rollback `<WF08_PUBLISHED>`). Full cross-tenant
isolation is **not** proven (12.5, two real accounts).
Permanent test tenant `bot_state` **did not land** —
packet **12.2b**.

- Fingerprint is `lni_instance` name `NIS`. The string
  `LEAP 2026` is gone from WF-00 / WF-07 / WF-08.
- WF-00 `audit_log.owner_id` = `lni_instance.platform_owner_id`.
  Alert `chat_id` from `lni_settings.operator_chat_id`
  under the platform owner. Not `bot_state`.
- WF-07 `/digest` Load digest `$1` is the **caller**
  `owner_id`. Hourly fan-out lists owners with both
  `bot_state` and `events`; local hour 22 = close, 7 =
  brief. Gmail fail-closed (D-M): mailbox linkage is
  `lni_settings.digest_email` (036). Missing key →
  Telegram only.
- WF-08 Self-identify gates `lni_instance`. Retrieve
  corpus `$1` still the caller `owner_id`.

WF-01 / 02 / 03 / 05 / 06 / 09 / 10 unchanged.
`capture_no` audit stays later.

### Packet 12.2a — `digest_email` (applied 16 Sep)

Catalog **036_digest_email** (`20260916030417`). WF-07
PUT `becd329b` (rollback `9197f7a3`). Load digest looks
up `digest_email` for `$1`. Live owner seeded from
`auth.users.email`. Platform owner not seeded (D-O).
Mailbox linkage until Phase 14 OAuth. N>1 hourly
fan-out blockers filed as **12.4b**. WF-06
Apollo missing-ceiling is already 0; no PUT. WF-01
draft still `<WF01_DRAFT>`. WF-06 draft still `<WF06_DRAFT>`.
`<WF07_ROLLBACK>` is **12.3b**, not 12.2a (71b4049 label smear).

### Packet 12.2b-i — inert test tenant (applied 16 Sep)

Catalog **037_test_tenant** (`20260916033502`). Auth user
`<TEST_TENANT_EMAIL>` resolved by exact email
(009 RAISE). `events` + ceilings + `sender_profile`.
**No `bot_state`.** **No `digest_email`.** Invisible to
`List due owners`, WF-01 allowlist, and every cron. D2d
fixture. Never deleted, never frozen (Q2).

### Packet 12.2b — permanent test tenant `bot_state` (12.8 applied)

The door is **packet 12.8** (`041_tenant2_bot_state`,
catalog `20260917060142`). Live `bot_state` count is
**2**. 0a wait withdrawn: `7c72371f` stays as the
B7 `failed_24h` finding. B1/B2a `row_count=1`
(owner predicate applied). B7 WF-09 **495812**
alerted account 2 only; live owner Silent clean.
Copy pass: user-facing still `LNI watchdog` (D-N).
Do not fix now. B2b gated `want_contact` path
PASS (`row_count=1`, no email in the reply).
B3 `/digest` WF-01 **495886** / WF-07 **495887**:
not silent in n8n (Telegram `message_id` 1074).
`Email skipped` is scheduled-only. STOP before
B4/B5.

### Packet 12.3 — `person_emails` (deferred)

One human, several emails/phones/titles. <CONTACT_3_NAME>
`d2335783` + `ba037ac0` stay two rows until this
exists. Do not merge.

### Packet 12.4 — `entity_candidates` pair storage (deferred)

Stored pair + human-readable reasons. 61 pre-window
pending stay pending. No false `rejected`.

### Packet 12.3b — Kind on demand test affordance (superseded)

WF-07 PUT `<WF07_ROLLBACK>` (rollback `becd329b`). Kind on
demand `source` passed through a caller `schedule` so the
TEST caller could reach Gmail. Hourly tick exec **483097**
proved the scheduled branch without that affordance.
Reverted in 12.4b to literal `call`.

Version chain: `9197f7a3` (12.2) → `becd329b` (12.2a) →
`<WF07_ROLLBACK>` (12.3b) → `<WF07_PUBLISHED>` (12.4b).

### Packet 12.4b — hourly fan-out N>1 (applied 16 Sep)

E1 / E2 / E3 **fixed in 12.4b**. WF-07 PUT `<WF07_PUBLISHED>`
(named rollback `<WF07_ROLLBACK>` before the first 12.4b PUT).
Kind on demand `source` is literal `call`. Scheduled
path processes owners one at a time (`Each owner`
SplitInBatches v3: output 0 done, output 1 loop,
batchSize 1). `Wait both channels` is
`combine` / `combineByPosition` so `Any delivered?`
reads the **current** owner's Telegram
`result.message_id` and Gmail `id` from `$json`.
Scheduled empty / undeliverable writes `audit_log`
(`digest_undeliverable`) and continues. On-demand still
`stopAndError`. N=2 failure isolation proven Hourly
tick exec **483257**. N=2 successful delivery to two
real chats is **not** this packet — that is 12.5.

Same-packet intermediates: `353f649a` (03:49:23) →
`feb5f066` (03:51:57) → `<WF07_PUBLISHED>` (03:53:25). Packet
restore `<WF07_ROLLBACK>` named before the first 12.4b PUT.

### Packet 12.4c — reconcile `<WF07_PUBLISHED>` (docs only)

No PUT. `<WF07_PUBLISHED>` is 12.4b. 04:00Z tick **483309** ran
on it. Packet restore `<WF07_ROLLBACK>` was named before the
first 12.4b PUT; immediate predecessor `feb5f066` was
named before the PUT that created `<WF07_PUBLISHED>`.
Intermediates recorded in docs after the fact.
D3 **483257** status success.

### Packet 12.4e — restore capture unique (applied 16 Sep)

Catalog **038_restore_assets_single_unique**
(`20260916043514`). No PUT. No canvas. Drafts
`<WF01_DRAFT>` / `<WF06_DRAFT>` unpublished.

034 dropped `assets_telegram_file_unique_id_key`.
Published WF-01 Insert asset still infers
`ON CONFLICT (telegram_file_unique_id)` → 42P10.
Capture down since 02:28Z. Architect-caused.

038 re-CREATEs UNIQUE `(telegram_file_unique_id)`
and **keeps** `assets_owner_id_telegram_file_unique_id_key`.
Zero duplicate `telegram_file_unique_id` first (191/191).
Constraint comment: TEMPORARY. Drop in **packet 12.2
remainder** when that packet PUTs WF-01 Insert asset to
`ON CONFLICT (owner_id, telegram_file_unique_id)`.
030 still absent.

STEP 2 live phone (not the report): WF-01 **483617**
success photo Insert asset `57b0e023` stored 91339;
WF-01 **483620** success voice Insert asset `cdccd64e`
stored 16378. assets **191 → 193**.

STEP 3 ON CONFLICT audit (re-released with additions):
7 clauses in published graphs. All 7 parse against a
live unique (rolled-back `EXPLAIN`). Arbiters:
`assets_telegram_file_unique_id_key` (WF-01 Insert
asset), `processing_jobs_enrichment_person_uniq`
(WF-01 Flag enqueue, WF-05 Enqueue enrichment),
`processing_jobs_asset_job_uniq` (WF-02 Enqueue asset
jobs / sweep / closed standard, WF-09 Enqueue orphan
jobs). Zeros: WF-00/03/04/06/07/08/10 plus active
LNI-TEST 10.4b ×2 and NIWL-01. No published
`ON CONSTRAINT`. No SQL naming an index/constraint.
No published graph infers
`assets_owner_id_telegram_file_unique_id_key` or
`bot_state_telegram_user_id_key` (both would parse).
`pg_depend` non-internal on assets/bot_state uniques:
empty. Only FK onto those tables:
`processing_jobs_asset_id_fkey` → `assets(id)` PK.
Unapplied repo file: **012** only —
`ON CONFLICT (owner_id, telegram_user_id)` infers
`bot_state_owner_id_telegram_user_id_key` (034 kept
it). Rule **24** added to `rules.md`. No PUT.

### Packet 12.5a-0 — close WF-10 History webhook (16 Sep)

Severity 1. Rollback **`<WF10_ROLLBACK>`** named before PUT.
Removed unauthenticated `History webhook`
(`POST /webhook/<WF10_HISTORY_PATH>`). One-off Phase 10
kick; no live caller. Path was in **public** LEAP-NI
(not only NIWL). Normalize input no longer falls back
to Self identify `owner_id`. Missing caller `owner_id`
errors. Self identify still returns `owner_id` (C1
waits). Published **`<WF10_PUBLISHED>`**. Rollback
**`<WF10_ROLLBACK>`**. 12.5a C/D/E/G unstarted. No other
workflow.

### Packet 12.5a-0b — close TEST webhooks; Driver ingest cause-only (16 Sep)

Severity 1 first. Two ACTIVE unauthenticated
`LNI-TEST- 10.4b` throwaways (gmail draft attach /
delete drafts) deactivated then **archived** (session
08 pattern: archive, do not delete). Production POST
both 404. **No WF-01 PUT.** Published WF-01 stays
`<WF01_PUBLISHED>`; draft `<WF01_DRAFT>` unpublished.

Cause only on WF-01 `Driver ingest` (GET published
`<WF01_PUBLISHED>`): unauthenticated webhook, wired into
Allowlist beside Telegram Trigger. Allowlist keys off
Telegram-shaped `$json.message.from.id`. Classify
reads `$('Telegram Trigger')`, not Driver ingest.
Default wrapped POST fails allowlist (session-09 exec
**273668**, now pruned). Residual: endpoint still
registered on ACTIVE WF-01. Own PUT, not this packet.

Repo literal audit (all **119** commits, not 31):
README policy **did not hold**. Project ref, workflow
ids, credential ids, owner uuid prefix, and emails
are in tracked docs. n8n host, telegram_user_id,
platform / test-tenant uuids, NIWL header cred: **zero**
in git. No history rewrite. 12.5a C/D/E/G unstarted.
PR #81 unmerged.

### Packet 12.5a-0c — repo scrub plan + close signup (16 Sep)

Signup already disabled (Auth `disable_signup=true`;
anon POST `/auth/v1/signup` → `422 signup_disabled`).
Confirm email still off (`mailer_autoconfirm=true`) —
item 11 remains owner. Do not delete the stray Auth
user (item 10). Public NIWL repo: **zero** n8n host /
webhook base URL in any commit; Vercel function reads
`N8N_WAITLIST_WEBHOOK_URL` from env, browser posts
`/api/waitlist` only. Driver ingest urgency is
instance-local, not NIWL-repo-local.

Scrub: `git-filter-repo --replace-text` **not run**.
Map is gitignored `docs/scrub-map.local.md`. Rule **25**
+ `scripts/check-no-literals.sh` + CI. No force-push.
No WF-01 PUT. 12.5a C/D/E/G unstarted.

### Packet 12.5a-0d — amend map, narrow rule 25, merge #81 (16 Sep)

Map amended: `<CONTACT_N_NAME>` aligned with
`<CONTACT_N_EMAIL>`; company domains / identifying
company names added; longest-first. Rule 25 now two
lists: banned identity/infrastructure, allowed
row-level uuids. Checker dropped the generic uuid
scan. `git-filter-repo` **not run**. No force-push.
No WF-01 PUT. Confirm email still off (item 11).
12.5a C/D/E/G unstarted.

Architect accepts the Phase 12 docs on live
verification. **A2–A4 diffs waived** (architect
decision, recorded in the #81 squash-merge).

### Packet 12.5a-0e — reconcile #81, amend map (16 Sep)

#81 **is merged** (`cd060e1` on `talalbaig1/LEAP-NI`
`main`). Head ref deleted. Open PRs: 0. GitHub still
stores `headRefName=cursor/phase-12-docs-c69e` and the
pre-squash commit list (first two `830b0ea`, `e02bbf0`);
those SHAs are **not** ancestors of `origin/main`.

Map: drop ordinary company-name tokens. Names are
`regex:(?i)\b…\b`. Drop `talalbaig1`. Keep
<CONTACT_4_COMPANY> / <CONTACT_1_COMPANY> / <CONTACT_2_COMPANY>. Count 212.
`git-filter-repo` **not run**. Dry-run is after
architect approval. 12.5a C/D/E/G unstarted.

### Packet 12.5 — Isolation proven (two real accounts)

Two real `bot_state` rows. Depends on 12.2b and 12.4b.

### Packet 12.6 — Login surface (after isolation)

Minimal login: Supabase Auth, Google/Microsoft,
Telegram-ID capture. A Phase 12 **dependency**, landing
**after** 12.5. Isolation before there is a door.
Onboarding must seed `events` (exec 482941) and
ceilings. Owner IU account reserved Phase 14, not
the harness. See phase-12-plan 12.6 E1–E4.

---

## Phase 13 — Enrichment read path

**Timing:** after packet **12.2**, never before. Logged
15 Sep. Architect-owned defect. No SELECT written in
this packet. No PUT.

`enrichment_records` is written by WF-06 and read by
nothing. Verified 15 Sep: **85** rows, **40** real Apollo
person reveals carrying title / seniority / headline /
employment_history, **35** company records. Of **85**
follow-up bodies belonging to an enriched person,
Apollo's title differs from the card title in **75** and
appears in the body in **2**; Apollo's headline appears
in **0**. **18** people carry an Apollo-sourced
`linkedin_url`; overlap with the 10 LinkedIn-channel
draft recipients is **0**.

`/ask` exclusion was **DELIBERATE**
(`docs/plans/phase-06-plan.md`). WF-10 was an
**OMISSION** — no doc line decides it.

Any enrichment SELECT written now would hardcode
single-owner assumptions and become another 12.4 audit
item. `enrichment_records` without an `owner_id`
predicate leaks one tenant's contact intelligence into
another's draft.

Two design rules, locked (also `masterplan.md` §4):

- **D-P** Card is truth; enrichment is context. What the
  draft ASSERTS about a person comes from their card.
  Apollo may be stale or wrong — <CONTACT_33_NAME>'s card
  reads "Solution Specialist", Apollo reads "Connectivity
  Consultant, seniority entry". Enrichment informs the
  composer's brief; it never becomes a sentence claiming
  their title.
- **D-Q** Enrichment surfaces as evidence beside the
  draft in Telegram (D-F), never silently inside a body.

**Out of this log.** Do not write the read path until
12.2 isolation is live.

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
