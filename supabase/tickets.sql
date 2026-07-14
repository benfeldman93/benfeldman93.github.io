-- ══════════════════════════════════════════════════════════════
-- TICKETS feature — run this once in the Supabase SQL editor
-- (Dashboard → SQL Editor → New query → paste → Run)
--
-- Adds: tickets table, ticket_passengers join table, RLS policies,
-- a public "tickets" storage bucket, and realtime publication.
-- Mirrors the conventions used by the existing expenses/todos tables
-- (client-generated uuid ids, group_id scoping, is_member_of RLS).
-- ══════════════════════════════════════════════════════════════

-- ── tables ──────────────────────────────────────────────────────
create table if not exists public.tickets (
  id              uuid primary key,
  group_id        uuid not null references public.groups(id) on delete cascade,
  created_by      uuid not null references auth.users(id),
  kind            text not null default 'flight',   -- flight | train | bus | other
  title           text,                             -- optional label, e.g. "Outbound flight"
  from_loc        text,
  to_loc          text,
  depart_date     date,
  depart_time     text,
  arrive_date     date,
  arrive_time     text,
  confirmation    text,
  seat            text,
  notes           text,
  price           numeric,
  currency        text default 'USD',
  cost_expense_id uuid references public.expenses(id) on delete set null,
  file_url        text,
  shared          boolean not null default true,
  created_at      timestamptz not null default now()
);

create table if not exists public.ticket_passengers (
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  user_id   uuid not null references auth.users(id),
  primary key (ticket_id, user_id)
);

create index if not exists tickets_group_idx     on public.tickets(group_id);
create index if not exists ticket_pax_ticket_idx on public.ticket_passengers(ticket_id);

-- ── row level security ──────────────────────────────────────────
alter table public.tickets           enable row level security;
alter table public.ticket_passengers enable row level security;

-- tickets: visible to group members if shared, or to the creator always
drop policy if exists tickets_select on public.tickets;
create policy tickets_select on public.tickets
  for select using (
    public.is_member_of(group_id)
    and (shared or created_by = auth.uid())
  );

drop policy if exists tickets_insert on public.tickets;
create policy tickets_insert on public.tickets
  for insert with check (
    public.is_member_of(group_id) and created_by = auth.uid()
  );

drop policy if exists tickets_update on public.tickets;
create policy tickets_update on public.tickets
  for update using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists tickets_delete on public.tickets;
create policy tickets_delete on public.tickets
  for delete using (created_by = auth.uid());

-- passengers: readable when the parent ticket is readable; managed by the ticket owner
drop policy if exists ticket_pax_select on public.ticket_passengers;
create policy ticket_pax_select on public.ticket_passengers
  for select using (
    exists (
      select 1 from public.tickets t
      where t.id = ticket_id
        and public.is_member_of(t.group_id)
        and (t.shared or t.created_by = auth.uid())
    )
  );

drop policy if exists ticket_pax_write on public.ticket_passengers;
create policy ticket_pax_write on public.ticket_passengers
  for all using (
    exists (select 1 from public.tickets t where t.id = ticket_id and t.created_by = auth.uid())
  )
  with check (
    exists (select 1 from public.tickets t where t.id = ticket_id and t.created_by = auth.uid())
  );

-- ── realtime ────────────────────────────────────────────────────
alter publication supabase_realtime add table public.tickets;
alter publication supabase_realtime add table public.ticket_passengers;

-- ── storage bucket for ticket files (PDF / images) ──────────────
insert into storage.buckets (id, name, public)
values ('tickets', 'tickets', true)
on conflict (id) do nothing;

-- allow any logged-in user to upload/read/replace files in the tickets bucket
-- (paths are unguessable uuids, same model as the receipts bucket)
drop policy if exists "tickets read"   on storage.objects;
create policy "tickets read" on storage.objects
  for select using (bucket_id = 'tickets');

drop policy if exists "tickets insert" on storage.objects;
create policy "tickets insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'tickets');

drop policy if exists "tickets update" on storage.objects;
create policy "tickets update" on storage.objects
  for update to authenticated using (bucket_id = 'tickets');
