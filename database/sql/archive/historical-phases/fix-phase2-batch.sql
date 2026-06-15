-- ══════════════════════════════════════════════════════════════════════
-- fix-phase2-batch.sql — notifications on review, origin_locality column
-- Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS origin_locality text;

CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id   uuid;
  v_name      text;
  v_msg       text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

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
      p_id,
      v_name,
      v_msg
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-phase2-batch.sql complete' AS status;
