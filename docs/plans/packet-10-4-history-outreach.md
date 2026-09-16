# Packet 10.4 — History outreach (docs only)

**Date:** 7 Sep 2026 · **Updated:** 14 Sep 2026 (Phase 10 close + 10.1 skip list)
**Status:** Q1–Q3 LOCKED. Phase 10 CLOSED after CH1–CH5.
Email + WhatsApp + LinkedIn generated. Decision 12 holds.
Packet 10.1: History load skip ids reduced to Zahir
kaacib `ba037ac0` only (WF-10 published `226fe197`).
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

**Q1 LOCKED 14 Sep (reversed).** Evidence goes to
**Telegram only.** Never into the Gmail draft body. A draft
body is one careless send from the recipient. The Gmail
draft is the sendable email and nothing else.

Telegram carries: person name, channel, transcript, summary,
and an explicit warning line where the transcript is
wrong-script or garbled. Fall back to the general letter
(D-G). Do not quote garbage as if it were the conversation.

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

## D-I — Signature block (CH5)

Same content, three renderings, all in `sender_profile`.
Never `$env`. Never jsCode. Never `lni_config`. Never
hardcoded in the Extract prompt.

| Column | Channel | Shape |
|---|---|---|
| `signature_block` | email | existing HTML (032). Unchanged. |
| `signature_whatsapp` | whatsapp | compact plain text, no HTML, no bullets. Four short lines: name; SilaCares + URL; Ionicx; LinkedIn URL. |
| `signature_linkedin` | linkedin | one line plus the URL. Connection note + bio must stay under 300 characters. |

033 added the two plain columns (forward-only). 030 stays
reserved for Phase 6. History Gmail `emailType=html`.

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

## Q1–Q3 — LOCKED 14 Sep 2026

**Q1.** Telegram only. Never put evidence in the Gmail
draft body. Draft = sendable email. Telegram = name,
channel, transcript, summary, garbled warning.

**Q2.** Batch, but a **three-draft dry run first**: one
voice-note / usable transcript, one no-transcript, one
with a scene photo. Owner reads. Remaining seventeen
need a separate authorisation.

**Q3.** `follow_ups.channel` + `draft_state='gmail_draft'`.
Partial unique index `(person_id, channel) WHERE
draft_state <> 'cancelled'` (and person_id / channel not
null). Re-run cannot double-draft.

---

## 10.4b build notes

- Rollback WF-10 published **`1c1c39f4-3bff-4f1f-ba16-c3d6765a4221`**
  (named before any history PUT). First accepted history
  graph: **`966950f1`**. Composer fix published
  **`0799a8dd-2e16-4cc8-b3c4-fb9dddfe7b34`** (172 nodes).
  Non-Latin script is not garbled. Extract proven on Zahir
  and Deema. Name-checked `LNI WF-10 - Follow-up drafting`.
- `Extract history draft` is a sibling OpenAI node. Live
  `Extract draft` expressions require command/voice nodes
  and would throw on this path. Voice-path Gmail nodes stay
  `resource=message` `operation=send`. History Gmail nodes
  are `resource=draft` `operation=create`.
- `Route source` outputs: 0 command, 1 voice, 2 callback,
  3 history, 4 unknown.
- Kick path was `POST /webhook/lni-wf10-history`
  `{source:history, person_id}`. **Removed 12.5a-0**
  (unauthenticated; path in public LEAP-NI). History
  is executeWorkflow `When called` with caller
  `owner_id`. MCP `execute_workflow`
  cannot run an Execute-Workflow-only graph.
- Gmail draft + real attachment proven before the batch:
  `LNI-TEST- 10.4b gmail draft attach` `YjgQeHvlRigRzugm`
  exec **461630**. Owner should delete that test draft.
  **12.5a-0b:** that TEST workflow and
  `LNI-TEST- 10.4b delete drafts` were ACTIVE
  unauthenticated webhooks; both deactivated then
  archived (not deleted). Production POST 404.
- First dry run **rejected**. Martin was a pre-event
  test-card (hand-passed list; History load had no
  `created_at` / `LNI %` / example-email filter). Rashid
  no-transcript branch fired; LLM still invented. Unusable
  path now uses `History template`, not OpenAI.
- Second dry run (in-scope). Owner reads; STOP.

| Person | person_id | Exec | Telegram | follow_ups | Gmail draft | Attach | Reason |
|---|---|---|---|---|---|---|---|
| Sulaiman Asif | `e4f1751a` | **461817** | 925 | `0ee1d8f4` | `r-1419115434923293829` | 1 | wrong-script |
| Abdullah Ahsan | `96066d72` | **461818** | 926 | `ab87acc9` | `r484651116714432984` | 0 | no transcript |
| Omair Shaikh | `a864283f` | **461819** | 927 | `7dc52905` | `r-3776398866982478871` | 1 | wrong-script |

  Cancelled v1: `ff71b02c` / `ada18272` / `5d9a7d64`.
  Gmail deletes exec **461816**.
- History load now requires `created_at >= 2026-08-30
  21:00:00+00`, excludes `full_name LIKE 'LNI %'` and
  example/invalid emails. Dry run is still a hand-passed
  list of three; there is no batch SELECT of the 20.
- Third dry run (usable path). D3: non-Latin is not
  garbled. Owner reads; STOP.

| Person | person_id | Exec | Telegram | follow_ups | Gmail draft | Path | Attach |
|---|---|---|---|---|---|---|---|
| Muhammad Zahir | `d2335783` | **461871** | 928 | `10787045` | `r6789855113287998840` | Extract | 110524 |
| Deema Alwaala | `2ca63896` | **461872** | 929 | `c2c819f8` | `r-8320115643520228008` | Extract | 0 |
| Abdalla Elkhouli | `db31bc6e` | **461873** | 930 | `76083561` | `r-7517758840755362577` | template (`aaa aaa`) | 103619 |

- Third dry run: mechanics accepted, content rejected
  (greeting + dry template + signature typography).
- C1: 032 HTML `signature_block`. History parse wraps
  the letter and appends the HTML signature.
- C2: `History template` is a warm stay-in-touch note
  from the card only. Invents nothing about a conversation.
- C3: greeting-by-name is a hard rule in the Extract
  prompt, the template, and History parse (prepend if
  the body does not start with Hello / Dear / Hi).
- C4: S9 attachment miss. History load photo lookup
  joined only through `interactions.person_id = p.id`.
  Proposed interaction backfill is **not unambiguous**
  for all seven (only #151 Abdullah). Backfill **not
  written**. WF-10 photo LATERAL also matches
  `extraction_runs.structured_output` on
  `email_normalized` (Abdullah #151, 107532 bytes).
- C5 / fourth dry run. Stale v2 + Zahir v3 cancelled.
  Prompt `wf10-hist-v4`. Published **`bed27da5`**.
  Owner reads bodies. STOP.

| Person | person_id | Exec | Telegram | follow_ups | Gmail draft | Path | Attach | Reason |
|---|---|---|---|---|---|---|---|---|
| Omair Shaikh | `a864283f` | **462396** | 931 | `32146c79` | `r-2339983374018899941` | Extract | 114326 | Urdu usable |
| Sulaiman Asif | `e4f1751a` | **462397** | 932 | `5f4d1173` | `r635050107219057841` | Extract | 111968 | Urdu usable |
| Abdullah Ahsan | `96066d72` | **462398** | 933 | `a8b2dbaf` | `r7147000344519431064` | template | 107532 | no transcript |
| Muhammad Zahir | `d2335783` | **462399** | 934 | `b1786e3f` | `r-4333065214953054450` | Extract | 110524 | greeting + HTML sig |

  Fourth dry run accepted. C4 backfill stays unwritten
  until 10.1 merges duplicates.
- Deema + Abdalla regenerated v4. Remaining in-window
  email humans drafted. 19 live `gmail_draft` rows.
  One-webhook multi-person fails when Extract and
  template mix (`History parse` pairing). Kicked one
  person per webhook. WF-10 still `bed27da5`.
  WhatsApp / LinkedIn not started.

| Person | person_id | Exec | Telegram | follow_ups | Gmail draft | Path | Attach | Reason |
|---|---|---|---|---|---|---|---|---|
| Deema Alwaala | `2ca63896` | **462459** | 935 | `c789f86c` | `r8067515570626867707` | Extract | 0 | usable |
| Abdalla Elkhouli | `db31bc6e` | **462469** | 936 | `1fbc8a9f` | `r8677868495208793358` | template | 103619 | aaa aaa |
| Ahmad Alnasser | `deafcf1a` | **462472** | 937 | `a9ac18b1` | `r7748022095252994021` | Extract | 0 | usable |
| Ahmed Alkaf | `32c8efee` | **462474** | 938 | `a1b91e19` | `r-836529973338330291` | template | 0 | no transcript |
| Animesh Anand | `9bfa8ce0` | **462475** | 939 | `724f0add` | `r5119167887856017740` | template | 0 | no transcript |
| Faten Matmati | `1831ecd0` | **462476** | 940 | `9309173a` | `r5415257922690620755` | Extract | 0 | usable |
| Ghassan Siyamak | `a602827b` | **462477** | 941 | `83b68f68` | `r-1790470466397325196` | template | 106306 | no transcript |
| Imad Afyouni | `26ed5169` | **462478** | 942 | `44c889ca` | `r434767192073961307` | Extract | 0 | usable |
| Jamal Rafiq | `681d308c` | **462479** | 943 | `adff2e7c` | `r3542818162193356830` | template | 0 | no transcript |
| Khizer Ahmed Siddiqui | `b01f265a` | **462481** | 944 | `d4b7074e` | `r1626157842668145537` | template | 0 | no transcript |
| Muhammad Toheed | `32bac9fc` | **462482** | 945 | `988d4cd2` | `r-6183830881006665318` | template | 0 | no transcript |
| Rashid Mehmood | `9f91fb97` | **462483** | 946 | `c208f7b6` | `r1436963579507133188` | template | 106701 | no transcript |
| Syed Ammad | `40b9bbe4` | **462485** | 947 | `6a7cf7b9` | `r5109628820246424018` | template | 125373 | garbled |
| Soliman A. Alzahrani | `77efedfd` | **462487** | 948 | `245ed4cb` | `r1790556644158495512` | template | 0 | no transcript |
| Tasneem Ibraheim | `541a55ec` | **462488** | 949 | `b2809899` | `r8981891638223927533` | template | 0 | no transcript |

  Skipped by load filter / human dedupe: D-H four,
  DES RAJ, Shahzad, `kacaib.com` typo, Zahir kaacib
  row (same human as live haramain draft), pre-window,
  LNI-prefix, example/invalid. 19 humans, not 23 rows.

- DES RAJ second-touch email. Sent row `4c58b08a` untouched
  (`channel` NULL, so unique index does not apply — no 033).
  Name skip removed for him only. Exec **462598**, Telegram
  950, follow_ups `7f4b0c2f`, Gmail `r-4113403307621163658`,
  photo 83829. WF-10 **`1e4ae9c6`** (rollback `1c1c39f4`).
- WhatsApp/LinkedIn: webhook `channel`, short plain copy,
  no Gmail. Dry run of three; rest stopped.

| Person | channel | Exec | Telegram | follow_ups | Path | chars |
|---|---|---|---|---|---|---|
| Raheel Zaman | whatsapp | **462602** | 951 | `66b1d4a7` | Extract | 172 |
| Ahmed Alkaf | whatsapp | **462603** | 952 | `c9fcd3c7` | template | 150 |
| Vishvajit Pathak | linkedin | **462604** | 953 | `f3962905` | template | 126 |

Those three dry-run rows were **cancelled** before CH2–CH5
regeneration (Alkaf WhatsApp had wrongly `second_touch=true`
because a Gmail draft was treated as a touch).

---

## CH1–CH5 — Phase 10 close (14 Sep)

**CH1.** Previously-emailed people get a second-channel
touch, same as DES RAJ. Shahzad Jameel and Fawaz Al-Eisai
(09-07 row `58ea7ec0`, the one with email + phone) are
on the History load. Shahzad's transcript is factually
wrong ("NetEngine Bus"; he is at VirtueNetz) — name
force to template, Extract never runs. Rana Waleed,
Saad Raja, Ali Abbas, both Aadil Abbasi USA rows, and
Abbod stay excluded.

**CH2.** WhatsApp evidence includes a Meta click-to-chat
link. Context7 was not available in this environment.
Verified against Meta Help Center
https://faq.whatsapp.com/5913398998672934 and
https://faq.whatsapp.com/425247423114725:

- Format: `https://wa.me/<number>?text=<urlencodedtext>`
- Number is full international format. Omit plus, dashes,
  brackets, and leading zeros.
- Use `https://wa.me/1XXXXXXXXXX`. Don't
  `https://wa.me/+001-(XXX)XXXXXXX`.
- Local Saudi numbers (leading 0, 10 digits): drop 0,
  prefix 966. Do not silently rewrite country code 996
  (Kyrgyzstan) to 966.

**CH3.** No stored `linkedin_url` on the LinkedIn-channel
cohort. LinkedIn Help (a563153) documents Connect → Add
a note from a **profile**; there is no documented public
URL that prefills a connection note. `linkedin://profile/[id]`
needs a member id we do not have. `linkedin.com/in/{vanity}`
needs a vanity we do not have. Emit a people-search URL
from name + company, the paste-text below it, and a plain
line that the profile must be found manually.

**CH4.** `second_touch` keys on `follow_ups.draft_state='sent'`
only. A Gmail draft is not a touch. Ahmed Alkaf WhatsApp
regenerated after the fix.

**CH5.** Bios from 033 columns. Prompt does not contain
the bio. Catalog `033_sender_profile_channel_signatures`
(`20260914083604`). 030 still absent.

WF-10 published **`fd8b7f9b`**. 42 kicks, all HTTP 200.
Live counts: 22 email `gmail_draft`, 29 WhatsApp, 11
LinkedIn. Telegram 954–995. Decision 12: none sent.

**Coverage.** In-window humans with an email and no
email draft: **Rana Waleed** only (manual). Zahir
kaacib row `ba037ac0` also has no draft — D-J duplicate
of the haramain row; both addresses already on that
Gmail To:.

**CH4 proof.** Ahmed Alkaf WhatsApp `8138a531` Telegram
959, `second_touch=false` (email is `gmail_draft`, not
`sent`). Shahzad + DES RAJ `second_touch=true`.

**CH2 proof.** Local SA → `966` and drop 0: Khizr
`wa.me/966509609942`, Waleed `966538584129`, Raheel
`966567888578`. Syed Ammad: no link, 996 flag, Telegram
980. Telegram evidence has the full `?text=` prefill.

**CH3.** All LinkedIn notes ≤247 characters including
bio. Search URL + “find manually”. No fake `/in/` links.

Phase 10 is **closed**.

New-row table (prior 20 emails unchanged, Telegram
931–950). `wa.me` shown without `?text=`; prefill is
on Telegram.

| Person | Channel | Path | Reason | Chars | wa.me / why none | LinkedIn search | Photo | Tg |
|---|---|---|---|---|---|---|---|---|
| Fawaz Al-Eisai | email | template | no transcript | 1259 | n/a | n/a | c4f9a0aa…jpg | 955 |
| Shahzad Jameel | email | template | NetEngine Bus forced | 1164 | n/a | n/a | cdf49511…jpg | 954 |
| Abdalla Elkhouli | whatsapp | template | aaa aaa | 237 | https://wa.me/966562284579 | n/a | e26b572f…jpg | 956 |
| Abdullah Ahsan | whatsapp | template | no transcript | 238 | https://wa.me/966547098160 | n/a | 6ea2d374…jpg | 957 |
| Ahmad Alnasser | whatsapp | Extract | usable | 333 | https://wa.me/966541105476 | n/a | - | 958 |
| Ahmed Alkaf | whatsapp | template | no transcript | 235 | https://wa.me/966582887324 | n/a | - | 959 |
| Animesh Anand | whatsapp | template | no transcript | 237 | https://wa.me/918434348504 | n/a | - | 960 |
| Awais Rahat | whatsapp | template | no transcript | 235 | https://wa.me/447545222169 | n/a | - | 961 |
| DES RAJ CHAUHAN | whatsapp | template | no transcript | 250 | https://wa.me/966538714540 | n/a | efece2a9…jpg | 963 |
| Deema Alwaala | whatsapp | Extract | usable | 363 | https://wa.me/966534037303 | n/a | - | 962 |
| Faten Matmati | whatsapp | Extract | usable | 328 | https://wa.me/21629350910 | n/a | - | 964 |
| Fawaz Al-Eisai | whatsapp | template | no transcript | 235 | https://wa.me/966556677268 | n/a | c4f9a0aa…jpg | 965 |
| Fazal (Bahrain) | whatsapp | template | no transcript | 235 | https://wa.me/97336555758 | n/a | - | 966 |
| Ghassan Siyamak | whatsapp | template | no transcript | 237 | https://wa.me/966543334381 | n/a | 697cf050…jpg | 967 |
| Imad Afyouni | whatsapp | Extract | usable | 315 | https://wa.me/971525122455 | n/a | - | 968 |
| Jamal Rafiq | whatsapp | template | no transcript | 235 | https://wa.me/923335684410 | n/a | - | 969 |
| Khizer Ahmed Siddiqui | whatsapp | template | no transcript | 236 | https://wa.me/923324046546 | n/a | - | 970 |
| Khizr Hussain | whatsapp | template | no transcript | 235 | https://wa.me/966509609942 | n/a | - | 971 |
| Muhammad Toheed | whatsapp | template | no transcript | 238 | https://wa.me/923167142536 | n/a | - | 972 |
| Muhammad Zahir | whatsapp | Extract | usable | 334 | https://wa.me/447522192620 | n/a | 96e2bf67…jpg | 973 |
| Omair Shaikh | whatsapp | Extract | usable | 327 | https://wa.me/966582839355 | n/a | 4db135cb…jpg | 974 |
| Raheel Zaman | whatsapp | Extract | usable | 343 | https://wa.me/966567888578 | n/a | 492ef0e6…jpg | 975 |
| Rashid Mehmood | whatsapp | template | no transcript | 236 | https://wa.me/923334002269 | n/a | 2b14354c…jpg | 976 |
| Shahzad Jameel | whatsapp | template | NetEngine Bus forced | 254 | https://wa.me/923028444707 | n/a | cdf49511…jpg | 977 |
| Soliman A. Alzahrani | whatsapp | template | no transcript | 237 | https://wa.me/966591910548 | n/a | - | 978 |
| Sulaiman Asif | whatsapp | Extract | usable | 307 | https://wa.me/923012730261 | n/a | 80372849…jpg | 979 |
| Syed Ammad | whatsapp | template | garbled | 234 | no link: stored 996 is Kyrgyzstan, OCR, do not auto-correct | n/a | 6a4ecbf0…jpg | 980 |
| Tasneem Ibraheim | whatsapp | template | no transcript | 237 | https://wa.me/962788711503 | n/a | - | 981 |
| Waleed Ahmad Dammam | whatsapp | template | no transcript | 236 | https://wa.me/966538584129 | n/a | - | 982 |
| Zahid Latif | whatsapp | template | no transcript | 235 | https://wa.me/923000334560 | n/a | - | 983 |
| Zuhair 100 Ventures Jeddah | whatsapp | template | no transcript | 236 | https://wa.me/966554936765 | n/a | - | 984 |
| Ashraf Abu Elayyan | linkedin | Extract | usable | 247 | n/a | name search | 10fa70f3…jpg | 985 |
| Deshraj Chauhan | linkedin | Extract | usable | 184 | n/a | name+Utopian | - | 986 |
| Hayam A. | linkedin | Extract | usable | 222 | n/a | name search | - | 987 |
| Imad | linkedin | Extract | usable | 208 | n/a | name search | 8bd42dda…jpg | 988 |
| Mohamed Ousmane Fayaz | linkedin | template | no transcript | 139 | n/a | name+BYOC.global | - | 989 |
| Mouaz Abdullah | linkedin | template | no transcript | 137 | n/a | name search | - | 990 |
| Muath Abuhilal | linkedin | Extract | usable | 233 | n/a | name+KFUPM | 858a7cef…jpg | 991 |
| Muhammad Usman Fiaz | linkedin | Extract | usable | 225 | n/a | name+BYOC.global | deff4730…jpg | 992 |
| Syed Sair Ali | linkedin | Extract | usable | 242 | n/a | name+Blinkco.io | - | 993 |
| Vishvajit Pathak | linkedin | template | no transcript | 141 | n/a | name+MarsDevs | b77e443c…jpg | 994 |
| أشرف | linkedin | template | no transcript | 136 | n/a | Arabic name+SEED | - | 995 |
