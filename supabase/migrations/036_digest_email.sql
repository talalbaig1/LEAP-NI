-- 036_digest_email
-- Packet 12.3. Forward-only. Idempotent.
-- Seed lni_settings key digest_email for the LIVE OWNER only.
-- Value is that owner's auth.users.email, resolved at apply
-- time. Never hardcoded. RAISE if bot_state has no row or
-- email is empty. Do NOT seed the platform owner (D-O).
-- Mailbox linkage is this setting until per-tenant OAuth
-- (Phase 14). Missing key → owner_email '' → Email skipped.

do $$
declare
  v_platform uuid;
  v_owner uuid;
  v_email text;
  v_n integer;
  v_ins uuid;
begin
  select platform_owner_id into v_platform
  from public.lni_instance
  where singleton = true;

  if v_platform is null then
    raise exception
      'LNI 036_digest_email: lni_instance has no row.';
  end if;

  select count(*)::int into v_n from public.bot_state;
  if v_n = 0 then
    raise exception
      'LNI 036_digest_email: bot_state has no row.';
  end if;

  select b.owner_id, u.email
    into v_owner, v_email
  from public.bot_state b
  join public.events e on e.owner_id = b.owner_id
  join auth.users u on u.id = b.owner_id
  where b.owner_id is distinct from v_platform
  limit 1;

  if v_owner is null then
    raise exception
      'LNI 036_digest_email: could not resolve live owner from bot_state.';
  end if;

  if v_email is null or btrim(v_email) = '' then
    raise exception
      'LNI 036_digest_email: live owner auth.users.email is empty.';
  end if;

  insert into public.lni_settings (owner_id, key, value)
  values (v_owner, 'digest_email', v_email)
  on conflict (owner_id, key) do nothing
  returning owner_id into v_ins;

  if not exists (
    select 1
    from public.lni_settings s
    where s.owner_id = v_owner
      and s.key = 'digest_email'
      and btrim(s.value) <> ''
  ) then
    raise exception
      'LNI 036_digest_email: seed did not land for live owner.';
  end if;

  if exists (
    select 1
    from public.lni_settings s
    where s.owner_id = v_platform
      and s.key = 'digest_email'
  ) then
    raise exception
      'LNI 036_digest_email: digest_email must not exist for platform owner.';
  end if;
end
$$;
