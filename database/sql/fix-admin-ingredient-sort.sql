-- Run once in Supabase SQL Editor if ingredient column sorting does not work.
-- Safe to re-run. Replaces admin_get_ingredients with sort-aware version.

DROP FUNCTION IF EXISTS public.admin_get_ingredients(text, text, int, int, text, text);
CREATE OR REPLACE FUNCTION public.admin_get_ingredients(
  p_search text DEFAULT NULL, p_category text DEFAULT NULL,
  p_limit int DEFAULT 50, p_offset int DEFAULT 0,
  p_sort_col text DEFAULT 'Ingredient Name', p_sort_dir text DEFAULT 'asc'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rows jsonb;
  v_col  text;
  v_dir  text;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  v_col := CASE WHEN p_sort_col IN (
      'ID','Ingredient Name','Also Known As','Category','Sub Category',
      'Standard Qty','Standard Weight (g or ml)','Unit','Liquid (Yes/No)',
      'CJ Recommended Brand','Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes')
    THEN p_sort_col ELSE 'Ingredient Name' END;
  v_dir := CASE WHEN lower(p_sort_dir) = 'desc' THEN 'DESC' ELSE 'ASC' END;
  IF v_col = 'ID' THEN
    EXECUTE format(
      'SELECT jsonb_agg(to_jsonb(i)) FROM (
         SELECT * FROM ingredients
         WHERE ($1 IS NULL OR "Ingredient Name" ILIKE ''%%''||$1||''%%'')
           AND ($2 IS NULL OR "Category" = $2)
         ORDER BY "ID" %s
         LIMIT $3 OFFSET $4
       ) i', v_dir)
    INTO v_rows USING p_search, p_category, p_limit, p_offset;
  ELSIF v_col = 'Standard Weight (g or ml)' THEN
    EXECUTE format(
      'SELECT jsonb_agg(to_jsonb(i)) FROM (
         SELECT * FROM ingredients
         WHERE ($1 IS NULL OR "Ingredient Name" ILIKE ''%%''||$1||''%%'')
           AND ($2 IS NULL OR "Category" = $2)
         ORDER BY NULLIF(regexp_replace("Standard Weight (g or ml)", ''[^0-9.\-]'', '''', ''g''), '''')::numeric %s NULLS LAST
         LIMIT $3 OFFSET $4
       ) i', v_dir)
    INTO v_rows USING p_search, p_category, p_limit, p_offset;
  ELSE
    EXECUTE format(
      'SELECT jsonb_agg(to_jsonb(i)) FROM (
         SELECT * FROM ingredients
         WHERE ($1 IS NULL OR "Ingredient Name" ILIKE ''%%''||$1||''%%'')
           AND ($2 IS NULL OR "Category" = $2)
         ORDER BY %I %s NULLS LAST
         LIMIT $3 OFFSET $4
       ) i', v_col, v_dir)
    INTO v_rows USING p_search, p_category, p_limit, p_offset;
  END IF;
  RETURN COALESCE(v_rows, '[]'::jsonb);
END; $$;

GRANT EXECUTE ON FUNCTION public.admin_get_ingredients(text, text, int, int, text, text) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
