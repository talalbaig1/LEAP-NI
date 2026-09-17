-- 042_bot_state_current_event
-- Packet 12.9. Forward-only. Idempotent.
-- Per-tenant current event on bot_state. Replaces
-- events.name = 'LEAP 2026' as the capture INSERT key.
-- 030 stays Phase 6 embeddings.
-- Catalog name MUST be 042_bot_state_current_event.

-- B2. UNIQUE (owner_id, id) on events so a composite FK
-- can enforce owner consistency. id is already PK; this
-- unique exists for the FK target, not for extra
-- uniqueness of id.

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.events'::regclass
      and conname = 'events_owner_id_id_key'
  ) then
    alter table public.events
      add constraint events_owner_id_id_key
      unique (owner_id, id);
  end if;
end
$$;

-- B1. Nullable. A tenant may exist before their first
-- event. MATCH SIMPLE on the composite FK allows NULL.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'bot_state'
      and column_name = 'current_event_id'
  ) then
    alter table public.bot_state
      add column current_event_id uuid references public.events (id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bot_state'::regclass
      and conname = 'bot_state_owner_current_event_fk'
  ) then
    alter table public.bot_state
      add constraint bot_state_owner_current_event_fk
      foreign key (owner_id, current_event_id)
      references public.events (owner_id, id);
  end if;
end
$$;

comment on column public.bot_state.current_event_id is
  'Packet 12.9. The event a new capture binds to. NULL means no active event — workflows must message, not silence. Owner consistency is bot_state_owner_current_event_fk, not a name match.';

comment on constraint events_owner_id_id_key on public.events is
  'Packet 12.9. FK target for bot_state (owner_id, current_event_id).';

comment on constraint bot_state_owner_current_event_fk on public.bot_state is
  'Packet 12.9. A tenant cannot point current_event_id at another tenant''s event.';

-- B3. Backfill from that owner's events row. Never by
-- name. Never LIMIT 1 over all events. Exactly one
-- events row per bot_state owner is required today.

do $$
declare
  v_bad integer;
  v_n integer;
  v_mismatch integer;
begin
  select count(*)::int into v_bad
  from public.bot_state b
  where (
    select count(*) from public.events e where e.owner_id = b.owner_id
  ) is distinct from 1;

  if v_bad > 0 then
    raise exception
      'LNI 042_bot_state_current_event: % bot_state owner(s) do not have exactly one events row. Refusing backfill.',
      v_bad;
  end if;

  update public.bot_state b
  set current_event_id = e.id
  from public.events e
  where e.owner_id = b.owner_id
    and b.current_event_id is null;

  select count(*)::int into v_n from public.bot_state;
  if v_n is distinct from 2 then
    raise exception
      'LNI 042_bot_state_current_event: expected 2 bot_state rows, found %.',
      v_n;
  end if;

  select count(*)::int into v_mismatch
  from public.bot_state b
  join public.events e on e.id = b.current_event_id
  where e.owner_id is distinct from b.owner_id
     or b.current_event_id is null;

  if v_mismatch > 0 then
    raise exception
      'LNI 042_bot_state_current_event: % bot_state row(s) missing current_event_id or pointing at another owner.',
      v_mismatch;
  end if;

  if exists (
    select 1 from public.bot_state where current_event_id is null
  ) then
    raise exception
      'LNI 042_bot_state_current_event: a bot_state row still has NULL current_event_id after backfill.';
  end if;
end
$$;
