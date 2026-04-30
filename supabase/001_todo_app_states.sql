create extension if not exists pgcrypto;

create table if not exists public.todo_app_states (
  owner_email text primary key,
  schema_version integer not null default 1,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.todo_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists todo_touch_updated_at on public.todo_app_states;

create trigger todo_touch_updated_at
before update on public.todo_app_states
for each row
execute function public.todo_touch_updated_at();

alter table public.todo_app_states enable row level security;

drop policy if exists "todo_select_own_state" on public.todo_app_states;
create policy "todo_select_own_state"
on public.todo_app_states
for select
to authenticated
using ((auth.jwt() ->> 'email') = owner_email);

drop policy if exists "todo_insert_own_state" on public.todo_app_states;
create policy "todo_insert_own_state"
on public.todo_app_states
for insert
to authenticated
with check ((auth.jwt() ->> 'email') = owner_email);

drop policy if exists "todo_update_own_state" on public.todo_app_states;
create policy "todo_update_own_state"
on public.todo_app_states
for update
to authenticated
using ((auth.jwt() ->> 'email') = owner_email)
with check ((auth.jwt() ->> 'email') = owner_email);
