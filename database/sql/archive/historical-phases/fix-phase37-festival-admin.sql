-- fix-phase37-festival-admin.sql — Festival admin CRUD + dish sections
-- Safe to re-run. Run after fix-phase36-platform-batch.sql

ALTER TABLE public.festival_dishes ADD COLUMN IF NOT EXISTS section_label text;

-- ── Admin: upsert festival ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_festival(uuid, text, text, text, text, text, text, text[], int, boolean);
CREATE FUNCTION public.admin_upsert_festival(
  p_id           uuid    DEFAULT NULL,
  p_slug         text    DEFAULT NULL,
  p_name         text    DEFAULT NULL,
  p_emoji        text    DEFAULT '🎉',
  p_when_label   text    DEFAULT NULL,
  p_description  text    DEFAULT NULL,
  p_planner_path text    DEFAULT NULL,
  p_tags         text[]  DEFAULT '{}',
  p_sort_order   int     DEFAULT 0,
  p_is_active    boolean DEFAULT true
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_slug IS NULL OR btrim(p_slug) = '' OR p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Slug and name required';
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.festivals (slug, name, emoji, when_label, description, planner_path, tags, sort_order, is_active)
    VALUES (btrim(p_slug), btrim(p_name), p_emoji, p_when_label, p_description, p_planner_path,
            COALESCE(p_tags, '{}'), COALESCE(p_sort_order, 0), COALESCE(p_is_active, true))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.festivals SET
      slug = btrim(p_slug), name = btrim(p_name), emoji = p_emoji, when_label = p_when_label,
      description = p_description, planner_path = p_planner_path, tags = COALESCE(p_tags, tags),
      sort_order = COALESCE(p_sort_order, sort_order), is_active = COALESCE(p_is_active, is_active),
      updated_at = now()
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_festival(uuid,text,text,text,text,text,text,text[],int,boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_toggle_festival(uuid, boolean);
CREATE FUNCTION public.admin_toggle_festival(p_id uuid, p_is_active boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE public.festivals SET is_active = p_is_active, updated_at = now() WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_toggle_festival(uuid, boolean) TO authenticated;

-- ── Admin: dish slots ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_festival_dish(uuid, uuid, text, text, int, boolean, text);
CREATE FUNCTION public.admin_upsert_festival_dish(
  p_id            uuid    DEFAULT NULL,
  p_festival_id   uuid    DEFAULT NULL,
  p_dish_name     text    DEFAULT NULL,
  p_section_label text    DEFAULT NULL,
  p_sort_order    int     DEFAULT 0,
  p_is_required   boolean DEFAULT false,
  p_notes         text    DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_dish_name IS NULL OR btrim(p_dish_name) = '' THEN RAISE EXCEPTION 'Dish name required'; END IF;
  IF p_id IS NULL THEN
    IF p_festival_id IS NULL THEN RAISE EXCEPTION 'Festival required for new dish'; END IF;
    INSERT INTO public.festival_dishes (festival_id, dish_name, section_label, sort_order, is_required, notes)
    VALUES (p_festival_id, btrim(p_dish_name), NULLIF(btrim(p_section_label), ''), COALESCE(p_sort_order, 0),
            COALESCE(p_is_required, false), p_notes)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.festival_dishes SET
      dish_name = btrim(p_dish_name),
      section_label = NULLIF(btrim(p_section_label), ''),
      sort_order = COALESCE(p_sort_order, sort_order),
      is_required = COALESCE(p_is_required, is_required),
      notes = p_notes
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_festival_dish(uuid,uuid,text,text,int,boolean,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_festival_dish(uuid);
CREATE FUNCTION public.admin_delete_festival_dish(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM public.festival_dishes WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_festival_dish(uuid) TO authenticated;

-- ── Admin: link recipe variants ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_link_festival_recipe(uuid, uuid, uuid, text, boolean);
CREATE FUNCTION public.admin_link_festival_recipe(
  p_id            uuid    DEFAULT NULL,
  p_dish_id       uuid    DEFAULT NULL,
  p_recipe_id     uuid    DEFAULT NULL,
  p_variant_label text    DEFAULT 'Classic',
  p_is_featured   boolean DEFAULT false
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_dish_id IS NULL OR p_recipe_id IS NULL THEN RAISE EXCEPTION 'Dish and recipe required'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.festival_dish_recipes (dish_id, recipe_id, variant_label, is_featured, visibility, approval_status)
    VALUES (p_dish_id, p_recipe_id, COALESCE(NULLIF(btrim(p_variant_label), ''), 'Classic'),
            COALESCE(p_is_featured, false), 'public', 'approved')
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.festival_dish_recipes SET
      recipe_id = p_recipe_id,
      variant_label = COALESCE(NULLIF(btrim(p_variant_label), ''), variant_label),
      is_featured = COALESCE(p_is_featured, is_featured)
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_link_festival_recipe(uuid,uuid,uuid,text,boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_unlink_festival_recipe(uuid);
CREATE FUNCTION public.admin_unlink_festival_recipe(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM public.festival_dish_recipes WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_unlink_festival_recipe(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_search_recipes(text, int);
CREATE FUNCTION public.admin_search_recipes(p_query text, p_limit int DEFAULT 20)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(row_to_json(r) ORDER BY r.recipe_name), '[]'::jsonb)
  FROM (
    SELECT id, recipe_name, category, origin_country
    FROM public.submitted_recipes
    WHERE status = 'approved'
      AND (p_query IS NULL OR btrim(p_query) = '' OR recipe_name ILIKE '%' || btrim(p_query) || '%')
    ORDER BY recipe_name
    LIMIT COALESCE(p_limit, 20)
  ) r;
$$;
GRANT EXECUTE ON FUNCTION public.admin_search_recipes(text, int) TO authenticated;

-- Refresh get_festival_detail to expose section_label
DROP FUNCTION IF EXISTS public.get_festival_detail(text);
CREATE FUNCTION public.get_festival_detail(p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fest jsonb; v_dishes jsonb;
BEGIN
  SELECT row_to_json(f)::jsonb INTO v_fest FROM public.festivals f WHERE f.slug = p_slug AND f.is_active = true;
  IF v_fest IS NULL THEN RETURN NULL; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(d) ORDER BY d.section_label NULLS LAST, d.sort_order), '[]'::jsonb) INTO v_dishes
  FROM (
    SELECT fd.id, fd.dish_name, fd.section_label, fd.sort_order, fd.is_required, fd.notes,
      COALESCE((
        SELECT jsonb_agg(row_to_json(r) ORDER BY r.is_featured DESC, r.variant_label)
        FROM (
          SELECT fdr.id, fdr.variant_label, fdr.is_featured, fdr.visibility, fdr.approval_status,
                 fdr.recipe_id, sr.recipe_name
          FROM public.festival_dish_recipes fdr
          LEFT JOIN public.submitted_recipes sr ON sr.id = fdr.recipe_id
          WHERE fdr.dish_id = fd.id
            AND (fdr.visibility = 'public' AND fdr.approval_status = 'approved'
                 OR fdr.submitted_by = auth.uid())
        ) r
      ), '[]'::jsonb) AS recipes
    FROM public.festival_dishes fd
    WHERE fd.festival_id = (v_fest->>'id')::uuid
  ) d;
  RETURN v_fest || jsonb_build_object('dishes', v_dishes);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_festival_detail(text) TO anon, authenticated;

-- Optional: sample Onam sections (only where section_label still null)
UPDATE public.festival_dishes fd SET section_label = v.sec
FROM public.festivals f,
(VALUES
  ('Upperi / banana chips','Starters & Crunch'),
  ('Inji curry','Pickles & Chutneys'),
  ('Mango pickle','Pickles & Chutneys'),
  ('Lime pickle','Pickles & Chutneys'),
  ('Pappadam','Starters & Crunch'),
  ('Banana (ripe)','Sides'),
  ('Salt','Rice & Staples'),
  ('Parippu + ghee','Rice & Staples'),
  ('Sambar','Main Curries'),
  ('Rasam','Main Curries'),
  ('Avial','Vegetable Dishes'),
  ('Thoran','Vegetable Dishes'),
  ('Olan','Vegetable Dishes'),
  ('Kalan','Vegetable Dishes'),
  ('Erissery','Vegetable Dishes'),
  ('Pulisery','Vegetable Dishes'),
  ('Kootu curry','Vegetable Dishes'),
  ('Payasam (first)','Desserts'),
  ('Payasam (second)','Desserts'),
  ('Rice','Rice & Staples')
) AS v(dish, sec)
WHERE f.slug = 'onam' AND fd.festival_id = f.id AND fd.dish_name = v.dish AND fd.section_label IS NULL;

-- Admin detail (includes inactive festivals)
DROP FUNCTION IF EXISTS public.admin_get_festival_detail(text);
CREATE FUNCTION public.admin_get_festival_detail(p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fest jsonb; v_dishes jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT row_to_json(f)::jsonb INTO v_fest FROM public.festivals f WHERE f.slug = p_slug;
  IF v_fest IS NULL THEN RETURN NULL; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(d) ORDER BY d.section_label NULLS LAST, d.sort_order), '[]'::jsonb) INTO v_dishes
  FROM (
    SELECT fd.id, fd.dish_name, fd.section_label, fd.sort_order, fd.is_required, fd.notes,
      COALESCE((
        SELECT jsonb_agg(row_to_json(r) ORDER BY r.is_featured DESC, r.variant_label)
        FROM (
          SELECT fdr.id, fdr.variant_label, fdr.is_featured, fdr.recipe_id, sr.recipe_name
          FROM public.festival_dish_recipes fdr
          LEFT JOIN public.submitted_recipes sr ON sr.id = fdr.recipe_id
          WHERE fdr.dish_id = fd.id
        ) r
      ), '[]'::jsonb) AS recipes
    FROM public.festival_dishes fd
    WHERE fd.festival_id = (v_fest->>'id')::uuid
  ) d;
  RETURN v_fest || jsonb_build_object('dishes', v_dishes);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_festival_detail(text) TO authenticated;

SELECT 'Phase 37 festival admin ready' AS status;
