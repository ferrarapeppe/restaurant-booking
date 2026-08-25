-- Chiude il database agli anonimi.
--
-- Fino a oggi la chiave anonima, che e' pubblica dentro il sito, permetteva di
-- leggere e riscrivere l'anagrafica clienti, le prenotazioni e i messaggi.
-- Il modulo e la pagina di stato ora passano dalla funzione `public-booking`,
-- che usa la chiave di servizio: nessuna pagina pubblica ha piu' bisogno di
-- parlare direttamente alle tabelle.
--
-- ATTENZIONE: eseguire questa migrazione solo dopo aver pubblicato le pagine
-- che usano `public-booking`. Prima, il modulo smetterebbe di funzionare.

-- ── 1. L'anonimo perde ogni privilegio ──────────────────────────────────────
-- Questo da solo blocca tutto, a prescindere dalle policy: senza privilegi di
-- tabella non si arriva nemmeno a valutare le regole per riga.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;

-- ── 2. Lo staff autenticato opera solo sul proprio ristorante ───────────────
-- Serve anche fra colleghi: un membro con la sola sezione Calendario non deve
-- poter tirare giu' l'anagrafica clienti chiamando l'API a mano.
create or replace function public.ristorante_dello_staff()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select restaurant_id
  from public.staff_members
  where id = auth.uid() and active
  limit 1;
$$;

-- Il ristorante si riconosce dalla propria chiave primaria.
alter table public.restaurants enable row level security;
drop policy if exists "staff sul proprio ristorante" on public.restaurants;
create policy "staff sul proprio ristorante"
  on public.restaurants for all to authenticated
  using (id = public.ristorante_dello_staff())
  with check (id = public.ristorante_dello_staff());

-- Le altre tabelle portano restaurant_id.
do $$
declare t text;
begin
  foreach t in array array['opening_hours', 'areas', 'tables', 'guests', 'bookings']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "staff sul proprio ristorante" on public.%I', t);
    execute format($p$
      create policy "staff sul proprio ristorante"
        on public.%I for all to authenticated
        using (restaurant_id = public.ristorante_dello_staff())
        with check (restaurant_id = public.ristorante_dello_staff())
    $p$, t);
  end loop;
end $$;

-- I messaggi non hanno restaurant_id: si risale dalla prenotazione.
alter table public.booking_messages enable row level security;
drop policy if exists "staff sul proprio ristorante" on public.booking_messages;
create policy "staff sul proprio ristorante"
  on public.booking_messages for all to authenticated
  using (exists (
    select 1 from public.bookings b
    where b.id = booking_id and b.restaurant_id = public.ristorante_dello_staff()
  ))
  with check (exists (
    select 1 from public.bookings b
    where b.id = booking_id and b.restaurant_id = public.ristorante_dello_staff()
  ));
