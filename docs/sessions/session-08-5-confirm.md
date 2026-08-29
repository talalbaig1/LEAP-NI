# Session 08.5 — confirm card correctness

**Date:** 29 August 2026
**Packet:** 8.5. **WF-10 only.** WF-01 stayed `1d53c03d`.
**Do not merge** PRs #54–#58.
**Rollback:** `b9a5a890-7422-4537-92e8-42bfb0baf3cc`.
**Live WF-10:** `2b6580b8-1c1a-43a1-860a-6c39560a1eab` (142, active). One PUT.

---

## A. Cause (no fix)

Owner card (Telegram from packet 8.2 unique-email confirm):
exec **276473**, 2026-08-29T02:24:17.867Z, success.

Showed both:

```
Attachments: 8cfa042b-fbe6-4928-ba00-494d36d6d093-AQADqxFrG_nwkVB-.jpg
Could not match: photo
```

### Extract draft output (verbatim)

```
selected_asset_ids: ["7799b7d3-4573-490b-a263-eda179dd392c"]
unmatched_requests: []
```

`send_what` was `"the photo"`. Full extract text object:

```json
{
  "recipient_ref": "ahmed.eltohfa@veeam.com",
  "agreed": "",
  "send_what": "the photo",
  "deadline": "",
  "subject": "Follow-Up from Leap Meeting",
  "body": "Hi Ahmed,\n\nI hope this message finds you well. It was great meeting you at Leap. I wanted to follow up regarding our discussion and share the photo we took together.\n\nLooking forward to staying in touch!\n\nBest regards,\nTalal",
  "selected_asset_ids": ["7799b7d3-4573-490b-a263-eda179dd392c"],
  "unmatched_requests": []
}
```

### candidate_text the model saw

```
id=7799b7d3-4573-490b-a263-eda179dd392c kind=photo filename=8cfa042b-fbe6-4928-ba00-494d36d6d093-AQADqxFrG_nwkVB-.jpg capture_no=116 created_at=2026-08-29T02:24:17.318Z size_bytes=82567 source=in_block
```

### Which happened

The model selected the candidate and left `unmatched_requests` **empty**.
**Parse extract** then populated unmatched.

Brief (`Resolve brief`): `Email ahmed.eltohfa@veeam.com. Met at Leap. Meeting 10 September 9am. Attach the photo.`

Parse extract, only when unmatched is empty:

```
briefTxt.match(/attach(?:ing)?\s+(?:the\s+)?([^\n.]+)/i)
```

That match consumes optional `the `, so the capture is `photo`. The
exclusion list is `this photo|these photos|the photo|a photo|…` —
bare `photo` is not excluded. Parse pushes `"photo"` onto
`unmatched_requests`. Compose confirm prints both the attached
filename and `Could not match: photo`.

Not fixed in this PUT.

---

## B. Card order (PUT)

Restore owner-read order:

```
Follow-up draft
To: …
CC: …
Subject: …

<body>

Attachments: …
Could not match: …    # only when non-empty
Omitted (too large): … # only when a size drop happened
```

GET Compose confirm after PUT contains `head` then `body` then `foot`.
WF-01 still `1d53c03d`.
