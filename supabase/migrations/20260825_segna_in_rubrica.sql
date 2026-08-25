-- Segna un elenco di clienti come "gia' presenti nell'agenda del telefono".
--
-- Serve dopo aver importato il file dei contatti sull'iPhone: senza, l'app
-- continuerebbe a proporre gli stessi nomi alla successiva esportazione e si
-- creerebbero doppioni in rubrica.
--
-- Aggiungere un valore a un array non si esprime con le chiamate dirette alle
-- tabelle, e aggiornare trecento schede una per una sarebbe lentissimo: da qui
-- si fa in una sola istruzione.
--
-- `security invoker`: la funzione agisce con i permessi di chi la chiama,
-- quindi restano valide le regole che limitano lo staff al proprio ristorante.

create or replace function public.segna_in_rubrica(ids uuid[])
returns integer
language sql
security invoker
set search_path = public
as $$
  with aggiornate as (
    update public.guests
    set tags = array_append(coalesce(tags, array[]::text[]), 'rubrica')
    where id = any(ids)
      and not ('rubrica' = any(coalesce(tags, array[]::text[])))
    returning 1
  )
  select count(*)::int from aggiornate;
$$;

-- Gli anonimi non devono nemmeno poterla chiamare.
revoke all on function public.segna_in_rubrica(uuid[]) from anon;
grant execute on function public.segna_in_rubrica(uuid[]) to authenticated;
