-- Il giro orario della pipeline: pg_cron chiama ogni ora, al minuto 7, la
-- funzione foresta-aggiorna, che fa partire il workflow "Genera" su GitHub. Il
-- cron di GitHub Actions da solo salta ore intere.
--
-- Da lanciare una volta nel SQL editor del progetto Supabase di Projects.
-- Rilanciarlo è innocuo: cron.schedule con lo stesso nome sostituisce il giro.
-- Per toglierlo: select cron.unschedule('foresta-aggiorna');
-- Gli ultimi giri: select * from cron.job_run_details order by start_time desc limit 10;
--                  select * from net._http_response order by created desc limit 10;

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'foresta-aggiorna',
  '7 * * * *',
  $$
  select net.http_post(
    url := 'https://fvsohjlrulwabvfvcfxo.supabase.co/functions/v1/foresta-aggiorna?orario',
    timeout_milliseconds := 15000
  )
  $$
);
