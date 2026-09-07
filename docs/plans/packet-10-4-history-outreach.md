# Packet 10.4 — History outreach (docs only)

**Date:** 7 Sep 2026
**Status:** DOCUMENTED. No PUT, no migration, no SQL write until
the architect authorises the build.
**Home:** this file. Contracts also in `masterplan.md` §4,
`phases.md` packet 10.4, `architecture.md` compose-from-history,
`workflows.md` WF-10, `prd.md` §8b.

Voice `/followup` path is untouched. Decision 12 still holds:
the system never sends on this path.

---

## Measured inputs (architect, live SQL, 7 Sep 2026)

Use these. Do not recount in the build.

| Cut | N |
|---|---|
| Reachable people | 37 |
| Have email (all 20 also have a phone) | 20 |
| Phone-only | 10 |
| No channel | 18 |
| Of the 20 emails: usable transcript | 8 |
| Of the 20 emails: no usable transcript → general letter | 12 |

**Transcripts are unreliable.** Known Whisper defect
(`rules.md` §7 rule 1; ElderWise WF-5 `language: "en"` trap
is the same family — LNI already omits `language`, and the
output is still wrong-script / garbled / factually wrong):

- Wrong-script: Urdu for Omair Shaikh, Sulaiman Asif
- Garbled entities: "AAA AAA" for TripLA, "sulphur"
- Factually wrong summary: Shahzad Jameel recorded as
  "software developer at NetEngine Bus"; he is at VirtueNetz

Do not write confidently from a bad transcript (D-F).

5 Sep counted 16 with email, 3 already emailed (DES RAJ
Chauhan, Rana Waleed, Shahzad Jameel) → 13 remaining. 7 Sep
is 20 with email (S7b replays added rows). Skip already-sent
people via Q3, not by hard-coding those three names.

---

## Channel split (D-E)

One sender: the owner, by hand. WF-10 gains `source='history'`.

| Channel | Who | What LNI writes | Owner does |
|---|---|---|---|
| email | the 20 | Gmail **Draft** in Drafts. Never sent. | Opens Gmail, edits, sends |
| whatsapp | the 10 phone-only | Message **TEXT** to Telegram | Copies into WhatsApp |
| linkedin | no-email, has LinkedIn (owner's list; not the 18 empty) | Message **TEXT** to Telegram | Copies into LinkedIn |

A person in the 20 is **email-only** on this run. Do not also
queue a WhatsApp copy for them. One message per person.

**Not in this packet**

- WhatsApp Business API (D-D still: no API). D-E is copy-text.
- LinkedIn automation (prd non-goal). D-E is copy-text.
- The four D-H exceptions (manual; not WF-10).

---

## D-E — Three channels, one sender

WF-10 `Normalize input` / `Route source` accept `history`.
Gmail node on this branch is `resource=draft` `operation=create`
(typeVersion 2.2). No `resource=message` `operation=send`.
WhatsApp and LinkedIn branches do not call any third-party
send API. They return `reply_text` (and `reply_text_2` if
needed) for WF-01 or WF-10 to deliver on Telegram.

---

## D-F — Evidence beside the draft

Every generated message is accompanied by the transcript and
the `interactions.summary` it was written from. A draft with
no visible source is not acceptable.

Where the transcript is wrong-script, garbled, or known-wrong,
**say so on the draft** and fall back to the general letter
(D-G). Do not quote garbage as if it were the conversation.

**Q1 (open — recommendation below).** How the evidence reaches
the owner.

---

## D-G — Tone by source

`people.source_type`: `card` / `photo` / `voice_note` /
`shared_contact` (and typed_note / vcard if they appear).

- Has a **usable** voice-note transcript → reference what was
  actually discussed. No invented booth, role, or offer.
- No voice note, or transcript flagged unusable (D-F) →
  general stay-in-touch. No invented specifics.

12 of 20 emails are this general letter by measurement.

---

## D-H — The ask

The ask comes from the voice note. If the transcript carries
no ask, the message has **no ask**. Do not invent a meeting,
intro, or product push.

Four owner-specified exceptions are **MANUAL**, not automated.
Do not put them on the `source=history` SELECT:

| Person | Channel | Ask |
|---|---|---|
| Saad Raja (Antler) | LinkedIn only | SilaCares |
| Ali Abbas (Blossom) | WhatsApp only | SilaCares |
| Rana Waleed | (owner sends) | iOS/Android launch help |
| Fawaz Alesayi | (owner sends) | iOS/Android launch help |

SilaCares was not pitched on the floor (D-I). These four are
the only SilaCares asks, and they are done by the owner.

---

## D-I — Signature block

Identical in all three channels. Loaded from Postgres
(`sender_profile.signature_block`, proposed). Never `$env`.
Never jsCode. Never `lni_config` (integer).

```
Talal Baig
Building SilaCares - caring for loved ones from a distance,
  through technology. silacares.com
Building Ionicx.io - AI-driven architecture and services.
  We automate the work: lower cost, faster processes,
  more revenue.
Twenty years in IT, networks and communications - now
  putting it into my own products.
linkedin.com/in/talal-baig
```

Ionicx was pitched in person to most contacts. SilaCares was
**not**. Do not write as if SilaCares was discussed, except
the four D-H manuals.

---

## D-J — Muhammad Zahir

One man, two ventures, two cards, two `people` rows. **Do not
merge the rows in this packet.**

- One Gmail draft. To: `muhammad@kaacib.com` **and**
  `muhammad@haramaincompanion.com`.
- Same WhatsApp text to both stored numbers (if he is on the
  phone path; if he is in the 20, email only per the split).
- Q3 must mark **both** person rows so a re-run does not
  draft twice.

---

## D-K — Rashid domain

**Exclude** `rashid@kacaib.com`. OCR transposition of
`rashid@kaacib.com` (live website, real company domain).
One email to Rashid, not two. Filter the typo in the
history SELECT.

---

## Storage — propose, do not write

`lni_config.value` is `integer` (Phase 4, migration 020).
The signature will not fit.

**Recommend: `sender_profile` (proposed 031).** Do not take
030 (Phase 6 embeddings, reserved).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `gen_random_uuid()` |
| `owner_id` | uuid UNIQUE NOT NULL → `auth.users` | one row |
| `signature_block` | text NOT NULL | exact D-I block |
| `created_at` / `updated_at` | timestamptz | |

RLS: one policy `sender_profile_owner_all`, same shape as
`lni_config`. Seed the owner's row in the same migration.

**Rejected:** extra `value_text` on `lni_config`. Mixes ceilings
with prose. Every other key stays integer.

**Rejected:** stuffing the block into WF-10 jsCode. A PUT would
hard-code owner copy; the next signature edit becomes a workflow
change.

Do not write 031 in this packet.

`follow_ups.draft_state` planned values (CHECK migration in the
build, not here): `gmail_draft` (email draft exists, unsent);
`handed_off` (WhatsApp / LinkedIn copy delivered on Telegram).
`status` stays `open`. Do not alter `follow_ups_status_check`.

Optional additive (build, not this packet): `channel` text
CHECK `email | whatsapp | linkedin`. Q3.

---

## Composer

Reuse **`Extract draft`** (`gpt-4o-mini`, `temperature: 0`,
schema `wf10-v2`). History fills the `Brief:` line. Prompt
gains: stored notes; D-G / D-H / D-I; "if transcript looks
wrong-script or garbled, say so and write the general letter".
Do not add a second LLM node.

Scene photo auto-attach on the **email** path only, when
`assets.kind IN ('photo','selfie')` on the linked capture
(D-B). No picker. WhatsApp / LinkedIn copy-text has no
attachment.

---

## Q1–Q3 — implementer recommendation (architect decides)

**Q1 — How does a draft carry its evidence?**
Recommend **both**, because the surfaces differ.

- **Email:** evidence appendix **in the Gmail draft body**,
  below the signature, marked so the owner deletes it before
  send (e.g. a line `--- evidence, delete before send ---`
  then transcript + summary). The owner reviews in Gmail.
  A Telegram-only receipt would split the letter from its
  source.
- **WhatsApp / LinkedIn:** there is no Gmail draft. Evidence
  rides in the **same Telegram message** as the copy-text
  (or `reply_text_2`). Telegram is the only surface.

Wrong-script / garbled: the evidence block says so in
plain words. The letter above it is the general stay-in-touch.

**Q2 — Trigger: per person, or a batch of 20 drafts?**
Recommend **one batch** that produces **20 separate Gmail
drafts** (and a later batch for the 10 WhatsApp texts).
Not a blast: 20 composes, one To: each (D-A, Decision 12).
The set is closed and counted. Per-person Telegram commands
invite "later" on a fading event. Build note: Gmail
`executeOnce` must not collapse the 20 into one draft
(WF-04 Call WF-05 lesson).

**Q3 — What marks contacted so a re-run does not duplicate?**
Recommend **`follow_ups` + `channel`**, not a new table.

- One row per `(person_id, channel)`.
- Email: `draft_state='gmail_draft'`, `gmail_message_id` set,
  `status='open'`.
- WhatsApp / LinkedIn: `draft_state='handed_off'`.
- History SELECT: `NOT EXISTS` a non-cancelled row for that
  person+channel.
- Zahir: two rows, same `gmail_message_id`, both channels
  marked.
- Already-sent live-path follow-ups (`draft_state='sent'`)
  also exclude.

`draft_state` alone without `channel` cannot tell email-done
from WhatsApp-still-open on the same person.

---

## Out of this packet

- PUT WF-10 / WF-01
- Migration 031
- 10.4a Gmail draft+attach spike (still the prove before
  attaching scene photos)
- 10.3 Apollo sweep
- Merging Zahir's two people rows
- The four D-H manuals
- S9 interaction backfill
- Starting Phase 5 / 6 / 8
