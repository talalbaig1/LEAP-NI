# Phase 12 — Multi-tenancy

**Date:** 14 Sep 2026 · **Amended:** 16 Sep 2026 (packet 12.4e)
**Status:** Q1–Q5 LOCKED. D-L ACCEPTED. D-M D-N D-O locked.
Packet **12.1 applied** (catalog `034_multitenancy_foundation`,
`20260916022806`). Packet **12.2 applied** (catalog
`035_operator_chat`, `20260916024816`). Packet **12.2a
applied** (catalog `036_digest_email`,
`20260916030417`). Packet **12.3c / 12.2b-i applied**
(catalog `037_test_tenant`, `20260916033502`) — inert
test tenant, **no `bot_state`**. Packet **12.4b applied**
(WF-07 `<WF07_PUBLISHED>`, rollback `<WF07_ROLLBACK>`). Packet **12.4e
applied** (catalog `038_restore_assets_single_unique`,
`20260916043514`) — column-only assets unique restored
TEMPORARY so published WF-01 Insert asset can infer.
No WF-01 PUT. E1–E3 fixed.
Kind on demand `source` literal `call`. WF-01 / WF-06
drafts untouched. Full
cross-tenant isolation is **not** proven here (12.5).
**Home:** this file. Contracts also in `phases.md` Phase 12,
`architecture.md` §4, `masterplan.md` D-L…D-Q, `prd.md` §8c,
`workflows.md` §1 owner-resolution.

Packet 10.1 closed. Highest applied migration is
`038_restore_assets_single_unique` (catalog `20260916043514`).
**030 stays Phase 6 embeddings.**

Product name is **Networking Intelligence System (NIS)**.
`LNI` is the legacy internal code prefix (D-N). Internal
identifiers do not change.

---

## What this phase is

The schema already stamps `owner_id` on every user-owned
table and RLS-scopes it. Launch used **one** owner
(`<OWNER_ID>`). Workflows still find that owner by the seed
event name `LEAP 2026`. A second human cannot run.

Phase 12 makes a second owner real. It is **not** a new
`tenant_id` column on every table.

Plain picture: `owner_id` is already the customer tag on
every row (like a VRF). Isolation in Postgres is done.
The broken part is how n8n *picks* the customer — it
looks up the event named LEAP 2026 and takes that one
`owner_id`. Cron jobs (digest, enrichment drain,
watchdog) therefore serve one person. `lni_config.value`
is integer-only, so there is nowhere to store a display
name. The fingerprint itself lives in a tenant row, which
a shared instance must not do. That is the work.

NIWL (waitlist intake on the same n8n host) is **not** an
NIS tenant. Do not activate NIWL WF-00. Do not bind LNI
workflows to NIWL credentials.

---

## Live facts (SQL + GET, 14 Sep 2026)

| Fact | Value |
|---|---|
| `auth.users` | 3 (owner + two Phase 0 RLS probes) |
| `bot_state` / `events` / `sender_profile` | 1 row each, all `<OWNER_ID>` |
| `people.owner_id` distinct | 1 |
| `lni_config` | 3 integer keys (Apollo daily 60, lifetime 2200, Tavily 1000) |
| `person_emails` / `tenants` | **absent** |
| `lni_settings` / `lni_instance` | **live 16 Sep (034)** |
| Pending `entity_candidates` | 77 (61 pre-window + 16 in-window) |
| `assets_telegram_file_unique_id_key` | **restored 16 Sep 12.4e** (038 `20260916043514`). TEMPORARY. Coexists with UNIQUE `(owner_id, telegram_file_unique_id)`. Drop in 12.2 remainder WF-01 PUT. |
| `bot_state` unique | `(owner_id, telegram_user_id)` **and** `(telegram_user_id)` |
| WF-01 published | `<WF01_PUBLISHED>` · draft still `<WF01_DRAFT>` (30 Aug autosave) |
| WF-06 published | `<WF06_PUBLISHED>` · draft still `<WF06_DRAFT>` (30 Aug autosave) |

If either unpublished draft id changes, someone wrote
the canvas — STOP.

---

## Locked here (D-L ACCEPTED)

**Tenant = `owner_id`.** One `auth.users` row owns
`bot_state`, `events`, `sender_profile`, `lni_config`,
`lni_settings` (12.1), and all children. No `tenants`
table. No parallel `tenant_id`. No `value_text` on
`lni_config`.

A second human is:

1. An Auth user (same pattern as migration 009: match by
   email setting, never “earliest row”).
2. A `bot_state` row (`telegram_user_id` globally unique).
3. An `events` row (name need not be `LEAP 2026`).
4. `sender_profile` + integer `lni_config` ceilings +
   text `lni_settings`.

`bot_state` is still the WF-01 allowlist. Unknown Telegram
senders stay silent.

The **platform owner** (D-O) is not a tenant. It owns
platform `audit_log` rows only. No `bot_state`, no
`events`, no `sender_profile`. Never a sender.

The **permanent test tenant** (Q2) is a tenant. Schema in
12.1. **12.2b-i** (037, applied 16 Sep): `events` +
ceilings + `sender_profile`. **No `bot_state`.** **No
`digest_email`.** Invisible to cron and WF-01. Never
deleted, never frozen — standing cross-tenant regression
harness, same principle as capture #9. Live second
`bot_state` is still **12.2b**. Do not assert an allowlist
row the database does not have.

---

## 12.1 tables (applied 16 Sep, catalog 034)

Catalog **034_multitenancy_foundation**
(`20260916022806`). 030 stays Phase 6.

### `lni_settings`

Text config home. **Not** `lni_config` (integer ceilings).
**Not** `sender_profile` (signatures, D-I). **Not** 030.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `owner_id` | uuid → `auth.users` | NOT NULL |
| `key` | text | NOT NULL |
| `value` | text | NOT NULL |
| `created_at` | timestamptz | `now()` |
| `updated_at` | timestamptz | `now()` |

UNIQUE `(owner_id, key)`. RLS
`lni_settings_owner_all`, same shape as `lni_config`.
n8n `service_role` still bypasses RLS.

Seed for the live owner, key `display_name`. Do not
invent other keys in 12.1. Signatures stay on
`sender_profile`.

### `lni_instance`

Instance fingerprint. **Not owner-scoped.** One row.
Lives next to `lni_public_suffixes`, not inside
`events`. After 12.1 the string `LEAP 2026` appears
**nowhere in workflow logic** — only in one tenant's
`events` row, where it belongs (Q4).

Writes: service_role / owner migrations only. SELECT for
`authenticated` (same family as `lni_public_suffixes`).
Exact columns named in 12.1. One row, instance name.

### Platform owner seed (D-O)

Dedicated `auth.users` row. Canonical, **dotless**:
`<PLATFORM_EMAIL>`. Gmail ignores dots; a dotted
variant would mint a second Auth user on the same inbox.

Identity, never a sender. No `bot_state`, no `events`,
no `sender_profile`. Must not later be promoted to the
system mail sender. Platform `audit_log.owner_id` is this
row. WF-00 Telegram alerts still go to the operator chat
(Q5 routing).

### Uniques in the same 034

Live `bot_state` unique is `(owner_id, telegram_user_id)`
only. WF-01 looks up by `telegram_user_id` alone. 12.1
adds **global `UNIQUE (telegram_user_id)`**. Live row
count is 1, so it applies cleanly.

Live `assets_telegram_file_unique_id_key` is UNIQUE on
the **column alone**. Telegram `file_unique_id` is stable
across bots **and** users. Two tenants sending the same
file: the second hits Duplicate terminal, no asset, no
WF-02, silent. That is cross-tenant **capture loss**.
Previously logged out of scope. **Reversed.** 12.1
replaces it with **`(owner_id, telegram_file_unique_id)`**.
Mandatory. Same packet as the other 034 work.

---

## Owner resolution vs self-identify (Q4 LOCKED)

Today those are the same SELECT:

```
SELECT name, timezone, owner_id
FROM public.events
WHERE name = 'LEAP 2026'
LIMIT 1
```

That SELECT does two jobs. Split them. The fingerprint
must not be a tenant's data row. `events` is
owner-scoped.

| Job | After 12.1 / 12.2 | Why |
|---|---|---|
| **Database fingerprint** | `lni_instance` (one row). Miss → `stopAndError` wrong-database. | Proves this instance, not ElderWise. Not Talal's event. |
| **Who is this user?** | Inbound: `bot_state` by `telegram_user_id`. Cron: every tenant `bot_state.owner_id`. Never the platform owner. | A second owner has a different event name. |

After 12.1, workflow logic must not contain the string
`LEAP 2026`. Do not hardcode `<OWNER_ID>`. Do not resolve
owner from `$env`.

**WF-00 routing (Q5).** Telegram alerts stay on the
**operator** chat. **Ownership:** `audit_log.owner_id`
for platform errors is the platform owner, not the live
tenant. Writing tenant errors under Talal's id pollutes
his data and will show in the Phase 5 dashboard under
RLS.

---

## Credentials — fail closed (D-M / Q3 LOCKED)

Per-owner Gmail / OpenAI / Apollo stay **out of Phase 12**.
Shared credentials are **not** the workaround.

- A tenant with **no linked mailbox** gets **no** Gmail
  draft and **no** digest email. They receive composed
  copy-text in Telegram (already the D-E pattern for
  WhatsApp and LinkedIn).
- A tenant with **no** `lni_config` Apollo ceiling row is
  treated as **ceiling 0**, never unlimited. Missing
  config fails closed.
- A second tenant's drafts landing in the live owner's
  mailbox is a **privacy defect**, not a fallback.

Until a later packet names a mailbox-link row, absence of
an explicit link means no Gmail. Do not invent a refresh
token column. Do not send another tenant's mail through
the instance Gmail credential.

---

## What stays global vs what 12.1 changes

| Object | Decision | Reason |
|---|---|---|
| `captures.capture_no` | Stays global identity | Per-owner counter serialises `/batch`. Receipts stay `#47`. **12.2 audit:** every query that resolves a capture **by number** must be `WHERE capture_no = $n AND owner_id = $owner`. Number alone is a cross-tenant vector. |
| `assets.telegram_file_unique_id` | **Changes in 12.1** | Live unique is the column alone (`assets_telegram_file_unique_id_key`). Becomes `(owner_id, telegram_file_unique_id)`. Capture loss otherwise. |
| `bot_state.telegram_user_id` | **Changes in 12.1** | Adds global UNIQUE. Live unique is `(owner_id, telegram_user_id)` only. |
| `lni_public_suffixes` | Not owner-scoped | Reference list. `lni_instance` sits in the same class. |
| Storage path `{owner_id}/…` | **Unverified** | Bucket policy is `foldername(name)[1] = auth.uid()`. n8n writes over REST and bypasses it. Whether WF-01 actually writes an owner-prefixed path is a **12.2 read-back**, not an assumption. |

Owner-scoped uniques already: `events (owner_id, name)`,
`people (owner_id, email_normalized)`,
`lni_config (owner_id, key)`,
`sender_profile (owner_id)`.

---

## Deferred inside this phase (not 12.0, not 12.1)

Logged in 10.1. Not a reason to start with a migration.

### Packet 12.3 — `person_emails` (or equivalent)

`people.email` is one column, UNIQUE
`(owner_id, email_normalized)`. <CONTACT_3_NAME>
`d2335783` (<CONTACT_4_COMPANY>) + `ba037ac0` (<CONTACT_2_COMPANY>) stay two
rows until this exists. Outreach already dual-To:.
**Do not merge.** Same human also needs several phones
and titles; `person_companies` already allows two current
employers (<CONTACT_14_NAME>: Aliph + Utopian).

### Packet 12.4 — `entity_candidates` pair storage

77 pending. 10.1 left them pending: `rejected` would
claim a review nobody did. Row today:
`candidate_entity_id` + `score` + `reasons[]`. No stored
pair. `{name_trgm}` is not a human reason. 61 pre-window
stay pending through 12.4.

### Packet 12.2b-i — inert test tenant (applied 16 Sep)

Catalog **037_test_tenant** (`20260916033502`). Auth user
created in the dashboard (do **not** reopen public
signup). Exact email match. `events` name `NIS test
tenant` (not `LEAP 2026`, timezone `Pacific/Auckland`).
Ceilings + `sender_profile`. **No `bot_state`.** **No
`digest_email`** (D2d). Never deleted. Never frozen.

### Packet 12.2b — permanent test tenant `bot_state` (slipped from 12.2)

12.2 did **not** land a second `bot_state` row. Live count
is still 1. 12.2b-i is inert only. Give `bot_state` its
own packet. Needed before 12.5 can pass.

### Packet 12.4b — hourly fan-out N>1 (E1–E3)

**Fixed in 12.4b.** WF-07 PUT `<WF07_PUBLISHED>` (named rollback
`<WF07_ROLLBACK>` before the first 12.4b PUT). Chain:
`9197f7a3` (12.2) → `becd329b` (12.2a) → `<WF07_ROLLBACK>`
(12.3b) → `<WF07_PUBLISHED>` (12.4b). Self identify, Load digest
(mail CTE), Compose digest, and List due owners were not
changed.

**E1. `Any delivered?`** — `executeOnce` removed. Delivery
reads the **current** merged item: Telegram
`result.message_id` or `message_id`, Gmail `id`. Named
`.first()` / `.last()` / `isExecuted` across the whole
run would still report owner 1's Gmail for owner 2.

**E2. `Wait both channels`** — `combine` /
`combineByPosition` pairs Telegram + Gmail (or skip)
inside the current owner's iteration. `Each owner`
(SplitInBatches v3, batchSize 1; output 0 done, output 1
loop) serializes the scheduled path. Loop → Load digest;
done → `Fan-out done`. `Scheduled done` / audit-recorded
loop back.

**E3. Empty / undeliverable on the scheduled path** —
`stopAndError` no longer aborts owners N+1..M. Empty
Load digest → `Scheduled empty?` true → `Record empty
digest` (`audit_log.action = digest_undeliverable`,
`after.reason = empty_digest`) → continue. Both channels
empty → `Record undeliverable` (`after.reason =
both_channels_empty`) → continue. On-demand still
`Empty digest terminal` / `stopAndError` (one caller,
one owner). Audit write failure still throws.

Kind on demand `source` is the literal `call`. A caller
cannot make WF-07 send.

N=2 **failure isolation** proven Hourly tick exec
**483257**. N=2 **successful** delivery to two real
chats is **not** proven — that is 12.5.

Same-packet intermediates (named before each PUT):
`353f649a` (03:49:23) → `feb5f066` (03:51:57) →
`<WF07_PUBLISHED>` (03:53:25). Immediate predecessor of
`<WF07_PUBLISHED>` is `feb5f066`. Packet restore is `<WF07_ROLLBACK>`.

### Packet 12.4c — reconcile `<WF07_PUBLISHED>` (docs only, 16 Sep)

No PUT. No rollback issued. `<WF07_PUBLISHED>` is a **12.4b**
build. The unattended 04:00Z tick exec **483309** ran on
it. Filing that tick under packet 12.3 was a standing-
rule slip.

**Rollback for `<WF07_PUBLISHED>` (recorded here):** packet
restore `<WF07_ROLLBACK>` — captured **before** the first 12.4b
PUT. Immediate predecessor `feb5f066` — captured
**before** the PUT that created `<WF07_PUBLISHED>`. The two
intermediates are written into docs after the fact
(they were already in n8n history).

Chain: `9197f7a3` (12.2) → `becd329b` (12.2a) →
`<WF07_ROLLBACK>` (12.3b) → `<WF07_PUBLISHED>` (12.4b). D3 **483257**
status **success** (completed, last node Fan-out done).

### Packet 12.5 — isolation proven (two real accounts)

Two real `bot_state` rows. Cross-tenant proof. Depends
on 12.2b (second tenant exists) and 12.4b (fan-out does
not lie about the second owner). Not the login surface.

### Packet 12.6 — login surface (after isolation)

Minimal login: Supabase Auth, Google/Microsoft,
Telegram-ID capture. **Dependency, not a shortcut.**
Isolation (12.5) is proven first. Isolation before
there is a door.

**Onboarding notes (found 12.3c, record for 12.6):**

**E1.** A tenant with no `events` row hits `stopAndError`
on `/digest` (`Empty digest terminal`). Tenant creation
must seed `events`, or WF-07 must answer gracefully.
Found by exec **482941**.

**E2.** A tenant with no `lni_config` ceiling row gets
**ZERO** enrichment, silently — correct per D-M, but
tenant creation must seed ceilings or the tenant never
learns why nothing happens.

**E3.** Owner IU Microsoft account reserved as a Phase 14
OAuth tenant, while that account is still held. Not the
permanent harness. Token `<OWNER_IU_EMAIL>`.

**E4 (12.5a-0c / 12.5a-0h).** Fresh-deploy owner /
platform / test tenant seed must use the `009`
`current_setting` pattern (already flagged 2b).
**12.5a-0h rewrite tokenised 034 and 037** to
`<PLATFORM_EMAIL>` / `<TEST_TENANT_EMAIL>`. Those
files are **no longer re-runnable**. Making them
re-runnable is 12.6, not a re-apply of 034/037.

---

## Packets

| Packet | What | Migration | Workflows |
|---|---|---|---|
| **12.0 / 12.0a** | This plan. Docs only. Q1–Q5 locked. | none | none |
| **12.1** | `lni_settings` + `lni_instance` + `bot_state` UNIQUE `(telegram_user_id)` + assets composite unique + platform owner seed | **034 applied** (`20260916022806`) | none. WF-01/06 drafts untouched. |
| **12.2** | Split self-id onto `lni_instance`. WF-07 hourly fan-out per owner local hour. Fail-closed Gmail. `operator_chat_id` seed. WF-00 platform `audit_log.owner_id`. | **035 applied** (`20260916024816`) | WF-00 / WF-07 / WF-08 only. **No unpublished-draft publish.** WF-01/02/06/09 stay. Test tenant **slipped → 12.2b**. capture_no audit later. |
| **12.2a** | `digest_email` door. WF-07 Load digest lookup. Record N>1 fan-out as 12.4b. WF-06 Apollo ceiling cause only. | **036 applied** (`20260916030417`) | WF-07 only. **No unpublished-draft publish.** No WF-06 PUT. |
| **12.2b-i** | Inert test tenant. `events` + ceilings + `sender_profile`. No `bot_state`. No `digest_email`. | **037 applied** (`20260916033502`) | none. D2d via existing TEST caller. |
| **12.2b** | Permanent test tenant `bot_state` (slipped from 12.2) | named then | none until named |
| **12.3** | `person_emails` | 035-class, named then | WF-05 / WF-10 only if the packet says so |
| **12.4** | `entity_candidates` pair + human reasons | named then | WF-05 |
| **12.4b** | Fix E1–E3 hourly fan-out for N>1. Revert Kind on demand `source` to literal `call`. | none | WF-07 PUT `<WF07_PUBLISHED>` (rollback `<WF07_ROLLBACK>`). **Before 12.5.** |
| **12.4c** | Reconcile `<WF07_PUBLISHED>`. PUT history, rollback, versions_diff, D3 success, 12.3c D2d errors. | none | **No PUT.** |
| **12.4e** | Restore capture. Re-CREATE UNIQUE `(telegram_file_unique_id)` TEMPORARY. Keep composite unique. No WF-01 PUT. | **038 applied** (`20260916043514`) | **No PUT.** Drop the column-only unique in **12.2 remainder** when WF-01 Insert asset is PUT to `(owner_id, telegram_file_unique_id)`. |
| **12.5a-0** | Close WF-10 public History webhook. Normalize: no owner_id fallback. | none | WF-10 only. Rollback `<WF10_ROLLBACK>`. 12.5a C/D/E/G wait. |
| **12.5a-0b** | Archive two ACTIVE `LNI-TEST- 10.4b` webhooks. Cause-only on WF-01 `Driver ingest`. Full-history repo literal audit. | none | TEST 10.4b ×2: deactivate then archive (do not delete). **No WF-01 PUT.** 12.5a C/D/E/G wait. |
| **12.5a-0c** | Close public signup. Plan history scrub (no rewrite). Rule 25 + CI. Correct NIWL-privacy claim. | none | **No PUT. No rewrite. No force-push.** 12.5a C/D/E/G wait. |
| **12.5a-0d** | Amend scrub map (names + company domains). Narrow rule 25. Squash-merge #81. | none | **No PUT. No rewrite. No force-push.** Confirm email still owner (item 11). 12.5a C/D/E/G wait. |
| **12.5a-0e** | Reconcile #81. Drop ordinary company tokens. Names as `(?i)\\b` regex. Drop github handle. | none | **No PUT. No rewrite. No force-push.** Map gitignored. Merged by 12.5a-0h A2 (#82). |
| **12.5a-0f** | Dry-run rewrite on throwaway clone. | none | **Nothing pushed.** C2=16 (8-char prefixes ate full version UUIDs). |
| **12.5a-0g** | Map fix: full UUIDs above 8-char prefixes. Second dry-run. Squash-merge #83 (2c). | none | **Nothing pushed.** C2=0. |
| **12.5a-0h** | Real rewrite. Backup, resolve #82, filter-repo, force-push main. | none | **No PUT. No canvas.** 12.5a C/D/E/G still unstarted. |
| **12.5** | Isolation proven with two real accounts | none | proof, not a PUT |
| **12.6** | Minimal login surface | named then | none until 12.5 proven |

One packet at a time. Architect verifies live SQL / live
JSON. Implementer report is not evidence.

---

## Q1–Q5 — LOCKED 14 Sep 2026

**Q1. Tenant identity.** ACCEPTED. Tenant = `owner_id`.
No `tenants` table. D-L ACCEPTED.

**Q2. Second owner.** AMENDED. Permanent test tenant, not
a throwaway. Schema in 12.1. **12.2b-i applied** (037):
inert `events` + ceilings + `sender_profile`. Live second
`bot_state` **still slipped** — packet **12.2b**. Never
deleted. Never frozen. Standing cross-tenant regression
harness, same principle as capture #9.

**Q3. Per-owner Gmail / OpenAI / Apollo.** OVERRIDDEN.
Stay out of Phase 12. Behaviour is **fail closed**, not
shared credentials. No linked mailbox → no Gmail draft,
no digest email; Telegram copy-text (D-E). No Apollo
ceiling row → ceiling 0, never unlimited. A second
tenant's drafts in the live owner's mailbox is a privacy
defect. D-M.

**Q4. Self-identify.** OVERRIDDEN. Split self-identify
from owner lookup. The fingerprint must **not** be a
tenant's data row. 12.1 creates non-owner-scoped
`lni_instance` (one row, instance name). After 12.1 the
string `LEAP 2026` appears nowhere in workflow logic —
only in one tenant's `events` row.

**Q5. WF-00.** ROUTING ACCEPTED, OWNERSHIP OVERRIDDEN.
Alerts stay on the operator chat. `audit_log.owner_id` is
NOT NULL, so tenant errors must not be written under the
live owner's id. 12.1 seeds a dedicated platform
`auth.users` row (`<PLATFORM_EMAIL>`, dotless).
Platform errors are owned by it, inside no tenant. D-O.

---

## Non-goals (12.0 / 12.0a and until a packet names them)

- No migration beyond those named in an applied packet.
- `value_text` on `lni_config`.
- Stealing 030.
- PUT any workflow. Do not publish drafts `<WF01_DRAFT>` /
  `<WF06_DRAFT>`.
- Activate WF-00b or NIWL WF-00.
- Merge the two <CONTACT_3_NAME> rows.
- Set the 61 pending candidates to `rejected`.
- INSERT/UPDATE `interactions.person_id` (S6/S9).
- Fix S8 (WF-05 stays `<WF05_PUBLISHED>`).
- Per-owner n8n credentials (fail closed instead).
- A `tenant_id` column on existing tables.
- A `tenants` table.
- Renaming workflows off the `LNI ` prefix (D-N).
- Promoting the platform owner to a mail sender.
- Deleting or freezing the permanent test tenant.
- ElderWise. Instance restart. `$env`.
  `$getWorkflowStaticData`.

---

## Acceptance (this docs packet, 12.0a)

- Q1–Q5 LOCKED in this file. No “recommend”. D-L
  ACCEPTED. D-M D-N D-O in `masterplan.md`.
- `lni_settings` + `lni_instance` + platform owner +
  assets composite unique + `bot_state` telegram unique
  named as 034. No migration file.
- Live GET: WF-01 / WF-06 unpublished drafts unchanged.

## Acceptance (12.1 — applied 16 Sep)

- `pg_tables` has `lni_settings` and `lni_instance`.
- `pg_policies`: `lni_settings_owner_all`,
  `lni_instance_select`.
- `bot_state` unique on `telegram_user_id`.
- assets unique is `(owner_id, telegram_file_unique_id)`.
- catalog `034_multitenancy_foundation`
  (`20260916022806`); 030 still absent.
- WF-01 published `<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`.
  WF-06 published `<WF06_PUBLISHED>` / draft `<WF06_DRAFT>`.

## Acceptance (12.2 — applied 16 Sep)

- catalog `035_operator_chat` (`20260916024816`); 030 still
  absent.
- `lni_settings` key `operator_chat_id` under
  `lni_instance.platform_owner_id`; value = live owner
  `bot_state.telegram_user_id`.
- `lni_settings_set_updated_at` BEFORE UPDATE trigger live.
- WF-00 / WF-07 / WF-08 published JSON: zero `LEAP 2026`.
- Fingerprint is `lni_instance` name `NIS`.
- WF-00 `audit_log.owner_id` = platform owner. Alert from
  `operator_chat_id`, not `bot_state`.
- WF-07 `/digest` Load digest `$1` from caller payload.
  Hourly fan-out per owner local hour. Gmail fail-closed.
- WF-08 Retrieve corpus `$1` still caller `owner_id`.
- WF-00 published `be1e7b71` (rollback `<WF00_PUBLISHED>`).
  WF-07 published `9197f7a3` (rollback `<WF07_PUBLISHED_9_14>`).
  WF-08 published `8b835659` (rollback `<WF08_PUBLISHED>`).
- WF-01 published `<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`.
  WF-06 published `<WF06_PUBLISHED>` / draft `<WF06_DRAFT>`.
- Full cross-tenant isolation is **not** proven (12.5).
  Permanent test tenant `bot_state` did **not** land
  (12.2b).

## Acceptance (12.2a — applied 16 Sep)

- catalog `036_digest_email` (`20260916030417`); 030 still
  absent.
- `lni_settings` key `digest_email` under the live owner
  only; value = that owner's `auth.users.email` (resolved,
  not hardcoded). Platform owner has no row (D-O).
- WF-07 Load digest `mail` CTE LEFT JOINs `lni_settings`
  `digest_email` on `$1`. Missing key → `''` →
  `Email skipped` (fail-closed with a door).
- WF-07 published `becd329b` (rollback `9197f7a3`).
  `<WF07_ROLLBACK>` is **12.3b**, not 12.2a (71b4049 label smear).
- WF-01 published `<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`.
  WF-06 published `<WF06_PUBLISHED>` / draft `<WF06_DRAFT>`.
- 12.4b E1–E3 were recorded here, then fixed in 12.4b.
- WF-06 Apollo: missing `apollo_daily_ceiling` is already
  treated as 0 (no PUT this packet).

## Acceptance (12.3c / 12.2b-i — applied 16 Sep)

- catalog `037_test_tenant` (`20260916033502`); 030 still
  absent.
- Auth user resolved by exact email
  `<TEST_TENANT_EMAIL>` (confirmed, unique). Never
  a hardcoded uuid.
- `events` name `NIS test tenant`, timezone
  `Pacific/Auckland`. Not `LEAP 2026`.
- `lni_config` apollo daily + lifetime ceilings. `sender_profile` row.
- **No `bot_state`.** **No `digest_email`.**
- Never deleted. Never frozen (Q2).
- WF-01 published `<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`.
  WF-06 published `<WF06_PUBLISHED>` / draft `<WF06_DRAFT>`.

## Acceptance (12.4b — applied 16 Sep)

- WF-07 published `<WF07_PUBLISHED>` (named rollback `<WF07_ROLLBACK>`
  before the first 12.4b PUT). Chain: `9197f7a3` (12.2) →
  `becd329b` (12.2a) → `<WF07_ROLLBACK>` (12.3b) → `<WF07_PUBLISHED>`
  (12.4b).
- Kind on demand `source` is the literal `call`.
- Scheduled path: `Each owner` SplitInBatches batchSize 1
  (v3 output 0 done, output 1 loop). Owner N empty /
  undeliverable writes `audit_log` and continues to N+1.
  On-demand still `stopAndError`.
- E1–E3 **fixed in 12.4b**. N=2 failure isolation proven
  Hourly tick exec **483257** (live owner Telegram 1017 +
  Gmail `1a0a8592df6c384c`; tenant 2 `audit_log`
  `08c94fa6` `digest_undeliverable` /
  `both_channels_empty`; execution **success**, not
  errored). N=2 successful delivery to two real chats is
  **not** proven — that is 12.5.
- Self identify, Load digest (mail CTE), Compose digest,
  List due owners unchanged.
- WF-01 published `<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`.
  WF-06 published `<WF06_PUBLISHED>` / draft `<WF06_DRAFT>`.
  No other workflow PUT.

## Acceptance (12.4c — docs 16 Sep)

- No PUT. WF-07 still `<WF07_PUBLISHED>`. Packet restore
  `<WF07_ROLLBACK>` was named **before** the first 12.4b PUT.
  Immediate predecessor `feb5f066` was named **before**
  the PUT that created `<WF07_PUBLISHED>`.
- Same-packet intermediates: `353f649a` → `feb5f066` →
  `<WF07_PUBLISHED>`. Recorded in docs after the fact.
- D3 exec **483257** status **success**.
- 04:00Z exec **483309** ran on `<WF07_PUBLISHED>` (12.4b), not
  `<WF07_ROLLBACK>`.
- WF-00 still `be1e7b71`. WF-08 still `8b835659`.

## Acceptance (12.4e — applied 16 Sep)

- catalog `038_restore_assets_single_unique` (`20260916043514`);
  030 still absent.
- `assets_telegram_file_unique_id_key` UNIQUE
  `(telegram_file_unique_id)` restored. TEMPORARY.
  Coexists with `assets_owner_id_telegram_file_unique_id_key`.
- Zero duplicate `telegram_file_unique_id` at apply (191/191).
- No WF-01 PUT. Drafts `<WF01_DRAFT>` / `<WF06_DRAFT>` unpublished.
- Drop the column-only unique in **12.2 remainder** when
  WF-01 Insert asset is PUT to
  `ON CONFLICT (owner_id, telegram_file_unique_id)`.
- STEP 2: WF-01 **483617** success photo `57b0e023`
  stored 91339; **483620** success voice `cdccd64e`
  stored 16378. assets 191 → 193.
- STEP 3: 7 published ON CONFLICT clauses, all parse
  (rolled-back EXPLAIN). Arbiters live. Zeros:
  WF-00/03/04/06/07/08/10. No `ON CONSTRAINT`. No SQL
  naming an index. No FK onto the 034/038 uniques
  (`processing_jobs_asset_id_fkey` → `assets` PK only).
  Unapplied **012** infers
  `bot_state_owner_id_telegram_user_id_key` (kept).
  Rule 24 in `rules.md`. No PUT.

## Acceptance (12.5a-0 — applied 16 Sep)

- WF-10 published `<WF10_PUBLISHED>`. Rollback `<WF10_ROLLBACK>` named
  before PUT.
- History webhook node gone. POST production URL 404.
- Normalize: no Self identify owner_id fallback.
- Self identify still returns owner_id (C1 waits).
- WF-01 `<WF01_PUBLISHED>` / draft `<WF01_DRAFT>`. WF-06 `<WF06_PUBLISHED>`
  / draft `<WF06_DRAFT>`. No other workflow PUT.
- 12.5a C/D/E/G unstarted.

## Acceptance (12.5a-0b — applied 16 Sep)

- `LNI-TEST- 10.4b gmail draft attach` and
  `LNI-TEST- 10.4b delete drafts`: `active=false`,
  `isArchived=true`. POST production URLs 404. Not
  deleted.
- WF-01 unchanged: published `<WF01_PUBLISHED>`, draft
  `<WF01_DRAFT>`. `Driver ingest` still on the published
  graph (cause-only; no PUT).
- README policy did not hold (119-commit audit). No
  history rewrite. No force-push.
- 12.5a C/D/E/G unstarted. PR #81 unmerged.

## Acceptance (12.5a-0c — applied 16 Sep)

- Auth `disable_signup=true`. Anon signup `422`.
- `mailer_autoconfirm` still true (item 11). Stray Auth
  user not deleted (item 10).
- NIWL public repo: zero n8n host / webhook base URL.
- Scrub map gitignored. `git-filter-repo` **not run**.
- Rule 25 + `scripts/check-no-literals.sh` + CI.
- No WF-01 PUT. No force-push.

## Acceptance (12.5a-0d — applied 16 Sep)

- Scrub map amended (names + domains, longest-first).
  Rewrite **not run**.
- Rule 25: banned identity/infrastructure; allowed
  row-level uuids. Checker no longer scans generic uuid.
- #81 squash-merged. Branch deleted. A2–A4 diffs waived
  (architect decision).
- `mailer_autoconfirm` still true until Talal flips
  Confirm email (item 11).

## Acceptance (12.5a-0h — applied 16 Sep)

- Pre-rewrite backup: `~/lni-preservrub-backup.git`
  captured `6326264`. Post-#82 tip `1caf528` stored as
  `refs/backup/pre-rewrite-tip`. Decoder next to it.
- `#82` squash-merged. Origin heads = `main` only.
  Then `git-filter-repo --replace-text` (all refs).
  Force-pushed `main` `1caf528` → `ef640a320d979e8b7516adcb978ffe6d1b8a30e2`.
- 034 / 037 now contain `<PLATFORM_EMAIL>` /
  `<TEST_TENANT_EMAIL>`. **Not re-runnable.** 12.6
  bootstrap uses `009` `current_setting` (E4 / 2b).
- Rule 25 checker green on a fresh origin clone.
  C2 eaten-uuid count = 0. 12.5a C/D/E/G unstarted.
- No WF-01 PUT. No canvas.

## Logged, do not fix in 12.5a

**WF-10 `Load callback follow_up` OR branch.**
`($3::text='p' AND f.draft_state IN ('draft','awaiting_voice'))`
returns the owner's latest draft rather than the tapped
person. Owner-scoped, so not a cross-tenant leak — a
correctness defect. Own packet. Published graph `<WF10_PUBLISHED>` (OR branch
unchanged). Do not PUT this in 12.5a.

## Acceptance (later — do not execute here)

- 12.2 remainder: PUT WF-01 Insert asset
  `ON CONFLICT (owner_id, telegram_file_unique_id)`
  then DROP `assets_telegram_file_unique_id_key`.
  Also: `capture_no` lookups include `owner_id`
  on WF-01/02; storage path read-back.
- 12.2b: permanent test tenant `bot_state` live. Not
  asserted today.
- 12.3 `person_emails`: <CONTACT_3_NAME> still two people rows until
  a merge packet after `person_emails` exists.
- 12.4: 61 pre-window candidates still `pending` unless
  a human reviewed them.
- 12.4b: E1–E3 **fixed in 12.4b** (WF-07 `<WF07_PUBLISHED>`,
  rollback `<WF07_ROLLBACK>`). N=2 failure isolation proven
  exec **483257**. N=2 successful delivery to two real
  chats is **not** proven — that is 12.5.
- 12.5: isolation proven with two real accounts.
- 12.6: login surface only after 12.5. Seed `events` and
  ceilings at tenant creation (12.6 E1 / E2). Owner IU
  Microsoft account reserved Phase 14, not the harness
  (12.6 E3). Fresh-deploy seeds use `009` `current_setting`
  (12.6 E4). 034/037 are tokenised as of 12.5a-0h and
  are not re-runnable — do not re-apply them.
