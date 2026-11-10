-- Hourly plans: duration_hours > 0 overrides duration_days (days stays >= 1 as a placeholder).
alter table public.plans add column if not exists duration_hours integer not null default 0 check (duration_hours >= 0);
alter table public.payment_orders add column if not exists duration_hours integer not null default 0;

create or replace function private.plan_interval(p_days int, p_hours int) returns interval
language sql immutable set search_path = '' as
$$ select case when coalesce(p_hours, 0) > 0 then make_interval(hours => p_hours) else make_interval(days => p_days) end $$;

create or replace function public.public_plans()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id, 'code', code, 'name', name, 'price_inr', price_inr,
    'duration_days', duration_days, 'duration_hours', duration_hours, 'perks', perks, 'badge', badge, 'position', position
  ) order by position), '[]'::jsonb)
  from public.plans where active;
$$;

create or replace function private.order_snapshot() returns trigger language plpgsql security definer set search_path = '' as
$$
declare pl public.plans%rowtype; ps public.payment_settings%rowtype;
begin
  select * into pl from public.plans where id = new.plan_id;
  if not found then raise exception 'plan not found'; end if;
  select * into ps from public.payment_settings where id = 1;
  new.plan_code := pl.code; new.plan_name := pl.name;
  new.amount_paise := pl.price_inr::bigint * 100;
  new.duration_days := pl.duration_days; new.duration_hours := pl.duration_hours;
  new.upi_id_used := ps.upi_id; new.payee_used := ps.payee_name;
  select email into new.email_at_purchase from auth.users where id = new.user_id;
  new.reference := 'OB' || to_char(now() at time zone 'Asia/Kolkata', 'YYMMDD') || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  new.status := 'pending'; new.success_reported := false; new.raw_result := null;
  new.txn_id := null; new.utr := null; new.activated_at := null; new.activation_kind := null;
  return new;
end $$;

create or replace function private.activate_order(p_order uuid, p_kind text) returns void
language plpgsql security definer set search_path = '' as
$$
declare o public.payment_orders%rowtype; base timestamptz; new_end timestamptz;
begin
  select * into o from public.payment_orders where id = p_order for update;
  if not found then raise exception 'order not found'; end if;
  if exists (select 1 from public.subscriptions where order_id = o.id) then
    update public.payment_orders set status = 'paid', updated_at = now() where id = o.id and status <> 'paid';
    return;
  end if;
  select greatest(now(), coalesce(max(ends_at), now())) into base
    from public.subscriptions where user_id = o.user_id and not revoked and ends_at > now();
  new_end := base + private.plan_interval(o.duration_days, o.duration_hours);
  insert into public.subscriptions (user_id, plan_id, plan_code, plan_name, kind, order_id, starts_at, ends_at)
  values (o.user_id, o.plan_id, o.plan_code, o.plan_name, 'payment', o.id, base, new_end);
  update public.payment_orders set status = 'paid', activated_at = now(), activation_kind = p_kind, updated_at = now() where id = o.id;
  if private.source_of(o.user_id) = 'organic' then
    update public.profiles set ads_access_status = 'pending' where id = o.user_id and ads_access_status in ('none','rejected');
  end if;
  perform private.enqueue_meta('Purchase', o.user_id, o.id, o.amount_paise / 100.0);
end $$;

create or replace function public.claim_free_plan(p_plan uuid) returns timestamptz language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); pl public.plans%rowtype; promo int; new_end timestamptz; sub_id uuid;
begin
  if not public.is_member() then raise exception 'login required' using errcode = '42501'; end if;
  if not public.plans_visible_for_me() then raise exception 'plans are not available for this account'; end if;
  if not public.free_plan_for_me(p_plan) then raise exception 'this plan is not free for you'; end if;
  if public.has_plan() then raise exception 'you already have an active plan'; end if;
  select * into pl from public.plans where id = p_plan;
  select promo_id into promo from public.app_mode where id = 1;
  if exists (select 1 from public.free_plan_claims where user_id = uid and plan_id = p_plan and promo_id = promo) then
    raise exception 'already claimed';
  end if;
  new_end := now() + private.plan_interval(pl.duration_days, pl.duration_hours);
  insert into public.subscriptions (user_id, plan_id, plan_code, plan_name, kind, starts_at, ends_at)
  values (uid, pl.id, pl.code, pl.name, 'free_promo', now(), new_end) returning id into sub_id;
  insert into public.free_plan_claims (user_id, plan_id, promo_id, subscription_id) values (uid, p_plan, promo, sub_id);
  if private.source_of(uid) = 'organic' then
    update public.profiles set ads_access_status = 'pending' where id = uid and ads_access_status in ('none','rejected');
  end if;
  return new_end;
end $$;

create or replace function public.grant_premium(p_user uuid, p_plan uuid) returns timestamptz language plpgsql security definer set search_path = '' as
$$
declare pl public.plans%rowtype; base timestamptz; new_end timestamptz;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  select * into pl from public.plans where id = p_plan;
  if not found then raise exception 'plan not found'; end if;
  if not exists (select 1 from public.profiles where id = p_user) then raise exception 'user not found'; end if;
  select greatest(now(), coalesce(max(ends_at), now())) into base
    from public.subscriptions where user_id = p_user and not revoked and ends_at > now();
  new_end := base + private.plan_interval(pl.duration_days, pl.duration_hours);
  insert into public.subscriptions (user_id, plan_id, plan_code, plan_name, kind, starts_at, ends_at)
  values (p_user, pl.id, pl.code, pl.name, 'admin_grant', now(), new_end);
  return new_end;
end $$;
