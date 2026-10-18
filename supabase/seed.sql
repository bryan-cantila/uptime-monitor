-- ============================================================
-- Uptime Monitor — DEMO seed data (optional)
-- These rows are clearly-labeled demo content so you can see the
-- dashboard with data before adding your own monitors.
--
-- HOW TO USE: replace 'YOUR_USER_UUID' with your own auth.users id
-- (find it in Supabase Dashboard → Authentication → Users), then run.
-- Delete the demo rows any time: they are yours, under your user_id.
-- ============================================================

-- \set demo_user 'YOUR_USER_UUID'  -- psql-style hint; paste the UUID below

-- Demo monitors (2)
insert into public.monitors (user_id, name, url, interval_minutes, expected_status)
values
  ('YOUR_USER_UUID', 'Demo — example.com',  'https://example.com',  5, 200),
  ('YOUR_USER_UUID', 'Demo — httpstat.us',  'https://httpstat.us/200', 5, 200)
on conflict do nothing;

-- Demo checks: a believable 24h of 5-minute samples for the first demo monitor.
-- (Supabase SQL editor: run once. n8n will append real rows afterwards.)
with m as (
  select id from public.monitors
  where user_id = 'YOUR_USER_UUID' and name = 'Demo — example.com' limit 1
)
insert into public.checks (monitor_id, checked_at, status_code, response_time_ms, is_up, error)
select m.id,
       now() - (g * interval '5 minutes'),
       case when (g % 97) = 0 then 500 else 200 end,          -- one blip every ~8h
       80 + ((g * 37) % 220),                                 -- 80–300 ms jitter
       (g % 97) <> 0,
       case when (g % 97) = 0 then 'HTTP 500 from origin' end
from m, generate_series(0, 287) g;

-- Demo resolved incident matching that blip
with m as (
  select id from public.monitors
  where user_id = 'YOUR_USER_UUID' and name = 'Demo — example.com' limit 1
)
insert into public.incidents (monitor_id, started_at, resolved_at, downtime_seconds)
select m.id, now() - interval '8 hours', now() - interval '8 hours' + interval '5 minutes', 300
from m;

-- Demo alert target (Telegram shape — fill in your own bot token + chat id)
insert into public.alert_targets (user_id, type, label, config)
values ('YOUR_USER_UUID', 'telegram', 'Demo — my Telegram',
        '{"bot_token": "PUT_YOUR_BOT_TOKEN_HERE", "chat_id": "PUT_YOUR_CHAT_ID_HERE"}')
on conflict do nothing;
