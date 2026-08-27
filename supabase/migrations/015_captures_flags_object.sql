-- 015_captures_flags_object
-- flags must be a jsonb object so 013's predicate flags ? 'media_group_id'
-- can ever match. Live rows were arrays ('[]').
-- Do not drop or recreate captures_owner_media_group_uniq.

-- If a flags value is a non-empty jsonb array: RAISE, do not convert.
-- An array has no object keys we can preserve; silently writing '{}' would
-- discard whatever was stored. Empty '[]' is safe to replace with '{}'.

alter table public.captures
  alter column flags set default '{}'::jsonb;

do $$
declare
  v_nonempty integer;
begin
  select count(*) into v_nonempty
  from public.captures
  where jsonb_typeof(flags) = 'array'
    and flags <> '[]'::jsonb;

  if v_nonempty > 0 then
    raise exception
      'LNI 015_captures_flags_object: % captures.flags row(s) are non-empty jsonb arrays; refusing to discard contents. Convert those rows explicitly before re-running.',
      v_nonempty;
  end if;
end
$$;

update public.captures
set flags = '{}'::jsonb
where jsonb_typeof(flags) = 'array';

alter table public.captures
  add constraint captures_flags_object_check
  check (jsonb_typeof(flags) = 'object');
