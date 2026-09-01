-- Respaldo opcional del repositorio documental local.
-- SQLite sigue siendo la fuente principal y estas tablas no participan en el
-- guardado interactivo de la aplicación.

create table if not exists public.todo_knowledge_pages (
  owner_email text not null,
  page_id text not null,
  parent_id text,
  title text not null,
  document jsonb not null default '{}'::jsonb,
  properties jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  local_revision integer not null default 1,
  content_hash text not null,
  deleted_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (owner_email, page_id)
);

create table if not exists public.todo_knowledge_collections (
  owner_email text not null,
  collection_id text not null,
  page_id text not null,
  name text not null,
  schema jsonb not null default '[]'::jsonb,
  views jsonb not null default '[]'::jsonb,
  content_hash text not null,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (owner_email, collection_id)
);

create table if not exists public.todo_knowledge_revisions (
  owner_email text not null,
  revision_id text not null,
  page_id text not null,
  title text not null,
  document jsonb not null,
  properties jsonb not null default '{}'::jsonb,
  reason text not null,
  source_device text not null default '',
  created_at timestamptz not null,
  primary key (owner_email, revision_id)
);

create table if not exists public.todo_knowledge_assets (
  owner_email text not null,
  asset_id text not null,
  sha256 text not null,
  mime_type text not null,
  relative_path text not null,
  size_bytes bigint not null,
  provenance jsonb not null default '{}'::jsonb,
  storage_path text,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (owner_email, asset_id),
  unique (owner_email, sha256)
);

-- Solo se respalda el estado derivado. Las rutas, slots y bytes de partidas
-- guardadas permanecen exclusivamente en el equipo local.
create table if not exists public.todo_knowledge_progress (
  owner_email text not null,
  root_page_id text not null,
  progress_key text not null,
  value jsonb,
  source text not null default 'manual',
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (owner_email, root_page_id, progress_key)
);

alter table public.todo_knowledge_pages enable row level security;
alter table public.todo_knowledge_collections enable row level security;
alter table public.todo_knowledge_revisions enable row level security;
alter table public.todo_knowledge_assets enable row level security;
alter table public.todo_knowledge_progress enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'todo_knowledge_pages',
    'todo_knowledge_collections',
    'todo_knowledge_revisions',
    'todo_knowledge_assets',
    'todo_knowledge_progress'
  ] loop
    execute format('drop policy if exists todo_knowledge_select_own on public.%I', table_name);
    execute format(
      'create policy todo_knowledge_select_own on public.%I for select to authenticated using ((auth.jwt() ->> ''email'') = owner_email)',
      table_name
    );
    execute format('drop policy if exists todo_knowledge_insert_own on public.%I', table_name);
    execute format(
      'create policy todo_knowledge_insert_own on public.%I for insert to authenticated with check ((auth.jwt() ->> ''email'') = owner_email)',
      table_name
    );
    execute format('drop policy if exists todo_knowledge_update_own on public.%I', table_name);
    execute format(
      'create policy todo_knowledge_update_own on public.%I for update to authenticated using ((auth.jwt() ->> ''email'') = owner_email) with check ((auth.jwt() ->> ''email'') = owner_email)',
      table_name
    );
    execute format('drop policy if exists todo_knowledge_delete_own on public.%I', table_name);
    execute format(
      'create policy todo_knowledge_delete_own on public.%I for delete to authenticated using ((auth.jwt() ->> ''email'') = owner_email)',
      table_name
    );
  end loop;
end;
$$;

insert into storage.buckets (id, name, public)
values ('todo-knowledge-assets', 'todo-knowledge-assets', false)
on conflict (id) do update set public = false;

drop policy if exists todo_knowledge_assets_select_own on storage.objects;
create policy todo_knowledge_assets_select_own
on storage.objects for select to authenticated
using (
  bucket_id = 'todo-knowledge-assets'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'email')
);

drop policy if exists todo_knowledge_assets_insert_own on storage.objects;
create policy todo_knowledge_assets_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'todo-knowledge-assets'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'email')
);

drop policy if exists todo_knowledge_assets_update_own on storage.objects;
create policy todo_knowledge_assets_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'todo-knowledge-assets'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'email')
)
with check (
  bucket_id = 'todo-knowledge-assets'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'email')
);

drop policy if exists todo_knowledge_assets_delete_own on storage.objects;
create policy todo_knowledge_assets_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'todo-knowledge-assets'
  and (storage.foldername(name))[1] = (auth.jwt() ->> 'email')
);
