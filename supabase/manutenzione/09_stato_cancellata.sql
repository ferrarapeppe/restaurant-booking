-- Aggiunge lo stato `canceled_by_venue` — CANCELLATA dal locale.
--
-- Sono tre cose diverse che prima finivano in due caselle:
--   canceled          il cliente disdice          (ANNULLATA)
--   canceled_by_venue il locale cancella          (CANCELLATA)  <- nuovo
--   rejected          la richiesta non è accolta  (RIFIUTATA)
--
-- Non tocca nessuna riga esistente: aggiunge solo un valore ammesso.
-- Si esegue dall'editor SQL di Supabase. Alla fine stampa cosa ha fatto.

do $$
declare
  tipo   text;
  nome   text;
  regola text;
begin
  select format_type(atttypid, atttypmod) into tipo
  from pg_attribute
  where attrelid = 'public.bookings'::regclass
    and attname = 'status'
    and not attisdropped;

  if tipo is null then
    raise exception 'La colonna bookings.status non esiste.';
  end if;

  -- Caso 1: la colonna è un tipo enumerato. Si aggiunge il valore al tipo.
  if exists (select 1 from pg_type where typname = tipo and typtype = 'e') then
    execute format(
      'alter type public.%I add value if not exists %L', tipo, 'canceled_by_venue');
    raise notice 'Valore aggiunto al tipo enumerato %.', tipo;
    return;
  end if;

  -- Caso 2: è testo. Il limite, se c'è, è un vincolo CHECK da riscrivere.
  select conname, pg_get_constraintdef(oid) into nome, regola
  from pg_constraint
  where conrelid = 'public.bookings'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%status%'
  limit 1;

  if nome is null then
    raise notice 'Colonna % senza vincolo: non serve fare niente.', tipo;
    return;
  end if;

  raise notice 'Vincolo trovato (%): %', nome, regola;
  execute format('alter table public.bookings drop constraint %I', nome);
  execute 'alter table public.bookings add constraint bookings_status_check
    check (status in (
      ''pending'', ''approved'', ''seated'', ''left'', ''completed'',
      ''walkin'', ''no_show'', ''canceled'', ''canceled_by_venue'', ''rejected''
    ))';
  raise notice 'Vincolo riscritto con canceled_by_venue.';
end $$;

-- Verifica: gli stati presenti oggi e quanti sono.
select status, count(*) as quante
from public.bookings
group by status
order by quante desc;
