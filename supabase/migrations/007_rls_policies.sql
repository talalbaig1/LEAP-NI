-- 007_rls_policies
-- Explicit ENABLE + one FOR ALL policy per table.
-- ensure_rls also sets rowsecurity; that flag is not evidence of policy work.
-- No FORCE RLS: service_role (n8n) must continue to bypass.
-- No policies for anon.

alter table public.events enable row level security;
alter table public.bot_state enable row level security;
alter table public.captures enable row level security;
alter table public.assets enable row level security;
alter table public.processing_jobs enable row level security;
alter table public.extraction_runs enable row level security;
alter table public.people enable row level security;
alter table public.companies enable row level security;
alter table public.person_companies enable row level security;
alter table public.interactions enable row level security;
alter table public.follow_ups enable row level security;
alter table public.entity_candidates enable row level security;
alter table public.field_corrections enable row level security;
alter table public.enrichment_records enable row level security;
alter table public.credit_ledger enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists events_owner_all on public.events;
create policy events_owner_all on public.events
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists bot_state_owner_all on public.bot_state;
create policy bot_state_owner_all on public.bot_state
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists captures_owner_all on public.captures;
create policy captures_owner_all on public.captures
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists assets_owner_all on public.assets;
create policy assets_owner_all on public.assets
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists processing_jobs_owner_all on public.processing_jobs;
create policy processing_jobs_owner_all on public.processing_jobs
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists extraction_runs_owner_all on public.extraction_runs;
create policy extraction_runs_owner_all on public.extraction_runs
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists people_owner_all on public.people;
create policy people_owner_all on public.people
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists companies_owner_all on public.companies;
create policy companies_owner_all on public.companies
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists person_companies_owner_all on public.person_companies;
create policy person_companies_owner_all on public.person_companies
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists interactions_owner_all on public.interactions;
create policy interactions_owner_all on public.interactions
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists follow_ups_owner_all on public.follow_ups;
create policy follow_ups_owner_all on public.follow_ups
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists entity_candidates_owner_all on public.entity_candidates;
create policy entity_candidates_owner_all on public.entity_candidates
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists field_corrections_owner_all on public.field_corrections;
create policy field_corrections_owner_all on public.field_corrections
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists enrichment_records_owner_all on public.enrichment_records;
create policy enrichment_records_owner_all on public.enrichment_records
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists credit_ledger_owner_all on public.credit_ledger;
create policy credit_ledger_owner_all on public.credit_ledger
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists audit_log_owner_all on public.audit_log;
create policy audit_log_owner_all on public.audit_log
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());
