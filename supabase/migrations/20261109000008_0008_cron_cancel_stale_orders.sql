
create extension if not exists pg_cron;

create function private.cancel_stale_orders() returns void language sql security definer set search_path = '' as
$$
  update public.payment_orders set status = 'cancelled'
   where status = 'pending' and not success_reported and created_at < now() - interval '24 hours'
$$;

select cron.schedule('cancel-stale-orders', '*/30 * * * *', 'select private.cancel_stale_orders()');
