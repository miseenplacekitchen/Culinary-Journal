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
-- Always saves on top: reactivates archived rows, resolves by (category, name), logs nothing here (client auditLog).
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
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_id := p_id;

  -- 1) Update by explicit id (rename + overwrite fields; reactivate if archived)
  IF v_id IS NOT NULL THEN
    UPDATE public.recipe_subcategories SET
      category = p_category,
      name = p_name,
      sort_order = COALESCE(p_sort_order, sort_order),
      ingredient_hints = CASE WHEN p_ingredient_hints IS NULL THEN ingredient_hints ELSE p_ingredient_hints END,
      tagline = CASE WHEN p_tagline IS NULL THEN tagline ELSE NULLIF(TRIM(p_tagline), '') END,
      description = CASE WHEN p_description IS NULL THEN description ELSE NULLIF(TRIM(p_description), '') END,
      emoji = CASE WHEN p_emoji IS NULL THEN emoji ELSE NULLIF(TRIM(p_emoji), '') END,
      is_active = true
    WHERE id = v_id
    RETURNING id INTO v_id;
  END IF;

  -- 2) Resolve archived / hidden row by (category, name) and overwrite
  IF v_id IS NULL THEN
    SELECT id INTO v_id
      FROM public.recipe_subcategories
     WHERE category = p_category AND name = p_name
     LIMIT 1;
    IF v_id IS NOT NULL THEN
      UPDATE public.recipe_subcategories SET
        category = p_category,
        name = p_name,
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
      p_category, p_name, COALESCE(p_sort_order, 0),
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
    RAISE EXCEPTION 'Sub-category upsert failed for % > %', p_category, p_name;
  END IF;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_subcategory(uuid, text, text, int, text[], text, text, text) TO authenticated;

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
