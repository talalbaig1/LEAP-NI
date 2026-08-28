# prd.md

**LEAP Networking Intelligence (LNI)** · Product Requirements
Version 2.0 · 25 August 2026

> **Documentation precedes implementation.** Behaviour changes are recorded here
> *before* they are built. See `rules.md` §1.

---

## 1. The user and the situation

One user: Talal, attending LEAP 2026 in Riyadh as a visitor, 31 Aug – 3 Sep.

**The physical reality the product must survive:**
- Halls open 1:00 PM – 9:00 PM. Eight hours on his feet, four days running.
- ~200,000 attendees sharing venue wifi. Connectivity is unreliable by default.
- One hand free. The other holds a bag, a coffee, or a business card.
- Expected volume: 40–80 contacts per day, ~350 across the event.
- Mornings are free. That is the review and planning window.

**What he collects:** business cards, occasional selfies with people, and his
own voice notes describing what was discussed.

---

## 2. Jobs to be done

| # | Job | Success looks like |
|---|---|---|
| 1 | Capture a contact without breaking the conversational moment | Under 30 seconds, one hand, no thinking about the tool |
| 2 | Never lose anything | Every card, note, and photo survives, even with no signal |
| 3 | Remember *why* someone mattered | The conversation is attached to the person, not just their title |
| 4 | Know how to spend tomorrow | A morning briefing that changes the plan for the day |
| 5 | Follow up before the memory fades | Prioritised list with drafts referencing real specifics |
| 6 | Find anyone later | "Who did I meet from fintech?" answered in seconds |

**Job 1 and Job 2 are the only ones with a deadline.** Jobs 3–6 replay against
retained raw assets at any future date (`masterplan.md` §3).

---

## 3. Capture surface: Telegram

Chosen because it already solves — tested at scale, for years — camera access,
microphone, multi-image albums, an offline outbox, and automatic retry on
reconnect. A hand-rolled offline queue tested for two days would not.

A PWA is built later (Phase 8), sharing the same backend.

---

## 4. Command surface

| Command | Behaviour |
|---|---|
| `/new` | Opens a capture. **Implicitly closes any previously open one.** |
| `/done` | Closes the open capture (batch: all open batch captures). Standard reply: `✓ Capture #47 saved · 2 items`. Batch reply: `N cards received · processing` — extraction has not run yet (`prd.md` §5). |
| `/batch` | Every subsequent photo becomes its own independent capture. |
| `/status` | Shows what is currently open and in what mode. |
| `/digest` | Runs the digest on demand. Before 12:00 Riyadh → morning briefing; otherwise → day close. WF-01 sends the `reply_text`. |
| `/ask <question>` | Natural-language query over captures. |
| `/fix <n>` | **Post-event** (packet 2.5 cut). Correct fields on a capture. `<n>` is `captures.capture_no`, never the uuid. |
| `/flag <text>` | Force-enqueue enrichment of **one** person. `<text>` is a name or email, not a capture number. WF-01 **enqueues** only (`force=true`); it does not dispatch and does not call Apollo. WF-06 drains on its `*/15` schedule. Resolution, stop at the first step that yields a match: (1) exact `email_normalized`, (2) exact `full_name` case-insensitive, (3) trigram similarity on `full_name`, threshold 0.4. Outcomes are **reply-only** except the single-match enqueue: 0 matches → `No person matches <text>.` (nothing enqueued); 2+ matches → list name + email, max 5, nothing enqueued, owner re-issues `/flag` with an email, never guess; 1 match already queued → `Already queued for enrichment.`; 1 match → enqueue `force=true`, reply `Queued <name> for enrichment. Result within 15 minutes.` Empty argument → `Usage: /flag <name or email>`. `force=true` bypasses the 30-day cache **only**. It never bypasses the daily or lifetime credit ceiling. |

### The four guardrails

The owner chose explicit `/new`…`/done` over reply-threading. These guardrails
exist so that forgetting `/done` — which *will* happen at 7 PM on day three —
can never lose or mis-attribute data.

1. **`/new` implicitly closes the previous capture.** The most common mistake
   becomes a no-op.
2. **Inactivity auto-close** after 10 minutes idle (`captures.last_activity_at`,
   per capture — not `bot_state.last_activity_at`),
   stamped `close_reason = auto` so it is visible in review. Window is a
   documented constant in the WF-02 sweep query, not `$env`. The sweep is
   WF-02's Schedule Trigger (every 5 minutes, `Asia/Riyadh`). **Closing is
   not enough:** the sweep must enqueue `processing_jobs` for every stored
   asset of every capture it closes, then dispatch WF-03 best-effort, using
   the same INSERT and the same unique-index `ON CONFLICT` as `/done`.
   A capture closed by the guardrail and never processed is the defect
   this guardrail exists to prevent (`prd.md` §4: forgetting `/done` WILL
   happen).
3. **Media with no open capture is never rejected.** A capture opens silently
   (`resolve_target` orphan adoption) and the bot says so. Nothing is dropped
   for a protocol error.
4. **Every bot reply echoes current state**, using `captures.capture_no`, never
   the uuid. WF-02 returns `reply_text` and `state_echo`; **only WF-01 sends**.
   If storage fails, no receipt is sent.

### Bulk entry

Two modes, covering genuinely different moments.

**`/batch`** — deliberate evening data entry. Toggle on, send thirty cards in a
row, `/done` to exit. No grouping, no commands between. **This is the live
album-scale path.** Packet 2.5 cut album auto-detect from Phase 2; grouping
stays on `/batch`, which is proven.

**Album auto-detect** — **post-event** (packet 2.5). Telegram delivers each album member as a separate
update, so there is no shared in-memory buffer. The first member creates
the capture keyed by `flags->>'media_group_id'`; later members attach to
that row (partial unique index, migration `013`; `flags` is a jsonb
**object** after `015`). An album of more than
two images triggers a single inline prompt **after** the assets are stored:
*"20 images — separate people, or one person?"* The bot **asks rather than
assumes**, so twenty strangers can never be silently fused into one contact,
and no unanswered callback can lose an asset. Album implementation is
Phase 2 (promoted from packet 1.4 leftover, owner decision 27 Aug 2026);
the Postgres-buffer design is in `workflows.md` WF-01.

Batch-captured cards have no voice note and produce thinner records. They are
marked `card_only`, so that later the owner can distinguish *"I have no memory
of this person"* from *"I met them and it wasn't interesting."*

---

## 5. Feedback model

The owner chose **silent unless a flag fires**. Two adjustments make that safe.

### The receipt is not a review card

`/done` replies with a bare `✓ Capture #47 saved · 2 items`. This is not the
review prompt the owner declined — it is proof the pipeline is alive. Without
it, a dead pipeline looks identical to a healthy one, and the failure would
surface on day four instead of day one.

**Batch `/done` cannot quote extraction outcomes.** Extraction has not run at
that instant, so clean / need_review / failed numbers can never be true
there. The batch receipt is **`N cards received · processing`**. Do not
emit hardcoded zeros for clean / need_review / failed. Real counts
are deferred to the digest (WF-07), which runs after WF-03/04 have actually
produced them.

**If storage fails, no receipt is sent.** Silence means something went wrong.
The owner must never be falsely reassured. Inbound chat replies live in
WF-01; WF-02 / on-demand WF-07 / WF-08 only return `reply_text`. Scheduled
digests and watchdog alerts send on their own cron execution (no parent
WF-01); `chat_id` from `bot_state`, same pattern as WF-00.

### Flagging is rule-based, not model-reported

A vision model is often *most* confident exactly when it is transliterating an
Arabic name wrongly, so self-reported confidence is not a reliable error filter.
Observable conditions are. Full rule list in `architecture.md` §6.

Everything not flagged surfaces in the daily digest.

Phase 1 stores images without classifying them. Composition is unpredictable
and the owner has one hand free, so `'photo'` at capture time means
unclassified; WF-03 assigns the real `assets.kind` in Phase 2.

---

## 6. Digests

| Digest | Time | Purpose |
|---|---|---|
| Day close | 10:00 PM `Asia/Riyadh` | Operational health |
| Morning briefing | 7:00 AM `Asia/Riyadh` | Actionable intelligence |
| On demand | `/digest` | The report matching Riyadh time of day |

**10 PM close** — captured, clean, flagged, failed, **stuck**. The stuck count
is the figure that saves the project: it is how the owner learns on day one that
something is jammed, rather than on day four. Scheduled close is copied to
email as a durable record independent of Telegram history. `/digest` is
Telegram-only (WF-01 sends).

**7 AM briefing** — people met, companies, sector distribution, coverage gaps
against `events.target_sectors`, follow-ups due today, unreviewed count.
Empty `target_sectors` prints "Target sectors not set" rather than inventing
gaps. `companies.industry` is empty until Phase 4; the mix then reads
`unknown`. This is the only moment the collected data can change how the
next eight hours are spent. After Thursday the event is over and the
information is only useful for follow-up.

Example shape: *"14 people, 9 companies, mostly systems integrators. Nobody yet
from your target sectors. 3 people asked you to follow up today."*

---

## 7. Data quality requirements

- **Arabic original script is preserved** alongside transliteration, in
  `name_original_script`. Never discarded. Transliteration is lossy and is the
  highest-error surface at this event.
- **Nullable beats guessed.** The model must never invent an email, phone,
  domain, or date not present in the source.
- **User corrections are canonical** and are never overwritten by a re-run.
  Model output is retained alongside, which is what allows extraction quality to
  be measured and better models to be re-run later without losing edits.
- **No auto-merge on name similarity.** Only exact email or exact LinkedIn URL.
- **Provenance recorded.** `source_type` distinguishes a card handed over
  voluntarily from data obtained any other way.

---

## 8. Privacy requirements

- **Voice notes are self-dictation only** — the owner describing the
  conversation afterward, never a recording of the other party. This removes the
  consent question almost entirely, and his own summary of what mattered is more
  useful than raw small talk anyway.
- **No facial recognition, ever.** A selfie is context and proof of meeting —
  *"the man in the grey jacket at the Aramco stand"* — never an identity lookup.
- **Per-contact deletion is a real feature**, removing database rows and storage
  objects. Retention is indefinite; the ability to delete is what makes that
  defensible.

---

## 9. Non-goals

Explicitly out of scope, to prevent scope creep under deadline pressure:

- Multi-user or team collaboration (schema supports it; not built)
- Automated outbound messaging of any kind
- LinkedIn connection or message automation
- Face matching, badge scanning, or attendee-list scraping
- A native mobile app
- Real-time processing — asynchronous is correct and sufficient
- Perfect extraction. Flagged-and-reviewable beats confidently-wrong.

---

## 10. Acceptance criteria — launch (30 August)

The system ships when all of these pass **on the owner's actual phone with real
business cards**:

1. Card photo, voice note, and typed note each capture independently
2. 20 consecutive real-device captures with **100% asset preservation** and
   100% visible outcome — no silent loss
3. Resending identical media creates no duplicate asset
4. A card plus a 30-second voice note produces a reviewable record within
   2 minutes
5. Arabic name preserved in original script
7. Forgetting `/done` loses nothing — the inactivity sweep enqueues and
   dispatches the same as `/done` (packet 2.5 defect 1)
8. A 20-image album prompts once and never fuses contacts silently —
   **post-event**; live grouping is `/batch`
8. Both digests fire at correct Riyadh local time, verified by observed
   execution timestamps
9. Watchdog alerts on a stuck job independently of the digest
10. Failed provider calls retry, then land in a visible `failed` state without
    creating duplicate people
11. A second authenticated test user can read nothing

**Criterion 2 is the one that matters most.** Everything else can be repaired
after the event. Data never captured cannot be.
