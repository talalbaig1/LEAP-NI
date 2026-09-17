-- 045_interactions_capture_person_uniq
-- Packet 13.2 S6. Forward-only. Idempotent.
-- One interaction per extracted person on a capture.
-- Partial unique: NULL person_id rows stay legal (note-only).
-- Refuse if live duplicate (capture_id, person_id) groups exist.
-- 030 stays Phase 6.

do $$
declare
  v_dups integer;
begin
  select count(*)::int into v_dups
  from (
    select 1
    from public.interactions
    where person_id is not null
    group by capture_id, person_id
    having count(*) > 1
  ) s;

  if v_dups > 0 then
    raise exception
      'LNI 045_interactions_capture_person_uniq: live duplicate (capture_id, person_id) groups: %. Refusing.',
      v_dups;
  end if;
end
$$;

create unique index if not exists interactions_capture_person_uniq
  on public.interactions (capture_id, person_id)
  where person_id is not null;

comment on index public.interactions_capture_person_uniq is
  'Packet 13.2 S6. One interaction per extracted person per capture. Partial: NULL person_id stays legal.';
