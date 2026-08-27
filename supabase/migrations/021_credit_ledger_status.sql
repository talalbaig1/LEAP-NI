-- 021_credit_ledger_status
-- Ledger row is written BEFORE the provider call. status distinguishes
-- attempted vs confirmed vs no_match vs failed. Table was empty; no backfill.

alter table public.credit_ledger
  add column if not exists status text not null default 'attempted';

alter table public.credit_ledger
  drop constraint if exists credit_ledger_status_check;

alter table public.credit_ledger
  add constraint credit_ledger_status_check
  check (status in ('attempted', 'confirmed', 'no_match', 'failed'));
