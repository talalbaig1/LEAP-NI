# Phase 15 — Transcription quality

**Date:** 16 Sep 2026
**Status:** SPIKE recorded (12.5j). TEST archived.
**Home:** this file. Stub in `phases.md` Phase 15.
WF-10 contract unchanged: `docs/workflows.md` Transcribe
(`language` absent, no `verbose_json` on the live node).

This is **not** a Phase 12 packet. 12.5g/h left the
garble gate unable to catch non-Latin garbage and left
`verbose_json` logged as session 08 item 3. The
question here is whether a **different transcribe
call** recovers the trilingual clip. If it does not,
the evidence pane stays the defence.

## Non-goals

- No PUT of WF-10, WF-01, WF-02, WF-03, WF-05, WF-06,
  WF-09.
- No change to the live Transcribe node.
- No `language` key on any transcribe call (trap
  locked: forcing English yields confident garbage).
- No garble heuristic.
- No `verbose_json` on live WF-10.
- No canvas. No pin. No webhook. Do not activate the
  TEST. Do not edit follow_ups `96461882` or
  `2fd8c529`.

## Input (one clip)

Capture **#214** re-run audio. Asset `0982a7df`,
`kind=audio`, `mime audio/ogg`, `size_bytes` **51978**,
`upload_status=stored`. Real Storage GET, never a
pinned fixture. Phase 1: a pin is inline base64; a
real download is `data: "filesystem-v2"`. They are
different programs.

HEAD `Content-Length` must equal `51978`. Disagree is
a defect; the run stops.

Hint B is built at run time from the capture's
resolved person and company plus the event name LEAP.
Names are not literals in this file.

## TEST workflow

Name: `LNI-TEST-15.0-transcribe`. **Archived 16 Sep
(12.5j). Do not delete.**

Manual Trigger only. `active=false`. No webhook.
`availableInMCP: true` so MCP can fire Manual Trigger.
`errorWorkflow` = WF-00. Timezone `Asia/Riyadh`.
`executionTimeout` 300.

REST-created. MCP `create_workflow_from_code` auto-binds
ElderWise — forbidden here. Credentials on the saved
JSON: Postgres **Leap-NI**, HTTP **Supabase_Leap-NI**,
OpenAI **OpenAi account**. First node after Manual is
Self identify (`SELECT name FROM public.lni_instance`,
gate `NIS`).

HTTP Request, not the Whisper / OpenAI audio node.
OpenAI calls use `predefinedCredentialType` `openAiApi`
on HTTP Request (unproven before this spike; the
failure is itself a result).

Graph is specified in `docs/workflows.md`
`LNI-TEST-15.0-transcribe`. Fan-out A/B/C/D from
**GET audio** so each call still holds binary `asset`.
Named-node sourcing after every I/O.

## Comparisons

All four: same bytes. No `language` field.

| Arm | Call | What we read |
|---|---|---|
| **A** | `POST /v1/audio/transcriptions` model `whisper-1`, `response_format=verbose_json` | Claimed `language`. Segment-level field names. `text`. |
| **B** | A plus multipart `prompt` naming LEAP, loaded `full_name`, loaded company | Do those nouns appear in `text`? |
| **C** | Same endpoint, model = live pick from `GET /v1/models` (`gpt-4o-transcribe` if present, else `gpt-4o-mini-transcribe`, else first id containing `transcribe`) | Same fields as A. Do not trust a remembered model id (Phase 2 Gemini stale id). |
| **D** | Audio-capable chat / Responses model from the same live list, asked for (1) a faithful transcript that keeps each language as spoken and (2) an English rendering | File upload `POST /v1/files` then `file_id`. Code cannot read filesystem-v2, so inline base64 is not a legal D. If the live model rejects the file, report that. |

## Per-arm record

For each arm that returns a body:

- raw `text` / message (session report; **not** copied
  into this file if it holds a contact name)
- Latin letter count (A–Z a–z) and Arabic-script
  count (U+0600–U+06FF)
- English portion survived? (clear English words, not
  merely Latin letters)
- books / study-together ask present?
- A/C only: detected `language`; keys on
  `segments[0]`

## Decision rule

Recommend the smallest change that recovers
trilingual speech **on this clip**, with the numbers
attached.

- If C (or B) recovers English + the books ask and A
  does not: say so. Live WF-10 still does not change
  in this packet; that would be a later apply packet.
- If D is the only arm that keeps languages **and**
  yields English: say so, and say whether file-id
  chat is usable on this instance.
- If none recover trilingual speech: say so in those
  words. The evidence pane is the only defence. That
  is an acceptable product answer when it is true.

Do not add `language: en` to "fix" mixed audio.

## Acceptance

- TEST exists, inactive, name
  `LNI-TEST-15.0-transcribe`, Manual only, no webhook,
  `availableInMCP: true`, `errorWorkflow` = WF-00,
  Leap-NI creds, Self identify gate `NIS`.
- One execution on the real #214 object.
  `filesystem-v2`. HEAD `Content-Length` = 51978.
- Model id for C (and D) taken from that run's
  `GET /v1/models`, not from training data.
- No `language` key on A/B/C. GET of WF-10 published
  still `dfd35bfb`. Transcribe params unchanged.
- This file records counts, language, segment keys,
  English-survived, books-ask, and the
  recommendation. Raw contact names stay out of git.

## Result (16 Sep 2026)

TEST `LNI-TEST-15.0-transcribe`, inactive, Manual only.
Self identify `NIS`. Asset `0982a7df`, capture **#214**,
`filesystem-v2`, HEAD `Content-Length` **51978** =
`size_bytes` **51978**. Execs **486506** (first),
**486521** (`.ogg` rename + D `gpt-4o`), **486532**
(C `json`). No `language` key on A/B/C. WF-10
published still `dfd35bfb`. Transcribe params
unchanged. WF-01 `4836ffd8` / draft `e454df40`.
WF-06 `356a2d1f` / draft `76840a2a`.

Live `GET /v1/models` (same runs): transcribe ids
include `gpt-4o-transcribe` (picked),
`gpt-4o-mini-transcribe`,
`gpt-4o-transcribe-diarize`, `gpt-transcribe`,
`gpt-live-transcribe`. Audio-chat ids include
`gpt-audio` (picked), `gpt-audio-mini`,
`gpt-audio-1.5`.

### A — `whisper-1` `verbose_json`

- Claimed `language`: **urdu**. `duration` 13.21 s.
  One segment.
- Segment-level fields: `id`, `seek`, `start`,
  `end`, `text`, `tokens`, `temperature`,
  `avg_logprob`, `compression_ratio`,
  `no_speech_prob`. Top-level also `task`,
  `usage`.
- Latin **0** / Arabic-script **101**.
- English portion survived? **No.**
- Books / study-together ask? **No.**
- Card person name appeared in Urdu script
  without a hint. Company and event names did
  not. Body is a garbled follow-up/meeting
  paraphrase (`avg_logprob` about **-0.63**).

### B — `whisper-1` + proper-noun `prompt`

- Claimed `language`: **english** (flipped).
- Latin **101** / Arabic-script **0**.
- English words? **Yes, but steered.** Whisper
  `prompt` is a transcript **prefix**, not a
  hint. An English prefix continued in English.
  `avg_logprob` about **-0.30** (more confident,
  less faithful).
- Person name recovered in Latin. Company and
  event names from the same prompt **did not**
  appear.
- Books / study-together ask? **No.**
- Output is an English “create a follow-up …
  meeting … any day available” instruction, not
  mixed speech.

### C — live `gpt-4o-transcribe`

- Telegram `.oga` rejected (`unsupported_value`
  file). Same filesystem-v2 bytes with
  `fileName` remapped to `clip.ogg` (metadata
  only; Code did not read bytes) accepted.
- `verbose_json` rejected on this model
  (“use `json` or `text`”). Exec **486532**
  used `json`.
- No `language` field, no `segments` (json
  format). Latin **0** / Arabic-script **89**.
- English portion survived? **No.**
- Books / study-together ask? **No.**
- Person name in Urdu. Body is a more fluent
  Urdu meeting/follow-up paraphrase with a
  broken English loan (“follow up”), still not
  the spoken mix.

### D — audio chat

**Not yet proven. Untested, not impossible.**

- File upload `POST /v1/files` worked
  (`purpose=user_data`, 51978 bytes).
- Live `gpt-audio` is not on the Responses API.
- `gpt-4o` Responses `input_file` rejects audio
  (document list only).
- Chat `input_audio` wants inline base64. **Code
  cannot read filesystem-v2.** That is the block
  this spike hit.
- `extractFromFile` `binaryToProperty` is a
  **node**, not Code. It was not in the TEST
  graph. Untested on a real stored object. Do
  not record D as impossible until that node is
  measured.

## Locked non-goals (12.5j)

- **No `language` key on Transcribe.** The owner
  speaks three languages. Forcing one yields
  confident garbage (trap 1).
- **No Whisper prompt hint.** Measured: B raises
  confidence (`-0.30` vs A `-0.63`) and lowers
  fidelity (invented a meeting, dropped the books
  ask, missed LEAP and the company). A clean
  wrong transcript defeats the evidence pane —
  worse than a visibly garbled one.
- **No swap to `gpt-4o-transcribe` on the live
  path.** Telegram sends `.oga`; C rejects that
  format and loses the same English / books
  content anyway.

## Open finding (no build)

Transcription detects **one language per clip**.
A follow-up block already accepts multiple audio
assets. One language per voice note may preserve
all three where one mixed note cannot. Owner to
try on the next real follow-up. If it holds, it
becomes a product rule and an onboarding
instruction.

## Recommendation (A/B/C)

None of A/B/C recovered trilingual speech on
this clip. **The evidence pane is the only
defence** for mixed notes until the open finding
is tried, or D is measured with
`extractFromFile`. That is the true answer for
A–C, not a deferral of the locked non-goals.

TEST `LNI-TEST-15.0-transcribe` **archived**
16 Sep (12.5j), not deleted. Follow_ups
`96461882` / `2fd8c529` untouched. No live PUT.
