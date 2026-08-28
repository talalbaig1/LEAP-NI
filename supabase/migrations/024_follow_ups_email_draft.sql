-- 024_follow_ups_email_draft
-- Additive email-draft columns on empty follow_ups, plus bot_state
-- await columns for the post-gate voice intercept.
-- Catalog name MUST be 024_follow_ups_email_draft (023 unnamed-prefix
-- lesson: file prefix AND catalog name).
-- Does not alter follow_ups_status_check (WF-07 depends on
-- open|done|cancelled).
-- Does not GRANT SELECT to authenticated (Phase 5).

alter table public.follow_ups
  add column if not exists to_email text,
  add column if not exists cc_email text,
  add column if not exists subject text,
  add column if not exists body text,
  add column if not exists attachment_asset_ids uuid[] not null default '{}',
  add column if not exists draft_state text not null default 'draft',
  add column if not exists idempotency_key uuid not null default gen_random_uuid(),
  add column if not exists gmail_message_id text,
  add column if not exists sent_at timestamptz,
  add column if not exists confirm_expires_at timestamptz default (now() + interval '12 hours'),
  add column if not exists prompt_version text;

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
    'failed'
  ));

-- PARTIAL: person_id required only on awaiting_confirm.
-- awaiting_voice is inserted before person resolution finishes.
alter table public.follow_ups
  drop constraint if exists follow_ups_person_id_confirm_check;
alter table public.follow_ups
  add constraint follow_ups_person_id_confirm_check
  check (draft_state <> 'awaiting_confirm' or person_id is not null);

alter table public.follow_ups
  drop constraint if exists follow_ups_idempotency_key_key;
alter table public.follow_ups
  add constraint follow_ups_idempotency_key_key unique (idempotency_key);

alter table public.bot_state
  add column if not exists awaiting_followup_id uuid references public.follow_ups (id),
  add column if not exists awaiting_followup_until timestamptz;
