# Session 08 overnight — cleanup manifest

Record artefacts **as they are created**. Delete at end of matrix.
Never touch R3 locked rows.

Apollo credits at start (28 Aug 2026 ~21:00Z): **15** spent all-time
(`credit_ledger.provider='apollo'`, `sum(credits_spent)`).
Stop if delta > 5.

`follow_ups.draft_state='sent'` at start: **2**.
`audit_log.action='followup_sent'` at start: **2**.

Locked (do not mutate): captures #9 #62 #63 #66 #68 #69 #73 #75 #82
#83 #85 #87; jobs `1564abc3` `f6a1e703`; credit_ledger `73fc2831`;
people `ec5dc966` `9489be75`; follow_ups `5df341f8` (leave
`awaiting_confirm`).

| when_utc | kind | id | scenario | deleted |
|---|---|---|---|---|
| 2026-08-28T21:17:42Z | follow_ups | `5ea0a8ea-2969-4457-896a-f3e3b47c4d78` | leftover empty-block miss | cancelled (not R3) |
| 2026-08-28T19:21:23Z | follow_ups | `becb0e07-686a-481e-b50c-bb81198db9e9` | pre-packet awaiting_voice | cancelled (not R3) |
| 2026-08-28T21:17:16Z | capture | `2973ce8d-42c1-4df0-94f3-5e1061fb825a` #88 | smoke followup | closed, no draft |
| 2026-08-28T21:25:47Z | capture | `b1a37249-f272-45ef-ae3a-c198c170632a` | open | pending | Follow-up #90 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:25:56Z | capture | `eb75def2-1886-4dbf-b159-467d27ee89a4` | open | pending | Follow-up #91 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:26:00Z | capture | `84981969-98b6-42ea-bd4b-c5329c99f7c5` | 7 | pending | standard before followup
| 2026-08-28T21:26:01Z | asset | `ad48c6a7-c53c-41cf-895d-30c931599c16` | 7 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:26:09Z | capture | `908c48c1-ffca-4b61-b7b4-8174e4695ebf` | open | pending | Follow-up #94 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:26:10Z | asset | `5781ec8a-24ea-48b9-9ba4-627c83922c82` | 3 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:26:14Z | follow_ups | `bf75d740-121d-43ef-b150-33498c59ac2b` | 3 | pending | cancelled
| 2026-08-28T21:26:16Z | capture | `7c69aa58-d7bb-41da-9dc7-5e01010caefd` | open | pending | Follow-up #95 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:26:16Z | asset | `bdffaff7-742e-4ed8-b290-a40d81727815` | 2 | pending | copy of ab8a7a7e-8044-46e2-9fbc-0c212fc8eeb4
| 2026-08-28T21:26:24Z | follow_ups | `0450f374-00b9-4430-858b-9bdd9ab42173` | 2 | pending | cancelled
| 2026-08-28T21:26:25Z | capture | `3d41a503-288b-4ddf-b692-952987a4adfc` | open | pending | Follow-up #96 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:26:25Z | asset | `53276afc-3ec0-4701-b202-ede24c72e7ff` | 1 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:26:26Z | asset | `6578e61f-1913-4761-879c-5c344ca035f0` | 1 | pending | copy of ab8a7a7e-8044-46e2-9fbc-0c212fc8eeb4
| 2026-08-28T21:26:35Z | follow_ups | `13896953-b1ab-4e72-a01b-dc14d392103b` | 1 | pending | cancelled
| 2026-08-28T21:26:36Z | capture | `accfae87-9b28-46d2-b318-8585a5b528b6` | open | pending | Follow-up #97 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:26:37Z | asset | `018c313d-5021-4ee0-a8de-1fd7ea2fe446` | 5 | pending | copy of ab8a7a7e-8044-46e2-9fbc-0c212fc8eeb4
| 2026-08-28T21:26:37Z | asset | `e6b3d620-6c71-4067-90dd-b1346a17ef48` | 5 | pending | copy of ab1849f8-ecf4-423c-9a12-1ec6ae77983b
| 2026-08-28T21:26:48Z | follow_ups | `ba973835-065b-45eb-a298-4bb9a331ab08` | 5 | pending | cancelled
| 2026-08-28T21:26:49Z | capture | `058c7088-9228-4ec3-87a1-90e79f0b880d` | open | pending | Follow-up #98 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:26:50Z | asset | `11ebeb42-c49c-487a-a5e5-dd0cfbdd6887` | 6 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:26:50Z | asset | `42ab0ba0-608a-449f-9034-804535058f43` | 6 | pending | copy of 74937d60-7971-4c5a-94e6-8f2aeabac2ce
| 2026-08-28T21:26:51Z | asset | `2f641d91-79a7-4430-9d52-9fa6b543af42` | 6 | pending | copy of 60574f89-617d-4f40-820f-0ff1b3d4a665
| 2026-08-28T21:26:51Z | asset | `7a694675-032b-4b75-a61a-4399a3b1df6a` | 6 | pending | copy of 0120a967-00f8-462a-90f7-2703e7805eed
| 2026-08-28T21:26:59Z | follow_ups | `ef1a608a-3802-4da7-94a3-36d2f8f9d751` | 6 | pending | cancelled
| 2026-08-28T21:27:01Z | capture | `e9333d77-4441-4e35-9592-d7f1a5c6d805` | open | pending | Follow-up #99 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:01Z | asset | `06c6a71b-ada8-4f44-9798-2a79ffba4d39` | 11 | pending | copy of ab8a7a7e-8044-46e2-9fbc-0c212fc8eeb4
| 2026-08-28T21:27:10Z | follow_ups | `c1e4a636-0eab-4484-9014-ac3d724da7c4` | 11 | pending | cancelled
| 2026-08-28T21:27:11Z | capture | `6e00bc1d-af2a-446c-9c9c-2cf1c08a9cf6` | open | pending | Follow-up #100 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:11Z | asset | `257a4851-950a-42b5-a84a-f2e92858c929` | 12 | pending | copy of ab8a7a7e-8044-46e2-9fbc-0c212fc8eeb4
| 2026-08-28T21:27:19Z | follow_ups | `9bfec681-6562-4bdc-b16e-587bcfd4d066` | 12 | pending | cancelled
| 2026-08-28T21:27:22Z | capture | `555a3929-1119-4fb9-a581-d76d4651f959` | open | pending | Follow-up #101 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:22Z | asset | `89a75f53-ec9d-42a2-812f-828c978362e4` | 13 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:27:25Z | follow_ups | `d82b485e-fb9b-42b1-bdba-5cda141d0c80` | 13 | pending | cancelled
| 2026-08-28T21:27:28Z | capture | `76ef0717-a2da-4af6-89b2-5f5b3e158a79` | open | pending | Follow-up #102 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:31Z | follow_ups | `3c18e8e6-46d2-490a-a832-9a32ecc39bd6` | 14 | pending | cancelled
| 2026-08-28T21:27:33Z | capture | `b65de818-5b9b-4c97-9f04-15461c988ade` | open | pending | Follow-up #103 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:34Z | asset | `22dce777-e712-42fc-868d-2ddb5f3f6e1b` | 15 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:27:42Z | follow_ups | `452a0e91-2458-45a2-a67d-393446238c20` | 15 | pending | cancelled
| 2026-08-28T21:27:43Z | capture | `60dfef6e-9ad6-49a4-93f7-fe56bc1f8ed6` | open | pending | Follow-up #104 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:44Z | asset | `bad537ae-fa75-4e24-a0b2-34695c97fbc1` | 16 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:27:44Z | asset | `ec23b5f8-b856-499c-94c7-81fd2f2d65be` | 16 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:27:50Z | follow_ups | `d720def9-ecdf-4ac4-a288-ca31ca38d1e7` | 16 | pending | cancelled
| 2026-08-28T21:27:52Z | capture | `af26c383-8056-4b54-8140-db4340b15f16` | open | pending | Follow-up #105 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:27:52Z | asset | `05b20ffd-b521-42ba-b877-b331762ed743` | 19 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:28:00Z | capture | `af443470-950c-4073-ac40-ab713bf0fd3f` | open | pending | Follow-up #106 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:28:01Z | asset | `72c85afb-e961-4a4a-8184-6314f1110996` | 17 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:28:13Z | capture | `4c564190-12b0-493a-9f94-39bbed0e92b4` | open | pending | Follow-up #107 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:28:14Z | asset | `4e9737e1-0c68-4695-b0d0-d20e5f0de332` | 20 | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:28:26Z | capture | `7cadef03-c0a8-44cc-a273-46aae2595726` | open | pending | Follow-up #108 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:28:27Z | asset | `7aa9074e-4b31-40cc-9ae4-ad86e25b7912` | 21 | pending | copy of f88d975b-f549-49b2-923b-d8862aa97c5f
| 2026-08-28T21:28:34Z | follow_ups | `1e07af65-d51a-4dd4-8f32-04b14d16e234` | 21 | pending | cancelled
| 2026-08-28T21:28:35Z | capture | `fdbabb05-87e2-47f4-84e0-421208a83a8e` | open | pending | Follow-up #109 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:28:42Z | follow_ups | `590c96f1-0c86-40fe-a8ed-b36c8cf27414` | 22 | pending | cancelled
| 2026-08-28T21:28:44Z | capture | `70cdb25c-7724-4a2b-a7f7-ad71deccde57` | open | pending | Follow-up #110 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:28:44Z | asset | `176ca456-9d35-4f28-9944-4b49674cc5c2` | 10 | pending | copy of ab8a7a7e-8044-46e2-9fbc-0c212fc8eeb4
| 2026-08-28T21:30:09Z | follow_ups | `1ea2c7b4-1f20-47fa-a5a5-fe3ea5fe9993` | 10 | pending | cancelled
| 2026-08-28T21:32:12Z | capture | `cbba51b3-2621-40c2-bdde-7ab6f56e89e6` | open | pending | Follow-up #111 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:32:13Z | asset | `768a19b6-74ed-4f9d-ad63-78431f615c47` | 15-retry | pending | copy of 8cfa042b-fbe6-4928-ba00-494d36d6d093
| 2026-08-28T21:32:19Z | follow_ups | `7a46722f-5da5-4c7f-b743-ea53293dd956` | 15-retry | pending | cancelled
| 2026-08-28T21:32:22Z | capture | `7f08099e-6903-42f2-8a85-52859006b15c` | open | pending | Follow-up #112 open. Photo and voice stay in this block. /done drafts.
| 2026-08-28T21:32:28Z | follow_ups | `6248069c-5b4b-4b2e-bcd7-3bf8cbba794e` | 22-retry | pending | cancelled |

End of matrix (21:33Z):

- **Cancelled:** every test `follow_ups` row except sent `aad3457a` and locked `5df341f8`.
- **Deleted:** queued/running `processing_jobs` on tonight’s captures (including enrichment `a07939cf` on #99).
- **Not deleted:** closed test captures #88–#112 and copied `assets` rows (new ids, copied `storage_path` only). Needs a cascade decision.
- TEST driver `iqAx0KwCsTbb32BY` **deactivated**.
