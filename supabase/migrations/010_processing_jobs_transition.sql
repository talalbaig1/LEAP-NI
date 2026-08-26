-- 010_processing_jobs_transition
-- WF-09 measures staleness from last_transition_at, never created_at.
-- Trigger-maintained so a workflow cannot forget to set it.

alter table public.processing_jobs
  add column if not exists last_transition_at timestamptz not null default now();

create or replace function public.processing_jobs_set_last_transition_at()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status
     or new.attempt_count is distinct from old.attempt_count then
    new.last_transition_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists processing_jobs_last_transition_at
  on public.processing_jobs;

create trigger processing_jobs_last_transition_at
  before update on public.processing_jobs
  for each row
  execute function public.processing_jobs_set_last_transition_at();

create index if not exists processing_jobs_status_last_transition_at_idx
  on public.processing_jobs (status, last_transition_at);
