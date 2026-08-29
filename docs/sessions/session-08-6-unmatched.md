# Session 08.6 — unmatched regex removed

**Date:** 29 August 2026
**Packet:** 8.6. **WF-10 only.** WF-01 stayed `1d53c03d`.
**Rollback:** `2b6580b8-1c1a-43a1-860a-6c39560a1eab`.
**Live WF-10:** `ab21c10c-6d04-44eb-a97b-c4409ec38c90` (142). One PUT.

Agree with the architect. Do not keep the fallback.

- **276473** — model `selected_asset_ids=[7799b7d3…]`,
  `unmatched_requests=[]`. Regex captured `photo`. Defect.
- **274108** — model itself returned
  `unmatched_requests=["the spreadsheet from yesterday"]`,
  `selected_asset_ids=[]`. Fallback not required.
- No execution found where the regex was the only source of a
  genuine miss.

Absolute rule in Parse extract: drop unmatched phrases that are a
selected filename/id, or a bare photo/image word when an asset was
selected. That is not an exclusion-list patch of the old regex.

### Proofs (TEST driver)

| # | Result | Evidence |
|---|---|---|
| Attach the photo. | PASS | **277987**. Attachment `8cfa042b-…jpg`. `unmatched=[]`. No `Could not match`. |
| Genuinely absent | PASS | **278004**. Model `unmatched_requests=["Q3-budget.xlsx"]`. Card: `Attachments: (none)` + `Could not match: Q3-budget.xlsx`. No selected asset. |

GET WF-01 `1d53c03d` after PUT. TEST driver off. Artefacts deleted.
Counts: 72 / 17 / 87 / 24 / 27 / 78 / 55. `5df341f8` kept.
