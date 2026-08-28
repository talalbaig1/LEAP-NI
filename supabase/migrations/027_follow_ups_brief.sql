-- 027_follow_ups_brief
-- Additive: persist the voice transcript and script flags on the
-- awaiting_voice row so a later f7:p: execution can draft from the
-- row, not from nodes that did not run in that execution.
-- Catalog name MUST be 027_follow_ups_brief.
-- Does not alter follow_ups_status_check (WF-07 depends on
-- open|done|cancelled).
-- Does not GRANT SELECT to authenticated (Phase 5).
-- Phase 6 embeddings is 029, not this file. 028 is captures_followup_mode.

alter table public.follow_ups
  add column if not exists brief text,
  add column if not exists has_arabic boolean,
  add column if not exists has_latin boolean;

-- Backfill flags stuffed into prompt_version by 7.6-FIX-R F6.
update public.follow_ups
set
  has_arabic = case
    when position('has_arabic=true' in coalesce(prompt_version, '')) > 0 then true
    when position('has_arabic=false' in coalesce(prompt_version, '')) > 0 then false
    else has_arabic
  end,
  has_latin = case
    when position('has_latin=true' in coalesce(prompt_version, '')) > 0 then true
    when position('has_latin=false' in coalesce(prompt_version, '')) > 0 then false
    else has_latin
  end
where prompt_version like '%has_arabic=%'
   or prompt_version like '%has_latin=%';

-- prompt_version is a version again.
update public.follow_ups
set prompt_version = 'wf10-v2'
where prompt_version like 'wf10-v2;%';
