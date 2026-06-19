-- fix-taxonomy-archive-phase1.sql — Phase 1 critical path (TCJ-adapted steps 1–3).
-- Maps to Database-Schema-Modifications.sql steps 1–3 for THIS schema.
-- Safe to re-run. Run after fix-admin-taxonomy-editor.sql.
--
-- TCJ uses is_active = false as "archived" (no separate is_archived column).

-- ── Step 1: Performance indexes on active/archive flag ───────────────────────
CREATE INDEX IF NOT EXISTS idx_recipe_subcategories_active
  ON public.recipe_subcategories (category, is_active, sort_order);

CREATE INDEX IF NOT EXISTS idx_recipe_divisions_active
  ON public.recipe_divisions (category, subcategory, is_active, sort_order);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'is_active'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_categories_active ON public.categories (is_active, sort_order)';
  END IF;
END $$;

-- ── Step 2: Canonical browse RPC (active rows only) ──────────────────────────
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

-- ── Step 3: Block hard deletes — use is_active = false (archive) ─────────────
CREATE OR REPLACE FUNCTION public.prevent_taxonomy_hard_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Hard delete blocked. Deactivate with is_active = false (admin Remove button).';
END;
$$;

DROP TRIGGER IF EXISTS prevent_recipe_subcategory_delete ON public.recipe_subcategories;
CREATE TRIGGER prevent_recipe_subcategory_delete
  BEFORE DELETE ON public.recipe_subcategories
  FOR EACH ROW EXECUTE FUNCTION public.prevent_taxonomy_hard_delete();

DROP TRIGGER IF EXISTS prevent_recipe_division_delete ON public.recipe_divisions;
CREATE TRIGGER prevent_recipe_division_delete
  BEFORE DELETE ON public.recipe_divisions
  FOR EACH ROW EXECUTE FUNCTION public.prevent_taxonomy_hard_delete();

DROP TRIGGER IF EXISTS prevent_category_delete ON public.categories;
CREATE TRIGGER prevent_category_delete
  BEFORE DELETE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.prevent_taxonomy_hard_delete();

-- ── Admin archive RPCs (soft delete) ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_delete_recipe_subcategory(uuid);
CREATE OR REPLACE FUNCTION public.admin_delete_recipe_subcategory(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_subcategories SET is_active = false WHERE id = p_id;
  UPDATE public.recipe_divisions SET is_active = false
  WHERE subcategory = (SELECT name FROM public.recipe_subcategories WHERE id = p_id)
    AND category = (SELECT category FROM public.recipe_subcategories WHERE id = p_id);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_delete_recipe_subcategory(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_recipe_subcategory(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_recipe_division(uuid);
CREATE OR REPLACE FUNCTION public.admin_delete_recipe_division(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_divisions SET is_active = false WHERE id = p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_delete_recipe_division(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_recipe_division(uuid) TO authenticated;

-- ── Verify ───────────────────────────────────────────────────────────────────
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('get_recipe_taxonomy', 'admin_delete_recipe_subcategory', 'admin_delete_recipe_division')
ORDER BY routine_name;

SELECT tgname FROM pg_trigger
WHERE tgname IN (
  'prevent_recipe_subcategory_delete',
  'prevent_recipe_division_delete',
  'prevent_category_delete'
)
ORDER BY tgname;
