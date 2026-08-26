-- 009_seed_leap_2026
-- owner_id is resolved by explicit email match on lni.owner_email.
-- Never by creation order. Never a hardcoded UUID.
-- Set the GUC at apply time (SET LOCAL / set_config); do not commit the email.

do $$
declare
  v_owner uuid;
  v_email text;
  v_unconfirmed boolean;
begin
  v_email := nullif(btrim(current_setting('lni.owner_email', true)), '');
  if v_email is null then
    raise exception
      'LNI 009_seed_leap_2026: lni.owner_email is not set. Set it with SET LOCAL before applying. Do not fall back to earliest auth.users row.';
  end if;

  select exists (
    select 1 from auth.users where lower(email) = lower(v_email)
  ) into v_unconfirmed;

  if not v_unconfirmed then
    raise exception
      'LNI 009_seed_leap_2026: no auth.users row matches lni.owner_email.';
  end if;

  select id into v_owner
  from auth.users
  where lower(email) = lower(v_email)
    and email_confirmed_at is not null
  limit 1;

  if v_owner is null then
    raise exception
      'LNI 009_seed_leap_2026: auth.users row matching lni.owner_email is not email-confirmed.';
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
    'LEAP 2026',
    timestamptz '2026-08-31 00:00:00+03',
    timestamptz '2026-09-03 23:59:59+03',
    'Riyadh Exhibition & Convention Centre, Malham',
    'Asia/Riyadh'
  )
  on conflict (owner_id, name) do nothing;
end
$$;
