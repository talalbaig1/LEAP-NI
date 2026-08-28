-- 026_captures_last_activity
-- Per-capture idle clock for the WF-02 inactivity sweep.
-- Catalog name MUST be 026_captures_last_activity.
-- Phase 6 embeddings is 027. Do not reuse this number.
--
-- WF-01 is frozen: Append typed note is not modified. A BEFORE
-- UPDATE trigger stamps last_activity_at when typed_note changes.
-- An AFTER INSERT ON assets trigger stamps the parent capture.
--
-- Trigger (b) WHEN (NEW.typed_note IS DISTINCT FROM OLD.typed_note)
-- must NOT fire on the sweep UPDATE of status/closed_at/close_reason,
-- or a capture would refresh itself and never close.
-- Trigger (a) UPDATEs last_activity_at only; typed_note is unchanged,
-- so (a) cannot recurse into (b).

alter table public.captures
  add column if not exists last_activity_at timestamptz;

-- Backfill existing rows from that capture's own clocks.
-- Do not use captures.created_at. Do not leave rows at now().
update public.captures
set last_activity_at = greatest(
  opened_at,
  coalesce(
    (select max(a.created_at)
     from public.assets a
     where a.capture_id = captures.id),
    opened_at
  )
);

alter table public.captures
  alter column last_activity_at set default now();

alter table public.captures
  alter column last_activity_at set not null;

-- (a) New asset = activity on that capture.
create or replace function public.captures_stamp_last_activity_from_asset()
returns trigger
language plpgsql
as $$
begin
  update public.captures
  set last_activity_at = now()
  where id = new.capture_id;
  return new;
end;
$$;

drop trigger if exists captures_last_activity_from_asset
  on public.assets;

create trigger captures_last_activity_from_asset
  after insert on public.assets
  for each row
  execute function public.captures_stamp_last_activity_from_asset();

-- (b) Typed-note change only. Sweep status/closed_at UPDATE must
-- not enter this function.
create or replace function public.captures_stamp_last_activity_from_note()
returns trigger
language plpgsql
as $$
begin
  new.last_activity_at := now();
  return new;
end;
$$;

drop trigger if exists captures_last_activity_from_note
  on public.captures;

create trigger captures_last_activity_from_note
  before update on public.captures
  for each row
  when (new.typed_note is distinct from old.typed_note)
  execute function public.captures_stamp_last_activity_from_note();
