# Session 05 — Phase 3 digests, /ask, watchdog (packets 3.1–3.14)

**Date:** 27 August 2026
**Chat purpose:** Phase 3 — WF-07 digests, WF-08 `/ask`, WF-09 watchdog,
then close.
**Outcome:** Phase 3 **closed**. WF-07, WF-08 and WF-09 are built,
**ACTIVE**, and proven with real data. PR **#23** is the last merge
vehicle (vcard decline + QR A6 wording). Earlier Phase 3 packets
squash-merged to `main` as #14–#22.

No n8n workflow JSON is committed. Repo stays identifier-free. Live
values live in gitignored `docs/environment.local.md`.

Implementer: Cursor. Architect/verifier: Claude. Owner: Talal.

---

## 1. What was achieved

Phase 3 is the owner-facing loop around already-captured data: a
10 PM close, a 7 AM briefing, `/digest` on demand, `/ask` over real
rows, and a stuck-job watchdog that does not depend on the digest.

Live, all three workflows **ACTIVE**, versionId = activeVersionId:

- **WF-07** — `settings.timezone` `Asia/Riyadh`, cron `0 22 * * *`
  (close) and `0 7 * * *` (brief). `/digest` returns `reply_text`;
  WF-01 sends. Parallel Telegram + Gmail; delivery via
  `$('Node').first()`, never `.item` across the Merge. Gated Load
  digest (empty item ≠ zero counts).
- **WF-08** — `/ask` over live people / companies / interactions.
  `want_contact` regex without backslash escapes. Parse answer walks
  Responses `content[].text`. Empty `reply_text` is a defect, not a
  silent success.
- **WF-09** — `*/15` `Asia/Riyadh`, independent of WF-07. Fingerprint
  suppression. Silent when clean. Poison (twice-failed) is an alert,
  not a third retry.

WF-01 remains the only Telegram sender. Contact (exec **256611**,
**256687**) and vcard (exec **256753**) are reply-only: nothing
stored. Captures **#68** / **#69** are QR evidence and were not
touched.

---

## 2. Locked decisions (do not reopen)

**Pre-event scope.** Phases 0–3 are the launch set. Phase 4
(enrichment, `/flag`, Apollo, Tavily, credit guard) is gated on the
29 August phone test and is otherwise **dropped pre-event**. WF-05
still ends at `WF-06 dispatch (not yet)`. Do not call WF-06.

**Imran on `ikhalid@`.** The OCR-split pair (two Imran Khalid rows,
`ikhaild@` vs `ikhalid@`) was an owner-confirmed merge in packet 3.9.
Survivor is the `ikhalid@` row; absorbed title carried. That is data.
WF-05 still never auto-merges on name.

**Arabic-only names accepted.** A non-Latin `full_name` is identity
and does not force `needs_review`. The flag `'Non-Latin script present
in the name field'` is informational only; every other flag still
forces review. `name_original_script` alone is still not identity
(trap 7). Captures **#62** / **#63** are evidence, not retro-fixed.

**Phone preference (`wf04-v5`).** When several numbers are printed,
prefer mobile / جوال / cell; else the first printed. Do not return
null merely because more than one number is present. Capture **#66**
is evidence; do not rewrite it.

---

## 3. What read-back found that Cursor reports did not

Rule 2 exists because the implementer report is not the artefact.
Architect read-back of live JSON and executions found defects that
were **not** in the Cursor report that claimed the packet done:

| Defect | What was live | Why the report missed it |
|---|---|---|
| **Ungated Load digest** | `alwaysOutputData: true` and a direct edge to Compose. Empty item → fabricated all-zeros briefing. | Spec conflated a real SQL row with `captured = 0` (must send) with an empty n8n item (must not). |
| **`.item` across a Merge** | `$('Node').item` after parallel Telegram + Gmail. Discarded Merge branch is not an ancestor; throws or reads the wrong lineage. | Named-node sourcing was treated as enough. It is not: `.item` still needs lineage. `.first()` is the cross-branch read. |
| **`want_contact` backslash** | REST PUT stored `\b` as U+0008 backspace. English email/phone questions never set `want_contact` true. | The source looked like a word boundary. JSON does not. |
| **Duplicate company rows** | One physical Huawei became three company rows (orphan + Arabic legal + English legal). | Matcher inserted on each distinct exact key. Packet 3.9 collapsed onto `huawei.com`; WF-05 still does not auto-merge. |
| **First-write-wins on person fields** | Capture 62 (Arabic) created the person; capture 63 (English, same email) could not upgrade `full_name` / title. | Auto-link was reported as working. The stored record was still the worse first write. |
| **Parse answer empty string** | OpenAI Responses puts text at `output[0].content[0].text` (`content` is an array). Extract treated `content` as a string → `reply_text` `''`. Exec **255686** errored; **255695** succeeded. An earlier packet quoted the Huawei sentence from the **errored** run. | The model output was visible in the execution. The node that WF-01 sends from was empty. |

Say this plainly for session 06: **verification is by read-back of
the live artefact, never by the implementer report.** That is why
rule 2 exists.

### Rule 2 cuts both ways — architect error on B7

The architect accepted B7 (vcard branch) as passed because
captures / assets / jobs stayed at 55 / 59 / 61. That was wrong.
A shared Telegram contact also leaves counts unchanged, so the
counts do not discriminate.

Exec **256611** was `branch=contact`, last node `Contact reply sent`,
reply `Contact cards are not supported yet…`. The vcard named rule
had **never** executed. Cursor kept B7 open. Architect reversed on
execution read-back.

**Actual vcard prove (packet 3.14):** exec **256753**,
`startedAt` `2026-08-27T10:50:59.832Z`. Route type named rule
`vcard` (output index 9), last node `Vcard reply sent`. Incoming
`mime_type` `text/vcard`, `file_name` `.vcf`. Reply verbatim:
`Contact files are not supported. Send a photo of the card or a
voice note instead.` Counts still 55 / 59 / 61. No asset. No
`card_vision` job. Execs 256611 and 256687 remain contact evidence;
they do not count as vcard.

Indirect evidence is not a finished branch. That lesson cost the
project twice on 27 Aug (Parse answer quoted from an error run;
B7 accepted on counts).

---

## 4. Measured limitations (not defects to "fix" tonight)

- **OCR is not reproducible between runs.** Same physical card, two
  photos, two emails (`ikhaild@` vs `ikhalid@`). Exact-email auto-link
  will not merge them. Name similarity must not auto-merge.
- **`/ask` retrieval has no relevance floor.** Compose context
  `row_count` was **10** on every live retrieve (255773, 255781,
  255786, 255800, 255806) — the full interaction corpus. An
  off-topic question still ships real rows. A confident answer to an
  unsupported question is not a retrieval success.
- **Non-image assets would be enqueued to vision.** WF-02 enqueue is
  still `audio → transcription`, else `card_vision`, with no mime
  filter. A stored `.vcf` would vision-fail three times and leave
  the capture at `processing`. Mitigated at WF-01 for vcard (and
  contact) once 256753 proved the branch. Other documents (PDF,
  video) still take `document`.
- **QR ceiling.** GPT-4o cannot decode the pattern. Capture **#68**:
  code + brand `wave` only → `image_type` `other`, zero people,
  `needs_review`, nothing recoverable. Capture **#69**: printed
  name/title/company/email/phone → `business_card`, `ready`, empty
  `flag_reasons`. If details are readable, photograph the screen. If
  only a code is visible, scan it and screenshot the contact page,
  or record a voice note. **#68** and **#69** stay as evidence.
- **Contact and vcard are declined, not ingested.** Full contact
  ingest needs a new `people.source_type` and touches two ACTIVE
  workflows. Deferred post-event.

---

## 5. What is deferred post-event, and why

| Item | Why not now |
|---|---|
| WF-06 enrichment, `/flag`, Apollo, Tavily, credit guard | Phase 4. Event is days away; enrichment on a wrong person is worse than no enrichment. |
| `/fix` → `field_corrections` | Table exists; command is not built. Silent NoOp on WF-01. |
| Album auto-detect | Live grouping stays on proven `/batch`. |
| Provider benchmark (GPT-4o / Gemini / Mistral) | `rules.md` §7 rule 14 knowingly not honoured. GPT-4o ships. |
| Contact / vcard ingest | New `source_type`; WF-01 + WF-02 both ACTIVE; four days to the event. |
| `/ask` relevance floor | Launch-scale corpus is small; changing retrieval mid-event is a new failure mode. |
| WF-03 vision on non-image documents besides vcard | Matcher change waits on seeing what Telegram actually sends (A5). `text/vcard` was what arrived on 256753. |

Do not start Phase 4 in the next chat unless the architect issues
that packet after the 29 August gate.

---

## 6. What was completed (packets, evidence)

- WF-07 built, bound to Leap-NI Postgres, self-identifying, ACTIVE.
  Send-path standard: parallel Telegram + Gmail, `.first()`, gated
  Load digest, `parse_mode` explicit.
- WF-08 built, ACTIVE. `/ask` on real questions. `want_contact`
  true on an email question (255810), false on Huawei (255812)
  after the regex fix.
- WF-09 built, ACTIVE. Independent of the digest. Fingerprint
  suppression. Silent clean when there is nothing to say.
- WF-04 `wf04-v5` phone preference. WF-05 person upgrade (Latin
  overwrites non-Latin on exact email/LinkedIn match) and company
  exact-key matcher.
- Packet 3.9 owner-confirmed Imran / Huawei reconcile (data, not
  auto-merge).
- Contact reply-only (256611, 256687) and vcard reply-only (256753).
- QR measured on #68 and #69. Vision prompt not changed after #68.

Tonight's clock observations (22:00 close, 23:41 WF-09 silent,
07:00 briefing, Asia/Riyadh) are **armed, not yet observed**.
Counts will read zero because `events.starts_at` is 30 Aug. That
is expected. The clock is the remaining prove, not a Phase 3
re-open.

---

## 7. Data state at close (27 Aug 2026, after exec 256753)

| Fact | Value |
|---|---|
| captures | 55 (8 `ready`, 4 `needs_review`, 43 `processing`, 0 `failed`) |
| assets / jobs / people / companies | 59 / 61 / 6 / 6 |
| interactions / extraction_runs | 12 / 21 |
| `entity_candidates` | 3 (1 accepted Imran merge, 2 pending person) |
| max `capture_no` | 69 |

Capture **#9** (`processing` / `close_reason=auto`) — do not delete.
Vision job `1564abc3` — do not rewrite. Captures **#62 #63 #66 #68
#69** — evidence, not retro-fixed.

---

## 8. Traps this session proved again (carry forward)

- `$env` and `$getWorkflowStaticData` are forbidden. Postgres is state.
- MCP create binds ElderWise Postgres. Proof is a self-identifying
  `SELECT` of `LEAP 2026`, then REST PUT, then read-back.
- Public PUT of `settings.binaryMode` is 400. Strip it. Do not send
  `active` on an already-active workflow.
- REST jsCode: double backslashes, or write patterns with none.
- `$('Node').first()` after a Merge, never `.item`.
- Empty item from `alwaysOutputData` is not a zero-count report.
- Unchanged row counts do not prove a decline branch.
- Parse the envelope WF-01 actually sends, not the provider text
  sitting on an errored node.
- n8n API only against names starting `LNI ` or `LNI-TEST-`. Never
  restart the shared container. Never deactivate to "test".
