-- 035_operator_chat
-- Packet 12.2. Forward-only. Idempotent.
-- Seed lni_settings key operator_chat_id under the platform owner.
-- Value is the live owner's bot_state.telegram_user_id, resolved at
-- apply time. Never hardcoded. RAISE if bot_state has no row.
-- This is lni_settings, not bot_state — D-O is not violated.
-- Also: BEFORE UPDATE trigger so lni_settings.updated_at is real.

create or replace function public.lni_settings_set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists lni_settings_set_updated_at on public.lni_settings;
create trigger lni_settings_set_updated_at
  before update on public.lni_settings
  for each row
  execute function public.lni_settings_set_updated_at();

revoke all on function public.lni_settings_set_updated_at() from public;
revoke all on function public.lni_settings_set_updated_at() from anon, authenticated;

do $$
declare
  v_platform uuid;
  v_chat text;
  v_n integer;
begin
  select platform_owner_id into v_platform
  from public.lni_instance
  where singleton = true;

  if v_platform is null then
    raise exception
      'LNI 035_operator_chat: lni_instance has no row.';
  end if;

  select count(*) into v_n from public.bot_state;
  if v_n = 0 then
    raise exception
      'LNI 035_operator_chat: bot_state has no row.';
  end if;

  select b.telegram_user_id::text into v_chat
  from public.bot_state b
  join public.events e on e.owner_id = b.owner_id
  limit 1;

  if v_chat is null or btrim(v_chat) = '' then
    raise exception
      'LNI 035_operator_chat: could not resolve live owner telegram_user_id from bot_state.';
  end if;

  insert into public.lni_settings (owner_id, key, value)
  values (v_platform, 'operator_chat_id', v_chat)
  on conflict (owner_id, key) do nothing;
end
$$;

comment on function public.lni_settings_set_updated_at() is
  'BEFORE UPDATE on lni_settings. Sets updated_at = now(). Packet 12.2.';
