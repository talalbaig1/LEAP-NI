-- 023_processing_jobs_enrichment_person_uniq
-- Natural key for WF-05 enrichment enqueue. A re-run of entity
-- resolution enqueues nothing twice while a queued job already exists
-- (ON CONFLICT DO NOTHING). Completed jobs are outside the index so
-- /flag and a later drain can enqueue again. Partial: queued
-- enrichment jobs with a person_id in output.

create unique index if not exists processing_jobs_enrichment_person_uniq
  on public.processing_jobs ((output->>'person_id'), job_type)
  where job_type = 'enrichment'
    and (output->>'person_id') is not null
    and status = 'queued';
