-- Run once in Supabase SQL Editor to fix Recipe Management panel errors.
-- Safe to re-run. Fixes PGRST202 "Could not find admin_get_recipes" errors.

DROP FUNCTION IF EXISTS public.admin_get_recipes(text, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.admin_get_recipes(
  p_status   text DEFAULT NULL,
  p_search   text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_limit    integer DEFAULT 50,
  p_offset   integer DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
    SELECT json_build_object(
      'id',                    r.id,
      'recipe_name',           r.recipe_name,
      'native_title',          r.native_title,
      'category',              r.category,
      'spice_level',           r.spice_level,
      'origin_continent',      r.origin_continent,
      'origin_country',        r.origin_country,
      'origin_state',          r.origin_state,
      'status',                r.status,
      'submitted_at',          r.submitted_at,
      'reviewed_at',           r.reviewed_at,
      'reviewer_notes',        r.reviewer_notes,
      'introduction',          r.introduction,
      'cooking_notes',         r.cooking_notes,
      'servings',              r.servings,
      'image_url',             r.image_url,
      'username',              p.username,
      'full_name',             p.full_name,
      'featured',              COALESCE(r.is_featured, false),
      'is_featured',           COALESCE(r.is_featured, false),
      'recipe_of_week',        COALESCE(r.is_recipe_of_week, false),
      'is_recipe_of_week',     COALESCE(r.is_recipe_of_week, false),
      'recipe_of_week_at',     r.recipe_of_week_at,
      'recipe_of_week_expires', r.recipe_of_week_expires
    )
    FROM public.submitted_recipes r
    LEFT JOIN public.profiles p ON p.id = r.user_id
    WHERE (p_status IS NULL OR r.status = p_status)
      AND (p_search IS NULL OR r.recipe_name ILIKE '%' || p_search || '%'
           OR COALESCE(p.username, '') ILIKE '%' || p_search || '%')
      AND (p_category IS NULL OR r.category = p_category)
    ORDER BY r.submitted_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_recipes(text, text, text, integer, integer) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
