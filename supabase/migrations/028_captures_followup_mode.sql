-- 028_captures_followup_mode
-- Additive: allow captures.capture_mode='followup' and bind a
-- follow_ups draft to that capture row. No DROP of await columns.
-- No bot_state.mode value 'followup'. No GRANT SELECT (Phase 5).
-- Catalog name MUST be 028_captures_followup_mode.
-- Phase 6 embeddings is 029, not this file.

alter table public.captures
  drop constraint if exists captures_capture_mode_check;

alter table public.captures
  add constraint captures_capture_mode_check
  check (capture_mode in ('standard', 'batch', 'followup'));

alter table public.follow_ups
  add column if not exists capture_id uuid references public.captures (id);

create index if not exists follow_ups_capture_id_idx
  on public.follow_ups (capture_id);
