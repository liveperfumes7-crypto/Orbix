-- Admin panel v2: counters, campaign table, payment filters, approvals, plan impact, audit trail.
-- Every function re-checks the role in the database; the UI is never the only guard.

create or replace function public.admin_role() returns text language sql stable security definer set search_path = '' as
$$ select role from public.admins where user_id = auth.uid() $$;

create or replace function public.admin_nav_counts() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
declare today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if not public.is_owner() then return '{}'::jsonb; end if;
  return jsonb_build_object(
    'channels', (select count(*) from public.channels where review_status = 'pending'),
    'approvals', (select count(*) from public.profiles where ads_access_status = 'pending'),
    'payments', (select count(*) from public.payment_orders
        where status = 'review' or (status = 'paid' and activation_kind = 'auto' and not bank_verified
              and (activated_at at time zone 'Asia/Kolkata')::date = today)),
    'requests', (select count(*) from public.support_requests where status = 'open'));
end $$;

create or replace function public.admin_campaigns() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x)) from (
    select i.source, coalesce(i.utm_campaign, '(none)') as campaign, count(*) as installs,
           count(*) filter (where exists (select 1 from public.profiles p where p.id = i.user_id and not p.is_guest)) as registrations,
           count(distinct i.user_id) filter (where exists (select 1 from public.payment_orders o where o.user_id = i.user_id and o.status = 'paid')) as buyers
    from public.installs i group by 1, 2 order by 3 desc limit 100) x), '[]'::jsonb);
end $$;

create or replace function public.admin_payments(
  p_status text default null, p_plan text default null, p_from date default null, p_to date default null,
  p_search text default null, p_sort text default 'newest', p_verify text default null, p_limit int default 200) returns jsonb
language plpgsql stable security definer set search_path = '' as
$$
declare today date := (now() at time zone 'Asia/Kolkata')::date; q text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x)) from (
    select o.id, o.created_at, o.updated_at, coalesce(u.email, o.email_at_purchase) as email, o.user_id,
           (u.id is not null and coalesce(u.is_anonymous, false)) as guest,
           o.plan_code, o.plan_name, o.amount_paise / 100 as amount_inr, o.reference, o.utr, o.txn_id, o.upi_id_used,
           o.status, o.activation_kind, o.activated_at, o.bank_verified, o.bank_verified_at, o.admin_note, o.raw_result
    from public.payment_orders o left join auth.users u on u.id = o.user_id
    where (coalesce(p_status, '') = '' or o.status = p_status)
      and (coalesce(p_plan, '') = '' or o.plan_code = p_plan)
      and (p_from is null or (o.created_at at time zone 'Asia/Kolkata')::date >= p_from)
      and (p_to is null or (o.created_at at time zone 'Asia/Kolkata')::date <= p_to)
      and (q is null or o.reference ilike '%' || q || '%' or o.utr ilike '%' || q || '%' or o.txn_id ilike '%' || q || '%'
           or coalesce(u.email, o.email_at_purchase) ilike '%' || q || '%' or o.user_id::text = q)
      and (coalesce(p_verify, '') = ''
           or (p_verify = 'today' and (o.status = 'review' or (o.status = 'paid' and o.activation_kind = 'auto' and not o.bank_verified
                                        and (o.activated_at at time zone 'Asia/Kolkata')::date = today)))
           or (p_verify = 'all' and (o.status = 'review' or (o.status = 'paid' and o.activation_kind = 'auto' and not o.bank_verified))))
    order by case when p_sort = 'highest' then o.amount_paise end desc nulls last, o.created_at desc
    limit least(greatest(p_limit, 1), 500)) x), '[]'::jsonb);
end $$;

create or replace function public.admin_approvals(p_status text default 'pending') returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('pending','approved','rejected') then raise exception 'invalid status'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x)) from (
    select pr.id, u.email, coalesce(u.is_anonymous, false) as guest, private.source_of(pr.id) as source,
           (select i.utm_campaign from public.installs i where i.user_id = pr.id order by i.created_at limit 1) as campaign,
           (select s.plan_name from public.subscriptions s where s.user_id = pr.id and not s.revoked and s.ends_at > now() order by s.ends_at desc limit 1) as plan_name,
           pr.ads_access_status as status, pr.created_at
    from public.profiles pr join auth.users u on u.id = pr.id
    where pr.ads_access_status = p_status
    order by pr.created_at desc limit 300) x), '[]'::jsonb);
end $$;

create or replace function public.admin_plan_impact() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_object_agg(pl.id, jsonb_build_object(
      'subscribers', (select count(distinct s.user_id) from public.subscriptions s where s.plan_id = pl.id and not s.revoked and s.ends_at > now()),
      'orders', (select count(*) from public.payment_orders o where o.plan_id = pl.id and o.status = 'paid')))
    from public.plans pl), '{}'::jsonb);
end $$;

create or replace function public.admin_free_plan_claims() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
declare promo int;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  select promo_id into promo from public.app_mode where id = 1;
  return jsonb_build_object(
    'organic', (select count(*) from public.free_plan_claims c where c.promo_id = promo and private.source_of(c.user_id) = 'organic'),
    'ads', (select count(*) from public.free_plan_claims c where c.promo_id = promo and private.source_of(c.user_id) = 'ads'));
end $$;

create or replace function public.admin_audit(p_limit int default 100) returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x)) from (
    select a.table_name, a.row_key, a.field, a.old_value, a.new_value, u.email as changed_by, a.changed_at
    from public.settings_audit a left join auth.users u on u.id = a.changed_by
    order by a.changed_at desc limit least(greatest(p_limit, 1), 500)) x), '[]'::jsonb);
end $$;

-- users list: add the install campaign and allow the latest 500
create or replace function public.admin_users(p_search text default null, p_source text default null, p_plan text default null,
                                   p_guest boolean default null, p_access text default null, p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as
$$
declare res jsonb;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  with base as (
    select pr.id, u.email, pr.display_name, pr.is_guest, private.source_of(pr.id) as source, pr.ads_access_status, pr.used_bytes, pr.created_at,
      (select i.utm_campaign from public.installs i where i.user_id = pr.id order by i.created_at limit 1) as campaign,
      (select s.plan_name from public.subscriptions s where s.user_id = pr.id and not s.revoked and s.ends_at > now() order by s.ends_at desc limit 1) as plan_name,
      (select max(s.ends_at) from public.subscriptions s where s.user_id = pr.id and not s.revoked and s.ends_at > now()) as plan_ends_at
    from public.profiles pr join auth.users u on u.id = pr.id
    where (coalesce(p_search, '') = '' or u.email ilike '%' || p_search || '%' or pr.display_name ilike '%' || p_search || '%')
      and (coalesce(p_source, '') = '' or private.source_of(pr.id) = p_source)
      and (p_guest is null or pr.is_guest = p_guest)
      and (coalesce(p_access, '') = '' or pr.ads_access_status = p_access)),
  filtered as (
    select * from base
    where (coalesce(p_plan, '') = '') or (p_plan = 'active' and plan_name is not null) or (p_plan = 'none' and plan_name is null))
  select jsonb_build_object('total', (select count(*) from filtered),
    'rows', coalesce((select jsonb_agg(to_jsonb(f) order by f.created_at desc) from (
        select * from filtered order by created_at desc limit least(greatest(p_limit, 1), 500) offset greatest(p_offset, 0)) f), '[]'::jsonb))
  into res;
  return res;
end $$;

do $$
declare f text;
begin
  foreach f in array array['admin_role()','admin_nav_counts()','admin_campaigns()',
    'admin_payments(text,text,date,date,text,text,text,int)','admin_approvals(text)','admin_plan_impact()',
    'admin_free_plan_claims()','admin_audit(int)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;
