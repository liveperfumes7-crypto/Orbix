
alter table public.payment_settings drop constraint if exists payment_settings_upi_id_check;
alter table public.payment_settings add constraint payment_settings_upi_id_check
  check (upi_id = '' or upi_id ~ '^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9]{2,64}$');

create table public.payment_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.plans(id),
  plan_code text, plan_name text,
  amount_paise bigint not null default 0 check (amount_paise >= 0),
  duration_days integer not null default 0,
  reference text unique,
  upi_id_used text, payee_used text,
  status text not null default 'pending' check (status in ('pending','submitted','review','paid','failed','cancelled','rejected','revoked')),
  raw_result text, txn_id text, approval_ref text, utr text,
  success_reported boolean not null default false,
  reported_at timestamptz, activated_at timestamptz,
  activation_kind text check (activation_kind in ('auto','manual','webhook')),
  bank_verified boolean not null default false, bank_verified_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payment_orders_user_idx on public.payment_orders (user_id, created_at desc);
create index payment_orders_status_idx on public.payment_orders (status, created_at desc);
create index payment_orders_plan_idx on public.payment_orders (plan_id);

alter table public.subscriptions add constraint subscriptions_order_fk foreign key (order_id) references public.payment_orders(id);

create table private.used_payment_utrs (
  txn_id text primary key,
  order_id uuid,
  created_at timestamptz not null default now()
);

create table public.free_plan_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.plans(id),
  promo_id integer not null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, plan_id, promo_id)
);
create index free_plan_claims_plan_idx on public.free_plan_claims (plan_id);
create index free_plan_claims_sub_idx on public.free_plan_claims (subscription_id);

create table public.settings_audit (
  id bigint generated always as identity primary key,
  table_name text not null, row_key text, field text not null,
  old_value text, new_value text,
  changed_by uuid, changed_at timestamptz not null default now()
);
create index settings_audit_time_idx on public.settings_audit (changed_at desc);

create table public.meta_settings (
  id int primary key default 1 check (id = 1),
  pixel_id text not null default '',
  capi_token text not null default '',
  test_event_code text not null default '',
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.meta_settings (id) values (1);

create table public.meta_events (
  id bigint generated always as identity primary key,
  event_name text not null check (event_name in ('Lead','CompleteRegistration','Purchase')),
  event_id text not null unique,
  user_id uuid references auth.users(id) on delete set null,
  order_id uuid,
  value_inr numeric,
  status text not null default 'pending' check (status in ('pending','sent','failed')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index meta_events_status_idx on public.meta_events (status, created_at);
create index meta_events_user_idx on public.meta_events (user_id);

alter table public.payment_orders enable row level security;
alter table public.free_plan_claims enable row level security;
alter table public.settings_audit enable row level security;
alter table public.meta_settings enable row level security;
alter table public.meta_events enable row level security;

create policy orders_read on public.payment_orders for select to authenticated using (user_id = (select auth.uid()) or (select public.is_owner()));
create policy claims_owner_read on public.free_plan_claims for select to authenticated using ((select public.is_owner()));
create policy audit_owner_read on public.settings_audit for select to authenticated using ((select public.is_owner()));
create policy meta_settings_owner on public.meta_settings for all to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy meta_events_owner_read on public.meta_events for select to authenticated using ((select public.is_owner()));

create function private.upi_param(p_raw text, p_key text) returns text language sql immutable set search_path = '' as
$$ select substring(coalesce(p_raw,'') from '(?i)(?:^|[?&;,\s])' || p_key || '=([^&;,\s]*)') $$;

create function private.enqueue_meta(p_event text, p_user uuid, p_order uuid, p_value numeric) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  if not exists (select 1 from public.meta_settings where enabled and pixel_id <> '' and capi_token <> '') then return; end if;
  insert into public.meta_events (event_name, event_id, user_id, order_id, value_inr)
  values (p_event,
          case p_event when 'Purchase' then 'purchase-' || p_order::text when 'Lead' then 'lead-' || p_user::text else 'reg-' || p_user::text end,
          p_user, p_order, p_value)
  on conflict (event_id) do nothing;
end $$;

create function private.order_json(p_order uuid) returns jsonb language sql stable security definer set search_path = '' as
$$
 select jsonb_build_object(
   'order_id', o.id, 'status', o.status, 'reference', o.reference, 'plan_name', o.plan_name,
   'amount_paise', o.amount_paise, 'amount_inr', o.amount_paise / 100,
   'txn_id', o.txn_id, 'activated_at', o.activated_at,
   'ends_at', (select s.ends_at from public.subscriptions s where s.order_id = o.id))
 from public.payment_orders o where o.id = p_order
$$;

create function private.activate_order(p_order uuid, p_kind text) returns void
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
  new_end := base + make_interval(days => o.duration_days);
  insert into public.subscriptions (user_id, plan_id, plan_code, plan_name, kind, order_id, starts_at, ends_at)
  values (o.user_id, o.plan_id, o.plan_code, o.plan_name, 'payment', o.id, base, new_end);
  update public.payment_orders set status = 'paid', activated_at = now(), activation_kind = p_kind, updated_at = now() where id = o.id;
  if private.source_of(o.user_id) = 'organic' then
    update public.profiles set ads_access_status = 'pending' where id = o.user_id and ads_access_status in ('none','rejected');
  end if;
  perform private.enqueue_meta('Purchase', o.user_id, o.id, o.amount_paise / 100.0);
end $$;

create function private.order_snapshot() returns trigger language plpgsql security definer set search_path = '' as
$$
declare pl public.plans%rowtype; ps public.payment_settings%rowtype;
begin
  select * into pl from public.plans where id = new.plan_id;
  if not found then raise exception 'plan not found'; end if;
  select * into ps from public.payment_settings where id = 1;
  new.plan_code := pl.code; new.plan_name := pl.name;
  new.amount_paise := pl.price_inr::bigint * 100;
  new.duration_days := pl.duration_days;
  new.upi_id_used := ps.upi_id; new.payee_used := ps.payee_name;
  new.reference := 'OB' || to_char(now() at time zone 'Asia/Kolkata', 'YYMMDD') || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  new.status := 'pending'; new.success_reported := false; new.raw_result := null;
  new.txn_id := null; new.utr := null; new.activated_at := null; new.activation_kind := null;
  return new;
end $$;
create trigger payment_orders_snapshot before insert on public.payment_orders for each row execute function private.order_snapshot();
create trigger payment_orders_touch before update on public.payment_orders for each row execute function private.touch_updated_at();

create function private.audit_changes() returns trigger language plpgsql security definer set search_path = '' as
$$
declare k text; o jsonb; n jsonb; rk text;
begin
  n := to_jsonb(new);
  rk := coalesce(n ->> 'code', n ->> 'id');
  if tg_op = 'INSERT' then
    insert into public.settings_audit (table_name, row_key, field, old_value, new_value, changed_by)
    values (tg_table_name, rk, 'created', null, coalesce(n ->> 'name', rk), auth.uid());
    return new;
  end if;
  o := to_jsonb(old);
  for k in select jsonb_object_keys(n) loop
    if k = 'updated_at' then continue; end if;
    if (o -> k) is distinct from (n -> k) then
      insert into public.settings_audit (table_name, row_key, field, old_value, new_value, changed_by)
      values (tg_table_name, rk, k, o ->> k, n ->> k, auth.uid());
    end if;
  end loop;
  return new;
end $$;
create trigger plans_audit after insert or update on public.plans for each row execute function private.audit_changes();
create trigger payment_settings_audit after update on public.payment_settings for each row execute function private.audit_changes();
create trigger app_mode_audit after update on public.app_mode for each row execute function private.audit_changes();

create function private.registration_event() returns trigger language plpgsql security definer set search_path = '' as
$$
begin
  if (tg_op = 'INSERT' and not new.is_guest) or (tg_op = 'UPDATE' and old.is_guest and not new.is_guest) then
    perform private.enqueue_meta('CompleteRegistration', new.id, null, null);
  end if;
  return new;
end $$;
create trigger profiles_registration after insert or update of is_guest on public.profiles for each row execute function private.registration_event();

create function public.create_order(p_plan uuid) returns jsonb language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); pl public.plans%rowtype; ps public.payment_settings%rowtype; o public.payment_orders%rowtype;
begin
  if not public.is_member() then raise exception 'login required' using errcode = '42501'; end if;
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
    perform private.enqueue_meta('Lead', uid, o.id, null);
  end if;
  return jsonb_build_object('order_id', o.id, 'reference', o.reference, 'amount_paise', o.amount_paise,
    'amount_inr', o.amount_paise / 100, 'plan_name', o.plan_name, 'status', o.status, 'created_at', o.created_at,
    'upi_id', o.upi_id_used, 'payee_name', o.payee_used);
end $$;

create function public.report_result(p_order uuid, p_raw text) returns jsonb language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); o public.payment_orders%rowtype; raw text := coalesce(p_raw, '');
        st text; txn text; ref text; apr text; mode text; recent int; got boolean;
begin
  select * into o from public.payment_orders where id = p_order and user_id = uid for update;
  if not found then raise exception 'order not found'; end if;
  if o.status not in ('pending','submitted') then return private.order_json(o.id); end if;

  update public.payment_orders set raw_result = left(raw, 4000), reported_at = now() where id = o.id;

  st := upper(coalesce(private.upi_param(raw, 'Status'), ''));
  apr := nullif(private.upi_param(raw, 'ApprovalRefNo'), '');
  txn := coalesce(nullif(private.upi_param(raw, 'txnId'), ''), apr);
  ref := private.upi_param(raw, 'txnRef');

  if st in ('FAILURE','FAILED') then
    update public.payment_orders set status = 'failed' where id = o.id;
  elsif st = 'SUCCESS' then
    update public.payment_orders set success_reported = true where id = o.id;
    if lower(coalesce(ref, '')) = lower(o.reference)
       and txn ~ '^[A-Za-z0-9]{6,40}$'
       and o.created_at > now() - interval '2 hours' then
      insert into private.used_payment_utrs (txn_id, order_id) values (upper(txn), o.id) on conflict (txn_id) do nothing;
      get diagnostics recent = row_count;
      got := recent = 1;
      if got then
        update public.payment_orders set txn_id = txn, approval_ref = apr where id = o.id;
        select activation_mode into mode from public.payment_settings where id = 1;
        select count(*) into recent from public.payment_orders
         where user_id = uid and status = 'paid' and activation_kind = 'auto' and activated_at > now() - interval '24 hours';
        if mode = 'manual' or recent >= 3 then
          update public.payment_orders set status = 'review' where id = o.id;
        else
          perform private.activate_order(o.id, 'auto');
        end if;
      end if;
    end if;
  end if;
  return private.order_json(o.id);
end $$;

create function public.claim_free_plan(p_plan uuid) returns timestamptz language plpgsql security definer set search_path = '' as
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
  new_end := now() + make_interval(days => pl.duration_days);
  insert into public.subscriptions (user_id, plan_id, plan_code, plan_name, kind, starts_at, ends_at)
  values (uid, pl.id, pl.code, pl.name, 'free_promo', now(), new_end) returning id into sub_id;
  insert into public.free_plan_claims (user_id, plan_id, promo_id, subscription_id) values (uid, p_plan, promo, sub_id);
  if private.source_of(uid) = 'organic' then
    update public.profiles set ads_access_status = 'pending' where id = uid and ads_access_status in ('none','rejected');
  end if;
  return new_end;
end $$;

create function public.plan_offers() returns jsonb language plpgsql stable security definer set search_path = '' as
$$
declare fm boolean; ids uuid[];
begin
  select a.free_mode into fm from public.app_mode a where a.id = 1;
  select coalesce(array_agg(p.id), '{}') into ids from public.plans p where p.active and public.free_plan_for_me(p.id);
  return jsonb_build_object(
    'free_plan_ids', to_jsonb(ids),
    'payments_available', (not fm) and public.payments_available(),
    'plans_visible', (not fm) and public.plans_visible_for_me());
end $$;

create function public.provider_payment_update(p_reference text, p_txn text, p_status text, p_amount_paise bigint) returns jsonb
language plpgsql security definer set search_path = '' as
$$
declare o public.payment_orders%rowtype; got int;
begin
  select * into o from public.payment_orders where reference = p_reference for update;
  if not found then return jsonb_build_object('result', 'unknown_reference'); end if;
  if o.status in ('paid','revoked') then return private.order_json(o.id); end if;
  if upper(p_status) in ('FAILURE','FAILED') then
    update public.payment_orders set status = 'failed' where id = o.id and status in ('pending','submitted','review');
    return private.order_json(o.id);
  end if;
  if upper(p_status) <> 'SUCCESS' then return private.order_json(o.id); end if;
  if p_amount_paise is distinct from o.amount_paise then
    update public.payment_orders set status = 'review', admin_note = 'webhook amount mismatch' where id = o.id;
    return private.order_json(o.id);
  end if;
  if p_txn is null or p_txn !~ '^[A-Za-z0-9]{6,40}$' then return private.order_json(o.id); end if;
  insert into private.used_payment_utrs (txn_id, order_id) values (upper(p_txn), o.id) on conflict (txn_id) do nothing;
  get diagnostics got = row_count;
  if got = 0 and not exists (select 1 from private.used_payment_utrs where txn_id = upper(p_txn) and order_id = o.id) then
    return jsonb_build_object('result', 'txn_reused');
  end if;
  update public.payment_orders set txn_id = p_txn, success_reported = true, bank_verified = true, bank_verified_at = now() where id = o.id;
  perform private.activate_order(o.id, 'webhook');
  return private.order_json(o.id);
end $$;

update public.payment_settings set upi_id = '2728412a@bandhan', payee_name = 'As Enterprice', enabled = true, activation_mode = 'manual' where id = 1;

do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f' and p.proname <> 'rls_auto_enable' loop
    execute format('revoke execute on function %s from public, anon', r.sig);
    if r.proname = 'provider_payment_update' then
      execute format('revoke execute on function %s from authenticated', r.sig);
      execute format('grant execute on function %s to service_role', r.sig);
    else
      execute format('grant execute on function %s to authenticated, service_role', r.sig);
    end if;
  end loop;
end $$;
