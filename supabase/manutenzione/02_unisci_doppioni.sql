-- Unione delle schede cliente doppie.
--
-- Due schede sono la stessa persona se hanno la stessa email (normalizzata)
-- oppure lo stesso telefono (normalizzato). Sopravvive la scheda piu'
-- completa; a parita' di dati, quella gia' in uso; poi la piu' vecchia.
--
-- TRE COPPIE SONO ESCLUSE A MANO perche' combaciano per un solo dato ma
-- sembrano persone diverse, verificate una per una:
--   +39 320 159 7867            -> Laura ed Emanuele
--   091 772 7259                -> Roberta e Giovanna Verdi, fisso di famiglia
--   florianamazzone@gmail.com   -> Beatrice e Floriana, nomi e telefoni diversi
--
-- Nulla va perduto: le schede cancellate finiscono per intero in
-- `public.guests_uniti`, da cui si possono rileggere o ripristinare.
--
-- Tutto dentro un solo blocco: l'editor SQL di Supabase esegue le istruzioni
-- separatamente, quindi piu' istruzioni non sarebbero ne' atomiche ne' capaci
-- di condividere tabelle temporanee.

do $$
declare
  n_gruppi   int;
  n_cancella int;
begin
  -- ── Archivio di sicurezza ──────────────────────────────────────────────────
  create table if not exists public.guests_uniti (
    id            uuid primary key,
    sopravvissuto uuid        not null,
    scheda        jsonb       not null,
    unito_il      timestamptz not null default now()
  );
  alter table public.guests_uniti enable row level security;

  -- ── Chi sta con chi ────────────────────────────────────────────────────────
  create temp table _comp on commit drop as
  with recursive
  base as (
    select id,
           nullif(lower(trim(email)), '') as email_n,
           nullif(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), '') as tg
    from public.guests
  ),
  n as (
    select id, email_n,
      case when length(tg) > 10 and left(tg, 4) = '0039' then substr(tg, 5)
           when length(tg) > 10 and left(tg, 2) = '39'   then substr(tg, 3)
           else tg end as tel_n
    from base
  ),
  archi as (
    select a.id as x, b.id as y from n a join n b
      on a.email_n = b.email_n and a.email_n is not null and a.id <> b.id
     -- L'email condivisa da due persone diverse non fa testo.
     and a.email_n <> 'florianamazzone@gmail.com'
    union
    select a.id, b.id from n a join n b
      on a.tel_n = b.tel_n and a.tel_n is not null and a.id <> b.id
     -- Idem per i due numeri condivisi.
     and a.tel_n not in ('3201597867', '0917727259')
  ),
  raggiunge (origine, nodo) as (
    select id, id from n
    union
    select r.origine, a.y from raggiunge r join archi a on a.x = r.nodo
  )
  select origine as id, min(nodo::text)::uuid as radice
  from raggiunge group by origine;

  create temp table _gruppi on commit drop as
  select radice from _comp group by radice having count(*) > 1;

  -- ── Chi sopravvive ─────────────────────────────────────────────────────────
  create temp table _scelti on commit drop as
  select c.radice,
    (array_agg(g.id order by
        ( (case when nullif(trim(g.email), '')      is not null then 1 else 0 end)
        + (case when nullif(trim(g.phone), '')      is not null then 1 else 0 end)
        + (case when nullif(trim(g.first_name), '') is not null then 1 else 0 end)
        + (case when nullif(trim(g.surname), '')    is not null then 1 else 0 end)
        + (case when nullif(trim(g.name), '')       is not null then 1 else 0 end)
        ) desc,
        -- A parita' di dati vince la scheda gia' in uso: si sposta meno roba.
        coalesce(g.visits_count, 0) desc,
        g.created_at asc, g.id::text))[1] as vincitore
  from _comp c
  join _gruppi gr on gr.radice = c.radice
  join public.guests g on g.id = c.id
  group by c.radice;

  create temp table _perdenti on commit drop as
  select c.id, s.vincitore
  from _comp c join _scelti s on s.radice = c.radice
  where c.id <> s.vincitore;

  select count(*) into n_gruppi   from _gruppi;
  select count(*) into n_cancella from _perdenti;

  -- ── Copia di sicurezza prima di toccare qualsiasi cosa ─────────────────────
  insert into public.guests_uniti (id, sopravvissuto, scheda)
  select p.id, p.vincitore, to_jsonb(g)
  from _perdenti p join public.guests g on g.id = p.id
  on conflict (id) do nothing;

  -- ── I dati migliori confluiscono nella scheda che resta ────────────────────
  -- Per ogni campo si tiene il primo valore non vuoto, preferendo quello della
  -- scheda che sopravvive; del nome si tiene la forma piu' estesa, cosi'
  -- "Emanuela Chiovaro" batte "Emanuela". Visite sommate, tag uniti.
  with dati as (
    select s.vincitore,
      (array_agg(nullif(trim(g.email), '')
         order by (nullif(trim(g.email), '') is null), (g.id <> s.vincitore), g.created_at))[1] as email,
      (array_agg(nullif(trim(g.phone), '')
         order by (nullif(trim(g.phone), '') is null), (g.id <> s.vincitore), g.created_at))[1] as phone,
      (array_agg(nullif(trim(g.first_name), '')
         order by (nullif(trim(g.first_name), '') is null), (g.id <> s.vincitore), g.created_at))[1] as first_name,
      (array_agg(nullif(trim(g.surname), '')
         order by (nullif(trim(g.surname), '') is null), (g.id <> s.vincitore), g.created_at))[1] as surname,
      (array_agg(nullif(trim(g.name), '')
         order by length(coalesce(trim(g.name), '')) desc, g.created_at))[1] as name,
      (array_agg(nullif(trim(g.notes), '')
         order by (nullif(trim(g.notes), '') is null), (g.id <> s.vincitore), g.created_at))[1] as notes,
      sum(coalesce(g.visits_count, 0)) as visite
    from _scelti s
    join _comp c on c.radice = s.radice
    join public.guests g on g.id = c.id
    group by s.vincitore
  ),
  tag_uniti as (
    select s.vincitore, array_agg(distinct t) as tags
    from _scelti s
    join _comp c on c.radice = s.radice
    join public.guests g on g.id = c.id
    cross join lateral unnest(coalesce(g.tags, array[]::text[])) as t
    group by s.vincitore
  )
  update public.guests g
  set email        = d.email,
      phone        = d.phone,
      first_name   = d.first_name,
      surname      = d.surname,
      name         = d.name,
      notes        = d.notes,
      visits_count = d.visite,
      tags         = coalesce(t.tags, g.tags)
  from dati d
  left join tag_uniti t on t.vincitore = d.vincitore
  where g.id = d.vincitore;

  -- ── Le prenotazioni seguono la scheda che resta ────────────────────────────
  update public.bookings b
  set guest_id = p.vincitore
  from _perdenti p
  where b.guest_id = p.id;

  update public.waitlist w
  set guest_id = p.vincitore
  from _perdenti p
  where w.guest_id = p.id;

  -- ── Via le schede doppie ───────────────────────────────────────────────────
  delete from public.guests g using _perdenti p where g.id = p.id;

  raise notice 'gruppi uniti: %, schede cancellate: %', n_gruppi, n_cancella;
end $$;
