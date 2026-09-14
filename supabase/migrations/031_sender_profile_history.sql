-- 031_sender_profile_history
-- Packet 10.4b. 030 stays reserved for Phase 6 embeddings.
-- Catalog name MUST be 031_sender_profile_history.
-- Does not alter follow_ups_status_check.

create table if not exists public.sender_profile (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  signature_block text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sender_profile_owner_uniq unique (owner_id)
);

alter table public.sender_profile enable row level security;

drop policy if exists sender_profile_owner_all on public.sender_profile;
create policy sender_profile_owner_all on public.sender_profile
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

insert into public.sender_profile (owner_id, signature_block)
select e.owner_id, $sig$Talal Baig
Building SilaCares - caring for loved ones from a distance,
  through technology. silacares.com
Building Ionicx.io - AI-driven architecture and services.
  We automate the work: lower cost, faster processes,
  more revenue.
Twenty years in IT, networks and communications - now
  putting it into my own products.
linkedin.com/in/talal-baig$sig$
from public.events e
where e.name = 'LEAP 2026'
on conflict (owner_id) do update
  set signature_block = excluded.signature_block,
      updated_at = now();

alter table public.follow_ups
  add column if not exists channel text;

alter table public.follow_ups
  drop constraint if exists follow_ups_channel_check;
alter table public.follow_ups
  add constraint follow_ups_channel_check
  check (channel is null or channel in ('email', 'whatsapp', 'linkedin'));

alter table public.follow_ups
  drop constraint if exists follow_ups_draft_state_check;
alter table public.follow_ups
  add constraint follow_ups_draft_state_check
  check (draft_state in (
    'draft',
    'awaiting_voice',
    'awaiting_confirm',
    'sending',
    'sent',
    'failed',
    'cancelled',
    'gmail_draft'
  ));

drop index if exists follow_ups_person_channel_live_uniq;
create unique index follow_ups_person_channel_live_uniq
  on public.follow_ups (person_id, channel)
  where draft_state <> 'cancelled'
    and person_id is not null
    and channel is not null;
