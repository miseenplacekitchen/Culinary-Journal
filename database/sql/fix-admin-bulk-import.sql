-- Run once in Supabase SQL Editor to fix CSV ingredient import failures.
-- Safe to re-run. Fixes duplicate-key errors like uq_ingredients_name_ci on "caster sugar".

DROP FUNCTION IF EXISTS public.admin_bulk_upsert_ingredients(jsonb);
CREATE OR REPLACE FUNCTION public.admin_bulk_upsert_ingredients(p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r           jsonb;
  v_name      text;
  v_csv_id    int;
  v_target_id int;
  v_name_id   int;
  v_inserted  int := 0;
  v_updated   int := 0;
  v_skipped   int := 0;
  v_extra     jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_name := NULLIF(TRIM(r->>'Ingredient Name'), '');
    v_csv_id := NULL;
    v_target_id := NULL;
    v_name_id := NULL;

    IF v_name IS NULL THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    IF (r->>'ID') IS NOT NULL AND BTRIM(r->>'ID') ~ '^\d+$' THEN
      v_csv_id := BTRIM(r->>'ID')::int;
    END IF;

    -- Name match wins (case-insensitive) — avoids unique-constraint collisions
    SELECT "ID" INTO v_name_id
    FROM ingredients
    WHERE LOWER(TRIM("Ingredient Name")) = LOWER(v_name)
    LIMIT 1;

    IF v_name_id IS NOT NULL THEN
      v_target_id := v_name_id;
    ELSIF v_csv_id IS NOT NULL THEN
      SELECT "ID" INTO v_target_id FROM ingredients WHERE "ID" = v_csv_id;
      IF v_target_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM ingredients
        WHERE LOWER(TRIM("Ingredient Name")) = LOWER(v_name)
          AND "ID" <> v_target_id
      ) THEN
        SELECT "ID" INTO v_target_id
        FROM ingredients
        WHERE LOWER(TRIM("Ingredient Name")) = LOWER(v_name)
        LIMIT 1;
      END IF;
    END IF;

    v_extra := r->'extra_fields';
    IF v_extra IS NULL OR v_extra = 'null'::jsonb THEN
      v_extra := NULL;
    END IF;

    IF v_target_id IS NOT NULL THEN
      UPDATE ingredients SET
        "Ingredient Name"          = v_name,
        "Also Known As"            = COALESCE(NULLIF(r->>'Also Known As',''),       "Also Known As"),
        "Category"                 = COALESCE(NULLIF(r->>'Category',''),            "Category"),
        "Sub Category"             = COALESCE(NULLIF(r->>'Sub Category',''),        "Sub Category"),
        "Standard Qty"             = COALESCE(NULLIF(r->>'Standard Qty',''),        "Standard Qty"),
        "Standard Weight (g or ml)"= COALESCE(
          CASE WHEN r->>'Standard Weight (g or ml)' ~ '^\d+(\.\d+)?$'
               THEN (r->>'Standard Weight (g or ml)')::float8 END,
          "Standard Weight (g or ml)"),
        "Unit"                     = COALESCE(NULLIF(r->>'Unit',''),                "Unit"),
        "Liquid (Yes/No)"          = COALESCE(NULLIF(r->>'Liquid (Yes/No)',''),     "Liquid (Yes/No)"),
        "CJ Recommended Brand"     = COALESCE(NULLIF(r->>'CJ Recommended Brand',''),"CJ Recommended Brand"),
        "Allergen"                 = COALESCE(NULLIF(r->>'Allergen',''),            "Allergen"),
        "Vegan (Yes/No)"           = COALESCE(NULLIF(r->>'Vegan (Yes/No)',''),     "Vegan (Yes/No)"),
        "Vegetarian (Yes/No)"      = COALESCE(NULLIF(r->>'Vegetarian (Yes/No)',''),"Vegetarian (Yes/No)"),
        "Notes"                    = COALESCE(NULLIF(r->>'Notes',''),               "Notes"),
        extra_fields               = CASE
          WHEN v_extra IS NOT NULL THEN COALESCE(extra_fields, '{}'::jsonb) || v_extra
          ELSE extra_fields
        END
      WHERE "ID" = v_target_id;
      v_updated := v_updated + 1;
    ELSE
      INSERT INTO ingredients (
        "Ingredient Name","Also Known As","Category","Sub Category","Standard Qty",
        "Standard Weight (g or ml)","Unit","Liquid (Yes/No)","CJ Recommended Brand",
        "Allergen","Vegan (Yes/No)","Vegetarian (Yes/No)","Notes","extra_fields"
      ) VALUES (
        v_name,
        NULLIF(r->>'Also Known As',''),
        NULLIF(r->>'Category',''),
        NULLIF(r->>'Sub Category',''),
        NULLIF(r->>'Standard Qty',''),
        CASE WHEN r->>'Standard Weight (g or ml)' ~ '^\d+(\.\d+)?$'
             THEN (r->>'Standard Weight (g or ml)')::float8 END,
        NULLIF(r->>'Unit',''),
        NULLIF(r->>'Liquid (Yes/No)',''),
        NULLIF(r->>'CJ Recommended Brand',''),
        NULLIF(r->>'Allergen',''),
        NULLIF(r->>'Vegan (Yes/No)',''),
        NULLIF(r->>'Vegetarian (Yes/No)',''),
        NULLIF(r->>'Notes',''),
        COALESCE(v_extra, '{}'::jsonb)
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('inserted', v_inserted, 'updated', v_updated, 'skipped', v_skipped);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_bulk_upsert_ingredients(jsonb) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
