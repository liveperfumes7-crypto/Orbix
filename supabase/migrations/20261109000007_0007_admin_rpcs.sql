
create function public.admin_mark_paid(p_order uuid, p_utr text) returns jsonb language plpgsql security definer set search_path = '' as
$$
declare o public.payment_orders%rowtype; got int;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_utr is null or p_utr !~ '^[0-9]{12}$' then raise exception 'UTR must be exactly 12 digits'; end if;
  select * into o from public.payment_orders where id = p_order for update;
  if not found then raise exception 'order not found'; end if;
  if o.status in ('paid','revoked') then raise exception 'order is already %', o.status; end if;
  insert into private.used_payment_utrs (txn_id, order_id) values (upper(p_utr), o.id) on conflict (txn_id) do nothing;
  get diagnostics got = row_count;
  if got = 0 and not exists (select 1 from private.used_payment_utrs where txn_id = upper(p_utr) and order_id = o.id) then
    raise exception 'this UTR was already used for another order';
  end if;
  update public.payment_orders set utr = p_utr, success_reported = true, bank_verified = true, bank_verified_at = now() where id = o.id;
  perform private.activate_order(o.id, 'manual');
  return private.order_json(o.id);
end $$;

create function public.admin_confirm_bank(p_order uuid) returns jsonb language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.payment_orders set bank_verified = true, bank_verified_at = now() where id = p_order and status = 'paid';
  if not found then raise exception 'only paid orders can be bank-verified'; end if;
  return private.order_json(p_order);
end $$;

create function public.admin_reject_order(p_order uuid, p_note text default null) returns jsonb language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.payment_orders set status = 'rejected', admin_note = left(p_note, 500)
   where id = p_order and status in ('pending','submitted','review','failed');
  if not found then raise exception 'order cannot be rejected in its current status'; end if;
  return private.order_json(p_order);
end $$;

create function public.admin_revoke_order(p_order uuid, p_note text default null) returns jsonb language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.payment_orders set status = 'revoked', admin_note = left(p_note, 500) where id = p_order and status = 'paid';
  if not found then raise exception 'only paid orders can be revoked'; end if;
  update public.subscriptions set revoked = true where order_id = p_order;
  return private.order_json(p_order);
end $$;

create function public.admin_dashboard() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
declare res jsonb; today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  res := jsonb_build_object(
    'channels', (select count(*) from public.channels where review_status = 'approved'),
    'posts', (select count(*) from public.posts));
  if not public.is_owner() then return res; end if;
  return res || jsonb_build_object(
    'ads_installs', (select count(*) from public.installs where source = 'ads'),
    'organic_installs', (select count(*) from public.installs where source = 'organic'),
    'users', (select count(*) from public.profiles),
    'logged_in', (select count(*) from public.profiles where not is_guest),
    'premium_users', (select count(distinct user_id) from public.subscriptions where not revoked and ends_at > now()),
    'revenue_today', coalesce((select sum(amount_paise) from public.payment_orders where status = 'paid' and (activated_at at time zone 'Asia/Kolkata')::date = today), 0) / 100,
    'revenue_month', coalesce((select sum(amount_paise) from public.payment_orders where status = 'paid' and date_trunc('month', activated_at at time zone 'Asia/Kolkata') = date_trunc('month', now() at time zone 'Asia/Kolkata')), 0) / 100,
    'free_claims', (select count(*) from public.free_plan_claims),
    'alerts', jsonb_build_object(
      'channel_requests', (select count(*) from public.channels where review_status = 'pending'),
      'organic_buyers_waiting', (select count(*) from public.profiles where ads_access_status = 'pending'),
      'payments_to_verify', (select count(*) from public.payment_orders
          where status = 'review' or (status = 'paid' and activation_kind = 'auto' and not bank_verified
                and (activated_at at time zone 'Asia/Kolkata')::date = today)),
      'open_requests', (select count(*) from public.support_requests where status = 'open')),
    'installs_by_campaign', coalesce((select jsonb_agg(x) from (
        select source, coalesce(utm_campaign, '(none)') as campaign, count(*) as installs
        from public.installs group by 1, 2 order by 3 desc limit 50) x), '[]'::jsonb));
end $$;

create function public.admin_payment_stats() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
declare today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(
    'paid_orders', (select count(*) from public.payment_orders where status = 'paid'),
    'revenue_total', coalesce((select sum(amount_paise) from public.payment_orders where status = 'paid'), 0) / 100,
    'revenue_today', coalesce((select sum(amount_paise) from public.payment_orders where status = 'paid' and (activated_at at time zone 'Asia/Kolkata')::date = today), 0) / 100,
    'to_verify', (select count(*) from public.payment_orders where status = 'review' or (status = 'paid' and activation_kind = 'auto' and not bank_verified and (activated_at at time zone 'Asia/Kolkata')::date = today)),
    'pending_orders', (select count(*) from public.payment_orders where status in ('pending','submitted')),
    'failed_orders', (select count(*) from public.payment_orders where status in ('failed','rejected')),
    'sales_per_plan', coalesce((select jsonb_agg(x) from (
        select plan_name, count(*) as orders, sum(amount_paise) / 100 as revenue
        from public.payment_orders where status = 'paid' group by plan_name order by 3 desc) x), '[]'::jsonb),
    'repeat_buyers', coalesce((select jsonb_agg(x) from (
        select u.email, count(*) as paid_orders, sum(o.amount_paise) / 100 as spent
        from public.payment_orders o join auth.users u on u.id = o.user_id
        where o.status = 'paid' group by u.email having count(*) >= 2 order by 2 desc limit 50) x), '[]'::jsonb));
end $$;

create function public.admin_orders(p_status text default null, p_verify_today boolean default false, p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as
$$
declare today date := (now() at time zone 'Asia/Kolkata')::date; res jsonb;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into res from (
    select o.id, o.created_at, u.email, o.user_id, o.plan_name, o.amount_paise / 100 as amount_inr, o.reference,
           coalesce(o.utr, o.txn_id) as txn, o.upi_id_used, o.status, o.activation_kind, o.bank_verified, o.raw_result, o.admin_note
    from public.payment_orders o join auth.users u on u.id = o.user_id
    where (coalesce(p_status, '') = '' or o.status = p_status)
      and (not p_verify_today or (o.status = 'paid' and o.activation_kind = 'auto' and not o.bank_verified
                                   and (o.activated_at at time zone 'Asia/Kolkata')::date = today))
    order by o.created_at desc limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) x;
  return res;
end $$;

create function public.admin_users(p_search text default null, p_source text default null, p_plan text default null,
                                   p_guest boolean default null, p_access text default null, p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as
$$
declare res jsonb;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  with base as (
    select pr.id, u.email, pr.display_name, pr.is_guest, private.source_of(pr.id) as source, pr.ads_access_status, pr.used_bytes, pr.created_at,
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
        select * from filtered order by created_at desc limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) f), '[]'::jsonb))
  into res;
  return res;
end $$;

create function public.admin_channel_requests() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at) from (
    select c.id, c.name, c.description, c.category, c.tags, c.icon_url, c.created_at,
           u.email as creator_email, p.display_name as creator_name, private.source_of(c.created_by) as creator_source
    from public.channels c left join auth.users u on u.id = c.created_by left join public.profiles p on p.id = c.created_by
    where c.review_status = 'pending') x), '[]'::jsonb);
end $$;

create function public.admin_requests(p_status text default 'open') returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
    select r.id, r.kind, r.target_type, r.target_id, r.reason, r.details, r.status, r.created_at, r.email as contact_email,
           u.email as user_email, r.user_id,
           case r.target_type when 'post' then (select title from public.posts where id = r.target_id)
                              when 'channel' then (select name from public.channels where id = r.target_id) end as target_title
    from public.support_requests r left join auth.users u on u.id = r.user_id
    where p_status is null or r.status = p_status
    order by r.created_at desc limit 200) x), '[]'::jsonb);
end $$;

create function public.admin_close_request(p_id uuid) returns void language plpgsql security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.support_requests set status = 'closed' where id = p_id;
end $$;

create function public.admin_list_admins() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at) from (
    select a.user_id, a.role, a.created_at, u.email,
           coalesce((select jsonb_agg(c.name) from public.admin_channel_access ac join public.channels c on c.id = ac.channel_id where ac.user_id = a.user_id), '[]'::jsonb) as channels
    from public.admins a join auth.users u on u.id = a.user_id) x), '[]'::jsonb);
end $$;

-- public website needs a safe, minimal view of one shareable post (service role only)
create function public.public_post_preview(p_id uuid) returns jsonb language sql stable security definer set search_path = '' as
$$
 select jsonb_build_object('id', p.id, 'title', p.title, 'description', left(p.description, 300), 'channel', c.name)
 from public.posts p join public.channels c on c.id = p.channel_id
 where p.id = p_id and not p.hidden and p.audience = 'all' and p.status = 'published'
   and c.audience = 'all' and c.review_status = 'approved' and not c.hidden
$$;
revoke execute on function public.public_post_preview(uuid) from public, anon, authenticated;
grant execute on function public.public_post_preview(uuid) to service_role;

do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f' and p.proname like 'admin\_%' loop
    execute format('revoke execute on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated, service_role', r.sig);
  end loop;
end $$;
