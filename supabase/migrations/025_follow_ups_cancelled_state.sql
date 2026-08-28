-- 025_follow_ups_cancelled_state
-- Add 'cancelled' to follow_ups.draft_state CHECK. Do not remove
-- any existing value. Do not touch follow_ups_status_check.
-- Catalog name MUST be 025_follow_ups_cancelled_state.

alter table public.follow_ups
  drop constraint if exists follow_ups_draft_state_check;
alter table public.follow_ups
  add constraint follow_ups_draft_state_check
  check (draft_state in (
    'draft',
    'awaiting_voice',
    'awaiting_confirm',
    'sending',
    'sent',
    'failed',
    'cancelled'
  ));
