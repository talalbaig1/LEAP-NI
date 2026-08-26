-- 002_events_bot_state

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  location text,
  timezone text not null,
  created_at timestamptz not null default now(),
  unique (owner_id, name)
);

create table if not exists public.bot_state (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  telegram_user_id bigint not null,
  open_capture_id uuid,
  mode text not null default 'normal',
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (owner_id, telegram_user_id),
  constraint bot_state_mode_check
    check (mode in ('normal', 'batch'))
);
