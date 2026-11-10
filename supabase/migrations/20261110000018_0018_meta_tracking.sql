-- Meta tracking v2: full funnel (Lead -> AppInstall -> CompleteRegistration -> InitiateCheckout -> Purchase),
-- ad-click matching (fbc / fbp / IP / user agent) so Purchase value can be attributed for ROAS,
-- automatic sending (no button needed), and a public pixel id so the website follows the admin setting.
create extension if not exists pg_net with schema extensions;

alter table public.meta_events drop constraint if exists meta_events_event_name_check;
alter table public.meta_events add constraint meta_events_event_name_check
  check (event_name in ('Lead','AppInstall','CompleteRegistration','InitiateCheckout','Purchase'));
alter table public.meta_events
  add column if not exists fbc text,
  add column if not exists fbp text,
  add column if not exists client_ip text,
  add column if not exists client_ua text,
  add column if not exists source_url text,
  add column if not exists content_name text;
create index if not exists ad_clicks_ip_idx on public.ad_clicks (ip, created_at desc);

create table if not exists private.user_attribution (
  user_id uuid primary key references auth.users(id) on delete cascade,
  click_id uuid,
  fbc text,
  fbp text,
  ip text,          -- browser IP at the ad click
  ua text,          -- browser user agent at the ad click
  last_ip text,     -- most recent app IP
  last_ua text,
  updated_at timestamptz not null default now()
);

create table if not exists private.meta_cron (
  id int primary key default 1 check (id = 1),
  key text not null default encode(extensions.gen_random_bytes(24), 'hex'),
  url text not null default ''   -- https://<project>.supabase.co/functions/v1/meta-send (set once per project)
);
insert into private.meta_cron (id) values (1) on conflict do nothing;

create or replace function private.req_header(p_name text) returns text language plpgsql stable set search_path = '' as
$$
declare h text := current_setting('request.headers', true);
begin
  if h is null or h = '' then return null; end if;
  return nullif(h::json ->> p_name, '');
exception when others then return null;
end $$;

create or replace function private.req_ip() returns text language sql stable set search_path = '' as
$$ select nullif(trim(split_part(coalesce(private.req_header('x-forwarded-for'), ''), ',', 1)), '') $$;

create or replace function private.touch_attribution(p_user uuid) returns void language plpgsql security definer set search_path = '' as
$$
declare v_ip text := private.req_ip(); v_ua text := left(private.req_header('user-agent'), 400);
begin
  if p_user is null or v_ip is null then return; end if;
  insert into private.user_attribution (user_id, last_ip, last_ua) values (p_user, v_ip, v_ua)
  on conflict (user_id) do update set last_ip = excluded.last_ip, last_ua = excluded.last_ua, updated_at = now();
end $$;

create or replace function private.meta_ready() returns boolean language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.meta_settings where enabled and pixel_id <> '' and capi_token <> '') $$;

create or replace function private.enqueue_meta(p_event text, p_user uuid, p_order uuid, p_value numeric) returns void
language plpgsql security definer set search_path = '' as
$$
declare a private.user_attribution%rowtype; v_name text;
begin
  if not private.meta_ready() then return; end if;
  select * into a from private.user_attribution where user_id = p_user;
  if p_order is not null then select plan_name into v_name from public.payment_orders where id = p_order; end if;
  insert into public.meta_events (event_name, event_id, user_id, order_id, value_inr, fbc, fbp, client_ip, client_ua, content_name)
  values (p_event,
          case p_event when 'Purchase' then 'purchase-' || p_order::text
                       when 'InitiateCheckout' then 'checkout-' || p_order::text
                       when 'AppInstall' then 'install-' || p_user::text
                       when 'Lead' then 'lead-' || p_user::text
                       else 'reg-' || p_user::text end,
          p_user, p_order, p_value, a.fbc, a.fbp, coalesce(a.last_ip, a.ip), coalesce(a.ua, a.last_ua), v_name)
  on conflict (event_id) do nothing;
end $$;

-- Website: remembers an ad click (and optionally queues the Lead for the download tap). Called from the browser,
-- so the IP and user agent are the visitor's own.
create or replace function public.record_ad_click(p_fbclid text, p_fbc text, p_fbp text, p_url text, p_lead_event_id text default null)
returns uuid language plpgsql security definer set search_path = '' as
$$
declare v_ip text := private.req_ip(); v_ua text := left(private.req_header('user-agent'), 400); v_fbc text; v_id uuid;
begin
  if v_ip is null then return null; end if;
  if (select count(*) from public.ad_clicks where ip = v_ip and created_at > now() - interval '1 hour') >= 30 then return null; end if;
  p_fbclid := nullif(left(p_fbclid, 500), '');
  v_fbc := coalesce(nullif(left(p_fbc, 600), ''),
                    case when p_fbclid is not null then 'fb.1.' || (extract(epoch from now()) * 1000)::bigint || '.' || p_fbclid end);
  insert into public.ad_clicks (fbclid, fbc, fbp, ip, user_agent)
  values (p_fbclid, v_fbc, nullif(left(p_fbp, 200), ''), v_ip, v_ua) returning id into v_id;
  if p_lead_event_id ~ '^lead-[0-9a-f-]{36}$' and private.meta_ready() then
    insert into public.meta_events (event_name, event_id, fbc, fbp, client_ip, client_ua, source_url, content_name)
    values ('Lead', p_lead_event_id, v_fbc, nullif(left(p_fbp, 200), ''), v_ip, v_ua, left(p_url, 500), 'apk_download')
    on conflict (event_id) do nothing;
  end if;
  return v_id;
end $$;
revoke all on function public.record_ad_click(text, text, text, text, text) from public;
grant execute on function public.record_ad_click(text, text, text, text, text) to anon, authenticated;

-- The website reads the pixel id from here, so changing it in the admin panel changes it everywhere.
create or replace function public.meta_public() returns jsonb language sql stable security definer set search_path = '' as
$$ select coalesce((select jsonb_build_object('pixel_id', pixel_id) from public.meta_settings where id = 1 and enabled and pixel_id <> ''), '{}'::jsonb) $$;
revoke all on function public.meta_public() from public;
grant execute on function public.meta_public() to anon, authenticated;

create or replace function public.record_install(p_install_id text, p_referrer_status text, p_raw_referrer text, p_install_secret text)
returns text language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); norm text; src text; camp text; existing text; v_ip text := private.req_ip(); c public.ad_clicks%rowtype;
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

  -- Link this install to the most recent ad click from the same network (last 7 days).
  if v_ip is not null then
    select * into c from public.ad_clicks where ip = v_ip and created_at > now() - interval '7 days' order by created_at desc limit 1;
  end if;
  insert into private.user_attribution (user_id, click_id, fbc, fbp, ip, ua, last_ip, last_ua)
  values (uid, c.id, c.fbc, c.fbp, c.ip, c.user_agent, v_ip, left(private.req_header('user-agent'), 400))
  on conflict (user_id) do nothing;
  perform private.enqueue_meta('AppInstall', uid, null, null);
  return src;
end $$;

create or replace function public.create_order(p_plan uuid) returns jsonb language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); pl public.plans%rowtype; ps public.payment_settings%rowtype; o public.payment_orders%rowtype;
begin
  if uid is null then raise exception 'session required' using errcode = '42501'; end if;
  if (select free_mode from public.app_mode where id = 1) then raise exception 'payments are off in free mode'; end if;
  if not public.plans_visible_for_me() then raise exception 'plans are not available for this account'; end if;
  select * into pl from public.plans where id = p_plan and active;
  if not found then raise exception 'This plan is no longer available.'; end if;
  if public.free_plan_for_me(p_plan) then raise exception 'this plan is free for you'; end if;
  if not public.payments_available() then raise exception 'payments are not available'; end if;
  select * into ps from public.payment_settings where id = 1;

  update public.payment_orders set status = 'cancelled'
   where user_id = uid and status = 'pending' and not success_reported
     and (created_at < now() - interval '2 hours' or plan_id <> p_plan
          or amount_paise <> pl.price_inr::bigint * 100 or coalesce(upi_id_used, '') <> ps.upi_id);

  select * into o from public.payment_orders
   where user_id = uid and plan_id = p_plan and status = 'pending' and not success_reported
   order by created_at desc limit 1;
  if not found then
    insert into public.payment_orders (user_id, plan_id) values (uid, p_plan) returning * into o;
    perform private.touch_attribution(uid);
    perform private.enqueue_meta('InitiateCheckout', uid, o.id, o.amount_paise / 100.0);
  end if;
  return jsonb_build_object('order_id', o.id, 'reference', o.reference, 'amount_paise', o.amount_paise,
    'amount_inr', o.amount_paise / 100, 'plan_name', o.plan_name, 'status', o.status, 'created_at', o.created_at,
    'upi_id', o.upi_id_used, 'payee_name', o.payee_used);
end $$;

-- ---------- automatic sending ----------
create or replace function public.meta_cron_ok(p_key text) returns boolean language sql stable security definer set search_path = '' as
$$ select coalesce(p_key, '') <> '' and exists (select 1 from private.meta_cron where id = 1 and key = p_key) $$;
revoke all on function public.meta_cron_ok(text) from public, anon, authenticated;
grant execute on function public.meta_cron_ok(text) to service_role;

create or replace function private.meta_kick() returns void language plpgsql security definer set search_path = '' as
$$
declare c private.meta_cron%rowtype;
begin
  select * into c from private.meta_cron where id = 1;
  if c.url is null or c.url = '' or not private.meta_ready() then return; end if;
  if not exists (select 1 from public.meta_events where status = 'pending' and attempts < 5) then return; end if;
  perform net.http_post(url := c.url, body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-key', c.key));
exception when others then null; -- tracking must never break a payment or a sign-up
end $$;

create or replace function private.meta_kick_trg() returns trigger language plpgsql security definer set search_path = '' as
$$ begin perform private.meta_kick(); return null; end $$;
create or replace trigger meta_events_kick after insert on public.meta_events for each statement execute function private.meta_kick_trg();

select cron.schedule('meta-send', '*/5 * * * *', 'select private.meta_kick()');

-- ---------- admin ----------
create or replace function public.admin_meta_overview() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(
    'funnel', coalesce((select jsonb_agg(row_to_json(f)) from (
        select n.event_name,
               count(e.id) filter (where e.created_at > now() - interval '1 day') as d1,
               count(e.id) filter (where e.created_at > now() - interval '7 days') as d7,
               count(e.id) as d30,
               count(e.id) filter (where e.status = 'sent') as sent,
               count(e.id) filter (where e.status = 'failed') as failed,
               count(e.id) filter (where e.fbc is not null) as with_click,
               coalesce(sum(e.value_inr) filter (where n.event_name = 'Purchase' and e.created_at > now() - interval '7 days'), 0) as value_d7,
               coalesce(sum(e.value_inr) filter (where n.event_name = 'Purchase'), 0) as value_d30
          from unnest(array['Lead','AppInstall','CompleteRegistration','InitiateCheckout','Purchase']) with ordinality as n(event_name, ord)
          left join public.meta_events e on e.event_name = n.event_name and e.created_at > now() - interval '30 days'
         group by n.event_name, n.ord order by n.ord) f), '[]'::jsonb),
    'recent', coalesce((select jsonb_agg(row_to_json(r)) from (
        select id, event_name, status, value_inr, content_name, attempts, last_error, created_at, sent_at,
               (fbc is not null) as has_click, (client_ip is not null) as has_ip
          from public.meta_events order by created_at desc limit 40) r), '[]'::jsonb),
    'clicks_7d', (select count(*) from public.ad_clicks where created_at > now() - interval '7 days'),
    'matched_installs_7d', (select count(*) from private.user_attribution where click_id is not null and updated_at > now() - interval '7 days'),
    'auto_send', (select url <> '' from private.meta_cron where id = 1));
end $$;
revoke all on function public.admin_meta_overview() from public, anon;
grant execute on function public.admin_meta_overview() to authenticated, service_role;

create or replace function public.admin_meta_retry() returns integer language plpgsql security definer set search_path = '' as
$$
declare n integer;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.meta_events set status = 'pending', attempts = 0
   where status = 'failed' and created_at > now() - interval '6 days';
  get diagnostics n = row_count;
  perform private.meta_kick();
  return n;
end $$;
revoke all on function public.admin_meta_retry() from public, anon;
grant execute on function public.admin_meta_retry() to authenticated, service_role;
