
create schema if not exists private;

-- ============ global config ============
create table public.app_mode (
  id int primary key default 1 check (id = 1),
  free_mode boolean not null default false,
  plans_visible_for text not null default 'everyone' check (plans_visible_for in ('everyone','ads','organic','none')),
  free_plans_for text not null default 'none' check (free_plans_for in ('none','organic','ads','everyone')),
  promo_id int not null default 0,
  updated_at timestamptz not null default now()
);
insert into public.app_mode (id) values (1);

create table public.plan_catalog (
  id int primary key default 1 check (id = 1),
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);
insert into public.plan_catalog (id) values (1);

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{1,30}$'),
  name text not null check (length(trim(name)) > 0),
  price_inr integer not null check (price_inr >= 1),
  duration_days integer not null check (duration_days >= 1),
  perks text[] not null default '{}',
  badge text,
  position integer not null default 0,
  active boolean not null default true,
  free_eligible boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payment_settings (
  id int primary key default 1 check (id = 1),
  upi_id text not null default '' check (upi_id = '' or upi_id ~ '^[A-Za-z0-9._-]{2,256}@[A-Za-z0-9]{2,64}$'),
  payee_name text not null default '',
  enabled boolean not null default true,
  activation_mode text not null default 'instant' check (activation_mode in ('instant','manual')),
  updated_at timestamptz not null default now()
);
insert into public.payment_settings (id) values (1);

create table public.play_settings (
  id int primary key default 1 check (id = 1),
  play_billing_enabled boolean not null default false,
  google_approval_confirmed boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.play_settings (id) values (1);

-- ============ accounts ============
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  is_guest boolean not null default true,
  used_bytes bigint not null default 0 check (used_bytes >= 0),
  ads_access_status text not null default 'none' check (ads_access_status in ('none','pending','approved','rejected')),
  play_verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table private.owner_bootstrap (email text primary key);
insert into private.owner_bootstrap (email) values ('liveperfumes7@gmail.com');

create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','content')),
  created_at timestamptz not null default now()
);

create table public.consents (
  user_id uuid not null references auth.users(id) on delete cascade,
  policy_version text not null,
  accepted_at timestamptz not null default now(),
  primary key (user_id, policy_version)
);

-- ============ attribution ============
create table public.installs (
  install_id text primary key,
  user_id uuid references auth.users(id) on delete set null,
  source text not null check (source in ('ads','organic')),
  referrer_status text,
  raw_referrer text,
  utm_campaign text,
  install_secret text,
  created_at timestamptz not null default now()
);
create index installs_user_idx on public.installs (user_id);
create index installs_source_idx on public.installs (source, utm_campaign);

create table private.user_sources (
  user_id uuid primary key references auth.users(id) on delete cascade,
  source text not null check (source in ('ads','organic')),
  created_at timestamptz not null default now()
);

create table public.ad_clicks (
  id uuid primary key default gen_random_uuid(),
  fbclid text,
  fbc text,
  fbp text,
  ip text,
  user_agent text,
  created_at timestamptz not null default now()
);

-- ============ channels & posts ============
create table public.channels (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 80),
  description text not null default '',
  category text,
  tags text[] not null default '{}',
  icon_url text,
  audience text not null default 'all' check (audience in ('all','organic','ads')),
  status text not null default 'draft' check (status in ('draft','published','active')),
  review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
  created_by uuid references auth.users(id) on delete set null,
  members_count integer not null default 0 check (members_count >= 0),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index channels_created_by_idx on public.channels (created_by);
create index channels_review_idx on public.channels (review_status, status);

create table public.admin_channel_access (
  user_id uuid not null references auth.users(id) on delete cascade,
  channel_id uuid not null references public.channels(id) on delete cascade,
  primary key (user_id, channel_id)
);
create index admin_channel_access_channel_idx on public.admin_channel_access (channel_id);

create table public.channel_members (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);
create index channel_members_user_idx on public.channel_members (user_id);

create table public.channel_folders (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  name text not null,
  position integer not null default 0
);
create index channel_folders_channel_idx on public.channel_folders (channel_id);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  folder_id uuid references public.channel_folders(id) on delete set null,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  audience text not null default 'all' check (audience in ('all','organic','ads')),
  status text not null default 'draft' check (status in ('draft','published','scheduled')),
  publish_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index posts_channel_idx on public.posts (channel_id, created_at desc);
create index posts_folder_idx on public.posts (folder_id);
create index posts_created_by_idx on public.posts (created_by);
create index posts_feed_idx on public.posts (status, created_at desc);

create table public.post_items (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  media_key text not null,
  thumbnail_key text,
  mime text not null default 'video/mp4',
  is_premium boolean not null default false,
  duration_s integer check (duration_s is null or duration_s >= 0),
  trailer_key text,
  position integer not null default 0,
  size_bytes bigint not null default 0
);
create index post_items_post_idx on public.post_items (post_id, position);

create table public.blocked_channels (
  user_id uuid not null references auth.users(id) on delete cascade,
  channel_id uuid not null references public.channels(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, channel_id)
);
create index blocked_channels_channel_idx on public.blocked_channels (channel_id);

create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  kind text not null check (kind in ('report','deletion','other')),
  target_type text check (target_type in ('post','channel','account')),
  target_id uuid,
  reason text,
  details text,
  email text,
  status text not null default 'open' check (status in ('open','closed')),
  created_at timestamptz not null default now()
);
create index support_requests_user_idx on public.support_requests (user_id);
create index support_requests_status_idx on public.support_requests (status, created_at desc);

-- ============ personal cloud ============
create table public.cloud_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid references public.cloud_folders(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);
create index cloud_folders_user_idx on public.cloud_folders (user_id, parent_id);
create index cloud_folders_parent_idx on public.cloud_folders (parent_id);

create table public.cloud_files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  folder_id uuid references public.cloud_folders(id) on delete set null,
  name text not null check (length(trim(name)) > 0),
  storage_path text not null unique,
  mime text,
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  created_at timestamptz not null default now()
);
create index cloud_files_user_idx on public.cloud_files (user_id, folder_id);
create index cloud_files_folder_idx on public.cloud_files (folder_id);

-- ============ subscriptions ============
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid references public.plans(id),
  plan_code text,
  plan_name text,
  kind text not null check (kind in ('payment','free_promo','admin_grant')),
  order_id uuid unique,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);
create index subscriptions_user_idx on public.subscriptions (user_id, ends_at desc);
create index subscriptions_plan_idx on public.subscriptions (plan_id);

-- seed plans (editable later in admin)
insert into public.plans (code, name, price_inr, duration_days, perks, badge, position) values
 ('trial','Trial',49,7,array['2 TB cloud storage','Full-length premium videos','Offline downloads'],null,1),
 ('silver','Silver',129,7,array['2 TB cloud storage','Full-length premium videos','Offline downloads'],null,2),
 ('gold','Gold',259,30,array['2 TB cloud storage','Full-length premium videos','Offline downloads','Priority support'],'Popular',3),
 ('platinum','Platinum',599,180,array['2 TB cloud storage','Full-length premium videos','Offline downloads','Priority support'],null,4),
 ('diamond','Diamond',999,365,array['2 TB cloud storage','Full-length premium videos','Offline downloads','Priority support'],'Best value',5);
