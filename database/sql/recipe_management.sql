-- ── recipe_drafts table ──────────────────────────────────────────────
-- Stores auto-saved and named drafts from submit-recipe.html
CREATE TABLE IF NOT EXISTS public.recipe_drafts (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_name text,
  draft_data  jsonb       NOT NULL DEFAULT '{}',
  local_key   text,
  updated_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE public.recipe_drafts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own drafts" ON public.recipe_drafts;
CREATE POLICY "Users manage own drafts" ON public.recipe_drafts
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS recipe_drafts_updated_at ON public.recipe_drafts;
CREATE TRIGGER recipe_drafts_updated_at
  BEFORE UPDATE ON public.recipe_drafts
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ── Recipe Management SQL ─────────────────────────────────────────

-- ── 1. Add columns to submitted_recipes ──────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS is_featured            BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS featured_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_recipe_of_week      BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recipe_of_week_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS recipe_of_week_expires TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS native_title        TEXT,
  ADD COLUMN IF NOT EXISTS introduction        TEXT,
  ADD COLUMN IF NOT EXISTS cooking_notes       TEXT,
  ADD COLUMN IF NOT EXISTS photo_url           TEXT;

-- ── 2. Collections table ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_collections (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT,
  recipe_ids  UUID[] NOT NULL DEFAULT '{}',
  published   BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.recipe_collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.recipe_collections;
CREATE POLICY "Admin full access" ON public.recipe_collections FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 3. Enhanced admin_get_recipes ────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipes(text, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.admin_get_recipes(
  p_status   text DEFAULT NULL,
  p_search   text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_limit    integer DEFAULT 50,
  p_offset   integer DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
    SELECT json_build_object(
      'id',                    r.id,
      'recipe_name',           r.recipe_name,
      'native_title',          r.native_title,
      'category',              r.category,
      'spice_level',           r.spice_level,
      'origin_continent',      r.origin_continent,
      'origin_country',        r.origin_country,
      'origin_state',          r.origin_state,
      'status',                r.status,
      'submitted_at',          r.submitted_at,
      'reviewed_at',           r.reviewed_at,
      'reviewer_notes',        r.reviewer_notes,
      'introduction',          r.introduction,
      'cooking_notes',         r.cooking_notes,
      'servings',              r.servings,
      'image_url',             r.image_url,
      'username',              p.username,
      'full_name',             p.full_name,
      'featured',              COALESCE(r.is_featured, false),
      'is_featured',           COALESCE(r.is_featured, false),
      'recipe_of_week',        COALESCE(r.is_recipe_of_week, false),
      'is_recipe_of_week',     COALESCE(r.is_recipe_of_week, false),
      'recipe_of_week_at',     r.recipe_of_week_at,
      'recipe_of_week_expires', r.recipe_of_week_expires
    )
    FROM public.submitted_recipes r
    LEFT JOIN public.profiles p ON p.id = r.user_id
    WHERE (p_status IS NULL OR r.status = p_status)
      AND (p_search IS NULL OR r.recipe_name ILIKE '%' || p_search || '%'
           OR COALESCE(p.username, '') ILIKE '%' || p_search || '%')
      AND (p_category IS NULL OR r.category = p_category)
    ORDER BY r.submitted_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_recipes(text, text, text, integer, integer) TO authenticated;

-- ── 4. Get full recipe detail ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipe_detail(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_recipe_detail(p_id UUID)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT row_to_json(t) INTO result FROM (
    SELECT r.*, p.username, p.full_name, p.avatar_url as submitter_avatar
    FROM public.submitted_recipes r
    LEFT JOIN public.profiles p ON p.id = r.user_id
    WHERE r.id = p_id
  ) t;
  RETURN result;
END;
$$;

-- ── 5. Review recipe (approve/reject/reset) ───────────────────────
-- Canonical owner: manifest.json function_owners.admin_review_recipe
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_review_recipe' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id     uuid,
  p_status text,
  p_notes  text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_name    text;
  v_msg     text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending')
    THEN RAISE EXCEPTION 'Invalid status: %', p_status; END IF;
  SELECT user_id, recipe_name INTO v_user_id, v_name
    FROM public.submitted_recipes WHERE id = p_id;
  UPDATE public.submitted_recipes
     SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
   WHERE id = p_id;
  IF v_user_id IS NOT NULL AND p_status IN ('approved', 'rejected') THEN
    v_msg := CASE p_status
      WHEN 'approved' THEN 'Your recipe "' || COALESCE(v_name, 'submission') || '" was approved and is now live!'
      ELSE 'Your recipe "' || COALESCE(v_name, 'submission') || '" needs updates.'
           || CASE WHEN COALESCE(p_notes, '') <> '' THEN ' ' || p_notes ELSE '' END
    END;
    INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (
      v_user_id,
      CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id, v_name, v_msg
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid,text,text) TO authenticated;

-- ── 6. Edit recipe fields before approving ────────────────────────
DROP FUNCTION IF EXISTS public.admin_edit_recipe(uuid, text, text, text, text, text, text, integer);
CREATE OR REPLACE FUNCTION public.admin_edit_recipe(
  p_id UUID, p_recipe_name TEXT DEFAULT NULL, p_category TEXT DEFAULT NULL,
  p_spice_level TEXT DEFAULT NULL, p_native_title TEXT DEFAULT NULL,
  p_introduction TEXT DEFAULT NULL, p_cooking_notes TEXT DEFAULT NULL,
  p_servings INT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name   = COALESCE(p_recipe_name,   recipe_name),
    category      = COALESCE(p_category,       category),
    spice_level   = COALESCE(p_spice_level,    spice_level),
    native_title  = COALESCE(p_native_title,   native_title),
    introduction  = COALESCE(p_introduction,   introduction),
    cooking_notes = COALESCE(p_cooking_notes,  cooking_notes),
    servings      = COALESCE(p_servings,       servings)
  WHERE id = p_id;
END;
$$;

-- ── 7. Feature/unfeature recipe ───────────────────────────────────
DROP FUNCTION IF EXISTS admin_feature_recipe(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.admin_feature_recipe(p_id UUID, p_featured BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET is_featured = p_featured,
    featured_at = CASE WHEN p_featured THEN now() ELSE NULL END
  WHERE id = p_id;
END;
$$;

-- ── 8. Set recipe of the week ─────────────────────────────────────
DROP FUNCTION IF EXISTS admin_set_recipe_of_week(UUID);
CREATE OR REPLACE FUNCTION public.admin_set_recipe_of_week(p_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes
     SET is_recipe_of_week = false, recipe_of_week_at = NULL, recipe_of_week_expires = NULL
   WHERE is_recipe_of_week = true;
  IF p_id IS NOT NULL THEN
    UPDATE public.submitted_recipes SET
      is_recipe_of_week = true,
      recipe_of_week_at = now(),
      recipe_of_week_expires = now() + interval '7 days'
    WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;
  END IF;
END;
$$;

-- ── 9. Get recipe stats ───────────────────────────────────────────
-- ── 10. Collections CRUD ──────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_collections();
CREATE OR REPLACE FUNCTION public.admin_get_collections()
RETURNS SETOF public.recipe_collections
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.recipe_collections ORDER BY updated_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_save_collection(bigint, text, text, uuid[], boolean);
CREATE OR REPLACE FUNCTION public.admin_save_collection(
  p_id BIGINT DEFAULT NULL, p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL, p_recipe_ids UUID[] DEFAULT '{}',
  p_published BOOLEAN DEFAULT false
)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id BIGINT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_id IS NULL OR p_id = 0 THEN
    INSERT INTO public.recipe_collections (name, description, recipe_ids, published)
    VALUES (p_name, p_description, p_recipe_ids, p_published)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_collections SET
      name = COALESCE(p_name, name),
      description = p_description,
      recipe_ids = p_recipe_ids,
      published = p_published,
      updated_at = now()
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS admin_delete_collection(BIGINT);
CREATE OR REPLACE FUNCTION public.admin_delete_collection(p_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.recipe_collections WHERE id = p_id;
END;
$$;

-- ── Grants ────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_get_recipe_detail(uuid)                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_edit_recipe(uuid,text,text,text,text,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_feature_recipe(uuid,boolean)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_recipe_of_week(uuid)                       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_collections()                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_collection(bigint,text,text,uuid[],boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_collection(bigint)                      TO authenticated;
NOTIFY pgrst, 'reload schema';
