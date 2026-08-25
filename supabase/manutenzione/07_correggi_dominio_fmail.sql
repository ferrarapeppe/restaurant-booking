-- Ultimo indirizzo con il dominio sbagliato: fmail.com non esiste, e' gmail.com.
-- Confermato dal proprietario. Il valore originale resta in guests_correzioni.

do $$
declare
  n int;
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

  with da_correggere as (
    select id, email as prima, replace(email, '@fmail.com', '@gmail.com') as dopo
    from public.guests
    where email like '%@fmail.com'
  ),
  archiviate as (
    insert into public.guests_correzioni (id, campo, prima, dopo)
    select id, 'email', prima, dopo from da_correggere
    returning 1
  )
  update public.guests g set email = d.dopo
  from da_correggere d where g.id = d.id;
  get diagnostics n = row_count;

  raise notice 'domini fmail.com corretti: %', n;
end $$;
