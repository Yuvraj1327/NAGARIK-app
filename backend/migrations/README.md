# Running these migrations

This backend never runs DDL against your Supabase project on its own — it
only holds your service-role key at runtime for normal queries, not a way
to execute schema changes you haven't reviewed. You apply these once,
yourself, in the Supabase Dashboard's **SQL Editor** (Project -> SQL
Editor -> New query), **in order**:

1. `0001_reports.sql` — creates the `reports` table (columns, check
   constraints, indexes, the `updated_at` trigger, and RLS policies).
2. `0002_report_images_bucket.sql` — creates the private `report-images`
   Storage bucket and its per-user-folder RLS policies.
3. `0003_report_reference_id.sql` — adds the human-readable `reference_id`
   column (e.g. `NGR-2026-00001`), backfills it for any reports that
   already exist, and adds the trigger that assigns it to every future
   report. **Required before using the My Reports / Report Tracking
   upgrade** — without it, every report response is missing
   `reference_id`, which the API schema now requires.

Paste each file's full contents into the SQL Editor and click **Run**, in
order (0001, then 0002, then 0003). All three are safe to re-run (`create
table if not exists`, `create index if not exists`, `on conflict (id) do
nothing`, and 0003's backfill only touches rows that still have a null
`reference_id`) — running any of them again is a no-op, not an error, so if
you're not sure whether one already applied, just run it again.

There's no separate migration for a `profiles`/`users` table because
there isn't one: `GET /api/v1/users/me` reads `email` and `full_name`
straight out of the caller's verified Supabase Auth JWT (`full_name` is
what the Flutter app passed as `signUp()`'s `data: {'full_name': ...}`,
stored by Supabase Auth itself in `auth.users.raw_user_meta_data`) — no
database round-trip and nothing extra to create.

## "Could not find the table 'public.reports' in the schema cache" (PGRST205)

This means PostgREST — the layer Supabase's REST API and this backend's
`supabase-py` client both go through — doesn't have a `reports` table in
its cached schema. Two different causes produce the exact same message:

**1. The migration was never actually run against this project.** Open
Supabase Dashboard -> **Table Editor** and check whether `reports` is
listed under the `public` schema. If it isn't, run `0001_reports.sql` (and
then `0002_report_images_bucket.sql`) as above — this is by far the most
common cause, especially the first time you're setting the project up, or
if `.env`'s `SUPABASE_URL`/keys point at a different Supabase project than
the one you ran the SQL against.

**2. The table exists, but PostgREST's schema cache is stale.** PostgREST
normally reloads automatically within a few seconds of a DDL change
(Supabase's Postgres sends it a `NOTIFY`), but if a request lands in that
window — or the auto-reload notification was missed for any reason — the
error can persist. Force a reload with either:

- Dashboard -> **Database** -> **API** -> **Reload schema cache** button, or
- running `NOTIFY pgrst, 'reload schema';` in the SQL Editor.

If neither clears it within a minute, double-check `SUPABASE_URL` in
`backend/.env` actually matches the project you just ran the migration
against (a copy-pasted URL from an old/other project is a common way to
see "the table isn't there" when it very much is, just in a different
project).

As of this fix, the API itself also distinguishes this from other
failures: a request that hits `PGRST205` (or the related `PGRST204`/
`PGRST202`/`42P01`) now gets a `503` with a message pointing back here,
instead of a generic `500`/`502` — see
`app/services/reports_service.py`'s `_raise_for_supabase_error`.
