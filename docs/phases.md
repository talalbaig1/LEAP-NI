# phases.md

**LEAP Networking Intelligence (LNI)** · Version 2.0 · 25 August 2026

Companion to `masterplan.md`. Each phase is built in **its own new chat window**
(`rules.md` §2).

> **Documentation precedes implementation.** A phase does not begin until this
> document reflects its scope. See `rules.md` §1.

---

## Timeline

| Date | Target |
|---|---|
| 25 Aug | Phase 0 — foundation |
| 26–27 Aug | Phase 1 — capture |
| 27–28 Aug | Phase 2 — extraction |
| 28–29 Aug | Phase 3 — digests, `/ask`, watchdog |
| **29 Aug** | **GATE: 0–3 green on real phone with real cards** |
| 30 Aug | Phase 4 if green, otherwise hardening |
| **31 Aug** | **LEAP day 1** |
| 31 Aug – 3 Sep | Event operations |
| Sep onward | Phases 5–8 |

**The 29 August gate is binding.** If Phases 0–3 are not passing on the owner's
actual phone with real cards, all feature work stops and 30 August is spent
hardening. Phase 4 is never allowed to compete with Phase 1 reliability.

---

## Phase 0 — Foundation

**Timing:** now · **Blocking:** everything

### Scope
- New dedicated Supabase project, paid tier, ~2 GB storage headroom
- Complete schema from `architecture.md` §4, via numbered forward-only
  migrations — **including tables belonging to later phases**
- RLS enabled on every user-owned table
- Private storage bucket `lni-assets` with owner-scoped path policy
- Telegram bot registered via BotFather; token stored as an n8n credential
- n8n credentials wired: Supabase Postgres, Supabase Storage (`httpHeaderAuth`),
  Telegram
- WF-00 central error handler, set as `errorWorkflow` on all LNI workflows
- Read-only credential-check workflow proving Postgres query **and** Storage
  bucket listing both succeed

### Definition of done
- Migrations apply cleanly against an empty project, in order, no errors
- A second authenticated test user reads zero rows from every table and cannot
  list or download any object in `lni-assets`
- Duplicate `telegram_file_unique_id` insert fails
- LEAP 2026 seed row present with timezone `Asia/Riyadh`
- Nothing created or altered in the ElderWise project

### Verification (architect, by read-back)
1. Read live schema — every table present with stated columns and types
2. `rowsecurity = true` confirmed via `pg_tables` / `pg_policies`, **not** by
   reading the migration file
3. Bucket confirmed private; policy references `auth.uid()` as first segment
4. `assets.telegram_file_unique_id` carries a real UNIQUE constraint
5. Seed row timezone correct
6. ElderWise untouched

---

## Phase 1 — Capture path

**Timing:** 26–27 Aug · **Must be live 30 Aug** · **This is the launch release**

### Scope
- WF-01 ingest router: Telegram → Storage → Postgres
- Commands `/new`, `/done`, `/batch`, `/status`
- Album auto-detect with inline "separate people or one person?" prompt
- Four guardrails (`prd.md` §4)
- Bare receipt on `/done`
- Idempotency on `telegram_file_unique_id`

### Definition of done
- Photo, voice note, and typed note each capture independently
- `/new` implicitly closes a previously open capture
- Media arriving with no open capture opens one silently and says so
- Inactivity auto-close fires and stamps `close_reason = auto`
- Album of 20 images prompts once, never fuses silently
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
- WF-03 asset processors: card vision → JSON, Whisper audio
- WF-04 structured extraction against the versioned contract
- WF-05 entity resolution — suggest only
- Normalized writes to `people`, `companies`, `person_companies`,
  `interactions`
- Rule-based flagging
- `field_corrections` on `/fix`
- **Provider benchmark**

### Definition of done
- Benchmark run on 8–10 real cards across GPT-4o, Gemini, Mistral OCR; winner
  chosen on **measured field-level accuracy**, recorded in this repo
- `language` unset on the transcription node — verified in the live JSON
- Arabic name preserved in `name_original_script`
- A card plus a 30-second voice note produces a reviewable record within
  2 minutes
- Raw vision output, transcript, and structured output all traceable from one
  capture
- No auto-merge occurs on name similarity alone
- `/fix` writes to `field_corrections` and does **not** overwrite model output
- Failed provider calls retry, then land in a visible `failed` state without
  creating duplicate people

---

## Phase 3 — Digests, query, watchdog

**Timing:** 28–29 Aug · **Should be live 30 Aug**

### Scope
- WF-07 digests: 10 PM close, 7 AM briefing, `/digest` on demand
- WF-08 `/ask` natural-language query
- WF-09 stuck-job watchdog

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

**Timing:** 30 Aug **only if Phases 0–3 are green on 29 Aug** · otherwise post-event

### Scope
- WF-06: Apollo company enrichment by domain
- `/flag` triggering person enrichment
- Credit guard with daily ceiling and `credit_ledger`
- Tavily fallback on no-match

### Definition of done
- Company enrichment fires automatically on domain availability
- Person enrichment fires **only** on `/flag`
- Credit ceiling proven to hold under a forced retry loop
- `credit_ledger` total reconciles against Apollo's reported balance
- Tavily results labelled `provider = 'tavily'`, never conflated with Apollo data

**Deferring this costs nothing.** Company enrichment on a contact captured on
31 August works identically on 5 September. The data is already in the building.

---

## Phase 5 — Web dashboard

**Timing:** post-LEAP

Next.js on Vercel. Tables, filters, bulk review, merge tooling with visible
scores and reasons, per-contact delete, export.

Better for waiting: designing review queues against 350 real captured records
beats designing them against imagined ones.

---

## Phase 6 — RAG

**Timing:** post-LEAP

pgvector, hybrid keyword + vector retrieval, citations back to source
interactions, owner-scoped filters.

Embed **approved interaction summaries, notes, and approved entity data** — not
raw media. Answers must state when evidence is weak rather than confabulate.

Deferred deliberately: a few hundred rows fit comfortably in a model's context,
so `/ask` needs no vector store at launch. Vectors earn their place when the
corpus outgrows the context window.

---

## Phase 7 — Follow-up and prioritisation

**Timing:** post-LEAP

Prioritisation scoring with **visible factors** — no opaque AI scores. Gmail
draft generation referencing what was actually discussed. Reminders and due
dates.

**Draft-only, enforced.** A mis-extracted address plus auto-send puts a warm,
specific message about a private conversation into the wrong inbox at the right
company. That is not a bug you fix; it is a relationship lost without knowing
why.

**LinkedIn:** store and resolve profile URLs only. Automating connection
requests or messages violates LinkedIn's terms and the realistic outcome of bulk
automation is a restricted account.

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
