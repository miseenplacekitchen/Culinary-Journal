-- fix-phase48-recipe-ingredient-orphans.sql
-- Repair approved-recipe ingredient lines that do not match governed ingredients.
-- Safe to re-run. Run when health_report shows orphan_recipe_ingredient_names > 0.

-- ── 1. Show orphans before repair ─────────────────────────────────────
SELECT DISTINCT
  x.ing_name AS orphan_name,
  x.recipe_count
FROM (
  SELECT
    lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name,
    count(DISTINCT sr.id)::int AS recipe_count
  FROM public.submitted_recipes sr,
       jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
       jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
  WHERE sr.status = 'approved'
    AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
  GROUP BY 1
) x
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
     OR EXISTS (
       SELECT 1
       FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
       WHERE btrim(aka.part) = x.ing_name
     )
)
ORDER BY x.recipe_count DESC, x.ing_name;

-- ── 2. Resolve raw text → canonical governed name (or null) ───────────
CREATE OR REPLACE FUNCTION public.tcj_resolve_governed_ingredient_name(p_raw text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_raw text;
  v_name text;
  v_cnt int;
BEGIN
  v_raw := lower(btrim(COALESCE(p_raw, '')));
  IF v_raw = '' OR length(v_raw) < 2 THEN RETURN NULL; END IF;

  SELECT i."Ingredient Name" INTO v_name
  FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = v_raw
  LIMIT 1;
  IF v_name IS NOT NULL THEN RETURN v_name; END IF;

  SELECT i."Ingredient Name" INTO v_name
  FROM public.ingredients i
  WHERE i."Also Known As" IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM unnest(string_to_array(lower(i."Also Known As"), ',')) aka(part)
      WHERE btrim(aka.part) = v_raw
    )
  LIMIT 1;
  IF v_name IS NOT NULL THEN RETURN v_name; END IF;

  SELECT count(*)::int INTO v_cnt
  FROM public.ingredients i
  WHERE length(v_raw) >= 4
    AND lower(btrim(i."Ingredient Name")) LIKE '%' || v_raw || '%';

  IF v_cnt = 1 THEN
    SELECT i."Ingredient Name" INTO v_name
    FROM public.ingredients i
    WHERE length(v_raw) >= 4
      AND lower(btrim(i."Ingredient Name")) LIKE '%' || v_raw || '%'
    LIMIT 1;
    RETURN v_name;
  END IF;

  SELECT count(*)::int INTO v_cnt
  FROM public.ingredients i
  WHERE length(v_raw) >= 4
    AND v_raw LIKE '%' || lower(btrim(i."Ingredient Name")) || '%'
    AND length(btrim(i."Ingredient Name")) >= 4;

  IF v_cnt = 1 THEN
    SELECT i."Ingredient Name" INTO v_name
    FROM public.ingredients i
    WHERE length(v_raw) >= 4
      AND v_raw LIKE '%' || lower(btrim(i."Ingredient Name")) || '%'
      AND length(btrim(i."Ingredient Name")) >= 4
    LIMIT 1;
    RETURN v_name;
  END IF;

  RETURN NULL;
END;
$$;

-- ── 3. Rewrite approved recipe JSON (ingredient + name keys) ──────────
CREATE OR REPLACE FUNCTION public.repair_orphan_recipe_ingredients()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec record;
  v_secs jsonb;
  v_sec jsonb;
  v_item jsonb;
  v_new_items jsonb;
  v_raw text;
  v_canonical text;
  v_changed boolean;
  v_recipes int := 0;
  v_lines int := 0;
  v_inserted int := 0;
  v_orphan text;
BEGIN
  FOR v_rec IN
    SELECT id, ingredients
    FROM public.submitted_recipes
    WHERE status = 'approved' AND ingredients IS NOT NULL
  LOOP
    v_secs := '[]'::jsonb;
    v_changed := false;

    FOR v_sec IN SELECT value FROM jsonb_array_elements(v_rec.ingredients) AS t(value)
    LOOP
      v_new_items := '[]'::jsonb;
      FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(v_sec->'items', '[]'::jsonb)) AS t(value)
      LOOP
        v_raw := btrim(COALESCE(v_item->>'ingredient', v_item->>'name', ''));
        IF v_raw <> '' THEN
          v_canonical := public.tcj_resolve_governed_ingredient_name(v_raw);
          IF v_canonical IS NOT NULL
             AND (v_item->>'ingredient' IS DISTINCT FROM v_canonical
                  OR v_item->>'name' IS DISTINCT FROM v_canonical) THEN
            v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(v_canonical), true);
            v_item := jsonb_set(v_item, '{name}', to_jsonb(v_canonical), true);
            v_changed := true;
            v_lines := v_lines + 1;
          ELSIF btrim(COALESCE(v_item->>'ingredient', '')) = '' AND btrim(COALESCE(v_item->>'name', '')) <> '' THEN
            v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(btrim(v_item->>'name')), true);
            v_changed := true;
            v_lines := v_lines + 1;
          END IF;
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

  FOR v_orphan IN
    SELECT DISTINCT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
    FROM public.submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
      AND public.tcj_resolve_governed_ingredient_name(
        btrim(COALESCE(item->>'ingredient', item->>'name', ''))
      ) IS NULL
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.ingredients i
      WHERE lower(btrim(i."Ingredient Name")) = v_orphan
    ) THEN
      INSERT INTO public.ingredients ("Ingredient Name", "Category", "Notes")
      VALUES (
        initcap(v_orphan),
        'Uncategorised',
        'Auto-added by fix-phase48 — recipe orphan repair'
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'recipes_updated', v_recipes,
    'lines_normalized', v_lines,
    'ingredients_inserted', v_inserted
  );
END;
$$;

SELECT public.repair_orphan_recipe_ingredients() AS phase48_repair_summary;

-- ── 4. Orphans remaining (expect zero rows) ───────────────────────────
SELECT DISTINCT x.ing_name AS orphan_still_remaining
FROM (
  SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
  FROM public.submitted_recipes sr,
       jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
       jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
  WHERE sr.status = 'approved'
    AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
) x
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
     OR EXISTS (
       SELECT 1
       FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
       WHERE btrim(aka.part) = x.ing_name
     )
)
ORDER BY 1;
