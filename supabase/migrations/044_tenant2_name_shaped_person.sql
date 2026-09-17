-- 044_tenant2_name_shaped_person
-- Packet 14.0 A2. Forward-only. Idempotent.
-- One name-shaped person on the tenant that owns
-- events.name = 'NIS test tenant' AND has bot_state.
-- Do not touch existing fixture people on that owner.
-- 030 stays Phase 6.

do $$
declare
  v_owner uuid;
  v_n integer;
begin
  select count(*)::int into v_n
  from public.events e
  where e.name = 'NIS test tenant'
    and exists (
      select 1 from public.bot_state b where b.owner_id = e.owner_id
    );

  if v_n <> 1 then
    raise exception
      'LNI 044_tenant2_name_shaped_person: expected 1 NIS test tenant with bot_state, found %.',
      v_n;
  end if;

  select e.owner_id into v_owner
  from public.events e
  where e.name = 'NIS test tenant'
    and exists (
      select 1 from public.bot_state b where b.owner_id = e.owner_id
    );

  if exists (
    select 1 from public.people p
    where p.owner_id = v_owner
      and p.full_name = 'Sara Alharbi'
  ) then
    return;
  end if;

  insert into public.people (
    owner_id,
    full_name,
    email,
    source_type,
    review_status,
    linkedin_source
  ) values (
    v_owner,
    'Sara Alharbi',
    'sara.alharbi@example.invalid',
    'typed_note',
    'approved',
    'card'
  );

  if (
    select count(*)::int
    from public.people p
    where p.owner_id = v_owner
      and p.full_name = 'Sara Alharbi'
      and p.email_normalized = 'sara.alharbi@example.invalid'
  ) <> 1 then
    raise exception
      'LNI 044_tenant2_name_shaped_person: row did not land.';
  end if;
end
$$;
