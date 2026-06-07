-- ══════════════════════════════════════════════════════════════════════
-- schedule-rotw-expiry-cron.sql — Clear expired Recipe of the Week daily
-- Prerequisites: fix-phase34-batch.sql ran
-- Schedule: 00:15 UTC daily
-- ══════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.unschedule('expire-recipe-of-week')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire-recipe-of-week');

SELECT cron.schedule(
  'expire-recipe-of-week',
  '15 0 * * *',
  $$SELECT public.expire_recipe_of_week();$$
);

-- Verify:
-- SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'expire-recipe-of-week';
