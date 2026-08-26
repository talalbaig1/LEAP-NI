# masterplan.md

**LEAP Networking Intelligence (LNI)**
Version 2.0 · 26 August 2026 · Owner: Talal Baig
Architect/verifier: Claude · Implementer: Cursor

**Document set:** `masterplan.md` (this) · `architecture.md` · `phases.md` ·
`prd.md` · `workflows.md` · `rules.md`

> **Documentation precedes implementation.** No code, migration, or workflow is
> written before the relevant document reflects the change. See `rules.md` §1.

---

## 1. Mission

Turn business-card photos, event photos, and voice notes captured at LEAP 2026
into durable, searchable, structured records of people, companies,
conversations, and follow-up actions — with enough intelligence to change how
the owner spends each remaining day of the event.

**Not** a CRM. A capture-and-recall system whose output happens to be a
relational database.

---

## 2. Verified event facts

Confirmed against the official LEAP FAQ, 25 August 2026.

| Fact | Value |
|---|---|
| Dates | **31 August – 3 September 2026** |
| Venue | Riyadh Exhibition & Convention Centre, Malham |
| Visitor hours | **1:00 PM – 9:00 PM** daily (12:00 PM selected passes) |
| Scale | ~200,000 attendees, 1,800+ exhibitors |
| Timezone | `Asia/Riyadh` (UTC+3) |

**Two consequences drive everything:**
1. Capture must be live before 30 August.
2. Mornings are free. Review, digest, and reconciliation are morning activities.

---

## 3. The core architectural bet: replayability

**Only capture has a real deadline.**

If raw assets are stored faithfully — card image, audio file, photo, typed note,
timestamp, event, grouping — then every downstream layer (OCR, transcription,
extraction, entity resolution, enrichment, RAG, CRM) can be re-run against that
raw data at any future point with no loss. A voice note captured on 31 August
can be processed by a better pipeline on 20 September and produce a strictly
better record.

All deadline pressure therefore collapses onto one component.

**Corollary 1.** No phase may ever compete with capture reliability. If later
work threatens capture stability, the later work loses.

**Corollary 2.** User corrections are *not* replayable — they are irreplaceable
human input. Corrections are stored separately from model output and are never
overwritten by a re-run.

**Corollary 3 (degraded mode).** If extraction is broken on 31 August, capture
still runs and jobs queue for later replay. Raw assets landing in storage with a
timestamped row is, by itself, a successful event.

---

## 4. Locked decisions

Fourteen decisions, settled 25 August 2026. **Do not reopen without a documented
reason and a document update first.**

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Capture surface | Telegram now, PWA later | Telegram's outbox already solves offline queueing, retry-on-reconnect, camera, mic, albums. A hand-rolled IndexedDB queue tested for two days does not. |
| 2 | AI stack | OpenAI; OCR engine by benchmark | OpenAI credentials already proven in n8n. Card reading is a layout problem, not a document problem. |
| 3 | Database home | New dedicated Supabase project | ElderWise is live with real users. Total blast-radius isolation for ~15 min of wiring. |
| 4 | Capture grouping | Explicit `/new` … `/done` + guardrails | Owner's choice; guardrails neutralise the forgotten-`/done` failure. |
| 5 | Bulk entry | `/batch` **and** album auto-detect | Evening reconciliation of a pocket of cards is the real high-volume pattern. |
| 6 | Notification | Silent unless rule-based flag; receipt on `/done` | Owner's choice. A receipt is not a review card — it proves the pipeline is alive. |
| 7 | Data model | Fully normalized at launch | Retrofitting onto 800 hand-corrected flat rows is days of work and risks losing edits. |
| 8 | Enrichment | Company-first auto, person on demand | 1 credit per match. Six people from one company = 1 credit, not 6. |
| 9 | Primary surface | Telegram-native; dashboard later | 1–9 PM the owner is standing, one hand free. A dashboard is a laptop surface. |
| 10 | Digests | 10 PM close + 7 AM briefing + `/digest` | Evening = operational health. Morning = actionable intelligence while the event still runs. |
| 11 | Retention | Indefinite + real per-contact delete | Owner's choice. Delete capability is what makes indefinite defensible. |
| 12 | Follow-up | Draft-only + visible prioritisation | Auto-send to a mis-extracted address is an unrecoverable loss for a two-second saving. |
| 13 | Pre-event scope | Phases 0–3 committed; 4 gated on 29 Aug | Enrichment works identically on 5 September. Capture does not. |
| 14 | Implementation split | Cursor implements incl. n8n; Claude verifies by read-back | Author and verifier must be different parties or the check is theatre. |

### Where the owner overrode the recommendation

- **#4** — Claude recommended reply-threading. Owner chose `/new`…`/done`.
  Accepted; four guardrails added (`prd.md` §4).
- **#6** — Claude recommended a confirmation card per capture. Owner chose
  low-confidence-only. Accepted; a bare receipt and rule-based flagging added
  (`prd.md` §5).
- **#11** — Claude recommended 12-month raw retention. Owner chose indefinite.
  Accepted; per-contact delete promoted to a real feature.

---

## 5. Verified environment facts

Checked directly, 25 August 2026. **Re-verify if stale.**

> **Placeholder convention.** This repository is public. Host names, project
> refs, workflow IDs, and account IDs appear here as `<PLACEHOLDERS>`. The real
> values live in `docs/environment.local.md`, which is gitignored. None of them
> are credentials, but published together they are a reconnaissance package —
> and a live production system with real users' health data sits behind the same
> n8n host. Keep it that way: **never commit a literal identifier.**

### n8n — `<N8N_HOST>` (52 workflows)
- **OpenAI credential live and proven.** `@n8n/n8n-nodes-langchain.openAi` for
  Whisper (`resource: audio, operation: transcribe`) and `gpt-4o-mini` at
  `temperature: 0`.
- **Supabase pattern established.** Postgres node with parameterised
  `queryReplacement`; Storage via raw REST with `httpHeaderAuth`,
  `x-upsert: true`, deterministic paths.
- **Error-workflow discipline in place.** `errorWorkflow: <ERROR_WF_ID>`,
  `executionTimeout: 300`, `ON CONFLICT` idempotency on media IDs, explicit NoOp
  terminal branches. **Copy this.**
- Existing ElderWise Supabase project: `<ELDERWISE_PROJECT_REF>` — **LNI must not
  touch it.**
- **WhatsApp Business API is live** but is
  committed to ElderWise's inbound router and permanent Meta callback URL. This
  is *why* LNI uses Telegram: channel isolation, not approval delay.
- ⚠️ **Known trap.** ElderWise WF-5 hardcodes `language: "en"` on the Transcribe
  node. **Never copy this into LNI.** Forcing English decoding on Arabic or
  code-switched audio yields confident garbage rather than an error.

### Apollo.io — Talal Baig
| Credit type | Remaining |
|---|---|
| Lead / enrichment | **175** |
| Direct dial | 160 |
| AI | 5,000 |
| Export | **0** |

`waterfall_email_enabled: false` · `waterfall_phone_enabled: false`

### Other connected services
Gmail, Google Calendar, Google Drive, Notion, Supabase, Tavily, Canva, Context7,
Fireflies, LinkedIn, Twilio, HeyGen.

---

## 6. Roadmap summary

Full detail in `phases.md`.

| Phase | Contents | Timing |
|---|---|---|
| 0 | Foundation: Supabase project, schema, RLS, storage, bot, credentials, error handler | 26 Aug |
| 1 | Capture path | **Live 30 Aug** |
| 2 | Extraction | **Live 30 Aug** |
| 3 | Digests, `/ask`, watchdog | **Live 30 Aug** |
| 4 | Enrichment | Stretch, gated 29 Aug |
| 5 | Web dashboard | Post-LEAP |
| 6 | pgvector RAG | Post-LEAP |
| 7 | Follow-up drafting | Post-LEAP |
| 8 | PWA capture surface | Post-LEAP |

**The 29 August gate.** If Phases 0–3 are not passing on the owner's actual
phone with real cards, all feature work stops and 30 August is spent hardening.

---

## 7. Assessment of the superseded v1 plan

Recorded so the reasoning isn't lost.

**Alignment: ~90%.** Engineering judgment was sound — asset-first processing,
Postgres as source of truth, no biometrics, no silent merges. All retained.

**Speed: not feasible as written.** v1 specified a production system, not a
sprint. Phase 0+1 was realistically 5–8 engineer-days against a 6-day window.
The custom PWA alone was 3–5 days and was the component most likely to fail
silently in a hall with 200,000 people on shared wifi.

**Gaps found:** no bulk capture path despite a stated 100–1,000 contact volume;
Arabic named once and never designed for; no AI cost ceiling; consent framing
assumed recording *other people* rather than self-dictation; no total-failure
fallback.

---

## 8. Open items

| # | Item | Owner | Status | Blocks |
|---|---|---|---|---|
| 1 | Create Telegram bot via BotFather, supply token | Talal | **DONE** — credential `Leap-NI` in n8n. Token not yet proven on a real chat. | — |
| 2 | Create new Supabase project, paid tier (~2 GB) | Talal | **DONE** — project `LEAP-NI`, `eu-central-1`, Pro, Postgres 17.6. Migrations `001`–`008` applied. `009` seed blocked until the owner Auth user exists. | — |
| 3 | Owner `telegram_user_id` for the WF-01 allowlist | Talal | Open | Phase 1 |
| 4 | Photograph 8–10 representative cards + 2 code-switched voice notes | Talal | Open | Phase 2 benchmark, by 29 Aug |
| 5 | Top up Apollo to ~750 credits (add ~575) | Talal | Open | Phase 4 |
| 6 | Confirm whether anyone else needs access | Talal | Open | — (schema already supports) |
| 7 | Create owner Auth user on LEAP-NI | Talal | Open | Migration `009` seed; `owner_id` is resolved from `auth.users` and must fail loudly if none exist |
| 8 | Create second authenticated test user on LEAP-NI | Talal | Open | Phase 0 RLS proof: test user must read zero rows and cannot list/download `lni-assets` |

### Apollo credit budget

| Scenario | Contacts | Distinct companies | Flagged people | Credits |
|---|---|---|---|---|
| Conservative | 200 | ~150 | ~30 | ~180 |
| **Expected** | **350** | **~250** | **~55** | **~305** |
| Heavy | 500 | ~350 | ~90 | ~440 |
| Post-event depth | — | — | — | +150 |

**Plan around 350 contacts.** 1,000 cards across four 8-hour days is one card
every two minutes without pause, which nobody achieves. 40–80/day is
aggressive-but-real.
