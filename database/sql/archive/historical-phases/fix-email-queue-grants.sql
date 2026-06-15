-- ══════════════════════════════════════════════════════════════════════
-- fix-email-queue-grants.sql — Let send-queued-emails edge function read/update queue.
-- Safe to re-run. Run in Supabase SQL editor before or after edge deploy.
-- Fixes: permission denied for table email_queue (42501)
-- ══════════════════════════════════════════════════════════════════════

GRANT USAGE ON SCHEMA public TO service_role;

GRANT SELECT, UPDATE ON public.email_queue TO service_role;
GRANT SELECT ON public.email_templates TO service_role;

SELECT 'fix-email-queue-grants.sql complete' AS status;
