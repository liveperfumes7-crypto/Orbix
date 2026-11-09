
drop policy admins_owner_write on public.admins;
create policy admins_owner_insert on public.admins for insert to authenticated with check ((select public.is_owner()));
create policy admins_owner_update on public.admins for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy admins_owner_delete on public.admins for delete to authenticated using ((select public.is_owner()));

drop policy admin_access_owner_write on public.admin_channel_access;
create policy admin_access_owner_insert on public.admin_channel_access for insert to authenticated with check ((select public.is_owner()));
create policy admin_access_owner_update on public.admin_channel_access for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy admin_access_owner_delete on public.admin_channel_access for delete to authenticated using ((select public.is_owner()));

drop policy channel_folders_write on public.channel_folders;
create policy channel_folders_insert on public.channel_folders for insert to authenticated with check ((select public.can_manage_channel(channel_id)));
create policy channel_folders_update on public.channel_folders for update to authenticated using ((select public.can_manage_channel(channel_id))) with check ((select public.can_manage_channel(channel_id)));
create policy channel_folders_delete on public.channel_folders for delete to authenticated using ((select public.can_manage_channel(channel_id)));

drop policy post_items_write on public.post_items;
create policy post_items_insert on public.post_items for insert to authenticated with check ((select public.can_edit_post(post_id)));
create policy post_items_update on public.post_items for update to authenticated using ((select public.can_edit_post(post_id))) with check ((select public.can_edit_post(post_id)));
create policy post_items_delete on public.post_items for delete to authenticated using ((select public.can_edit_post(post_id)));
