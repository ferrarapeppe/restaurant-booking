-- Contenitore per il logo del ristorante.
--
-- Da eseguire una volta sola nell'editor SQL di Supabase.
-- Serve perche' la riga di comando non sa creare i contenitori: sa solo
-- copiarci dentro dei file.
--
-- Il contenitore e' pubblico in lettura perche' il logo deve potersi vedere
-- anche da fuori — nelle email e nel modulo di prenotazione, dove chi guarda
-- non ha fatto nessun accesso. In scrittura invece entra solo lo staff.

insert into storage.buckets (id, name, public)
values ('loghi', 'loghi', true)
on conflict (id) do nothing;

-- Le regole si ricreano da capo, cosi' rieseguire il file non da' errore.
drop policy if exists "loghi leggibili da tutti" on storage.objects;
drop policy if exists "loghi caricabili dallo staff" on storage.objects;
drop policy if exists "loghi sostituibili dallo staff" on storage.objects;
drop policy if exists "loghi cancellabili dallo staff" on storage.objects;

create policy "loghi leggibili da tutti"
  on storage.objects for select
  using (bucket_id = 'loghi');

create policy "loghi caricabili dallo staff"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'loghi');

create policy "loghi sostituibili dallo staff"
  on storage.objects for update to authenticated
  using (bucket_id = 'loghi')
  with check (bucket_id = 'loghi');

create policy "loghi cancellabili dallo staff"
  on storage.objects for delete to authenticated
  using (bucket_id = 'loghi');

-- Verifica: deve comparire una riga con public = true
select id, name, public from storage.buckets where id = 'loghi';
