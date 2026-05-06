-- ============================================================
-- MediGuard — Supabase Migration
-- Run once in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================


-- ── Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";


-- ── Users ────────────────────────────────────────────────────
-- Extends Supabase auth.users (do NOT replace it)
create table public.users (
  id                  uuid primary key references auth.users(id) on delete cascade,
  name                text not null,
  phone               text,
  language            text not null default 'zh-TW',
  apns_token          text,
  emergency_contacts  jsonb not null default '[]',
  created_at          timestamptz not null default now()
);

-- Auto-create row when user registers via Supabase Auth
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'User'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ── Medications ───────────────────────────────────────────────
create table public.medications (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid not null references public.users(id) on delete cascade,
  name              text not null,
  name_zh           text,
  dosage            text,
  drug_info         jsonb,           -- {main_effects, side_effects, warnings, elderly_notes, interactions, source}
  source_image_url  text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now()
);


-- ── Schedules ─────────────────────────────────────────────────
create table public.schedules (
  id              uuid primary key default uuid_generate_v4(),
  medication_id   uuid not null references public.medications(id) on delete cascade,
  user_id         uuid not null references public.users(id) on delete cascade,
  times           text[] not null,      -- e.g. {"08:00","20:00"}
  days_of_week    int[],                -- NULL = every day, else [1..7]
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);


-- ── Medication Logs ───────────────────────────────────────────
create table public.medication_logs (
  id                uuid primary key default uuid_generate_v4(),
  schedule_id       uuid not null references public.schedules(id) on delete cascade,
  user_id           uuid not null references public.users(id) on delete cascade,
  status            text not null check (status in ('taken', 'skipped', 'pending')),
  scheduled_at      timestamptz,
  taken_at          timestamptz,
  monitoring_start  timestamptz,
  monitoring_end    timestamptz,
  created_at        timestamptz not null default now()
);


-- ── Health Events ─────────────────────────────────────────────
create table public.health_events (
  id                    uuid primary key default uuid_generate_v4(),
  user_id               uuid not null references public.users(id) on delete cascade,
  medication_log_id     uuid not null references public.medication_logs(id) on delete cascade,
  timestamp             timestamptz not null,
  anomaly_level         int not null check (anomaly_level in (0, 1, 2)),
  anomaly_type          text not null,
  core_ml_confidence    float not null,
  resolved_at           timestamptz,
  created_at            timestamptz not null default now()
);


-- ── Alert Logs ────────────────────────────────────────────────
create table public.alert_logs (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid not null references public.users(id) on delete cascade,
  health_event_id   uuid not null references public.health_events(id) on delete cascade,
  level             int not null check (level in (1, 2, 3)),  -- 1=push 2=iMessage 3=call
  sent_at           timestamptz not null default now(),
  responded_at      timestamptz,
  response          text check (response in ('ok', 'no_response'))
);


-- ============================================================
-- Row Level Security (RLS)
-- Each user can only read/write their own data
-- ============================================================

alter table public.users              enable row level security;
alter table public.medications        enable row level security;
alter table public.schedules          enable row level security;
alter table public.medication_logs    enable row level security;
alter table public.health_events      enable row level security;
alter table public.alert_logs         enable row level security;

-- users
create policy "users: own row only"
  on public.users for all
  using (id = auth.uid());

-- medications
create policy "medications: own rows only"
  on public.medications for all
  using (user_id = auth.uid());

-- schedules
create policy "schedules: own rows only"
  on public.schedules for all
  using (user_id = auth.uid());

-- medication_logs
create policy "logs: own rows only"
  on public.medication_logs for all
  using (user_id = auth.uid());

-- health_events
create policy "health_events: own rows only"
  on public.health_events for all
  using (user_id = auth.uid());

-- alert_logs
create policy "alert_logs: own rows only"
  on public.alert_logs for all
  using (user_id = auth.uid());


-- ============================================================
-- Indexes (query performance)
-- ============================================================

create index on public.medications        (user_id, is_active);
create index on public.schedules          (user_id, is_active);
create index on public.medication_logs    (user_id, status);
create index on public.medication_logs    (schedule_id);
create index on public.health_events      (user_id, resolved_at);
create index on public.health_events      (medication_log_id);
create index on public.alert_logs         (health_event_id);
