-- NAGARIK — My Reports & Report Tracking upgrade: human-readable report
-- reference IDs, e.g. "NGR-2026-00001".
--
-- Run this in your Supabase project's SQL editor, after 0001_reports.sql
-- and 0002_report_images_bucket.sql. Safe to re-run (every statement below
-- is idempotent), same as the earlier migrations.
--
-- Design notes:
--
-- 1. The number resets to 00001 at the start of each calendar year (per
--    `report_reference_counters`, keyed by year) and is zero-padded to 5
--    digits, matching the "NGR-2026-00001" format. It does not reset per
--    category or city — one citywide counter per year is what the format
--    implies and is all that's needed to make the ID short and readable.
--
-- 2. The counter increment and the reference-id assignment both happen
--    inside a single `INSERT ... ON CONFLICT ... DO UPDATE ... RETURNING`
--    statement (see the trigger function below), which Postgres executes
--    atomically. Two reports submitted at the exact same instant by
--    different users still get two different, correctly-ordered numbers —
--    there's no separate "read the counter, then write it back" step that
--    a race condition could land between.
--
-- 3. The id is assigned by a BEFORE INSERT trigger, not by this backend's
--    Python code, and the trigger only fills it in when it's still null —
--    it is never touched by an UPDATE. That's what makes it "stable after
--    creation": nothing in this schema can change a report's reference_id
--    once the row exists, including a future status-transition feature.

-- 1. The column itself. Nullable for now so this statement is safe to run
--    against a table that already has rows (they're backfilled below,
--    immediately before the column is locked down to NOT NULL).
alter table public.reports add column if not exists reference_id text;

-- 2. One row per calendar year, holding "the last number handed out this
--    year". A single small table is simpler and easier to inspect/reset
--    than a dynamically-named-per-year Postgres SEQUENCE object, and gives
--    the same atomicity guarantee via its own primary key + ON CONFLICT.
create table if not exists public.report_reference_counters (
    year integer primary key,
    last_value integer not null default 0
);

-- 3. Backfill: any existing rows (created before this migration ran) get a
--    reference_id too, assigned in the order they were actually submitted
--    (oldest first), using the exact same per-year counter the trigger
--    below uses — so backfilled and newly-created IDs share one
--    continuous, correctly-ordered sequence per year. A fresh project with
--    an empty `reports` table simply does nothing here.
do $$
declare
    backfill_row record;
    assigned_value integer;
    row_year integer;
begin
    for backfill_row in
        select id, extract(year from created_at)::integer as created_year
        from public.reports
        where reference_id is null
        order by created_at asc
    loop
        row_year := backfill_row.created_year;

        insert into public.report_reference_counters (year, last_value)
        values (row_year, 1)
        on conflict (year) do update
            set last_value = public.report_reference_counters.last_value + 1
        returning last_value into assigned_value;

        update public.reports
        set reference_id = 'NGR-' || row_year::text || '-' || lpad(assigned_value::text, 5, '0')
        where id = backfill_row.id;
    end loop;
end;
$$ language plpgsql;

-- 4. Lock the column down now that every existing row has a value.
alter table public.reports alter column reference_id set not null;

-- A unique index both enforces uniqueness and serves as the lookup index —
-- no separate index needed. `create unique index if not exists` is
-- idempotent, unlike `add constraint`, which is why this is an index
-- rather than a named UNIQUE constraint.
create unique index if not exists reports_reference_id_key on public.reports (reference_id);

-- 5. From here on, every new report gets its reference_id assigned by this
-- trigger instead of the backfill loop above.
create or replace function public.set_report_reference_id()
returns trigger as $$
declare
    current_year integer := extract(year from now())::integer;
    assigned_value integer;
begin
    if new.reference_id is not null then
        return new;
    end if;

    insert into public.report_reference_counters (year, last_value)
    values (current_year, 1)
    on conflict (year) do update
        set last_value = public.report_reference_counters.last_value + 1
    returning last_value into assigned_value;

    new.reference_id := 'NGR-' || current_year::text || '-' || lpad(assigned_value::text, 5, '0');
    return new;
end;
$$ language plpgsql;

drop trigger if exists reports_set_reference_id on public.reports;
create trigger reports_set_reference_id
    before insert on public.reports
    for each row
    execute function public.set_report_reference_id();
