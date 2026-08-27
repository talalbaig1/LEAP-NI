-- 017_events_target_sectors
-- 7 AM briefing coverage gaps. Empty array = not set; do not seed guesses.
-- companies.industry stays null until Phase 4 enrichment.

alter table public.events
  add column if not exists target_sectors text[] not null default '{}';
