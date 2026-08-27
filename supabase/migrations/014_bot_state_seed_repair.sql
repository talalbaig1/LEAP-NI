-- 014_bot_state_seed_repair
-- Catalog repair so schema_migrations matches reality without disturbing
-- the live bot_state row (exactly one row already exists).
-- 012 failed on 26 Aug 2026: current_setting('lni.owner_telegram_user_id')
-- without missing_ok raised "unrecognized configuration parameter".
-- This file uses current_setting(..., true) like 009.
-- Never hardcode a UUID or a telegram id. Never fall back to earliest
-- auth.users. Idempotent.

do $$
declare
  v_owner uuid;
  v_email text;
  v_tg_raw text;
  v_tg bigint;
  v_cnt integer;
  v_row public.bot_state%rowtype;
  v_open_ok boolean;
begin
  v_email := nullif(btrim(current_setting('lni.owner_email', true)), '');
  v_tg_raw := nullif(btrim(current_setting('lni.owner_telegram_user_id', true)), '');

  if v_email is not null then
    -- Same explicit method as 009: confirmed email match, no creation-order heuristic.
    select exists (
      select 1 from auth.users where lower(email) = lower(v_email)
    ) into v_open_ok;

    if not v_open_ok then
      raise exception
        'LNI 014_bot_state_seed_repair: no auth.users row matches lni.owner_email.';
    end if;

    select id into v_owner
    from auth.users
    where lower(email) = lower(v_email)
      and email_confirmed_at is not null
    limit 1;

    if v_owner is null then
      raise exception
        'LNI 014_bot_state_seed_repair: auth.users row matching lni.owner_email is not email-confirmed.';
    end if;
  else
    -- GUC absent. Use the owner 009 already stored on events — not earliest auth.users.
    select owner_id into v_owner
    from public.events
    where name = 'LEAP 2026';

    if v_owner is null then
      raise exception
        'LNI 014_bot_state_seed_repair: lni.owner_email is not set AND LEAP 2026 has no owner_id. Set the GUC. Do not fall back to earliest auth.users row.';
    end if;
  end if;

  select count(*) into v_cnt from public.bot_state;

  if v_cnt = 0 then
    -- Need an explicit telegram id to insert. Never invent one.
    if v_tg_raw is null then
      raise exception
        'LNI 014_bot_state_seed_repair: bot_state is empty and lni.owner_telegram_user_id is not set. Set current_setting(..., true) GUCs. Never hardcode a telegram id.';
    end if;

    begin
      v_tg := v_tg_raw::bigint;
    exception when invalid_text_representation then
      raise exception
        'LNI 014_bot_state_seed_repair: lni.owner_telegram_user_id is not a bigint.';
    end;

    if v_tg is null or v_tg <= 0 then
      raise exception
        'LNI 014_bot_state_seed_repair: lni.owner_telegram_user_id is missing or invalid.';
    end if;

    insert into public.bot_state (owner_id, telegram_user_id, mode)
    values (v_owner, v_tg, 'normal')
    on conflict (owner_id, telegram_user_id) do nothing;
  end if;
  -- Existing rows are not UPDATEd. Catalog repair must not disturb live state.

  select count(*) into v_cnt from public.bot_state;
  if v_cnt <> 1 then
    raise exception
      'LNI 014_bot_state_seed_repair: expected exactly one bot_state row, found %.',
      v_cnt;
  end if;

  select * into strict v_row from public.bot_state;

  if v_row.owner_id is distinct from v_owner then
    raise exception
      'LNI 014_bot_state_seed_repair: bot_state.owner_id does not equal the owner resolved by the 009 method (lni.owner_email when set, else events.owner_id for LEAP 2026).';
  end if;

  if v_row.open_capture_id is null then
    v_open_ok := true;
  else
    select exists (
      select 1
      from public.captures c
      where c.id = v_row.open_capture_id
        and c.owner_id = v_row.owner_id
        and c.status = 'open'
    ) into v_open_ok;
  end if;

  if not v_open_ok then
    raise exception
      'LNI 014_bot_state_seed_repair: open_capture_id is set but is not an open capture of the same owner.';
  end if;
end
$$;
