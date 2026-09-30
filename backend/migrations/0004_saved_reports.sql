-- NAGARIK — Report Sharing, Saved Reports & Final Feature Polish.
--
-- Run this in your Supabase project's SQL editor (Dashboard -> SQL Editor)
-- after 0001-0003. This backend cannot run migrations against your project
-- itself — it only has your service-role key at runtime, not a way to
-- execute DDL you haven't reviewed and approved.

create table if not exists public.saved_reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    report_id uuid not null references public.reports(id) on delete cascade,
    created_at timestamptz not null default now(),
    -- The actual duplicate-save guard: a second `POST /reports/{id}/save`
    -- for the same user+report hits this constraint (Postgres error
    -- `23505`), which `reports_service.save_report` catches and treats as
    -- success rather than an error — saving an already-saved report should
    -- behave the same as saving it the first time, from the caller's POV.
    unique (user_id, report_id)
);

create index if not exists saved_reports_user_id_idx on public.saved_reports (user_id);
create index if not exists saved_reports_report_id_idx on public.saved_reports (report_id);

-- Row Level Security: enabled as defense-in-depth, same reasoning as
-- `0001_reports.sql` — the backend always talks to Supabase with the
-- SERVICE ROLE key, which bypasses RLS entirely, so these policies only
-- matter if this table is ever queried with the anon/authenticated key
-- directly. They're what makes "users can only manage their own saved
-- records" true even in that case, not just an application-layer promise.
alter table public.saved_reports enable row level security;

create policy "Users can view their own saved reports"
    on public.saved_reports for select
    using (auth.uid() = user_id);

create policy "Users can save reports for themselves"
    on public.saved_reports for insert
    with check (auth.uid() = user_id);

create policy "Users can remove their own saved reports"
    on public.saved_reports for delete
    using (auth.uid() = user_id);
