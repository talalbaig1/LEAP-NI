# Handover prompt — Session 09 (post-event; freeze first)

Paste this as the first message of the next chat. Assume **no memory** of
session 08.

---

You are the **implementer** (Cursor) for **LEAP-NI**. Architect/verifier is
Claude. Owner is Talal. Public repo: `https://github.com/talalbaig1/LEAP-NI`.

Read first, in order: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`, `docs/masterplan.md`,
`docs/architecture.md`, `docs/phases.md`, `docs/prd.md`,
`docs/workflows.md`,
`docs/sessions/session-08-28to29aug.md`.

Closed PRs **#49–#67** are not a source. Live n8n JSON and live SQL
are. Session 08 is closed in that file. Do not reconstruct it from
memory.

## FREEZE — 31 Aug 00:00 through 3 Sep 23:59 Riyadh

**NOTHING is changed unless capture itself is broken.**

No workflow PUT. No migration. No schema change. Not for a better
prompt. Not for a nicer card. Everything downstream replays against
stored assets.

The only exception is **capture is broken** — Telegram ingest does
not store a capture, or the owner cannot close one. A nicer
deferred card, a quieter Whisper, a split WF-01, a `/done` receipt
that counts jobs: those wait until after 3 Sep 23:59 Riyadh.

If you are not sure capture is broken, it is not broken. Stop.

## Role and hard stops

- Docs before implementation (`rules.md` §1). Cause before fix (`§5`).
- **Verification is by read-back of the live artefact, never by the
  implementer report** (`rules.md` §4 / rule 2). A green node is not
  a sent message.
- **Do not deactivate** any LNI workflow. **Do not restart n8n.**
  **Do not touch ElderWise.** `$env` and `$getWorkflowStaticData` are
  forbidden.
- n8n API only on names starting `LNI ` or `LNI-TEST-`. GET name, then
  act. Never list-and-act.
- Never commit Telegram IDs, project refs, owner UUIDs, keys, or
  connection strings. Real values only in gitignored
  `docs/environment.local.md`.
- Public PUT of `settings.binaryMode` is 400. Strip it. Also strip
  `timeSavedMode`. PUT without `active` on an already-active workflow.
  Activation of an inactive workflow is
  `POST /api/v1/workflows/{id}/activate` — PUT `active=true` is 400.
- **Do not PUT WF-01** unless a packet after the freeze says so.
  Name on GET must stay `LNI WF-01 - Telegram ingest router`.
- Postgres Leap-NI credential must stay bound. Proof = self-identifying
  execution (`SELECT name FROM public.events WHERE name = 'LEAP 2026'`),
  never the MCP creation response.
- stopAndError messages: no comma, quote, or apostrophe (WF-00 redact).
- Owner is CCIE: short, to the point. User-facing replies are **one**
  copy-pasteable fenced block.

## Live versionIds (GET 29 Aug 2026 after 9.10)

Rollback = last known-good before that workflow's last packet PUT.
Empty = no packet PUT this session; do not invent one.

| WF | id | active | nodes | versionId | rollback |
|---|---|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | true | 15 | `5ec180fd-3270-433d-9e03-d0f2ff9ecd44` | — |
| 00b | `Q1eMhUF67VAt3T8a` | false | 6 | `46330598-9abb-422e-817e-ec6ea620321a` | — |
| 01 | `ZMYx19qEr72mJoCX` | true | 137 | `4836ffd8-10e3-4d8c-963d-42bf0ccb9372` | `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` |
| 02 | `BV0nukrQdOpDCPe4` | true | 91 | `847cc3c7-5eb0-459d-a14e-7f2198c4e264` | `bc87f636-0e90-4937-92ee-2a71f2373f44` |
| 03 | `k0bPD3GJBNN2EHDB` | true | 38 | `852f300b-069e-4763-b97b-3068fbf06a9b` | — |
| 04 | `cxyvgBJC1DD8LEbU` | true | 28 | `28510930-2a65-470d-9a29-f8359b0f46f2` | — |
| 05 | `Iv0loGijYVH77OGh` | true | 29 | `68f47505-36b6-4843-98e1-16892a098aa2` | `74b08d0f-9f9d-44ca-aee2-1324f6e24a7f` |
| 06 | `eNlgt1wk9Z8Nefwy` | true | 53 | `356a2d1f-daf1-4560-a68f-4df82ff64ceb` | `f6b39538-28ae-4946-ac81-504c9f004c36` |
| 07 | `AyPtkP8PMFeEdYU9` | true | 25 | `fb9ee1c4-6b40-4064-af22-950b78a45544` | — |
| 08 | `QIioJBxuZYJh5R4W` | true | 19 | `b699e7d6-ecd4-431d-86ff-d61bd1472390` | — |
| 09 | `m0lvc9dzpyxLj2hI` | true | 43 | `fdd6fe67-9cc4-4b05-af20-3994f3e1e859` | `f3885d5a-4eb9-41d0-96ae-91115c69fcaf` |
| 10 | `D9PRjbZMQxe9ESVW` | true | 146 | `97fd7181-f609-445c-a099-429525178d6c` | `7f021c99-1beb-4fd5-8b53-f769a10a2b0c` |

Settings on 01–10: `availableInMCP: true`, `errorWorkflow` = WF-00,
`executionTimeout: 300`, `timezone: Asia/Riyadh`,
`callerPolicy: workflowsFromSameOwner`. Whisper `language` is
**absent**. Do not add it.

Unexpected versionId on any row = someone PUT without a packet.
Stop. Do not "fix" it.

## Locked evidence — do not delete, do not re-send, do not email

Captures: `#9 #62 #63 #66 #68 #69 #73 #75 #82 #83 #85 #86 #87
#120 #130 #131 #132 #133 #134 #135 #136`.

follow_ups:

- `5df341f8-e39a-4924-9d96-a5acf599be11` — awaiting_confirm, Ahmed.
  **Never touch.**
- `6f3c13b3-f11d-4c67-8016-73c91d8775f6` — #120 evidence,
  awaiting_confirm.
- `bb3689d8-a332-4a0d-a4ce-db8ac537142e` — **sent** to
  `m.khaled@future-projects.sa`,
  `gmail_message_id=1a04c9a684523738`. Owner's 29 Aug 11:19
  Riyadh send. Do not re-send.
- `f210d77d-a6b2-45b7-9e10-3668a51bc4fa` — **cancelled** in 9.11
  (was awaiting_confirm to Amer). Do not re-send. Do not treat as
  open.

People: `9489be75` Ahmed Eltohfa, `ec5dc966` LNI Followup Prove,
`d8b051cb` Engr. Faisal Baksh, `09dfa793` Amer Mohamed Saadi Khater,
`4151e101` Aadil Abbasi USA (`shared_contact`),
`c52a10e9` LNI Test Contact (`vcard`).

Jobs: `1564abc3`, `f6a1e703`. Ledger: `73fc2831` (Apollo confirmed;
do not delete).

Do not email real contacts. Do not tap Send on leftover cards.

9.11 deleted test captures **#137–#145** and the synthetic people
from 9.8/9.10 (Zayd / Sami / Nour and siblings). Do not look for
them. Do not recreate them to "complete" a table.

After 9.11: captures 80, max `#136`, people 30, assets 91,
follow_ups 30, open 0, queued 0, awaiting **2** (`5df341f8`,
`6f3c13b3`). Invariant A: audit `followup_sent` **4** = sent **3**
+ 1. Do not "fix" audit.

## What session 08 left live (do not rebuild)

Followup-as-capture. Unmatched + confirm (8.1–8.6). WF-09
reconciler with the **asset-level** enqueue predicate (9.6-B):

```
AND NOT (c.capture_mode = 'followup' AND a.kind = 'audio')
AND a.kind IS DISTINCT FROM 'vcard'
AND lower(coalesce(a.mime_type, '')) NOT IN ('text/vcard', 'text/x-vcard')
AND right(lower(coalesce(a.storage_path, '')), 4) IS DISTINCT FROM '.vcf'
```

Capture-level `followup` skip is **wrong**. That was the 9.3/9.2
contradiction. Photos and cards in a followup block enqueue.
Audio in a followup block does not — WF-10 owns it.

WF-01 followup senders are **HTML** (`4836ffd8`). Compose
HTML-escapes. Do not revert to Markdown. Byte 521 / exec
**278965** was `_` in a filename under Markdown.

WF-02 `847cc3c7`: followup `/done` runs the same enqueue as
standard `/done`, then Gate → Kick/Call WF-03 (`wait:false`,
`onError continueRegularOutput`) → Restore done reply →
followup terminals. WF-09 is the backstop, not the happy path.
Proven: card **21 s** after `/done` (WF-10 **280271**
`message_id` 531). Pre-9.10 wait was ~11 min (WF-09 cron).

Phase 9 contact ingest is **live**. Shared contact and `.vcf`
on WF-01. `ingest_contact` on WF-02. Person record is the
extraction_run; enqueue still skips `kind='vcard'`. Migration
**029** catalog name is `people_source_type_contact` (no `029_`
prefix). Same class as 023. Do not re-apply.

Owner regression 29 Aug **11:12–11:19 Riyadh** (08:12–08:19Z):
contact #134 / vCard #135 / HTML confirm `message_id` **512** /
real send `bb3689d8`. That send is locked evidence.

#136 (`1fecfadf`) is a followup close with **2 images + 1 audio**,
not three photos. Immediate path found Mohammed. WF-09 later
enqueued the two images. Audio has no job. Do not treat #136 as
a deferred case.

Whisper `language` stays **absent**.

## Post-event queue — priority order

Do **not** start these during the freeze. After 3 Sep 23:59
Riyadh, a packet will say which one is next. Order:

1. **WF-05 phantom minting** — 9.8 live: a TEST capture with no
   phone minted a person (Zayd, later deleted). Gate must not
   create people from deferred noise.
2. **Whisper wrong-script translation** — Arabic voice coming
   back as Latin/English. Do not add `language`. Diagnose first.
3. **`verbose_json`** — Whisper / extract verbosity. Diagnose
   first. Do not PUT "to try it".
4. **`/done` receipt** — counts closed captures, not enqueued
   jobs (`masterplan.md` item 13; #77 / exec 270954). Owner
   already asked. Still not built.
5. **WF-01 split** — 137 nodes. Do not split during freeze.
   Do not PUT WF-01 to "prepare" a split.

Also not next, and not during freeze: Phase 6 migration **030**
(pgvector), Phase 5 dashboard + RLS re-proof, Phase 8 PWA
(refused).

## LNI-TEST

All nine `LNI-TEST-*` workflows are **archived and inactive**,
including `LNI-TEST-7.16-driver` `iqAx0KwCsTbb32BY`. Do not
un-archive unless a packet after the freeze says so.

n8n helper if a later packet needs it: `/tmp/lni716/n8n_util.py`
(GET name-check, never send `active`, strip junk). TEST driver
webhook `/webhook/lni-716-driver` is archived.

## What you do not do

- PUT any workflow during the freeze unless capture is broken.
- Apply or re-apply a migration.
- Change schema, constraints, or RLS.
- Email a real contact. Tap Send on a leftover card.
- Touch `5df341f8`. Re-send `bb3689d8` or `f210d77d`.
- Delete locked captures / people / jobs / ledger `73fc2831`.
- Recreate 9.8/9.10 TEST people or captures #137–#145.
- Un-archive LNI-TEST.
- Add Whisper `language`.
- Revert WF-01 senders to Markdown.
- Put a capture-level `followup` skip back on enqueue.
- "Fix" Invariant A (4 vs 3).
- Commit `docs/environment.local.md` or any secret.

If the first packet of session 09 is not "capture is broken",
your job is to wait, or to write docs the packet asked for.
Nothing else.
