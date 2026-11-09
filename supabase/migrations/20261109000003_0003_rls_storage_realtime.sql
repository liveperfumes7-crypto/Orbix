
alter table public.app_mode enable row level security;
alter table public.plan_catalog enable row level security;
alter table public.plans enable row level security;
alter table public.payment_settings enable row level security;
alter table public.play_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.admins enable row level security;
alter table public.admin_channel_access enable row level security;
alter table public.consents enable row level security;
alter table public.installs enable row level security;
alter table public.ad_clicks enable row level security;
alter table public.channels enable row level security;
alter table public.channel_members enable row level security;
alter table public.channel_folders enable row level security;
alter table public.posts enable row level security;
alter table public.post_items enable row level security;
alter table public.blocked_channels enable row level security;
alter table public.support_requests enable row level security;
alter table public.cloud_folders enable row level security;
alter table public.cloud_files enable row level security;
alter table public.subscriptions enable row level security;

-- config
create policy app_mode_read on public.app_mode for select to anon, authenticated using (true);
create policy app_mode_owner_update on public.app_mode for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy plan_catalog_read on public.plan_catalog for select to anon, authenticated using (true);
create policy plans_read on public.plans for select to anon, authenticated using (active or (select public.is_admin()));
create policy plans_owner_insert on public.plans for insert to authenticated with check ((select public.is_owner()));
create policy plans_owner_update on public.plans for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy payment_settings_owner_read on public.payment_settings for select to authenticated using ((select public.is_owner()));
create policy payment_settings_owner_update on public.payment_settings for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy play_settings_owner_read on public.play_settings for select to authenticated using ((select public.is_owner()));
create policy play_settings_owner_update on public.play_settings for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));

-- accounts
create policy profiles_read on public.profiles for select to authenticated using (id = (select auth.uid()) or (select public.is_admin()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy admins_read on public.admins for select to authenticated using (user_id = (select auth.uid()) or (select public.is_owner()));
create policy admins_owner_write on public.admins for all to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy admin_access_read on public.admin_channel_access for select to authenticated using (user_id = (select auth.uid()) or (select public.is_owner()));
create policy admin_access_owner_write on public.admin_channel_access for all to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy consents_read on public.consents for select to authenticated using (user_id = (select auth.uid()));
create policy consents_insert on public.consents for insert to authenticated with check (user_id = (select auth.uid()) and (select public.is_member()));
create policy subscriptions_read on public.subscriptions for select to authenticated using (user_id = (select auth.uid()) or (select public.is_admin()));

-- channels
create policy channels_select on public.channels for select to authenticated using (
  (select public.is_admin())
  or created_by = (select auth.uid())
  or (review_status = 'approved' and not hidden and status in ('published','active') and (select public.can_see_audience(audience)))
);
create policy channels_insert on public.channels for insert to authenticated with check (
  (select public.is_owner()) or ((select public.is_member()) and created_by = (select auth.uid()))
);
create policy channels_update on public.channels for update to authenticated
  using ((select public.can_manage_channel(id)) or created_by = (select auth.uid()))
  with check ((select public.can_manage_channel(id)) or created_by = (select auth.uid()));
create policy channels_delete on public.channels for delete to authenticated using ((select public.is_owner()));

create policy channel_members_select on public.channel_members for select to authenticated using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy channel_members_insert on public.channel_members for insert to authenticated with check (
  user_id = (select auth.uid()) and (select public.is_member()) and exists (select 1 from public.channels c where c.id = channel_id)
);
create policy channel_members_delete on public.channel_members for delete to authenticated using (user_id = (select auth.uid()));

create policy channel_folders_select on public.channel_folders for select to authenticated using (exists (select 1 from public.channels c where c.id = channel_id));
create policy channel_folders_write on public.channel_folders for all to authenticated
  using ((select public.can_manage_channel(channel_id))) with check ((select public.can_manage_channel(channel_id)));

create policy posts_select on public.posts for select to authenticated using (
  (select public.is_admin())
  or created_by = (select auth.uid())
  or (not hidden
      and (status = 'published' or (status = 'scheduled' and publish_at <= now()))
      and (select public.can_see_audience(audience))
      and exists (select 1 from public.channels c where c.id = posts.channel_id))
);
create policy posts_insert on public.posts for insert to authenticated with check (
  (select public.can_post_to_channel(channel_id))
  and ((select public.can_manage_channel(channel_id)) or (select public.has_consent()))
);
create policy posts_update on public.posts for update to authenticated
  using ((select public.can_edit_post(id))) with check ((select public.can_post_to_channel(channel_id)));
create policy posts_delete on public.posts for delete to authenticated using ((select public.can_edit_post(id)));

create policy post_items_select on public.post_items for select to authenticated using (exists (select 1 from public.posts p where p.id = post_items.post_id));
create policy post_items_write on public.post_items for all to authenticated
  using ((select public.can_edit_post(post_id))) with check ((select public.can_edit_post(post_id)));

create policy blocked_own on public.blocked_channels for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy support_owner_read on public.support_requests for select to authenticated using ((select public.is_owner()));
create policy support_owner_update on public.support_requests for update to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));

-- personal cloud
create policy cloud_folders_own on public.cloud_folders for all to authenticated
  using (user_id = (select auth.uid()) and (select public.is_member()))
  with check (user_id = (select auth.uid()) and (select public.is_member()));
create policy cloud_files_select on public.cloud_files for select to authenticated using (user_id = (select auth.uid()));
create policy cloud_files_insert on public.cloud_files for insert to authenticated with check (
  user_id = (select auth.uid()) and (select public.is_member())
  and (coalesce((select used_bytes from public.profiles where id = (select auth.uid())), 0) + size_bytes) <= (select public.quota_bytes())
);
create policy cloud_files_update on public.cloud_files for update to authenticated
  using (user_id = (select auth.uid()) and (select public.is_member()))
  with check (user_id = (select auth.uid()) and size_bytes = (select f.size_bytes from public.cloud_files f where f.id = cloud_files.id));
create policy cloud_files_delete on public.cloud_files for delete to authenticated using (user_id = (select auth.uid()));

-- ============ storage ============
insert into storage.buckets (id, name, public) values
  ('media','media',false), ('cloud','cloud',false), ('avatars','avatars',false),
  ('channel-icons','channel-icons',false), ('downloads','downloads',true)
on conflict (id) do nothing;

create policy media_select on storage.objects for select to authenticated using (
  bucket_id = 'media' and (
    (select public.is_admin())
    or exists (select 1 from public.post_items i
               where i.thumbnail_key = name or i.trailer_key = name
                  or (i.media_key = name and (not i.is_premium or (select public.can_full_premium()))))
  )
);
create policy media_insert on storage.objects for insert to authenticated with check (bucket_id = 'media' and (select public.can_write_channel_path(name)));
create policy media_update on storage.objects for update to authenticated using (bucket_id = 'media' and (select public.can_write_channel_path(name)));
create policy media_delete on storage.objects for delete to authenticated using (bucket_id = 'media' and (select public.can_write_channel_path(name)));

create policy icons_select on storage.objects for select to authenticated using (
  bucket_id = 'channel-icons' and ((select public.is_admin()) or (select public.can_write_channel_path(name))
    or exists (select 1 from public.channels c where c.icon_url = name))
);
create policy icons_insert on storage.objects for insert to authenticated with check (bucket_id = 'channel-icons' and (select public.can_write_channel_path(name)));
create policy icons_update on storage.objects for update to authenticated using (bucket_id = 'channel-icons' and (select public.can_write_channel_path(name)));
create policy icons_delete on storage.objects for delete to authenticated using (bucket_id = 'channel-icons' and (select public.can_write_channel_path(name)));

create policy cloud_obj_select on storage.objects for select to authenticated using (
  bucket_id = 'cloud' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()));
create policy cloud_obj_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'cloud' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member())
  and exists (select 1 from public.cloud_files f where f.user_id = (select auth.uid()) and f.storage_path = name));
create policy cloud_obj_update on storage.objects for update to authenticated using (
  bucket_id = 'cloud' and (storage.foldername(name))[1] = (select auth.uid())::text and (select public.is_member()));
create policy cloud_obj_delete on storage.objects for delete to authenticated using (
  bucket_id = 'cloud' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_own on storage.objects for all to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy downloads_owner_write on storage.objects for all to authenticated
  using (bucket_id = 'downloads' and (select public.is_owner()))
  with check (bucket_id = 'downloads' and (select public.is_owner()));

-- ============ realtime ============
alter publication supabase_realtime add table public.app_mode, public.plans, public.plan_catalog, public.profiles;
