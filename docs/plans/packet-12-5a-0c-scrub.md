# Packet 12.5a-0c — history scrub plan

**Status:** REPORT ONLY. Do not run `git-filter-repo`. Do not
force-push. Architect reads the replacement map first.

The literal → token table is **not** in this file. Putting it
here would index every leak. Live values: gitignored
`docs/scrub-map.local.md` and `docs/environment.local.md`.
Token names are below so documents stay coherent after rewrite.

## Tokens (stable across all history)

| Class | Token |
|---|---|
| Owner uuid | `<OWNER_ID>` |
| Platform owner uuid | `<PLATFORM_OWNER_ID>` |
| Test tenant uuid | `<TEST_TENANT_ID>` |
| Stray unconfirmed Auth user | `<STRAY_AUTH_USER_ID>` |
| Phase 0 RLS probe user | `<RLS_PROBE_USER_ID>` |
| Supabase project ref | `<SUPABASE_PROJECT_REF>` |
| Supabase pooler host | `<SUPABASE_POOLER_HOST>` |
| n8n host | `<N8N_HOST>` |
| WF-00 … WF-10 ids | `<WF00_ID>` … `<WF10_ID>` |
| WF-00b | `<WF00B_ID>` |
| NIWL-00 / NIWL-01 | `<NIWL00_ID>` `<NIWL01_ID>` |
| Archived `LNI-TEST-*` workflow ids | `<TEST_104B_ATTACH_WF_ID>` `<TEST_104B_DEL_WF_ID>` `<TEST_716_DRIVER_WF_ID>` plus remaining TEST ids as `<TEST_{name}_WF_ID>` |
| ElderWise creds (do-not-bind) | `<ELDERWISE_PG_CRED_ID>` `<ELDERWISE_TAVILY_CRED_ID>` |
| ElderWise error workflow (do-not-bind) | `<ELDERWISE_ERROR_WF_ID>` |
| n8n version ids | `<WF{nn}_{PUBLISHED\|ROLLBACK\|DRAFT}>` — one token per distinct version uuid, stable for that uuid |
| Postgres / Telegram / Gmail / OpenAI creds | `<PG_CRED_ID>` `<TELEGRAM_CRED_ID>` `<GMAIL_CRED_ID>` `<OPENAI_CRED_ID>` |
| Storage / Apollo / Tavily / NIWL header | `<STORAGE_CRED_ID>` `<APOLLO_CRED_ID>` `<TAVILY_CRED_ID>` `<NIWL_HEADER_CRED_ID>` |
| Webhook paths | `<WF10_HISTORY_PATH>` `<WF01_INGEST_PATH>` `<NIWL_WAITLIST_PATH>` |
| Owner / platform / test / IU emails | `<OWNER_EMAIL>` `<OWNER_GMAIL>` `<PLATFORM_EMAIL>` `<TEST_TENANT_EMAIL>` `<OWNER_IU_EMAIL>` |
| Third-party emails | `<CONTACT_1_EMAIL>` … numbered by first git appearance, never reused |
| Contact names | `<CONTACT_N_NAME>` — same N as that human’s email. Same-human email pairs (1+2, 3+4, 7+8) share the **lower** N. Extra named people continue from 12. Rewrite map uses `regex:(?i)\b…\b`, not literals (so `<CONTACT_19_NAME>` cannot eat `American`). Arabic/CJK stay literal. |
| Company-as-person only | `<CONTACT_4_COMPANY>`, `<CONTACT_1_COMPANY>`, `<CONTACT_2_COMPANY>` (and their `.com`). Ordinary company names stay. |
| Capture / person / follow_up uuids | **Allowed under rule 25 (12.5a-0d).** Not in the replace-text map. Evidence keys, not operator identity. |

Argue-with-the-packet notes are in the 12.5a-0c implementer
report (version-id tokens, extra creds, extra workflow ids).

## 2b — 034 / 037 (flag, do not solve)

Those files resolve `auth.users` by a literal email. Tokenising
them makes a fresh apply fail. They are already applied and
forward-only. History need not re-run.

**12.6 tenant-bootstrap requirement:** new owner seed uses the
`009` `current_setting('lni.owner_email')` pattern. Never a
literal email in a migration file. Same for platform-owner and
test-tenant bootstrap.

## 2c — evidence that depends on the exact string

Two lessons are the *edit distance*, not the address:

- OCR split: two latinisations of the same card differ by one
  character (`…ld@` vs `…lid@` on the same corporate domain).
  Do not auto-merge `email_normalized` on a one-edit pair.
- Domain transposition: a one-character swap in the registrable
  domain (`…cai…` vs `…aci…`). Exclude the transposed domain;
  keep the live company domain.

After rewrite, those sentences stay; the addresses become
`<CONTACT_7_EMAIL>` / `<CONTACT_8_EMAIL>` and
`<CONTACT_1_EMAIL>` / `<CONTACT_2_EMAIL>`. Full strings remain
only in gitignored evidence.

## 2d — mechanism (not run)

```
git-filter-repo --replace-text docs/scrub-map.local.md
```

Touches **every ref** that contains a mapped literal: `main`,
`cursor/phase-12-docs-c69e`, other local/remote branches, tags.
Open **PR #81** keeps its number only if the branch is
force-pushed after rewrite; review comments on old SHAs go
stale; CI re-runs on new SHAs. Collaborator clones must reset
to the rewritten branch. Zero forks / stars / watchers means
no downstream copies to coordinate — still a force-push.

Do not run it in this packet.

## 2e — rotation

Credential ids are references, not secrets. Workflow ids need
instance auth to change anything. Project ref is not a key
(signup is now disabled). n8n host was never committed in
LEAP-NI or NIWL (PART 0: ZERO). Anon JWT is not in git.
No rotation required from *this* class of leak. Third-party
emails are PII, not credentials — scrub, do not "rotate".
Keys in gitignored `docs/.env.local` were never in git.

**Disagree-if-needed:** none on rotation. Caveat: project
ref + public anon key is how a stranger *would* have signed
up while item 9 was open. Signup is now `422`. Confirm
email is still off (item 11) — no new user can reach that
path while `disable_signup=true`.
