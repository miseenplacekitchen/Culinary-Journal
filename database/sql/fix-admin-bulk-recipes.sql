-- fix-admin-bulk-recipes.sql — Phase 2: Bulk Recipe Editor RPCs (TCJ schema).
-- Run once in Supabase after fix-taxonomy-archive-phase1.sql.
-- Safe to re-run.

-- ── Recipe code (RM#) ────────────────────────────────────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS recipe_code text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_submitted_recipes_recipe_code
  ON public.submitted_recipes (recipe_code)
  WHERE recipe_code IS NOT NULL AND btrim(recipe_code) <> '';

CREATE INDEX IF NOT EXISTS idx_submitted_recipes_visibility
  ON public.submitted_recipes (visibility, status);

-- ── Bulk list for editor ─────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipes_bulk(int, int, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_get_recipes_bulk(
  p_limit    int  DEFAULT 50,
  p_offset   int  DEFAULT 0,
  p_search   text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_status   text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total bigint;
  v_rows  json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT count(*) INTO v_total
    FROM public.submitted_recipes sr
   WHERE (p_search IS NULL OR btrim(p_search) = ''
          OR sr.recipe_name ILIKE '%' || p_search || '%'
          OR COALESCE(sr.recipe_code, '') ILIKE '%' || p_search || '%')
     AND (p_category IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
     AND (p_status IS NULL OR btrim(p_status) = '' OR sr.status = p_status);

  SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) INTO v_rows
    FROM (
      SELECT
        sr.id,
        sr.recipe_code,
        sr.recipe_name,
        sr.category,
        sr.sub_category,
        sr.division,
        sr.cooking_style,
        sr.visibility,
        sr.status,
        sr.dietary_tags,
        sr.style_tags,
        sr.health_tags,
        sr.submitted_at
      FROM public.submitted_recipes sr
     WHERE (p_search IS NULL OR btrim(p_search) = ''
            OR sr.recipe_name ILIKE '%' || p_search || '%'
            OR COALESCE(sr.recipe_code, '') ILIKE '%' || p_search || '%')
       AND (p_category IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
       AND (p_status IS NULL OR btrim(p_status) = '' OR sr.status = p_status)
     ORDER BY sr.recipe_name ASC
     LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
     OFFSET greatest(0, coalesce(p_offset, 0))
    ) t;

  RETURN json_build_object('rows', v_rows, 'total', v_total);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_recipes_bulk(int, int, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_recipes_bulk(int, int, text, text, text) TO authenticated;

-- ── Inline field update ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_recipe_field(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_update_recipe_field(
  p_id    uuid,
  p_field text,
  p_value text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  IF p_field = 'recipe_name' THEN
    UPDATE public.submitted_recipes SET recipe_name = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'recipe_code' THEN
    UPDATE public.submitted_recipes SET recipe_code = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'category' THEN
    UPDATE public.submitted_recipes SET category = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'sub_category' THEN
    UPDATE public.submitted_recipes SET sub_category = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'division' THEN
    UPDATE public.submitted_recipes SET division = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'cooking_style' THEN
    UPDATE public.submitted_recipes SET cooking_style = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'visibility' THEN
    UPDATE public.submitted_recipes SET visibility = coalesce(nullif(btrim(p_value), ''), 'Public') WHERE id = p_id;
  ELSIF p_field = 'status' THEN
    IF p_value NOT IN ('pending', 'approved', 'rejected') THEN
      RAISE EXCEPTION 'Invalid status: %', p_value;
    END IF;
    UPDATE public.submitted_recipes SET status = p_value WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'Unknown field: %', p_field;
  END IF;

  IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_update_recipe_field(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_recipe_field(uuid, text, text) TO authenticated;

-- ── Bulk visibility (Public = on site when approved; Private = hidden) ───────
DROP FUNCTION IF EXISTS public.admin_bulk_update_recipe_visibility(uuid[], text);
CREATE OR REPLACE FUNCTION public.admin_bulk_update_recipe_visibility(
  p_recipe_ids uuid[],
  p_visibility text
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_visibility NOT IN ('Public', 'Private', 'Friends', 'Archived') THEN
    RAISE EXCEPTION 'Invalid visibility: %', p_visibility;
  END IF;
  UPDATE public.submitted_recipes
     SET visibility = p_visibility
   WHERE id = ANY(p_recipe_ids);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_bulk_update_recipe_visibility(uuid[], text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_update_recipe_visibility(uuid[], text) TO authenticated;

-- ── Generate RM# codes ───────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_generate_recipe_codes(int);
CREATE OR REPLACE FUNCTION public.admin_generate_recipe_codes(p_batch_size int DEFAULT 500)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  v_total int;
  v_code  text;
  v_rec   record;
  v_prefix text;
  v_seq   int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT count(*) INTO v_total
    FROM public.submitted_recipes
   WHERE recipe_code IS NULL OR btrim(recipe_code) = '';

  v_prefix := 'RM' || to_char(now(), 'YYYYMMDD');

  FOR v_rec IN
    SELECT id FROM public.submitted_recipes
     WHERE recipe_code IS NULL OR btrim(recipe_code) = ''
     ORDER BY submitted_at ASC
     LIMIT greatest(1, least(coalesce(p_batch_size, 500), 2000))
  LOOP
    v_seq := v_count + 1;
    v_code := v_prefix || lpad(v_seq::text, 3, '0');
    UPDATE public.submitted_recipes SET recipe_code = v_code WHERE id = v_rec.id;
    v_count := v_count + 1;
  END LOOP;

  RETURN json_build_object('generated_count', v_count, 'total_missing', v_total);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_generate_recipe_codes(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_generate_recipe_codes(int) TO authenticated;

-- ── Cascade recipe text when taxonomy sub is renamed ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_subcategory(
  p_id uuid,
  p_category text,
  p_name text,
  p_sort_order int DEFAULT NULL,
  p_ingredient_hints text[] DEFAULT NULL,
  p_tagline text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_emoji text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_old_name text;
  v_old_cat  text;
  v_recipes  int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  IF p_id IS NOT NULL THEN
    SELECT name, category INTO v_old_name, v_old_cat
      FROM public.recipe_subcategories WHERE id = p_id;
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.recipe_subcategories (category, name, sort_order, ingredient_hints, tagline, description, emoji)
    VALUES (
      p_category, p_name, coalesce(p_sort_order, 0),
      coalesce(p_ingredient_hints, '{}'),
      nullif(btrim(p_tagline), ''), nullif(btrim(p_description), ''), nullif(btrim(p_emoji), '')
    )
    ON CONFLICT (category, name) DO UPDATE SET
      sort_order = coalesce(EXCLUDED.sort_order, recipe_subcategories.sort_order),
      is_active = true,
      ingredient_hints = CASE WHEN p_ingredient_hints IS NULL THEN recipe_subcategories.ingredient_hints ELSE EXCLUDED.ingredient_hints END,
      tagline = coalesce(nullif(btrim(EXCLUDED.tagline), ''), recipe_subcategories.tagline),
      description = coalesce(nullif(btrim(EXCLUDED.description), ''), recipe_subcategories.description),
      emoji = coalesce(nullif(btrim(EXCLUDED.emoji), ''), recipe_subcategories.emoji)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_subcategories SET
      category = p_category,
      name = p_name,
      sort_order = coalesce(p_sort_order, sort_order),
      ingredient_hints = CASE WHEN p_ingredient_hints IS NULL THEN ingredient_hints ELSE p_ingredient_hints END,
      tagline = CASE WHEN p_tagline IS NULL THEN tagline ELSE nullif(btrim(p_tagline), '') END,
      description = CASE WHEN p_description IS NULL THEN description ELSE nullif(btrim(p_description), '') END,
      emoji = CASE WHEN p_emoji IS NULL THEN emoji ELSE nullif(btrim(p_emoji), '') END
    WHERE id = p_id RETURNING id INTO v_id;

    IF v_old_name IS NOT NULL AND (v_old_name IS DISTINCT FROM p_name OR v_old_cat IS DISTINCT FROM p_category) THEN
      UPDATE public.submitted_recipes SET
        category = CASE WHEN category = v_old_cat THEN p_category ELSE category END,
        sub_category = p_name
      WHERE category = v_old_cat AND sub_category = v_old_name;
      GET DIAGNOSTICS v_recipes = ROW_COUNT;

      UPDATE public.recipe_divisions SET
        category = p_category,
        subcategory = p_name
      WHERE category = v_old_cat AND subcategory = v_old_name;
    END IF;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text) TO authenticated;

-- ── Cascade recipe text when division is renamed ─────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_recipe_division(uuid, text, text, text, text, text, text, text[], int);
CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_division(
  p_id uuid, p_category text, p_subcategory text, p_name text,
  p_emoji text DEFAULT '🍽', p_subtitle text DEFAULT NULL,
  p_description text DEFAULT NULL, p_tags text[] DEFAULT '{}',
  p_sort_order int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_old_name text;
  v_old_cat  text;
  v_old_sub  text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  IF p_id IS NOT NULL THEN
    SELECT name, category, subcategory INTO v_old_name, v_old_cat, v_old_sub
      FROM public.recipe_divisions WHERE id = p_id;
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, tags, sort_order)
    VALUES (p_category, p_subcategory, p_name, coalesce(p_emoji, '🍽'), p_subtitle, p_description, coalesce(p_tags, '{}'), coalesce(p_sort_order, 0))
    ON CONFLICT (category, subcategory, name) DO UPDATE SET
      emoji = EXCLUDED.emoji, subtitle = EXCLUDED.subtitle, description = EXCLUDED.description,
      tags = EXCLUDED.tags, sort_order = EXCLUDED.sort_order, is_active = true
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_divisions SET
      category = p_category, subcategory = p_subcategory, name = p_name,
      emoji = coalesce(p_emoji, emoji), subtitle = p_subtitle, description = p_description,
      tags = coalesce(p_tags, tags), sort_order = coalesce(p_sort_order, sort_order)
    WHERE id = p_id RETURNING id INTO v_id;

    IF v_old_name IS NOT NULL AND v_old_name IS DISTINCT FROM p_name THEN
      UPDATE public.submitted_recipes SET division = p_name
       WHERE category = v_old_cat AND sub_category = v_old_sub AND division = v_old_name;
    END IF;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_division(uuid, text, text, text, text, text, text, text[], int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_division(uuid, text, text, text, text, text, text, text[], int) TO authenticated;

-- ── Verify ───────────────────────────────────────────────────────────────────
SELECT routine_name FROM information_schema.routines
 WHERE routine_schema = 'public'
   AND routine_name IN (
     'admin_get_recipes_bulk',
     'admin_update_recipe_field',
     'admin_bulk_update_recipe_visibility',
     'admin_generate_recipe_codes'
   )
 ORDER BY routine_name;
