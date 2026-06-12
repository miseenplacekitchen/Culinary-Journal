-- fix-phase41-browse-pagination.sql
-- Server-side contributor filter + paginated public browse/search.
-- Safe to re-run.

DROP FUNCTION IF EXISTS public.get_approved_recipes(text, text, text, text, text, text, int, int);

CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category     text DEFAULT NULL,
  p_spice        text DEFAULT NULL,
  p_dietary      text DEFAULT NULL,
  p_search       text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL,
  p_username     text DEFAULT NULL,
  p_credit_name  text DEFAULT NULL,
  p_limit        int  DEFAULT 48,
  p_offset       int  DEFAULT 0
)
RETURNS TABLE (
  id                  uuid,
  recipe_name         text,
  native_title        text,
  also_known_as       text,
  category            text,
  sub_category        text,
  division            text,
  spice_level         text,
  dietary_tags        text[],
  origin_country      text,
  image_url           text,
  credit_name         text,
  credit_handle       text,
  submitted_at        timestamptz,
  username            text,
  prep_time_minutes   int,
  cook_time_minutes   int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 48), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.native_title, sr.also_known_as, sr.category,
         sr.sub_category, sr.division,
         sr.spice_level, sr.dietary_tags, sr.origin_country,
         sr.image_url, sr.credit_name, sr.credit_handle,
         sr.submitted_at, p.username,
         COALESCE(sr.prep_time_minutes, 0)::int,
         COALESCE(sr.cook_time_minutes, 0)::int
    FROM public.submitted_recipes sr
    LEFT JOIN public.profiles p ON p.id = sr.user_id
   WHERE sr.status = 'approved'
     AND (
       sr.visibility = 'Public'
       OR (
         sr.visibility = 'Friends'
         AND auth.uid() IS NOT NULL
         AND EXISTS (
           SELECT 1 FROM public.contributor_follows cf
            WHERE cf.follower_id = auth.uid() AND cf.following_id = sr.user_id
         )
       )
     )
     AND (p_category     IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
     AND (p_spice        IS NULL OR btrim(p_spice) = '' OR sr.spice_level = p_spice)
     AND (p_dietary      IS NULL OR btrim(p_dietary) = '' OR p_dietary = ANY(sr.dietary_tags))
     AND (
       p_search IS NULL OR btrim(p_search) = ''
       OR sr.recipe_name ILIKE '%' || btrim(p_search) || '%'
       OR sr.native_title ILIKE '%' || btrim(p_search) || '%'
       OR sr.also_known_as ILIKE '%' || btrim(p_search) || '%'
       OR sr.category ILIKE '%' || btrim(p_search) || '%'
       OR sr.origin_country ILIKE '%' || btrim(p_search) || '%'
     )
     AND (p_sub_category IS NULL OR btrim(p_sub_category) = '' OR sr.sub_category = p_sub_category)
     AND (p_division     IS NULL OR btrim(p_division) = '' OR sr.division = p_division)
     AND (
       p_username IS NULL OR btrim(p_username) = ''
       OR lower(p.username) = lower(btrim(p_username))
     )
     AND (
       p_credit_name IS NULL OR btrim(p_credit_name) = ''
       OR lower(btrim(sr.credit_name)) = lower(btrim(p_credit_name))
     )
   ORDER BY
     CASE WHEN p_search IS NOT NULL AND btrim(p_search) <> '' THEN
       CASE WHEN lower(sr.recipe_name) = lower(btrim(p_search)) THEN 0
            WHEN sr.recipe_name ILIKE btrim(p_search) || '%' THEN 1
            ELSE 2 END
     ELSE 2 END,
     sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,text,text,text,text,int,int) TO anon, authenticated;

-- Ingredient search pagination
DROP FUNCTION IF EXISTS public.search_ingredients(text, int);

CREATE OR REPLACE FUNCTION public.search_ingredients(
  p_query  text DEFAULT '',
  p_limit  int  DEFAULT 20,
  p_offset int  DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN COALESCE(
    (SELECT jsonb_agg(r)
     FROM (
       SELECT
         "ID"              AS id,
         "Ingredient Name" AS ingredient_name,
         "Also Known As"   AS also_known_as,
         "Category"        AS category,
         "Allergen"        AS allergen,
         "Vegan (Yes/No)"  AS vegan
       FROM ingredients
       WHERE p_query = '' OR btrim(p_query) = ''
          OR "Ingredient Name" ILIKE '%' || btrim(p_query) || '%'
          OR "Also Known As"   ILIKE '%' || btrim(p_query) || '%'
       ORDER BY "Ingredient Name" ASC
       LIMIT p_limit OFFSET p_offset
     ) r),
    '[]'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.search_ingredients(text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_ingredients(text, int, int) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase41-browse-pagination ready' AS status;
