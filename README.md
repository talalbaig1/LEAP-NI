# LEAP Networking Intelligence (LNI)

Capture-and-recall system for LEAP 2026 (Riyadh, 31 Aug – 3 Sep 2026).
Business-card photos, event photos, and voice notes become durable, searchable,
structured records of people, companies, conversations, and follow-up actions.

**Owner:** Talal Baig · **Architect/verifier:** Claude · **Implementer:** Cursor

---

## The one rule that governs everything

> **Documentation precedes implementation.**
> Update the document first. Implement second. No exceptions, including fixes
> and "small" changes. See [`docs/rules.md`](docs/rules.md) §1.

An undocumented change made under pressure is how a document set rots into
fiction — and a fictional document set is worse than none, because it produces
confident wrong decisions.

---

## Document set

| Document | Contains |
|---|---|
| [`docs/masterplan.md`](docs/masterplan.md) | Mission, the replayability bet, 14 locked decisions, verified environment facts, roadmap, open items |
| [`docs/architecture.md`](docs/architecture.md) | System design, data model, storage, AI contracts, security, failure/rollback |
| [`docs/phases.md`](docs/phases.md) | Phase 0–8 scope, definitions of done, gates, verification |
| [`docs/prd.md`](docs/prd.md) | User, jobs to be done, command surface, feedback model, acceptance criteria |
| [`docs/workflows.md`](docs/workflows.md) | Every n8n workflow spec, WF-00 → WF-09, plus instance conventions |
| [`docs/rules.md`](docs/rules.md) | Operating protocol, roles, verification, troubleshooting, standing technical rules |

**Which document to update for which change** — see `docs/rules.md` §1.

Session logs live in [`docs/sessions/`](docs/sessions/). Each phase is built in
its own chat window and ends with a handover prompt plus a session log.

---

## Core architectural bet

**Only capture has a real deadline.** If raw assets are stored faithfully, every
downstream layer — OCR, transcription, extraction, entity resolution,
enrichment, RAG, CRM — replays against them at any future date with no loss.

All deadline pressure therefore collapses onto one component. No phase may ever
compete with capture reliability.

---

## Status

| Phase | Contents | State |
|---|---|---|
| 0 | Foundation: Supabase, schema, RLS, storage, bot, error handler | Not started |
| 1 | Capture path — **launch release** | Not started |
| 2 | Extraction | Not started |
| 3 | Digests, `/ask`, watchdog | Not started |
| 4 | Enrichment | Gated on 0–3 green by 29 Aug |
| 5–8 | Dashboard, RAG, follow-up, PWA | Post-LEAP |

---

## Security note

This repository is **public**. Host names, project refs, workflow IDs, and
account IDs appear as `<PLACEHOLDERS>`. Real values belong in
`docs/environment.local.md`, which is gitignored.

**Never commit a literal identifier, key, token, or connection string.**
