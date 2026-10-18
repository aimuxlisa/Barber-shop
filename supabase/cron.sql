-- Runs only after pg_cron, pg_net and vault are enabled.
-- The cron secret is the vault secret named cron_secret.

do $$
declare
  job_id bigint;
begin
  if to_regnamespace('cron') is null or to_regnamespace('net') is null or to_regnamespace('vault') is null then
    raise notice 'pg_cron, pg_net or vault is not installed';
    return;
  end if;

  select jobid into job_id from cron.job where jobname = 'orda-notifications';
  if job_id is not null then
    perform cron.unschedule(job_id);
  end if;

  perform cron.schedule(
    'orda-notifications',
    '*/5 * * * *',
    $job$
    select net.http_post(
      url := 'https://barber-shop-wwwaiwork-7531.vercel.app/internal/notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret' limit 1)
      ),
      body := '{}'::jsonb
    );
    $job$
  );
end $$;
