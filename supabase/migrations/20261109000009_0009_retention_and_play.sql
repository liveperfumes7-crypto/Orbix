
-- keep payment records (anonymised) when an account is deleted: legal/tax retention
alter table public.payment_orders alter column user_id drop not null;
alter table public.payment_orders drop constraint payment_orders_user_id_fkey;
alter table public.payment_orders add constraint payment_orders_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null;
alter table public.payment_orders add column email_at_purchase text;

create or replace function private.order_snapshot() returns trigger language plpgsql security definer set search_path = '' as
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
  select email into new.email_at_purchase from auth.users where id = new.user_id;
  new.reference := 'OB' || to_char(now() at time zone 'Asia/Kolkata', 'YYMMDD') || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  new.status := 'pending'; new.success_reported := false; new.raw_result := null;
  new.txn_id := null; new.utr := null; new.activated_at := null; new.activation_kind := null;
  return new;
end $$;

create or replace function public.admin_orders(p_status text default null, p_verify_today boolean default false, p_limit int default 50, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as
$$
declare today date := (now() at time zone 'Asia/Kolkata')::date; res jsonb;
begin
  if not public.is_owner() then raise exception 'forbidden' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) into res from (
    select o.id, o.created_at, coalesce(u.email, o.email_at_purchase) as email, o.user_id, o.plan_name, o.amount_paise / 100 as amount_inr, o.reference,
           coalesce(o.utr, o.txn_id) as txn, o.upi_id_used, o.status, o.activation_kind, o.bank_verified, o.raw_result, o.admin_note
    from public.payment_orders o left join auth.users u on u.id = o.user_id
    where (coalesce(p_status, '') = '' or o.status = p_status)
      and (not p_verify_today or (o.status = 'paid' and o.activation_kind = 'auto' and not o.bank_verified
                                   and (o.activated_at at time zone 'Asia/Kolkata')::date = today))
    order by o.created_at desc limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) x;
  return res;
end $$;

create or replace function public.admin_payment_stats() returns jsonb language plpgsql stable security definer set search_path = '' as
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
        select coalesce(u.email, o.email_at_purchase) as email, count(*) as paid_orders, sum(o.amount_paise) / 100 as spent
        from public.payment_orders o left join auth.users u on u.id = o.user_id
        where o.status = 'paid' group by coalesce(u.email, o.email_at_purchase) having count(*) >= 2 order by 2 desc limit 50) x), '[]'::jsonb));
end $$;

-- Play Integrity (free 15 GB cloud for verified Play installs)
create table private.play_challenges (
  nonce text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  used boolean not null default false,
  created_at timestamptz not null default now()
);
create index play_challenges_user_idx on private.play_challenges (user_id, created_at desc);

create function public.play_integrity_challenge() returns text language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid(); n text;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if (select count(*) from private.play_challenges where user_id = uid and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'too many requests';
  end if;
  n := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into private.play_challenges (nonce, user_id, expires_at) values (n, uid, now() + interval '10 minutes');
  return n;
end $$;

create function public.enable_play_free_cloud(p_user uuid, p_nonce text) returns boolean language plpgsql security definer set search_path = '' as
$$
begin
  update private.play_challenges set used = true
   where nonce = p_nonce and user_id = p_user and not used and expires_at > now();
  if not found then return false; end if;
  update public.profiles set play_verified = true where id = p_user;
  return true;
end $$;
revoke execute on function public.enable_play_free_cloud(uuid, text) from public, anon, authenticated;
grant execute on function public.enable_play_free_cloud(uuid, text) to service_role;
revoke execute on function public.play_integrity_challenge() from public, anon;
grant execute on function public.play_integrity_challenge() to authenticated, service_role;

-- Google Play billing scaffold (stays OFF until play_settings flags are enabled; see docs/play-billing.md)
create table public.play_products (
  id uuid primary key default gen_random_uuid(),
  play_product_id text not null,
  base_plan_id text,
  plan_id uuid references public.plans(id),
  created_at timestamptz not null default now(),
  unique (play_product_id, base_plan_id)
);
create index play_products_plan_idx on public.play_products (plan_id);

create table public.play_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  product_id uuid references public.play_products(id),
  purchase_token text not null unique,
  status text not null default 'pending' check (status in ('pending','verified','reported','failed')),
  verified_at timestamptz, reported_at timestamptz,
  external_transaction_id text, last_error text,
  created_at timestamptz not null default now()
);
create index play_purchases_user_idx on public.play_purchases (user_id);
create index play_purchases_product_idx on public.play_purchases (product_id);

alter table public.play_products enable row level security;
alter table public.play_purchases enable row level security;
create policy play_products_owner on public.play_products for all to authenticated using ((select public.is_owner())) with check ((select public.is_owner()));
create policy play_purchases_owner_read on public.play_purchases for select to authenticated using ((select public.is_owner()));
