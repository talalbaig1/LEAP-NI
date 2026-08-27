-- 016_processing_jobs_asset_job_uniq
-- Natural key for WF-02 /done enqueue. A re-run or replay of stored assets
-- enqueues nothing twice (ON CONFLICT DO NOTHING).
-- Partial: capture-scoped jobs (extraction, entity_resolution) carry
-- asset_id NULL and are excluded from this key.

create unique index processing_jobs_asset_job_uniq
  on public.processing_jobs (asset_id, job_type)
  where asset_id is not null;
