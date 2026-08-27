-- 020_lni_config_credit_ceilings
-- Packet 4.1: no existing config table on LEAP-NI. This is the first.

create table if not exists public.lni_config (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  key text not null,
  value integer not null,
  created_at timestamptz not null default now(),
  constraint lni_config_owner_key_uniq unique (owner_id, key)
);

alter table public.lni_config enable row level security;

drop policy if exists lni_config_owner_all on public.lni_config;
create policy lni_config_owner_all on public.lni_config
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

insert into public.lni_config (owner_id, key, value)
select e.owner_id, k.key, k.value
from public.events e
cross join (
  values
    ('apollo_daily_ceiling', 60),
    ('apollo_lifetime_ceiling', 2200),
    ('tavily_lifetime_ceiling', 1000)
) as k(key, value)
where e.name = 'LEAP 2026'
on conflict (owner_id, key) do update
  set value = excluded.value;
