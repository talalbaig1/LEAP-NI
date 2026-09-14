# Phase 12 — Multi-tenancy (docs only)

**Date:** 14 Sep 2026 · **Amended:** 14 Sep 2026 (packet 12.0a)
**Status:** PLAN ONLY. Q1–Q5 LOCKED. D-L ACCEPTED. D-M D-N D-O
locked. No migration, no PUT, no SQL write.
**Home:** this file. Contracts also in `phases.md` Phase 12,
`architecture.md` §4, `masterplan.md` D-L…D-O, `prd.md` §8c,
`workflows.md` §1 owner-resolution.

Packet 10.1 closed. Highest applied migration is
`033_sender_profile_channel_signatures` (catalog
`20260914083604`). Next LNI schema number is **034**.
**030 stays Phase 6 embeddings.** Do not steal it.

Product name is **Networking Intelligence System (NIS)**.
`LNI` is the legacy internal code prefix (D-N). Internal
identifiers do not change.

---

## What this phase is

The schema already stamps `owner_id` on every user-owned
table and RLS-scopes it. Launch used **one** owner
(`a79b744e`). Workflows still find that owner by the seed
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
| `bot_state` / `events` / `sender_profile` | 1 row each, all `a79b744e` |
| `people.owner_id` distinct | 1 |
| `lni_config` | 3 integer keys (Apollo daily 60, lifetime 2200, Tavily 1000) |
| `person_emails` / `lni_settings` / `tenants` / `lni_instance` | **absent** |
| Pending `entity_candidates` | 77 (61 pre-window + 16 in-window) |
| `assets_telegram_file_unique_id_key` | UNIQUE on the column alone |
| `bot_state` unique | `(owner_id, telegram_user_id)` only |
| WF-01 published | `4836ffd8` · draft still `e454df40` (30 Aug autosave) |
| WF-06 published | `356a2d1f` · draft still `76840a2a` (30 Aug autosave) |

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
12.1, live second `bot_state` in 12.2. Never deleted,
never frozen — standing cross-tenant regression harness,
same principle as capture #9.

---

## 12.1 tables (named then, not now)

Catalog **034**. Do not write the file in 12.0 / 12.0a.
030 stays Phase 6.

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
`donotreplynis@gmail.com`. Gmail ignores dots; a dotted
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
`LEAP 2026`. Do not hardcode `a79b744e`. Do not resolve
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
`(owner_id, email_normalized)`. Muhammad Zahir
`d2335783` (haramain) + `ba037ac0` (kaacib) stay two
rows until this exists. Outreach already dual-To:.
**Do not merge.** Same human also needs several phones
and titles; `person_companies` already allows two current
employers (DES RAJ: Aliph + Utopian).

### Packet 12.4 — `entity_candidates` pair storage

77 pending. 10.1 left them pending: `rejected` would
claim a review nobody did. Row today:
`candidate_entity_id` + `score` + `reasons[]`. No stored
pair. `{name_trgm}` is not a human reason. 61 pre-window
stay pending through 12.4.

### Packet 12.5 — login surface (after isolation)

Minimal login: Supabase Auth, Google/Microsoft,
Telegram-ID capture. **Dependency, not a shortcut.**
Isolation (12.1–12.2) is proven first. Isolation before
there is a door.

---

## Packets

| Packet | What | Migration | Workflows |
|---|---|---|---|
| **12.0 / 12.0a** | This plan. Docs only. Q1–Q5 locked. | none | none |
| **12.1** | `lni_settings` + `lni_instance` + `bot_state` UNIQUE `(telegram_user_id)` + assets composite unique + platform owner seed | **034** (named then, not now) | none unless a seed-read prove |
| **12.2** | Split self-id onto `lni_instance`. Cron iterates tenants. Fail-closed Gmail/Apollo. `capture_no` + owner audit. Storage path read-back. Permanent test tenant `bot_state` | none | WF-00/01/02/06/07/09 as the packet lists. **No unpublished-draft publish.** |
| **12.3** | `person_emails` | 035-class, named then | WF-05 / WF-10 only if the packet says so |
| **12.4** | `entity_candidates` pair + human reasons | named then | WF-05 |
| **12.5** | Minimal login surface | named then | none until isolation proven |

One packet at a time. Architect verifies live SQL / live
JSON. Implementer report is not evidence.

---

## Q1–Q5 — LOCKED 14 Sep 2026

**Q1. Tenant identity.** ACCEPTED. Tenant = `owner_id`.
No `tenants` table. D-L ACCEPTED.

**Q2. Second owner.** AMENDED. Permanent test tenant, not
a throwaway. Schema in 12.1. Live second `bot_state` row
in 12.2. Never deleted. Never frozen. Standing
cross-tenant regression harness, same principle as
capture #9.

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
`auth.users` row (`donotreplynis@gmail.com`, dotless).
Platform errors are owned by it, inside no tenant. D-O.

---

## Non-goals (12.0 / 12.0a and until a packet names them)

- Any migration file in this PR.
- `value_text` on `lni_config`.
- Stealing 030.
- PUT any workflow. Do not publish drafts `e454df40` /
  `76840a2a`.
- Activate WF-00b or NIWL WF-00.
- Merge the two Zahir rows.
- Set the 61 pending candidates to `rejected`.
- INSERT/UPDATE `interactions.person_id` (S6/S9).
- Fix S8 (WF-05 stays `68f47505`).
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

## Acceptance (later — do not execute here)

- 12.1: `pg_tables` has `lni_settings` and
  `lni_instance`; `pg_policies` has
  `lni_settings_owner_all`; `bot_state` unique on
  `telegram_user_id`; assets unique is
  `(owner_id, telegram_file_unique_id)`; platform Auth
  user exists; catalog 034; 030 still absent.
- 12.2: no workflow node contains the string
  `LEAP 2026`; fingerprint is `lni_instance`; owner from
  `bot_state`; fail-closed Gmail/Apollo; `capture_no`
  lookups include `owner_id`; storage path read-back;
  permanent test tenant `bot_state` live; WF-01 published
  id still `4836ffd8` unless a packet authorised a PUT.
- 12.3: Zahir still two people rows until a merge packet
  after `person_emails` exists.
- 12.4: 61 pre-window candidates still `pending` unless
  a human reviewed them.
- 12.5: login surface only after isolation is proven.
