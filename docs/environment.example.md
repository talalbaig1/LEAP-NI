# environment.local.md — template

Copy to `docs/environment.local.md`. **That file is gitignored. Keep it so.**
Values below are identifiers, not credentials. Credentials live only in the n8n
credential store and Supabase — never in any file in this repo.

## n8n
- Host: `<N8N_HOST>`
- ElderWise error workflow ID (pattern reference only): `<ERROR_WF_ID>`
- LNI error workflow ID (WF-00): live value lives in `docs/environment.local.md` (gitignored). Do not commit the ID here.
- n8n instance env `N8N_BLOCK_ENV_ACCESS_IN_NODE`: ENABLED. Fact, not a to-do. `$env` is denied in every node. Do not remove it (shared ElderWise container). LNI does not use `$env`.
- `LNI_OWNER_UUID` / `LNI_TELEGRAM_CHAT_ID`: unused. Dead. WF-00 resolves `owner_id` from `events` and `chat_id` from `bot_state`.
- `LNI_OWNER_TELEGRAM_USER_ID`: `<LNI_OWNER_TELEGRAM_USER_ID>` — personal account identifier. Real value belongs only in gitignored `docs/environment.local.md`. Used at apply time for migration `012` (`SET lni.owner_telegram_user_id`); never `$env`.
- `N8N_API_KEY`: `<PASTE_N8N_API_KEY_HERE>` — INSTANCE-WIDE (write/delete every workflow on the shared instance, including ElderWise). Local-only; not committed. Gitignored. Lives in `docs/n8n.local.env`.
- `N8N_BASE_URL`: `https://<N8N_HOST>` — local-only; not committed. Same gitignored file. Owner pastes both values; do not copy live host or key into this template.

## Supabase
- ElderWise project ref — **DO NOT TOUCH**: `<ELDERWISE_PROJECT_REF>`
- LNI project ref (created in Phase 0): `TBD`
- Storage bucket: `lni-assets` (private)

## Telegram
- Bot username: `TBD`
- Owner telegram_user_id (allowlist): placeholder only — see `LNI_OWNER_TELEGRAM_USER_ID` above. Real value belongs only in gitignored `docs/environment.local.md`.

## Apollo
- Team ID: `<APOLLO_TEAM_ID>`
- Lead credits at 25 Aug 2026: 175 · target after top-up: 750

## WhatsApp (ElderWise — reference only, LNI does not use it)
- Phone number ID: `<WABA_PHONE_ID>`
