# Session 08 overnight — PACKET 7.16

**When:** 28 Aug 2026 21:00–21:35Z (00:00–00:35 Riyadh). Owner asleep.
**Branch:** `cursor/phase-07-16-apply-ce36`  PR **#55** (do not merge).
**R3 evidence `5df341f8`:** still `awaiting_confirm` / `open`. Untouched.

**Verdict:** `/followup` as a capture works on WF-02 + WF-10. It is **not proven on the live Telegram bot tonight**, so it is **not Monday-floor-ready**. Phone `/followup` *should* work (Telegram Trigger is not the broken test ingest). Photo/voice in the block were proven only by copying stored files, not by a real Telegram update.

---

## What was applied

C1–C4 written into `docs/plans/phase-07-15-followup-as-capture.md` first, then:

- Migration **028** `captures.capture_mode='followup'` + `follow_ups.capture_id`
- Embeddings catalog moved to **029** (027 in live DB is already `027_follow_ups_brief`)
- WF-02 / WF-10 graphs for followup-as-capture
- WF-01 **one PUT** (R4), then no second PUT

---

## VersionIds (live now)

| WF | id | versionId now | nodes | rollback |
|---|---|---|---|---|
| WF-01 | `ZMYx19qEr72mJoCX` | **`1d53c03d-4e8f-42a1-9f84-f6f0b97aa240`** | 131 active | **`864bcb8b-8ac1-4fb6-a577-8772ff5e22bd`** (128). Saved GET: `/tmp/lni716/WF01-rollback-864bcb8b.json` |
| WF-02 | `BV0nukrQdOpDCPe4` | **`071a4794-4d2f-4c05-ac2b-9f482efde605`** | 76 active | pre-7.16 `8d56f518-…`; 7.16 graph before enqueue guard `b5c6bbf2-…` |
| WF-10 | `D9PRjbZMQxe9ESVW` | **`fde7f832-63f8-45bb-8f2f-624b081be8b7`** | 123 active | pre-7.16 `f1013395-…`; first 7.16 `12881a77-…` |
| WF-03 | `k0bPD3GJBNN2EHDB` | `852f300b-…` unchanged | 38 | — |
| TEST driver | `iqAx0KwCsTbb32BY` | `626f2957-…` | 9 | **deactivated** (had a SQL op on an unauthenticated webhook) |

WF-01 PUT was once. Graph read-back passed. `versionId` unchanged through the whole matrix (invariant F).

---

## How tests ran (no phone)

`LNI-TEST-7.16-driver` posted to WF-02 / WF-10. Photos and voice were **new asset rows** copying `storage_path` from already-stored files (R3 rows never updated). After `/done`, the harness always called WF-10 with `capture_id`.

**WF-01 ingest is blocked for us:** production Telegram webhook returns 403 (secret not in workflow JSON). The one PUT added `Driver ingest` (`lni-716-ingest`) which wraps `{body: update}`, so Allowlist sees no `from.id` (exec **273668**). R4 forbids a second PUT to unwrap it.

---

## Scenario matrix

Latest result wins where a row was retried.

| # | Result | WF-10 (or WF-02) exec | What we saw |
|---|---|---|---|
| 1 | **PASS** | 273871 | Photo+voice. Card To `ahmedfouad@jccs.com.sa`, photo attached, **10 September 9 a.m. in the body**. Cap `3d41a503` #96 |
| 2 | **FAIL** | 273859 | Voice only. Stored Fouad audio says “Ahmed Al Fuad” → **picker**, not a card. Attachments-none unproven on `/done`. Cap `7c69aa58` #95 |
| 3 | **PASS** | 273847 | Exact C3 sentence. Draft `bf75d740` `draft_state=draft`, no Send buttons. Cap `908c48c1` #94 |
| 4 | **PASS** | 273792 | `Follow-up was empty. Nothing drafted.` No follow_ups row. Cap `b1a37249` #90 |
| 5 | **PASS** | 273884 | Two stored voices transcribed into the brief (order kept). Card. Cap `accfae87` #97 |
| 6 | **PASS** | 273901 | Four photos, three on the card, `Omitted (too large):` fourth filename. Cap `058c7088` #98 |
| 7 | **PASS** | WF-02 close-and-process | Standard #92 `84981969` got `card_vision` job `d2524a64` **running** then deleted. Follow-up #93 opened. |
| 8 | **PASS** | WF-02 | `Follow-up cannot start while /batch is on. /done first.` Batch then reset. |
| 9 | **PASS** | WF-02 | `/new` → `Follow-up #91 is open. /done to draft first.` (C4) |
| 10 | **PASS** (dispatch) | WF-02 **274072** → WF-10 **274073** | Sweep closed #110, `Call WF-10 sweep` ran (`closed_ids=[]`, `followup_ids=[70cdb25c]`). Brief **was written** (`1ea2c7b4`). Exec then **errored** `Draft insert returned no row` (second insert after the brief). Dispatch proven; confirm-card on sweep is not clean. |
| 11 | **PASS** | 273914 | Typed email, no picker, To Fouad. Cap `e9333d77` #99 |
| 12 | **PASS** | 273925 then tap 273928 | Picker → tap Eltohfa `9489be75` (person row not mutated). Brief survived; date in body. Cap `6e00bc1d` #100 |
| 13 | **PASS** | 273939 | `No person matches that note.` Photo still `stored`. Cap `555a3929` #101 |
| 14 | **PASS** | 273949 | `Ahmed Al-Touhaf has no email address. Send /followup with an email to draft one.` Cap `76ef0717` #102 |
| 15 | **PASS** (retry) | 274108 | `Could not match: the spreadsheet from yesterday` + draft still offered. First try 273960 missed unmatched (LLM). Heuristic added. Cap retry `cbba51b3` #111 |
| 16 | **PASS** | 273975 | Two asset copies, same sha256 → **one** attachment on the card. Cap `60dfef6e` #104 |
| 17 | **PASS** | 274001 send | **One Gmail** to `talalbaig@gmail.com`. `Sent to talalbaig@gmail.com. … Files: 1`. `gmail_message_id=1a04a45dda61bd07`. Draft `aad3457a`. R1: 1 of 3. |
| 18 | **PASS** | 274008 | Same id again → `Already sent.` Same gmail id. Gmail did not run. |
| 19 | **PASS** | 273987 / 273989 | `Cancelled.` `cancelled/cancelled`. No send. `490a6aca` |
| 20 | **PASS** | 274019/021/023 error | WF-10 `{error: invalid input syntax for type uuid}`. Capture #107 already `processing`, photo still `stored`. WF-01 fail-line untested (no ingest). |
| 21 | **PASS** | 274034 | Arabic transcript stored (`مرحباً، ألتقيت بأحمد التوحف…`). Picker attempted. Cap `7cadef03` #108 |
| 22 | **PASS** (retry) | 274118 | `reply_text_2` fired because brief > 3800 (extract still summarised the email). Cap `7f08099e` #112 |

**Regression after WF-01 PUT (R4):** **BLOCKED.** Cannot reach `Send ask/digest/flag/command reply` without the phone or a second PUT. Locked compare execs unchanged: `/ask` 255773/255781/255786/255800/255806; `/flag` 265855/265857/265540; digest WF-07 264951/260806.

Driver one-scenario prove before the matrix: empty block #89 then #90 (273767 / 273792).

---

## Invariants (after every scenario, final 21:32Z)

| | Check | Result |
|---|---|---|
| A | `follow_ups` sent == audit `followup_sent` == 2 + R1 sends | **3 = 3 = 2+1** |
| B | no `open` capture with `last_activity` older than 10 min | **0** (except the intentional scenario-10 wait, then sweep closed it) |
| C | no asset `upload_status != stored` | **0** |
| D | test `processing_jobs` terminal or deleted | queued/running on tonight’s captures **deleted**; leftover `needs_review`/`succeeded` left as terminal |
| E | audit `followup_*` has no email/body/transcript | **PASS** (`after` is person_id, follow_up_id, attachment_count, gmail_message_id) |
| F | WF-01 versionId | **`1d53c03d-…` unchanged** |
| G | `bot_state` one row, owner | **PASS** `a79b744e-…` |

---

## Apollo credits

| | spent |
|---|---|
| Start (~21:00Z) | **15** |
| End (21:32Z) | **15** |
| Delta | **0** (stop line is >5) |

Enrichment job `a07939cf` (capture #99, queued) **deleted** before WF-06’s next tick.

---

## Cleanup

Manifest: `docs/sessions/session-08-cleanup-manifest.md` (written as artefacts were created).

**Deleted / cancelled**

- follow_ups `5ea0a8ea`, `becb0e07` (leftovers, not R3) → `cancelled`
- All matrix drafts except the one real send (`aad3457a` **sent**) and locked `5df341f8`
- Queued/running jobs on tonight’s captures, including 12 followup `card_vision`/`transcription` rows and 1 enrichment

**Left in DB (closed, not R3)**

- Captures #88–#112 `processing` + copied asset rows (same `storage_path` as originals, new ids / `t716-…` unique ids). Not removed: deleting captures would need a cascade decision.
- `88026126` `failed` (pre-packet, left)

**R3 untouched:** captures listed in the packet; jobs `1564abc3` `f6a1e703`; ledger `73fc2831`; people `ec5dc966` `9489be75`; follow_ups `5df341f8`.

TEST driver **deactivated**.

---

## Stopped / morning decisions

1. **WF-01 second PUT?** Driver ingest wraps `{body}`. Allowlist needs `$json.body.message.from.id` (Telegram Trigger stays direct). Without that (or the Telegram secret header), we cannot run the R4 regression or drive media through Duplicate check. **Decision: allow a surgical unwrap PUT, or give the webhook secret.**
2. **Scenario 2.** Stored Fouad audio is not a unique-email speaker. `/done` showed a picker, not a card. **Decision: record a unique-email voice, or accept picker-then-card as the voice-only path.**
3. **Sweep 274073.** Dispatch works; after writing the brief, `Insert draft` misses and StopAndError fires. Sweep `wait: false` so WF-02 still shows dispatched. **Decision: on sweep, stop after Insert brief (draft only) — do not continue into confirm insert.**
4. **Followup captures got WF-03 jobs** at 21:30:00 (before the 21:30:02 sweep). That is the duplicate-person path we were told not to use. Enqueue SQL now has `capture_mode IS DISTINCT FROM 'followup'` (`071a4794`). **Decision: confirm that guard is enough, or also make WF-03 ignore `followup` captures.**
5. Do **not** run tests 06:50–07:10 Riyadh. 07:00 briefing left untouched.

No other decision was invented. Session did not stop early on R1–R6.

---

## R1 Gmail

Allowed: `talalbaig@gmail.com` only, max 3. **Used 1.** Subject from extract, 1 file. Second send on the same id was a no-op.
