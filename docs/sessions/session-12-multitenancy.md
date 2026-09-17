# Session 12 — multi-tenancy (packets 12.0–14.0)

**Window:** 14–17 Sep 2026.
**Not this session:** Phase 13 enrichment read path,
`person_emails` (12.3), `entity_candidates` review (12.4),
login surface (12.6).

Product name **NIS**. Internal prefix **LNI** (D-N).

## What was found

Launch was one owner. Every user-owned table already had
`owner_id` + RLS. Workflows still resolved that owner from
`events.name = 'LEAP 2026'`. Cron served one person.

034 dropped the column-only assets unique while published
WF-01 still inferred `ON CONFLICT (telegram_file_unique_id)`
→ 42P10. Capture down until 038 restored it TEMPORARY.

B5 picker silence on tenant 2 was first read as a leak.
It was a **fixture** defect: D3probe / NIS mailbox prove
are not name-shaped, so Extract recipient yields
`none named` and Lookup people never runs.

S3 note-only extraction lived only on `/done`
(`Enqueue asset jobs`). Sweep, follow-up supersede, and
the watchdog orphan path never enqueued extraction.

S6/S9: one interaction per capture (`LIMIT 1` +
`NOT EXISTS capture_id`). S8: `Set capture status` could
write `ready` onto `open` — kick-split was discipline,
not structure.

User-facing Telegram/Gmail copy still said LNI after D-N.

Supabase project ref is concatenated in WF-01 Upload/HEAD
and WF-10 GET/Fetch URLs.

## What was fixed

| Packet | What |
|---|---|
| 12.1 | 034: `lni_settings`, `lni_instance`, composite assets unique, `bot_state` telegram unique, platform owner |
| 12.2 | 035 + WF-00/07/08: fingerprint is `lni_instance` name NIS. Operator chat. `audit_log` under platform owner |
| 12.2a | 036 `digest_email`. Fail-closed Gmail (D-M) |
| 12.2b-i | 037 inert test tenant (no `bot_state`) |
| 12.4b | WF-07 hourly fan-out N>1, one owner at a time |
| 12.4e | 038 TEMPORARY column unique restored |
| 12.5a-0 | Closed WF-10 public History webhook |
| 12.5a-0b | Archived TEST 10.4b webhooks |
| 12.5a-0h | Rule 25 rewrite. 034/037 tokenised |
| 12.6 drain | Owner resolution off the fingerprint (login surface itself **not** built) |
| 12.7 | 040 `handed_off`. Destination-less WF-09 kick |
| 12.8 | Second `bot_state` (041). Isolation evidence. B5 cause |
| 12.9 | 042 `bot_state.current_event`. Per-tenant event |
| 13.0 | WF-01 owner-scoped Duplicate/Insert. 043 drop column unique. Dead await gone. History skip via `lni_settings` |
| 14.0 | 044 Sara Alharbi. NIS copy. Followup payload deleted. Note UNION on sweep/closed/orphan. S8 status guard |

## What was proven

- Cross-tenant store: same Telegram `file_unique_id` under
  two owners (#229 live / #230 tenant 2). Composite
  ON CONFLICT. Resend same-owner Duplicate terminal.
- WF-07 N=2 failure isolation (exec **483257**). N=2
  successful digest delivery to two chats was 12.5, not
  12.4b.
- Isolation is owner-scoped joins, not "the other account
  cannot send a card". #230 is a copied person row on
  tenant 2 — expected, keep it.
- B5 typed "probe" ≠ spoken path. Keyboard is Lookup
  people after Extract recipient.

**Still owed:** A3 owner voice on account 2 naming Sara.
SQL simulation returns Sara Alharbi `d62b48f7` only.

## Architect errors

1. **Unique vs ON CONFLICT.** 034 dropped a unique the
   published graph still inferred. Rule 24 exists because
   of this. Schema read-back cannot catch a workflow bind.
2. **B5 as a leak.** Looked like Lookup people crossed
   tenants. It never ran. Fixture was not name-shaped.
3. **S8 via kick-split.** Discipline is not a predicate.
   14.0 added `AND status IS DISTINCT FROM 'open'`.
4. **Hardcoded skip lists / locked uuid** in WF-10 History
   load and Load incomplete draft (13.0 P3).
5. **Canvas autosave ≠ published.** `sanitize_for_put`
   must take `activeVersion` or it publishes the autosave.
6. **MCP create binds ElderWise credentials.** Self-identify
   `lni_instance` name NIS is the gate, not the create
   response.
7. **User-facing LNI after D-N.** Product name is NIS;
   internal identifiers stay LNI. 14.0 B1 applied that to
   Telegram/Gmail copy only.

## Process change

- GET **name**, then act. Names begin `LNI ` / `LNI-TEST-`.
- Named rollback printed **before** the mutation.
- `sanitize_for_put` from `activeVersion` on an active
  workflow. Top-level is the canvas draft. Raise if
  `activeVersion` is missing.
- No canvas. Opening a workflow autosaves and strips
  explicit defaults.
- Rule 25 on every committed line. 8-char prefixes and
  execution ids are allowed. Owner uuid / emails / host /
  project ref / workflow ids are not.
- STOP only where the packet marks it. Report once unless
  a STOP fires.
- Combined SQL via MCP returns the last result only.
  One statement per `execute_sql`.
- Implementer report is not evidence. Architect verifies
  live SQL / live JSON.

## Tenant 2 fixture catalogue

Permanent unless a later packet says otherwise. Owner is
the `events.name = 'NIS test tenant'` row that has
`bot_state`. Do not hardcode the uuid.

| Row | Why | Permanent |
|---|---|---|
| `events` NIS test tenant (037) | Inert then live harness | yes |
| `bot_state` (041) | Second allowlist. Isolation | yes |
| `sender_profile` + 3 `lni_config` ceilings (037) | Fail-closed spend / sign-off | yes |
| `7cee0027` NIS mailbox prove | D-M mailbox prove. Not name-shaped | yes |
| `de10f49f` D3probe | 12.8 B5 typed probe. Not name-shaped | yes |
| `d2c90b68` | Cross-tenant card copy, capture **#230** | yes |
| `d62b48f7` Sara Alharbi (044) | Name-shaped B5 picker. `example.invalid` | yes |
| `7c72371f` | 12.6 C3 deliberate `card_vision` failed / `packet_126_c3` / `asset_id` NULL / capture **#217**. Watchdog will keep reporting it. Do not requeue | yes |

Captures **#217–#234** are prove artifacts. Keep.

`lni_settings` on this owner: **0**. Missing
`history_skip_person_ids` = no skip (13.0 P3). Do not seed.

## Open after 14.0

- A3 owner voice prove
- C2 interaction-per-person design
- C4/C5/D1 backfills (predicates proposed, not run)
- B4 project ref → config
- Phase 13, 12.3, 12.4, 12.6 login
