# Session 08.3 — phantom Ahmed consolidation

**Date:** 29 August 2026
**Packet:** 8.3. Owner-authorised. **Data only. No workflow. No PUT.**
**Do not merge** PRs #54–#58.
**Do not touch** `5df341f8`. Captures #73 #82 #83 #85 #86 and their assets kept.

Keeper `9489be75` Ahmed Eltohfa (`ahmed.eltohfa@veeam.com`, card
capture #75). Fields not altered: name, email, title
`Territory Manager` unchanged.

Merged then deleted (five):

| id | name |
|---|---|
| `55ab6b1a-6ade-4da6-b360-30f3d902fad3` | Ahmed Al-Touhaf |
| `e84189e6-f565-4e0b-9a25-9a5f214e3b69` | Ahmed Tufa |
| `afc28fd8-785d-44b9-a70f-b6b3ec717a5c` | Ahmed Al Tofa |
| `66b7280a-5d98-415b-9dc9-3c3a12b9cf35` | Ahmed Al Tohfa |
| `73996fe0-3ef5-461c-acf8-8dbe90d1098e` | Ahmad |

Repointed: 5 `interactions` (captures #73 #82 #83 #85 #86) and 1
cancelled `follow_ups` (`83201e2b`) onto `9489be75`.

Also deleted phantom `person_companies` `a5849b85` (same
`company_id` as the keeper's existing Veeam row). Required to
delete the person; keeper company row not touched.

Five `entity_candidates` rows, `decision='accepted'`,
`reasons` = owner-confirmed phonetic merge from voice transcripts
into `9489be75`. Ids: `242df639`, `7a505f62`, `73ea9f3b`,
`6dfe9439`, `927f8b05`.

| metric | before | after |
|---|---|---|
| people | 29 | 24 |
| keeper interactions | 1 | 6 |
| keeper follow_ups | 9 | 10 |
| captures #73 #82 #83 #85 #86 | present | present (assets 1/2/1/2/1) |

### /ask-equivalent (trigram ≥ 0.4 on `Ahmed`)

Before: five Eltohfa phonetics plus Eltohfa plus Basawten
(Ahmed Tufa 0.545, Al Tofa 0.462, Al Tohfa 0.429, Eltohfa 0.429,
Basawten 0.400, Al-Touhaf 0.400; Ahmad 0.333 below the gate).

After:

```
Ahmed Eltohfa     0.429  9489be75  ahmed.eltohfa@veeam.com
AHMED BASAWTEN    0.400  c8d3a819  a.basawten@future-projects.net
```

One Eltohfa where five variants were. Basawten is a different person.
