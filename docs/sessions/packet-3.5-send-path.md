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
