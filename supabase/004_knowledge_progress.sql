-- Progreso derivado/manual de Biblioteca. Las rutas de fuentes importadas se
-- conservan exclusivamente en SQLite local y nunca se sincronizan.
create table if not exists public.todo_knowledge_progress (
  owner_email text not null,
  root_page_id text not null,
  progress_key text not null,
  value jsonb,
  source text not null default 'manual',
  updated_at timestamptz not null default now(),
  primary key (owner_email, root_page_id, progress_key)
);

alter table public.todo_knowledge_progress enable row level security;

drop policy if exists todo_knowledge_select_own on public.todo_knowledge_progress;
create policy todo_knowledge_select_own
on public.todo_knowledge_progress for select to authenticated
using ((auth.jwt() ->> 'email') = owner_email);

drop policy if exists todo_knowledge_insert_own on public.todo_knowledge_progress;
create policy todo_knowledge_insert_own
on public.todo_knowledge_progress for insert to authenticated
with check ((auth.jwt() ->> 'email') = owner_email);

drop policy if exists todo_knowledge_update_own on public.todo_knowledge_progress;
create policy todo_knowledge_update_own
on public.todo_knowledge_progress for update to authenticated
using ((auth.jwt() ->> 'email') = owner_email)
with check ((auth.jwt() ->> 'email') = owner_email);

drop policy if exists todo_knowledge_delete_own on public.todo_knowledge_progress;
create policy todo_knowledge_delete_own
on public.todo_knowledge_progress for delete to authenticated
using ((auth.jwt() ->> 'email') = owner_email);
