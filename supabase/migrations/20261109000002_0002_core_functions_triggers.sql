
-- ============ helpers (public, executable by authenticated only; see grants at end) ============
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

create function public.is_owner() returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.admins where user_id = auth.uid() and role = 'owner') $$;

create function public.is_member() returns boolean language sql stable security definer set search_path = '' as
$$ select auth.uid() is not null and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false $$;

create function public.source_of(p_uid uuid default auth.uid()) returns text language sql stable security definer set search_path = '' as
$$ select coalesce((select source from private.user_sources where user_id = p_uid), 'organic') $$;

create function public.is_free_mode() returns boolean language sql stable security definer set search_path = '' as
$$ select free_mode from public.app_mode where id = 1 $$;

create function public.has_plan(p_uid uuid default auth.uid()) returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.subscriptions where user_id = p_uid and not revoked and ends_at > now()) $$;

create function public.has_ads_access(p_uid uuid default auth.uid()) returns boolean language sql stable security definer set search_path = '' as
$$
 select case
   when p_uid is null then false
   when exists (select 1 from public.admins where user_id = p_uid) then true
   when public.source_of(p_uid) = 'ads' then true
   else coalesce((select ads_access_status = 'approved' from public.profiles where id = p_uid), false)
        and ((select free_mode from public.app_mode where id = 1) or public.has_plan(p_uid))
 end
$$;

create function public.plans_visible_for_me() returns boolean language sql stable security definer set search_path = '' as
$$
 select public.is_admin() or coalesce(
   case (select plans_visible_for from public.app_mode where id = 1)
     when 'everyone' then true
     when 'none' then false
     when 'ads' then public.source_of() = 'ads'
     when 'organic' then public.source_of() = 'organic'
   end, false)
$$;

create function public.free_plan_for_me(p_plan uuid) returns boolean language sql stable security definer set search_path = '' as
$$
 select public.plans_visible_for_me()
   and not (select free_mode from public.app_mode where id = 1)
   and exists (select 1 from public.plans pl where pl.id = p_plan and pl.active and pl.free_eligible)
   and coalesce(
     case (select free_plans_for from public.app_mode where id = 1)
       when 'everyone' then true
       when 'none' then false
       when 'ads' then public.source_of() = 'ads'
       when 'organic' then public.source_of() = 'organic'
     end, false)
$$;

create function public.quota_bytes(p_uid uuid default auth.uid()) returns bigint language sql stable security definer set search_path = '' as
$$
 select case
   when p_uid is null then 0::bigint
   when coalesce((select is_guest from public.profiles where id = p_uid), true) then 0::bigint
   when public.has_plan(p_uid) then 2199023255552::bigint
   when (select free_mode from public.app_mode where id = 1)
        or coalesce((select play_verified from public.profiles where id = p_uid), false) then 16106127360::bigint
   else 0::bigint
 end
$$;

create function public.payments_available() returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.payment_settings where enabled and coalesce(upi_id, '') <> '') $$;

create function public.can_see_audience(p_aud text) returns boolean language sql stable security definer set search_path = '' as
$$
 select public.is_admin()
     or p_aud = 'all'
     or (p_aud = 'organic' and public.source_of() = 'organic')
     or (p_aud = 'ads' and public.has_ads_access())
$$;

create function public.can_full_premium() returns boolean language sql stable security definer set search_path = '' as
$$
 select public.is_admin()
     or case when (select free_mode from public.app_mode where id = 1)
          then public.has_ads_access() else public.has_plan() end
$$;

create function public.can_manage_channel(p_channel uuid) returns boolean language sql stable security definer set search_path = '' as
$$
 select public.is_owner()
     or exists (select 1 from public.admin_channel_access a where a.user_id = auth.uid() and a.channel_id = p_channel)
$$;

create function public.can_post_to_channel(p_channel uuid) returns boolean language sql stable security definer set search_path = '' as
$$
 select public.can_manage_channel(p_channel)
     or (public.is_member() and exists (
          select 1 from public.channels c
          where c.id = p_channel and c.created_by = auth.uid()
            and c.review_status = 'approved' and c.status in ('published','active')))
$$;

create function public.can_edit_post(p_post uuid) returns boolean language sql stable security definer set search_path = '' as
$$
 select exists (select 1 from public.posts p where p.id = p_post
        and (public.can_manage_channel(p.channel_id)
             or (p.created_by = auth.uid() and public.can_post_to_channel(p.channel_id))))
$$;

create function public.has_consent() returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.consents where user_id = auth.uid()) $$;

create function public.can_write_channel_path(p_name text) returns boolean language plpgsql stable security definer set search_path = '' as
$$
declare seg text := split_part(p_name, '/', 1);
begin
  if seg !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return false; end if;
  return public.can_post_to_channel(seg::uuid);
end $$;

-- ============ RPCs ============
create function public.record_install(p_install_id text, p_referrer_status text, p_raw_referrer text, p_install_secret text)
returns text language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); norm text; src text; camp text; existing text;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if p_install_id is null or length(p_install_id) not between 8 and 100 then raise exception 'invalid install id'; end if;
  select source into existing from private.user_sources where user_id = uid;
  if existing is not null then return existing; end if;
  norm := replace(replace(lower(coalesce(p_raw_referrer, '')), '%3d', '='), '%26', '&');
  if norm ~ '(^|[&?])utm_source=(meta|facebook|instagram|ig)(&|$)' then src := 'ads'; else src := 'organic'; end if;
  camp := substring(norm from 'utm_campaign=([^&]+)');
  insert into public.installs (install_id, user_id, source, referrer_status, raw_referrer, utm_campaign, install_secret)
  values (p_install_id, uid, src, left(p_referrer_status, 100), left(p_raw_referrer, 1000), left(camp, 200), left(p_install_secret, 200))
  on conflict (install_id) do nothing;
  insert into private.user_sources (user_id, source) values (uid, src) on conflict (user_id) do nothing;
  return src;
end $$;

create function public.my_status() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
declare
  uid uuid := auth.uid();
  pr public.profiles%rowtype;
  am public.app_mode%rowtype;
  v_plan text; v_ends timestamptz; src text; pb boolean;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  select * into pr from public.profiles where id = uid;
  select * into am from public.app_mode where id = 1;
  select plan_name, ends_at into v_plan, v_ends from public.subscriptions
    where user_id = uid and not revoked and ends_at > now() order by ends_at desc limit 1;
  src := public.source_of(uid);
  select play_billing_enabled into pb from public.play_settings where id = 1;
  return jsonb_build_object(
    'user_id', uid,
    'is_guest', coalesce(pr.is_guest, true),
    'is_admin', public.is_admin(),
    'source', src,
    'has_ads_access', public.has_ads_access(uid),
    'is_premium', public.has_plan(uid),
    'can_play_premium', public.can_full_premium(),
    'plan_name', v_plan,
    'plan_ends_at', v_ends,
    'used_bytes', coalesce(pr.used_bytes, 0),
    'quota_bytes', public.quota_bytes(uid),
    'free_mode', am.free_mode,
    'paid_enabled', not am.free_mode,
    'access_status', case when src = 'ads' then 'approved' else coalesce(pr.ads_access_status, 'none') end,
    'payments_available', (not am.free_mode) and public.payments_available(),
    'free_plans_for', am.free_plans_for,
    'plans_visible', (not am.free_mode) and public.plans_visible_for_me(),
    'play_verified', coalesce(pr.play_verified, false),
    'play_billing_enabled', coalesce(pb, false)
  );
end $$;

create function public.request_full_access() returns text language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); st text;
begin
  if not public.is_member() then raise exception 'login required' using errcode = '42501'; end if;
  if public.source_of(uid) <> 'organic' then raise exception 'not needed for this account'; end if;
  if not (select free_mode from public.app_mode where id = 1) then raise exception 'only available in free mode'; end if;
  update public.profiles set ads_access_status = 'pending' where id = uid and ads_access_status in ('none','rejected');
  select ads_access_status into st from public.profiles where id = uid;
  return st;
end $$;

create function public.set_ads_access(p_user uuid, p_status text) returns void language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('none','pending','approved','rejected') then raise exception 'invalid status'; end if;
  update public.profiles set ads_access_status = p_status where id = p_user;
  if not found then raise exception 'user not found'; end if;
end $$;

create function public.grant_premium(p_user uuid, p_plan uuid) returns timestamptz language plpgsql security definer set search_path = '' as
$$
declare pl public.plans%rowtype; base timestamptz; new_end timestamptz;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  select * into pl from public.plans where id = p_plan;
  if not found then raise exception 'plan not found'; end if;
  if not exists (select 1 from public.profiles where id = p_user) then raise exception 'user not found'; end if;
  select greatest(now(), coalesce(max(ends_at), now())) into base
    from public.subscriptions where user_id = p_user and not revoked and ends_at > now();
  new_end := base + make_interval(days => pl.duration_days);
  insert into public.subscriptions (user_id, plan_id, plan_code, plan_name, kind, starts_at, ends_at)
  values (p_user, pl.id, pl.code, pl.name, 'admin_grant', now(), new_end);
  return new_end;
end $$;

create function public.revoke_subscription(p_sub uuid) returns void language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.subscriptions set revoked = true where id = p_sub;
  if not found then raise exception 'subscription not found'; end if;
end $$;

create function public.review_channel(p_channel uuid, p_approve boolean, p_audience text default null) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_approve then
    if p_audience is null or p_audience not in ('all','organic','ads') then raise exception 'audience required'; end if;
    update public.channels set review_status = 'approved', status = 'published', audience = p_audience where id = p_channel;
  else
    update public.channels set review_status = 'rejected' where id = p_channel;
  end if;
  if not found then raise exception 'channel not found'; end if;
end $$;

create function public.set_content_hidden(p_type text, p_id uuid, p_hidden boolean) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_type = 'post' then update public.posts set hidden = p_hidden where id = p_id;
  elsif p_type = 'channel' then update public.channels set hidden = p_hidden where id = p_id;
  else raise exception 'invalid type'; end if;
end $$;

create function public.report_content(p_target_type text, p_target_id uuid, p_reason text, p_details text default null) returns uuid
language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); rid uuid;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if p_target_type not in ('post','channel') then raise exception 'invalid target'; end if;
  if p_reason not in ('Sexual/nude','Violence','Hate/harassment','Copyright','Spam/scam','Other') then raise exception 'invalid reason'; end if;
  if p_target_type = 'post' and not exists (select 1 from public.posts where id = p_target_id) then raise exception 'not found'; end if;
  if p_target_type = 'channel' and not exists (select 1 from public.channels where id = p_target_id) then raise exception 'not found'; end if;
  if (select count(*) from public.support_requests where user_id = uid and kind = 'report' and created_at > now() - interval '1 day') >= 20 then
    raise exception 'too many reports';
  end if;
  insert into public.support_requests (user_id, kind, target_type, target_id, reason, details)
  values (uid, 'report', p_target_type, p_target_id, p_reason, left(p_details, 2000)) returning id into rid;
  return rid;
end $$;

create function public.accept_consent(p_policy text) returns void language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_member() then raise exception 'login required' using errcode = '42501'; end if;
  insert into public.consents (user_id, policy_version) values (auth.uid(), left(p_policy, 50)) on conflict do nothing;
end $$;

-- ============ trigger functions (private) ============
create function private.touch_updated_at() returns trigger language plpgsql set search_path = '' as
$$ begin new.updated_at := now(); return new; end $$;

create function private.lock_plan_code() returns trigger language plpgsql set search_path = '' as
$$ begin if new.code is distinct from old.code then raise exception 'plan code cannot be changed'; end if; return new; end $$;

create function private.bump_catalog() returns trigger language plpgsql security definer set search_path = '' as
$$ begin update public.plan_catalog set revision = revision + 1, updated_at = now() where id = 1; return null; end $$;

create function private.promo_counter() returns trigger language plpgsql set search_path = '' as
$$
begin
  if old.free_plans_for = 'none' and new.free_plans_for <> 'none' then new.promo_id := old.promo_id + 1; end if;
  return new;
end $$;

create function private.user_sources_immutable() returns trigger language plpgsql set search_path = '' as
$$
begin
  if tg_op = 'UPDATE' then raise exception 'user source is immutable' using errcode = '42501'; end if;
  if tg_op = 'DELETE' and pg_trigger_depth() < 2 then raise exception 'user source is immutable' using errcode = '42501'; end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

create function private.maybe_make_owner(p_id uuid, p_email text, p_confirmed timestamptz, p_anon boolean) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  if p_confirmed is not null and not coalesce(p_anon, false) and p_email is not null
     and exists (select 1 from private.owner_bootstrap where lower(email) = lower(p_email)) then
    insert into public.admins (user_id, role) values (p_id, 'owner') on conflict (user_id) do nothing;
  end if;
end $$;

create function private.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as
$$
begin
  insert into public.profiles (id, is_guest, display_name)
  values (new.id, coalesce(new.is_anonymous, false), nullif(split_part(coalesce(new.email, ''), '@', 1), ''))
  on conflict (id) do nothing;
  perform private.maybe_make_owner(new.id, new.email, new.email_confirmed_at, new.is_anonymous);
  return new;
end $$;

create function private.handle_user_updated() returns trigger language plpgsql security definer set search_path = '' as
$$
begin
  update public.profiles
     set is_guest = coalesce(new.is_anonymous, false),
         display_name = coalesce(display_name, nullif(split_part(coalesce(new.email, ''), '@', 1), ''))
   where id = new.id;
  perform private.maybe_make_owner(new.id, new.email, new.email_confirmed_at, new.is_anonymous);
  return new;
end $$;

create function private.guard_profiles() returns trigger language plpgsql set search_path = '' as
$$
begin
  if current_user in ('authenticated','anon') then
    if new.id is distinct from old.id or new.is_guest is distinct from old.is_guest
       or new.used_bytes is distinct from old.used_bytes
       or new.ads_access_status is distinct from old.ads_access_status
       or new.play_verified is distinct from old.play_verified
       or new.created_at is distinct from old.created_at then
      raise exception 'protected profile fields' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

create function private.guard_channels() returns trigger language plpgsql set search_path = '' as
$$
begin
  if tg_op = 'INSERT' then
    if current_user in ('authenticated','anon') then
      if public.is_owner() then
        new.review_status := 'approved';
        new.created_by := coalesce(new.created_by, auth.uid());
        new.members_count := 0;
      else
        new.created_by := auth.uid(); new.review_status := 'pending'; new.status := 'draft';
        new.members_count := 0; new.hidden := false; new.audience := 'all';
      end if;
    end if;
    return new;
  end if;
  if current_user in ('authenticated','anon') and not public.is_owner() then
    if new.created_by is distinct from old.created_by or new.review_status is distinct from old.review_status
       or new.members_count is distinct from old.members_count or new.hidden is distinct from old.hidden then
      raise exception 'protected channel fields' using errcode = '42501';
    end if;
    if not public.can_manage_channel(old.id) then
      if new.audience is distinct from old.audience or new.status is distinct from old.status then
        raise exception 'protected channel fields' using errcode = '42501';
      end if;
      if new.name is distinct from old.name or new.description is distinct from old.description
         or new.category is distinct from old.category or new.tags is distinct from old.tags
         or new.icon_url is distinct from old.icon_url then
        new.review_status := 'pending';
      end if;
    end if;
  end if;
  return new;
end $$;

create function private.guard_posts() returns trigger language plpgsql set search_path = '' as
$$
declare ch_aud text;
begin
  if current_user not in ('authenticated','anon') then return new; end if;
  if tg_op = 'INSERT' then
    if public.can_manage_channel(new.channel_id) then
      new.created_by := coalesce(new.created_by, auth.uid());
    else
      select audience into ch_aud from public.channels where id = new.channel_id;
      new.created_by := auth.uid(); new.hidden := false; new.audience := coalesce(ch_aud, 'all');
    end if;
    return new;
  end if;
  if new.channel_id is distinct from old.channel_id or new.created_by is distinct from old.created_by then
    raise exception 'protected post fields' using errcode = '42501';
  end if;
  if not public.is_owner() then
    if new.hidden is distinct from old.hidden then raise exception 'protected post fields' using errcode = '42501'; end if;
    if not public.can_manage_channel(old.channel_id) and new.audience is distinct from old.audience then
      raise exception 'protected post fields' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

create function private.sync_members_count() returns trigger language plpgsql security definer set search_path = '' as
$$
declare cid uuid := coalesce(new.channel_id, old.channel_id);
begin
  update public.channels set members_count = (select count(*) from public.channel_members where channel_id = cid) where id = cid;
  return null;
end $$;

create function private.sync_used_bytes() returns trigger language plpgsql security definer set search_path = '' as
$$
begin
  if tg_op = 'INSERT' then
    update public.profiles set used_bytes = used_bytes + new.size_bytes where id = new.user_id;
  elsif tg_op = 'DELETE' then
    update public.profiles set used_bytes = greatest(0, used_bytes - old.size_bytes) where id = old.user_id;
  else
    update public.profiles set used_bytes = greatest(0, used_bytes + new.size_bytes - old.size_bytes) where id = new.user_id;
  end if;
  return null;
end $$;

create function private.protect_last_owner() returns trigger language plpgsql security definer set search_path = '' as
$$
begin
  if (tg_op = 'DELETE' and old.role = 'owner') or (tg_op = 'UPDATE' and old.role = 'owner' and new.role <> 'owner') then
    if not exists (select 1 from public.admins where role = 'owner' and user_id <> old.user_id) then
      raise exception 'cannot remove the last owner';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

-- ============ triggers ============
create trigger plans_touch before update on public.plans for each row execute function private.touch_updated_at();
create trigger plans_lock_code before update on public.plans for each row execute function private.lock_plan_code();
create trigger payment_settings_touch before update on public.payment_settings for each row execute function private.touch_updated_at();
create trigger app_mode_touch before update on public.app_mode for each row execute function private.touch_updated_at();
create trigger app_mode_promo before update on public.app_mode for each row execute function private.promo_counter();
create trigger play_settings_touch before update on public.play_settings for each row execute function private.touch_updated_at();

create trigger plans_bump after insert or update or delete on public.plans for each statement execute function private.bump_catalog();
create trigger app_mode_bump after update on public.app_mode for each statement execute function private.bump_catalog();
create trigger payment_settings_bump after update on public.payment_settings for each statement execute function private.bump_catalog();

create trigger user_sources_immutable before update or delete on private.user_sources for each row execute function private.user_sources_immutable();
create trigger profiles_guard before update on public.profiles for each row execute function private.guard_profiles();
create trigger channels_guard before insert or update on public.channels for each row execute function private.guard_channels();
create trigger posts_guard before insert or update on public.posts for each row execute function private.guard_posts();
create trigger members_count_sync after insert or delete on public.channel_members for each row execute function private.sync_members_count();
create trigger cloud_files_used after insert or delete or update of size_bytes on public.cloud_files for each row execute function private.sync_used_bytes();
create trigger admins_last_owner before update or delete on public.admins for each row execute function private.protect_last_owner();

create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();
create trigger on_auth_user_updated after update of is_anonymous, email, email_confirmed_at on auth.users for each row execute function private.handle_user_updated();

-- ============ grants: functions callable only by signed-in users ============
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f' loop
    execute format('revoke execute on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated, service_role', r.sig);
  end loop;
end $$;
alter default privileges in schema public revoke execute on functions from public, anon;
