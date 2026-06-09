-- Admin can replace recipe image during review (dashboard-recipes.js)
-- Safe to re-run — drops all admin_edit_recipe overloads then recreates.

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'admin_edit_recipe'
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_edit_recipe(
  p_id uuid, p_recipe_name text DEFAULT NULL, p_category text DEFAULT NULL,
  p_spice_level text DEFAULT NULL, p_native_title text DEFAULT NULL,
  p_introduction text DEFAULT NULL, p_cooking_notes text DEFAULT NULL,
  p_servings int DEFAULT NULL,
  p_origin_locality text DEFAULT NULL, p_origin_state text DEFAULT NULL,
  p_origin_country text DEFAULT NULL,
  p_image_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name      = COALESCE(NULLIF(btrim(p_recipe_name), ''), recipe_name),
    category         = COALESCE(NULLIF(btrim(p_category), ''), category),
    spice_level      = COALESCE(NULLIF(btrim(p_spice_level), ''), spice_level),
    native_title     = COALESCE(NULLIF(btrim(p_native_title), ''), native_title),
    introduction     = COALESCE(p_introduction, introduction),
    cooking_notes    = COALESCE(p_cooking_notes, cooking_notes),
    servings         = COALESCE(p_servings, servings),
    origin_locality  = COALESCE(NULLIF(btrim(p_origin_locality), ''), origin_locality),
    origin_state     = COALESCE(NULLIF(btrim(p_origin_state), ''), origin_state),
    origin_country   = COALESCE(NULLIF(btrim(p_origin_country), ''), origin_country),
    image_url        = CASE
                         WHEN p_image_url IS NOT NULL AND btrim(p_image_url) <> '' THEN btrim(p_image_url)
                         ELSE image_url
                       END
  WHERE id = p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_edit_recipe(
  uuid,text,text,text,text,text,text,int,text,text,text,text
) TO authenticated;

SELECT 'admin_edit_recipe now accepts p_image_url' AS status;
