-- Correzione dei recapiti malformati, in vista dell'esportazione in rubrica.
--
-- WhatsApp riconosce un contatto solo se il numero e' in formato
-- internazionale e pulito. Un campo con due numeri separati da virgola, o col
-- prefisso +39 scritto due volte, produce un contatto muto: c'e', sembra a
-- posto, ma non ci puoi scrivere.
--
-- I valori originali finiscono in `public.guests_correzioni` prima di essere
-- toccati, cosi' ogni modifica e' reversibile.
--
-- NON tocca le quattro schede di prova (Giovanna Lunga, Giovanna Rossi,
-- Roberta Verdi, Giovanna Verdi): vanno decise a parte, insieme alle loro
-- eventuali prenotazioni.

do $$
declare
  n_doppio   int;
  n_scelti   int;
  n_email    int;
begin
  create table if not exists public.guests_correzioni (
    id           uuid        not null,
    campo        text        not null,
    prima        text,
    dopo         text,
    corretto_il  timestamptz not null default now(),
    primary key (id, campo, corretto_il)
  );
  alter table public.guests_correzioni enable row level security;

  -- ── 1. Prefisso +39 scritto due volte ──────────────────────────────────────
  -- 14 cifre che iniziano per 3939: si toglie il primo 39 e restano le 12
  -- corrette. Regola meccanica, vale per tutti allo stesso modo.
  with da_correggere as (
    select id, phone as prima,
           '+' || substr(regexp_replace(phone, '\D', '', 'g'), 3) as dopo
    from public.guests
    where phone is not null
      and phone not like '%,%'
      and length(regexp_replace(phone, '\D', '', 'g')) = 14
      and left(regexp_replace(phone, '\D', '', 'g'), 4) = '3939'
  ),
  archiviate as (
    insert into public.guests_correzioni (id, campo, prima, dopo)
    select id, 'phone', prima, dopo from da_correggere
    returning 1
  )
  update public.guests g set phone = d.dopo
  from da_correggere d where g.id = d.id;
  get diagnostics n_doppio = row_count;

  -- ── 2. Due numeri in un campo ──────────────────────────────────────────────
  -- Quattro casi, ognuno con la sua ragione: si tiene il numero che ha le
  -- dodici cifre giuste, che non e' sempre il primo dei due.
  create temp table _scelte_tel (prima text, dopo text) on commit drop;
  insert into _scelte_tel (prima, dopo) values
    -- il secondo e' il primo senza il prefisso doppio
    ('+39393664848076,+393664848076', '+393664848076'),
    -- il secondo ha una cifra di troppo
    ('+393925978544,+3939259785443',  '+393925978544'),
    -- il secondo ha il prefisso doppio
    ('+393284343198,+39393284343198', '+393284343198'),
    -- il primo ha solo nove cifre, e' monco
    ('+39328604775,+393286047757',    '+393286047757');

  with da_correggere as (
    select g.id, g.phone as prima, s.dopo
    from public.guests g join _scelte_tel s on s.prima = g.phone
  ),
  archiviate as (
    insert into public.guests_correzioni (id, campo, prima, dopo)
    select id, 'phone', prima, dopo from da_correggere
    returning 1
  )
  update public.guests g set phone = d.dopo
  from da_correggere d where g.id = d.id;
  get diagnostics n_scelti = row_count;

  -- ── 3. Due email in un campo, e domini con refusi ──────────────────────────
  create temp table _scelte_mail (prima text, dopo text) on commit drop;
  insert into _scelte_mail (prima, dopo) values
    -- stessa persona, due caselle: si tiene la prima
    ('ettoreorlando01@icloud.com,ettoreorlando01@yahoo.com', 'ettoreorlando01@icloud.com'),
    -- la prima corrisponde al nome della scheda
    ('marella_78@libero.it,mariapappalardo3@gmail.com', 'marella_78@libero.it'),
    -- la prima e' un refuso della seconda: "prestigiscoko" invece di "prestigiacomo"
    ('nicoloprestigiscoko0@gmail.com,nicoloprestigiacomo0@gmail.com', 'nicoloprestigiacomo0@gmail.com'),
    -- il dominio .ti non esiste
    ('priolo.stefania@virgilio.ti', 'priolo.stefania@virgilio.it');

  with da_correggere as (
    select g.id, g.email as prima, s.dopo
    from public.guests g join _scelte_mail s on s.prima = g.email
  ),
  archiviate as (
    insert into public.guests_correzioni (id, campo, prima, dopo)
    select id, 'email', prima, dopo from da_correggere
    returning 1
  )
  update public.guests g set email = d.dopo
  from da_correggere d where g.id = d.id;
  get diagnostics n_email = row_count;

  raise notice 'prefissi doppi: %, numeri scelti: %, email corrette: %',
    n_doppio, n_scelti, n_email;
end $$;
