# Session 01 — Architecture & Decisions

**Date:** 25 August 2026
**Chat purpose:** Review the v1 plan, interrogate assumptions, lock decisions,
produce the Phase 0 handover.
**Outcome:** All 14 architectural decisions locked. Master Plan v2 produced.
**No code was written in this session.** Implementation begins in the Phase 0 chat.

---

## 1. What was discovered

### Verified by direct inspection — treat as fact

**LEAP 2026 (web, official FAQ):**
- 31 August – 3 September 2026, Riyadh Exhibition & Convention Centre, Malham.
- Visitor hours **1:00 PM – 9:00 PM** daily (12:00 PM selected pass holders).
- v1's date assumption was correct. Mornings are free → review window.

**n8n instance `<N8N_HOST>` — 52 workflows:**
- Owner runs a substantial production system (ElderWise) on this instance.
- **OpenAI credential live and proven**: `@n8n/n8n-nodes-langchain.openAi` for
  Whisper transcription and `gpt-4o-mini` at `temperature: 0`.
- **Supabase integration pattern established**: Postgres node with
  parameterised `queryReplacement`; Storage via raw REST with `httpHeaderAuth`
  and `x-upsert: true` on deterministic paths.
- Existing ElderWise Supabase project ref: `<ELDERWISE_PROJECT_REF>`.
- **Error-workflow discipline already in place**: `errorWorkflow:
  <ERROR_WF_ID>`, `executionTimeout: 300`, `ON CONFLICT` idempotency keyed on
  `media_id`, explicit NoOp terminal branches. Worth copying wholesale.
- Workflows tagged `aiBuilderAssisted: true, builderVariant: mcp`.

**Apollo.io (Talal Baig):**
- Lead credits: **175**. Direct dial: 160. AI: 5,000. Export: **0**.
- `waterfall_email_enabled: false`, `waterfall_phone_enabled: false`.
- This is the binding constraint on enrichment design.

### Corrections made to earlier claims

**Claude was wrong about WhatsApp.** Claude asserted a WABA would need Meta
approval unattainable in six days. Inspection showed the owner already runs a
live WhatsApp Business API integration (phone number ID `<WABA_PHONE_ID>`,
WF-2 owning a permanent Meta callback URL). The Telegram recommendation still
stands, but on a *different* and stronger basis: that number and its single
webhook belong to ElderWise, so sharing it would couple two products' routing
and blast radius. **Lesson: verify before asserting.**

### Live issue found (unrelated to LNI)

**ElderWise WF-5 hardcodes `language: "en"`** on the Transcribe node. May be
deliberate for ElderWise. **Must not be copied into LNI** — forcing English
decoding on Arabic or code-switched audio produces confident garbage rather than
an error. Flagged to owner.

### Assessment of the v1 plan

- **Alignment: ~90%.** Content and engineering judgment were sound —
  asset-first processing, Postgres as source of truth, no biometrics, no silent
  merges. All retained in v2.
- **Speed: not feasible as written.** v1 specified a production system, not a
  sprint. Phase 0+1 was realistically 5–8 engineer-days against a 6-day window;
  the custom PWA alone was 3–5 days and was the component most likely to fail
  silently in a hall with 200,000 people on shared wifi.
- **Gaps found in v1:** no bulk/batch capture path despite a stated 100–1,000
  contact volume; Arabic named only once and never designed for; no AI cost
  ceiling; consent framing assumed recording *other people* rather than
  self-dictation; no total-failure fallback.

---

## 2. Decisions locked (14)

| # | Question | Decision |
|---|---|---|
| 1 | Capture surface | Telegram now, PWA as later phase |
| 2 | AI stack | OpenAI; OCR engine decided by benchmark, not reputation |
| 3 | Database home | New dedicated Supabase project |
| 4 | Capture grouping | Explicit `/new` … `/done`, plus 4 guardrails |
| 5 | Bulk entry | `/batch` **and** album auto-detect |
| 6 | Post-processing notification | Silent unless rule-based flag; bare receipt on `/done` |
| 7 | Data model | Fully normalized at launch |
| 8 | Enrichment | Company-first automatic, person on demand |
| 9 | Primary surface | Telegram-native; dashboard is a later phase |
| 10 | Digests | 10 PM close + 7 AM briefing + `/digest` |
| 11 | Retention | Indefinite, with real per-contact delete |
| 12 | Follow-up | Draft-only + visible prioritisation |
| 13 | Pre-event scope | Phases 0–3 committed; Phase 4 gated on 29 Aug |
| 14 | Implementation split | Cursor implements incl. n8n; Claude verifies by read-back |

### Where the owner overrode the recommendation

- **#4:** Claude recommended reply-threading; owner chose `/new`…`/done`.
  Accepted; four guardrails added so a forgotten `/done` cannot lose or
  mis-attribute data.
- **#6:** Claude recommended a confirmation card per capture; owner chose
  low-confidence-only. Accepted; two adjustments added — a bare receipt on
  `/done` (pipeline liveness proof, not a review prompt), and rule-based
  flagging replacing unreliable model self-reported confidence.
- **#11:** Claude recommended 12-month raw retention; owner chose indefinite.
  Accepted; per-contact delete promoted to a real feature.

### Where Claude declined a capability deliberately

Claude has **write** access to n8n via MCP and could build the workflows
directly. It declined: if Claude authors and then verifies, the verification is
theatre, and the failures most likely to be missed are the ones Claude built in.
Cursor implements; Claude verifies by independent read-back.

---

## 3. Key architectural insight established

**Only capture has a real deadline.** If raw assets are stored faithfully,
every downstream layer replays against them at any future date with no loss. All
deadline pressure therefore collapses onto capture reliability alone;
extraction, enrichment, RAG, and CRM can be built properly after the event.

Corollary: no phase may compete with capture reliability.
Second corollary: user corrections are *not* replayable and must never be
overwritten by a re-run.

---

## 4. What remains

### Immediate — Phase 0 (next chat)
Supabase project creation, full schema + RLS + storage buckets, Telegram bot
registration, n8n credential wiring, WF-00 error handler.

### Owner actions (blocking or near-blocking)
1. **Create Telegram bot via BotFather**, supply token — blocks Phase 1.
2. **Create the new Supabase project**, likely on a paid tier (~2 GB storage).
3. **Top up Apollo to ~750 credits** (add ~575) — needed before Phase 4.
4. **Photograph 8–10 representative business cards** (Arabic-only, bilingual,
   glossy, dark, embossed, bad angle) + record 2 code-switched voice notes —
   these are the OCR benchmark inputs, needed before 29 Aug.
5. Confirm whether anyone else needs access (schema supports it; launch is
   single-owner).

### Later phases
5 (dashboard), 6 (pgvector RAG), 7 (follow-up drafting), 8 (PWA).

---

## 5. Standing rules for all subsequent chats

1. **Each phase is built in its own new chat window.**
2. Every chat ends with a handover prompt **and** a complete `session.md`.
3. **Verification is by read-back, never by report.** Claude reads live schema
   and live workflow JSON through its own MCP connections.
4. **Troubleshooting protocol:** Claude asks Cursor to explain the cause first.
   Only once the cause is understood does Claude instruct a fix.
5. Provider choices are settled by benchmark, not by reputation.
6. Never copy `language: "en"` into any transcription node.
7. All cron schedules explicitly pinned to `Asia/Riyadh`.
