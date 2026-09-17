-- 043_drop_assets_column_unique
-- Packet 13.0 P1c. Forward-only. Idempotent.
-- Drop TEMPORARY UNIQUE (telegram_file_unique_id) restored by 038.
-- ONLY after WF-01 Insert asset ON CONFLICT (owner_id, telegram_file_unique_id)
-- is published AND a real photo has stored on that graph.
-- Keep assets_owner_id_telegram_file_unique_id_key.
-- 030 stays Phase 6.

do $$
declare
  v_dep_constraint integer := 0;
  v_dep_fk integer := 0;
  v_before_n bigint;
  v_before_d bigint;
  v_after_n bigint;
  v_after_d bigint;
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.assets'::regclass
      and conname = 'assets_owner_id_telegram_file_unique_id_key'
  ) then
    raise exception
      'LNI 043_drop_assets_column_unique: composite unique missing. Refusing drop.';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.assets'::regclass
      and conname = 'assets_telegram_file_unique_id_key'
  ) then
    return;
  end if;

  select count(*) into v_dep_constraint
  from pg_constraint c
  join pg_depend d on d.refobjid = c.oid
  where c.conrelid = 'public.assets'::regclass
    and c.conname = 'assets_telegram_file_unique_id_key'
    and d.deptype <> 'i';

  select count(*) into v_dep_fk
  from pg_constraint u
  join pg_constraint fk
    on fk.contype = 'f'
   and fk.confrelid = u.conrelid
   and fk.confkey = u.conkey
  where u.conrelid = 'public.assets'::regclass
    and u.conname = 'assets_telegram_file_unique_id_key';

  if v_dep_constraint > 0 or v_dep_fk > 0 then
    raise exception
      'LNI 043_drop_assets_column_unique: assets_telegram_file_unique_id_key has dependents (pg_depend non-internal %, fk %). STOP.',
      v_dep_constraint, v_dep_fk;
  end if;

  select count(*), count(distinct telegram_file_unique_id)
    into v_before_n, v_before_d
  from public.assets;

  alter table public.assets
    drop constraint assets_telegram_file_unique_id_key;

  select count(*), count(distinct telegram_file_unique_id)
    into v_after_n, v_after_d
  from public.assets;

  if v_after_n is distinct from v_before_n
     or v_after_d is distinct from v_before_d then
    raise exception
      'LNI 043_drop_assets_column_unique: assets counts changed during drop (before %/% after %/%).',
      v_before_n, v_before_d, v_after_n, v_after_d;
  end if;
end
$$;

comment on constraint assets_owner_id_telegram_file_unique_id_key on public.assets is
  'Live unique. Packet 034. Packet 13.0 P1c dropped the TEMPORARY column-only unique from 038 once Insert asset ON CONFLICT (owner_id, telegram_file_unique_id) was published and a real photo stored.';
