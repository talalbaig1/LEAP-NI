-- 004_entities

create table if not exists public.extraction_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  capture_id uuid not null references public.captures (id),
  model text,
  prompt_version text,
  raw_vision_output jsonb,
  raw_transcript text,
  structured_output jsonb,
  flag_reasons text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  full_name text,
  name_original_script text,
  title text,
  email text,
  email_normalized text generated always as (lower(trim(email))) stored,
  phone text,
  linkedin_url text,
  linkedin_url_normalized text generated always as (
    lower(regexp_replace(trim(linkedin_url), '/+$', ''))
  ) stored,
  review_status text not null default 'unreviewed',
  source_type text,
  created_at timestamptz not null default now(),
  constraint people_review_status_check
    check (review_status in ('unreviewed', 'approved', 'needs_review')),
  constraint people_source_type_check
    check (source_type is null or source_type in (
      'card', 'voice_note', 'typed_note', 'photo', 'enrichment'
    ))
);

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  name text not null,
  normalized_name text,
  domain text,
  industry text,
  enrichment_status text not null default 'none',
  created_at timestamptz not null default now(),
  constraint companies_enrichment_status_check
    check (enrichment_status in ('none', 'pending', 'enriched', 'no_match', 'failed'))
);

create table if not exists public.person_companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  person_id uuid not null references public.people (id),
  company_id uuid not null references public.companies (id),
  role_title text,
  is_current boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.interactions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  capture_id uuid references public.captures (id),
  person_id uuid references public.people (id),
  company_id uuid references public.companies (id),
  occurred_at timestamptz not null default now(),
  summary text,
  topics text[] not null default '{}',
  opportunities text[] not null default '{}',
  importance smallint,
  created_at timestamptz not null default now()
);

create table if not exists public.follow_ups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  interaction_id uuid references public.interactions (id),
  person_id uuid references public.people (id),
  title text not null,
  due_at timestamptz,
  priority text not null default 'medium',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  constraint follow_ups_priority_check
    check (priority in ('low', 'medium', 'high')),
  constraint follow_ups_status_check
    check (status in ('open', 'done', 'cancelled'))
);
