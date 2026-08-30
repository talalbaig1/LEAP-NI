# Cursor handover — Session 09 (implementer to implementer)

Paste this into a **new Cursor window** together with
`docs/sessions/handover-to-session-09.md`. Assume no memory of
session 08. You are the implementer. Architect/verifier is Claude.
Owner is Talal.

Public repo: `https://github.com/talalbaig1/LEAP-NI`.

**SESSION 09 IS A LIVE-EVENT INCIDENT SESSION.** The owner is at
LEAP on his phone. Freeze is in force. Only a broken capture path
justifies a change. Triage before diagnosis, diagnosis before fix,
smallest possible change, one workflow, named rollback, regression
on the owner's phone.

Read first: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`,
`docs/sessions/handover-to-session-09.md`,
`docs/sessions/session-08-28to29aug.md`,
`docs/workflows.md`. Live JSON and live SQL beat this file.
Secrets stay in gitignored `docs/environment.local.md`. Never
commit it. Never copy a secret into chat or a tracked file.

This file is what a report would not carry: the REST shapes that
work on this build, the TEST-driver wrapper that failed Allowlist,
the enqueue copy, the send-path contract, and what to do first if
capture dies on the floor.

---

## 1. n8n REST — exact shapes that work

Base: `N8N_BASE_URL` (no trailing slash). Every call:

```
X-N8N-API-KEY: <key from environment.local.md>
Accept: application/json
```

PUT/POST also `Content-Type: application/json`.

Helper on this VM (not in git): `/tmp/lni716/n8n_util.py`.
`get_wf` name-checks `LNI ` / `LNI-TEST-`. `sanitize_for_put`
keeps only `name`, `nodes`, `connections`, `settings`.

### GET

```
GET /api/v1/workflows/{id}
```

Read `name` first. Wrong prefix → STOP. Then read `versionId`,
`active`, `nodes.length`, `settings`. Unexpected `versionId`
means someone PUT without a packet. Do not "fix" it.

```
GET /api/v1/executions/{id}
GET /api/v1/executions?workflowId={id}&limit=N
```

Proof is `runData`, `lastNodeExecuted`, Telegram `message_id`,
Gmail `id`. A green node is not a sent message.

### PUT

```
PUT /api/v1/workflows/{id}
```

Body: `{ name, nodes, connections, settings }` only.

**Must strip (public PUT is 400):**

- top-level `active` (read-only on this build)
- `versionId` (read-only; omit it)
- `settings.binaryMode` (GET shows `"separate"`; sending it 400s)
- `settings.timeSavedMode` (additional property, 400)
- also drop `createdAt`, `updatedAt`, `shared`, `tags`,
  `triggerCount`, `isArchived`, `meta`, `pinData`, `staticData`

Settings that stick: `timezone` (`Asia/Riyadh`), `errorWorkflow`
(WF-00 `X7zKL3wTFPIhwyaN`, never ElderWise), `executionTimeout`
(300), `availableInMCP` (true), `callerPolicy`
(`workflowsFromSameOwner`), `executionOrder`.

**Already-active workflow:** PUT without `active`. The workflow
stays active if you do not send the field.

**jsxCode via REST:** double every backslash, or write patterns
with none. Single `\b` is a backspace. Proven WF-08
`want_contact`.

### POST /activate

```
POST /api/v1/workflows/{id}/activate
```

This is how an **inactive** workflow is published. PUT
`"active": true` returns **400**
`request/body/active is read-only` (packet 4.8, WF-06).

Never `POST /activate` on WF-01 (already active). Never
deactivate to "test". Never restart n8n.

### What 400s and why

| Call | Why |
|---|---|
| PUT `"active": true` | read-only on this build |
| PUT `settings.binaryMode` | public schema rejects it |
| PUT `settings.timeSavedMode` | additional property |
| PUT a non-`LNI ` name | you listed-and-acted. STOP. |
| Telegram production webhook without secret | **403**. You cannot POST a fake update at the live trigger. |

Rollback of a live workflow is a PUT of the last known-good JSON
(GET that version if you saved it; otherwise reconstruct from the
named rollback `versionId` snapshot under `/tmp/lni716/`). Still
no `active`. Still strip junk.

---

## 2. Bind a credential and prove it

MCP `create_workflow_from_code` binds the **first** credential of
each type on the instance — ElderWise Postgres `WH9oLDfKfOX6KW5F`
and a random Telegram bot. The create response is not evidence.

After every create, REST PUT settings **and** rebind:

- postgres **Leap-NI** `zzFzIzjYqRw0dvoE`
- telegramApi **Leap-NI** `hHCehaaqdJIzsuUu`
- httpHeaderAuth **Supabase_Leap-NI** `HtnR4WtqOeIH88Gw`
- openAiApi **OpenAi account** `ouWVjrmc8Ia4SRD2`
- gmailOAuth2 **Gmail** `trL46GcpmkGxJNnm`
- Apollo **Apollo Leap-NI** `mVnLObeho9sP40Aj`
- Tavily **Tavily Leap-NI** `UqzMo31ehtMX2Ur1` — never generic
  `Tavily account`

**Self-identifying SELECT** (every workflow that reads Postgres,
`executeOnce: true`):

```
SELECT name FROM public.events WHERE name = 'LEAP 2026'
```

(WF-10 also returns `owner_id`.) Gate `name` equals `LEAP 2026`,
strict. Miss → `stopAndError` `Wrong database LEAP 2026 row missing`
(no comma, quote, or apostrophe — WF-00 redact).

A bind is proven only by that execution, never by the MCP create
response, never by the credential picker looking right.

---

## 3. TEST-driver pattern (no phone)

**Do not un-archive during the freeze** unless a packet after
"capture is broken" says so.

`LNI-TEST-7.16-driver` `iqAx0KwCsTbb32BY`, webhook
`POST {N8N_BASE_URL}/webhook/lni-716-driver`.

Body:

```
{ "target": "wf02" | "wf10" | "sql", "payload": { ... } }
```

`wf02` must include `action`, `owner_id`, `telegram_user_id`,
`correlation_id`. `wf10` must include `source`, `owner_id`,
`correlation_id`, and `capture_id` for `done` / `deferred`.
`sql` is a **whitelist of named ops** (see
`/tmp/lni716/put_test_sql.py`) — not arbitrary SQL.

9.8 / 9.10 deferred proves used this path. They never touched
WF-01. That is why they could run without the phone.

### The wrapper Allowlist rejects

A second ingest was added on WF-01: webhook `Driver ingest`
`POST /webhook/lni-716-ingest` wired into **Allowlist**. n8n
webhook wraps the POST as `{ body: <your json> }`. Allowlist
reads:

```
$json.message?.from?.id || $json.edited_message?.from?.id || $json.callback_query?.from?.id
```

The wrapper has none of those. Exec **273668**: no `from.id`,
allowlist miss, rejected. The live Telegram Trigger also
requires the production webhook **secret** — POST without it is
**403**. You cannot inject a synthetic Telegram update into
WF-01 without either the owner's phone or a surgical unwrap PUT
on WF-01 (forbidden during freeze; was already refused in 7.16
R4).

So: driver reaches **WF-02 / WF-10 / SQL**. It does **not**
reach WF-01 send terminals (`Send followup kb3`, command /
ask / digest). Those need the phone.

---

## 4. Node-level gotchas (paid for)

**inlineKeyboard.** Telegram v1.2 `inlineKeyboard.rows` must be
**fixed collection entries** with scalar expressions. A
whole-array expression saves, sends, and emits **no keyboard**.
Node config is not proof. Read `sendMessage.result.reply_markup`.
Proven 7.4-B `LNI-TEST-WF10-buttons` exec **271606**
`message_id` 359. Confirm cards are kb3 = three fixed rows.

**parse_mode is a cross-workflow contract.** Absent on this
build is **Markdown**, not plain text. WF-10 sweep senders were
HTML. WF-01 followup senders were absent. Exec **278965** died
at byte 521 (`_` in a filename). After 9.6 both sides are HTML
and compose HTML-escapes `&` then `<` then `>`. Escape before
Telegram. Do not feed escaped text to Gmail (`emailType: text`).
Do not revert WF-01 to Markdown.

**HTTP file GET.** `responseFormat: file` + distinct
`outputPropertyName` (`attach_0` / `attach_1` / `attach_2`,
voice `asset`). Sequential named GETs **keep prior binary
keys**. Unused Merge inputs hang — do not Merge binaries to
"collect" them. Cap attachments where candidates are chosen
(Load candidate assets, 3), not at send.

**Gmail attachmentsUi.**
`options.attachmentsUi.attachmentsBinary[0].property` =
comma-separated keys actually downloaded (`attach_0,attach_1`).
A missing parameter is not an attachment. Prove from the sent
message's filename and byte size, not the node JSON. 7.3
shipped a 1-file cap and a uuid-as-URL after noticing.

**`$credentials` is undefined in HTTP URLs.**
`this.getCredentials` is unavailable in the task runner. 7.4-B
tried `$credentials.baseUrl + '/bot' + $credentials.accessToken`.
Use the Telegram node. Do not HTTP the bot token.

**filesystem-v2.** Code can create binaries and cannot read
them. Pins are a different program. Size = HEAD
`Content-Length` after PUT, and it must agree with Telegram
`file_size`.

**Named node after I/O.** Never `$json` from the previous item
after Postgres / HTTP / Crypto / Code. Crypto emits json-only
(Hash blanks the binary). `alwaysOutputData` empty item is
`{success:true}` — gate RETURNING `id` notEmpty before any send.

**Switch connections are index-based.** Append a named rule →
re-GET **every** `connection[i]`. Fallback does not shift.
Session 06 4.9 shipped a named rule whose wire still pointed at
the old fallback.

---

## 5. Enqueue — one statement, three nodes

The same four lines live in:

1. WF-02 `Enqueue asset jobs` (`/done`)
2. WF-02 `Enqueue sweep jobs` (5-min idle sweep)
3. WF-09 `Enqueue orphan jobs` (`*/15` backstop)

```
AND NOT (c.capture_mode = 'followup' AND a.kind = 'audio')
AND a.kind IS DISTINCT FROM 'vcard'
AND lower(coalesce(a.mime_type, '')) NOT IN ('text/vcard', 'text/x-vcard')
AND right(lower(coalesce(a.storage_path, '')), 4) IS DISTINCT FROM '.vcf'
```

**Change all three or none.** 9.3 copied a capture-level
`followup` skip onto enqueue and broke 9.2 (photos never
extracted; #130 = 4 assets, 0 jobs). 9.6-B is the correction.
9.10 then wired followup `/done` **into** `Enqueue asset jobs`
(both `Followup close?` outputs). Before that, the SQL sat in a
node the followup branch skipped (11 min to WF-09). After:
**21 s**.

Audio in a followup block is the brief. WF-10 owns it. Photos
and cards enqueue. vCard never enqueues (`kind='vcard'`).

---

## 6. WF-10 routing map

Normalize treats `done` / `sweep` / `command` / `deferred` as
`command` for the old Route source switch. Live callers:

| Caller | `source` | Who sends Telegram |
|---|---|---|
| WF-01 `/followup` leftover / picker / confirm tap | `command` / `callback` | **WF-01** sends `reply_text` (HTML after 9.6) |
| WF-01 `/done` on a followup capture | `done` | WF-10 returns the card; **WF-01** sends |
| WF-02 idle sweep close | `sweep` | **WF-10** sends (`Sweep source?` true) |
| WF-05 after ER, followup draft still `draft` | `deferred` | **WF-10** sends (`Sweep source?` true) |
| Voice await (`source=voice`) | stub | leftover graph. Not how `/followup` works. Do not build on it. |

`Sweep source?` is an OR: `sweep` **or** `deferred`. That is the
recorded exception to "callee decides, WF-01 sends." Immediate
`/done` still returns to WF-01.

Lookup floor 0.25. `hit_count > 1` or trigram step 3 → picker,
never a silent pick. `f7:p:` pick, `f7:s:` send, `f7:n:`
send-none, `f7:x:` cancel.

Do not tap Send on leftover cards. Do not email real contacts.
`5df341f8` never. `bb3689d8` already sent.

---

## 7. Cleanup discipline

**Manifest as you go.** Before you insert a TEST capture, person,
draft, or job, append the id to a manifest (9.8/9.10 used
`/tmp/lni716` + a session file). Delete from the manifest, not
from memory. 9.11 had to reconstruct #137–#145 after the fact.

After every delete, run the orphan queries. A `DELETE` that
returns `{success:true}` with zero RETURNING is a miss.

```
-- the ids you think you deleted must be gone
SELECT id, capture_no FROM captures WHERE capture_no BETWEEN 137 AND 145;
SELECT id, full_name FROM people WHERE id IN (...synthetic...);
SELECT id FROM follow_ups WHERE id IN (...test drafts...);
SELECT id FROM processing_jobs WHERE capture_id IN (...);

-- leftovers hanging off a deleted parent
SELECT a.id FROM assets a
  LEFT JOIN captures c ON c.id = a.capture_id
  WHERE c.id IS NULL;
SELECT j.id FROM processing_jobs j
  LEFT JOIN captures c ON c.id = j.capture_id
  WHERE c.id IS NULL;
SELECT f.id FROM follow_ups f
  LEFT JOIN captures c ON c.id = f.capture_id
  WHERE f.capture_id IS NOT NULL AND c.id IS NULL;
```

Never include locked ids (`1564abc3`, `f6a1e703`, `5df341f8`,
`73fc2831`, captures in the locked list). Do not "fix"
Invariant A (audit `followup_sent` = sent + 1).

---

## 8. If capture breaks during the event — do this FIRST

Capture broken = Telegram ingest does not store a capture, or
the owner cannot `/done`. A nicer card is not broken capture.

1. **Triage, no PUT.** Ask: last `/new` or photo — did the bot
   reply? Which execution id?
2. **GET WF-01** name + `versionId`. Must be
   `LNI WF-01 - Telegram ingest router` /
   `4836ffd8-10e3-4d8c-963d-42bf0ccb9372`. If the version moved,
   STOP and report. Someone PUT.
3. **Latest WF-01 execution.** `lastNodeExecuted`, error text
   (redacted). Allowlist miss vs Storage mismatch vs Compose vs
   Telegram 400 (`parse_mode`) are different diseases.
4. **SQL read** (no write): open capture for the owner, last
   `assets` row, last `storage_path` HEAD if you must. Storage
   first: no row is better than a lying row.
5. **Diagnosis before fix.** One cause. Write it down.
6. **Smallest change, one workflow, named rollback.** GET, save
   JSON, PUT that one workflow, strip junk, no `active`. Re-GET
   `versionId`. Prove on the **owner's phone** (driver cannot
   reach WF-01 send). If the prove fails, PUT the rollback JSON
   immediately.
7. Do not touch WF-10 / WF-05 / a prompt / a card while the
   owner cannot capture.

If you are not sure capture is broken, it is not broken. Stop.

---

## 9. Standing

No `$env`. No `$getWorkflowStaticData`. No ElderWise. No n8n
restart. No Whisper `language`. No commit of
`docs/environment.local.md`. User-facing replies: one fenced
block. Owner is CCIE — short.
