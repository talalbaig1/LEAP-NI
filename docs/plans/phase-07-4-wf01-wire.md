# Packet 7.4 — WF-01 wire (authored, not applied)

**Date:** 28 August 2026 (PREP-R same day)
**Status:** 7.4-B **APPLIED** 28 Aug 2026. WF-01 PUT once
(`4d4d6e6c-40e1-49ad-80f6-5e67203ce0b3`, 118 nodes, active).
Config read-back passed. Live `/ask` **271785**, `/digest`
**271788**, `/flag` **271790**, `/whatever` **271791**,
`/followup` usage **271797** (no keyboard), confirm card
**271799** `message_id` **369** **has** `reply_markup`
(`f7:s:` / `f7:n:` / `f7:x:`). That is the 10.20 miss.
WF-10 stays ACTIVE `8bd44005-…`. BotFather not changed
(owner can add `followup` now). There is not a fourth PUT.

APPLY 28 Aug 2026 **FAILED 10.20 and rolled back** (first
apply). Confirm card `message_id` 349 was sent as plain text.
Telegram `sendMessage` result had **no `reply_markup`**. Map
markup had `has_markup=true` and three `f7:` rows; n8n v1.2
**whole-array** `inlineKeyboard.rows` expression did not emit
buttons.

7.4-B off-router proof (do not touch WF-01 to test a send):

| What | Evidence |
|---|---|
| (a) HTTP `sendMessage` with raw `reply_markup` | **FAIL.** `$credentials` in HTTP URL is undefined. Code `this.getCredentials` is not a function (task runner). Token is not available to HTTP/Code. Cannot put the token in workflow JSON. |
| (b) Telegram node, `inlineKeyboard.rows` as **fixed collection entries** (literals) | **WIN.** LNI-TEST-WF10-buttons `C92yyOvwvyWq1Wg0` exec **271606**, `message_id` **359**. API result `reply_markup.inline_keyboard = [[{text:"TAP THIS - LNI prove", callback_data:"f7:t:prove74b"}]]`. |
| Tap produces an update | **WIN.** Owner tapped 359. WF-01 exec **271715** (and **271717**). `callback_query.data = f7:t:prove74b`. Last node `Callback terminal` (expected on rolled-back graph). |
| Whole-array / whole-`buttons` expression | **FAIL** (same class as 10.20). Exec **271732**: expression on `row.buttons` was iterated as a string → dozens of empty-text buttons → Telegram 400. |
| Fixed rows, **scalar** expressions on `text` and `callback_data` | **WIN.** Exec **271738** `message_id` **363**, three buttons Send / Send no attach / Cancel. Exec **271747** `message_id` **364**, five `f7:p:` rows. |

Proven send for WF-01: Telegram v1.2 `replyMarkup: inlineKeyboard`
literal, N **fixed** collection rows (N = 1..5), each button
`text` / `additionalFields.callback_data` as **scalar**
expressions from Map markup `t0`/`d0` … `t4`/`d4`. Switch on
`n_rows` picks the N-row send node. Do not use a whole-array
expression. Do not use HTTP `sendMessage` on this instance.

Live after rollback (GET), before the 7.4-B PUT:

| Fact | Value |
|---|---|
| WF-01 `versionId` = `activeVersionId` | `baa462d8-5e69-417e-b068-1a6697f3d6c5` |
| WF-01 graph | 97 nodes. Matches frozen snapshot `e3f817e2-…`. No Followup payload, no Call WF-10. Route type `[5]` = Callback terminal. `[11]` = Unknown type terminal. |
| WF-10 | **ACTIVE** `8bd44005-8d91-422b-80f3-b0820b9e1e20`. Empty-brief compose is the true usage line. `Need voice wait?` true → Compose usage (no `awaiting_voice` insert). Left ACTIVE per §9. |
| Leftover draft | `22b8e515-d9f1-44ed-872a-cf9429b5d60c` **cancelled** (7.4-B step 4). Not locked evidence. |

Live baseline this document was written against (GET, read-only):

| Fact | Value |
|---|---|
| WF-01 id | `ZMYx19qEr72mJoCX` |
| WF-01 name | `LNI WF-01 - Telegram ingest router` |
| WF-01 `active` | `true` |
| WF-01 `versionId` = `activeVersionId` | `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a` |
| Route type id | `83a2de860bb047eb` |
| Classify update id | `a34be17d252f4749` |
| `connections["Route type"].main` length | **12** (indexes 0–11) |
| `[10]` | `Flag arg empty?` |
| `[11]` | `Unknown type terminal` |
| WF-10 id | `D9PRjbZMQxe9ESVW` |
| WF-10 | **INACTIVE** (`active=false`, `activeVersionId=null`) |
| Callback today | Route type `[5]` → silent NoOp `Callback terminal` (`d2c7a632f8994497`) |
| `answerCallbackQuery` on WF-01 | **does not exist** |
| Attach correlation | `42680b774d7e4f1f` — Code v2 **passthrough**. Verified GET 28 Aug, see §1.1 |

If a GET before apply shows any other `versionId`, **stop**. Someone
PUT without a packet.

---

## Binding rules for the apply packet

- Never send `active` in the WF-01 PUT (already active).
- Never `POST /activate` on WF-01.
- Never deactivate WF-01.
- Strip `binaryMode` and `timeSavedMode` from the public PUT.
- Do not renumber Route type outputs 0–10.
- Re-GET **every** `connection[i]` after the PUT. Appending a named
  Switch rule does **not** move the old fallback wire (session 06
  4.9 void prove).
- Do not edit `Send ask reply`, `Send digest reply`, `Send flag
  reply`, or `Send command reply`. Followup gets its own send node.
- `parse_mode` stays **absent** on the new send nodes.
- Named-node reads after I/O. `waitForSubWorkflow: true` on Call
  WF-10. `onError: continueRegularOutput` on Call WF-10. A throw
  must still send the owner a line. Silence is reserved for
  storage failure.
- stopAndError messages: no comma, quote, or apostrophe.
- n8n API only on names starting `LNI ` or `LNI-TEST-`. GET name,
  then act.

---

## 1. Complete new "Classify update" jsCode

Replace the entire `parameters.jsCode` on node `Classify update`
(`a34be17d252f4749`). This is the whole function, not a diff.

What changed versus live, in words:

- `/followup`: strip `@botname` on the first token (same
  `raw.replace(/@[\w_]+$/, '')` already used for `/ask` `/flag`).
  `branch = 'followup'`. `text` = the original message. **No
  `followup_arg`.** WF-10 Parse is the one splitter (name vs brief).
  See §1.2. Empty remainder is **not** a voice wait — see §8.
- Callback: still `branch = 'callback'`, but now copies
  `callback_data` and `callback_query_id`. Live classify returns
  without those fields, which is why a later `f7:` gate cannot work
  today.

Editor form (single backslashes). Existing `/\\s+/` and `/@[\\w_]+$/`
are unchanged; do not re-type them. The new `/followup` block uses
`indexOf` / `slice` like `/flag` — no new regex.

```javascript
const allow = $('Allowlist').item.json;
const root = $('Telegram Trigger').first().json;
const cb = root.callback_query || null;
const msg = root.message || root.edited_message || {};
const base = {
  owner_id: allow.owner_id,
  telegram_user_id: allow.telegram_user_id,
  mode: allow.mode,
  correlation_id: null,
  branch: 'unknown',
  action: null,
  file_id: null,
  file_unique_id: null,
  mime_type: null,
  ext: 'bin',
  kind: null,
  note_text: null,
  is_ask: false,
  question: null
};
if (cb) {
  base.branch = 'callback';
  base.callback_data = String(cb.data || '');
  base.callback_query_id = cb.id;
  return [{ json: base }];
}
if (msg.contact) {
  base.branch = 'contact';
  return [{ json: base }];
}
const text = String(msg.text || '');
if (text.startsWith('/')) {
  const raw = text.trim().split(/\s+/)[0].toLowerCase();
  const cmd = raw.replace(/@[\w_]+$/, '');
  if (cmd === '/ask') {
    base.branch = 'ask';
    const parts = text.trim().split(/\s+/);
    base.question = parts.slice(1).join(' ');
    return [{ json: base }];
  }
  if (cmd === '/digest') {
    base.branch = 'digest';
    return [{ json: base }];
  }
  if (cmd === '/flag') {
    base.branch = 'flag';
    const sp = text.indexOf(' ');
    base.flag_arg = sp < 0 ? '' : text.slice(sp + 1).trim();
    return [{ json: base }];
  }
  if (cmd === '/followup') {
    base.branch = 'followup';
    base.text = text;
    return [{ json: base }];
  }
  const map = { '/new': 'new', '/done': 'done', '/batch': 'batch', '/status': 'status', '/start': 'status' };
  if (map[cmd]) {
    base.branch = 'command';
    base.action = map[cmd];
    return [{ json: base }];
  }
  return [{ json: base }];
}
const photos = msg.photo || [];
if (photos.length) {
  let best = photos[0];
  for (let i = 1; i < photos.length; i++) {
    if (Number(photos[i].file_size || 0) > Number(best.file_size || 0)) best = photos[i];
  }
  base.branch = 'photo';
  base.file_id = best.file_id;
  base.file_unique_id = best.file_unique_id;
  base.mime_type = 'image/jpeg';
  base.ext = 'jpg';
  base.kind = 'photo';
  return [{ json: base }];
}
if (msg.voice || msg.audio) {
  const a = msg.voice || msg.audio;
  base.branch = 'voice';
  base.file_id = a.file_id;
  base.file_unique_id = a.file_unique_id;
  base.mime_type = a.mime_type || 'audio/ogg';
  base.ext = (String(base.mime_type).indexOf('mpeg') >= 0) ? 'mp3' : 'oga';
  base.kind = 'audio';
  return [{ json: base }];
}
if (msg.document || msg.video || msg.video_note) {
  const d = msg.document || msg.video || msg.video_note;
  const mime = String(d.mime_type || '').toLowerCase();
  const fname = String(d.file_name || '').toLowerCase();
  if (msg.document && (mime === 'text/vcard' || mime === 'text/x-vcard' || fname.slice(-4) === '.vcf')) {
    base.branch = 'vcard';
    return [{ json: base }];
  }
  base.branch = 'document';
  base.file_id = d.file_id;
  base.file_unique_id = d.file_unique_id;
  base.mime_type = d.mime_type || ((msg.video || msg.video_note) ? 'video/mp4' : 'application/octet-stream');
  let ext = 'bin';
  if (d.file_name && String(d.file_name).indexOf('.') >= 0) {
    ext = String(d.file_name).split('.').pop().toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 8) || 'bin';
  } else if (msg.video || msg.video_note) ext = 'mp4';
  else if (base.mime_type === 'application/pdf') ext = 'pdf';
  base.ext = ext;
  base.kind = 'document';
  return [{ json: base }];
}
if (text) {
  base.branch = 'text';
  base.note_text = text;
  base.is_ask = false;
  return [{ json: base }];
}
return [{ json: base }];
```

---

## 1.1 Attach correlation — verified GET, not an assertion

GET 28 Aug 2026, WF-01 `versionId`
`e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a`. Node id `42680b774d7e4f1f`.
Type `n8n-nodes-base.code` v2. **Passthrough.** Not a fixed-field
Set. Not an explicit field list. Do not edit it.

Actual `parameters` (whole object):

```json
{
  "jsCode": "const j = Object.assign({}, $('Classify update').item.json);\nj.correlation_id = $input.first().json.data || $input.first().json.uuid;\nreturn [{ json: j }];"
}
```

Cited: `Object.assign({}, $('Classify update').item.json)` copies
**every** Classify key, then overwrites `correlation_id` from Mint
correlation (`$input.first().json.data || $input.first().json.uuid`).
So `text`, `callback_data`, and `callback_query_id` ride through.
§4 named-node reads of those fields are valid.

---

## 1.2 One parser — drop `followup_arg`

Classify must **not** set `followup_arg`. Followup payload passes
the full original `text`. WF-10 Parse already strips a leading
`/followup` token (and `@bot`) and splits first remaining token =
name, rest = brief. That path is proven.

Two parsers for one string is how they drift (`/flag` vs WF-10
already taught that). Classify only decides `branch`. WF-10 only
splits. Empty `text` after the command token is a usage reply
(§8), not a second field.

---

## 2. Exact appended Route type rule

Append this object as the **12th** entry of
`Route type.parameters.rules.values` (after `flag`, before the
fallback). Do not insert. Do not reorder.

`id` of the inner condition: `r-followup`. `outputKey`: `followup`.

```json
{
  "conditions": {
    "combinator": "and",
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict",
      "version": 2
    },
    "conditions": [
      {
        "id": "r-followup",
        "leftValue": "={{ $json.branch }}",
        "operator": {
          "type": "string",
          "operation": "equals"
        },
        "rightValue": "followup"
      }
    ]
  },
  "renameOutput": true,
  "outputKey": "followup"
}
```

Leave `options.fallbackOutput = "extra"` and
`options.renameFallbackOutput = "unknown"` unchanged.

Live named rules today, in order, stay: `command`, `photo`, `voice`,
`document`, `text`, `callback`, `contact`, `ask`, `digest`, `vcard`,
`flag`. After the append the named list is those eleven plus
`followup`. Fallback remains the extra output.

---

## 3. FULL `connections["Route type"].main` after the append

Indexes 0–10 are **byte-identical** to live. `[11]` becomes the new
followup node. `[12]` is the re-wired Unknown type terminal.

Live (12 entries, architect-verified 28 Aug 2026):

```
[0]  Command payload
[1]  Duplicate check          (photo)
[2]  Duplicate check          (voice)
[3]  Duplicate check          (document)
[4]  Text is ask?
[5]  Callback terminal        ← 7.4 also changes this target, see §5
[6]  Contact unsupported reply
[7]  Ask payload
[8]  Digest payload
[9]  Vcard unsupported reply
[10] Flag arg empty?
[11] Unknown type terminal
```

After apply (13 entries). `[5]` is the only 0–10 retarget: it must
point at `Callback is f7?`, not at `Callback terminal`. If `[5]` still
says `Callback terminal` after the PUT, the `f7:` buttons will hang
and WF-10 will never see a callback.

```json
[
  [ { "node": "Command payload", "type": "main", "index": 0 } ],
  [ { "node": "Duplicate check", "type": "main", "index": 0 } ],
  [ { "node": "Duplicate check", "type": "main", "index": 0 } ],
  [ { "node": "Duplicate check", "type": "main", "index": 0 } ],
  [ { "node": "Text is ask?", "type": "main", "index": 0 } ],
  [ { "node": "Callback is f7?", "type": "main", "index": 0 } ],
  [ { "node": "Contact unsupported reply", "type": "main", "index": 0 } ],
  [ { "node": "Ask payload", "type": "main", "index": 0 } ],
  [ { "node": "Digest payload", "type": "main", "index": 0 } ],
  [ { "node": "Vcard unsupported reply", "type": "main", "index": 0 } ],
  [ { "node": "Flag arg empty?", "type": "main", "index": 0 } ],
  [ { "node": "Followup payload", "type": "main", "index": 0 } ],
  [ { "node": "Unknown type terminal", "type": "main", "index": 0 } ]
]
```

Written out:

| i | node | note |
|---|---|---|
| 0 | Command payload | unchanged |
| 1 | Duplicate check | unchanged |
| 2 | Duplicate check | unchanged |
| 3 | Duplicate check | unchanged |
| 4 | Text is ask? | unchanged |
| 5 | **Callback is f7?** | was Callback terminal |
| 6 | Contact unsupported reply | unchanged |
| 7 | Ask payload | unchanged |
| 8 | Digest payload | unchanged |
| 9 | Vcard unsupported reply | unchanged |
| 10 | Flag arg empty? | unchanged |
| 11 | **Followup payload** | new named output |
| 12 | **Unknown type terminal** | fallback, must be re-wired |

The 4.9 failure mode: `[11]` still Unknown, `[12]` missing or empty.
That is a failed apply. Stop and roll back (§9).

---

## 4. Every new node, in full

Copy `credentials.telegramApi` from a live WF-01 Telegram send node
at PUT time. Public GET of WF-01 on 28 Aug omitted credential
objects; do not invent an id. `retryOnFail: true` on provider nodes.

Proposed ids are unused on live WF-01 (97 nodes today). If a collision
appears on GET, generate a new 16-hex id and keep the **name**.

### 4.1 Command branch (`/followup`)

**Followup payload** — Set, same family as Ask payload. `text` is the
full original line so WF-10 Parse (strip leading `/followup` token,
first remaining token = name, rest = brief) stays as proven.

```json
{
  "id": "a7f10c01e4b24a11",
  "name": "Followup payload",
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [2016, 2480],
  "parameters": {
    "mode": "raw",
    "jsonOutput": "={{ { owner_id: $('Attach correlation').item.json.owner_id, correlation_id: $('Attach correlation').item.json.correlation_id, text: $('Attach correlation').item.json.text || '', source: 'command' } }}",
    "options": {}
  }
}
```

**Call WF-10** — shared by command and callback (two inbound wires,
same pattern as Duplicate check). `waitForSubWorkflow: true`.
`onError: continueRegularOutput` so a WF-10 throw does not die
silent on WF-01. The owner tapped Send (or issued `/followup`);
silence is reserved for storage failure, not for a callee error.
`retryOnFail` stays. After a throw the item has no `ok` /
`reply_text`, so **Followup has reply?** goes false and §4 fail
send runs.

```json
{
  "id": "b8e21d12f5c35b22",
  "name": "Call WF-10",
  "type": "n8n-nodes-base.executeWorkflow",
  "typeVersion": 1.3,
  "position": [2240, 2480],
  "retryOnFail": true,
  "continueOnFail": true,
  "onError": "continueRegularOutput",
  "parameters": {
    "workflowId": {
      "__rl": true,
      "value": "D9PRjbZMQxe9ESVW",
      "mode": "id",
      "cachedResultName": "LNI WF-10 - Follow-up drafting"
    },
    "options": {
      "waitForSubWorkflow": true
    }
  }
}
```

**Followup has reply?** — `ok` true AND `reply_text` notEmpty, named
node, strict. True → Map markup → confirm/send path. False (throw
continued, `ok` false, or empty `reply_text`) → **real send**, not
a silent NoOp. Empty `reply_text` on a successful WF-10 return is
still a WF-10 defect; the owner still gets the fail line.

```json
{
  "id": "c9d32e23a6d46c33",
  "name": "Followup has reply?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.3,
  "position": [2464, 2480],
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "combinator": "and",
      "conditions": [
        {
          "id": "f7-ok",
          "leftValue": "={{ $('Call WF-10').first().json.ok }}",
          "operator": { "type": "boolean", "operation": "true", "singleValue": true },
          "rightValue": ""
        },
        {
          "id": "f7-rt",
          "leftValue": "={{ $('Call WF-10').first().json.reply_text }}",
          "operator": { "type": "string", "operation": "notEmpty", "singleValue": true },
          "rightValue": ""
        }
      ]
    },
    "options": {}
  }
}
```

**Map markup** — WF-10 returns Telegram Bot API
`reply_markup.inline_keyboard` (one button per row, up to five
rows). Flatten to scalar slots `t0`/`d0` … `t4`/`d4` and
`n_rows`. Do **not** emit an `n8n_inline_rows` array — that is
the 10.20 whole-array expression that Telegram dropped. No regex.

```json
{
  "id": "d0e43f34b7e57d44",
  "name": "Map markup",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [2688, 2400],
  "parameters": {
    "mode": "runOnceForAllItems",
    "language": "javaScript",
    "jsCode": "const src = $('Call WF-10').first().json || {};\nconst kb = src.reply_markup && src.reply_markup.inline_keyboard;\nconst t = ['', '', '', '', ''];\nconst d = ['', '', '', '', ''];\nlet n = 0;\nif (Array.isArray(kb)) {\n  const lim = kb.length < 5 ? kb.length : 5;\n  for (let i = 0; i < lim; i++) {\n    const line = kb[i] || [];\n    const b = line[0] || {};\n    const text = String(b.text || '');\n    const data = String(b.callback_data || '');\n    if (text) {\n      t[n] = text;\n      d[n] = data;\n      n = n + 1;\n    }\n  }\n}\nreturn [{ json: {\n  ok: src.ok,\n  reply_text: src.reply_text,\n  reply_text_2: src.reply_text_2 || '',\n  has_markup: n > 0,\n  n_rows: n,\n  t0: t[0], d0: d[0],\n  t1: t[1], d1: d[1],\n  t2: t[2], d2: d[2],\n  t3: t[3], d3: d[3],\n  t4: t[4], d4: d[4]\n} }];"
  }
}
```

**Followup has markup?** — true → rows switch. false →
**Send followup reply** (usage / no keyboard). Empty
`reply_markup` on a successful WF-10 return is the usage line.

```json
{
  "id": "a1b2c3d4e5f60718",
  "name": "Followup has markup?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.3,
  "position": [2800, 2400],
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "combinator": "and",
      "conditions": [
        {
          "id": "f7-has-markup",
          "leftValue": "={{ $('Map markup').first().json.has_markup }}",
          "operator": { "type": "boolean", "operation": "true", "singleValue": true },
          "rightValue": ""
        }
      ]
    },
    "options": {}
  }
}
```

**Followup rows switch** — `n_rows` equals 1..5. Extra
(unexpected count) → no-keyboard send. Do not skip-empty a
5-row node: empty `text` is Telegram 400 (exec 271732).

```json
{
  "id": "b2c3d4e5f6071829",
  "name": "Followup rows switch",
  "type": "n8n-nodes-base.switch",
  "typeVersion": 3.4,
  "position": [2912, 2240],
  "parameters": {
    "rules": {
      "values": [
        {
          "conditions": {
            "combinator": "and",
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict", "version": 2 },
            "conditions": [
              { "id": "f7-n1", "leftValue": "={{ $('Map markup').first().json.n_rows }}", "operator": { "type": "number", "operation": "equals" }, "rightValue": 1 }
            ]
          },
          "renameOutput": true,
          "outputKey": "n1"
        },
        {
          "conditions": {
            "combinator": "and",
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict", "version": 2 },
            "conditions": [
              { "id": "f7-n2", "leftValue": "={{ $('Map markup').first().json.n_rows }}", "operator": { "type": "number", "operation": "equals" }, "rightValue": 2 }
            ]
          },
          "renameOutput": true,
          "outputKey": "n2"
        },
        {
          "conditions": {
            "combinator": "and",
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict", "version": 2 },
            "conditions": [
              { "id": "f7-n3", "leftValue": "={{ $('Map markup').first().json.n_rows }}", "operator": { "type": "number", "operation": "equals" }, "rightValue": 3 }
            ]
          },
          "renameOutput": true,
          "outputKey": "n3"
        },
        {
          "conditions": {
            "combinator": "and",
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict", "version": 2 },
            "conditions": [
              { "id": "f7-n4", "leftValue": "={{ $('Map markup').first().json.n_rows }}", "operator": { "type": "number", "operation": "equals" }, "rightValue": 4 }
            ]
          },
          "renameOutput": true,
          "outputKey": "n4"
        },
        {
          "conditions": {
            "combinator": "and",
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict", "version": 2 },
            "conditions": [
              { "id": "f7-n5", "leftValue": "={{ $('Map markup').first().json.n_rows }}", "operator": { "type": "number", "operation": "equals" }, "rightValue": 5 }
            ]
          },
          "renameOutput": true,
          "outputKey": "n5"
        }
      ]
    },
    "options": { "fallbackOutput": "extra", "renameFallbackOutput": "none" }
  }
}
```

**Send followup reply** — usage / no keyboard. Do not reuse
Send ask / digest / flag / command. No `parse_mode`.
`appendAttribution: false`. **No** `replyMarkup`.

```json
{
  "id": "e1f54045c8f68e55",
  "name": "Send followup reply",
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "position": [3136, 2560],
  "retryOnFail": true,
  "webhookId": "7c1d2e3f-4a5b-6c7d-8e9f-0a1b2c3d4e5f",
  "parameters": {
    "chatId": "={{ $('Allowlist').item.json.telegram_user_id }}",
    "text": "={{ $('Call WF-10').first().json.reply_text }}",
    "additionalFields": {
      "appendAttribution": false
    }
  }
}
```

**Send followup kb3** — confirm card (3 rows) and 3-person
disambiguation. `replyMarkup` is the **literal**
`inlineKeyboard`. Each row is a **fixed** collection entry.
`text` and `callback_data` are **scalar** expressions (proven
exec 271738 `message_id` 363). Copy `credentials.telegramApi`
from live `Send ask reply` at PUT time. kb1 / kb2 / kb4 / kb5
are the same node with 1 / 2 / 4 / 5 rows using `t0`/`d0` …
`t4`/`d4`. Ids: kb1 `c3d4e5f60718293a`, kb2 `d4e5f60718293a4b`,
kb3 `e5f60718293a4b5c`, kb4 `f60718293a4b5c6d`, kb5
`a708293a4b5c6d7e`.

```json
{
  "id": "e5f60718293a4b5c",
  "name": "Send followup kb3",
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "position": [3136, 2240],
  "retryOnFail": true,
  "webhookId": "7c1d2e3f-4a5b-6c7d-8e9f-0a1b2c3d4e53",
  "parameters": {
    "chatId": "={{ $('Allowlist').item.json.telegram_user_id }}",
    "text": "={{ $('Call WF-10').first().json.reply_text }}",
    "replyMarkup": "inlineKeyboard",
    "inlineKeyboard": {
      "rows": [
        { "row": { "buttons": [ { "text": "={{ $('Map markup').first().json.t0 }}", "additionalFields": { "callback_data": "={{ $('Map markup').first().json.d0 }}" } } ] } },
        { "row": { "buttons": [ { "text": "={{ $('Map markup').first().json.t1 }}", "additionalFields": { "callback_data": "={{ $('Map markup').first().json.d1 }}" } } ] } },
        { "row": { "buttons": [ { "text": "={{ $('Map markup').first().json.t2 }}", "additionalFields": { "callback_data": "={{ $('Map markup').first().json.d2 }}" } } ] } }
      ]
    },
    "additionalFields": {
      "appendAttribution": false
    }
  }
}
```

Physical limit (proven 7.4-B, not a hope): n8n v1.2
`inlineKeyboard.rows` is a collection. A whole-array expression
**saves** and still sends **no** buttons (10.20, `message_id`
349). An expression on `row.buttons` is iterated as a string
(exec 271732, Telegram 400). HTTP `sendMessage` **cannot** get
the bot token on this instance. The only proven path is fixed
collection rows + scalar `text` / `callback_data`. Read-back
after PUT: each kbN node must still have N collection rows,
not an expression. Live confirm must show `reply_markup` in
the `sendMessage` result. Do not hard-code the three confirm
labels — disambiguation emits up to five `f7:p:<uuid>` rows,
which is why there are five send nodes rather than one
3-button node.

**Followup has reply_text_2?** — second send only when WF-10 set it.

```json
{
  "id": "f2065156d9079f66",
  "name": "Followup has reply_text_2?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.3,
  "position": [3136, 2320],
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "combinator": "and",
      "conditions": [
        {
          "id": "f7-rt2",
          "leftValue": "={{ $('Call WF-10').first().json.reply_text_2 }}",
          "operator": { "type": "string", "operation": "notEmpty", "singleValue": true },
          "rightValue": ""
        }
      ]
    },
    "options": {}
  }
}
```

**Send followup reply 2** — body continuation. No markup. No
`parse_mode`. See §7.

```json
{
  "id": "a3176267ea18a077",
  "name": "Send followup reply 2",
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "position": [3360, 2240],
  "retryOnFail": true,
  "webhookId": "8d2e3f40-5b6c-7d8e-9f0a-1b2c3d4e5f60",
  "parameters": {
    "chatId": "={{ $('Allowlist').item.json.telegram_user_id }}",
    "text": "={{ $('Call WF-10').first().json.reply_text_2 }}",
    "additionalFields": {
      "appendAttribution": false
    }
  }
}
```

**Followup sent terminal** and **Followup no-send terminal**

The NoOp `Followup no-send terminal` stays. It is **downstream of
a real send**. Do not wire Followup has reply? false directly to
it.

**Followup fail reply** — fixed text. No comma, quote, or
apostrophe (same family as stopAndError hygiene even though this
is a send, not a throw).

```json
{
  "id": "a9177378fc3ad3aa",
  "name": "Followup fail reply",
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [2688, 2640],
  "parameters": {
    "mode": "raw",
    "jsonOutput": "={{ { reply_text: 'Follow-up failed. Nothing was sent. Try again.' } }}",
    "options": {}
  }
}
```

**Send followup fail** — same Telegram pattern as Send flag reply.
No `parse_mode`. No markup. Named-node `reply_text`.

```json
{
  "id": "b02884890d4be4bb",
  "name": "Send followup fail",
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "position": [2912, 2640],
  "retryOnFail": true,
  "webhookId": "a0b1c2d3-e4f5-6071-8293-a4b5c6d7e8f9",
  "parameters": {
    "chatId": "={{ $('Allowlist').item.json.telegram_user_id }}",
    "text": "={{ $('Followup fail reply').item.json.reply_text }}",
    "additionalFields": {
      "appendAttribution": false
    }
  }
}
```

```json
{
  "id": "b4287378fb29b188",
  "name": "Followup sent terminal",
  "type": "n8n-nodes-base.noOp",
  "typeVersion": 1,
  "position": [3584, 2240],
  "parameters": {}
}
```

```json
{
  "id": "c53984890c3ac299",
  "name": "Followup no-send terminal",
  "type": "n8n-nodes-base.noOp",
  "typeVersion": 1,
  "position": [3136, 2640],
  "parameters": {}
}
```

### 4.2 Callback branch (see also §5)

**Callback is f7?** — string startsWith `f7:`. Source the field from
Attach correlation (named), not `$json`.

```json
{
  "id": "d64a959a1d4bd3aa",
  "name": "Callback is f7?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.3,
  "position": [2016, 1264],
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict",
        "version": 2
      },
      "combinator": "and",
      "conditions": [
        {
          "id": "f7-prefix",
          "leftValue": "={{ $('Attach correlation').item.json.callback_data }}",
          "operator": { "type": "string", "operation": "startsWith" },
          "rightValue": "f7:"
        }
      ]
    },
    "options": {}
  }
}
```

**Answer callback** — Telegram `resource=callback`,
`operation=answerQuery`. Must run **before** Call WF-10. Telegram
times out unanswered queries at ~10 s; WF-10 OpenAI + Gmail can
exceed that. Empty notification text (no toast). `continueOnFail:
true` so a duplicate tap does not block the chat reply.

```json
{
  "id": "e75ba6ab2e5ce4bb",
  "name": "Answer callback",
  "type": "n8n-nodes-base.telegram",
  "typeVersion": 1.2,
  "position": [2240, 1184],
  "retryOnFail": true,
  "continueOnFail": true,
  "onError": "continueRegularOutput",
  "webhookId": "9e3f4051-6c7d-8e9f-0a1b-2c3d4e5f6071",
  "parameters": {
    "resource": "callback",
    "operation": "answerQuery",
    "queryId": "={{ $('Attach correlation').item.json.callback_query_id }}",
    "additionalFields": {}
  }
}
```

**Callback payload**

```json
{
  "id": "f86cb7bc3f6df5cc",
  "name": "Callback payload",
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [2464, 1184],
  "parameters": {
    "mode": "raw",
    "jsonOutput": "={{ { owner_id: $('Attach correlation').item.json.owner_id, correlation_id: $('Attach correlation').item.json.correlation_id, source: 'callback', callback_data: $('Attach correlation').item.json.callback_data || '', text: '' } }}",
    "options": {}
  }
}
```

Existing **Callback terminal** (`d2c7a632f8994497`) stays a NoOp.
Move its position to `[2240, 1360]` so it is not stacked on the new
IF. Do not rename it. Non-`f7:` callbacks still die silent here.

### 4.3 New connections (besides Route type)

```json
{
  "Followup payload": { "main": [ [ { "node": "Call WF-10", "type": "main", "index": 0 } ] ] },
  "Callback is f7?": {
    "main": [
      [ { "node": "Answer callback", "type": "main", "index": 0 } ],
      [ { "node": "Callback terminal", "type": "main", "index": 0 } ]
    ]
  },
  "Answer callback": { "main": [ [ { "node": "Callback payload", "type": "main", "index": 0 } ] ] },
  "Callback payload": { "main": [ [ { "node": "Call WF-10", "type": "main", "index": 0 } ] ] },
  "Call WF-10": { "main": [ [ { "node": "Followup has reply?", "type": "main", "index": 0 } ] ] },
  "Followup has reply?": {
    "main": [
      [ { "node": "Map markup", "type": "main", "index": 0 } ],
      [ { "node": "Followup fail reply", "type": "main", "index": 0 } ]
    ]
  },
  "Followup fail reply": { "main": [ [ { "node": "Send followup fail", "type": "main", "index": 0 } ] ] },
  "Send followup fail": { "main": [ [ { "node": "Followup no-send terminal", "type": "main", "index": 0 } ] ] },
  "Map markup": { "main": [ [ { "node": "Followup has markup?", "type": "main", "index": 0 } ] ] },
  "Followup has markup?": {
    "main": [
      [ { "node": "Followup rows switch", "type": "main", "index": 0 } ],
      [ { "node": "Send followup reply", "type": "main", "index": 0 } ]
    ]
  },
  "Followup rows switch": {
    "main": [
      [ { "node": "Send followup kb1", "type": "main", "index": 0 } ],
      [ { "node": "Send followup kb2", "type": "main", "index": 0 } ],
      [ { "node": "Send followup kb3", "type": "main", "index": 0 } ],
      [ { "node": "Send followup kb4", "type": "main", "index": 0 } ],
      [ { "node": "Send followup kb5", "type": "main", "index": 0 } ],
      [ { "node": "Send followup reply", "type": "main", "index": 0 } ]
    ]
  },
  "Send followup kb1": { "main": [ [ { "node": "Followup has reply_text_2?", "type": "main", "index": 0 } ] ] },
  "Send followup kb2": { "main": [ [ { "node": "Followup has reply_text_2?", "type": "main", "index": 0 } ] ] },
  "Send followup kb3": { "main": [ [ { "node": "Followup has reply_text_2?", "type": "main", "index": 0 } ] ] },
  "Send followup kb4": { "main": [ [ { "node": "Followup has reply_text_2?", "type": "main", "index": 0 } ] ] },
  "Send followup kb5": { "main": [ [ { "node": "Followup has reply_text_2?", "type": "main", "index": 0 } ] ] },
  "Send followup reply": { "main": [ [ { "node": "Followup has reply_text_2?", "type": "main", "index": 0 } ] ] },
  "Followup has reply_text_2?": {
    "main": [
      [ { "node": "Send followup reply 2", "type": "main", "index": 0 } ],
      [ { "node": "Followup sent terminal", "type": "main", "index": 0 } ]
    ]
  },
  "Send followup reply 2": { "main": [ [ { "node": "Followup sent terminal", "type": "main", "index": 0 } ] ] }
}
```

Delete the old Route type `[5]` wire to `Callback terminal`. The IF
false branch is now the only wire into that NoOp.

---

## 5. Callback branch change

**Today.** Classify sets `branch='callback'` and returns without
`callback_query.data`. Route type `[5]` → `Callback terminal`
(NoOp). No `answerCallbackQuery` node exists. A tap on any future
inline button is a silent success.

**After 7.4.**

```
Route type [5]
  → Callback is f7?
       true  → Answer callback (queryId = callback_query_id)
             → Callback payload (source='callback', callback_data)
             → Call WF-10 (same node as /followup)
             → Followup has reply? → Map markup → Followup has markup?
                 true  → Followup rows switch → Send followup kbN
                 false → Send followup reply (no keyboard)
             → optional Send followup reply 2
             → optional Send followup reply 2
       false → Callback terminal (existing NoOp, unchanged behaviour)
```

`f7:` kinds WF-10 already parses: `p` pick person, `s` send, `n` send
without attachments, `x` cancel. WF-01 does not re-parse them.

**answerCallbackQuery placement:** immediately after the `f7:` IF,
**before** Call WF-10. Not after Gmail. Not after the chat send.
Unanswered queries retry and the owner sees a spinner; answering
late is how Telegram double-fires a send tap.

Anything else (`callback_data` empty, missing prefix, a leftover
non-LNI button) keeps the existing terminal. Do not answer those.

---

## 6. `reply_markup` passthrough and `/ask` `/digest` `/flag` prove

Markup exists **only** on `Send followup reply`. The four live send
nodes stay:

| Node | id | live parameters (do not edit) |
|---|---|---|
| Send ask reply | `1065e079a8964813` | `chatId` Allowlist, `text` Call WF-08 `reply_text`, `appendAttribution: false`, **no** `replyMarkup`, **no** `parse_mode` |
| Send digest reply | `3d5e6af6b098433d` | `chatId` Allowlist, `text` Call WF-07 `reply_text`, `appendAttribution: false`, **no** `replyMarkup`, **no** `parse_mode` |
| Send flag reply | `2d2a8c5e15a6418e` | `chatId` Allowlist, `text` `$json.reply_text`, `appendAttribution: false`, **no** `replyMarkup`, **no** `parse_mode` |
| Send command reply | `83341e4eea5b4736` | `chatId` Allowlist, `text` `$json.reply_text \|\| $json.state_echo`, `appendAttribution: false`, **no** `replyMarkup`, **no** `parse_mode` |

Phase 7 plan said "shared command send node". Live WF-01 has four
separate send nodes. Sharing markup onto any of them is how `/ask`
grows a phantom keyboard. Disagreement: **new send node**, not a
shared one. See §D.

### Executions to compare against after the PUT

Issue one live `/ask`, one `/digest`, one `/flag` (usage or queue).
Compare each new WF-01 execution to these locked parents. Same last
node family. `Send * reply` parameters unchanged (GET the node, not
the report).

| Command | Locked executions | What "still sending" means |
|---|---|---|
| `/ask` | **255773, 255781, 255786, 255800, 255806** | Last node `Ask sent terminal`. Call WF-08 ran. Compose context `row_count` was 10 on those five (full interaction corpus). New `/ask` must still reach `Send ask reply` with non-empty `reply_text`. |
| `/flag` | **265855** (sent, no-match class), **265857** (queue), **265540** (usage-class) | Last node `Flag sent terminal`. Reply still comes from the flag ladder, not WF-10. |
| `/digest` | WF-01 on-demand parent is not in the 28 Aug execution index this author could page (MCP returned the recent `/flag` window only). Callee proofs: WF-07 scheduled **264951** (7 AM 28 Aug, `mode=trigger`) and **260806** (10 PM 27 Aug). | After PUT, send `/digest`. Last node `Digest sent terminal`. `Send digest reply` parameters identical to GET-before. `reply_text` shape matches 264951/260806 (brief vs close by hour). |

Also GET-diff the four send nodes **before vs after** the PUT. If any
parameter besides unrelated position noise moved, roll back.

`/followup` itself is new. Prove it against WF-10 execute_workflow
already locked (`2ea079a3` no-attach, `e5bf5982` two-attach) by
sending `/followup` at the prove person, not by mutating those rows.

---

## 7. `reply_text_2` when the confirm exceeds 3800 characters

Telegram `sendMessage` hard limit is 4096. Phase 7 plan §M: if the
confirm card would exceed **3800**, WF-10 splits: `reply_text` = card
header + To/CC/subject/filenames + buttons, `reply_text_2` = body.

WF-01 does **not** re-split. Gate `Followup has reply_text_2?` on
`Call WF-10.reply_text_2` string notEmpty. True → `Send followup
reply 2` (no markup — buttons stay on the first message). False →
`Followup sent terminal`.

Empty `reply_text_2` is the common path. A missing second send when
the field is set is a defect. A second send when the field is empty
is a defect.

---

## 8. Voice-await intercept — NOT in 7.4

**Recommendation: do not intercept voice in this apply. Voice stays
the WF-10 stub. Capture voice stays Route type `[2]` → Duplicate
check → WF-02.**

Reason: Corollary 1 — capture wins. Route type `[2]` is the hottest
path on the event floor. An awaiting-followup intercept that is one
predicate off swallows a meeting voice into WF-10 and never stores
an asset. Command + typed brief is already proven on inactive WF-10
(`execute_workflow`).

**Do not promise a voice path that is not wired.** Live WF-10
`Need voice wait?` true (empty brief, `source=command`) inserts
`draft_state='awaiting_voice'`, sets `bot_state.awaiting_followup_*`,
and replies `Record a voice note now (15 min). A photo still goes
to capture.` Nothing on WF-01 claims that voice. That sentence is
a lie until a later packet wires the intercept.

### Empty-brief reply (WF-10 change at apply, not now)

Replace that compose with a true line, same family as `/flag`
usage:

`Send /followup followed by a name or email and a short note.`

Use this for both "no name and no brief" and "name present, brief
empty". Do not keep two usage strings that drift.

### `awaiting_voice` row — do not write it

**Recommend: do not insert `awaiting_voice`. Do not set
`bot_state.awaiting_followup_id` / `_until`.** Apply-time WF-10:
`Need voice wait?` true → the compose above → Return. Skip
**Insert awaiting voice** and **Set bot await**.

Reason: a row that cannot be claimed is a lie in Postgres. It sits
`status='open'` until someone cancels it. `bot_state` await set
with no intercept is how a later voice packet steals a capture
voice by accident. Fail closed. When a packet wires the intercept,
that packet turns the insert back on.

This PREP does not PUT WF-10. The apply packet must change that
compose (and skip the insert) in the same packet as the WF-01
wire.

Phase 7 plan §A item 4 listed voice intercept in 7.4. Disagreement
is §D below. If the architect overrides, the intercept is a later
packet: Load `bot_state.awaiting_followup_id` / `_until` **before**
Duplicate check on voice only; claim only when set and
`until > now()`; Call WF-10 `source='voice'` with `file_id`; do not
call WF-02; photo/document/card on that interval still capture and
clear the await. Do not write that graph in this PUT.

---

## 9. Rollback

Never deactivate. Never `POST /activate` on WF-01 (already active).

1. Before the apply PUT, save the GET body of version
   `baa462d8-5e69-417e-b068-1a6697f3d6c5` (rolled-back 97-node
   graph, same as frozen `e3f817e2-…`) to a local file (not the
   repo).
2. To roll back: PUT that saved body back.
   - Do **not** send `active`.
   - Strip `binaryMode` and `timeSavedMode`.
   - Confirm GET `versionId` returns
     `e3f817e2-9989-4486-8c7d-fe2ebb0d1b8a` **or** a new id whose
     graph matches that snapshot (n8n mints a new versionId on PUT;
     the editor Versions UI restore to `e3f817e2-…` is the other
     legal path). Record both ids.
3. If WF-10 was activated in the same apply packet, leave it
   **ACTIVE** unless the architect says otherwise — deactivating it
   is a second blast. Rolling back WF-01 is enough to stop Telegram
   from calling it. Do not `POST /activate` again.

---

## 10. Read-back checklist (architect accepts, not the implementer report)

Run in this order. Any fail → roll back (§9). Do not "fix forward"
on WF-01 during 31 Aug–3 Sep.

**Before any owner `/followup`:**

1. GET WF-01 name is `LNI WF-01 - Telegram ingest router`.
2. `active === true`. `activeVersionId` equals `versionId`.
3. PUT did not include `active`. Settings still
   `availableInMCP: true`, `timezone: Asia/Riyadh`,
   `errorWorkflow: X7zKL3wTFPIhwyaN`, `executionTimeout: 300`.
   `binaryMode` / `timeSavedMode` not required on the public GET.
4. Classify update jsCode contains `cmd === '/followup'` and
   callback copies `callback_data` and `callback_query_id`. Whole
   function matches §1 (not a fragment).
5. Route type `rules.values` length is **12** named rules. Last
   named `outputKey` is `followup`, condition id `r-followup`.
   Fallback extra still `unknown`.
6. `connections["Route type"].main.length === 13`.
7. Re-GET **every** index 0–12. Assert §3 table. Especially:
   `[10] Flag arg empty?`, `[11] Followup payload`,
   `[12] Unknown type terminal`, `[5] Callback is f7?`.
8. New nodes §4 exist by **name**. Call WF-10
   `workflowId.value === D9PRjbZMQxe9ESVW`,
   `waitForSubWorkflow === true`,
   `onError === continueRegularOutput`.
9. `Send ask reply` / `Send digest reply` / `Send flag reply` /
   `Send command reply` parameters equal the pre-PUT GET.
10. `Send followup reply` has **no** `replyMarkup` (usage).
    `Send followup kb1`..`kb5` each have literal
    `replyMarkup: inlineKeyboard` and N **fixed** collection
    rows, scalar `text`/`callback_data` from Map markup `t*`/`d*`.
    GET: kb3 `inlineKeyboard.rows` length is 3, not an
    expression. `appendAttribution: false`, **no** `parse_mode`.
11. `Answer callback` is `resource=callback` `operation=answerQuery`,
    wired **before** Call WF-10. False branch of `Callback is f7?`
    is `Callback terminal`.
12. Classify jsCode has **no** `followup_arg`. Followup payload
    `text` is the full original line.
13. Followup has reply? false → `Followup fail reply` →
    `Send followup fail` → `Followup no-send terminal`. GET the
    fail text: `Follow-up failed. Nothing was sent. Try again.`
14. WF-10 apply (same packet, still not this PREP): empty-brief
    compose is the true usage line. No `awaiting_voice` insert on
    that branch. No `bot_state` await set.

**WF-10 activation (apply packet only, not this PREP):**

15. GET WF-10 still named `LNI WF-10 - Follow-up drafting`.
    Empty-brief compose is the true usage line. That branch does
    **not** INSERT `awaiting_voice` and does **not** set
    `bot_state` await. Then `POST /activate` once if
    `active === false`. Never send `active` on a WF-10 PUT. Never
    activate in this docs packet.

**Live regression (owner phone or the allowlisted bot):**

16. `/ask <question>` — new WF-01 execution last node `Ask sent
    terminal`. Compare to **255773 / 255781 / 255786 / 255800 /
    255806**.
17. `/digest` — last node `Digest sent terminal`. Compare callee
    shape to WF-07 **264951** (brief) / **260806** (close).
18. `/flag <name-or-email>` — last node `Flag sent terminal`.
    Compare to **265855 / 265857 / 265540**.
19. `/followup` with no name and no note — Telegram text is
    `Send /followup followed by a name or email and a short note.`
    No new `follow_ups` row. Last node is the confirm send path
    (usage is `ok` + `reply_text`), not the fail send.
20. `/followup <prove person> <short note>` — confirm card in
    Telegram, buttons present (`f7:s:` / `f7:n:` / `f7:x:`). WF-10
    execution exists. Do not mutate locked follow_ups rows.
21. Tap a non-`f7:` callback if one can be manufactured — still
    `Callback terminal`, no WF-10 call.
22. Voice note **without** `/followup` — still Duplicate check /
    capture path (asset count can increase). Proves §8 cut.
23. Unknown `/whatever` — still `Unknown type terminal` (index 12).
24. Force a WF-10 throw (architect method) — owner receives
    `Follow-up failed. Nothing was sent. Try again.` WF-01
    execution is success, last node `Followup no-send terminal`
    after `Send followup fail`.

---

## Apply order (later packet, not now)

1. GET WF-01. Confirm `versionId === baa462d8-5e69-417e-b068-1a6697f3d6c5`
   (rolled-back graph). Save body.
2. PUT WF-10: empty-brief compose → true usage line; skip
   `awaiting_voice` insert and `bot_state` await. No `active`.
   Strip `binaryMode` and `timeSavedMode`.
3. `POST /activate` WF-10 (`D9PRjbZMQxe9ESVW`) once.
4. PUT WF-01 with §1–§5 applied. No `active`. Strip `binaryMode` and `timeSavedMode`.
5. Run §10.
6. BotFather `/setcommands` add `followup` **only after** §10.16–18 pass.

This PREP packet stops before step 1.

---

## D. Disagreements with the Phase 7 plan

1. **Voice intercept is NOT in 7.4.** Plan §A.4 put it here.
   Capture path blast radius. Typed brief is enough for v1. See §8.
   Empty brief does **not** insert `awaiting_voice`. A row nothing
   can claim is a lie.
2. **No shared send node.** Plan §A.5 said pass `reply_markup` on
   the shared command send. Live WF-01 has four send nodes.
   Markup goes only on `Send followup reply`. That is how `/ask`
   `/digest` `/flag` stay proven.
3. **Activate WF-10 before the first Call.** Plan said publish
   WF-10 before adding the Call. The apply packet must
   `POST /activate` once. This PREP does not.
4. **n8n inlineKeyboard collection drops whole-array expressions.**
   Proven 10.20 and 7.4-B exec 271732. HTTP `sendMessage` cannot
   get the token. §4 send is fixed collection rows + scalar
   `text`/`callback_data` (exec 271606 / 271738 / 271747). Live
   confirm `sendMessage` result must still contain `reply_markup`.
5. **Call WF-10 cannot fail silent.** Plan left `onError` unset.
   A throw after the owner taps Send would return nothing. False
   branch of Followup has reply? is a real send. Silence is
   reserved for storage failure.

---

## What this file is not

- Not a PUT.
- Not a migration.
- Not an activation.
- Not a BotFather change.
- Not a voice build.
- Not a change to WF-02–WF-09.
