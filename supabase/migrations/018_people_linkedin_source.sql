-- 018_people_linkedin_source
-- Packet 4.1 called this 017. Live catalog already had 017_events_target_sectors.
-- Provenance for people.linkedin_url. Default 'card' is honest: all existing
-- rows have linkedin_url NULL.

alter table public.people
  add column if not exists linkedin_source text not null default 'card';

alter table public.people
  drop constraint if exists people_linkedin_source_check;

alter table public.people
  add constraint people_linkedin_source_check
  check (linkedin_source in ('card', 'apollo'));
