-- ══════════════════════════════════════════════════════════════════════
-- schedule-dead-link-cron.sql — Weekly dead-link sweep (Betty ops)
-- Prerequisites:
--   1. fix-phase9-batch.sql ran
--   2. Deploy edge function: check-dead-links (dashboard or CLI)
--   3. CRON_SECRET already set for send-queued-emails — reuse same value
--   4. Replace YOUR_CRON_SECRET below
--   5. JWT verification OFF on check-dead-links (same as send-queued-emails)
-- Schedule: 03:00 UTC every Sunday
-- ══════════════════════════════════════════════════════════════════════

SELECT cron.unschedule('check-dead-links')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-dead-links');

SELECT cron.schedule(
  'check-dead-links',
  '0 3 * * 0',
  $$
    SELECT net.http_post(
      url     := 'https://kzywmodvfbyexqgipcjt.supabase.co/functions/v1/check-dead-links',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer YOUR_CRON_SECRET'
      ),
      body    := '{}'::jsonb
    )
  $$
);

-- Verify:
-- SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'check-dead-links';
