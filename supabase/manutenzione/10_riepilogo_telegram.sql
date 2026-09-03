-- Il riepilogo della giornata su Telegram, ogni mattina.
--
-- Gli altri tre avvisi (prenotazione, annullamento, messaggio) partono da
-- soli quando succede qualcosa. Questo no: non succede niente, è l'ora che
-- arriva. Serve quindi qualcuno che chiami la funzione, e quel qualcuno è
-- `pg_cron` dentro Supabase.
--
-- PRIMA DI ESEGUIRE, sostituisci il gettone qui sotto con lo stesso valore
-- che hai messo fra i segreti della funzione come TELEGRAM_CRON_TOKEN.
-- Serve perché la chiamata non ha una persona dietro: il gettone è l'unica
-- cosa che distingue il programmatore da un estraneo che conosce l'indirizzo.

-- 1. Le due estensioni. Su Supabase ci sono già, questo le accende e basta.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- 2. Il lavoro programmato.
--
-- L'orario è in UTC, non in ora italiana: `30 8 * * *` sono le 10:30 d'estate
-- e le 9:30 d'inverno. Se lo vuoi fisso alle 10:30 tutto l'anno, va spostato
-- a `30 9 * * *` quando torna l'ora solare, l'ultima domenica di ottobre.
select cron.unschedule('riepilogo-telegram')
where exists (select 1 from cron.job where jobname = 'riepilogo-telegram');

select cron.schedule(
  'riepilogo-telegram',
  '30 8 * * *',
  $$
  select net.http_post(
    url := 'https://jxdnldyabhzmfnterzil.supabase.co/functions/v1/telegram',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{"azione": "riepilogo", "gettone": "METTI_QUI_IL_GETTONE"}'::jsonb
  );
  $$
);

-- 3. Verifica: il lavoro c'è ed è programmato.
select jobname, schedule, active from cron.job where jobname = 'riepilogo-telegram';

-- Per fermarlo:            select cron.unschedule('riepilogo-telegram');
-- Per vedere com'è andato: select * from cron.job_run_details
--                          where jobid = (select jobid from cron.job
--                                         where jobname = 'riepilogo-telegram')
--                          order by start_time desc limit 10;
