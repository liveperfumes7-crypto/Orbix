
drop policy cloud_files_insert on public.cloud_files;
create policy cloud_files_insert on public.cloud_files for insert to authenticated with check (
  user_id = (select auth.uid()) and (select public.is_member())
  and (coalesce((select used_bytes from public.profiles where id = (select auth.uid())), 0) + size_bytes) <= (select public.quota_bytes())
);
