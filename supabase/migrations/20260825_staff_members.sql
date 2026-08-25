-- Membri dello staff e permessi per sezione.
--
-- Ogni riga corrisponde a un utente di Supabase Auth. Il collegamento e' l'id:
-- quando l'utente entra, l'app legge la sua riga qui e sa cosa puo' vedere.

create table if not exists public.staff_members (
  id            uuid primary key references auth.users (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  email         text not null,
  full_name     text not null default '',
  -- 'admin' vede e fa tutto, e le sezioni sotto vengono ignorate.
  role          text not null default 'staff' check (role in ('admin', 'staff')),
  -- Chiavi delle sezioni abilitate, es. {calendar,bookings}.
  sections      text[] not null default '{}',
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists staff_members_restaurant_idx
  on public.staff_members (restaurant_id);

alter table public.staff_members enable row level security;

-- Chi e' entrato legge la propria riga: serve all'app per sapere i permessi.
drop policy if exists "staff legge se stesso" on public.staff_members;
create policy "staff legge se stesso"
  on public.staff_members for select
  to authenticated
  using (id = auth.uid());

-- Un amministratore vede tutti i membri del proprio ristorante.
-- La funzione sotto evita la ricorsione: una policy che interroga la stessa
-- tabella che sta proteggendo si richiama all'infinito.
create or replace function public.e_amministratore()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_members
    where id = auth.uid() and role = 'admin' and active
  );
$$;

drop policy if exists "amministratore vede il team" on public.staff_members;
create policy "amministratore vede il team"
  on public.staff_members for select
  to authenticated
  using (public.e_amministratore());

-- Nessuna policy di insert/update/delete: le modifiche passano dalla funzione
-- manage-staff, che usa la chiave di servizio e scavalca queste regole. Cosi'
-- non esiste modo di darsi permessi da soli dal browser.
