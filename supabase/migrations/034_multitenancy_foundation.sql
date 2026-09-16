-- 034_multitenancy_foundation
-- Packet 12.1. Isolation schema. Forward-only. Idempotent.
-- 030 stays Phase 6 embeddings. Do not steal it.
-- lni_config stays INTEGER-only and gains nothing.
-- Platform owner is resolved by exact email match. Never a hardcoded
-- UUID. Never earliest-row. Never a count heuristic.

-- 3a. lni_instance — instance fingerprint. NOT owner-scoped.
-- Singleton enforced structurally (boolean PK CHECK true).

create table if not exists public.lni_instance (
  singleton boolean not null default true,
  name text not null,
  platform_owner_id uuid not null references auth.users (id),
  constraint lni_instance_singleton_pkey primary key (singleton),
  constraint lni_instance_singleton_true check (singleton = true)
);

alter table public.lni_instance enable row level security;

drop policy if exists lni_instance_select on public.lni_instance;
create policy lni_instance_select on public.lni_instance
  for select to authenticated
  using (true);

revoke all on table public.lni_instance from public;
revoke all on table public.lni_instance from anon, authenticated;

-- 3b. lni_settings — owner-scoped TEXT key/value.

create table if not exists public.lni_settings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  key text not null,
  value text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lni_settings_owner_key_uniq unique (owner_id, key)
);

alter table public.lni_settings enable row level security;

drop policy if exists lni_settings_owner_all on public.lni_settings;
create policy lni_settings_owner_all on public.lni_settings
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

revoke all on table public.lni_settings from public;
revoke all on table public.lni_settings from anon, authenticated;

do $$
declare
  v_platform uuid;
  v_n integer;
  v_dupes integer;
  v_dep_constraint integer;
  v_dep_fk integer;
  v_old_exists boolean;
  v_new_exists boolean;
  v_before_n bigint;
  v_before_d bigint;
  v_after_n bigint;
  v_after_d bigint;
begin
  -- Platform owner: exact email, RAISE on 0 / many / unconfirmed.
  select count(*) into v_n
  from auth.users
  where email = 'donotreplynis@gmail.com';

  if v_n = 0 then
    raise exception
      'LNI 034_multitenancy_foundation: no auth.users row matches donotreplynis@gmail.com.';
  end if;

  if v_n > 1 then
    raise exception
      'LNI 034_multitenancy_foundation: multiple auth.users rows match donotreplynis@gmail.com.';
  end if;

  select id into v_platform
  from auth.users
  where email = 'donotreplynis@gmail.com'
    and email_confirmed_at is not null;

  if v_platform is null then
    raise exception
      'LNI 034_multitenancy_foundation: auth.users row matching donotreplynis@gmail.com is not email-confirmed.';
  end if;

  insert into public.lni_instance (singleton, name, platform_owner_id)
  values (true, 'NIS', v_platform)
  on conflict (singleton) do nothing;

  -- Seed display_name for the live owner only. Not the platform owner (D-O).
  insert into public.lni_settings (owner_id, key, value)
  select e.owner_id, 'display_name', 'Talal Baig'
  from public.events e
  where e.name = 'LEAP 2026'
  on conflict (owner_id, key) do nothing;

  -- 3c. bot_state: assert zero duplicate telegram_user_id, then global UNIQUE.
  select count(*) into v_dupes
  from (
    select telegram_user_id
    from public.bot_state
    group by telegram_user_id
    having count(*) > 1
  ) d;

  if v_dupes > 0 then
    raise exception
      'LNI 034_multitenancy_foundation: % duplicate telegram_user_id group(s) in bot_state. Refusing UNIQUE.',
      v_dupes;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.bot_state'::regclass
      and conname = 'bot_state_telegram_user_id_key'
  ) then
    alter table public.bot_state
      add constraint bot_state_telegram_user_id_key unique (telegram_user_id);
  end if;

  -- 3d. assets unique swap. STOP if anything depends on the dropped constraint.
  select exists (
    select 1
    from pg_constraint
    where conrelid = 'public.assets'::regclass
      and conname = 'assets_telegram_file_unique_id_key'
  ) into v_old_exists;

  select exists (
    select 1
    from pg_constraint
    where conrelid = 'public.assets'::regclass
      and conname = 'assets_owner_id_telegram_file_unique_id_key'
  ) into v_new_exists;

  if v_old_exists then
    select count(*) into v_dep_constraint
    from pg_constraint c
    join pg_depend d on d.refobjid = c.oid
    where c.conrelid = 'public.assets'::regclass
      and c.conname = 'assets_telegram_file_unique_id_key'
      and d.deptype <> 'i';

    select count(*) into v_dep_fk
    from pg_constraint u
    join pg_constraint fk
      on fk.contype = 'f'
     and fk.confrelid = u.conrelid
     and fk.confkey = u.conkey
    where u.conrelid = 'public.assets'::regclass
      and u.conname = 'assets_telegram_file_unique_id_key';

    if v_dep_constraint > 0 or v_dep_fk > 0 then
      raise exception
        'LNI 034_multitenancy_foundation: assets_telegram_file_unique_id_key has dependents (pg_depend non-internal %, fk %). STOP.',
        v_dep_constraint, v_dep_fk;
    end if;

    select count(*), count(distinct telegram_file_unique_id)
      into v_before_n, v_before_d
    from public.assets;

    alter table public.assets
      drop constraint assets_telegram_file_unique_id_key;

    if not v_new_exists then
      alter table public.assets
        add constraint assets_owner_id_telegram_file_unique_id_key
        unique (owner_id, telegram_file_unique_id);
    end if;

    select count(*), count(distinct telegram_file_unique_id)
      into v_after_n, v_after_d
    from public.assets;

    if v_after_n is distinct from v_before_n
       or v_after_d is distinct from v_before_d then
      raise exception
        'LNI 034_multitenancy_foundation: assets counts changed during unique swap (before %/% after %/%).',
        v_before_n, v_before_d, v_after_n, v_after_d;
    end if;
  elsif not v_new_exists then
    alter table public.assets
      add constraint assets_owner_id_telegram_file_unique_id_key
      unique (owner_id, telegram_file_unique_id);
  end if;
end
$$;

comment on table public.lni_instance is
  'Instance fingerprint. Not owner-scoped. Exactly one row. platform_owner_id is D-O (identity, never a sender).';

comment on table public.lni_settings is
  'Owner-scoped text config. lni_config stays integer-only. Signatures stay on sender_profile.';
