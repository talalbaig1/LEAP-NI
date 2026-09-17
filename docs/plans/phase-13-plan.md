# Phase 13 — Enrichment read path + S6

**Date:** 17 Sep 2026
**Status:** designed this packet. **Not built** until
13.1 / 13.2 PUT. No canvas.
**Home:** this file. Also `phases.md`, `architecture.md`
§ enrichment read, `workflows.md` WF-05 / WF-10,
`masterplan.md` D-P D-Q.

12.2 isolation is live. Packet 13.0 was leftovers, not
this work. Packet 14.0 left Phase 13 out on purpose.

Live GET + SQL 17 Sep beat the handover where they
disagree. Named rollback **before** every PUT.
`sanitize_for_put` from `activeVersion` (deepcopy).
GET name `LNI ` first. Postgres Leap-NI only
(`<PG_CRED_ID>`). Self-identify stays
`SELECT name FROM public.lni_instance LIMIT 1`,
gate `NIS`.

---

## What this phase is

WF-06 **writes** `enrichment_records`. Nothing **reads**
them into compose. 88 rows (46 person/apollo, 36
company/apollo, 6 company/tavily). That is the product
hole. D-P and D-Q are already locked.

S6 (14.0 C2) is the same chat because History load’s
summary comes from `interactions`, and Enqueue
enrichment already requires an interaction for that
person. Fixing S6 without the read path still leaves
Apollo unused; the read path without S6 still drops the
second person on a multi-name card.

Two packets, one deliverable each, sequential:

| Packet | Deliverable | Schema | PUT |
|---|---|---|---|
| **13.1** | Enrichment on WF-10 compose + Telegram evidence | none | WF-10 only |
| **13.2** | One interaction per extracted person (S6/S9) | **045** | WF-05 only |

030 stays Phase 6 embeddings. Next schema is **045**.

---

## Locked (D-P D-Q plus this packet)

**D-P.** Card is truth. Apollo may be stale or wrong.
The letter **asserts** card `people.title` /
`companies.name`. Apollo never becomes a sentence
claiming their title or seniority.

**D-Q.** Apollo / Tavily surface on Telegram beside the
draft (D-F). Never in `follow_ups.body`, never in a
Gmail draft, never in a WhatsApp/LinkedIn copy-text.

**D-R (this packet).** Channel pick stays the **card**:
email / phone / `people.linkedin_url`. An Apollo
LinkedIn URL must not flip a person onto the LinkedIn
channel. It may appear in evidence only.

**D-S (this packet).** Curated columns, never
`payload::text`. Hollow rows (`payload = '{}'` or blank
`name` on person/apollo) join as NULL. Latest
`fetched_at` wins (live duplicates exist). Every join is
`enrichment_records.owner_id = people.owner_id`.

**D-T (this packet).** `/ask` stays enrichment-blind
(Phase 6 deliberate). WF-07 digest does not read
`enrichment_records`. WF-06 write path unchanged.

**Rule 26.** Attach the read **before** the composer.
Do not add a Postgres node after Compose confirm /
History evidence / Return to caller.

---

## Live facts (GET + SQL, 17 Sep)

Published:

| WF | id | published | nodes |
|---|---|---|---|
| 05 | `<WF05_ID>` | `<WF05_PUBLISHED_14_0>` | 31 |
| 10 | `<WF10_ID>` | `<WF10_PUBLISHED_14_0>` | 167 |
| 07 | `<WF07_ID>` | `<WF07_PUBLISHED_14_0>` | 34 |
| 08 | `<WF08_ID>` | `<WF08_PUBLISHED_12_2>` | 19 |

`enrichment_records`: 88 rows. Unique is PK only.
Duplicates per `(owner_id, entity_type, entity_id,
provider)` exist (max 5). Person/apollo hollow **3**,
blank name **4**. Tavily companies blank name **6**.

`interactions`: 142 rows, `person_id` NULL **20**.
Zero duplicate `(capture_id, person_id)` where
`person_id` IS NOT NULL. Zero captures with two
interaction rows. Unique today is PK only.

WF-10 `History load` (published) already scopes
`interactions` by `ii.person_id = p.id … LIMIT 1`.
The handover line “may attach the other person’s
summary” is **wrong vs live GET**. Today the second
person gets an **empty** summary. 13.2 fills it.

WF-10 `Load voice person` / `Load picked person`:
`SELECT id, full_name, email_normalized` only. No
card title, no company, no enrichment. Extract draft
user message has Person + Email + Brief. No title.

WF-10 prompts: `wf10-v5` on Extract draft /
Extract history draft. Insert draft / History insert /
History copy insert write `prompt_version = 'wf10-v5'`.

WF-05 `Enqueue enrichment` already requires
`EXISTS (interactions … person_id = p.id)` for that
capture. S6 is why the second email on a card never
gets Apollo.

WF-05 `Load followup draft` still binds `$2` to the
locked follow_up `<never-touch awaiting_confirm>`
(`5df341f8`). 13.0 P3 removed the twin from WF-10.
Query already requires `draft_state='draft'`, so that
row never matches. Drop on the 13.2 PUT
(behaviour-neutral).

WF-05 `Call WF-10 deferred`: `executeOnce: true`,
`waitForSubWorkflow: false`.

No LNI workflow has `ON CONFLICT` on `interactions`
(rule 24 enumeration, GET 17 Sep). Only writer is
WF-05 `Insert interaction` (`WHERE NOT EXISTS
capture_id`).

---

## Packet 13.1 — enrichment read (WF-10)

**Rollback before PUT:** `<WF10_PUBLISHED_14_0>`
(`465a037a`). GET name
`LNI WF-10 - Follow-up drafting`.

### 13.1a — `History load`

Keep the published query. Add three LATERALs after
the photo LATERAL, still `p.owner_id` scoped.
`ORDER BY fetched_at DESC LIMIT 1`. Do **not**
stringify `payload`. Do **not** touch the
`<CONTACT_1_DOMAIN>` email skip, the `LNI %` skip,
or `history_skip_person_ids`.

```
LEFT JOIN LATERAL (
  SELECT
    NULLIF(btrim(er.payload->>'title'), '') AS apollo_title,
    NULLIF(btrim(er.payload->>'headline'), '') AS apollo_headline,
    NULLIF(btrim(er.payload->>'seniority'), '') AS apollo_seniority,
    NULLIF(btrim(er.payload->>'linkedin_url'), '') AS apollo_linkedin_url,
    er.fetched_at AS apollo_fetched_at
  FROM public.enrichment_records er
  WHERE er.owner_id = p.owner_id
    AND er.entity_type = 'person'
    AND er.entity_id = p.id
    AND er.provider = 'apollo'
    AND er.payload <> '{}'::jsonb
    AND COALESCE(btrim(er.payload->>'name'), '') <> ''
  ORDER BY er.fetched_at DESC
  LIMIT 1
) er_p ON true
LEFT JOIN LATERAL (
  SELECT
    NULLIF(btrim(er.payload->>'industry'), '') AS apollo_industry,
    LEFT(NULLIF(btrim(er.payload->>'short_description'), ''), 240)
      AS apollo_company_blurb,
    NULLIF(btrim(er.payload->>'estimated_num_employees'), '')
      AS apollo_headcount
  FROM public.enrichment_records er
  WHERE er.owner_id = p.owner_id
    AND er.entity_type = 'company'
    AND er.entity_id = c.id
    AND er.provider = 'apollo'
    AND c.id IS NOT NULL
  ORDER BY er.fetched_at DESC
  LIMIT 1
) er_c ON true
LEFT JOIN LATERAL (
  SELECT LEFT(NULLIF(btrim(er.payload->>'answer'), ''), 240)
    AS tavily_answer
  FROM public.enrichment_records er
  WHERE er.owner_id = p.owner_id
    AND er.entity_type = 'company'
    AND er.entity_id = c.id
    AND er.provider = 'tavily'
    AND c.id IS NOT NULL
    AND er_c.apollo_industry IS NULL
    AND er_c.apollo_company_blurb IS NULL
  ORDER BY er.fetched_at DESC
  LIMIT 1
) er_t ON true
```

Select list adds those aliases. `queryReplacement`
unchanged.

Never selected: email, phone, street, employment_history,
photo_url, facebook, twitter, github, raw payload.

### 13.1b — `Load voice person` and `Load picked person`

Same fat SELECT (person + current-or-any company +
the three LATERALs). Bind `$1` person id, `$2` owner
id from the named nodes already used
(`queryReplacement` stays one array).

Lookup people / Lookup people voice stay thin
(picker). Extract draft reads enrichment from the
**named** Load voice / Load picked nodes only.

### 13.1c — prompts → `wf10-v6`

**System (both Extract draft and Extract history
draft), append after the existing wf10-v5 sentence:**

`CARD TITLE AND COMPANY ARE TRUTH. Apollo / Tavily
lines are context only. Never write a sentence that
states their title, seniority, or headline from
Apollo. If Apollo disagrees with the card, the card
wins. Never copy Apollo emails, phones, or addresses
into the body.`

**Extract draft user message** — after Email, add
(same Load voice / Load picked named-node ladder as
Person, else empty):

```
Card title: …
Card company: …
Apollo context (do not assert as their title): title=…; headline=…; seniority=…; industry=…; blurb=…
```

Missing fields → `none`. Do not add a JSON-schema
property for enrichment (that would pull it into
`body`).

**Extract history draft user message** — after
`Title:` (card), add the same Apollo context line
from `$json` (History compose already
`Object.assign({}, r, …)` so History load columns
flow).

Insert draft / History insert / History copy insert:
`prompt_version` `'wf10-v5'` → `'wf10-v6'`.

### 13.1d — Telegram evidence (D-Q)

**History evidence.** After the Summary block, before
the Gmail/copy footer:

```
<b>Apollo (context, not used as title)</b>
```

Then one escaped line, truncated 400 chars:
headline · seniority · industry · fetched date, or
`(none)`. No emails, phones, or URLs (LinkedIn
search link already exists). HTML-escape via the
existing `esc()`.

**Compose confirm.** After the transcript block
(same card, so it sits with D-F), a short
`Apollo context:` line from the named Load voice /
Load picked node, truncated 200 chars, or omit
when all fields empty. Do not add a third Telegram
message. Existing 3800 split stays.

**History compose** channel pick unchanged (D-R).

### 13.1 acceptance

Live GET, name first:

1. `History load` query contains `enrichment_records`
   and `er.owner_id = p.owner_id`.
2. Hollow skip `payload <> '{}'` present.
3. Extract draft + Extract history draft system
   text contains `CARD TITLE AND COMPANY ARE TRUTH`.
4. User messages contain `Apollo context (do not assert`.
5. `prompt_version` `'wf10-v6'` on both extract
   nodes’ surviving comment and on the three INSERT
   writers.
6. History evidence js contains `Apollo (context, not used as title)`.
7. `LEAP 2026` count still 0. Self-identify still
   `lni_instance` / `NIS`. No `language` on either
   Transcribe. `errorWorkflow` WF-00. timezone
   `Asia/Riyadh`. `availableInMCP` true. Last nodes
   unchanged (`Return to caller` still last on the
   waited path).
8. SQL sim (no PUT needed to prove the SELECT): a
   person with hollow payload returns NULL
   `apollo_title`; a duplicated entity_id returns
   the latest `fetched_at`; a live-owner person id
   does not return the test-tenant’s enrichment
   rows.

DIFF vs `<WF10_PUBLISHED_14_0>`: only 13.1a–d.
Node count stays 167 unless a node must be added —
**do not add nodes**. No WF-01/02/03/04/05/06/07/08/09 PUT.

### 13.1 non-goals

- `/ask` (D-T)
- WF-06
- stringify payload
- auto-switch LinkedIn channel from Apollo URL
- drop `<CONTACT_1_DOMAIN>` skip
- seed `history_skip_person_ids`
- merge D-J / drain pending candidates
- requeue `7c72371f` / mutate locked rows
- A3 owner voice prove
- C5 six-row channel UPDATE
- canvas

---

## Packet 13.2 — S6 (WF-05 + 045)

Do **not** start 13.2 until 13.1 is published and
GET-verified. Unique **before** the INSERT that
names it (rule 24).

### Re-read (done, 17 Sep GET)

| Path | Verdict |
|---|---|
| WF-07 `Load digest` | No `interactions` join. Safe. |
| WF-08 `Retrieve corpus` | `FROM interactions LEFT JOIN people`. Second person **becomes visible**. Desired. |
| WF-05 `Load followup draft` | `follow_ups` by capture `LIMIT 1`. Not interactions. Unchanged product (one deferred draft per capture). |
| WF-05 `Call WF-10 deferred` | `executeOnce` true. Safe. |
| WF-05 `Mark resolution succeeded` | Keys `$('Prepare resolution')`, not INSERT RETURNING. |
| WF-05 `Enqueue enrichment` | Requires an interaction for that person. 13.2 will enqueue the second email. Desired. Unique is 023 person/job. |
| WF-10 `History load` | Already `person_id = p.id`. Empty summary today; 13.2 fills it. Does **not** attach the other person. |
| WF-10 `History insert` | `person_id + owner_id ORDER BY created_at DESC LIMIT 1`. Per-person. Safe. |
| WF-01 `Flag capture lookup` / Flag enqueue | `person_id + owner_id LIMIT 1`. Latest wins. Safe. |

**n8n item fan-out.** `Insert interaction` must still
emit **one** item. N RETURNING rows would re-run
Set capture status / Mark resolution. Outer SELECT
is capture-level. Enqueue enrichment may RETURN N
jobs — that already can, and the IF + NoOp terminals
already handle it. Do not set `executeOnce` on
Insert interaction.

Zero-people captures today still get a NULL
`person_id` row so the summary is not lost. Keep
that. Replay must not insert a second NULL row.

Do **not** backfill the 20 NULL `person_id` rows
or #153 / #151 by hand. New and replayed
extractions only.

### 13.2a — catalog **045_interactions_capture_person_uniq**

Forward-only. Idempotent. 030 stays Phase 6.

```
CREATE UNIQUE INDEX IF NOT EXISTS interactions_capture_person_uniq
  ON public.interactions (capture_id, person_id)
  WHERE person_id IS NOT NULL;
```

Refuse if live duplicates exist (count 0 on 17 Sep;
re-count in the migration). Partial unique: the 20
NULL `person_id` rows stay legal.

Rule 24: no workflow `ON CONFLICT` on this table
today. After apply, prove
`BEGIN; EXPLAIN INSERT INTO public.interactions
 (owner_id, capture_id, person_id, summary)
 VALUES (…, …, …, 'x')
 ON CONFLICT (capture_id, person_id)
 WHERE person_id IS NOT NULL
 DO NOTHING; ROLLBACK;`
parses.

### 13.2b — `Insert interaction` (verbatim)

`queryReplacement` **unchanged** (the same six
Prepare resolution fields). Credential Leap-NI.

```
WITH src AS (
  SELECT
    NULLIF(btrim(x.full_name), '') AS full_name,
    NULLIF(btrim(x.email), '') AS email,
    NULLIF(btrim(x.company_name), '') AS company_name
  FROM jsonb_to_recordset($3::jsonb)
    AS x(full_name text, email text, company_name text, title text)
  WHERE NULLIF(btrim(x.full_name), '') IS NOT NULL
),
person_hit AS (
  SELECT DISTINCT ON (p.id)
    p.id AS person_id,
    s.company_name
  FROM src s
  JOIN public.people p ON p.owner_id = $1::uuid AND (
    (s.email IS NOT NULL AND p.email_normalized = lower(s.email))
    OR (s.email IS NULL AND p.full_name = s.full_name)
  )
  ORDER BY p.id
),
company_hit AS (
  SELECT ph.person_id,
    COALESCE(
      (
        SELECT pc.company_id
        FROM public.person_companies pc
        WHERE pc.owner_id = $1::uuid
          AND pc.is_current
          AND pc.person_id = ph.person_id
        ORDER BY CASE
          WHEN ph.company_name IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.companies c2
            WHERE c2.id = pc.company_id
              AND lower(btrim(c2.name)) = lower(btrim(ph.company_name))
          ) THEN 0 ELSE 1
        END,
        pc.created_at
        LIMIT 1
      ),
      (
        SELECT c.id
        FROM public.companies c
        WHERE c.owner_id = $1::uuid
          AND ph.company_name IS NOT NULL
          AND lower(btrim(c.name)) = lower(btrim(ph.company_name))
        LIMIT 1
      )
    ) AS company_id
  FROM person_hit ph
),
ins AS (
  INSERT INTO public.interactions (
    owner_id, capture_id, person_id, company_id,
    summary, topics, opportunities
  )
  SELECT $1::uuid, $2::uuid, ph.person_id, ch.company_id,
    $4,
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(
      COALESCE($5::jsonb, '[]'::jsonb))), '{}'::text[]),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(
      COALESCE($6::jsonb, '[]'::jsonb))), '{}'::text[])
  FROM person_hit ph
  JOIN company_hit ch ON ch.person_id = ph.person_id
  ON CONFLICT (capture_id, person_id) WHERE person_id IS NOT NULL
  DO NOTHING
  RETURNING id
),
ins_null AS (
  INSERT INTO public.interactions (
    owner_id, capture_id, person_id, company_id,
    summary, topics, opportunities
  )
  SELECT $1::uuid, $2::uuid, NULL, NULL,
    $4,
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(
      COALESCE($5::jsonb, '[]'::jsonb))), '{}'::text[]),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(
      COALESCE($6::jsonb, '[]'::jsonb))), '{}'::text[])
  WHERE NOT EXISTS (SELECT 1 FROM person_hit)
    AND NOT EXISTS (
      SELECT 1 FROM public.interactions i
      WHERE i.capture_id = $2::uuid
    )
  RETURNING id
)
SELECT
  COALESCE(
    (SELECT id FROM ins LIMIT 1),
    (SELECT id FROM ins_null LIMIT 1),
    (SELECT i.id FROM public.interactions i
     WHERE i.capture_id = $2::uuid
     ORDER BY i.created_at DESC LIMIT 1)
  ) AS id,
  $2::uuid AS capture_id,
  (SELECT count(*)::int FROM ins) AS inserted_count,
  (SELECT count(*)::int FROM public.interactions i
   WHERE i.capture_id = $2::uuid) AS interaction_count,
  EXISTS (
    SELECT 1 FROM public.interactions i
    WHERE i.capture_id = $2::uuid AND i.summary IS NOT NULL
  ) AS has_summary;
```

Always one output row.

### 13.2c — `Load followup draft` leftover

Drop `AND f.id <> $2::uuid` and the locked uuid in
`queryReplacement`. Bind `$1` only
(`Mark resolution succeeded` `capture_id`). Same
class as 13.0 P3. Behaviour-neutral while
`5df341f8` stays `awaiting_confirm`.

### 13.2 PUT

**Rollback before PUT:** `<WF05_PUBLISHED_14_0>`
(`743c7c78`). GET name
`LNI WF-05 - Entity resolution`.

DIFF: Insert interaction SQL + Load followup draft
`$2` drop. Nothing else. Node count 31.

Survival: Leap-NI postgres `<PG_CRED_ID>` on every
PG node. `LEAP 2026` count 0. `errorWorkflow` WF-00.
timezone `Asia/Riyadh`. `availableInMCP` true.
`Set capture status` still `AND status IS DISTINCT FROM 'open'`.
Call WF-10 deferred `executeOnce` true.
Last node on the batch remains `Resolution batch done`.

### 13.2 acceptance

1. Catalog `045_interactions_capture_person_uniq` in
   `list_migrations`. Index live. 030 absent.
2. GET Insert interaction: no `LIMIT 1` on
   `person_hit`, no capture-level `NOT EXISTS`,
   has `ON CONFLICT (capture_id, person_id)`.
3. Outer SELECT has `inserted_count` (one item).
4. Load followup draft `queryReplacement` has one
   element, no `5df341f8`.
5. Prove: a **new** two-person extraction (not #153
   rewrite) writes two `interactions` rows, same
   `capture_id`, distinct `person_id`. Enqueue
   enrichment returns a job per email. `/ask` can
   see both names. Do not UPDATE #153 / #151.
6. Zero-people note-only still inserts one NULL
   `person_id` row when none exist.

### 13.2 non-goals

- Backfill 20 NULL `person_id` / #153 / #151
- C5 / D1
- WF-10 PUT (already 13.1)
- person_emails / entity_candidates review / login
- merge D-J
- canvas

---

## Order

1. This file + architecture / workflows / phases /
   prd pointers. Commit.
2. Packet 13.1 PUT. GET-verify. Commit.
3. Packet 13.2 migration 045, then PUT. GET-verify.
   Commit.
4. One PR per packet (or one PR if 13.1 is already
   on the branch when 13.2 starts — do not leave
   twelve open). Squash-merge onto `main` after
   architect read-back.

## Deliberate — do not “fix” on the way past

Permanent test tenant. Fixtures `#217`–`#234`,
`7c72371f`, two not-name-shaped people, D-J two-row
person. Locked follow_ups / jobs / ledger as in the
Phase 13 handover. GPT-4o card engine. Whisper
`language` absent. Do not activate WF-00b / NIWL-00.
