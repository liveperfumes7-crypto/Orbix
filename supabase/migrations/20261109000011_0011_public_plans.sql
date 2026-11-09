
create or replace function public.public_plans()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id, 'code', code, 'name', name, 'price_inr', price_inr,
    'duration_days', duration_days, 'perks', perks, 'badge', badge, 'position', position
  ) order by position), '[]'::jsonb)
  from public.plans where active;
$$;
revoke all on function public.public_plans() from public;
grant execute on function public.public_plans() to anon, authenticated, service_role;
