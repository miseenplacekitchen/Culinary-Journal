-- ══════════════════════════════════════════════════════════════════════
-- schedule-email-cron.sql — Betty ops only (run once edge function is deployed)
-- Prerequisites:
--   1. supabase functions deploy send-queued-emails
--   2. supabase secrets set RESEND_API_KEY=re_...
--   3. supabase secrets set CRON_SECRET=<random-secret>
-- Replace YOUR_CRON_SECRET below with the same CRON_SECRET value.
-- Safe to re-run: unschedule first if job already exists.
-- ══════════════════════════════════════════════════════════════════════

SELECT cron.unschedule('send-queued-emails')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-queued-emails');

SELECT cron.schedule(
  'send-queued-emails',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url     := 'https://kzywmodvfbyexqgipcjt.supabase.co/functions/v1/send-queued-emails',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer YOUR_CRON_SECRET'
      ),
      body    := '{}'::jsonb
    )
  $$
);

-- Verify:
-- SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'send-queued-emails';
