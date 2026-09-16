# Cursor handover — Phase 12 (multi-tenancy)

Paste this into a **new Cursor window**. Assume no memory of
Phase 10. You are the implementer. Architect/verifier is Claude.
Owner is Talal (CCIE; keep replies short).

Public repo: `https://github.com/talalbaig1/LEAP-NI`.
`main` only. Phase 10 and packet 10.1 are closed and
architect-verified.

Read first: `docs/rules.md`,
`.cursor/skills/lni-n8n-conventions/SKILL.md`,
`docs/workflows.md` §1, `docs/architecture.md` §4,
`docs/phases.md` Packet 10.1 + Phase 12.
Live JSON and live SQL beat this file.
Secrets stay in gitignored `docs/environment.local.md`.
Never commit it. Never copy a secret into chat or a
tracked file.

Phase 12 is **multi-tenancy**. Schema work identified in
10.1 (`person_emails`, `entity_candidates` pair storage,
a text config column) is **deferred inside this phase**,
not a reason to start with a migration.

**12.0a (docs, this window):** `docs/plans/phase-12-plan.md`.
Q1–Q5 **LOCKED**. D-L ACCEPTED. D-M D-N D-O locked.
12.1 (catalog 034, not written): `lni_settings` +
`lni_instance` + `bot_state` UNIQUE `(telegram_user_id)` +
assets UNIQUE `(owner_id, telegram_file_unique_id)` +
platform owner seed. Do not write 034 in 12.0a. Do not PUT.

Q1 ACCEPTED — tenant = `owner_id`. No `tenants` table.
Q2 AMENDED — permanent test tenant. Schema 12.1, live
second `bot_state` in 12.2. Never deleted, never frozen.
Q3 OVERRIDDEN — fail closed. No mailbox → no Gmail /
digest email (Telegram copy-text). No Apollo ceiling → 0.
Q4 OVERRIDDEN — fingerprint is `lni_instance`, not
`LEAP 2026`. After 12.1 that string is not in workflow
logic.
Q5 ROUTING ACCEPTED, OWNERSHIP OVERRIDDEN — operator
chat for alerts; platform `audit_log` owned by
`donotreplynis@gmail.com` (dotless). No `bot_state`.

---

## 1. Live workflow versions (GET 14 Sep 2026)

REST GET `/api/v1/workflows/{id}`, name-checked `LNI ` /
`LNI-TEST-` / `NIWL ` first. Published =
`activeVersionId`. Draft/top-level = `versionId`.
Rollback = previous version from live
`get_workflow_history` when that API still holds it;
otherwise the last **named** packet rollback, marked
`history-pruned`.

**Never publish WF-01 draft `e454df40` or WF-06 draft
`76840a2a`.** Both are 30 Aug canvas autosaves
(positions only; defaults stripped). Live GET still
shows those draft ids ≠ published. If either draft id
changes, someone wrote again — STOP.

| WF | id | active | published `activeVersionId` | draft `versionId` | rollback | nodes |
|---|---|---|---|---|---|---|
| 00 | `X7zKL3wTFPIhwyaN` | true | `be1e7b71-b55a-4bd8-a318-fa096ae0257d` | same | **12.2 rollback `5ec180fd-3270-433d-9e03-d0f2ff9ecd44`** | 15 |
| 00b | `Q1eMhUF67VAt3T8a` | **false** | none | `46330598-9abb-422e-817e-ec6ea620321a` | never activate | 6 |
| **01** | `ZMYx19qEr72mJoCX` | true | `4836ffd8-10e3-4d8c-963d-42bf0ccb9372` | **`e454df40-cc92-4a06-ba52-31fc0d1594c8` unpublished autosave** | named `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` (not in live history) | 137 |
| 02 | `BV0nukrQdOpDCPe4` | true | `eddb0f11-644a-47e2-a510-3098a090c510` | same (autosaved 10 Sep 17:40Z) | named `ce51e6f4` 10.2c (history API returns only current) | 98 |
| 03 | `k0bPD3GJBNN2EHDB` | true | `852f300b-069e-4763-b97b-3068fbf06a9b` | same | history-pruned | 38 |
| 04 | `cxyvgBJC1DD8LEbU` | true | `6fa41bc4-175f-4787-8b91-458e502e4a62` | same | named `dafe9b02` 10.2c-fix (history-pruned) | 29 |
| 05 | `Iv0loGijYVH77OGh` | true | `68f47505-36b6-4843-98e1-16892a098aa2` | same | named `74b08d0f` (history-pruned) | 29 |
| **06** | `eNlgt1wk9Z8Nefwy` | true | `356a2d1f-daf1-4560-a68f-4df82ff64ceb` | **`76840a2a-3d4f-454e-86ff-0f70bca48ca1` unpublished autosave** | named `f6b39538-28ae-4946-ac81-504c9f004c36` | 53 |
| 07 | `AyPtkP8PMFeEdYU9` | true | `9197f7a3-af51-41aa-8ea2-8f32a7670726` | same | **12.2 rollback `fb9ee1c4-6b40-4064-af22-950b78a45544`** | 27 |
| 08 | `QIioJBxuZYJh5R4W` | true | `8b835659-6179-4472-9f78-f096bdaba841` | same | **12.2 rollback `b699e7d6-ecd4-431d-86ff-d61bd1472390`** | 19 |
| 09 | `m0lvc9dzpyxLj2hI` | true | `fdd6fe67-9cc4-4b05-af20-3994f3e1e859` | same | named `f3885d5a-4eb9-41d0-96ae-91115c69fcaf` | 43 |
| 10 | `D9PRjbZMQxe9ESVW` | true | `226fe197-39bf-497c-ad4f-2735740f0547` | same | **`fd8b7f9b-f156-4295-ae92-87fa21c98350` (live history)** | 172 |
| NIWL-01 | `qsBvL6myQxqfZldF` | true | `93dccd28-cb98-4862-8c92-e43260d471f2` | same | history-pruned | 16 |
| NIWL-00 | `mt72Ygk6KqoIhisT` | **false** | none | `fc46433a-ee1b-4b1c-8e1d-22290d7a8fff` | never activate | 6 |

`sanitize_for_put` on an active workflow **must** take
nodes/connections from `activeVersion`. Do not PUT to
make draft `versionId` match `activeVersionId`.

WF-10 History skip after 10.1: UUID skip is Zahir kaacib
`ba037ac0` only. Name skips:
`saad raja`, `ali abbas`, `rana waleed`, `abbod`,
`aadil abbasi usa`. Voice Gmail stays
`resource=message` `operation=send`. History Gmail stays
`resource=draft` `operation=create`.

---

## 2. Migration catalogue (live `list_migrations` 14 Sep)

Highest applied: **`035_operator_chat`**
catalog `20260916024816`. 030 still reserved Phase 6.
Next LNI schema number is **036**.

| Catalog name | Version | Notes |
|---|---|---|
| `001`–`011`, `013`–`022`, `024`–`028` | as numbered | |
| **012 absent by design** | — | `012_seed_bot_state` never applied. `current_setting('lni.owner_telegram_user_id')` without `missing_ok` raised. File kept as history. Superseded by 014. |
| **023 unannounced** | `20260828013026` | Live name **`processing_jobs_enrichment_person_uniq`** (no `023_` prefix). Do not re-apply. |
| **029 no prefix** | `20260829054006` | Live name **`people_source_type_contact`**. Same class as 023. Do not re-apply. |
| **030 reserved** | — | Phase 6 embeddings / pgvector. **Not applied.** Do not take 031–033 for this. |
| 031 | `20260914060746` | `031_sender_profile_history` — `sender_profile` + `follow_ups.channel` + `gmail_draft` + partial unique `(person_id, channel)` |
| 032 | `20260914074931` | `032_sender_profile_signature_html` — HTML `signature_block` typography. No new columns. |
| 033 | `20260914083604` | `033_sender_profile_channel_signatures` — `signature_whatsapp` + `signature_linkedin` |
| 034 | `20260916022806` | `034_multitenancy_foundation` — packet 12.1 |
| 035 | `20260916024816` | `035_operator_chat` — packet 12.2. `operator_chat_id` + `lni_settings` updated_at trigger |

Next LNI schema number is **036**. Phase 12 must not steal 030.

---

## 3. `sanitize_for_put` — verbatim, and why it raises

```
def sanitize_for_put(wf):
    settings = dict(wf.get('settings') or {})
    settings.pop('binaryMode', None)
    settings.pop('timeSavedMode', None)
    published = wf.get('activeVersion') or {}
    if wf.get('active') or wf.get('activeVersionId'):
        nodes = published.get('nodes')
        connections = published.get('connections')
        if not nodes or connections is None:
            raise RuntimeError(
                'active workflow missing activeVersion graph; '
                'refusing top-level draft PUT'
            )
    else:
        nodes = wf.get('nodes')
        connections = wf.get('connections')
    return {
        'name': wf['name'],
        'nodes': nodes,
        'connections': connections,
        'settings': settings,
    }
```

**Why raise, never fall back to top-level nodes.** GET
top-level is the **canvas draft**. Opening a workflow
autosaves and bumps top-level `versionId` with no API
write (WF-01 / WF-06, 30 Aug 05:20Z). That draft stripped
explicit params that equal node defaults (`download:true`
on getFile vcard, `batchSize:1` on WF-06, …). None of it
has run on a device. Falling back to top-level would
silently PUT the autosave and look like a restore.
Published graph is `activeVersion.nodes` /
`activeVersion.connections`. If `activeVersion` is
missing on an active workflow, STOP — do not guess.

Also strip: top-level `active` (read-only; PUT with it is
400), `versionId`, `settings.binaryMode`,
`settings.timeSavedMode`. GET name, then act. Names
must begin `LNI `, `LNI-TEST-`, or `NIWL `.

---

## 4. Open defects (cause already established)

Do not "fix" these out of a named packet. Do not INSERT
or UPDATE `interactions.person_id` by hand.

**S3 incomplete.** Typed-note-only captures closed by
`Action done` used to enqueue 0 jobs; WF-05 never ran
(#161 #80 #11 #24 #44). 10.2b shipped a note-only
`Call WF-04 note` path and an extraction `NOT EXISTS`
idempotency guard. **Completion and R4 clobber were
deferred to 10.2d and 10.2d was never built.** Residual:
note-only extraction is not the finished packet; do not
assume every typed note has an `extraction_runs` row.

**S6.** Person minted with no interaction. Ahmed Alkaf
`32c8efee`, capture **#153**, `source_type=card`.
**Cause (10.2a):** `Insert interaction` ran. It wrote
**one** row, `person_id` = Ali Abbas `4efe1828`
(people[0], note, no email). Ahmed is people[1]. Guard
is `LIMIT 1` plus `WHERE NOT EXISTS (capture_id)` — one
interaction per capture; first join hit wins. Upsert
still mints everyone else. Shared pattern: second person
on a multi-person extraction. **Do not INSERT an
interaction by hand.**

**S8.** WF-05 `Set capture status` (`68f47505`) is
`UPDATE captures SET status=ready|needs_review WHERE
id=$1` — no prior-status predicate. It can write `ready`
onto `status='open'`. Standalone contact (#134 #160)
depends on that. A reused open `/new` block must not
Call WF-05 or the pointer dies mid-capture. 10.2c
kick-split is a **discipline** guarantee, not structural.
Structural fix is close-the-capture-before-WF-05.
**Do not fix in 10.2c. WF-05 stays `68f47505`.**

**S9 residual.** Replay-minted person has no
`interactions` row. WF-05 `Insert interaction` is
`WHERE NOT EXISTS (… capture_id)` — S6's one-row-per-
capture guard. Prior row already exists with
`person_id` NULL (or pointed at the old person). 10.1
merged ten duplicate **people** rows and moved children;
it did **not** backfill S9. Live after 10.1: **8**
interactions with `person_id` NULL, **0** missing-person
orphans. `/ask` and digests will not see replayed people
(or will see the old person without contact fields).
Outreach joins `people` directly, so it is unaffected.
**Do not UPDATE `person_id` by hand.**

**`entity_candidates` unreviewable.** 77 pending (61
pre-window + 16 in-window). 10.1 Part D left them
pending: `rejected` would claim a review nobody did. No
migration 034. The row stores `candidate_entity_id` +
`score` + `reasons[]` — no stored pair, no human-readable
why. 37 hardcoded score=1; 40 computed `name_trgm`
`similarity()` 0.3–0.6875. `{name_trgm}` is not a reason
a human can act on. Rework is Phase 12.

**`draft_state='gmail_draft'` misuse.** 031 added
`gmail_draft` for unsent Gmail drafts. WhatsApp / LinkedIn
copy-text on Telegram also writes `gmail_draft` because
031 has **no** `handed_off`. Unique live index is
`(person_id, channel) WHERE draft_state <> 'cancelled'`.
A Gmail draft is not a touch (`second_touch` keys on
`draft_state='sent'` only — CH4). Do not treat
`gmail_draft` as "emailed".

**Six `channel` NULL sent rows.** Pre-031 voice/command
sends. Unique index does not apply (`channel` NULL).
Do not backfill. Do not add 033-style uniqueness that
would collide. Live ids (14 Sep):

| follow_ups id | person |
|---|---|
| `2ea079a3` | LNI Followup Prove `ec5dc966` |
| `e5bf5982` | same |
| `bb3689d8` | Khaled — **locked sent evidence** |
| `18a40724` | (pre-031 send) |
| `a8dc84ea` | Rana Waleed `fc2ba74f` |
| `4c58b08a` | DES RAJ `61b14e31` |

---

## 5. Schema work identified and deliberately deferred

Not under time pressure. Not 10.1. Not 034 unless a
Phase 12 packet names it.

1. **`person_emails` (or equivalent).** `people.email` is
   one column, UNIQUE `(owner_id, email_normalized)`.
   Two employers with two emails is a normal networking
   case (Muhammad Zahir `d2335783` haramain + `ba037ac0`
   kaacib — **not merged**, outreach already dual-To:).
   One human needs several emails, phones, titles,
   employers.
2. **`entity_candidates` pair storage.** Stored pair +
   human-readable reasons. Current row cannot be
   reviewed. 61 pre-window pending stay pending.
3. **A text config column.** `lni_config.value` is
   **integer** (020). It cannot hold a signature or a
   tenant display name. Do **not** add `value_text` on
   `lni_config` (mixes ceilings with prose). Signature
   home is already `sender_profile` (031–033). Phase 12
   multi-tenancy still needs a text config home that is
   not integer ceilings and not stolen 030.

`person_companies` already allows two current employers
(DES RAJ: Aliph + Utopian). No UNIQUE `(person_id,
company_id)`.

---

## 6. Traps — session-10 §4 in full

These are the node-level gotchas carried as
session-10 section 4 (same text as
`docs/sessions/cursor-handover-to-session-09.md` §4,
still live after Phase 10). Copy them; do not summarise.

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
the old fallback target.

Phase 10 added, same rank:

- History Gmail is `draft`/`create`. Voice Gmail stays
  `message`/`send`. Do not swap them.
- `Extract history draft` is a **sibling** OpenAI node.
  Live `Extract draft` expressions require command/voice
  nodes and throw on `source=history`.
- One-webhook multi-person fails when Extract and
  template mix (`History parse` pairing). Kick **one
  person per webhook**.
- `second_touch` is `draft_state='sent'` only. A Gmail
  draft is not a touch.
- `wa.me` is Meta click-to-chat. Country code **996 is
  Kyrgyzstan**; do not auto-correct to 966.
- MCP `execute_workflow` cannot run an
  Execute-Workflow-only graph. History kick is
  `POST /webhook/lni-wf10-history`.
- MCP `create_workflow_from_code` binds the **first**
  credential of each type on the instance (ElderWise
  Postgres, random Telegram, **Serper Header Auth** on
  NIWL). Rebind. Believe a self-identify execution.

---

## 7. What must NEVER be touched

**ElderWise.** Any workflow whose name does not begin
`LNI `, `LNI-TEST-`, or `NIWL `. The shared n8n
container: no restart, no upgrade, no instance settings,
do not remove `N8N_BLOCK_ENV_ACCESS_IN_NODE`. ElderWise
Postgres `WH9oLDfKfOX6KW5F`. ElderWise error workflow
`uvBstI6J42nNhIYz`. Generic `Tavily account`
`HPwLtKmZ43pOFRg5`.

**Locked evidence — do not delete, do not re-send, do
not email, do not "fix" Invariant A.**

Captures: `#9 #62 #63 #66 #68 #69 #73 #75 #82 #83 #85
#86 #87 #120 #130 #131 #132 #133 #134 #135 #136 #146`
(#146 = 30 Aug phone proof that capture survived the
canvas autosave).

follow_ups: `5df341f8` (Ahmed, awaiting_confirm, **never
touch**), `6f3c13b3` (#120), `bb3689d8` (sent,
`gmail_message_id=1a04c9a684523738`), `f210d77d`
(cancelled 9.11 — do not re-send).

People: `9489be75` Ahmed Eltohfa, `ec5dc966` LNI
Followup Prove, `d8b051cb` Faisal, `09dfa793` Amer,
`4151e101` Aadil Abbasi USA (test — 10.1 did not
touch), `c52a10e9` LNI Test Contact (`vcard`).

Jobs: `1564abc3`, `f6a1e703`. Ledger: `73fc2831`
(Apollo confirmed / 1 for a 0-credit probe; lifetime
over-count of 1; do not edit).

Do not PUT WF-01 unless a packet says so. Do not merge
the two Muhammad Zahir rows. Do not set the 61 pending
candidates to `rejected`. Do not activate WF-00b or
NIWL WF-00.

---

## Phase 12 start — facts

- Owner `a79b744e-4134-4d1b-930f-52eb34d3a64f`.
- Supabase project `ldiqggebccsynaujgkdt`. Bucket
  `lni-assets`.
- After 10.1: people 74, interactions 125, follow_ups
  108, person_companies 55. Missing-person orphans 0.
- `$env` and `$getWorkflowStaticData` remain forbidden.
- Postgres only via Supavisor pooler, port 6543,
  transaction mode, no prepared statements.
- `queryReplacement` is **one** expression that evaluates
  to an array.
- jsCode via REST: no `\d \w \s \b`, or double every
  backslash.
- Multi-tenancy is new. Do not invent a tenant column on
  `lni_config.value` (integer). Do not steal 030.
- Docs first. GET name, then act.
