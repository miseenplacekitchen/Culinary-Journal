-- fix-recipe-discovery-rpcs.sql — Browse by occasion (festivals) or wellness (Nourish & Heal hub).
-- Run once in Supabase SQL Editor. Safe to re-run.

DROP FUNCTION IF EXISTS public.get_recipes_by_occasion(text, text, int, int);
CREATE OR REPLACE FUNCTION public.get_recipes_by_occasion(
  p_occasion       text DEFAULT NULL,
  p_festival_slug  text DEFAULT NULL,
  p_limit          int  DEFAULT 24,
  p_offset         int  DEFAULT 0
)
RETURNS TABLE (
  id             uuid,
  recipe_name    text,
  category       text,
  image_url      text,
  origin_country text,
  dietary_tags   text[],
  occasion_tags  text[]
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_occasion IS NULL AND p_festival_slug IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT sr.id, sr.recipe_name, sr.category, sr.image_url, sr.origin_country,
           sr.dietary_tags, sr.occasion_tags
    FROM public.submitted_recipes sr
    WHERE sr.status = 'approved'
      AND sr.visibility = 'Public'
      AND (
        (p_occasion IS NOT NULL AND p_occasion = ANY(COALESCE(sr.occasion_tags, '{}')))
        OR (
          p_festival_slug IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM public.festival_dish_recipes fdr
            JOIN public.festival_dishes fd ON fd.id = fdr.dish_id
            JOIN public.festivals f ON f.id = fd.festival_id
            WHERE fdr.recipe_id = sr.id
              AND f.slug = p_festival_slug
              AND f.is_active = true
          )
        )
      )
    ORDER BY sr.submitted_at DESC
    LIMIT GREATEST(p_limit, 1)
    OFFSET GREATEST(p_offset, 0);
END;
$$;
REVOKE ALL ON FUNCTION public.get_recipes_by_occasion(text, text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipes_by_occasion(text, text, int, int) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_recipes_by_wellness(text, int, int);
CREATE OR REPLACE FUNCTION public.get_recipes_by_wellness(
  p_tag    text DEFAULT NULL,
  p_limit  int  DEFAULT 24,
  p_offset int  DEFAULT 0
)
RETURNS TABLE (
  id             uuid,
  recipe_name    text,
  category       text,
  image_url      text,
  origin_country text,
  dietary_tags   text[],
  health_tags    text[]
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT sr.id, sr.recipe_name, sr.category, sr.image_url, sr.origin_country,
           sr.dietary_tags, sr.health_tags
    FROM public.submitted_recipes sr
    WHERE sr.status = 'approved'
      AND sr.visibility = 'Public'
      AND (
        p_tag IS NULL
        OR p_tag = ANY(COALESCE(sr.health_tags, '{}'))
        OR p_tag = ANY(COALESCE(sr.dietary_tags, '{}'))
      )
      AND (
        p_tag IS NOT NULL
        OR cardinality(COALESCE(sr.health_tags, '{}')) > 0
        OR COALESCE(sr.dietary_tags, '{}') && ARRAY[
          'Vegan', 'Vegetarian', 'Gluten Free', 'Dairy Free', 'Nut Free',
          'Egg Free', 'Shellfish Free', 'Halal', 'Kosher'
        ]::text[]
      )
    ORDER BY sr.submitted_at DESC
    LIMIT GREATEST(p_limit, 1)
    OFFSET GREATEST(p_offset, 0);
END;
$$;
REVOKE ALL ON FUNCTION public.get_recipes_by_wellness(text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipes_by_wellness(text, int, int) TO anon, authenticated;

SELECT 'fix-recipe-discovery-rpcs applied' AS status;
