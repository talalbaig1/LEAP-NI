# Phase 12 — Multi-tenancy (docs only)

**Date:** 14 Sep 2026
**Status:** PLAN ONLY. No migration, no PUT, no SQL write.
**Home:** this file. Contracts also in `phases.md` Phase 12,
`architecture.md` §4, `masterplan.md` D-L, `prd.md` §8c,
`workflows.md` §1 owner-resolution.

Packet 10.1 closed. Highest applied migration is
`033_sender_profile_channel_signatures` (catalog
`20260914083604`). Next LNI schema number is **034**.
**030 stays Phase 6 embeddings.** Do not steal it.

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
name. That is the work.

NIWL (waitlist intake on the same n8n host) is **not** an
LNI tenant. Do not activate NIWL WF-00. Do not bind LNI
to NIWL credentials.

---

## Live facts (SQL + GET, 14 Sep 2026)

| Fact | Value |
|---|---|
| `auth.users` | 3 (owner + two Phase 0 RLS probes) |
| `bot_state` / `events` / `sender_profile` | 1 row each, all `a79b744e` |
| `people.owner_id` distinct | 1 |
| `lni_config` | 3 integer keys (Apollo daily 60, lifetime 2200, Tavily 1000) |
| `person_emails` / `lni_settings` / `tenants` | **absent** |
| Pending `entity_candidates` | 77 (61 pre-window + 16 in-window) |
| WF-01 published | `4836ffd8` · draft still `e454df40` (30 Aug autosave) |
| WF-06 published | `356a2d1f` · draft still `76840a2a` (30 Aug autosave) |

If either unpublished draft id changes, someone wrote
the canvas — STOP.

---

## Locked here (D-L) — pending architect accept

**Tenant = `owner_id`.** One `auth.users` row owns
`bot_state`, `events`, `sender_profile`, `lni_config`,
`lni_settings` (proposed), and all children. No parallel
`tenant_id`. No `value_text` on `lni_config`.

A second human is:

1. An Auth user (same pattern as migration 009: match by
   email setting, never “earliest row”).
2. A `bot_state` row (`telegram_user_id` globally unique).
3. An `events` row (name need not be `LEAP 2026`).
4. `sender_profile` + integer `lni_config` ceilings +
   text `lni_settings`.

`bot_state` is still the WF-01 allowlist. Unknown Telegram
senders stay silent.

---

## Recommended table: `lni_settings`

Text config home. **Not** `lni_config` (integer ceilings).
**Not** `sender_profile` (signatures, D-I). **Not** 030.

Proposed (034, only when packet **12.1** names it):

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

Seed for the live owner, key `display_name`, value the
owner-chosen tenant label. Do not invent other keys in
12.1. Signatures stay on `sender_profile`.

Same packet: `UNIQUE (telegram_user_id)` on `bot_state`.
Live unique is only `(owner_id, telegram_user_id)`. WF-01
looks up by `telegram_user_id` alone. Two owners must not
share a chat id. Live row count is 1, so the unique
index applies cleanly.

---

## Owner resolution vs self-identify

Today those are the same SELECT:

```
SELECT name, timezone, owner_id
FROM public.events
WHERE name = 'LEAP 2026'
LIMIT 1
```

That SELECT does two jobs. Split them.

| Job | After Phase 12 | Why |
|---|---|---|
| **Database fingerprint** | Keep `name = 'LEAP 2026'` (or equal gate). Miss → `stopAndError` wrong-database. | Proves Leap-NI, not ElderWise. Seed row stays. |
| **Who is this user?** | Inbound: `bot_state` by `telegram_user_id`. Cron: every `bot_state.owner_id`, not `LIMIT 1` from the seed event. | A second owner has a different event name. |

Do not hardcode `a79b744e` in a workflow. Do not resolve
owner from `$env`.

**WF-00** stays a **platform** alert to the live operator
chat (today: the one `bot_state` row). A second tenant's
capture errors still page the operator, not that tenant,
until a later packet says otherwise. Shared n8n + shared
error workflow.

---

## Shared n8n credentials (out of this phase)

One Gmail, one OpenAI, one Apollo, one Telegram bot on
the instance. Per-owner OAuth / API keys are **not**
designed here. A second Telegram user on the **same** bot
can capture into their own `owner_id`. Their Gmail drafts
and Apollo spend would hit Talal's credentials — that is
why they are out of 12.1–12.2.

Phase 8 PWA uses Supabase Auth directly; it does not need
those n8n credentials. Do not invent a Postgres column
that stores a refresh token.

---

## What stays global (already decided)

| Object | Stays | Reason |
|---|---|---|
| `captures.capture_no` | Global identity | Per-owner counter serialises `/batch` (`architecture.md` §4). Receipts stay `#47` not `#47@owner`. |
| `assets.telegram_file_unique_id` | Global UNIQUE | Same bot, Telegram's native dedup. |
| `lni_public_suffixes` | Not owner-scoped | Reference list. |

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

---

## Packets

| Packet | What | Migration | Workflows |
|---|---|---|---|
| **12.0** | This plan. Docs only. | none | none |
| **12.1** | `lni_settings` + `bot_state.telegram_user_id` UNIQUE | **034** (named then, not now) | none unless a seed-read prove |
| **12.2** | Split self-id / owner. Cron iterates owners | none | WF-00/02/06/07/09 as the packet lists. **No WF-01** unless the packet says so |
| **12.3** | `person_emails` | 035-class, named then | WF-05 / WF-10 only if the packet says so |
| **12.4** | `entity_candidates` pair + human reasons | named then | WF-05 |

One packet at a time. Architect verifies live SQL / live
JSON. Implementer report is not evidence.

---

## Q1–Q5 — architect locks before 12.1

Same pattern as 10.4 Q1–Q3. Implementer recommendation
in italics. Do not apply 034 until these are locked.

**Q1. Tenant identity.** `owner_id` 1:1, no `tenants`
table? *Recommend yes. A tenants table with one owner is
a join with no query. Add it later if a tenant needs two
humans.*

**Q2. First prove of a second owner.** New `bot_state`
row on the shared Telegram bot (throwaway Auth user), or
docs-and-schema only until Phase 8? *Recommend schema in
12.1, one throwaway Telegram prove in 12.2, then delete
or freeze that user. Do not seed a production second
tenant in 12.1.*

**Q3. Per-owner Gmail / OpenAI / Apollo.** In or out?
*Recommend out of Phase 12. Shared credentials. Capture
isolation is the prove.*

**Q4. Self-identify.** Keep `LEAP 2026` as the Leap-NI
fingerprint; take `owner_id` from `bot_state` / cron
iteration? *Recommend yes.*

**Q5. WF-00 alerts.** Stay on the operator chat, not the
tenant's chat? *Recommend yes until a named packet
changes it.*

---

## Non-goals (12.0 and until a packet names them)

- Any migration file in this PR.
- `value_text` on `lni_config`.
- Stealing 030.
- PUT WF-01. Do not publish drafts `e454df40` / `76840a2a`.
- Activate WF-00b or NIWL WF-00.
- Merge the two Zahir rows.
- Set the 61 pending candidates to `rejected`.
- INSERT/UPDATE `interactions.person_id` (S6/S9).
- Fix S8 (WF-05 stays `68f47505`).
- Per-owner n8n credentials.
- A `tenant_id` column on existing tables.
- ElderWise. Instance restart. `$env`.
  `$getWorkflowStaticData`.

---

## Acceptance (this docs packet)

- D-L written in `masterplan.md`, this plan,
  `phases.md`, `architecture.md`, `prd.md` §8c,
  `workflows.md` §1.
- `lni_settings` proposed as 034. No migration file.
- Q1–Q5 listed. No 12.1 build until the architect
  answers.
- Live GET: WF-01 / WF-06 unpublished drafts unchanged.

## Acceptance (later — do not execute here)

- 12.1: `pg_tables` has `lni_settings`; `pg_policies`
  has `lni_settings_owner_all`; `bot_state` unique on
  `telegram_user_id`; catalog 034; 030 still absent.
- 12.2: scheduled WF-07/09/06 name-checked; owner from
  `bot_state` not `events.name`; self-id gate still LEAP
  2026; WF-01 published id still `4836ffd8` unless a
  packet authorised a PUT.
- 12.3: Zahir still two people rows until a merge packet
  after `person_emails` exists.
- 12.4: 61 pre-window candidates still `pending` unless
  a human reviewed them.
