-- ══════════════════════════════════════════════════════════════════════
-- fix-phase8-batch.sql — Bulk taxonomy backfill RPCs for approved recipes.
-- Safe to re-run. Run after fix-phase7-batch.sql.
-- Email cron: run database/sql/schedule-email-cron.sql separately (Betty ops).
-- ══════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.admin_list_recipes_missing_taxonomy(int);
DROP FUNCTION IF EXISTS public.admin_bulk_set_recipe_taxonomy(uuid[], text, text);

CREATE OR REPLACE FUNCTION public.admin_list_recipes_missing_taxonomy(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id           uuid,
  recipe_name  text,
  category     text,
  sub_category text,
  division     text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.category, sr.sub_category, sr.division
    FROM public.submitted_recipes sr
   WHERE sr.status = 'approved'
     AND (
       sr.sub_category IS NULL OR btrim(sr.sub_category) = ''
       OR sr.division IS NULL OR btrim(sr.division) = ''
     )
   ORDER BY sr.submitted_at DESC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_list_recipes_missing_taxonomy(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_bulk_set_recipe_taxonomy(
  p_recipe_ids   uuid[],
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_recipe_ids IS NULL OR array_length(p_recipe_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;
  IF (p_sub_category IS NULL OR btrim(p_sub_category) = '')
     AND (p_division IS NULL OR btrim(p_division) = '') THEN
    RAISE EXCEPTION 'Provide at least sub_category or division';
  END IF;

  UPDATE public.submitted_recipes sr
     SET sub_category = CASE
           WHEN p_sub_category IS NOT NULL AND btrim(p_sub_category) <> '' THEN btrim(p_sub_category)
           ELSE sr.sub_category
         END,
         division = CASE
           WHEN p_division IS NOT NULL AND btrim(p_division) <> '' THEN btrim(p_division)
           ELSE sr.division
         END
   WHERE sr.id = ANY(p_recipe_ids)
     AND sr.status = 'approved';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_bulk_set_recipe_taxonomy(uuid[], text, text) TO authenticated;
