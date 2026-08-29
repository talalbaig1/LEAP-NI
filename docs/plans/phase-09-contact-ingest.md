# Phase 9 plan — contact and vCard ingest

**Date:** 29 August 2026
**Status:** PLAN ONLY. No PUT. No migration. No code.
**Reversal:** Phase 3 cut contact/vcard ingest (reply-only). Owner
now reverses that cut. Digital cards (Wave and similar) have largely
replaced paper; a shared contact is the primary artifact and the
system currently declines it.

Do not implement from this document.

Rollback if a later packet applies: WF-01 `1d53c03d`, WF-02
`071a4794`, WF-10 current `ab21c10c` (this plan does not touch them).

---

## 1. `message.contact` shape

**Telegram Bot API** (`Contact`, https://core.telegram.org/bots/api#contact):

| Field | Type | Required |
|---|---|---|
| `phone_number` | String | yes |
| `first_name` | String | yes |
| `last_name` | String | optional |
| `user_id` | Integer | optional (Telegram user id) |
| `vcard` | String | optional — additional data as a vCard |

`Message.contact` is optional on Message. When present, the update is
a shared contact, not a document.

**Live executions 256611 and 256687** (cited from session-05 /
`workflows.md`, packet 3.9 / 3.14):

- WF-01. `branch=contact`. Last node `Contact reply sent`.
- Reply: `Contact cards are not supported yet. Send a photo of the
  card or a voice note instead.`
- Nothing stored. No asset. No WF-02 call.

**GET of those executions on 29 Aug 2026 returns 404.** n8n
retention has dropped the run JSON. The surviving record does **not**
include the `contact` object fields. Whether Wave attached
`contact.vcard` on those two shares is **not in the remaining
artefact**.

Live `Classify update` (GET WF-01 `1d53c03d`, 29 Aug):

```
if (msg.contact) {
  base.branch = 'contact';
  return [{ json: base }];
}
```

It tests truthy `msg.contact` and **reads nothing else**. Phone,
name, `user_id`, and `vcard` are discarded on that path today.

Wave-style share: API allows `vcard` (0–2048 bytes on sendContact).
Arrival is optional. Implementers must log the raw `msg.contact`
on the first new share before assuming the field is present.

---

## 2. `.vcf` document shape

**Telegram Bot API** (`Document`): `file_id`, `file_unique_id`,
optional `file_name`, `mime_type`, `file_size`, `thumbnail`.

**Live execution 256753** (packet 3.14, recorded):

- `startedAt` `2026-08-27T10:50:59.832Z`
- Route type named rule `vcard` (index **[9]**)
- Last node `Vcard reply sent`
- Incoming `mime_type` `text/vcard`
- `file_name` ends `.vcf`
- Reply: `Contact files are not supported. Send a photo of the card
  or a voice note instead.`
- No asset. No `card_vision` job. Counts stayed 55 / 59 / 61.

**`file_size` was not written into the session record.** GET 256753
is now 404. Size must be taken from the next live `.vcf` (Document
`file_size`, optional).

Live Classify (same GET): vcard **before** `branch='document'`:

```
mime === 'text/vcard' || mime === 'text/x-vcard' || fname.slice(-4) === '.vcf'
```

Then `branch='vcard'` and **return without** `file_id` /
`file_unique_id` / `mime_type`. Same discard pattern as contact.

---

## 3. Which WF-01 nodes change

Today Route type:

| i | node |
|---|---|
| [6] | Contact unsupported reply → Send contact reply → Contact reply sent |
| [9] | Vcard unsupported reply → Send vcard reply → Vcard reply sent |

Those two **terminal decline replies** become ingest entry points.

### LOUD: work OUTSIDE those two branches

**Yes. This is not a two-node swap.** Risk is the same class as
packet 3.9 (two ACTIVE workflows + schema).

Must also move:

1. **Classify update** — copy `msg.contact` fields and, for vcard,
   `file_id` / `file_unique_id` / `mime_type` / `file_name` /
   `file_size`. Today those are dropped. Without this, WF-02 cannot
   replay.
2. **Call WF-02** (or a new action) from those branches — today
   they never leave WF-01.
3. **WF-02** — new kind / `resolve_target` path, storage of raw
   payload, enqueue that is **not** `card_vision` on a text file
   (live enqueue is still audio→transcription else `card_vision`).
4. **Migration 029** — `people.source_type` values.
5. **WF-05** already auto-links on email; no matcher rewrite
   required if structured_output is shaped like a card extract.
6. **WF-10 / followup block** — see §9.

Do not pretend [6] and [9] text changes are the whole apply.

---

## 4. Does a shared contact produce an ASSET?

**`message.contact` has no binary.** No `file_id`. There is nothing
to PUT to `lni-assets` unless `contact.vcard` is present as text.

Recommended store (replayable):

| Kind | Asset row? | Raw retain |
|---|---|---|
| Shared contact, no `vcard` | **No.** Capture + `extraction_runs` only | Full `msg.contact` JSON in `extraction_runs.raw_vision_output` (or a jsonb column). Phone / names as structured_output. |
| Shared contact with `vcard` | Optional text object: `{owner_id}/{capture_id}/{asset_id}.vcf` | **Verbatim vCard string** in that object **and** in `extraction_runs.raw_transcript`. |
| `.vcf` document | **Yes.** Download via getFile like other documents. `kind` `document` or new `vcard`. mime `text/vcard`. | File bytes = vCard text, retained verbatim. Also copy into `extraction_runs.raw_transcript`. |

Silence-if-storage-fails still applies to the `.vcf` download path
(`prd.md` §5). A contact with no file has no storage fail mode;
the jsonb write is the receipt gate.

---

## 5. `people.source_type`

Live check (`004_entities`):

`card | voice_note | typed_note | photo | enrichment` or NULL.

Live catalog last migration: **028_captures_followup_mode**.
Next number is **029**. Phase 6 `027_embeddings` was never applied
(027/028 were used for follow_ups). **Embeddings moves to 030.**

Recommend 029 adds:

- `shared_contact` — Telegram `message.contact`
- `vcard` — `.vcf` document

No backfill. Existing rows stay `card` / `photo` / NULL. They were
not ingested from these branches. Default stays NULL. Do not rewrite
`9489be75` or any live person.

---

## 6. Extraction: WF-04 or straight to WF-05?

**Recommend: skip WF-04. Parse vCard / contact fields in WF-02 (or a
small WF-10-free Code node), write `extraction_runs.structured_output`
in the WF-04 person shape, enqueue `entity_resolution` only.**

Reason from live JSON, not intent:

- WF-04 is vision on an image binary. A vCard is text.
- WF-02 enqueue with no mime filter would send `card_vision` at a
  `.vcf` and fail three times (`workflows.md` packet 3.13). That is
  why decline exists today.
- Structured FN / EMAIL / TEL / ORG is already the extract.

Do not call Whisper. Do not call GPT vision on the vcf.

---

## 7. Entity resolution (live WF-05)

Auto-link **only** on exact `people.email_normalized` or exact
`people.linkedin_url_normalized` where `linkedin_source='card'`.
Name similarity **never** merges (`workflows.md` WF-05 §4).

A vCard with EMAIL → `email_normalized` → **exact-email auto-link
fires** if that email already exists.

No email: no auto-link. If another owner person has a
trigram-similar `full_name`, write `entity_candidates`
(`reasons={name_trgm}`). New silent person row if no key. Same as
a card with no email.

---

## 8. What the owner sees

Photo path today: resolve often returns **empty** `reply_text`
unless adopted (`Compose resolve reply`). Proof of life is `/done`:
`✓ Capture #N saved · K items` (or batch `N cards received ·
processing`).

Recommend a **short receipt, different from a card**:

- Shared contact: `Contact saved · #N` (name if present).
- `.vcf`: `Contact file saved · #N`.

Not a review card. Not the decline text. If the jsonb/file write
fails: **no receipt** (same rule as storage fail).

---

## 9. Contact inside a `/followup` block

Live followup open text: `Follow-up #N open. Photo and voice stay
in this block. /done drafts.`

Recommend: a contact/vcard in an open followup capture **stays in
that block** (same as photo). Attach the parsed person to that
capture’s interaction. Do not open a second capture. Do not start
a draft until `/done`. If the vCard email matches the draft target,
use it; if it is a different person, keep it as an extra interaction
on the same followup capture and say so on `/done`.

Do not treat a contact as a callback.

---

## 10. Rollback

| Workflow | Version to restore |
|---|---|
| WF-01 | `1d53c03d-4e8f-42a1-9f84-f6f0b97aa240` |
| WF-02 | `071a4794-4d2f-4c05-ac2b-9f482efde605` |
| WF-10 | current at plan time `ab21c10c-6d04-44eb-a97b-c4409ec38c90` |

This plan applies none of those PUTs.

---

## 11. Read-back checklist (when a later packet applies)

1. GET WF-01 name `LNI WF-01…` then versionId. Classify copies
   contact/vcard fields. Route [6] and [9] no longer send the
   decline text.
2. GET WF-02 name. Enqueue for vcard is **not** `card_vision`.
3. GET 029 applied. `people_source_type_check` includes
   `shared_contact` and `vcard`. Embeddings still absent (030).
4. One shared contact execution: `branch=contact`, capture row,
   `extraction_runs` has raw contact JSON, receipt sent, no
   vision job.
5. One `.vcf`: `branch=vcard`, asset stored, `raw_transcript`
   verbatim, mime `text/vcard` or `text/x-vcard`, no
   `card_vision`.
6. vCard with known email: WF-05 auto-link, no second person.
7. vCard with no email: no auto-merge; candidate if name-similar.
8. Contact inside followup: same `capture_id`, no nested capture.
9. WF-01 still `availableInMCP: true`. No `$env`. Leap-NI creds.
10. GET WF-10 unchanged if that packet did not authorize a PUT.

---

## 12. Disagreements

1. **Wave `vcard` on 256611 / 256687 is unknown.** Executions are
   404. Do not design as if the optional field was observed.
   First new share must be logged before the store shape is frozen.
2. **`.vcf` `file_size` was never recorded.** Do not invent it.
3. **Classify discard is the real cut**, not the reply text. A
   packet that only edits [6]/[9] strings will ingest nothing.
4. **Do not send vCards through WF-04.** Vision-on-text is the
   failure 3.13 already measured.
5. **`source_type='card'` must not be reused** for a Telegram
   contact. Provenance is the point of the column (`architecture.md`
   § provenance). New values, no backfill.
6. Packet 8.6 note (not this plan): the model often returns
   `unmatched_requests=[]` on a named-absent file (277990, 277997,
   278000). That is a model miss, not a reason to bring the regex
   back. When the model does return a phrase (278004
   `Q3-budget.xlsx`), Parse passes it through.
