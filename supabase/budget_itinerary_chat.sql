-- ══════════════════════════════════════════════════════════════
-- BUDGET + ITINERARY + CHAT — run once in the Supabase SQL editor
-- (Dashboard → SQL Editor → New query → paste → Run)
-- ══════════════════════════════════════════════════════════════

-- ── BUDGET: one shared budget per group, stored on the group row ──
alter table public.groups add column if not exists budget jsonb not null default '{}'::jsonb;

-- ── ITINERARY: collaborative day-by-day plan (any member can edit) ──
create table if not exists public.itinerary_items (
  id         uuid primary key,
  group_id   uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  title      text,
  day        date,
  time       text,
  location   text,
  notes      text,
  position   double precision not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists itin_group_idx on public.itinerary_items(group_id);
alter table public.itinerary_items enable row level security;

drop policy if exists itin_select on public.itinerary_items;
create policy itin_select on public.itinerary_items
  for select using (public.is_member_of(group_id));
drop policy if exists itin_insert on public.itinerary_items;
create policy itin_insert on public.itinerary_items
  for insert with check (public.is_member_of(group_id) and created_by = auth.uid());
drop policy if exists itin_update on public.itinerary_items;
create policy itin_update on public.itinerary_items
  for update using (public.is_member_of(group_id)) with check (public.is_member_of(group_id));
drop policy if exists itin_delete on public.itinerary_items;
create policy itin_delete on public.itinerary_items
  for delete using (public.is_member_of(group_id));

alter publication supabase_realtime add table public.itinerary_items;

-- ── CHAT: group messages ──
create table if not exists public.messages (
  id         uuid primary key,
  group_id   uuid not null references public.groups(id) on delete cascade,
  user_id    uuid not null references auth.users(id),
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists messages_group_idx on public.messages(group_id, created_at);
alter table public.messages enable row level security;

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select using (public.is_member_of(group_id));
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert with check (public.is_member_of(group_id) and user_id = auth.uid());
drop policy if exists messages_delete on public.messages;
create policy messages_delete on public.messages
  for delete using (user_id = auth.uid());

alter publication supabase_realtime add table public.messages;
