-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — Collections + Quick Edit + Public Profile
-- Run in Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── COLLECTIONS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collections (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text DEFAULT '',
  emoji       text DEFAULT '📁',
  is_public   boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own collections" ON public.collections;
CREATE POLICY "Users manage own collections"
  ON public.collections FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Public collections readable" ON public.collections;
CREATE POLICY "Public collections readable"
  ON public.collections FOR SELECT TO anon, authenticated
  USING (is_public = true);

-- ── COLLECTION RECIPES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collection_recipes (
  collection_id uuid REFERENCES public.collections(id) ON DELETE CASCADE,
  recipe_id     uuid REFERENCES public.submitted_recipes(id) ON DELETE CASCADE,
  added_at      timestamptz DEFAULT now(),
  PRIMARY KEY (collection_id, recipe_id)
);
ALTER TABLE public.collection_recipes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own collection recipes" ON public.collection_recipes;
CREATE POLICY "Users manage own collection recipes"
  ON public.collection_recipes FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_id AND c.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_id AND c.user_id = auth.uid()));

-- ── COLLECTION RPCs ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_my_collections()
RETURNS TABLE (
  id uuid, name text, description text, emoji text,
  is_public boolean, recipe_count bigint, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT c.id, c.name, c.description, c.emoji, c.is_public,
           COUNT(cr.recipe_id)::bigint, c.created_at
    FROM public.collections c
    LEFT JOIN public.collection_recipes cr ON cr.collection_id = c.id
    WHERE c.user_id = auth.uid()
    GROUP BY c.id ORDER BY c.created_at DESC;
END; $$;
GRANT EXECUTE ON FUNCTION get_my_collections() TO authenticated;

CREATE OR REPLACE FUNCTION upsert_collection(
  p_id uuid DEFAULT NULL, p_name text DEFAULT '',
  p_description text DEFAULT '', p_emoji text DEFAULT '📁',
  p_is_public boolean DEFAULT false
)
RETURNS public.collections
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.collections;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.collections (user_id, name, description, emoji, is_public)
    VALUES (auth.uid(), p_name, p_description, p_emoji, p_is_public)
    RETURNING * INTO result;
  ELSE
    UPDATE public.collections SET name=p_name, description=p_description,
      emoji=p_emoji, is_public=p_is_public
    WHERE id=p_id AND user_id=auth.uid() RETURNING * INTO result;
  END IF;
  RETURN result;
END; $$;
GRANT EXECUTE ON FUNCTION upsert_collection(uuid,text,text,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION delete_collection(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.collections WHERE id=p_id AND user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION delete_collection(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION add_to_collection(p_collection_id uuid, p_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.collections WHERE id=p_collection_id AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  INSERT INTO public.collection_recipes (collection_id, recipe_id) VALUES (p_collection_id, p_recipe_id)
  ON CONFLICT DO NOTHING;
END; $$;
GRANT EXECUTE ON FUNCTION add_to_collection(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION remove_from_collection(p_collection_id uuid, p_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.collection_recipes
  WHERE collection_id=p_collection_id AND recipe_id=p_recipe_id
    AND EXISTS (SELECT 1 FROM public.collections WHERE id=p_collection_id AND user_id=auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION remove_from_collection(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION get_collection_recipes(p_collection_id uuid)
RETURNS TABLE (
  id uuid, recipe_name text, category text, origin_country text,
  image_url text, dietary_tags text[], status text, added_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.collections WHERE id=p_collection_id
    AND (user_id=auth.uid() OR is_public=true)
  ) THEN RAISE EXCEPTION 'not_found'; END IF;
  RETURN QUERY
    SELECT sr.id, sr.recipe_name, sr.category, sr.origin_country,
           sr.image_url, sr.dietary_tags, sr.status, cr.added_at
    FROM public.collection_recipes cr
    JOIN public.submitted_recipes sr ON sr.id=cr.recipe_id
    WHERE cr.collection_id=p_collection_id
    ORDER BY cr.added_at DESC;
END; $$;
GRANT EXECUTE ON FUNCTION get_collection_recipes(uuid) TO authenticated, anon;

-- Check if recipe is in any of user's collections
CREATE OR REPLACE FUNCTION get_recipe_collections(p_recipe_id uuid)
RETURNS TABLE (id uuid, name text, emoji text, has_recipe boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT c.id, c.name, c.emoji,
           EXISTS(SELECT 1 FROM public.collection_recipes cr WHERE cr.collection_id=c.id AND cr.recipe_id=p_recipe_id)
    FROM public.collections c WHERE c.user_id=auth.uid() ORDER BY c.name;
END; $$;
GRANT EXECUTE ON FUNCTION get_recipe_collections(uuid) TO authenticated;

-- ── QUICK EDIT RECIPE ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION quick_update_recipe(
  p_id         uuid,
  p_name       text,
  p_visibility text,
  p_description text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name = p_name,
    visibility  = LOWER(p_visibility),
    description = COALESCE(p_description, description)
  WHERE id=p_id AND user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION quick_update_recipe(uuid,text,text,text) TO authenticated;

-- ── PUBLIC PROFILE ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_public_profile(p_username text)
RETURNS TABLE (
  id uuid, username text, full_name text, created_at timestamptz,
  recipe_count bigint, collection_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
    SELECT p.id, p.username, p.full_name, u.created_at,
           (SELECT COUNT(*) FROM public.submitted_recipes sr WHERE sr.user_id=p.id AND sr.status='approved' AND sr.visibility='public')::bigint,
           (SELECT COUNT(*) FROM public.collections c WHERE c.user_id=p.id AND c.is_public=true)::bigint
    FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE LOWER(p.username)=LOWER(p_username) AND COALESCE(p.is_active,true)=true;
END; $$;
GRANT EXECUTE ON FUNCTION get_public_profile(text) TO anon, authenticated;
