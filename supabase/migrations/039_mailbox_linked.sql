-- 039_mailbox_linked
-- Packet 12.5a D. Forward-only. Idempotent.
-- Seed lni_settings key mailbox_linked for the LIVE OWNER only.
-- Value is the literal true (not an email). Rule 25.
-- Never the platform owner. Never the test tenant.
-- Missing key → WF-10 email channel is Telegram copy-text (D-E / D-M).
-- 030 stays Phase 6.

do $$
declare
  v_platform uuid;
  v_owner uuid;
  v_n integer;
begin
  select platform_owner_id into v_platform
  from public.lni_instance
  where singleton = true;

  if v_platform is null then
    raise exception
      'LNI 039_mailbox_linked: lni_instance has no row.';
  end if;

  select count(*)::int into v_n from public.bot_state;
  if v_n = 0 then
    raise exception
      'LNI 039_mailbox_linked: bot_state has no row.';
  end if;

  select b.owner_id
    into v_owner
  from public.bot_state b
  where b.owner_id is distinct from v_platform
  limit 1;

  if v_owner is null then
    raise exception
      'LNI 039_mailbox_linked: could not resolve live owner from bot_state.';
  end if;

  insert into public.lni_settings (owner_id, key, value)
  values (v_owner, 'mailbox_linked', 'true')
  on conflict (owner_id, key) do nothing;

  if not exists (
    select 1
    from public.lni_settings s
    where s.owner_id = v_owner
      and s.key = 'mailbox_linked'
      and btrim(s.value) <> ''
  ) then
    raise exception
      'LNI 039_mailbox_linked: seed did not land for live owner.';
  end if;

  if exists (
    select 1
    from public.lni_settings s
    where s.owner_id = v_platform
      and s.key = 'mailbox_linked'
  ) then
    raise exception
      'LNI 039_mailbox_linked: mailbox_linked must not exist for platform owner.';
  end if;

  if exists (
    select 1
    from public.lni_settings s
    join public.events e on e.owner_id = s.owner_id
    where s.key = 'mailbox_linked'
      and e.name = 'NIS test tenant'
  ) then
    raise exception
      'LNI 039_mailbox_linked: mailbox_linked must not exist for the test tenant.';
  end if;
end
$$;
