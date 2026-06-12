-- =============================================================================
-- PHASES 39 + 40 ONLY — PARTIAL SNAPSHOT (superseded)
-- Prefer RUN-IN-SUPABASE-copy-paste-this.sql or RUN-LIVE-CLEANUP.sql instead.
-- Missing phases 41–43 health alignment. Do not use on fresh production refresh.
-- =============================================================================


-- ########## BEGIN: fix-phase39-data-integrity.sql ##########
-- fix-phase39-data-integrity.sql
-- Data integrity layer: ingredient amend cascade, guarded delete, bulk recipe
-- normalisation, integrity report, performance indexes, ingredient lookup RPC.
-- Safe to re-run. Run in Supabase SQL Editor after fix-library-unified.sql.

-- ── 1. Performance indexes (10k+ recipes) ─────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sr_status_submitted
  ON public.submitted_recipes (status, submitted_at DESC);

CREATE INDEX IF NOT EXISTS idx_sr_approved_public
  ON public.submitted_recipes (submitted_at DESC)
  WHERE status = 'approved' AND visibility = 'Public';

CREATE INDEX IF NOT EXISTS idx_sr_category
  ON public.submitted_recipes (category)
  WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_sr_user_id
  ON public.submitted_recipes (user_id);

CREATE INDEX IF NOT EXISTS idx_ingredients_name_lower
  ON public.ingredients (lower(trim("Ingredient Name")));

-- ── 2. Clean invalid governed links before FK ─────────────────────────
UPDATE public.library_profiles lp
SET governed_ingredient_id = NULL, updated_at = now()
WHERE lp.governed_ingredient_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id
  );

DO $$ BEGIN
  ALTER TABLE public.library_profiles
    ADD CONSTRAINT library_profiles_governed_ingredient_fk
    FOREIGN KEY (governed_ingredient_id) REFERENCES public.ingredients("ID")
    ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 3. Rewrite ingredient name across all recipe JSONB ────────────────
CREATE OR REPLACE FUNCTION public._rewrite_recipe_ingredient_name(p_old text, p_new text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec   record;
  v_secs  jsonb;
  v_sec   jsonb;
  v_items jsonb;
  v_item  jsonb;
  v_new_items jsonb;
  v_changed   boolean;
  v_recipes   int := 0;
BEGIN
  IF p_old IS NULL OR btrim(p_old) = '' OR p_new IS NULL OR btrim(p_new) = '' THEN
    RETURN 0;
  END IF;
  IF lower(btrim(p_old)) = lower(btrim(p_new)) THEN
    RETURN 0;
  END IF;

  FOR v_rec IN
    SELECT id, ingredients
    FROM public.submitted_recipes
    WHERE ingredients IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ingredients) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE lower(btrim(item->>'ingredient')) = lower(btrim(p_old))
      )
  LOOP
    v_secs := '[]'::jsonb;
    v_changed := false;

    FOR v_sec IN SELECT value FROM jsonb_array_elements(v_rec.ingredients) AS t(value)
    LOOP
      v_new_items := '[]'::jsonb;
      FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(v_sec->'items', '[]'::jsonb)) AS t(value)
      LOOP
        IF lower(btrim(v_item->>'ingredient')) = lower(btrim(p_old)) THEN
          v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(btrim(p_new)));
          v_changed := true;
        END IF;
        v_new_items := v_new_items || jsonb_build_array(v_item);
      END LOOP;
      v_sec := jsonb_set(v_sec, '{items}', v_new_items);
      v_secs := v_secs || jsonb_build_array(v_sec);
    END LOOP;

    IF v_changed THEN
      UPDATE public.submitted_recipes SET ingredients = v_secs WHERE id = v_rec.id;
      v_recipes := v_recipes + 1;
    END IF;
  END LOOP;

  RETURN v_recipes;
END; $$;

-- ── 4. Sync linked library profiles when governed ingredient changes ───
CREATE OR REPLACE FUNCTION public._sync_library_profiles_for_ingredient(
  p_ingredient_id int, p_new_name text, p_old_name text DEFAULT NULL, p_new_aka text DEFAULT NULL
)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  UPDATE public.library_profiles
  SET
    name = CASE
      WHEN p_old_name IS NOT NULL
           AND lower(btrim(name)) = lower(btrim(p_old_name))
      THEN btrim(p_new_name)
      ELSE name
    END,
    also_known_as = COALESCE(NULLIF(btrim(p_new_aka), ''), also_known_as),
    updated_at = now()
  WHERE profile_type = 'ingredient'
    AND governed_ingredient_id = p_ingredient_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

-- ── 5. Preview amend impact ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_preview_ingredient_amend(int, text);
CREATE FUNCTION public.admin_preview_ingredient_amend(p_id int, p_new_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old_name text;
  v_recipe_count int := 0;
  v_profile_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT "Ingredient Name" INTO v_old_name FROM ingredients WHERE "ID" = p_id;
  IF v_old_name IS NULL THEN RAISE EXCEPTION 'Ingredient not found'; END IF;

  IF p_new_name IS NOT NULL AND btrim(p_new_name) <> ''
     AND lower(btrim(p_new_name)) <> lower(btrim(v_old_name)) THEN
    SELECT count(*)::int INTO v_recipe_count
    FROM submitted_recipes sr
    WHERE sr.ingredients IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(sr.ingredients) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE lower(btrim(item->>'ingredient')) = lower(btrim(v_old_name))
      );
  END IF;

  SELECT count(*)::int INTO v_profile_count
  FROM library_profiles
  WHERE profile_type = 'ingredient' AND governed_ingredient_id = p_id;

  RETURN jsonb_build_object(
    'ingredient_id', p_id,
    'old_name', v_old_name,
    'new_name', COALESCE(NULLIF(btrim(p_new_name), ''), v_old_name),
    'name_will_change', (p_new_name IS NOT NULL AND btrim(p_new_name) <> ''
      AND lower(btrim(p_new_name)) <> lower(btrim(v_old_name))),
    'recipes_affected', v_recipe_count,
    'library_profiles_linked', v_profile_count
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_preview_ingredient_amend(int,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_preview_ingredient_amend(int,text) TO authenticated;

-- ── 6. Enhanced upsert — propagates rename to recipes + library ───────
DROP FUNCTION IF EXISTS public.admin_upsert_ingredient(int, text, text, text, text, text, float8, text, text, text, text, text, text, text, jsonb);
CREATE FUNCTION public.admin_upsert_ingredient(
  p_id integer DEFAULT NULL,
  p_ingredient_name text DEFAULT NULL, p_also_known_as text DEFAULT NULL,
  p_category text DEFAULT NULL, p_sub_category text DEFAULT NULL,
  p_standard_qty text DEFAULT NULL, p_standard_weight float8 DEFAULT NULL,
  p_unit text DEFAULT NULL, p_liquid text DEFAULT NULL,
  p_cj_recommended_brand text DEFAULT NULL, p_allergen text DEFAULT NULL,
  p_vegan text DEFAULT NULL, p_vegetarian text DEFAULT NULL,
  p_notes text DEFAULT NULL, p_extra_fields jsonb DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id int;
  v_old_name text;
  v_new_name text;
  v_recipes_updated int := 0;
  v_profiles_synced int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  v_new_name := NULLIF(btrim(p_ingredient_name), '');

  IF p_id IS NOT NULL THEN
    SELECT "Ingredient Name" INTO v_old_name FROM ingredients WHERE "ID" = p_id;
    IF v_old_name IS NULL THEN RAISE EXCEPTION 'Ingredient not found'; END IF;

    UPDATE ingredients SET
      "Ingredient Name"       = COALESCE(v_new_name, "Ingredient Name"),
      "Also Known As"         = COALESCE(NULLIF(btrim(p_also_known_as), ''), "Also Known As"),
      "Category"              = COALESCE(NULLIF(btrim(p_category), ''), "Category"),
      "Sub Category"          = COALESCE(NULLIF(btrim(p_sub_category), ''), "Sub Category"),
      "Standard Qty"          = COALESCE(NULLIF(btrim(p_standard_qty), ''), "Standard Qty"),
      "Standard Weight (g or ml)" = COALESCE(p_standard_weight, "Standard Weight (g or ml)"),
      "Unit"                  = COALESCE(NULLIF(btrim(p_unit), ''), "Unit"),
      "Liquid (Yes/No)"       = COALESCE(NULLIF(btrim(p_liquid), ''), "Liquid (Yes/No)"),
      "CJ Recommended Brand"  = COALESCE(NULLIF(btrim(p_cj_recommended_brand), ''), "CJ Recommended Brand"),
      "Allergen"              = COALESCE(NULLIF(btrim(p_allergen), ''), "Allergen"),
      "Vegan (Yes/No)"        = COALESCE(NULLIF(btrim(p_vegan), ''), "Vegan (Yes/No)"),
      "Vegetarian (Yes/No)"   = COALESCE(NULLIF(btrim(p_vegetarian), ''), "Vegetarian (Yes/No)"),
      "Notes"                 = COALESCE(NULLIF(btrim(p_notes), ''), "Notes"),
      extra_fields            = CASE
        WHEN p_extra_fields IS NOT NULL THEN COALESCE(extra_fields, '{}'::jsonb) || p_extra_fields
        ELSE extra_fields
      END
    WHERE "ID" = p_id RETURNING "ID" INTO v_id;

    IF v_new_name IS NOT NULL AND lower(btrim(v_new_name)) <> lower(btrim(v_old_name)) THEN
      v_recipes_updated := _rewrite_recipe_ingredient_name(v_old_name, v_new_name);
      v_profiles_synced := _sync_library_profiles_for_ingredient(p_id, v_new_name, v_old_name, p_also_known_as);
    END IF;

    RETURN jsonb_build_object(
      'id', v_id, 'action', 'updated',
      'recipes_updated', v_recipes_updated,
      'library_profiles_synced', v_profiles_synced
    );
  ELSE
    IF v_new_name IS NULL THEN RAISE EXCEPTION 'Ingredient name is required'; END IF;
    INSERT INTO ingredients (
      "Ingredient Name","Also Known As","Category","Sub Category","Standard Qty",
      "Standard Weight (g or ml)","Unit","Liquid (Yes/No)","CJ Recommended Brand",
      "Allergen","Vegan (Yes/No)","Vegetarian (Yes/No)","Notes","extra_fields"
    ) VALUES (
      v_new_name, NULLIF(btrim(p_also_known_as), ''),
      NULLIF(btrim(p_category), ''), NULLIF(btrim(p_sub_category), ''),
      NULLIF(btrim(p_standard_qty), ''), p_standard_weight,
      NULLIF(btrim(p_unit), ''), NULLIF(btrim(p_liquid), ''),
      NULLIF(btrim(p_cj_recommended_brand), ''), NULLIF(btrim(p_allergen), ''),
      NULLIF(btrim(p_vegan), ''), NULLIF(btrim(p_vegetarian), ''),
      NULLIF(btrim(p_notes), ''), COALESCE(p_extra_fields, '{}'::jsonb)
    ) RETURNING "ID" INTO v_id;
    RETURN jsonb_build_object('id', v_id, 'action', 'inserted', 'recipes_updated', 0, 'library_profiles_synced', 0);
  END IF;
END; $$;
REVOKE ALL ON FUNCTION public.admin_upsert_ingredient(int,text,text,text,text,text,float8,text,text,text,text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_ingredient(int,text,text,text,text,text,float8,text,text,text,text,text,text,text,jsonb) TO authenticated;

-- ── 7. Guarded delete ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_delete_ingredient(int);
DROP FUNCTION IF EXISTS public.admin_delete_ingredient(int, boolean);
CREATE FUNCTION public.admin_delete_ingredient(p_id int, p_force boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_name text;
  v_recipe_count int := 0;
  v_profile_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT "Ingredient Name" INTO v_name FROM ingredients WHERE "ID" = p_id;
  IF v_name IS NULL THEN RAISE EXCEPTION 'Ingredient not found'; END IF;

  SELECT count(*)::int INTO v_recipe_count
  FROM submitted_recipes sr
  WHERE sr.ingredients IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(sr.ingredients) sec,
           jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      WHERE lower(btrim(item->>'ingredient')) = lower(btrim(v_name))
    );

  SELECT count(*)::int INTO v_profile_count
  FROM library_profiles
  WHERE profile_type = 'ingredient' AND governed_ingredient_id = p_id;

  IF NOT p_force AND (v_recipe_count > 0 OR v_profile_count > 0) THEN
    RETURN jsonb_build_object(
      'blocked', true,
      'ingredient_id', p_id,
      'ingredient_name', v_name,
      'recipes_using', v_recipe_count,
      'library_profiles_linked', v_profile_count,
      'message', 'Ingredient is in use. Pass p_force=true to delete anyway (library links will be cleared).'
    );
  END IF;

  DELETE FROM ingredients WHERE "ID" = p_id;
  RETURN jsonb_build_object(
    'blocked', false, 'deleted', true,
    'ingredient_id', p_id, 'ingredient_name', v_name,
    'recipes_had', v_recipe_count, 'profiles_unlinked', v_profile_count
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_ingredient(int,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_ingredient(int,boolean) TO authenticated;

-- ── 8. Bulk normalise recipe ingredient spellings (10k migration) ─────
DROP FUNCTION IF EXISTS public.admin_bulk_normalize_recipe_ingredients(int, int);
CREATE FUNCTION public.admin_bulk_normalize_recipe_ingredients(
  p_limit int DEFAULT 100, p_offset int DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec       record;
  v_secs      jsonb;
  v_sec       jsonb;
  v_items     jsonb;
  v_item      jsonb;
  v_new_items jsonb;
  v_canonical text;
  v_changed   boolean;
  v_recipes   int := 0;
  v_items_fixed int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  p_limit := GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  FOR v_rec IN
    SELECT id, ingredients
    FROM submitted_recipes
    WHERE ingredients IS NOT NULL
    ORDER BY id
    LIMIT p_limit OFFSET p_offset
  LOOP
    v_secs := '[]'::jsonb;
    v_changed := false;

    FOR v_sec IN SELECT value FROM jsonb_array_elements(v_rec.ingredients) AS t(value)
    LOOP
      v_new_items := '[]'::jsonb;
      FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(v_sec->'items', '[]'::jsonb)) AS t(value)
      LOOP
        v_canonical := NULL;
        SELECT i."Ingredient Name" INTO v_canonical
        FROM ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = lower(btrim(v_item->>'ingredient'))
        LIMIT 1;

        IF v_canonical IS NULL THEN
          SELECT i."Ingredient Name" INTO v_canonical
          FROM ingredients i
          WHERE i."Also Known As" IS NOT NULL
            AND lower(btrim(i."Also Known As")) = lower(btrim(v_item->>'ingredient'))
          LIMIT 1;
        END IF;

        IF v_canonical IS NOT NULL AND v_item->>'ingredient' IS DISTINCT FROM v_canonical THEN
          v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(v_canonical));
          v_changed := true;
          v_items_fixed := v_items_fixed + 1;
        END IF;
        v_new_items := v_new_items || jsonb_build_array(v_item);
      END LOOP;
      v_sec := jsonb_set(v_sec, '{items}', v_new_items);
      v_secs := v_secs || jsonb_build_array(v_sec);
    END LOOP;

    IF v_changed THEN
      UPDATE submitted_recipes SET ingredients = v_secs WHERE id = v_rec.id;
      v_recipes := v_recipes + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'recipes_updated', v_recipes,
    'ingredient_lines_fixed', v_items_fixed,
    'batch_limit', p_limit,
    'batch_offset', p_offset
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_normalize_recipe_ingredients(int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_normalize_recipe_ingredients(int,int) TO authenticated;

-- ── 9. Full integrity report ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_data_integrity_report();
CREATE FUNCTION public.admin_data_integrity_report()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_total_ingredients int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'recipes', v_total_recipes,
      'ingredients', v_total_ingredients
    ),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (v_invalid_governed = 0 AND v_dupes = 0 AND v_orphan_recipe_names = 0)
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_data_integrity_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report() TO authenticated;

-- ── 10. Compact ingredient index for client pages (no 500 cap) ────────
DROP FUNCTION IF EXISTS public.get_ingredient_lookup_index();
CREATE FUNCTION public.get_ingredient_lookup_index()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', i."ID",
    'name', i."Ingredient Name",
    'aka', i."Also Known As",
    'category', i."Category",
    'unit', i."Unit",
    'allergen', i."Allergen",
    'brand', i."CJ Recommended Brand"
  ) ORDER BY i."Ingredient Name"), '[]'::jsonb)
  FROM public.ingredients i
  WHERE i."Ingredient Name" IS NOT NULL AND btrim(i."Ingredient Name") <> '';
$$;
REVOKE ALL ON FUNCTION public.get_ingredient_lookup_index() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_ingredient_lookup_index() TO anon, authenticated;

SELECT 'fix-phase39-data-integrity ready' AS status;

-- ########## BEGIN: fix-phase40-meal-planner-picker.sql ##########
-- fix-phase40-meal-planner-picker.sql
-- Meal planner: search full approved library (name, native title, AKA).
-- Safe to re-run.

ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS also_known_as text DEFAULT '';

DROP FUNCTION IF EXISTS public.get_approved_recipes(text, text, text, text, text, text, int, int);

CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category     text DEFAULT NULL,
  p_spice        text DEFAULT NULL,
  p_dietary      text DEFAULT NULL,
  p_search       text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL,
  p_limit        int  DEFAULT 50,
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
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
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
     )
     AND (p_sub_category IS NULL OR btrim(p_sub_category) = '' OR sr.sub_category = p_sub_category)
     AND (p_division     IS NULL OR btrim(p_division) = '' OR sr.division = p_division)
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

GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,text,text,int,int) TO anon, authenticated;

SELECT 'fix-phase40-meal-planner-picker ready' AS status;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'PHASES 39-40 COMPLETE' AS status;
