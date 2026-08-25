-- Rimozione delle quattro schede di prova rimaste dallo sviluppo.
--
-- Riconoscibili dai nomi di fantasia (Rossi, Verdi), dagli indirizzi inventati
-- (ddd@rrd.it, r@r.it) e dai numeri non validi. Verificato: nessuna ha
-- prenotazioni collegate.
--
-- Le schede finiscono per intero in `public.guests_cancellati` prima di
-- sparire, quindi si possono rileggere o ripristinare.

do $$
declare
  n int;
begin
  create table if not exists public.guests_cancellati (
    id            uuid primary key,
    scheda        jsonb       not null,
    motivo        text        not null,
    cancellato_il timestamptz not null default now()
  );
  alter table public.guests_cancellati enable row level security;

  with bersagli as (
    select id, to_jsonb(g) as scheda
    from public.guests g
    where g.email in ('ddd@rrd.it', 'giovanna@gmail.com', 'r@r.it', 'g.verdi@tin.it')
      -- cintura di sicurezza: mai toccare una scheda con prenotazioni
      and not exists (select 1 from public.bookings b where b.guest_id = g.id)
      and not exists (select 1 from public.waitlist w where w.guest_id = g.id)
  ),
  archiviate as (
    insert into public.guests_cancellati (id, scheda, motivo)
    select id, scheda, 'scheda di prova dello sviluppo' from bersagli
    on conflict (id) do nothing
    returning 1
  )
  delete from public.guests g using bersagli b where g.id = b.id;
  get diagnostics n = row_count;

  raise notice 'schede di prova rimosse: %', n;
end $$;
