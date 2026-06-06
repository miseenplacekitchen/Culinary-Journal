-- ══════════════════════════════════════════════════════════════════════
-- fix-cj006-pipeline.sql
-- Recipe pipeline: public fetch RPC, resubmit RLS, cooking_style column.
-- Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS cooking_style text;

ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS additional_time_minutes integer,
  ADD COLUMN IF NOT EXISTS servings_unit            text DEFAULT 'people',
  ADD COLUMN IF NOT EXISTS shelf_life_value         text,
  ADD COLUMN IF NOT EXISTS shelf_life_unit          text DEFAULT 'months',
  ADD COLUMN IF NOT EXISTS shelf_life_storage       text,
  ADD COLUMN IF NOT EXISTS after_open_value         text,
  ADD COLUMN IF NOT EXISTS after_open_unit          text DEFAULT 'weeks',
  ADD COLUMN IF NOT EXISTS unknown_ingredients      text[];

-- Allow owners to resubmit rejected recipes (status → pending)
DROP POLICY IF EXISTS "Users can update own submissions" ON public.submitted_recipes;
CREATE POLICY "Users can update own submissions"
  ON public.submitted_recipes FOR UPDATE TO authenticated
  USING (auth.uid() = user_id::uuid AND status IN ('pending', 'rejected'))
  WITH CHECK (auth.uid() = user_id::uuid AND status = 'pending');

DROP FUNCTION IF EXISTS public.get_public_recipe(uuid);

CREATE OR REPLACE FUNCTION public.get_public_recipe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row   public.submitted_recipes%ROWTYPE;
  v_user  text;
  v_uid   uuid;
BEGIN
  IF p_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_row
    FROM public.submitted_recipes
   WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT username INTO v_user
    FROM public.profiles
   WHERE id = v_row.user_id;

  v_uid := auth.uid();

  IF is_admin()
     OR (v_uid IS NOT NULL AND v_row.user_id = v_uid)
     OR (v_row.status = 'approved' AND v_row.visibility = 'Public')
  THEN
    RETURN to_jsonb(v_row) || jsonb_build_object('username', v_user);
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_recipe(uuid) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-cj006-pipeline.sql complete' AS status;
