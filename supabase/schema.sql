-- OmiWave database schema
-- Run this once in Supabase Dashboard > SQL Editor.
-- All user-owned tables use Row Level Security (RLS).

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null default 'New member' check (char_length(display_name) <= 50),
  avatar_url text,
  bio text not null default '' check (char_length(bio) <= 180),
  created_at timestamptz not null default now()
);

create table if not exists public.waves (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 90),
  description text not null default '' check (char_length(description) <= 1200),
  category text not null default 'Creative',
  visibility text not null default 'public' check (visibility in ('public','private')),
  created_at timestamptz not null default now()
);

create table if not exists public.wave_members (
  wave_id uuid not null references public.waves(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (wave_id, user_id)
);

create table if not exists public.spaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 3 and 60),
  description text not null default '' check (char_length(description) <= 500),
  created_at timestamptz not null default now()
);

create table if not exists public.space_members (
  space_id uuid not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null check (kind in ('follow','wave_join','message')),
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists waves_created_at_idx on public.waves(created_at desc);
create index if not exists wave_members_user_idx on public.wave_members(user_id);
create index if not exists messages_pair_idx on public.messages(sender_id, recipient_id, created_at desc);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.waves enable row level security;
alter table public.wave_members enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.follows enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;

-- Profiles: visible to signed-in users; only the owner can edit their profile.
create policy "Profiles are visible to authenticated users" on public.profiles
  for select to authenticated using (true);
create policy "Users create their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
create policy "Users update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Public Waves can be discovered by signed-in members. Private Waves are creator-only for now.
create policy "Read public Waves" on public.waves
  for select to authenticated using (visibility = 'public' or creator_id = auth.uid());
create policy "Create own Waves" on public.waves
  for insert to authenticated with check (creator_id = auth.uid());
create policy "Update own Waves" on public.waves
  for update to authenticated using (creator_id = auth.uid()) with check (creator_id = auth.uid());
create policy "Delete own Waves" on public.waves
  for delete to authenticated using (creator_id = auth.uid());

create policy "Read Wave membership" on public.wave_members
  for select to authenticated using (user_id = auth.uid() or exists (
    select 1 from public.waves w where w.id = wave_id and w.creator_id = auth.uid()
  ));
create policy "Join as yourself" on public.wave_members
  for insert to authenticated with check (user_id = auth.uid());
create policy "Leave as yourself" on public.wave_members
  for delete to authenticated using (user_id = auth.uid());

create policy "Spaces are visible to signed-in users" on public.spaces
  for select to authenticated using (true);
create policy "Create own spaces" on public.spaces
  for insert to authenticated with check (owner_id = auth.uid());
create policy "Update own spaces" on public.spaces
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "Delete own spaces" on public.spaces
  for delete to authenticated using (owner_id = auth.uid());

create policy "Read space membership" on public.space_members
  for select to authenticated using (user_id = auth.uid() or exists (
    select 1 from public.spaces s where s.id = space_id and s.owner_id = auth.uid()
  ));
create policy "Join space as yourself" on public.space_members
  for insert to authenticated with check (user_id = auth.uid());
create policy "Leave space as yourself" on public.space_members
  for delete to authenticated using (user_id = auth.uid());

create policy "Read follows" on public.follows
  for select to authenticated using (true);
create policy "Follow as yourself" on public.follows
  for insert to authenticated with check (follower_id = auth.uid());
create policy "Unfollow as yourself" on public.follows
  for delete to authenticated using (follower_id = auth.uid());

-- Only sender and recipient can read a direct message. Sender can create; recipient cannot spoof messages.
create policy "Participants read messages" on public.messages
  for select to authenticated using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy "Send messages as yourself" on public.messages
  for insert to authenticated with check (sender_id = auth.uid());

create policy "Read own notifications" on public.notifications
  for select to authenticated using (user_id = auth.uid());
create policy "Mark own notifications read" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Automatically create a profile after email/password or OAuth sign-up.
-- The username is a temporary unique handle; users can change it in profile settings later.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_name text;
  candidate text;
begin
  base_name := lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1), 'member'), '[^a-zA-Z0-9_]', '', 'g'));
  if char_length(base_name) < 3 then base_name := 'member'; end if;
  candidate := left(base_name, 16) || '_' || left(replace(new.id::text, '-', ''), 6);

  insert into public.profiles (id, username, display_name)
  values (new.id, candidate, coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), 'New member'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Optional realtime: enable the waves and messages tables in Supabase
-- Dashboard > Database > Publications > supabase_realtime.
