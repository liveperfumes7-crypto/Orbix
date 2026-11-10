-- AppInstall goes to Meta only for installs that came from an ad. Organic and Play-store installs send nothing,
-- which keeps the Play data-safety answers accurate.
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

  if src = 'ads' then
    if v_ip is not null then
      select * into c from public.ad_clicks where ip = v_ip and created_at > now() - interval '7 days' order by created_at desc limit 1;
    end if;
    insert into private.user_attribution (user_id, click_id, fbc, fbp, ip, ua, last_ip, last_ua)
    values (uid, c.id, c.fbc, c.fbp, c.ip, c.user_agent, v_ip, left(private.req_header('user-agent'), 400))
    on conflict (user_id) do nothing;
    perform private.enqueue_meta('AppInstall', uid, null, null);
  end if;
  return src;
end $$;
