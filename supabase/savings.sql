-- ══════════════════════════════════════════════════════════════
-- SAVINGS feature — run this once in the Supabase SQL editor
-- (Dashboard → SQL Editor → New query → paste → Run)
--
-- A single PRIVATE savings plan per user (global, not per-group).
-- Only the owner can ever read or write their row. Group mates
-- never see any of this. Everything (income, expense categories,
-- stacks/goals, windfalls, assumptions) lives in one row as JSONB
-- so there are no joins and no shared visibility.
-- ══════════════════════════════════════════════════════════════

create table if not exists public.savings_profiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  net_income   numeric,                              -- monthly take-home
  income_note  text,
  expenses     jsonb not null default '[]'::jsonb,   -- [{id,name,amount}]
  stacks       jsonb not null default '[]'::jsonb,   -- [{id,name,kind,target,balance,apy,monthly,priority,tripGroupId,note}]
  windfalls    jsonb not null default '[]'::jsonb,   -- [{id,name,amount,stackId,month}]
  assumptions  jsonb not null default '{}'::jsonb,   -- {hysaApy,investReturn,horizonMonths}
  updated_at   timestamptz not null default now()
);

alter table public.savings_profiles enable row level security;

-- owner-only access, all four verbs
drop policy if exists savings_select on public.savings_profiles;
create policy savings_select on public.savings_profiles
  for select using (user_id = auth.uid());

drop policy if exists savings_insert on public.savings_profiles;
create policy savings_insert on public.savings_profiles
  for insert with check (user_id = auth.uid());

drop policy if exists savings_update on public.savings_profiles;
create policy savings_update on public.savings_profiles
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists savings_delete on public.savings_profiles;
create policy savings_delete on public.savings_profiles
  for delete using (user_id = auth.uid());
