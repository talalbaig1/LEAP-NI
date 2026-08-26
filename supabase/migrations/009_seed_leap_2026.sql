-- 009_seed_leap_2026
-- owner_id is resolved from auth.users. Zero users is a hard failure.
-- Re-run must not create a second LEAP 2026 row (unique owner_id, name).

do $$
declare
  v_owner uuid;
  v_n integer;
begin
  select count(*)::integer into v_n from auth.users;
  if v_n = 0 then
    raise exception
      'LNI 009_seed_leap_2026: auth.users is empty. Create the owner Auth user (and the second test user) before seeding. owner_id must not be null or a placeholder.';
  end if;

  select id into v_owner
  from auth.users
  order by created_at asc nulls last, id asc
  limit 1;

  if v_owner is null then
    raise exception
      'LNI 009_seed_leap_2026: failed to resolve owner_id from auth.users.';
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
