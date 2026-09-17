-- 041_tenant2_bot_state
-- Packet 12.8. Forward-only. Idempotent.
-- The door: ONE bot_state row for the permanent test tenant.
-- IRREVERSIBLE once a real message is processed. A leak cannot
-- be un-shown. 7c72371f failed_24h is a real finding and is
-- kept for B7. Do not age it out. Do not block this INSERT
-- on it.
--
-- telegram_user_id is NEVER a literal. Resolve with
-- current_setting('lni.tenant2_telegram_user_id', true)
-- (009 / 014 pattern, missing_ok). RAISE on missing or empty.
-- Set the GUC out of band at apply time (SET LOCAL / set_config
-- in the same session). Value lives only in gitignored
-- docs/environment.local.md. Never $env.
--
-- Owner is resolved from events.name = 'NIS test tenant'
-- (037). Never a hardcoded uuid. Never LEAP 2026. Never
-- earliest auth.users.
--
-- Asserts 034 UNIQUE (telegram_user_id) still holds.
-- Does NOT seed digest_email (D2d fixture stays).
-- 030 stays Phase 6 embeddings.
-- Catalog name MUST be 041_tenant2_bot_state.

do $$
declare
  v_owner uuid;
  v_n integer;
  v_tg_raw text;
  v_tg bigint;
  v_cnt integer;
  v_owners integer;
  v_tgs integer;
begin
  v_tg_raw := nullif(btrim(current_setting('lni.tenant2_telegram_user_id', true)), '');
  if v_tg_raw is null then
    raise exception
      'LNI 041_tenant2_bot_state: lni.tenant2_telegram_user_id is not set. SET LOCAL it in the same session. Do not hardcode a telegram id.';
  end if;

  begin
    v_tg := v_tg_raw::bigint;
  exception when invalid_text_representation then
    raise exception
      'LNI 041_tenant2_bot_state: lni.tenant2_telegram_user_id is not a bigint.';
  end;

  if v_tg is null or v_tg <= 0 then
    raise exception
      'LNI 041_tenant2_bot_state: lni.tenant2_telegram_user_id is missing or invalid.';
  end if;

  select count(*)::int into v_n
  from public.events
  where name = 'NIS test tenant';

  if v_n = 0 then
    raise exception
      'LNI 041_tenant2_bot_state: events row NIS test tenant not found. 037 must land first.';
  end if;

  if v_n > 1 then
    raise exception
      'LNI 041_tenant2_bot_state: multiple events rows named NIS test tenant.';
  end if;

  select owner_id into v_owner
  from public.events
  where name = 'NIS test tenant';

  if v_owner is null then
    raise exception
      'LNI 041_tenant2_bot_state: NIS test tenant has no owner_id.';
  end if;

  if exists (
    select 1 from public.events e
    where e.name = 'LEAP 2026' and e.owner_id = v_owner
  ) then
    raise exception
      'LNI 041_tenant2_bot_state: refused — owner also owns LEAP 2026.';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.bot_state'::regclass
      and conname = 'bot_state_telegram_user_id_key'
      and contype = 'u'
  ) then
    raise exception
      'LNI 041_tenant2_bot_state: 034 unique bot_state_telegram_user_id_key is missing.';
  end if;

  if exists (
    select 1
    from public.bot_state b
    where b.telegram_user_id = v_tg
      and b.owner_id is distinct from v_owner
  ) then
    raise exception
      'LNI 041_tenant2_bot_state: that telegram_user_id already belongs to another owner.';
  end if;

  if not exists (
    select 1 from public.bot_state b where b.owner_id = v_owner
  ) then
    insert into public.bot_state (
      owner_id,
      telegram_user_id,
      mode,
      open_capture_id
    )
    values (
      v_owner,
      v_tg,
      'normal',
      null
    )
    on conflict (owner_id, telegram_user_id) do nothing;
  end if;

  select count(*)::int into v_cnt from public.bot_state;
  if v_cnt <> 2 then
    raise exception
      'LNI 041_tenant2_bot_state: expected 2 bot_state rows, found %.',
      v_cnt;
  end if;

  select count(distinct owner_id)::int,
         count(distinct telegram_user_id)::int
    into v_owners, v_tgs
  from public.bot_state;

  if v_owners <> 2 or v_tgs <> 2 then
    raise exception
      'LNI 041_tenant2_bot_state: bot_state owners or telegram ids are not distinct.';
  end if;

  if not exists (
    select 1
    from public.bot_state b
    where b.owner_id = v_owner
      and b.telegram_user_id = v_tg
      and b.mode = 'normal'
      and b.open_capture_id is null
  ) then
    raise exception
      'LNI 041_tenant2_bot_state: tenant bot_state row did not land as normal / open_capture_id NULL.';
  end if;

  if exists (
    select 1
    from public.lni_settings s
    where s.owner_id = v_owner
      and s.key = 'digest_email'
  ) then
    raise exception
      'LNI 041_tenant2_bot_state: digest_email must stay absent (D2d).';
  end if;
end
$$;
