-- Run this file once in the Supabase SQL Editor for this project.
-- It creates private, per-user storage for the Daylight app.
--
-- Changes from v1:
--   • profiles now stores first_name, last_name, full_name collected at sign-up.
--   • The on_auth_user_created trigger syncs those fields from raw_user_meta_data.
--   • Password strength is enforced client-side (min 6 chars, alphanumeric).

create extension if not exists pgcrypto;

-- ── Profiles ──────────────────────────────────────────────────────────────────
-- One row per authenticated user. Populated automatically on sign-up via trigger.

create table if not exists public.profiles (
  id         uuid        primary key references auth.users (id) on delete cascade,
  email      text,
  first_name text        check (char_length(first_name) <= 64),
  last_name  text        check (char_length(last_name)  <= 64),
  full_name  text        check (char_length(full_name)  <= 130),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── Categories ────────────────────────────────────────────────────────────────

create table if not exists public.categories (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 48),
  color_value integer     not null,
  created_at  timestamptz not null default now(),
  unique (user_id, name)
);

-- ── Activities ────────────────────────────────────────────────────────────────

create table if not exists public.activities (
  id           text        primary key,
  user_id      uuid        not null references auth.users (id) on delete cascade,
  entry_date   date        not null,
  title        text        not null check (char_length(title) between 1 and 160),
  start_minute integer     not null check (start_minute >= 0 and start_minute < 1440),
  end_minute   integer     not null check (end_minute > start_minute and end_minute <= 1440),
  category     text        not null,
  note         text        not null default '',
  carried      boolean     not null default false,
  source_id    text,
  updated_at   timestamptz not null default now()
);

create index if not exists activities_user_date_idx
  on public.activities (user_id, entry_date);

-- ── Goals ─────────────────────────────────────────────────────────────────────

create table if not exists public.goals (
  id         text        primary key,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null check (char_length(name) between 1 and 100),
  category   text        not null,
  schedule   text        not null check (schedule in ('Daily', 'Weekly', 'Specific days')),
  target     integer     not null check (target > 0),
  is_duration boolean    not null,
  weekdays   smallint[]  not null default '{}',
  created_at timestamptz not null default now()
);

-- ── Row Level Security ────────────────────────────────────────────────────────

alter table public.profiles    enable row level security;
alter table public.categories  enable row level security;
alter table public.activities  enable row level security;
alter table public.goals       enable row level security;

drop policy if exists "Users manage their own profile"     on public.profiles;
drop policy if exists "Users manage their own categories"  on public.categories;
drop policy if exists "Users manage their own activities"  on public.activities;
drop policy if exists "Users manage their own goals"       on public.goals;

create policy "Users manage their own profile"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Users manage their own categories"
  on public.categories for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage their own activities"
  on public.activities for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage their own goals"
  on public.goals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── Auto-create profile on sign-up ───────────────────────────────────────────
-- Reads first_name, last_name, full_name from the user_metadata supplied by
-- the Flutter app during auth.signUp(data: {...}).

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, first_name, last_name, full_name)
  values (
    new.id,
    new.email,
    (new.raw_user_meta_data ->> 'first_name'),
    (new.raw_user_meta_data ->> 'last_name'),
    (new.raw_user_meta_data ->> 'full_name')
  )
  on conflict (id) do update
    set
      email      = excluded.email,
      first_name = coalesce(excluded.first_name, public.profiles.first_name),
      last_name  = coalesce(excluded.last_name,  public.profiles.last_name),
      full_name  = coalesce(excluded.full_name,  public.profiles.full_name),
      updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();

-- ── Migration: add new columns to existing profiles table ────────────────────
-- Run these lines only if you already had the old schema deployed.
-- Safe to re-run — each is guarded by "if not exists" logic.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'profiles'
      and column_name  = 'first_name'
  ) then
    alter table public.profiles
      add column first_name text check (char_length(first_name) <= 64),
      add column last_name  text check (char_length(last_name)  <= 64),
      add column full_name  text check (char_length(full_name)  <= 130),
      add column updated_at timestamptz not null default now();
  end if;
end;
$$;
