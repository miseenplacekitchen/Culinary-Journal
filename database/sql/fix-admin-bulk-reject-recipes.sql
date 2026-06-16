-- fix-admin-bulk-reject-recipes.sql
-- One-shot bulk reject for clearing the admin pending inbox.
-- Run once in Supabase SQL Editor (Betty admin session or postgres).

DROP FUNCTION IF EXISTS public.admin_reject_all_pending(text);
CREATE OR REPLACE FUNCTION public.admin_reject_all_pending(p_notes text DEFAULT 'Bulk inbox clear')
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  r record;
  v_note text := COALESCE(NULLIF(trim(p_notes), ''), 'Bulk inbox clear');
  v_msg text;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  FOR r IN
    SELECT id, user_id, recipe_name
    FROM public.submitted_recipes
    WHERE status = 'pending'
  LOOP
    UPDATE public.submitted_recipes
       SET status = 'rejected',
           reviewer_notes = v_note,
           reviewed_at = now()
     WHERE id = r.id;

    IF r.user_id IS NOT NULL THEN
      v_msg := 'Your recipe "' || COALESCE(r.recipe_name, 'submission') || '" needs updates.'
        || CASE WHEN v_note <> '' THEN ' ' || v_note ELSE '' END;
      INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
      VALUES (r.user_id, 'recipe_rejected', r.id, r.recipe_name, v_msg);
    END IF;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reject_all_pending(text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_reject_all_pending(text) FROM PUBLIC;
