-- fix-admin-taxonomy-editor.sql — Admin-editable sub copy + reorder RPCs (2026).
-- Run once in Supabase SQL Editor. Safe to re-run.

ALTER TABLE public.recipe_subcategories
  ADD COLUMN IF NOT EXISTS tagline text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS emoji text;

-- ── Browse + admin taxonomy RPC (sub copy fields) ────────────────────────────
DROP FUNCTION IF EXISTS public.get_recipe_taxonomy(text);
CREATE OR REPLACE FUNCTION public.get_recipe_taxonomy(p_category text DEFAULT NULL)
RETURNS TABLE (
  subcategory_id uuid,
  subcategory_name text,
  subcategory_category text,
  subcategory_sort_order int,
  subcategory_emoji text,
  subcategory_tagline text,
  subcategory_description text,
  subcategory_ingredient_hints text[],
  division_id uuid,
  division_name text,
  division_emoji text,
  division_subtitle text,
  division_description text,
  division_sort_order int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT sc.id, sc.name, sc.category, sc.sort_order, sc.emoji, sc.tagline, sc.description, sc.ingredient_hints,
         d.id, d.name, d.emoji, d.subtitle, d.description, d.sort_order
    FROM public.recipe_subcategories sc
    LEFT JOIN public.recipe_divisions d
      ON d.category = sc.category AND d.subcategory = sc.name AND COALESCE(d.is_active, false) = true
   WHERE COALESCE(sc.is_active, false) = true
     AND (p_category IS NULL OR sc.category = p_category)
   ORDER BY sc.category, sc.sort_order, sc.name, d.sort_order, d.name;
$$;
REVOKE ALL ON FUNCTION public.get_recipe_taxonomy(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipe_taxonomy(text) TO anon, authenticated;

-- ── Upsert sub-category (name, hints, tagline, description, emoji, sort) ─────
-- Always saves on top: normalizes visible names, reactivates archived rows,
-- resolves same-looking duplicates by normalized (category, name), logs in client auditLog.
-- Renames/moves cascade to submitted_recipes.sub_category and recipe_divisions.subcategory.
DROP FUNCTION IF EXISTS public.admin_upsert_recipe_subcategory(uuid, text, text, int);
DROP FUNCTION IF EXISTS public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[]);
DROP FUNCTION IF EXISTS public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text);
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
  v_match_id uuid;
  v_category text;
  v_name text;
  v_old_name text;
  v_old_cat text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_category := regexp_replace(btrim(replace(COALESCE(p_category, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  v_name := regexp_replace(btrim(replace(COALESCE(p_name, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  IF v_category = '' OR v_name = '' THEN
    RAISE EXCEPTION 'Category and sub-category name are required';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT name, category INTO v_old_name, v_old_cat
      FROM public.recipe_subcategories WHERE id = p_id;
  END IF;

  v_id := p_id;

  -- Prefer the canonical normalized row if one already exists. This lets saving
  -- from a duplicate/dirty row overwrite the canonical row instead of colliding.
  SELECT id INTO v_match_id
    FROM public.recipe_subcategories
   WHERE regexp_replace(btrim(replace(category, chr(160), ' ')), '[[:space:]]+', ' ', 'g') = v_category
     AND regexp_replace(btrim(replace(name, chr(160), ' ')), '[[:space:]]+', ' ', 'g') = v_name
   ORDER BY
     CASE WHEN category = v_category AND name = v_name THEN 0 ELSE 1 END,
     COALESCE(is_active, false) DESC,
     created_at DESC
   LIMIT 1;
  IF v_match_id IS NOT NULL THEN
    v_id := v_match_id;
  END IF;

  -- 1) Update by explicit id (rename + overwrite fields; reactivate if archived)
  IF v_id IS NOT NULL THEN
    UPDATE public.recipe_subcategories SET
      category = v_category,
      name = v_name,
      sort_order = COALESCE(p_sort_order, sort_order),
      ingredient_hints = CASE WHEN p_ingredient_hints IS NULL THEN ingredient_hints ELSE p_ingredient_hints END,
      tagline = CASE WHEN p_tagline IS NULL THEN tagline ELSE NULLIF(TRIM(p_tagline), '') END,
      description = CASE WHEN p_description IS NULL THEN description ELSE NULLIF(TRIM(p_description), '') END,
      emoji = CASE WHEN p_emoji IS NULL THEN emoji ELSE NULLIF(TRIM(p_emoji), '') END,
      is_active = true
    WHERE id = v_id
    RETURNING id INTO v_id;
  END IF;

  -- 2) Resolve archived / hidden / same-looking row by normalized (category, name) and overwrite
  IF v_id IS NULL THEN
    SELECT id INTO v_id
      FROM public.recipe_subcategories
     WHERE regexp_replace(btrim(replace(category, chr(160), ' ')), '[[:space:]]+', ' ', 'g') = v_category
       AND regexp_replace(btrim(replace(name, chr(160), ' ')), '[[:space:]]+', ' ', 'g') = v_name
     ORDER BY
       CASE WHEN category = v_category AND name = v_name THEN 0 ELSE 1 END,
       COALESCE(is_active, false) DESC,
       created_at DESC
     LIMIT 1;
    IF v_id IS NOT NULL THEN
      UPDATE public.recipe_subcategories SET
        category = v_category,
        name = v_name,
        sort_order = COALESCE(p_sort_order, sort_order),
        ingredient_hints = CASE WHEN p_ingredient_hints IS NULL THEN ingredient_hints ELSE p_ingredient_hints END,
        tagline = CASE WHEN p_tagline IS NULL THEN tagline ELSE NULLIF(TRIM(p_tagline), '') END,
        description = CASE WHEN p_description IS NULL THEN description ELSE NULLIF(TRIM(p_description), '') END,
        emoji = CASE WHEN p_emoji IS NULL THEN emoji ELSE NULLIF(TRIM(p_emoji), '') END,
        is_active = true
      WHERE id = v_id
      RETURNING id INTO v_id;
    END IF;
  END IF;

  -- 3) Insert new row, or on name collision overwrite + reactivate
  IF v_id IS NULL THEN
    INSERT INTO public.recipe_subcategories (category, name, sort_order, ingredient_hints, tagline, description, emoji, is_active)
    VALUES (
      v_category, v_name, COALESCE(p_sort_order, 0),
      COALESCE(p_ingredient_hints, '{}'),
      NULLIF(TRIM(p_tagline), ''), NULLIF(TRIM(p_description), ''), NULLIF(TRIM(p_emoji), ''),
      true
    )
    ON CONFLICT (category, name) DO UPDATE SET
      sort_order = COALESCE(EXCLUDED.sort_order, recipe_subcategories.sort_order),
      is_active = true,
      ingredient_hints = CASE WHEN p_ingredient_hints IS NULL THEN recipe_subcategories.ingredient_hints ELSE EXCLUDED.ingredient_hints END,
      tagline = CASE WHEN p_tagline IS NULL THEN recipe_subcategories.tagline ELSE NULLIF(TRIM(EXCLUDED.tagline), '') END,
      description = CASE WHEN p_description IS NULL THEN recipe_subcategories.description ELSE NULLIF(TRIM(EXCLUDED.description), '') END,
      emoji = CASE WHEN p_emoji IS NULL THEN recipe_subcategories.emoji ELSE NULLIF(TRIM(EXCLUDED.emoji), '') END
    RETURNING id INTO v_id;
  END IF;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Sub-category upsert failed for % > %', v_category, v_name;
  END IF;

  -- Only one same-looking sub-category should remain visible after every save.
  UPDATE public.recipe_subcategories
     SET is_active = false
   WHERE id <> v_id
     AND regexp_replace(btrim(replace(category, chr(160), ' ')), '[[:space:]]+', ' ', 'g') = v_category
     AND regexp_replace(btrim(replace(name, chr(160), ' ')), '[[:space:]]+', ' ', 'g') = v_name;

  -- Cascade recipe + division text when a sub-category is renamed or moved.
  IF v_old_name IS NOT NULL AND (v_old_name IS DISTINCT FROM v_name OR v_old_cat IS DISTINCT FROM v_category) THEN
    UPDATE public.submitted_recipes SET
      category = CASE WHEN category = v_old_cat THEN v_category ELSE category END,
      sub_category = v_name
    WHERE category = v_old_cat AND sub_category = v_old_name;

    UPDATE public.recipe_divisions SET
      category = v_category,
      subcategory = v_name
    WHERE category = v_old_cat AND subcategory = v_old_name;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text) TO authenticated;

-- ── Upsert division (cascade recipe text on rename/move) ─────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_recipe_division(uuid, text, text, text, text, text, text, text[], int);
CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_division(
  p_id uuid,
  p_category text,
  p_subcategory text,
  p_name text,
  p_emoji text DEFAULT '🍽',
  p_subtitle text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_tags text[] DEFAULT '{}',
  p_sort_order int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_old_name text;
  v_old_cat text;
  v_old_sub text;
  v_category text;
  v_subcategory text;
  v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_category := regexp_replace(btrim(replace(COALESCE(p_category, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  v_subcategory := regexp_replace(btrim(replace(COALESCE(p_subcategory, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  v_name := regexp_replace(btrim(replace(COALESCE(p_name, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  IF v_category = '' OR v_subcategory = '' OR v_name = '' THEN
    RAISE EXCEPTION 'Category, sub-category, and division name are required';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT name, category, subcategory INTO v_old_name, v_old_cat, v_old_sub
      FROM public.recipe_divisions WHERE id = p_id;
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, tags, sort_order, is_active)
    VALUES (
      v_category, v_subcategory, v_name,
      COALESCE(NULLIF(TRIM(p_emoji), ''), '🍽'),
      NULLIF(TRIM(p_subtitle), ''), NULLIF(TRIM(p_description), ''),
      COALESCE(p_tags, '{}'), COALESCE(p_sort_order, 0), true
    )
    ON CONFLICT (category, subcategory, name) DO UPDATE SET
      emoji = COALESCE(NULLIF(TRIM(EXCLUDED.emoji), ''), recipe_divisions.emoji),
      subtitle = COALESCE(NULLIF(TRIM(EXCLUDED.subtitle), ''), recipe_divisions.subtitle),
      description = COALESCE(NULLIF(TRIM(EXCLUDED.description), ''), recipe_divisions.description),
      tags = COALESCE(EXCLUDED.tags, recipe_divisions.tags),
      sort_order = COALESCE(EXCLUDED.sort_order, recipe_divisions.sort_order),
      is_active = true
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_divisions SET
      category = v_category,
      subcategory = v_subcategory,
      name = v_name,
      emoji = COALESCE(NULLIF(TRIM(p_emoji), ''), emoji),
      subtitle = CASE WHEN p_subtitle IS NULL THEN subtitle ELSE NULLIF(TRIM(p_subtitle), '') END,
      description = CASE WHEN p_description IS NULL THEN description ELSE NULLIF(TRIM(p_description), '') END,
      tags = COALESCE(p_tags, tags),
      sort_order = COALESCE(p_sort_order, sort_order),
      is_active = true
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  IF v_old_name IS NOT NULL AND (
    v_old_name IS DISTINCT FROM v_name OR
    v_old_cat IS DISTINCT FROM v_category OR
    v_old_sub IS DISTINCT FROM v_subcategory
  ) THEN
    UPDATE public.submitted_recipes SET
      category = v_category,
      sub_category = v_subcategory,
      division = v_name
    WHERE category = v_old_cat
      AND sub_category = v_old_sub
      AND division = v_old_name;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_division(uuid, text, text, text, text, text, text, text[], int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_division(uuid, text, text, text, text, text, text, text[], int) TO authenticated;

-- ── Rename top-level browse category (cascade all recipe taxonomy text) ────────
DROP FUNCTION IF EXISTS public.admin_rename_recipe_category(text, text);
CREATE OR REPLACE FUNCTION public.admin_rename_recipe_category(
  p_old_name text,
  p_new_name text
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_old text;
  v_new text;
  v_recipes int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_old := regexp_replace(btrim(replace(COALESCE(p_old_name, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  v_new := regexp_replace(btrim(replace(COALESCE(p_new_name, ''), chr(160), ' ')), '[[:space:]]+', ' ', 'g');
  IF v_old = '' OR v_new = '' THEN
    RAISE EXCEPTION 'Old and new category names are required';
  END IF;
  IF v_old = v_new THEN RETURN 0; END IF;

  UPDATE public.categories SET name = v_new WHERE name = v_old;
  UPDATE public.submitted_recipes SET category = v_new WHERE category = v_old;
  UPDATE public.recipe_subcategories SET category = v_new WHERE category = v_old;
  UPDATE public.recipe_divisions SET category = v_new WHERE category = v_old;

  SELECT count(*)::int INTO v_recipes FROM public.submitted_recipes WHERE category = v_new;
  RETURN v_recipes;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_rename_recipe_category(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_rename_recipe_category(text, text) TO authenticated;

-- ── Reorder subs / divisions within a category ───────────────────────────────
DROP FUNCTION IF EXISTS public.admin_reorder_recipe_subcategories(text, uuid[]);
CREATE OR REPLACE FUNCTION public.admin_reorder_recipe_subcategories(
  p_category text,
  p_ordered_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE i int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_ordered_ids IS NULL OR array_length(p_ordered_ids, 1) IS NULL THEN RETURN; END IF;
  FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
    UPDATE public.recipe_subcategories
       SET sort_order = i * 10
     WHERE id = p_ordered_ids[i] AND category = p_category;
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_reorder_recipe_subcategories(text, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_reorder_recipe_subcategories(text, uuid[]) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_reorder_recipe_divisions(text, text, uuid[]);
CREATE OR REPLACE FUNCTION public.admin_reorder_recipe_divisions(
  p_category text,
  p_subcategory text,
  p_ordered_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE i int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_ordered_ids IS NULL OR array_length(p_ordered_ids, 1) IS NULL THEN RETURN; END IF;
  FOR i IN 1..array_length(p_ordered_ids, 1) LOOP
    UPDATE public.recipe_divisions
       SET sort_order = i * 10
     WHERE id = p_ordered_ids[i]
       AND category = p_category
       AND subcategory = p_subcategory;
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_reorder_recipe_divisions(text, text, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_reorder_recipe_divisions(text, text, uuid[]) TO authenticated;

-- ── Reorder top-level browse categories ────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_category_sort_order(text, int);
CREATE OR REPLACE FUNCTION public.admin_update_category_sort_order(
  p_name text,
  p_sort_order int
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.categories SET sort_order = p_sort_order WHERE name = p_name;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_update_category_sort_order(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_category_sort_order(text, int) TO authenticated;
