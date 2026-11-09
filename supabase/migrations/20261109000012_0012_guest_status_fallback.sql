create or replace function public.guest_status() returns jsonb language sql stable security definer set search_path = '' as
$$
 select jsonb_build_object(
   'is_guest', true, 'is_premium', false, 'can_play_premium', false,
   'free_mode', am.free_mode,
   'plans_visible', (not am.free_mode) and am.plans_visible_for = 'everyone',
   'quota_bytes', 0, 'used_bytes', 0)
 from public.app_mode am where am.id = 1
$$;
revoke all on function public.guest_status() from public;
grant execute on function public.guest_status() to anon, authenticated;
