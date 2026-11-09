
alter function public.source_of(uuid) set schema private;
alter function public.has_plan(uuid) set schema private;
alter function public.has_ads_access(uuid) set schema private;
alter function public.quota_bytes(uuid) set schema private;

create or replace function private.has_ads_access(p_uid uuid default null) returns boolean language sql stable security definer set search_path = '' as
$$
 select case
   when p_uid is null then false
   when exists (select 1 from public.admins where user_id = p_uid) then true
   when private.source_of(p_uid) = 'ads' then true
   else coalesce((select ads_access_status = 'approved' from public.profiles where id = p_uid), false)
        and ((select free_mode from public.app_mode where id = 1) or private.has_plan(p_uid))
 end
$$;

create or replace function private.quota_bytes(p_uid uuid default null) returns bigint language sql stable security definer set search_path = '' as
$$
 select case
   when p_uid is null then 0::bigint
   when coalesce((select is_guest from public.profiles where id = p_uid), true) then 0::bigint
   when private.has_plan(p_uid) then 2199023255552::bigint
   when (select free_mode from public.app_mode where id = 1)
        or coalesce((select play_verified from public.profiles where id = p_uid), false) then 16106127360::bigint
   else 0::bigint
 end
$$;

create function public.source_of() returns text language sql stable security definer set search_path = '' as $$ select private.source_of(auth.uid()) $$;
create function public.has_plan() returns boolean language sql stable security definer set search_path = '' as $$ select private.has_plan(auth.uid()) $$;
create function public.has_ads_access() returns boolean language sql stable security definer set search_path = '' as $$ select private.has_ads_access(auth.uid()) $$;
create function public.quota_bytes() returns bigint language sql stable security definer set search_path = '' as $$ select private.quota_bytes(auth.uid()) $$;

create or replace function public.my_status() returns jsonb language plpgsql stable security definer set search_path = '' as
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
  src := private.source_of(uid);
  select play_billing_enabled into pb from public.play_settings where id = 1;
  return jsonb_build_object(
    'user_id', uid,
    'is_guest', coalesce(pr.is_guest, true),
    'is_admin', public.is_admin(),
    'source', src,
    'has_ads_access', private.has_ads_access(uid),
    'is_premium', private.has_plan(uid),
    'can_play_premium', public.can_full_premium(),
    'plan_name', v_plan,
    'plan_ends_at', v_ends,
    'used_bytes', coalesce(pr.used_bytes, 0),
    'quota_bytes', private.quota_bytes(uid),
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

create or replace function public.request_full_access() returns text language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); st text;
begin
  if not public.is_member() then raise exception 'login required' using errcode = '42501'; end if;
  if private.source_of(uid) <> 'organic' then raise exception 'not needed for this account'; end if;
  if not (select free_mode from public.app_mode where id = 1) then raise exception 'only available in free mode'; end if;
  update public.profiles set ads_access_status = 'pending' where id = uid and ads_access_status in ('none','rejected');
  select ads_access_status into st from public.profiles where id = uid;
  return st;
end $$;

revoke execute on function public.source_of(), public.has_plan(), public.has_ads_access(), public.quota_bytes() from public, anon;
grant execute on function public.source_of(), public.has_plan(), public.has_ads_access(), public.quota_bytes() to authenticated, service_role;

do $$ begin
  revoke execute on function public.rls_auto_enable() from authenticated, anon, public;
exception when others then raise notice 'rls_auto_enable not changed: %', sqlerrm;
end $$;
