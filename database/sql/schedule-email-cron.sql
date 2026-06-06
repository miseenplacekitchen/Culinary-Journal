-- ══════════════════════════════════════════════════════════════════════
-- schedule-email-cron.sql — Betty ops only (run once edge function is deployed)
--
-- Prerequisites:
--   1. supabase functions deploy send-queued-emails
--   2. supabase secrets set RESEND_API_KEY=re_...
--   3. supabase secrets set CRON_SECRET=<random-secret>
--   4. Replace YOUR_CRON_SECRET below with that same CRON_SECRET value
--
-- If STEP 1 fails with a permission error, enable extensions in the dashboard:
--   Supabase → Database → Extensions → enable pg_cron AND pg_net
-- Then re-run this entire script.
-- ══════════════════════════════════════════════════════════════════════

-- STEP 1 — Extensions (creates the cron schema)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    RAISE EXCEPTION 'pg_cron still not available. Enable pg_cron and pg_net under Database → Extensions, then re-run this script.';
  END IF;
END $$;

-- STEP 2 — Remove previous job if present (safe on first run)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-queued-emails') THEN
    PERFORM cron.unschedule('send-queued-emails');
  END IF;
END $$;

-- STEP 3 — Schedule every 5 minutes
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
