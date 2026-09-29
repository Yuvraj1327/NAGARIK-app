-- NAGARIK — Step 5/6: reports table.
--
-- Run this in your Supabase project's SQL editor (Dashboard -> SQL Editor)
-- before testing report creation. This backend cannot run migrations
-- against your project itself — it only has your service-role key at
-- runtime, not a way to execute DDL you haven't reviewed and approved.

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    category text not null check (
        category in ('road', 'streetlight', 'sanitation', 'water', 'electricity', 'safety', 'other')
    ),
    description text not null,
    city text not null,
    pin_code text not null check (pin_code ~ '^[0-9]{6}$'),
    latitude double precision,
    longitude double precision,
    image_paths text[] not null default '{}',
    status text not null default 'submitted' check (
        status in ('submitted', 'in_review', 'resolved')
    ),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists reports_user_id_idx on public.reports (user_id);
create index if not exists reports_city_idx on public.reports (city);
create index if not exists reports_pin_code_idx on public.reports (pin_code);
create index if not exists reports_status_idx on public.reports (status);
create index if not exists reports_category_idx on public.reports (category);

-- Keeps updated_at current on every UPDATE. Nothing updates a report row
-- yet in Step 5/6 (reports are insert-only so far), but Step 8's status
-- transitions will rely on this being in place already.
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
    before update on public.reports
    for each row
    execute function public.set_updated_at();

-- Row Level Security: enabled as defense-in-depth. The backend always
-- talks to Supabase with the SERVICE ROLE key (see
-- backend/app/integrations/supabase_client.py), which bypasses RLS
-- entirely — these policies only matter if this table is ever queried
-- with the anon/authenticated key directly (e.g. during local debugging
-- in the Supabase dashboard, or if a future client-side integration is
-- added), and make sure that path can't do more than the backend does.
alter table public.reports enable row level security;

create policy "Reports are publicly readable"
    on public.reports for select
    using (true);

create policy "Users can insert their own reports"
    on public.reports for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own reports"
    on public.reports for update
    using (auth.uid() = user_id);
