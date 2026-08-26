-- 006_indexes
-- Foreign-key columns, trigram search, and the email uniqueness rule.
-- No ON DELETE CASCADE to assets — merges preserve raw media.

create unique index if not exists people_owner_email_normalized_uidx
  on public.people (owner_id, email_normalized)
  where email_normalized is not null;

create index if not exists people_full_name_trgm_idx
  on public.people using gin (full_name gin_trgm_ops);

create index if not exists companies_name_trgm_idx
  on public.companies using gin (name gin_trgm_ops);

create index if not exists interactions_summary_trgm_idx
  on public.interactions using gin (summary gin_trgm_ops);

create index if not exists events_owner_id_idx
  on public.events (owner_id);

create index if not exists bot_state_owner_id_idx
  on public.bot_state (owner_id);
create index if not exists bot_state_open_capture_id_idx
  on public.bot_state (open_capture_id);

create index if not exists captures_owner_id_idx
  on public.captures (owner_id);
create index if not exists captures_event_id_idx
  on public.captures (event_id);

create index if not exists assets_owner_id_idx
  on public.assets (owner_id);
create index if not exists assets_capture_id_idx
  on public.assets (capture_id);

create index if not exists processing_jobs_owner_id_idx
  on public.processing_jobs (owner_id);
create index if not exists processing_jobs_capture_id_idx
  on public.processing_jobs (capture_id);
create index if not exists processing_jobs_asset_id_idx
  on public.processing_jobs (asset_id);

create index if not exists extraction_runs_owner_id_idx
  on public.extraction_runs (owner_id);
create index if not exists extraction_runs_capture_id_idx
  on public.extraction_runs (capture_id);

create index if not exists people_owner_id_idx
  on public.people (owner_id);

create index if not exists companies_owner_id_idx
  on public.companies (owner_id);

create index if not exists person_companies_owner_id_idx
  on public.person_companies (owner_id);
create index if not exists person_companies_person_id_idx
  on public.person_companies (person_id);
create index if not exists person_companies_company_id_idx
  on public.person_companies (company_id);

create index if not exists interactions_owner_id_idx
  on public.interactions (owner_id);
create index if not exists interactions_capture_id_idx
  on public.interactions (capture_id);
create index if not exists interactions_person_id_idx
  on public.interactions (person_id);
create index if not exists interactions_company_id_idx
  on public.interactions (company_id);

create index if not exists follow_ups_owner_id_idx
  on public.follow_ups (owner_id);
create index if not exists follow_ups_interaction_id_idx
  on public.follow_ups (interaction_id);
create index if not exists follow_ups_person_id_idx
  on public.follow_ups (person_id);

create index if not exists entity_candidates_owner_id_idx
  on public.entity_candidates (owner_id);
create index if not exists entity_candidates_candidate_entity_id_idx
  on public.entity_candidates (candidate_entity_id);

create index if not exists field_corrections_owner_id_idx
  on public.field_corrections (owner_id);
create index if not exists field_corrections_entity_id_idx
  on public.field_corrections (entity_id);

create index if not exists enrichment_records_owner_id_idx
  on public.enrichment_records (owner_id);
create index if not exists enrichment_records_entity_id_idx
  on public.enrichment_records (entity_id);

create index if not exists credit_ledger_owner_id_idx
  on public.credit_ledger (owner_id);
create index if not exists credit_ledger_entity_id_idx
  on public.credit_ledger (entity_id);

create index if not exists audit_log_owner_id_idx
  on public.audit_log (owner_id);
create index if not exists audit_log_correlation_id_idx
  on public.audit_log (correlation_id);
