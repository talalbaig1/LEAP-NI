# environment.local.md — template

Copy to `docs/environment.local.md`. **That file is gitignored. Keep it so.**
Values below are identifiers, not credentials. Credentials live only in the n8n
credential store and Supabase — never in any file in this repo.

## n8n
- Host: `<N8N_HOST>`
- ElderWise error workflow ID (pattern reference only): `<ERROR_WF_ID>`
- LNI error workflow ID (WF-00, created in Phase 0): `TBD`
- n8n instance env `LNI_OWNER_UUID` (WF-00 audit_log fallback). Never commit the value.
- n8n instance env `LNI_TELEGRAM_CHAT_ID` (WF-00 repeat-failure alerts). Optional until the owner chat exists.

## Supabase
- ElderWise project ref — **DO NOT TOUCH**: `<ELDERWISE_PROJECT_REF>`
- LNI project ref (created in Phase 0): `TBD`
- Storage bucket: `lni-assets` (private)

## Telegram
- Bot username: `TBD`
- Owner telegram_user_id (allowlist): `TBD`

## Apollo
- Team ID: `<APOLLO_TEAM_ID>`
- Lead credits at 25 Aug 2026: 175 · target after top-up: 750

## WhatsApp (ElderWise — reference only, LNI does not use it)
- Phone number ID: `<WABA_PHONE_ID>`
