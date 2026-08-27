# Packet 3.5 — WF-07 send-path findings (awaiting ruling)

**Date:** 27 August 2026
**Scope:** Read-only diagnosis. No workflow edited. WF-07 left **active**
(`AyPtkP8PMFeEdYU9`) so tonight's 22:00 fire remains the timezone proof.
WF-08 / WF-09 not created. PR #15 not merged.

Live connections confirmed by MCP read-back of the published version.

This document is **findings, not a ruling**. Packet 3.6 implements after
the architect rules. WF-09 (3.7) must copy the ruled send topology, not
the live serial one.

---

## Q1. Email cannot survive a Telegram failure

### What is live

```
Compose digest → Scheduled send?
  true  → Chat id present?
            true  → Telegram digest → Email present?
                      true  → Gmail digest → Scheduled done
                      false → Telegram only → Scheduled done
            false → Undeliverable digest (stopAndError)
  false → Return to WF-01
```

Telegram digest: `retryOnFail: true`. No `continueOnFail`. No `onError`.
Gmail digest: `retryOnFail: true`, `continueOnFail: true`,
`onError: continueRegularOutput`.

A hard Telegram failure ends the execution. Email is never attempted.
Empty `chat_id` `stopAndError`s before Email present? runs, so missing
Telegram destination also kills the email channel.

### Cause

Not an n8n constraint. One IF true-output can fan out to two nodes.
Not for dedup. Not for ordering of content (both nodes already read
`Compose digest` by name).

It is how it got wired, following the spec as written.

`workflows.md` WF-07 scheduled send steps 3–4:

> 3. Gate `chat_id` notEmpty before Telegram.
> 4. Gate email notEmpty before Gmail. `continueOnFail: true` on Gmail —
>    Telegram already delivered. Do not `stopAndError` the digest if
>    mail fails.

That parenthetical treats email as a **copy after Telegram succeeded**,
and `continueOnFail` as "don't fail the run if the copy fails." It does
not encode "email exists so a Telegram-specific death still notifies the
owner."

The MCP skeleton encoded that reading literally:

```
telegramSend.to(emailPresent.onTrue(gmailSend).onFalse(skipEmail))
```

Packet 3.3 REST PUT copied the skeleton. Gmail's `continueOnFail` is
correct for "mail is optional after Telegram." It is the wrong lever
for "mail is the Telegram-survival channel."

### Proposed topology (do not build yet)

Fan-out from `Scheduled send?` **true**. Send in parallel. Merge **after**
both attempts, never before. Telegram `retryOnFail` must not delay Gmail.

```
Scheduled send? true
  ├─ Chat id present?
  │    true  → Telegram digest
  │              retryOnFail: true
  │              onError: continueRegularOutput
  │            → NoOp telegram-attempted
  │    false → NoOp telegram-skipped     (not stopAndError)
  └─ Email present?
       true  → Gmail digest              (continueOnFail already set)
       false → NoOp email-skipped

Merge (wait both)
  → IF at-least-one delivered
       true  → Scheduled done
       false → stopAndError
               "digest undeliverable both channels failed or empty"
```

Delivered = provider success field from the named send node
(Telegram `message_id`, Gmail `id`), not "the node ran." A
`continueOnFail` item with an `error` is not delivered.

Call path unchanged: `Scheduled send?` false → Return to WF-01.

WF-09 copies this pattern. Do not copy the live serial graph.

### Cost

- Extra Merge + IF + two skip NoOps.
- A Telegram-only hard fail no longer fails the whole execution.
- WF-00 fires only when **both** channels are empty or both failed.
- Owner still gets both channels on a clean run (already intended).
- Empty `chat_id` is no longer fatal by itself if email is present.
- Need an explicit delivered predicate; guessing from "node executed"
  would hide a failed send.

---

## Q2. Ungated zero-row path into the send chain

### What is live

`Load digest` has `alwaysOutputData: true` and a direct unconditional
edge to `Compose digest`. No IF between them.

On zero rows n8n emits one empty item. Compose reads `d.kind` =
undefined, falls to the `else` (briefing) branch, `n()` coerces every
count to 0. The `throw` on empty `reply_text` cannot fire because the
composed text is non-empty. Call path: `Scheduled send?` false →
Return to WF-01 → WF-01 sends a fabricated all-zeros briefing.

### Was `Row returned?` meant to cover this?

No. It sits on `Self identify` only. It is the wrong-database gate.
It cannot see Load digest's output.

Self identify SQL already filters `name = 'LEAP 2026'`. If that row
exists, Load's `params` CTE (same name + that `owner_id`) normally
returns a row too. The empty-item path that matters is
`alwaysOutputData` after a failed or empty SELECT looking like success
— the same trap as WF-01 `Duplicate check` (`workflows.md` §1).

### Why it was missed

Two spec lines were conflated:

1. "Zero captured is still a real report (not silent)" — a **real SQL
   row** with `captured = 0`. That must still compose and send.
2. "Explicit gate before any send node" / zero-row `{success:true}`
   must not reach a send — an **empty item**, not a zero count.

`alwaysOutputData: true` was copied from sibling Postgres nodes so the
node does not crash on empty. The matching IF after Load was never
added. Compose's `n()` helper then turns missing fields into a
believable briefing.

### Where the gate belongs

After `Load digest`, before `Compose digest`.

IF named Load: `kind` equals `close` OR equals `brief` (`typeValidation:
strict`) AND `riyadh_date` notEmpty.

False → `stopAndError` (no compose, no send, no return to WF-01).

Do **not** gate on `captured > 0`. A true zero-capture day is a real
report.

Keep `alwaysOutputData` on Load. The IF is the gate; removing
`alwaysOutputData` just moves the failure into a node crash with a
worse message.

A gate only on `Scheduled send?` would still return fabricated
`reply_text` to WF-01. Both send and call sit downstream of Compose,
so Compose is the last safe place to refuse.

---

## Q3. Wrong-database guard weaker than siblings

**Drift, not deliberate.**

| Workflow | Gate | Predicate | typeValidation |
|---|---|---|---|
| WF-03 / 04 / 05 | `Gate: LEAP-NI database` | `name` equals `LEAP 2026` | strict |
| WF-07 | `Row returned?` | `name` notEmpty | loose |

MCP skeleton (`/tmp/lni-wf07.js`) created `Row returned?` as notEmpty /
loose. Packet 3.3 rebind fixed the credential. The IF was never aligned.

SQL on Self identify still has `WHERE name = 'LEAP 2026'`, so ElderWise
with no such row still takes the false branch. The IF alone would pass
any database that returns a non-empty `events.name` if the SQL were
loosened or if `alwaysOutputData` left a stray field. Align to siblings
in 3.6: equals `LEAP 2026`, strict.

---

## Q4. Self identify options not explicit

**Carried from the MCP skeleton, not intentional.**

Live WF-07 Self identify: `options: {}`. No `executeOnce`. No
`replaceEmptyStrings: false`.

WF-03 / 04 / 05 Self-identify LEAP-NI all set both:

- `executeOnce: true`
- `options.replaceEmptyStrings: false`

Same skeleton that left `options: {}` on the query. Values relied on
must be explicit in saved JSON (`workflows.md` §1). Align in 3.6.

---

## Q5. Capture 62 wrote two company rows from one card

**Cause only. No WF-05 change proposed here.** WF-05 left active.

### What is live

Same `created_at` `2026-08-27 06:20:51.390502+00`:

| `companies.name` | person_companies | interactions |
|---|---|---|
| Huawei | 0 | 0 |
| شركة هواوي تك انفستمنت العربية السعودية المحدودة | 1 | 1 |

Companies went 2 → 4 on that capture. Huawei is an orphan.

`extraction_runs.structured_output` for #62:

- `companies[0].name` = `Huawei`
- `people[0].company_name` = the Arabic legal name
- `roles[0].company_name` = the Arabic legal name (unused downstream)

#61 both said `BTGroup`, so one key, one row.

The split starts one step earlier than WF-05. WF-03 vision for #62:

- `result.company.name` = `Huawei`
- `result.people[0].company_name` = the Arabic legal name

WF-04 copied that disagreement into `structured_output`. WF-05 then
materialised both strings as rows.

### What each node reads

**Prepare resolution** (Code, immediately before the upserts):

1. Seed a map from `companies[].name`, keyed by `name.toLowerCase()`.
2. For each `people[].company_name`, if that exact lowercased string is
   **not** already a key, insert a second map entry (domain/website null).
3. `roles[]` is ignored.
4. Emit `companies: Object.keys(companyByKey)`.

There is **no precedence**. Disagreeing strings are a UNION. Both survive.

**Upsert companies** reads `Prepare resolution.companies`. Match key is
`lower(trim(c.name)) = lower(trim(s.name))`. No unique index on
`(owner_id, name)` or `normalized_name` — only PK on `id`. Two different
strings → two INSERTs in one statement.

**Link person_companies** reads `Prepare resolution.people`, not the
companies array. Join:

`lower(trim(c.name)) = lower(trim(x.company_name))`

where `x.company_name` is `people[].company_name`. So only the Arabic
row is linked. Huawei has no person and no interaction.

**Insert interaction** uses the same people-side join. Capture 62's
interaction points at the Arabic company.

### Intended precedence in the spec

`workflows.md` WF-05 step 5 says upsert companies. It does **not** say
what to do when `companies[].name` and `people[].company_name` disagree.
No alias / brand-vs-legal rule exists. The code's behaviour is "both
are canonical if the strings differ."

### Does WF-07 count them as two?

**Yes.** Morning briefing `companies` is `count(*)` on `public.companies`
in event scope (`workflows.md` WF-07). It is a row count, not a
linked-or-interacted count. The briefing will report **4** companies.
Huawei and the Arabic legal name both count. That number is now wrong
as "how many companies did I actually meet."

---

## Q6. Arabic-only names — analysis only, no change

### What fired

WF-04 `Parse + validate + flag`:

```
hasNonLatinName = /[^\u0000-\u024F\u1E00-\u1EFF\s]/
flag if any people[].full_name matches
```

Capture 62 `full_name` = `وانغ (بوب)` (same string in
`name_original_script`). The card had no Latin name. The model did not
transliterate. The flag fired. Extraction job still `succeeded` (flags
do not set WF-04 outcome unless schema-invalid). WF-05 wrote the person
anyway (drop rule is empty `full_name`, not "must be Latin"), then set
capture + resolution job to `needs_review` because `flag_reasons` was
non-empty.

### Fraction of the needs_review path

Terminal captures at `needs_review`: **2** (#59, #62).

| Capture | Latest flags |
|---|---|
| #59 | No name extracted, No email and no phone |
| #62 | Non-Latin script present in the name field **only** |

This rule is **1 of 2** terminal `needs_review` captures. It is the
**only** flag on #62. It does not co-occur with anything else.

Latest extraction_runs that have any flag (one row per capture): **6**.
This rule is **1 of 6**. The other five are the no-name / no-contact
family, mostly leftover processing captures that never reached WF-05.

#62 has a name, an email, and a phone. Without this one flag it would
be `ready`.

### If an Arabic-only `full_name` were accepted

Analysis of consequences, not a recommendation:

1. #62 becomes `ready`. Owner-facing flagged list drops from 2 to 1
   (only #59).
2. The person row already exists with Arabic in **both** `full_name` and
   `name_original_script` (identical). Packet 2.5 called that a lost
   transliteration. Accepting Arabic-only `full_name` makes that policy,
   not a defect.
3. This flag does **not** review correctly-handled Arabic-only cards.
   A card that transliterated into Latin would not match the regex.
   It only fires when non-Latin **leaked into `full_name`**. Turning
   it off for Arabic-only identity means that leak is no longer a
   review reason.
4. Auto-link (email / LinkedIn) is unchanged. OCR-split
   `same_full_name` would then compare Arabic to Arabic; a later Latin
   reading of the same person would not hit that path.
5. Briefing `people` count does not change (row already written).
   Briefing `unreviewed` drops by one capture. Company-count error in
   Q5 is independent.
6. WF-04 still drops null/empty `full_name`. Arabic text already
   satisfies that. The identity contract today is "non-null **Latin**
   `full_name`" (`architecture.md` §6). Accepting Arabic-only is a
   contract change, not only a flag change.
