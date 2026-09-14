-- 033_sender_profile_channel_signatures
-- Packet 10.4b CH5. 030 stays reserved for Phase 6 embeddings.
-- Catalog name MUST be 033_sender_profile_channel_signatures.
-- Does not rewrite signature_block (email HTML stays as 032).

alter table public.sender_profile
  add column if not exists signature_whatsapp text not null default '',
  add column if not exists signature_linkedin text not null default '';

update public.sender_profile
set
  signature_whatsapp = $wa$<OWNER_NAME>
SilaCares - caring for loved ones from a distance. silacares.com
Ionicx.io - AI-driven architecture. We automate the work.
linkedin.com/in/talal-baig$wa$,
  signature_linkedin = $li$<OWNER_NAME> - building SilaCares and Ionicx.io. linkedin.com/in/talal-baig$li$,
  updated_at = now()
where owner_id = (
  select e.owner_id from public.events e where e.name = 'LEAP 2026' limit 1
);
