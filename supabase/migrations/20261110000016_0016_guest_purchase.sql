-- Guests (anonymous sessions) may buy a plan; they can add an email later (updateUser keeps the same user id).
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
    perform private.enqueue_meta('Lead', uid, o.id, null);
  end if;
  return jsonb_build_object('order_id', o.id, 'reference', o.reference, 'amount_paise', o.amount_paise,
    'amount_inr', o.amount_paise / 100, 'plan_name', o.plan_name, 'status', o.status, 'created_at', o.created_at,
    'upi_id', o.upi_id_used, 'payee_name', o.payee_used);
end $$;
