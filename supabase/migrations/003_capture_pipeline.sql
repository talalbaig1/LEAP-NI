-- 003_capture_pipeline

create table if not exists public.captures (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  event_id uuid not null references public.events (id),
  status text not null default 'open',
  capture_mode text not null default 'standard',
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  close_reason text,
  typed_note text,
  flags jsonb not null default '[]'::jsonb,
  card_only boolean not null default false,
  created_at timestamptz not null default now(),
  constraint captures_status_check
    check (status in ('open', 'processing', 'ready', 'needs_review', 'failed')),
  constraint captures_close_reason_check
    check (close_reason is null or close_reason in ('explicit', 'superseded', 'auto')),
  constraint captures_capture_mode_check
    check (capture_mode in ('standard', 'batch'))
);

alter table public.bot_state
  drop constraint if exists bot_state_open_capture_id_fkey;

alter table public.bot_state
  add constraint bot_state_open_capture_id_fkey
  foreign key (open_capture_id) references public.captures (id);

create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  capture_id uuid not null references public.captures (id),
  kind text not null,
  storage_path text,
  telegram_file_unique_id text,
  sha256 text,
  mime_type text,
  size_bytes bigint,
  upload_status text not null default 'pending',
  created_at timestamptz not null default now(),
  constraint assets_kind_check
    check (kind in ('business_card', 'audio', 'photo', 'selfie', 'document')),
  constraint assets_upload_status_check
    check (upload_status in ('pending', 'stored', 'failed')),
  constraint assets_telegram_file_unique_id_key unique (telegram_file_unique_id)
);

create table if not exists public.processing_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  capture_id uuid not null references public.captures (id),
  asset_id uuid references public.assets (id),
  job_type text not null,
  status text not null default 'queued',
  attempt_count integer not null default 0,
  provider text,
  provider_request_id text,
  error_code text,
  error_detail jsonb,
  output jsonb,
  created_at timestamptz not null default now(),
  constraint processing_jobs_status_check
    check (status in ('queued', 'running', 'succeeded', 'failed', 'needs_review')),
  constraint processing_jobs_job_type_check
    check (job_type in (
      'card_vision',
      'transcription',
      'photo_description',
      'extraction',
      'entity_resolution',
      'enrichment'
    ))
);
