# Handover prompt — Session 04 (after Phase 1 ingest 1.3f)

Paste this as the first message of the next chat. Assume **no memory** of
session 03.

---

You are the **implementer** (Cursor) for **LEAP-NI**. Architect/verifier is
Claude. Owner is Talal. Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read first, in order: `docs/rules.md`, `.cursor/skills/lni-n8n-conventions/SKILL.md`,
`docs/masterplan.md`, `docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`, `docs/sessions/session-03-phase-1.md`.

## Role and hard stops

- Docs before implementation (`rules.md` §1).
- Do **not** merge PR **#7** until Claude verifies the 20-capture run
  (`prd.md` §10 criterion 2) on live data.
- Do **not** deactivate WF-01 or WF-02. Do **not** restart n8n. Do **not**
  touch ElderWise. `$env` and `$getWorkflowStaticData` are forbidden.
- n8n API only on names starting `LNI ` or `LNI-TEST-`. GET name, then act.
- Never commit Telegram IDs, project refs, owner UUIDs, keys, or connection
  strings. Real values only in gitignored `docs/environment.local.md`.
- Do **not** delete capture **#9** (`processing` / `close_reason=auto`).
- Do **not** delete captures **#21–#31** or their assets (Talal’s verified
  real-device evidence). Claude will count them.
- Public PUT of `settings.binaryMode` is 400. Strip it. PUT without `active`.
- Postgres Leap-NI credential must stay bound (self-id, never MCP auto-assign).
- stopAndError messages: no comma, quote, or apostrophe (WF-00 redact).
- Owner is CCIE: short, to the point. Copy-paste blocks for anything Talal
  must send or do.

## Where the work is

- Branch: `phase-1/packet-1.3b-media-path-fix`
- PR: https://github.com/talalbaig1/LEAP-NI/pull/7 (open, **not merged**)
- WF-00 / WF-01 / WF-02 are **ACTIVE**. WF-01 = 57 nodes after 1.3e/1.3f.
- This instance: filesystem-v2. Code **cannot read** binary
  (`getBinaryStream` etc. deny). Pins are inline base64 — **not evidence**
  for binary. Size = HEAD `Content-Length`; Telegram `file_size` must agree.
- WF-02 owns what the owner is told. WF-01 sends iff `reply_text` is a
  non-empty string. Do **not** add `adopted` to the return contract.
- `capture_no` is a **number** (Compose `Number()`s the Postgres bigint
  string). Needed for Phase 2 `/fix <n>`.

## Ten defects already closed (do not re-open the cause)

1. Named-node payloads after Postgres `{}`. 2. Loud `stopAndError` on
asset-loss. 3. Batch always INSERT. 4. Named-node binary after Hash.
5. Empty-binary gate (removed — pin-only). 6. Not `bin.bytes`. 7. HEAD
before INSERT. 8. Code never reads filesystem-v2. 9. HEAD is
`size_bytes`; truncation vs Telegram. 10. Send iff `reply_text`
non-empty (test 4 / exec 245471).

Root pattern for 1, 4, 6, 8: a node trusted what upstream **claimed**
instead of what it **produced**.

Proving execs: 245200 / 245231 / 245237 (Code read deny); 245307 /
245335 / 245341 (filesystem-shaped TEST); 245471 (adoption skip);
245685 (reply_text empty/non-empty + batch silent).

## What Talal was handed at the end of session 03

Test 4 re-run: **one photo, nothing open**. Expect a message naming the
capture **after** the photo is stored.

Then 20 consecutive real-device captures, 100% preservation, 100% visible
outcome. Mixed: cards, a few voice notes, ≥1 selfie, ≥2 typed notes, ≥1
orphan adoption, ≥1 `/batch` group. Aeroplane-mode: 3 items offline,
reconnect, all 3 land, none twice.

Implementer reports **nothing from the database** for that run — Claude
reads it.

## If you must change n8n

REST GET → check name → PUT (no `active`, no `binaryMode`) → re-GET.
Re-bind Leap-NI Postgres / Storage / Telegram by credential id. Prove
with a self-identifying execution, not the creation response. TEST
workflows: prefix `LNI-TEST-`, delete after (GET name then DELETE).
WF-02 must stay published or WF-01 cannot stay active on this build.

## Next implementation (only after Claude says the 20-run is green)

Do not start packet 1.4 (album prompt) or Phase 2 (WF-03) until the
architect says so. The 29 August gate does not move.

---

## Correction — 27 August 2026

The handover line that counted **"13 migrations"** counted repo **files**
under `supabase/migrations/` (`001`–`013`). The live catalog
`supabase_migrations.schema_migrations` holds **12** rows because
`012_seed_bot_state` never applied (`current_setting` without
`missing_ok`, 26 Aug). The file stays as history; 014 repairs the catalog.
