-- fix-security-rpcs.sql — Harden SECURITY DEFINER RPCs (run once in Supabase SQL Editor)
-- See database/security/SECURITY-AUDIT.md for full findings.

-- ── 1. admin_get_submitter — require caller is admin ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_submitter(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN (SELECT email FROM auth.users WHERE id = p_user_id);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_submitter(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_submitter(uuid) TO authenticated;

-- ── 2. send_notification — explicit grants (body already checks is_admin) ───
REVOKE ALL ON FUNCTION public.send_notification(uuid, text, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_notification(uuid, text, uuid, text, text) TO authenticated;

-- ── 3. repair_orphan_recipe_ingredients — admin-only bulk repair ─────────────
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
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

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
REVOKE ALL ON FUNCTION public.repair_orphan_recipe_ingredients() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.repair_orphan_recipe_ingredients() TO authenticated;

SELECT 'fix-security-rpcs applied' AS status;
