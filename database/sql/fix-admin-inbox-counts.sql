-- Admin inbox badge counts — single RPC for dashboard + Interface hubs.
-- Run in Supabase SQL Editor after user_management / recipe / platform batches.

DROP FUNCTION IF EXISTS public.admin_get_inbox_counts();
CREATE OR REPLACE FUNCTION public.admin_get_inbox_counts()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN json_build_object(
    'pending_recipes', (
      SELECT COUNT(*)::int FROM public.submitted_recipes WHERE status = 'pending'
    ),
    'pending_users', (
      SELECT COUNT(*)::int FROM public.profiles WHERE is_active = false
    ),
    'new_feedback', (
      SELECT COUNT(*)::int FROM public.user_feedback WHERE status = 'new'
    ),
    'feedback_actionable', (
      SELECT COUNT(*)::int FROM public.user_feedback WHERE voc_category = 'actionable'
    ),
    'feedback_action_required', (
      SELECT COUNT(*)::int FROM public.user_feedback WHERE action_required IS TRUE
    ),
    'appeals_pending', (
      SELECT COUNT(*)::int FROM public.appeals WHERE status = 'pending'
    ),
    'reports_pending', (
      SELECT COUNT(*)::int FROM public.user_reports WHERE status = 'pending'
    ),
    'print_orders_pending', (
      SELECT COUNT(*)::int FROM public.print_order_requests WHERE status = 'pending'
    ),
    'pending_notes', (
      SELECT COUNT(*)::int FROM public.recipe_public_notes WHERE status = 'pending'
    ),
    'pending_ingredients', (
      SELECT COUNT(*)::int FROM public.pending_ingredients WHERE status = 'pending'
    ),
    'library_submissions_pending', (
      SELECT COUNT(*)::int FROM public.library_profile_submissions WHERE status = 'pending'
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_inbox_counts() TO authenticated;

SELECT 'fix-admin-inbox-counts.sql complete' AS status;
