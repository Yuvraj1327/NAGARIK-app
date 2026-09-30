-- NAGARIK — Official Logo & User Profile Photo upgrade: Supabase Storage
-- bucket for user profile photos.
--
-- Run this in your Supabase project's SQL editor, after 0001-0004. The
-- bucket is PRIVATE (public = false), same as report-images — a raw path
-- isn't fetchable by a client; the backend hands back a freshly signed URL
-- instead (see app/services/profile_service.py).
--
-- Bucket id must match backend/.env's SUPABASE_AVATAR_BUCKET
-- (default: 'avatars').

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- Objects are stored as "<user_id>/avatar.<ext>" (see
-- app/services/profile_service.py) — one photo per user, replaced in place
-- rather than accumulating like report images — so
-- `storage.foldername(name)`'s first segment is the owning user's id, same
-- convention as 0002_report_images_bucket.sql. As with every other bucket
-- here, the backend's service-role key bypasses these policies; they're
-- defense-in-depth for any path that ever queries Storage with the
-- anon/authenticated key instead.
create policy "Users can upload their own avatar"
    on storage.objects for insert
    with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "Users can read their own avatar"
    on storage.objects for select
    using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "Users can replace their own avatar"
    on storage.objects for update
    using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "Users can remove their own avatar"
    on storage.objects for delete
    using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
