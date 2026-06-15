-- fix-garden-public-rpcs.sql — richer public browse fields (names only in UI; ids stay server-side)
-- Run on live after RUN-GARDEN-V3-POLISH.sql. Safe to re-run.

DROP FUNCTION IF EXISTS public.get_published_plants(text, integer, integer);
CREATE OR REPLACE FUNCTION public.get_published_plants(
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
BEGIN
  p_limit := GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));
  RETURN QUERY
    SELECT json_build_object(
      'slug', p.slug,
      'common_name', p.common_name,
      'botanical_name', p.botanical_name,
      'care_summary', p.care_summary,
      'plant_family', p.plant_family,
      'plant_type', p.plant_type,
      'harvest_season', p.harvest_season,
      'ease_rating', er.name,
      'lifecycle', lc.name,
      'growth_habit', gh.name,
      'high_level_category', ch.name
    )
    FROM public.plants p
    LEFT JOIN public.ease_ratings er ON er.id = p.ease_rating_id
    LEFT JOIN public.lifecycles lc ON lc.id = p.lifecycle_id
    LEFT JOIN public.growth_habits gh ON gh.id = p.growth_habit_id
    LEFT JOIN public.cat_high_level ch ON ch.id = p.high_level_category_id
    WHERE p.is_published = true
      AND (p_search IS NULL OR p_search = ''
           OR p.common_name ILIKE '%' || p_search || '%'
           OR p.botanical_name ILIKE '%' || p_search || '%')
    ORDER BY p.common_name
    LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_published_plants(text, integer, integer) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'fix-garden-public-rpcs ready' AS status;
