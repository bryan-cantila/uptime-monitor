-- ============================================================
-- Uptime Monitor — initial schema (Supabase / PostgreSQL)
-- Run this in the Supabase SQL editor (one paste, top to bottom).
-- ============================================================

-- ---------- tables ----------

create table public.monitors (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references auth.users(id) on delete cascade not null,
  name             text not null,
  url              text not null,
  interval_minutes int not null default 5 check (interval_minutes >= 1),
  expected_status  int not null default 200,
  timeout_ms       int not null default 10000 check (timeout_ms >= 1000),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);

create table public.checks (
  id               bigint generated always as identity primary key,
  monitor_id       uuid references public.monitors(id) on delete cascade not null,
  checked_at       timestamptz not null default now(),
  status_code      int,
  response_time_ms int,
  is_up            boolean not null,
  error            text
);
create index checks_monitor_time_idx on public.checks (monitor_id, checked_at desc);

create table public.incidents (
  id               uuid primary key default gen_random_uuid(),
  monitor_id       uuid references public.monitors(id) on delete cascade not null,
  started_at       timestamptz not null default now(),
  resolved_at      timestamptz,
  downtime_seconds int
);

create table public.alert_targets (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade not null,
  type       text not null check (type in ('telegram','email','webhook')),
  label      text not null,
  config     jsonb not null default '{}'::jsonb,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);
-- config shapes (never store secrets anywhere else):
--   telegram: {"bot_token": "...", "chat_id": "..."}
--   email:    {"to": "you@example.com"}            (SMTP creds live in n8n)
--   webhook:  {"url": "https://..."}               (signing secret optional: {"secret": "..."})

-- ---------- row level security ----------
-- NOTE: n8n talks to Supabase with the service_role key, which BYPASSES
-- RLS entirely. These policies only constrain the anon/authenticated keys
-- used by the dashboard, so each user sees only their own rows.

alter table public.monitors      enable row level security;
alter table public.checks        enable row level security;
alter table public.incidents     enable row level security;
alter table public.alert_targets enable row level security;

-- monitors: owners manage their own
create policy monitors_owner_all on public.monitors
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- checks: ownership flows through the parent monitor
create policy checks_owner_read on public.checks
  for select to authenticated
  using (exists (
    select 1 from public.monitors m
    where m.id = checks.monitor_id and m.user_id = auth.uid()
  ));
-- (writes come from n8n via service_role; dashboard never writes checks)

-- incidents: ownership flows through the parent monitor
create policy incidents_owner_read on public.incidents
  for select to authenticated
  using (exists (
    select 1 from public.monitors m
    where m.id = incidents.monitor_id and m.user_id = auth.uid()
  ));
-- (writes come from n8n via service_role; dashboard never writes incidents)

-- alert targets: owners manage their own
create policy alert_targets_owner_all on public.alert_targets
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------- realtime ----------
alter publication supabase_realtime add table public.checks;
alter publication supabase_realtime add table public.incidents;
