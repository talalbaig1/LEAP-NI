# Packet 7.6 — Voice follow-up

**Date:** 28 August 2026
**Status:** APPLIED 28 Aug 2026 (PACKET 7.6-APPLY, C1–C4).
WF-10 PUT `40c0d5d9-15b8-4ad9-8b60-ff93f88646d8` (100 nodes,
ACTIVE). Voice path proven `execute_workflow` TEST
`LNI-TEST-WF10-voice-exec` `ygHqk6TGlXq7wJvd` (now inactive)
→ WF-10 exec **272059** on real stored `.oga` (Arabic, 18s).
Confirm card Attachments `(none)` — audio filename not listed.
Then **one** WF-01 PUT `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd`
(128 nodes, active). Rollback snapshot remains
`4d4d6e6c-40e1-49ad-80f6-5e67203ce0b3`. There is no sixth
WF-01 PUT. Never send `active`. Strip `binaryMode` /
`timeSavedMode`.
**Depends on:** 7.4-B apply (`docs/plans/phase-07-4-wf01-wire.md`)
for `/followup` Route type, Call WF-10, confirm send, and the
fail send. 7.6 adds the voice path **after** the asset is stored.
**Do not apply from memory.**

Live baseline to confirm before apply (GET, then act):

| Fact | Value |
|---|---|
| WF-01 | `ZMYx19qEr72mJoCX`, `active=true`, **was** `4d4d6e6c-…` (118). After 7.6 PUT: `864bcb8b-8ac1-4fb6-a577-8772ff5e22bd` (128). Rollback target `4d4d6e6c-40e1-49ad-80f6-5e67203ce0b3`. |
| WF-10 | `D9PRjbZMQxe9ESVW`, `active=true`, versionId `40c0d5d9-15b8-4ad9-8b60-ff93f88646d8` |
| WF-03 | `k0bPD3GJBNN2EHDB`, Whisper node `OpenAI transcribe` |
| Route type `[2]` | `Duplicate check` (voice). Length **13**. **Do not intercept.** |
| `executionTimeout` | 300 on WF-01, WF-03, WF-10 |

## Architect corrections C1–C4 (7.6-APPLY, binding)

These override earlier text in this file. Later sections are
amended to match. Reasons stay here so apply does not re-invent.

**C1. Voice kind? reads Insert asset RETURNING `kind`, not
`Attach correlation.kind`.** Classify sets kind on the MESSAGE
type: a `.oga` sent as a document classifies `branch=document`,
`kind=document`, and would never arm the await. `assets.kind` is
what actually landed. GET Insert asset RETURNING first; add
`kind` if it is not already there. Do not assume.

**C2. WF-10 claims, not WF-01.** Draft §1 had WF-01 Claim await
nulling `bot_state` before Call WF-10. Call WF-10 carries
`onError: continueRegularOutput`. If WF-10 throws, the await is
consumed, no draft exists, and re-recording does nothing because
nothing is armed. The owner loses the follow-up silently. WF-01
**reads** the await and passes `awaiting_followup_id` in the
payload. WF-10 claims **immediately before** the Insert draft
UPDATE, conditional on `until > now()`. One writer, and the
writer is the one that can finish the job.

**C3. Expiry must not cancel the `follow_ups` row.** Clear stale
await nulls `bot_state.awaiting_followup_id` and
`awaiting_followup_until` **only**. Leave
`draft_state='awaiting_voice'`. Twenty-one minutes late is not a
reason to destroy a draft the owner may still want; the existing
`confirm_expires_at` path handles real expiry.

**C4. Delete the prompt line "The voice note itself is not a
candidate."** Load candidate assets filters
`kind IN ('photo','selfie')`, so audio is structurally absent.
Telling the model about a category that cannot appear invites it
to reason about one. Structure over prompt.

---

## Owner override (record it as such)

Voice follow-up is **not cut**. The architect cut it the morning of
28 Aug (7.4-PREP-R item 3; this file's predecessor). The owner
reversed that. This is the primary way he intends to use follow-up
at LEAP: standing with someone, immediately after the conversation,
naming attachments aloud.

**Chosen interaction:** `/followup` with **no argument**, then a
voice note.

---

## Binding design constraint — do not design around it

**Store first, then dispatch.** There is **no intercept** at Route
type `[2]`. The voice runs the existing media path unchanged:

```
Duplicate check → Already stored?
  miss → Resolve payload → Call WF-02 resolve media
       → Media capture present? → Mint asset uuid → Mint asset
       → Telegram getFile → Hash sha256 → Prep upload
       → Upload to Storage → Upload succeeded? → HEAD object
       → Object size matches? → Insert asset → Asset row returned?
```

Live GET, node ids: Duplicate check `7aa888721e2a4c5c`, Insert
asset `0e90e16875aa40af`, Asset row returned? `ffa5aa0b9bd74ad9`.

**Only after** `Insert asset` returns an `id` does WF-01 **read**
an active await and Call WF-10. WF-01 does **not** claim (C2).

Reason: a diverted voice note that never becomes an asset is the
one unrecoverable failure in this system. Store-first worst case:
"no draft appeared, audio is safe and replayable."

Call WF-10 on this path: `waitForSubWorkflow: true`,
`onError: continueRegularOutput`. A WF-10 throw must **never**
error the capture execution, and must **not** consume the await
(C2). Capture send (`Send adoption?`) is a **parallel fan-out**
from the same true output, so it is not blocked on Whisper.

---

## Reversal — 7.4-PREP-R item 3

**Old decision (7.4-PREP-R, correct at the time):** `/followup`
with no argument writes **nothing**. Reply was a true usage line.
No `awaiting_voice` row. No `bot_state` await. Reason then: nothing
could claim the voice, so a row was a lie.

**New decision (owner override):** the empty-argument path **does**
write `follow_ups.draft_state='awaiting_voice'` and sets
`bot_state.awaiting_followup_id` + `awaiting_followup_until`.
The claim now exists: this packet, after the asset is stored.

Live WF-10 today (GET): `Usage?` true (name empty) →
`Compose usage` `Usage: /followup <name or email>` → Return.
`Need voice wait?` is only reached when a **name** is present and
`brief` is empty. So `/followup` with no argument currently never
inserts. 7.6 retargets that.

---

## 1. Where the await check attaches on WF-01

Live `connections["Asset row returned?"]`:

```
main[0] (true,  id notEmpty) → Send adoption?
main[1] (false)              → Insert miss terminal
```

`Send adoption?` true → `Send adoption` → `Media stored terminal`
(`00453fa3590d4a2d`).
`Send adoption?` false → `Adoption skipped terminal`
(`f014c33afe864b94`).

Those two terminals **stay**. Do not reroute them through WF-10.
A WF-10 failure must not replace `Media stored terminal` with an
error.

**Attach by fan-out on `main[0]`**, second target in the **same**
array (WF-07 `Scheduled send?` true already does this for Telegram
+ Gmail). After apply:

```
Asset row returned? main[0]:
  [ Send adoption?,          // existing, index in array 0
    Voice kind? ]            // new, same output, parallel
Asset row returned? main[1]:
  [ Insert miss terminal ]   // unchanged
```

**Voice kind?** IF `$('Insert asset').item.json.kind` equals
`audio` (C1). Named node, not `$json`, not
`Attach correlation.kind`. Classify kind is the Telegram message
type; a `.oga` sent as a document is `kind=document` there and
would never arm. GET Insert asset RETURNING first. If `kind` is
absent from RETURNING, add it before this IF.

- false (photo / document / selfie, or `.oga` as document that
  stored as non-audio) → **Voice skip terminal** (NoOp). Await is
  **not** read. Await is **not** cleared.
- true → **Load await** (Postgres).

**Load await** (WF-01 copy of WF-10's query, owner-scoped):

```sql
SELECT b.awaiting_followup_id AS id,
       b.awaiting_followup_until,
       f.person_id,
       f.draft_state
FROM public.bot_state b
LEFT JOIN public.follow_ups f ON f.id = b.awaiting_followup_id
WHERE b.owner_id = $1::uuid
LIMIT 1
```

Do **not** put `until > now()` in this SELECT. WF-01 must tell
expired from unset (see §9). Gate in IF nodes. WF-01 **never**
UPDATEs `follow_ups` and **never** claims (C2, C3):

1. **Await id set?** `id` notEmpty.
   - false → Voice skip terminal. This is a **normal capture
     voice**. No extra Telegram line. See §D.
2. **Await live?** `awaiting_followup_until` dateTime after `now`
   (or string compare of timestamptz; prove in apply). `draft_state`
   equals `awaiting_voice`.
   - false (expired or wrong state) → **Compose await expired** →
     **Send voice followup fail** (reuse 7.4 fail send or a twin)
     → **Clear stale await** (NULL
     `bot_state.awaiting_followup_id` and
     `awaiting_followup_until` **only**. Do **not** set
     `follow_ups.draft_state` or `status` — C3) → Voice skip
     terminal.
   - true → **Voice payload** → **Call WF-10**. No Claim await
     on WF-01.

**Voice payload** (Set):

```
owner_id, correlation_id from Attach correlation
source = 'voice'
file_id from Attach correlation
asset_id from Insert asset (RETURNING id)
storage_path from Insert asset
kind from Insert asset (RETURNING kind)
awaiting_followup_id from Load await (the follow_ups id)
```

Third inbound on 7.4 **Call WF-10** (`waitForSubWorkflow: true`,
`onError: continueRegularOutput`). Then the 7.4 **Followup has
reply?** path (confirm send / fail send). That path's terminals
are the 7.4 NoOps. Capture terminals stay on the Send adoption
fan-out.

**Route type `[2]` stays Duplicate check.** Re-GET it. If `[2]`
is anything else, stop.

---

## 2. Await window

**Propose 20 minutes.** Live WF-10 `Set bot await` is
`now() + interval '15 minutes'`. `Compose record now` says
`(15 min)`. Raise both to 20.

Defend:

- 15 min is the Phase 7 plan number. The owner now photographs a
  whiteboard **then** speaks. Two gestures plus walking off the
  booth floor eat 15 min.
- 60 min would still be live at the next conversation. A later
  voice would be claimed as a brief. Too long.
- 20 min is long enough for photo(s) + a quieter spot, short
  enough that the next booth is a new `/followup`.

**Photo or card during the window must NOT clear the await.**
Explicitly different from 7.4-PREP and from `phase-07-plan.md` §A
("Any photo / document / card on that interval clears the await").
Voice kind? false is a NoOp. Only a **successful WF-10 claim**
(Claim await RETURNING a row, immediately before Insert draft)
ends the armed window. Expiry on WF-01 clears `bot_state`
columns only (C3); the `follow_ups` row stays
`awaiting_voice`.

Compose record now, after apply:

`Record a voice note now (20 min). A photo still goes to capture and does not cancel this.`

No comma / quote / apostrophe in any `stopAndError`. This line is
a send, not a throw; keep it plain.

---

## 3. WF-10 voice path (full)

Live stub (GET): `Route source` `[1]` voice → `Load await` →
`Await present?` **both** outputs → `Compose no await`
(`No follow-up is waiting. Use /followup <name or email>.`).
`Transcribe` exists (`resource=audio`, `operation=transcribe`,
`binaryPropertyName=data`) but is **not reachable** from voice.
`language` is **absent** on that node (verified). Nothing fetches
bytes.

After 7.6, voice `[1]`:

1. **Load await** — keep. Load the follow_ups row by
   `awaiting_followup_id` from the payload (WF-01 already read
   bot_state). If empty / expired → compose §9 `no await` /
   `expired` → Return (`ok: true`, non-empty `reply_text`).
   Never silent. Do **not** claim yet. Do **not** cancel the
   follow_ups row (C3).
2. **Do not claim here.** Bytes, transcribe, person, extract all
   run **before** claim. If any of those throw or fail, the await
   stays armed and a re-record can retry (C2).
3. **Load audio object** — see disagreement §D. Specified path
   below.
4. **Gate: bytes present** — statusCode 200 and binary not empty.
   False → §9 transcription empty (treat as fetch fail).
5. **Transcribe** — copy WF-03 `OpenAI transcribe` exactly:
   - type `@n8n/n8n-nodes-langchain.openAi` v2.3
   - `resource: audio`, `operation: transcribe`
   - `binaryPropertyName` matching the fetch output (`asset` if
     storage GET; `data` if Telegram getFile)
   - **`language` key ABSENT** (not `"auto"`, not `"en"`).
     ElderWise WF-5 trap.
   - `retryOnFail: true`, `onError: continueRegularOutput`,
     `alwaysOutputData: true`
6. **Gate: transcript present** — copy WF-03
   `Gate: transcript present`:
   `$('Transcribe').item.json.text` string notEmpty.
   False → §9 transcription empty. Do not Call WF-03. Do not
   claim a `transcription` job.
7. Person resolution — §5.
8. **Load candidate assets** — §4 (list of 20, not 3).
9. **Load owner cc** — unchanged.
10. **Extract draft** — `prompt_version='wf10-v2'`. Closed
    candidate list in the user message. Schema adds
    `selected_asset_ids` (array of strings) and
    `unmatched_requests` (array of strings). Existing fields stay.
11. **Parse extract** — same envelope walk, same `[`+`]` guard,
    plus: drop any `selected_asset_ids` value not in the candidate
    id set; cap 3; pass `unmatched_requests` through.
12. **Claim await** (C2) — immediately before Insert draft.
    UPDATE `bot_state` SET `awaiting_followup_id` and
    `awaiting_followup_until` NULL WHERE `owner_id` AND id match
    AND `until > now()` RETURNING. Zero rows → treat as expired
    / raced (§9), do **not** UPDATE follow_ups. One writer: WF-10.
13. **Insert draft** — UPDATE the existing `awaiting_voice` row
    to `awaiting_confirm` (person_id, to_email, subject, body,
    attachment_asset_ids, confirm_expires_at). Do **not** INSERT a
    second follow_ups row. Gate RETURNING `id`.
14. **Compose confirm** — §6.

Do **not** write the transcript to `audit_log`.

### Bytes: specified path vs live-safer path

Packet text said Telegram getFile then Whisper. Live fact: WF-01
**already** getFile'd and stored the object. Insert asset
RETURNING includes `storage_path`. Telegram `file_path` from
getFile expires (~1 hour). The durable copy is `lni-assets`.

**Apply this:** HTTP GET, WF-03 `Fetch object bytes` pattern.

- method GET
- URL = same storage bucket prefix WF-03 / WF-10 attach GET already
  use + `storage_path` (do not hardcode the project host in a new
  place; copy the live prefix from WF-10 `GET attach 0`)
- `httpHeaderAuth` credential **Supabase_Leap-NI**
- `responseFormat: file`, `outputPropertyName: asset`
- timeout 60000, `onError: continueRegularOutput`
- Transcribe `binaryPropertyName: asset` (WF-03)

Telegram getFile on WF-10 is the fallback only if storage GET
fails and `file_id` is still valid. If used: `resource=file`,
`operation=get`, **`download: true` explicit**. Live WF-01
`Telegram getFile` currently saves only `resource=file` +
`fileId` — `download` and `operation` are **absent** from the
JSON. workflows.md says they must be explicit. Do not copy that
gap. See §D.

---

## 4. Attachment selection from speech

Live `Load candidate assets` (GET): owner-scoped, `stored`,
`kind IN ('photo','selfie')`, capture linked via `interactions`
for that person, `ORDER BY created_at DESC LIMIT 3`. Filename =
`reverse(split_part(reverse(storage_path), '/', 1))`. No
`filename` column on `assets`.

For voice extract, **load 20** (same WHERE, `LIMIT 20`). Send cap
stays **3**. The model **selects**; it does not invent.

Pass into Extract, closed list, one line per row:

```
id=<uuid> kind=<kind> filename=<filename> capture_no=<n> created_at=<iso> size_bytes=<n>
```

`capture_no` requires JOIN `captures` on `a.capture_id`. Add it
to the SELECT.

**Prompt contract (wf10-v2), additions only:**

- You are given a CLOSED candidate list. `selected_asset_ids` may
  contain only `id` values copied from that list. Maximum 3.
  Never invent an id. Never invent a filename.
- If the owner names a thing that is not in the list, put a short
  phrase in `unmatched_requests` (example: `whiteboard video`).
  Do not substitute a different asset.
- If the owner names nothing, `selected_asset_ids` is `[]` and
  `unmatched_requests` is `[]`.

Do **not** prompt "the voice note itself is not a candidate"
(C4). Audio is structurally absent from the closed list
(`kind IN ('photo','selfie')`). Telling the model about a
category that cannot appear invites it to reason about one.

Parse extract drops any id not in the list, then slices 3. Those
ids become `attachment_asset_ids` on the UPDATE.

**Unmatched on the confirm card**, plain line:

`Could not match: <unmatched_requests joined by semicolon>`

If the list is empty, omit the line. Never silent-drop a named
miss.

Omitted-for-size (18 MB) stays the existing `Omitted (too large):`
line from 7.3b.

---

## 5. Person resolution from the transcript

Same ladder as typed `/followup` / `/flag`: exact
`email_normalized`, then exact `full_name` case-insensitive, then
trigram `similarity >= 0.4`. Max 5. `count(*) OVER()::int AS
hit_count`. NEVER guess.

- Empty `/followup` insert has `person_id` NULL (PARTIAL CHECK
  allows this on `awaiting_voice`). Extract `recipient_ref` from
  the transcript. `"none named"` or empty → §9 no person.
- `/followup Ahmad` then voice: row already has `person_id`. Skip
  the ladder. Extract still runs for subject/body/attachments.
- 2+ hits → Compose many, buttons `f7:p:<person uuid>`,
  `<name> (no email)` when email is null. 64-byte
  `callback_data` cap: `f7:p:` (5) + uuid (36) = 41. Holds.
- 1 hit, no email → existing no-email text. No draft to confirm.
- 1 hit, email present → continue to candidates + extract.

`f7:p:` callback path on WF-10 is already built. Do not invent a
second picker.

---

## 6. Confirm card (voice path)

Unchanged rule: the owner approves the **recipient**.

Same compose as typed (plain text, real newlines, no `parse_mode`
on WF-01):

```
Follow-up draft
To: <full email>
CC: <owner auth.users.email>
Subject: <subject>

<body>

Attachments: <filenames or (none)>
Could not match: <…>          # only if unmatched_requests nonempty
Omitted (too large): <…>      # only if size drop happened
```

Buttons unchanged: `f7:s:<id>` Send, `f7:n:<id>` Send without
attachments, `f7:x:<id>` Cancel.

`reply_text_2` if over 3800, per 7.4 §7.

---

## 7. The voice note is a capture asset, not an email attachment

Insert asset already stored it (`kind='audio'`). Candidate SELECT
is `kind IN ('photo','selfie')` only. The audio id cannot appear
in `selected_asset_ids`. Do not add `audio` to that IN list.

WF-03 still transcribes it later as a normal capture job. That is
independent. WF-10 must not claim a `transcription` job.

---

## 8. Timing

Parent WF-01 `executionTimeout: 300`. Child WF-10 `300`.
`waitForSubWorkflow: true` on the Call. Fan-out means Send
adoption can finish while WF-10 runs.

Budget (one 60 s Telegram voice, worst case on this instance):

| Step | Bound |
|---|---|
| Storage GET (or getFile) | 10 s (node timeout 60 s) |
| Whisper | ~3 s for 8 s audio (exec C5, 26 Aug); budget 30 s for 60 s audio |
| Extract gpt-4o-mini | 20 s |
| Lookup + compose | 5 s |
| **Total WF-10** | **~65 s typical worst** |

300 s holds with margin. Telegram voice notes are usually << 60 s.
If Whisper hangs, `onError: continueRegularOutput` on Transcribe
and on Call WF-10: capture stays success, owner gets §9 fail text.

Do not raise `executionTimeout`. Do not add a Wait.

---

## 9. Failure modes — none silent

Silence remains reserved for **storage** failure (upload / HEAD /
insert miss already `stopAndError` or send nothing, `prd.md` §5).
Follow-up failures send a line.

| Mode | When | Owner text |
|---|---|---|
| No await set | WF-10 `source=voice` and no live `awaiting_voice` row | `No follow-up is waiting. Send /followup then a voice note.` |
| Await expired | id set, `until <= now()`, or `draft_state` not `awaiting_voice` | `Follow-up wait expired. Send /followup again then a voice note.` |
| Transcription empty | fetch fail or Whisper `text` empty | `Could not transcribe that note. The audio is saved. Try the voice again.` |
| No person matched | 0 ladder hits, or `recipient_ref` none named | `No person matches that note. Try /followup with a name or email.` |
| Named attachment not found | `unmatched_requests` nonempty | On the **confirm card**, not a stop: `Could not match: …` Draft still offered. |
| WF-10 unreachable / throw | Call WF-10 continued on error, or `ok` false / empty `reply_text` | `Follow-up failed. Nothing was sent. Try again.` (7.4 fail send) |

**Normal capture voice (never armed):** WF-01 Voice kind? true
(Insert asset `kind='audio'`), Await id set? false → Voice skip
terminal. **No extra text.** That is not a follow-up failure.
See §D.

2+ people is not a failure: disambiguation buttons, existing
compose.

---

## 10. Read-back checklist (architect, not the implementer report)

**WF-01 (after apply PUT, no `active`, strip `binaryMode` /
`timeSavedMode`):**

1. GET name `LNI WF-01 - Telegram ingest router`. `active=true`.
2. Route type `[2]` still `Duplicate check`. Length after 7.4 is
   13; `[2]` must not have moved.
3. Media chain Duplicate check → … → Insert asset → Asset row
   returned? **unchanged** except `main[0]` has **two** targets:
   `Send adoption?` and `Voice kind?`.
4. `Send adoption` still → `Media stored terminal`.
   `Send adoption?` false still → `Adoption skipped terminal`.
5. Call WF-10 `onError === continueRegularOutput`,
   `waitForSubWorkflow === true`.
6. Voice kind? false does not touch `bot_state`. Voice kind?
   reads Insert asset RETURNING `kind`, not Classify / Attach
   correlation (C1). WF-01 never claims (C2).

**WF-10:**

7. `language` absent on Transcribe (and on any new transcribe
   node). GET the saved JSON; do not trust the UI default.
8. `Await present?` both-to-no-await is **gone**. True path
   reaches bytes + Transcribe. **Claim await** runs immediately
   before Insert draft, not before Transcribe (C2).
9. `Usage?` true (empty `/followup`) inserts `awaiting_voice` and
   sets bot_state, does **not** stop at Compose usage.
10. `Set bot await` interval is `20 minutes`. Compose record now
    matches.
11. Extract schema is `wf10-v2` with `selected_asset_ids` and
    `unmatched_requests`. Prompt version column `wf10-v2`.
12. Load candidate assets for extract is LIMIT 20. Insert/update
    draft still caps 3 ids.

**Live (after gate, on the allowlisted bot):**

13. Photo **without** `/followup` — asset stored, no follow_ups
    insert, await columns null.
14. `/followup` no argument — `awaiting_voice` row, bot_state set,
    reply is the record-now line. No email.
15. Photo **during** the window — asset stored, await **still
    set**, no draft confirm yet.
16. Voice **during** the window — asset `kind=audio` stored
    (`Insert asset` RETURNING), then confirm card. Audio filename
    is **not** on the Attachments line.
17. Voice **after** expiry — asset stored, expired text,
    `bot_state` await columns null, `follow_ups.draft_state`
    still `awaiting_voice` (C3). No confirm.
18. Voice **never armed** — asset stored, **no** extra follow-up
    text.
19. Named attachment not in the list — confirm card has
    `Could not match:`.
20. Force WF-10 throw — capture execution success, owner gets the
    7.4 fail line, audio row remains, **await still armed**
    (C2: WF-01 did not claim).

---

## Empty `/followup` on WF-10 (command path change)

Retarget live `Usage?` true from `Compose usage` to the awaiting
insert:

- `person_id` NULL (do not read Lookup people; it did not run).
- `Insert awaiting voice` queryReplacement must tolerate NULL
  `$2` (`$2::uuid` with JS `null`).
- Then Set bot await 20 min, Compose record now.
- Keep Compose usage for a later typed-only help if needed; it is
  not the empty-command path anymore.

`/followup Ahmad` with no brief stays `Need voice wait?` true
(live: brief empty only — it does **not** check
`source=command` despite `workflows.md`). Leave that IF. Named
await still works: person is already on the row; voice skips the
ladder.

---

## D. Disagreements (with evidence)

1. **Telegram getFile as the Whisper source, after we stored the
   object.** Packet asked for getFile. Live Insert asset already
   RETURNING `storage_path`. WF-03 `Fetch object bytes` is the
   proven transcribe input (`outputPropertyName: asset`,
   `binaryPropertyName: asset`). Telegram `file_path` expires.
   **Recommend storage GET as primary.** getFile is fallback.
   Copying live WF-01 getFile would also copy a gap: saved JSON
   has no `download: true` and no `operation: get` (GET 28 Aug,
   node `c0902bc16a2c4ab7`). workflows.md says those must be
   explicit.

2. **`no await set` extra text on every capture voice.** Packet
   said none of the failure modes may be silent. A meeting voice
   with no `/followup` is not a follow-up failure. Extra text
   would train the owner to ignore the bot. WF-01 skips. WF-10
   still returns the no-await line if `source=voice` is called
   without a row (execute_workflow / race).

3. **Phase 7 plan / 7.4-PREP: photo clears await.** Owner override
   plus this packet: photo must **not** clear it. Evidence of the
   old text: `phase-07-plan.md` §A; 7.4-PREP-R §8. Recorded as
   reversed, not silently kept.

4. **`Need voice wait?` vs `workflows.md`.** Docs say
   `brief empty AND source equals command`. Live GET: **brief
   empty only**. Do not "fix" that in 7.6 unless the architect
   asks. Empty `/followup` is handled by retargeting `Usage?`,
   which is the live gate that actually fires.

5. **`Insert awaiting voice` binds Lookup people id.** Empty
   `/followup` never runs Lookup. Apply must change
   queryReplacement. Leaving it would throw or bind the wrong
   person. Not optional.

6. **Candidate LIMIT 3 is too small for speech selection.** Live
   LIMIT 3 is the **send** cap. A closed list of 3 means "the
   whiteboard photo" is often not in the prompt. Load 20, select
   3. Send cap unchanged.

7. **C1–C4 (architect, 7.6-APPLY).** Voice kind from Insert
   asset RETURNING, not Classify. WF-10 claims immediately
   before Insert draft, not WF-01 before Call. Expiry clears
   bot_state only. No prompt line about the voice note. These
   override draft §1 / §3 / §4 / §9.

---

## What this file is not

- Not a Route type `[2]` intercept.
- Not a new migration (024/025 already have `awaiting_voice` and
  bot_state columns).
- Not a change to WF-03 claim/transcription jobs.
- Not a BotFather change (`/followup` is already on the bot).
- Not a sixth WF-01 PUT. One PUT after WF-10 is proven. Rollback
  on any read-back failure.

Apply order (PACKET 7.6-APPLY): amend this file → merge → GET
WF-01 confirm `4d4d6e6c-…` → build and prove WF-10 via
`execute_workflow` on a real stored audio asset → **one** WF-01
PUT → section 10 checklist, all 20 items. Evidence from
executions and the phone, never node config. Item 16 must show
the audio filename is **not** on the Attachments line.
