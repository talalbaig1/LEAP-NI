# Session 04 — Phase 2 extraction (packets 2.1–2.8)

**Date:** 27 August 2026
**Chat purpose:** Phase 2 — WF-03 asset processors, WF-04 structured
extraction, WF-05 entity resolution, then close.
**Outcome:** Phase 2 **closed**. End-to-end proof on capture **#61**
accepted by the architect (27 Aug 2026). Wall clock `/done` → terminal
**20.15 s** against a 2-minute criterion. PR **#12** is the merge vehicle.

No n8n workflow JSON is committed. Repo stays identifier-free. Live
values live in gitignored `docs/environment.local.md`.

Implementer: Cursor. Architect/verifier: Claude. Owner: Talal.

---

## 1. What was achieved

Phase 2 is the path from stored media to a reviewable person / company /
interaction record, with no extra owner command after `/done`.

Live chain, proven on #61 (no manual kick):

`WF-01` → `WF-02 /done` enqueue + `Call WF-03` → `WF-03` vision/Whisper +
enqueue extraction + `Call WF-04` → `WF-04` `wf04-v2` + enqueue
entity_resolution + `Call WF-05` → `WF-05` upsert + capture `ready`.

Receipt sent: `✓ Capture #61 saved · 2 items`. Dispatch is best-effort
(`waitForSubWorkflow: false`, `onError: continueRegularOutput`). The
durable act is the row in `processing_jobs`.

Publish-order constraint (this n8n build): a parent cannot be published
while it references an unpublished child. WF-05 was activated first,
then WF-04 gained `Call WF-05`, then WF-03 gained `Call WF-04`.

---

## 2. What was discovered — reasoning, not just outcomes

### 012 catalog gap — a failed `apply_migration` writes no catalog row

Migration `012_seed_bot_state` calls
`current_setting('lni.owner_telegram_user_id')` **without**
`missing_ok := true`. On 26 Aug that GUC was unset. Postgres raised
`unrecognized configuration parameter`. The `DO` block aborted.

Supabase records a version in `supabase_migrations.schema_migrations`
**only after a successful apply**. A raised migration is not a version.
Counting files under `supabase/migrations/` therefore over-counted the
live catalog (13 files vs 12 rows). The file stays as history.
Migration `014` repairs the catalog without disturbing the live
`bot_state` row. **Do not re-apply 012.**

### `image_type` discriminator — capture-time classification was rejected

Telegram tells us “this is a photo”. It does not tell us “this is a
business card”. The owner has one hand free; there is no caption
convention. Composition at a booth is unpredictable.

So WF-01 writes `assets.kind = 'photo'` meaning **image, contents not
yet determined**. Phase 2 WF-03 sends **every** image to **one** vision
call. The strict schema returns `image_type`:
`business_card | scene | other`. WF-03 then `UPDATE`s `assets.kind`.

A WF-03 branch that only ran vision on `kind='business_card'` would
never have fired: every live image sat at `'photo'`. That is why
capture-time classification was rejected — it would have classified
nothing, confidently.

`scene` / `other` stay `kind='photo'` (no sixth kind in the CHECK). No
facial recognition (`rules.md` §7 rule 13). Still **one call**, no
OCR-then-parse.

### Adapter envelope — a provider shape must not reach WF-04

Packet 2.3 wrote two shapes into `processing_jobs.output`: the OpenAI
Responses envelope for vision, and a flat `{text, usage}` for Whisper.
WF-04 would have needed two unwrap paths, one of which depended on
OpenAI keeping `output[0].content[0].text` forever. That leaks a
provider detail into the data model (architecture rule 4).

The adapter envelope is the same shape for every `job_type`:
`provider`, `model`, `job_type`, `result`, `raw`, `error`,
`completed_at`. WF-04 reads **`result` only**. `raw` is for replay and
the (cut) benchmark. If the provider envelope changes, only WF-03’s
adapter node moves.

### Sweep-enqueue defect — auto-closed captures were stored and never processed

The inactivity sweep stamped `close_reason='auto'` and left
`captures.status` off `open`. It did **not** enqueue `processing_jobs`.
Assets were in Storage. Nothing ever claimed them. Capture #59 was the
proof: closed by the sweep, transcription never queued, until Defect 1
was fixed.

**Cause:** `/done` owned enqueue; the sweep only owned close. They must
be the same write. Fix: sweep enqueues with the same `INSERT … SELECT`
as `/done`, then best-effort `Call WF-03`. Zero rows enqueued is a
silent terminal. Dispatch failure must not fail the sweep (Postgres is
the queue; WF-09 is the backstop).

### Transliteration defect

`full_name` is the Latin form. `name_original_script` is the verbatim
original (Arabic on an Arabic card). If the card already prints Latin,
copy it exactly — never re-transliterate. If the card is Arabic-only,
the model transliterates. A prompt that did not say this produced
Arabic in `full_name` or a null, and the original was lost or treated
as the identity.

### Null-summary defect — “nullable beats guessed” made null the obedient answer

Defect 3 was diagnosed as (b), not (a). The transcript **did** reach the
model: `follow_ups[0].title` “Meeting with Imran Khalid” came from the
speech. The system prompt never instructed “summarise this” or “extract
topics”. Combined with “nullable beats guessed” and a nullable schema,
`summary: null` / `topics: []` was the obedient answer.

Fix (`wf04-v2`, does not overwrite `wf04-v1`): summary is 1–3 sentences,
**required** when a `[TRANSCRIPT]` or `[TYPED_NOTE]` block has text;
null only when both are empty. Topics are short tags from that same
text.

### Phantom-person defect — `full_name` required, not a wordlist

Defect 4: speech-only capture #59. `hasName` treated any non-empty
`name_original_script` as a name, so `"هذا الرجال"` became a person.
Only “No email and no phone” fired.

A demonstrative blocklist was proposed and **rejected as the primary
defence**. A wordlist is never complete (`هذا الشخص`, “the guy”, “some
lady from Aramco”).

**Primary rule:** a person row requires a **non-null `full_name`**.
`name_original_script` alone is not identity. Arabic-only card: model
transliterates, `full_name` present, survives. Speech that names a real
person: same. Speech that only refers: `full_name` null, dropped,
“No name extracted” fires. Closed-class blocklist is secondary only.

### OCR email-split — two Imran Khalid rows, now a visible suggestion

#58 and #60 are the same physical card, captured twice. Vision job
`1564abc3` (locked, Option 3 — do not rewrite) read
`ikhaild@sa.qatarairways.com`. The later photo read
`ikhalid@sa.qatarairways.com`. Exact `email_normalized` cannot merge
them. Name similarity must not auto-merge (shared family names at this
event would quietly corrupt the set).

Architect **accepted the split**. Two people is the honest output of
the rule.

Defect 5: the suggestion path only ran when email and LinkedIn were
absent, so an OCR-misread email produced two silent unlinked people.
That is the most likely duplicate-creation mechanism at this event.

Fix: write `entity_candidates` whenever another person shares **exact
`full_name` AND exact `company_id`**, even if both carry emails, when
those emails are not equal. Reasons name the two addresses. Score `1`.
Still a suggestion — never an automatic link.

Live row `affab30d-…`, decision `pending`, reasons
`same_full_name`, `same_company`,
`emails_differ: ikhaild@sa.qatarairways.com vs ikhalid@sa.qatarairways.com`.
Awaiting owner decision. Do not auto-accept it.

### Requeue without backoff — named Phase 3 item, do not “fix” now

A transient failure returns the job to `queued` with **no delay**.
`workflows.md` specifies 1 / 5 / 20 minutes. Safe in Phase 2 because
WF-03/04/05 run on dispatch. It becomes live the moment **WF-09**
re-dispatches a stale `queued` row. Do not add a Wait inside the
300 s execution.

### Scope cuts — knowingly not honouring `rules.md` §7 rule 14

Rule 14 says provider choices are settled by benchmark. Under the
29 August gate we cut, in writing:

| Cut | Where it lives | Why it is a known violation |
|---|---|---|
| Provider benchmark (GPT-4o / Gemini / Mistral) | post-event | GPT-4o ships as the card engine **without** a benchmark |
| Album auto-detect | post-event | Live grouping stays on proven `/batch` |
| `/fix` → `field_corrections` | post-event | Table exists; the command is not built |

These are not forgotten. They are deferred. Do not reopen them in
Phase 3.

### #61 company vs email domain — not a defect

Card company **BTGroup**. Email domain **hasoub.com**. `companies.domain`
is **null**. The model copied the printed company name and did not invent
a domain from the email. That is correct for Phase 2. Relevant to
**enrichment in September** (WF-06 / Apollo), not a flag today.

---

## 3. What was completed

- Docs before every n8n write (`rules.md` §1).
- WF-03: filesystem-v2 binary in, adapter envelope out, `image_type` →
  `assets.kind`, enqueue extraction, `Call WF-04`. Whisper `language`
  **absent**.
- WF-04: labelled sources, one strict `json_schema` call, `wf04-v2`
  beside `wf04-v1`, rule-based flags, enqueue entity_resolution,
  `Call WF-05`.
- WF-05: exact email or exact LinkedIn auto-link only; OCR-split
  candidates; capture `ready` / `needs_review`; terminal
  **`WF-06 dispatch (not yet)`**. Phase 4 dropped pre-event.
- E2E #61: 2 assets stored, four jobs succeeded, person
  **Amer Mohamed Saadi Khater** /
  **عامر محمد سعدي خاطر**, company **BTGroup**, interaction summary
  written, capture `ready`, `close_reason=explicit`.

Git commits on this line (docs; n8n is instance-only):

1. `97f13cf` — Packet 2.5 spec (sweep enqueue, transliteration, WF-04; cut benchmark)
2. `8b0e598` — Packet 2.6b (full_name identity, summary/topics, WF-05 spec)
3. `902a86e` — Packet 2.7 (OCR-split candidate rule; Call WF-04 / Call WF-05 spec)
4. *(this file)* — Packet 2.8 session close

Locked vision job `1564abc3` remained byte-identical
(`output_md5=9f830bbd14826866c12ee38b0f50fa5a`,
`last_transition_at=2026-08-26 21:10:09.478715+00`). Option 3 held.

Older captures at `processing` with no `entity_resolution` job were
**left**. WF-05 claims jobs, it does not sweep `captures.status`.

---

## 4. What remains

### Phase 3 (launch-blocking, next chat)

WF-07 digests (10 PM close, 7 AM briefing, `/digest`), WF-08 `/ask`,
WF-09 watchdog. The 29 August gate **does not move**. If Phase 3 is
squeezed, cut Phase 2 leftovers (already cut) before cutting the
watchdog. The watchdog must alert independently of the digest.

### Owner actions (Talal)

- Decide the pending `entity_candidates` row for the two Imran Khalid
  people (accept merge vs reject). The system will not decide.
- Do not delete capture **#9** (`processing` / `close_reason=auto`).
- Do not rewrite vision job `1564abc3`.
- Phase 3 work happens in a **new chat** with
  `docs/sessions/handover-to-session-05.md`.

### Not this session

WF-06 enrichment, `/flag`, `/fix`, album prompt, provider benchmark,
backoff delays.

---

## 5. Traps this session proved again (carry forward)

- `$env` and `$getWorkflowStaticData` are forbidden. Postgres is state.
- MCP auto-assigns the first Postgres credential (ElderWise). Bind
  Leap-NI Postgres via REST PUT. Proof is a self-identifying
  `SELECT` of `LEAP 2026`, not the creation response.
- Public PUT of `settings.binaryMode` is 400. Strip it. Do not send
  `active: false` on an active workflow.
- `queryReplacement` must be **one** expression that evaluates to an
  array. Code cannot **read** filesystem-v2 binaries.
- n8n API only against names starting `LNI ` or `LNI-TEST-`. GET name,
  then act. Never restart the shared container.
- Name similarity never auto-merges. Exact email / exact LinkedIn only.
- WF-01 is the only Telegram sender. Flagged captures sit at
  `needs_review` until the digest (WF-07) lists them.
