-- ANTEPRIMA — legge soltanto, non modifica nulla.
--
-- Mostra i 44 gruppi di schede doppie, quale scheda sopravvive e quali dati
-- verrebbero riportati su di lei. Da leggere prima di eseguire lo script 02.
--
-- Criterio: due schede sono la stessa persona se hanno la stessa email
-- (normalizzata) oppure lo stesso telefono (normalizzato). Sopravvive la
-- scheda piu' completa; a parita', la piu' vecchia.

with recursive
base as (
  select id, created_at, name, first_name, surname, email, phone, visits_count,
         nullif(lower(trim(email)), '') as email_n,
         nullif(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), '') as tg
  from public.guests
),
n as (
  select b.*,
    case when length(tg) > 10 and left(tg, 4) = '0039' then substr(tg, 5)
         when length(tg) > 10 and left(tg, 2) = '39'   then substr(tg, 3)
         else tg end as tel_n
  from base b
),
archi as (
  select a.id as x, b.id as y from n a join n b
    on a.email_n = b.email_n and a.email_n is not null and a.id <> b.id
  union
  select a.id, b.id from n a join n b
    on a.tel_n = b.tel_n and a.tel_n is not null and a.id <> b.id
),
raggiunge (origine, nodo) as (
  select id, id from n
  union
  select r.origine, a.y from raggiunge r join archi a on a.x = r.nodo
),
comp as (
  select origine as id, min(nodo::text)::uuid as radice
  from raggiunge group by origine
),
gruppi as (
  select radice from comp group by radice having count(*) > 1
),
punteggi as (
  select c.radice, n.*,
    (case when n.email_n is not null then 1 else 0 end)
  + (case when n.tel_n   is not null then 1 else 0 end)
  + (case when coalesce(trim(n.first_name), '') <> '' then 1 else 0 end)
  + (case when coalesce(trim(n.surname),    '') <> '' then 1 else 0 end)
  + (case when coalesce(trim(n.name),       '') <> '' then 1 else 0 end) as completezza
  from comp c
  join gruppi g on g.radice = c.radice
  join n on n.id = c.id
),
scelti as (
  select radice,
         (array_agg(id order by completezza desc, created_at asc, id::text))[1] as vincitore
  from punteggi group by radice
)
select
  case when p.id = s.vincitore then 'RESTA' else 'unita e cancellata' end as esito,
  coalesce(nullif(trim(p.name), ''),
           trim(coalesce(p.first_name, '') || ' ' || coalesce(p.surname, ''))) as nome,
  coalesce(p.email, '—')   as email,
  coalesce(p.phone, '—')   as telefono,
  coalesce(p.visits_count, 0) as visite,
  (select count(*) from public.bookings b where b.guest_id = p.id) as prenotazioni,
  p.created_at::date       as creata_il
from punteggi p
join scelti s on s.radice = p.radice
order by p.radice, (p.id = s.vincitore) desc;
