-- 038_restore_assets_single_unique
-- Packet 12.4e. Forward-only. Idempotent.
-- Restore UNIQUE (telegram_file_unique_id) so published WF-01
-- Insert asset ON CONFLICT (telegram_file_unique_id) can infer.
-- 034 dropped assets_telegram_file_unique_id_key; capture raises
-- 42P10 since 20260916022806. Architect-caused.
-- Keep assets_owner_id_telegram_file_unique_id_key. Both coexist.
-- 030 stays Phase 6.

do $$
declare
  v_dupes integer;
  v_before_n bigint;
  v_before_d bigint;
  v_after_n bigint;
  v_after_d bigint;
begin
  select count(*)::int into v_dupes
  from (
    select telegram_file_unique_id
    from public.assets
    where telegram_file_unique_id is not null
    group by telegram_file_unique_id
    having count(*) > 1
  ) d;

  if v_dupes > 0 then
    raise exception
      'LNI 038_restore_assets_single_unique: % duplicate telegram_file_unique_id group(s). Refusing UNIQUE.',
      v_dupes;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.assets'::regclass
      and conname = 'assets_owner_id_telegram_file_unique_id_key'
  ) then
    raise exception
      'LNI 038_restore_assets_single_unique: assets_owner_id_telegram_file_unique_id_key missing. Refusing to restore the column-only unique without the composite.';
  end if;

  select count(*), count(distinct telegram_file_unique_id)
    into v_before_n, v_before_d
  from public.assets;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.assets'::regclass
      and conname = 'assets_telegram_file_unique_id_key'
  ) then
    alter table public.assets
      add constraint assets_telegram_file_unique_id_key
      unique (telegram_file_unique_id);
  end if;

  select count(*), count(distinct telegram_file_unique_id)
    into v_after_n, v_after_d
  from public.assets;

  if v_after_n is distinct from v_before_n
     or v_after_d is distinct from v_before_d then
    raise exception
      'LNI 038_restore_assets_single_unique: assets counts changed during unique restore (before %/% after %/%).',
      v_before_n, v_before_d, v_after_n, v_after_d;
  end if;
end
$$;

comment on constraint assets_telegram_file_unique_id_key on public.assets is
  'TEMPORARY. Restored by packet 12.4e (038) so published WF-01 Insert asset ON CONFLICT (telegram_file_unique_id) can infer. 034 dropped this; capture raised 42P10 from 20260916022806. Drop this constraint in packet 12.2 remainder when that packet PUTs WF-01 Insert asset to ON CONFLICT (owner_id, telegram_file_unique_id). Do not drop it before that PUT.';

comment on index public.assets_telegram_file_unique_id_key is
  'TEMPORARY. Backing index for assets_telegram_file_unique_id_key. Packet 12.4e. Drop with the constraint in packet 12.2 remainder (WF-01 Insert asset ON CONFLICT PUT).';
