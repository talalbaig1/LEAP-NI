# Phase 7 plan — Follow-up drafting, confirm-before-send

**Date:** 28 August 2026
**Status:** PLAN ONLY. No workflow, no migration, no WF-01 edit.
**Order:** 7, then 6, then 5. Phase 8 PWA stays post-event
(`masterplan.md` §3 Corollary 1).
**Main at plan time:** `e2be548`.

Owner intent (paraphrase, not a quote to design around): after a
meeting he records a voice note naming the person or email; a
follow-up email goes out with attachments (photo of them, what was
discussed), CC'd to himself.

Architect constraints 1–7 are accepted. Disagreements and physical
limits are in §L, not buried in a node list.

---

## Binding rules this plan will not violate

- **No auto-send.** `masterplan.md` §4 decision 12. The system
  drafts; the owner taps Send. Same card produced `ikhaild@` and
  `ikhalid@`.
- **Confirm shows recipient address, subject, body, every
  attachment filename.** The owner is approving the recipient as
  much as the text.
- **CC the owner on every send.**
- **Attachments from `lni-assets`, owner-scoped, only assets
  already linked to that person's captures.**
- **No send without a person row with non-null email.**
- **Gmail is the transport** (live credential, already sending
  digests).
- **WF-01 is the only inbound Telegram sender.** WF-10 returns
  `reply_text` (and markup); WF-01 sends.
- **WF-01 is frozen until the 29 Aug gate passes.** Packets 7.1–7.3
  do not touch it. Packets 7.4–7.5 are gate-conditional.
- **Draft is a Postgres row.** Never `$env`, never
  `$getWorkflowStaticData`.
- **Do not deactivate any LNI workflow. Do not restart n8n. Do not
  touch ElderWise.**

---

## A. Trigger design

**Recommend ONE: `/followup <name-or-email>` as an explicit
command, same family as `/flag` and `/ask`.**

Optional remainder after the name is the brief (typed). If the
remainder is empty, WF-10 inserts a `draft_state='awaiting_voice'`
row and replies `Record a voice note now (15 min). A photo still
goes to capture.` The next **voice** from the allowlisted owner
is claimed by WF-01 only when `bot_state.awaiting_followup_id` is
set and `awaiting_followup_until > now()`. Any **photo / document /
card** on that interval **clears the await and takes the capture
path**. Capture wins. Corollary 1.

### Why not the other options

| Option | Why it loses |
|---|---|
| Voice inside an open capture with detected intent | Competes with the capture pipeline. “I’ll follow up with Ahmad” in a meeting note becomes a draft, or a real follow-up voice becomes only a transcript. False positive/negative both hurt. Touches WF-01/02/03, all ACTIVE. Not a 6 PM one-hand win; it is a capture risk. |
| Action on an existing capture (button on `/done` receipt) | Decision 6 is silent unless flagged. A button on every receipt is a confirmation card by another name. Also needs WF-01 markup on the media path, the hottest path. |
| Pure voice, no command | The 6 PM ideal. Telegram does not put a command and a voice on one update. Without a command or a mode flag, every voice is a capture asset. **Cannot be met safely before Monday.** Named in §L, not silently replaced. |

### One hand at 6 PM

Two gestures, both proven: type `/followup Ahmad` (same muscle as
`/flag Ahmad`), then hold the mic — or type the brief on the same
line if the hall is loud. Buttons on the confirm card are one
thumb. Re-typing a long email is the 2+ fallback, not the happy
path.

### WF-01 changes (after the gate only)

1. `Classify update`: `action=followup` from `/followup` (strip
   `@botname`, first token). Named Route type output **appended**
   after `flag`. Do not renumber 0–11. Re-GET **every**
   `connection[i]` (trap: Switch index).
2. Call WF-10, `waitForSubWorkflow: true`, payload
   `owner_id, correlation_id, text, source='command'`.
3. `callback` branch: stop being a silent NoOp. Answer the query,
   if `data` starts `f7:` Call WF-10 `source='callback'`. Anything
   else stays the existing Callback terminal.
4. Voice intercept **only** when awaiting is set: Call WF-10
   `source='voice'` with Telegram `file_id`. Do **not** store that
   voice as a capture asset. Do **not** call WF-02. A follow-up
   brief is an instruction, not a meeting record.
5. Shared command send node: pass optional `reply_markup` from the
   callee. Empty for `/ask` `/digest` `/flag`. Prove those three
   still send after the PUT.
6. Optional `reply_text_2` if the confirm exceeds Telegram 4096
   (see §L). Second send, same gates.

**Until the gate passes, WF-10 is built with Execute Workflow
Trigger + Manual Trigger only.** Architect proves it with
`execute_workflow`, not Telegram.

---

## B. Person resolution

**Reuse the `/flag` ladder.** Exact `email_normalized`, then exact
`full_name` case-insensitive, then trigram on `full_name` at 0.4.
Stop at the first step that yields a match. Max 5 rows.
`count(*) OVER()::int AS hit_count` (COUNT is a string otherwise).

| Hits | System | Owner |
|---|---|---|
| 0 | No draft row. | `No person matches <text>.` |
| 1, `email_normalized` null | No draft. | `<name> has no email. Capture a card with an address first.` |
| 1, email present | Draft proceeds. | Confirm card (see F). |
| 2+ | No draft. Inline buttons, one per person, `callback_data` = `f7:p:<person_uuid>`. Render `<name> (no email)` for nulls — never a dangling separator, never a bare `null`. A no-email person button replies the no-email text, does not draft. | Tap the right row, **or** re-issue `/followup email@`. NEVER guess. |

Disambiguation is **Telegram buttons first** (one hand). Re-issued
command is the fallback when the list is wrong or the email is the
only join key (OCR-split `ikhaild@` / `ikhalid@` — the owner picks
by address, which is the point of constraint 2).

Do not auto-merge on name. Do not honour “just use the other
Imran”.

---

## C. Intent and content extraction

**Model:** `gpt-4o-mini`, `temperature: 0`. Same as WF-08. Rule 14
is still knowingly not honoured; do not reopen a benchmark in this
phase.

**Prompt version:** `wf10-v1`. Bump only with a packet.

**Voice:** Whisper on WF-10, **`language` absent**. Never call
WF-03 (it claims `card_vision` / `transcription` jobs and would
mix queues). Code-switched Arabic/English is expected.

**Do not write the transcript to `audit_log`.** Rule 8. The OpenAI
node sees it; Postgres stores only the extracted fields and the
draft.

**Strict JSON schema** (Responses structured output, same family as
WF-04). Ask for what you want. Do **not** say “return null if
unsure” on the fields that must exist — Phase 2 taught that an
explicit null instruction produced null summaries everywhere.

```
{
  "recipient_ref":  string,   // name or email as spoken; if none, the string "none named"
  "agreed":         string,   // what was agreed, in the owner's words. If nothing was agreed, the sentence "No specific next step was stated."
  "send_what":      string,   // what should be attached or offered. If nothing, "No attachment mentioned."
  "deadline":       string,   // ISO date or the original words. If none mentioned, "none mentioned"
  "subject":        string,   // email subject, always produced
  "body":           string    // email body, always produced
}
```

`deadline` is **not** a Postgres null via “return null”. Map the
sentinel `"none mentioned"` to SQL NULL at the SQL boundary, in
the write node, not in the model.

Recipient resolution still uses the `/followup` argument first.
`recipient_ref` is a second opinion: if the argument was empty
(voice-only after `/followup`), run the ladder on `recipient_ref`.
If both are empty or `"none named"` → failure mode “transcript
names nobody”.

Body is a follow-up from Talal, not a transcript dump. No phones
unless they appeared in the brief. No invented facts.

---

## D. Attachment selection

**Candidate set.** Owner-scoped, `upload_status='stored'`,
`storage_path` not null, whose `capture_id` is in:

```
SELECT i.capture_id
FROM interactions i
WHERE i.person_id = $person
  AND i.capture_id IS NOT NULL
```

Never an asset from a capture that is not linked to that person.
Never another owner's object. Signed URL / Storage GET uses the
same `httpHeaderAuth` pattern as WF-01; path first segment is
`owner_id`.

**Default rule (not none, not all):**

- Include: `kind IN ('photo', 'selfie')` — “a photo of us”, scene
  after vision (`image_type=scene` stays `kind=photo`).
- Exclude: `business_card` (their card image is not a follow-up
  attachment), `audio` (the owner's self-dictation is not for the
  recipient), `document`.
- Order: newest first. Cap **3** files.
- Size: see ceiling below.

**Live finding, 28 Aug 2026 (architect query, all 8 people).** Every
person currently in the DB has **zero** assets with `kind IN
('photo','selfie')` on a capture linked via `interactions`. All
linked assets are `business_card` or `audio`. The v1 attachment
rule is unchanged — it is not weakened to include cards or audio.
Consequence: the confirm card must render `Attachments: (none)`
cleanly, and that is the Stage C prove. A later selfie/scene
capture will populate the set without a workflow change.

**Owner change before send, v1:** confirm lists every filename
chosen. Three buttons:

- `Send` — as listed
- `Send without attachments`
- `Cancel`

Per-file toggle is **not in v1**. Telegram `callback_data` is 64
bytes; two UUIDs do not fit. A picker is a dashboard job (Phase
5). Building a weaker silent picker is forbidden; this plan names
the cut. The owner can still get “none” in one tap.

**Gmail ceiling.** Gmail / Gmail API: **25 MB per message**
including MIME. Base64 expands ~33%. Plan limit: sum of
`assets.size_bytes` **≤ 18 MB**. Over: drop largest first until
under, **list omitted filenames on the confirm** (`Omitted (too
large): …`). Never send a silent subset. If even one file is over
18 MB, send with no attachments and say so. Size from
`assets.size_bytes` (HEAD at ingest), not item metadata, not a
Code buffer length (filesystem-v2 cannot be read in Code).

**Download for attach:** HTTP GET Storage, `responseFormat: file`.
Never Code-read bytes. Pin data is not evidence.

---

## E. Draft storage

Live `follow_ups` (read 28 Aug 2026, `information_schema` +
`count(*)`): **0 rows**. Columns:

| Column | Type | Null | Use? |
|---|---|---|---|
| `id` | uuid PK | NO | Draft id. In `callback_data`. |
| `owner_id` | uuid | NO | Owner scope. |
| `interaction_id` | uuid | YES | Set to that person's most recent interaction if any; NULL if none. Do not fail the draft on NULL (unlike `/flag` enqueue). |
| `person_id` | uuid | YES | **PARTIAL CHECK, not a blanket NOT NULL.** `person_id IS NOT NULL` only when `draft_state = 'awaiting_confirm'`. Constraint name `follow_ups_person_id_confirm_check`: `draft_state <> 'awaiting_confirm' OR person_id IS NOT NULL`. Reasoning: `/followup <name>` with an empty remainder inserts `awaiting_voice` **before** voice-side person confirmation; a voice-only remainder can also insert `awaiting_voice` with `person_id` still null until extract+ladder finish. A plain `NOT NULL` on `person_id` would reject that insert. Sendable drafts are `awaiting_confirm`; the claim SQL still requires `to_email IS NOT NULL`. Do not silently send a NULL person. |
| `title` | text | NO | Use the email subject. |
| `due_at` | timestamptz | YES | From `deadline` sentinel-mapped. NULL if none. |
| `priority` | text | NO | Default `medium`. Not in v1 UI. |
| `status` | text | NO | Keep `open` \| `done` \| `cancelled`. **Do not extend this CHECK.** WF-07 counts `status='open'` due today. Mapping: awaiting confirm = `open`; sent = `done`; cancel = `cancelled`; Gmail fail stays `open`. |
| `created_at` | timestamptz | NO | Insert time. |

**Missing — migration `024_follow_ups_email_draft.sql` (file prefix
AND catalog name; 023 taught us).** Additive, nullable/defaulted,
empty table so this is cheap. Apply **before Monday**. Event days
forbid schema refactors.

| Column | Type | Why |
|---|---|---|
| `to_email` | text | Frozen at confirm time. What the owner approved. |
| `cc_email` | text | Frozen owner address. |
| `subject` | text | May match `title`; store both so a title edit cannot desync. |
| `body` | text | Full sent body. |
| `attachment_asset_ids` | uuid[] not null default `{}` | Chosen set. |
| `draft_state` | text not null default `'draft'` | `draft` \| `awaiting_voice` \| `awaiting_confirm` \| `sending` \| `sent` \| `failed`. Separate from `status` so digest SQL does not change. |
| `idempotency_key` | uuid not null default `gen_random_uuid()` unique | Callback and send claim. |
| `gmail_message_id` | text | After send. |
| `sent_at` | timestamptz | After send. |
| `confirm_expires_at` | timestamptz | Stale tap. Default `now() + interval '12 hours'`. |
| `prompt_version` | text | `wf10-v1`. |

`bot_state` needs two columns in the same migration (or `025` if
split — prefer **one** 024 to avoid another unnamed catalog row):

- `awaiting_followup_id uuid` → `follow_ups(id)`
- `awaiting_followup_until timestamptz`

Clear both on send, cancel, expiry, and on any capture media.

RLS: same `owner_id` policy as today. Do not GRANT SELECT to
`authenticated` (Phase 5).

---

## F. The confirm loop

WF-01 `callback` is a silent NoOp today (`Callback terminal`).
Album auto-detect stays CUT. This packet **occupies** that branch
for `f7:` only.

**Telegram `callback_data` max 64 bytes.** Contract, all ≤ 42
chars:

| data | Meaning |
|---|---|
| `f7:s:<follow_ups.id>` | Send as listed |
| `f7:n:<follow_ups.id>` | Send, zero attachments |
| `f7:x:<follow_ups.id>` | Cancel |
| `f7:p:<people.id>` | Pick this person (2+ list) |

Always `answerCallbackQuery` first. Unanswered callbacks retry and
look like double taps.

**Confirm message (constraint 2)** must include:

- full `to_email`
- CC address
- subject
- full body (see §L if over 4096)
- every attachment filename, or `(none)`
- omitted-for-size list if any

HTML `parse_mode` explicit. Escape `& < >`. Emails in HTML are
fine; `_` in Markdown is why this build does not leave parse_mode
absent.

**Idempotent send** (not a hope):

```
UPDATE follow_ups
SET draft_state = 'sending'
WHERE id = $1
  AND owner_id = $2
  AND draft_state = 'awaiting_confirm'
  AND confirm_expires_at > now()
  AND to_email IS NOT NULL
RETURNING id, to_email, cc_email, subject, body, attachment_asset_ids;
```

`alwaysOutputData: true`. **Gate on RETURNING `id` notEmpty.**
Zero-row UPDATE is `{success:true}` — without the gate, Gmail
fires on a stale/double tap.

- 0 rows → load current `draft_state`. `sent` → `Already sent.`
  `cancelled` → `Cancelled.` expired → `This draft expired.
  /followup again.` `sending` → `Send already in progress.`
- 1 row → download attachments → Gmail → on success
  `draft_state='sent'`, `status='done'`, `gmail_message_id`,
  `sent_at`. On Gmail error → `draft_state='failed'` (still
  `status='open'`), reply the error, **do not** retry from the
  same callback.

`idempotency_key` unique is belt; the `draft_state` claim is the
suspenders. Gmail is after the claim so a double tap cannot
produce two messages.

**Hour-later tap:** 12-hour expiry. An hour is in window. Same
claim SQL. If the person row's email changed in between, still
send **`to_email` frozen on the row** (what they approved), not a
fresh lookup.

---

## G. Send and record

1. Gmail: To = frozen `to_email`, CC = frozen `cc_email` (owner
   `auth.users.email`, same join WF-07 uses). Attach binaries from
   Storage GET. Credential: existing Gmail Leap-NI. `onError:
   continueRegularOutput` is **wrong** here — a failed send must
   not look like success. `retryOnFail: true` once; then fail the
   draft.
2. `follow_ups`: as above.
3. `audit_log`: `actor_type='user'`, `action='followup_sent'`,
   `entity_type='follow_up'`, `after` = `{follow_up_id, person_id,
   gmail_message_id, attachment_count}`. **No email, no body, no
   transcript.**
4. **Do not rewrite `interactions.summary`.** The sent email is the
   follow-up record. Digest already counts `follow_ups`.
5. Clear `bot_state` awaiting columns.
6. Owner Telegram: `Sent to <name> <email>. Subject: … Files: …`
   (escape). Gate `reply_text` notEmpty.

---

## H. Failure modes

| # | Failure | System | Owner is told |
|---|---|---|---|
| 1 | Person has no email | No draft. No Gmail. | `<name> has no email. Capture a card with an address first.` |
| 2 | Asset download fails (Storage GET not 200 / empty file) | That file skipped, listed under omitted; if **all** fail, send is refused (do not send a body-only email the confirm said had files, unless they tapped `Send without attachments`). | `Could not attach <filename>.` + omit or refuse. |
| 3 | Gmail rejects | Claim already `sending` → `failed`. No second auto-try from the same tap. | `Gmail refused the send. Draft kept. Try later or Cancel.` |
| 4 | Owner taps Send twice | Second UPDATE returns 0 rows. | `Already sent.` (or `Send already in progress.` if overlapping). |
| 5 | Owner taps Send an hour later | Still `awaiting_confirm` and unexpired → send. Expired → no send. | Send confirmation, or `This draft expired. /followup again.` |
| 6 | Transcript names nobody | No person ladder hit. No draft. | `No person named. Try /followup <name or email>.` |
| 7 | 0 matches / 2+ unresolved | No draft. | `/flag`-style list or no-match text. |
| 8 | Oversize attachments | Drop largest, list omitted on confirm, owner still taps Send. | Filenames + omitted list **before** Send. |
| 9 | Awaiting voice, owner sends a photo | Await cleared. Capture path unchanged. | Capture receipt only. No follow-up error. |
| 10 | Awaiting voice times out (15 min) | Columns cleared. Draft `cancelled`. | Next voice is a normal capture. No surprise email. |
| 11 | Confirm HTML / parse_mode | Escape. Explicit HTML. | Readable address, not italic garbage. |
| 12 | WF-10 called without LEAP 2026 row | `stopAndError` wrong-database. WF-00. | No owner-facing send. |

---

## I. WF-10 node outline

Settings (REST PUT after MCP create; create is not evidence):
`availableInMCP: true`, `errorWorkflow` = WF-00, `executionTimeout:
300`, `timezone: Asia/Riyadh`. Bind Postgres Leap-NI, Gmail
Leap-NI, OpenAI, Telegram only if it must answerCallback — prefer
WF-01 to answer. HTTP Storage header auth. Self-identify first
execution: `SELECT name FROM public.events WHERE name = 'LEAP 2026'`.

**Every Postgres node: `alwaysOutputData: true`.** Every provider
and DB node: `retryOnFail: true` except Gmail after claim (one
retry then fail). Named-node sourcing after every I/O. No `$json`
after Postgres. `queryReplacement` one array expression.
`stopAndError` messages: no comma, quote, apostrophe.

### Shared head

1. **Manual Trigger** and **When called** (executeWorkflow) →
2. **Self identify** (Postgres) →
3. **Row returned?** `name` equals `LEAP 2026`, strict. False →
   **Wrong database terminal**.
4. **Route source** Switch: `command` | `voice` | `callback`.
   Fallback → **Unknown source terminal**. After any append,
   re-GET every connection index.

### Command path

5. **Parse argument** (Code, no `\\` regex if possible).
6. **Usage?** empty name and empty brief and not a voice await →
   reply `Usage: /followup <name or email>` → **Usage terminal**.
7. **Lookup people** (Postgres, `hit_count` `::int`, max 5).
8. **Lookup returned?** named `id` notEmpty. False → 0-match
   compose → return.
9. **Flag many?** number `gt` 1, **strict**, left side already
   int. True → button list compose → return. False →
10. **Has email?** `email_normalized` notEmpty. False → no-email
    compose → return.
11. **Load candidate assets** (Postgres).
12. **Whisper?** only if `source=voice`. Else skip to 14.
13. **Transcribe** OpenAI audio, language absent →
14. **Extract draft** OpenAI JSON schema `wf10-v1` →
15. **Parse extract** (Code). Empty subject/body is a defect,
    `stopAndError`.
16. **Insert draft** (Postgres) `draft_state='awaiting_confirm'`,
    freeze to/cc/subject/body/attachments/expiry. `RETURNING id`.
17. **Draft row returned?** False → stopAndError. True →
18. **Compose confirm** (Code) → `reply_text` + `reply_markup` →
    **Return to WF-01**.

Voice-await insert is a shorter branch at 6: insert
`awaiting_voice`, set `bot_state`, reply record-now, return.

### Callback path

19. **Parse callback** (Code) `f7:`.
20. **Pick person?** `f7:p:` → jump to command from step 10 with
    that id (load email; no re-guess).
21. **Cancel?** `f7:x:` UPDATE `cancelled` where
    `awaiting_confirm` RETURNING. Gate. Reply `Cancelled.`
22. **Claim send** UPDATE `sending` … RETURNING (SQL in §F).
23. **Claimed?** False → already/expired compose → return.
24. **Need files?** attachment ids length `::int` gt 0.
25. **GET each object** HTTP file. Merge. **Do not** Code-read.
26. **Gmail send** To/CC/subject/body/attachments.
27. **Gmail id present?** `id` notEmpty (`.first()` if any Merge).
    False → mark `failed` → compose error → return.
28. **Mark sent** UPDATE `sent` / `done` / `gmail_message_id` /
    `sent_at` WHERE `draft_state='sending'` RETURNING.
29. **Sent row returned?** False → stopAndError (Gmail may have
    sent; do **not** send again; WF-00). True →
30. **Clear await** (Postgres) → compose `Sent to …` → return.

Return contract to WF-01: `{ ok, reply_text, reply_text_2?,
reply_markup? }`. WF-01 gate: `ok` true AND `reply_text` notEmpty.
Empty `reply_text` is a WF-10 defect.

Inactive until packet 7.4. Publish WF-10 before adding the Call on
WF-01.

---

## J. Packet breakdown

Architect reads live workflow JSON, live SQL, live executions.
Never this report.

| Packet | Artefact | Architect read-back to accept |
|---|---|---|
| **7.1 Schema** | Migration file `024_follow_ups_email_draft.sql` applied. Docs: this plan + `architecture.md` §4 + `workflows.md` WF-10 stub. **No WF-10. No WF-01.** | `information_schema` shows the new columns. Catalog **name** starts `024_`. `follow_ups` still 0 rows. `follow_ups_status_check` still `open\|done\|cancelled`. WF-07 GET unchanged. |
| **7.2 WF-10 draft, INACTIVE** | Workflow created, REST PUT settings + Leap-NI binds. Manual + executeWorkflow. Command path through confirm compose. **No Gmail. No Telegram.** | GET name `LNI WF-10 - Follow-up drafting`. `active: false`, `activeVersionId: null`. `availableInMCP: true`, timezone, errorWorkflow=WF-00, timeout 300. Postgres credential is Leap-NI (self-id execution `LEAP 2026`). One `execute_workflow` INSERT: `draft_state='awaiting_confirm'`, `to_email` set, `status='open'`. Confirm JSON has full address, subject, body, filenames. WF-01 GET: Route type connections **identical** to post-#33. |
| **7.3 Confirm + Gmail, still INACTIVE** | Callback path + claim SQL + Gmail. Prove To+CC. Prove double execute does not send twice. **To = owner address** (not a real contact). Attachment: one stored `photo`/`selfie` of a probe capture, or none if none exists — never a production contact. | Execution 1: last node sent-compose, `draft_state='sent'`, `gmail_message_id` not null, `status='done'`. Execution 2 same id: RETURNING empty, last node already-sent, **one** Gmail `id` on the row. Profile: no second message. `audit_log` action `followup_sent` with no email in `after`. |
| **7.4 WF-01 wire** | **Only if 29 Aug gate passed.** Append Route `followup`. Callback `f7:`. Optional voice await. `reply_markup` / `reply_text_2` on the command send. PUT without `active`. | Live WF-01 (versionId `e3f817e2`, architect GET): Route type has **11 named rules**; `connections[10]` = Flag arg empty?, `connections[11]` = Unknown type terminal (fallback). After appending followup, Switch connections are **index-based** and the fallback extra output does **not** shift the old wire. Correct assertion: **`[10]` → Flag arg empty? (unchanged). `[11]` → the NEW followup node. `[12]` → Unknown type terminal (fallback, RE-WIRED).** The wording "[11] still Unknown" is satisfied by the exact mis-wire this check exists to catch — do not use it. Re-GET every `connection[i]`. `/ask` and `/digest` executions still return and send (regression). `/flag` usage still 265540-class. `POST /activate` is not used on WF-01 (already active). |
| **7.5 Device prove** | Owner phone. 0, 1, 2+, no-email, send, double-tap, stale (optional). Voice if 7.4 shipped await. | Webhook executions, last nodes, `reply_text`, `follow_ups` rows, Gmail CC. Capture counts do not jump on a follow-up voice. A photo during await still stores an asset. |

If the gate fails, **stop at 7.3**. Capture hardening wins.
7.1–7.3 stay dormant.

---

## K. Risk to the launch set

| Workflow | Touch? | Blast if it goes wrong during the event |
|---|---|---|
| **WF-01** | Yes, packet 7.4 only | **Highest.** A Switch mis-wire repeats 4.9: commands die silent (`/flag`, `/ask`, `/digest`, contact, vcard). A shared-send `reply_markup` bug can break every inbound reply. Voice-await bug can swallow a capture voice. **Rollback:** PUT WF-01 back to version `e3f817e2-…` (post-#33), do not deactivate. |
| WF-02–09 | No | None by design. Do not Call WF-03 from WF-10. Do not change WF-07 SQL. |
| **WF-10** | New | If ACTIVE and looping, it can Gmail. Keep INACTIVE until 7.4. Ceiling is the claim SQL, not a hope. |
| Capture / storage | Await-clear on photo | If clear fails, a voice might skip capture once. Prefer fail-open to capture. |
| `follow_ups` | Additive columns | Empty table. Digest uses `status` + `due_at` only. A bad CHECK on `status` would break WF-07 — **do not alter that CHECK**. |
| Gmail credential | Shared with WF-07/09 | A revoke or quota hit hurts digests too. 7.3 prove uses one owner-address mail, not a burst. |

**During 31 Aug – 3 Sep:** no further schema. Incident-only PUTs
with a known prior `versionId`.

---

## L. Traps — how this build avoids them

| Trap | How avoided |
|---|---|
| Postgres COUNT is a string | `count(*) OVER()::int`. Flag many? stays number/strict. |
| Switch connections are index-based | Append only. Re-GET every `connection[i]` before claiming 7.4 done. |
| `alwaysOutputData` empty item | Gate `id` notEmpty after every lookup/claim/insert. Empty item ≠ zero counts. |
| Zero-row UPDATE `{success:true}` | Claim send with RETURNING; gate before Gmail. |
| `$('Node').item` after a Merge | `.first()` for Gmail `id` / Telegram `message_id`. |
| `parse_mode` absent is Markdown | Explicit HTML on every new Telegram send. Escape. |
| REST jsCode backslash doubling | No `\\b` / `\\s` in new Code. Prefer no-escape patterns. |
| Literal `\n` in Telegram text | Real newlines in stored parameters. |
| PUT `active=true` is 400 | WF-10: `POST /activate` when the time comes. WF-01: PUT without `active`. Strip `binaryMode` and `timeSavedMode`. |
| MCP create binds ElderWise | REST PUT credentials + self-id execution. |
| `$json` after I/O | Named node. |
| filesystem-v2 | No Code-read of attachments. HTTP file GET. No pins as proof. |
| `queryReplacement` mixed CSV | One array expression. |
| Whisper `language: en` | Absent. |
| Never log PII | audit_log without email/body/transcript. |
| 023 unnamed catalog | File **and** catalog `024_…`. |

---

## M. Disagreement with the architect's constraints (cheap now)

1. **Constraints 1, 3, 4, 5, 6, 7 — no disagreement.**
2. **Constraint 2 vs Telegram 4096.** One WF-01 `reply_text` cannot
   always carry full recipient + subject + full body + filenames +
   buttons. Silent truncation of the **sent** body is forbidden.
   Plan: store the full body; if the confirm exceeds 3800
   characters, WF-01 sends `reply_text_2` (body) after the card.
   If the architect refuses a second send on WF-01, the fallback
   is a confirm line `Body stored in full; preview omitted for
   length` — that **is** weaker on constraint 2 and must be an
   explicit architect call, not an implementer default.
3. **Pure voice with no command** cannot be met safely before
   Monday (Corollary 1). The command prefix is the safety tax.
   Voice after `/followup` is in scope (7.4+). Intent detection
   inside capture is refused.
4. **Per-file attachment picker** cannot fit in 64-byte
   `callback_data` without a side table of short tokens. Not v1.
   `Send` / `Send without attachments` is the named cut.
5. **`follow_ups.status` should not grow new values.** Digest
   depends on `open/done/cancelled`. Email lifecycle is
   `draft_state`. If the architect wants a single status field,
   WF-07 SQL must change in the same packet — extra blast.

---

## N. What cannot be met safely before Monday

- Phase 8 PWA capture of the follow-up (already refused).
- Intent-detecting a follow-up inside a normal capture voice.
- Per-file attachment toggle on Telegram.
- Wiring WF-01 **before** the 29 Aug gate.
- Schema changes on event days (31 Aug – 3 Sep). 024 must land in
  7.1 this weekend or Phase 7 waits until September.
- A provider benchmark for the drafter (rule 14 still waived).

If 7.4 slips, the owner still has `/flag`, `/ask`, `/digest`, and
Gmail in the morning. Follow-up by hand from the briefing is the
degraded path. That is acceptable. A silent wrong-address send is
not.
