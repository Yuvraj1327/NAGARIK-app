-- NAGARIK — Step 6: Supabase Storage bucket for report images.
--
-- Run this in your Supabase project's SQL editor, after 0001_reports.sql.
-- The bucket is PRIVATE (public = false): objects aren't readable by a
-- bare URL. Serving images back to the app (with signed URLs) is added
-- when Step 7 builds report retrieval — Step 6 only needs upload to work.
--
-- Bucket id must match backend/.env's SUPABASE_STORAGE_BUCKET
-- (default: 'report-images').

insert into storage.buckets (id, name, public)
values ('report-images', 'report-images', false)
on conflict (id) do nothing;

-- Objects are stored as "<user_id>/<uuid>.<ext>" (see
-- backend/app/services/reports_service.py), so `storage.foldername(name)`'s
-- first segment is the uploading user's id — these policies restrict each
-- user to their own folder. As with the reports table, the backend's
-- service-role key bypasses these; they're defense-in-depth for any path
-- that ever queries Storage with the anon/authenticated key.
create policy "Users can upload their own report images"
    on storage.objects for insert
    with check (
        bucket_id = 'report-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "Users can read their own report images"
    on storage.objects for select
    using (
        bucket_id = 'report-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
