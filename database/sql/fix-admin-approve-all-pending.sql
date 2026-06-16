-- fix-admin-approve-all-pending.sql
-- One-shot bulk approve for clearing the admin pending inbox.
-- Run once in Supabase SQL Editor (Betty admin session or postgres).

DROP FUNCTION IF EXISTS public.admin_approve_all_pending();
CREATE OR REPLACE FUNCTION public.admin_approve_all_pending()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  r record;
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
       SET status = 'approved',
           reviewed_at = now(),
           reviewer_id = auth.uid()
     WHERE id = r.id;

    IF r.user_id IS NOT NULL THEN
      v_msg := 'Your recipe "' || COALESCE(r.recipe_name, 'submission') || '" was approved and is now live!';
      INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
      VALUES (r.user_id, 'recipe_approved', r.id, r.recipe_name, v_msg);
    END IF;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_approve_all_pending() TO authenticated;
REVOKE ALL ON FUNCTION public.admin_approve_all_pending() FROM PUBLIC;
