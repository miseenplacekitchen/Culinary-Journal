-- ══════════════════════════════════════════════════════════════════════
-- fix-phase9-batch.sql — Dead-link cron grants + admin link-status view.
-- Safe to re-run. Run after fix-email-queue-grants.sql.
-- Deploy check-dead-links edge function, then schedule-dead-link-cron.sql.
-- ══════════════════════════════════════════════════════════════════════

GRANT SELECT, UPDATE ON public.submitted_recipes TO service_role;

CREATE OR REPLACE FUNCTION public.admin_get_source_link_status(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id                    uuid,
  recipe_name           text,
  credit_url            text,
  source_link_status    text,
  source_link_checked_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.credit_url,
         sr.source_link_status, sr.source_link_checked_at
    FROM public.submitted_recipes sr
   WHERE sr.status = 'approved'
     AND sr.credit_url IS NOT NULL
     AND btrim(sr.credit_url) <> ''
   ORDER BY sr.source_link_checked_at NULLS FIRST, sr.submitted_at DESC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_source_link_status(int) TO authenticated;

SELECT 'fix-phase9-batch.sql complete' AS status;
