-- ══════════════════════════════════════════════════════════════════════
-- Recipe Notes — personal notes + public tip submissions
-- ══════════════════════════════════════════════════════════════════════

-- Personal notes: one per user per recipe, private
CREATE TABLE IF NOT EXISTS public.recipe_personal_notes (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id  uuid        NOT NULL REFERENCES submitted_recipes(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note       text        NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (recipe_id, user_id)
);
ALTER TABLE public.recipe_personal_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own personal notes" ON public.recipe_personal_notes;
CREATE POLICY "users manage own personal notes" ON public.recipe_personal_notes
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Public note submissions: submitted by users, reviewed by admin
CREATE TABLE IF NOT EXISTS public.recipe_public_notes (
  id         bigserial   PRIMARY KEY,
  recipe_id  uuid        NOT NULL REFERENCES submitted_recipes(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note       text        NOT NULL,
  status     text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_at timestamptz,
  reviewer_id uuid       REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE public.recipe_public_notes ENABLE ROW LEVEL SECURITY;
-- Users can insert their own
DROP POLICY IF EXISTS "users submit public notes" ON public.recipe_public_notes;
CREATE POLICY "users submit public notes" ON public.recipe_public_notes
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
-- Users can read their own
DROP POLICY IF EXISTS "users read own public notes" ON public.recipe_public_notes;
CREATE POLICY "users read own public notes" ON public.recipe_public_notes
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR (status = 'approved'));
-- Admin manages all
DROP POLICY IF EXISTS "admin manages public notes" ON public.recipe_public_notes;
CREATE POLICY "admin manages public notes" ON public.recipe_public_notes
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Get personal note for a recipe
DROP FUNCTION IF EXISTS public.get_my_recipe_note(uuid);
CREATE FUNCTION public.get_my_recipe_note(p_recipe_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN NULL; END IF;
  RETURN (SELECT note FROM recipe_personal_notes
          WHERE recipe_id = p_recipe_id AND user_id = auth.uid());
END; $$;
REVOKE ALL ON FUNCTION public.get_my_recipe_note(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_recipe_note(uuid) TO authenticated;

-- Admin: get pending public notes
DROP FUNCTION IF EXISTS public.admin_get_pending_notes();
CREATE FUNCTION public.admin_get_pending_notes()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(n ORDER BY n.created_at DESC)
     FROM (
       SELECT pn.id, pn.recipe_id, pn.note, pn.status, pn.created_at,
              sr.recipe_name, p.username AS submitted_by
       FROM recipe_public_notes pn
       JOIN submitted_recipes sr ON sr.id = pn.recipe_id
       JOIN profiles p ON p.id = pn.user_id
       WHERE pn.status = 'pending'
     ) n),
    '[]'::jsonb
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_pending_notes() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_pending_notes() TO authenticated;

-- Admin: approve or reject a public note
DROP FUNCTION IF EXISTS public.admin_review_note(bigint, text);
CREATE FUNCTION public.admin_review_note(p_id bigint, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE recipe_public_notes
  SET status = p_status, reviewed_at = NOW(), reviewer_id = auth.uid()
  WHERE id = p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_review_note(bigint, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_review_note(bigint, text) TO authenticated;

SELECT 'Recipe notes ready' AS status;

SELECT pg_notify('pgrst', 'reload schema');
