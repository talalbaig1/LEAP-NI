-- 005_review_support

create table if not exists public.entity_candidates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  entity_type text not null,
  candidate_entity_id uuid not null,
  score numeric,
  reasons text[] not null default '{}',
  decision text not null default 'pending',
  created_at timestamptz not null default now(),
  constraint entity_candidates_decision_check
    check (decision in ('pending', 'accepted', 'rejected'))
);

create table if not exists public.field_corrections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  entity_type text not null,
  entity_id uuid not null,
  field text not null,
  model_value text,
  corrected_value text,
  corrected_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.enrichment_records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  entity_type text,
  entity_id uuid,
  provider text not null,
  payload jsonb not null default '{}'::jsonb,
  confidence numeric,
  fetched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint enrichment_records_provider_check
    check (provider in ('apollo', 'tavily'))
);

create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  provider text not null,
  credits_spent integer not null,
  operation text not null,
  entity_id uuid,
  spent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  actor_type text not null,
  action text not null,
  entity_type text,
  before jsonb,
  after jsonb,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  constraint audit_log_actor_type_check
    check (actor_type in ('user', 'ai', 'system'))
);
