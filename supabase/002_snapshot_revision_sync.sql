alter table public.todo_app_states
  add column if not exists revision integer not null default 0,
  add column if not exists updated_by_device text not null default '',
  add column if not exists updated_by_platform text not null default '',
  add column if not exists state_hash text not null default '',
  add column if not exists last_synced_at timestamptz not null default timezone('utc', now());

create or replace function public.todo_push_state(
  p_owner_email text,
  p_expected_revision integer,
  p_schema_version integer,
  p_state jsonb,
  p_updated_by_device text,
  p_updated_by_platform text,
  p_state_hash text
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  current_row public.todo_app_states%rowtype;
  next_revision integer;
begin
  if (auth.jwt() ->> 'email') is distinct from p_owner_email then
    raise exception 'No puedes sincronizar otra cuenta.';
  end if;

  select *
  into current_row
  from public.todo_app_states
  where owner_email = p_owner_email
  for update;

  if found and current_row.revision <> p_expected_revision then
    return jsonb_build_object(
      'status', 'conflict',
      'revision', current_row.revision,
      'state', current_row.state,
      'updated_at', current_row.updated_at,
      'updated_by_device', current_row.updated_by_device,
      'updated_by_platform', current_row.updated_by_platform,
      'state_hash', current_row.state_hash
    );
  end if;

  next_revision := coalesce(current_row.revision, 0) + 1;

  insert into public.todo_app_states (
    owner_email,
    schema_version,
    state,
    updated_at,
    revision,
    updated_by_device,
    updated_by_platform,
    state_hash,
    last_synced_at
  )
  values (
    p_owner_email,
    p_schema_version,
    p_state,
    timezone('utc', now()),
    next_revision,
    p_updated_by_device,
    p_updated_by_platform,
    p_state_hash,
    timezone('utc', now())
  )
  on conflict (owner_email) do update set
    schema_version = excluded.schema_version,
    state = excluded.state,
    updated_at = excluded.updated_at,
    revision = excluded.revision,
    updated_by_device = excluded.updated_by_device,
    updated_by_platform = excluded.updated_by_platform,
    state_hash = excluded.state_hash,
    last_synced_at = excluded.last_synced_at;

  return jsonb_build_object(
    'status', 'pushed',
    'revision', next_revision,
    'state', p_state,
    'updated_at', timezone('utc', now()),
    'updated_by_device', p_updated_by_device,
    'updated_by_platform', p_updated_by_platform,
    'state_hash', p_state_hash
  );
end;
$$;
