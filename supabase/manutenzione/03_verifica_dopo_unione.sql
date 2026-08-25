-- Verifica dopo l'unione. Legge soltanto.
--
-- "prenotazioni orfane" deve essere 0: se non lo fosse, qualche prenotazione
-- punterebbe a una scheda cancellata e si dovrebbe ripristinare da
-- `public.guests_uniti`.

select 'schede cliente rimaste' as voce, count(*)::text as valore
from public.guests
union all select 'schede unite e archiviate',
  (select count(*)::text from public.guests_uniti)
union all select 'prenotazioni senza cliente',
  (select count(*)::text from public.bookings where guest_id is null)
union all select 'prenotazioni orfane',
  (select count(*)::text from public.bookings b
   where b.guest_id is not null
     and not exists (select 1 from public.guests g where g.id = b.guest_id))
union all select 'lista attesa orfana',
  (select count(*)::text from public.waitlist w
   where w.guest_id is not null
     and not exists (select 1 from public.guests g where g.id = w.guest_id))
union all select 'doppioni residui per email',
  (select count(*)::text from (
     select lower(trim(email)) e from public.guests
     where nullif(lower(trim(email)), '') is not null
     group by 1 having count(*) > 1) x);
