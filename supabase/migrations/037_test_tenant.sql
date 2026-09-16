-- 037_test_tenant
-- Packet 12.3c / 12.2b-i. Forward-only. Idempotent.
-- Permanent INERT test tenant. Never deleted. Never frozen (Q2).
-- Resolve owner by EXACT email match (009 / 034 RAISE:
-- 0 matches, many, or unconfirmed). Never a hardcoded uuid.
-- Never earliest-row.
-- Seeds: events (name NOT 'LEAP 2026', own timezone),
-- lni_config apollo_daily_ceiling + lifetime ceilings,
-- sender_profile.
-- Does NOT insert bot_state — that is the point: invisible
-- to List due owners, WF-01 allowlist, and every cron.
-- Does NOT insert lni_settings digest_email — D2d fixture
-- (missing key → owner_email '' → Email skipped).
-- 030 stays Phase 6.

do $$
declare
  v_email constant text := 'talalbaig+tenant2@gmail.com';
  v_owner uuid;
  v_n integer;
  v_event uuid;
begin
  select count(*)::int into v_n
  from auth.users
  where email = v_email;

  if v_n = 0 then
    raise exception
      'LNI 037_test_tenant: no auth.users row matches %.',
      v_email;
  end if;

  if v_n > 1 then
    raise exception
      'LNI 037_test_tenant: multiple auth.users rows match %.',
      v_email;
  end if;

  select id into v_owner
  from auth.users
  where email = v_email
    and email_confirmed_at is not null;

  if v_owner is null then
    raise exception
      'LNI 037_test_tenant: auth.users row matching % is not email-confirmed.',
      v_email;
  end if;

  insert into public.events (
    owner_id,
    name,
    starts_at,
    ends_at,
    location,
    timezone
  )
  values (
    v_owner,
    'NIS test tenant',
    timestamptz '2026-01-01 00:00:00+13',
    timestamptz '2026-12-31 23:59:59+13',
    'permanent inert harness',
    'Pacific/Auckland'
  )
  on conflict (owner_id, name) do nothing
  returning id into v_event;

  insert into public.lni_config (owner_id, key, value)
  values
    (v_owner, 'apollo_daily_ceiling', 60),
    (v_owner, 'apollo_lifetime_ceiling', 2200),
    (v_owner, 'tavily_lifetime_ceiling', 1000)
  on conflict (owner_id, key) do nothing;

  insert into public.sender_profile (owner_id, signature_block)
  values (
    v_owner,
    $sig$LNI permanent test tenant (inert). Not a mail sender.$sig$
  )
  on conflict (owner_id) do nothing;

  if not exists (
    select 1
    from public.events e
    where e.owner_id = v_owner
      and e.name = 'NIS test tenant'
      and e.name is distinct from 'LEAP 2026'
      and e.timezone is distinct from 'Asia/Riyadh'
  ) then
    raise exception
      'LNI 037_test_tenant: events row did not land.';
  end if;

  if (
    select count(*)::int
    from public.lni_config c
    where c.owner_id = v_owner
      and c.key in (
        'apollo_daily_ceiling',
        'apollo_lifetime_ceiling',
        'tavily_lifetime_ceiling'
      )
  ) <> 3 then
    raise exception
      'LNI 037_test_tenant: ceiling rows did not land.';
  end if;

  if not exists (
    select 1 from public.sender_profile s where s.owner_id = v_owner
  ) then
    raise exception
      'LNI 037_test_tenant: sender_profile row did not land.';
  end if;

  if exists (
    select 1 from public.bot_state b where b.owner_id = v_owner
  ) then
    raise exception
      'LNI 037_test_tenant: bot_state must not exist for the inert tenant.';
  end if;

  if exists (
    select 1
    from public.lni_settings s
    where s.owner_id = v_owner
      and s.key = 'digest_email'
  ) then
    raise exception
      'LNI 037_test_tenant: digest_email must not exist (D2d fixture).';
  end if;
end
$$;
