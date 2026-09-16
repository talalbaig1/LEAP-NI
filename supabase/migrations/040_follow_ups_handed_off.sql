-- 040_follow_ups_handed_off
-- Packet 12.7. Forward-only. Idempotent.
-- Add 'handed_off' to follow_ups_draft_state_check.
-- Keep every existing value. NO BACKFILL.
-- Does not alter follow_ups_status_check.
-- Does not alter follow_ups_person_channel_live_uniq
-- (`draft_state <> 'cancelled'` already treats handed_off as live).
-- Catalog name MUST be 040_follow_ups_handed_off.
-- 030 stays Phase 6 embeddings.

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
    'cancelled',
    'gmail_draft',
    'handed_off'
  ));
