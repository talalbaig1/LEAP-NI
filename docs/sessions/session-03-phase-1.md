# Session 03 — Phase 1 ingest (packets 1.1–1.3f)

**Date:** 26 August 2026
**Chat purpose:** Phase 1 capture — docs/migrations, WF-02 lifecycle,
WF-01 ingest router, media-path defects through 1.3f.
**Outcome:** Phase 1 core **accepted** by architect read-back (26 Aug 2026
18:10Z). **41 assets, 41 objects, 0 missing, 0 size mismatches, 0
duplicate `file_unique_id`, all `upload_status='stored'`.** PR **#7**
squash-merged to `main` (`306e1b8`). PR **#6** closed as superseded.
WF-01 and WF-02 remain **ACTIVE** on the production bot.

No n8n workflow JSON is committed. Repo stays identifier-free. Live
values live in gitignored `docs/environment.local.md`.

---

## 1. What was achieved

### Packet 1.1 — docs and migrations

Phase 1 schema/docs landed earlier on this line (PR #6 lineage into #7).
Capture table, assets, allowlist, Storage bucket `lni-assets` in use on
the live LEAP-NI project.

### Packet 1.2 / 1.2b — WF-02 capture lifecycle

WF-02 owns `bot_state` and `captures`. Commands `/new` `/done` `/batch`
`/status`. `resolve_target` never rejects: orphan adoption inserts a
capture so media has a home (`prd.md` §4 guardrail 3). Sweep every 5 min,
`Asia/Riyadh`, 10-minute inactivity, `close_reason=auto`.

**This n8n build refuses to publish a parent that calls an unpublished
sub-workflow.** WF-02 had to be **activated first** so WF-01 could
activate. That is a platform constraint, not a preference.

WF-02 **never sends Telegram**. Every send is WF-01, so “if storage
fails, no receipt” is enforced in one place.

### Packet 1.3 — WF-01 ingest router

Telegram trigger → allowlist → self-identify LEAP 2026 → branch
command | photo | voice | document | text | callback. Media path:
duplicate check → `resolve_target` → mint asset → `getFile` `download:
true` → Hash sha256 → Prep → Storage PUT → HEAD → INSERT assets → then
maybe tell the owner.

### Packets 1.3b–1.3f on PR #7 (**merged** `306e1b8`, 26 Aug 2026 18:11Z)

Live REST PUT, names checked first, Leap-NI creds rebound. Public PUT of
`settings.binaryMode` is 400 — GET shows `separate`; do not send it.

---

## 2. The ten defects, in order, and WHY

The single root pattern behind **1, 4, 6, and 8**: a node trusted what
an **upstream node claimed** (empty success item, json-only hash item,
`bin.bytes` metadata, “I can measure this buffer”) rather than what that
node **actually produced**.

| # | Packet | What broke | Why |
|---|---|---|---|
| **1** | 1.3b | Contract payloads read `$json` after Postgres | `Duplicate check` with `alwaysOutputData` emits `{}` on a miss. That looks like success. Downstream took `owner_id` from empty `$json` → WF-02 `malformed_payload` → success NoOp. Three assets lost. **Trusted the previous item instead of the named node that produced the fields.** |
| **2** | 1.3b | Failures were silent NoOps | Under “silence means failure” the owner could not tell a drop from a healthy quiet bot. Failure terminals must `stopAndError` so WF-00 runs (corr + file id only). |
| **3** | 1.3b | Batch did not always INSERT | `resolve_target` in batch must always insert a new `capture_mode=batch` row and must not reuse `open_capture_id`. |
| **4** | 1.3c | Prep forwarded empty binary | Hash sha256 emits a **json-only** item. Prep used `$input.binary` after Hash → Storage PUT “no binary file `data`”. Capture opened, 0 assets. **Trusted the previous item’s binary instead of `$('Telegram getFile').item.binary`.** |
| **5** | 1.3c | Empty-binary gate | Intended to catch defect 4. Only fired on **pinned** fixtures (inline base64). Removed in 1.3e: a gate that only fires on fixtures is worse than none. |
| **6** | 1.3d | `size_bytes` from `bin.bytes` / `fileSize` | Metadata, not the artifact. Pin padding `=` in 1.3c decoded to 14 bytes while metadata claimed 112 — measurement error, not a corrupt upload. Prep measured decoded buffer length. That only works on **inline** pins. |
| **7** | 1.3d | Row written without proving the object | After PUT, HEAD the object. Missing/zero → no INSERT. This Supabase build returns `Content-Length` on HEAD (list not used). Defect 7 was **never reached** on the first real photo because defect 8 threw first. |
| **8** | 1.3e | Prep called `getBinaryStream` on a real download | Real Telegram binary is **filesystem-v2**. Code can **create** filesystem binaries (`prepareBinaryData`, `setBinaryDataBuffer`) but **cannot read** them. Helpers denied: `getBinaryStream`, `binaryToBuffer`, `getBinaryMetadata`, `getBinaryPath`, `createReadStream`; `getBinaryDataBuffer` returns nothing usable. Exec **245200** (real photo, Prep threw). Probe **245231 / 245237**. Pins never hit this branch (inline base64). Prep stopped measuring; it copies named-node binary + sha256 only. |
| **9** | 1.3e | What number is `assets.size_bytes` | HEAD `Content-Length` **is** the stored size — measured from the artifact that survives. Telegram `getFile` `file_size` is an independent **second opinion that must agree**, not the value. Two sources that disagree is a defect; one source you cannot check is a hope. Truncation / missing object → `stopAndError`, no row. |
| **10** | 1.3f | Adoption message not sent (test 4, exec **245471**) | WF-02 SQL computes `adopted`; Compose uses it to fill `reply_text`, then **drops** the field. Documented return contract never had `adopted`. WF-01 `Send adoption?` tested `['true','t',true].indexOf(adopted)` on **undefined**. Photo path skipped. Text path tested the same absent field through **string notEmpty** on a boolean `&&` — the two paths could disagree. **Fix: do not add `adopted` to the contract.** WF-01 sends iff `reply_text` is a non-empty string. WF-02 already returns empty for batch and non-adopted resolves. |

---

## 3. Filesystem-v2 and why pins are not evidence

This instance stores binary as **filesystem-v2** (`data: "filesystem-v2"`
plus a filesystem `id`). Proven:

- Real Telegram download: exec **245200** (`getBinaryStream` not supported
  in the Code node).
- Helper probe: **245231 / 245237** (write works; every read helper
  denies).
- Filesystem-shaped TEST (HTTP `responseFormat: file`, not a pin):
  **245307 / 245335 / 245341**. Happy path sizes all **117383**.

A **pinned** item is inline base64. That is a **different program** from
a real download. Three green pin fixtures preceded three real-device
failures. MCP `test_workflow` also substituted `PLACEHOLDER` (8 bytes)
when a large pin passed through a subagent. Pinned proofs are not
evidence for anything touching binary.

---

## 4. Standing rules recorded this session

In `docs/workflows.md` §1 and `.cursor/skills/lni-n8n-conventions/SKILL.md`:

1. Code must never read filesystem bytes.
2. Pins are not binary evidence.
3. Size is HEAD `Content-Length`; Telegram `file_size` must agree.
4. **WF-02 owns every decision about what the owner is told; WF-01 owns
   only the sending.** `reply_text` non-empty means send; empty means
   stay silent. Do not add a second field that must stay in agreement
   with `reply_text`.
5. `capture_no` is a **number**. n8n Postgres returns bigint as a string
   (`"23"` on 245471). Compose `Number()`s it (245685 returned type
   `number`). Cosmetic today; `/fix <n>` in Phase 2 will parse it.

Named-node rule (defect 1/4): after any Postgres / HTTP / Crypto / Code,
read `$('Named').item…`, never `$json` / `$input` from the previous item.

---

## 5. Live state after architect acceptance

- **41 assets / 41 Storage objects.** 0 missing, 0 size mismatches, 0
  duplicate `telegram_file_unique_id`, every row `upload_status='stored'`.
- **Test 13 was not a dedup miss.** Capture #51 has two assets that
  differ in bytes and sha256. Telegram re-compresses on gallery
  re-upload, so `file_unique_id` differs and both rows are correct. No
  fix needed.
- WF-01 **ACTIVE**, 57 nodes. `Send adoption?` / `Send note adoption?`
  are `reply_text` notEmpty only.
- WF-02 **ACTIVE**, 39 nodes. Compose uses `adopted` internally to build
  `reply_text`; the return object does not include `adopted`.
- Capture **#9**: `processing` / `close_reason=auto`. Kept.
- Captures **#21–#31** and later real-device evidence: kept.
- PR **#7** merged. PR **#6** closed (superseded; its commits were
  ancestors of #7; merging it would have reverted 1.3b–1.3f docs).
  Feature branches deleted. `origin` heads: `main` only.

### 1.3f proofs (then deleted)

Exec **245685** on disposable `LNI-TEST-13f-reply-text`:

- Nothing open → `reply_text` =
  `Opened capture #32 (nothing was open — adopted)`
- Capture open → `reply_text` = `""`
- Batch `resolve_target` → `reply_text` = `""`

Deleted: TEST workflow (GET-name then DELETE, 404 after); throwaway
captures **#32** and **#33** (no assets). Did not touch #9 or #21–#31.

---

## 6. What remains

### Owner actions

- Hard-delete archived orphans `kMozml08Q10ojVmx` and `bvXpsnMJ2FH7PE7X`
  in the UI (MCP archives; it does not hard-delete). Still open from
  Phase 0.
- Do not deactivate WF-01 or WF-02. Do not restart n8n. Do not touch
  ElderWise. For multiple cards at LEAP: use `/batch` (proven working).

### Implementation remaining

- **Packet 1.4 album auto-detect is NOT built.** Interim rule stands:
  album members attach individually to the open capture. Nothing is
  lost, but **20 album photos WILL fuse into one capture**, which
  `prd.md` §4 forbids. Workaround for LEAP: use `/batch` for multiple
  cards — proven working.
- **WF-01 and WF-02 remain ACTIVE on the production bot.**
- WF-03 processors (Phase 2). `/fix <n>` will need numeric `capture_no`.
- Criteria 4–11 in `prd.md` §10 (extraction, Arabic, album prompt,
  digests, watchdog). Criterion 2 (20 consecutive captures, 100%
  preservation) **passed**.
- 29 August gate unchanged: Phases 2–3 still have to land before the
  event.

---

## 7. Corrections to earlier assumptions

- “Green TEST = media path works” was false three times. Pins and Code-
  embedded JPEG are not the filesystem-v2 program Telegram uses.
- Measuring in a Code node is impossible here; HEAD after PUT is the
  measurement.
- Adding `adopted` to the WF-02 contract would re-create defect 10 the
  next time Compose and WF-01 drift. Empty vs non-empty `reply_text` is
  the single channel.
- Public n8n PUT rejects `binaryMode`; GET still shows `separate`. Do
  not send the field. Do not set `$env`.
