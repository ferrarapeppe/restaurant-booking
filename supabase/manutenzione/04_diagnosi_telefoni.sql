-- Diagnosi dei recapiti malformati. Legge soltanto.
--
-- Serve prima di esportare la rubrica: WhatsApp riconosce un contatto solo se
-- il numero e' in formato internazionale e pulito. Un campo con due numeri
-- separati da virgola, o con il prefisso +39 scritto due volte, produce un
-- contatto muto: c'e', sembra a posto, ma non ci puoi scrivere.

with base as (
  select id,
         coalesce(nullif(trim(name), ''),
                  trim(coalesce(first_name, '') || ' ' || coalesce(surname, ''))) as nome,
         email,
         phone,
         regexp_replace(coalesce(phone, ''), '\D', '', 'g') as cifre
  from public.guests
)
select
  case
    when phone like '%,%'                          then '1. due numeri in un campo'
    when length(cifre) >= 14 and left(cifre, 4) = '3939' then '2. prefisso +39 doppio'
    when coalesce(trim(phone), '') <> '' and trim(phone) not like '+%' then '3. manca il prefisso'
    when email like '%,%'                          then '4. due email in un campo'
    else '5. altro'
  end as problema,
  nome,
  coalesce(phone, '—') as telefono,
  coalesce(email, '—') as email,
  length(cifre) as cifre_totali
from base
where phone like '%,%'
   or email like '%,%'
   or (length(cifre) >= 14 and left(cifre, 4) = '3939')
   or (coalesce(trim(phone), '') <> '' and trim(phone) not like '+%')
   or (length(cifre) between 1 and 9)
order by problema, nome;
