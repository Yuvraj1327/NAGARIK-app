-- NAGARIK — owner-only edit/delete of reports and their images.
--
-- Run after 0001/0002. The backend uses the service-role key (bypasses RLS)
-- and enforces ownership itself; these policies are the database-level
-- defense-in-depth for the same rules.

-- 0001 created an UPDATE policy with only USING; add WITH CHECK so an owner
-- can't reassign a report to someone else.
drop policy if exists "Users can update their own reports" on public.reports;
create policy "Users can update their own reports"
    on public.reports for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own reports" on public.reports;
create policy "Users can delete their own reports"
    on public.reports for delete
    using (auth.uid() = user_id);

drop policy if exists "Users can delete their own report images" on storage.objects;
create policy "Users can delete their own report images"
    on storage.objects for delete
    using (
        bucket_id = 'report-images'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
