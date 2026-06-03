-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — Notifications + Equipment + Font Size
-- Run in Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── NOTIFICATIONS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  type        text NOT NULL,  -- recipe_approved | recipe_rejected | recipe_pending
  recipe_id   uuid,
  recipe_name text,
  message     text,
  read        boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users see own notifications" ON public.notifications;
CREATE POLICY "Users see own notifications"
  ON public.notifications FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Get unread count (for badge)
DROP FUNCTION IF EXISTS public.get_notification_count();
CREATE OR REPLACE FUNCTION get_notification_count()
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN 0; END IF;
  RETURN (SELECT COUNT(*) FROM public.notifications WHERE user_id = auth.uid() AND read = false);
END; $$;
GRANT EXECUTE ON FUNCTION get_notification_count() TO authenticated;

-- Get all notifications
DROP FUNCTION IF EXISTS public.get_my_notifications();
CREATE OR REPLACE FUNCTION get_my_notifications()
RETURNS SETOF public.notifications
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY SELECT * FROM public.notifications
    WHERE user_id = auth.uid() ORDER BY created_at DESC LIMIT 50;
END; $$;
GRANT EXECUTE ON FUNCTION get_my_notifications() TO authenticated;

-- Mark one as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE id = p_id AND user_id = auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION mark_notification_read(uuid) TO authenticated;

-- Mark all as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE user_id = auth.uid() AND read = false;
END; $$;
GRANT EXECUTE ON FUNCTION mark_all_notifications_read() TO authenticated;

-- Admin creates a notification (called after approve/reject)
CREATE OR REPLACE FUNCTION admin_create_notification(
  p_user_id     uuid,
  p_type        text,
  p_recipe_id   uuid,
  p_recipe_name text,
  p_message     text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
  VALUES (p_user_id, p_type, p_recipe_id, p_recipe_name, p_message);
END; $$;
GRANT EXECUTE ON FUNCTION admin_create_notification(uuid,text,uuid,text,text) TO authenticated;

-- ── EQUIPMENT on submitted_recipes ───────────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS equipment     jsonb DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS cooking_methods jsonb DEFAULT '[]';

-- ── FONT SIZE on profiles ─────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS font_size text DEFAULT 'medium';

-- Update update_my_preferences to include font_size
CREATE OR REPLACE FUNCTION public.update_my_preferences(
  p_dietary_preferences text[], p_allergies text[],
  p_health_conditions text[], p_cooking_style text,
  p_font_size text DEFAULT 'medium'
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.profiles SET
    dietary_preferences = COALESCE(p_dietary_preferences,'{}'),
    allergies           = COALESCE(p_allergies,'{}'),
    health_conditions   = COALESCE(p_health_conditions,'{}'),
    cooking_style       = COALESCE(p_cooking_style,''),
    font_size           = COALESCE(p_font_size,'medium')
  WHERE id = auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION public.update_my_preferences(text[],text[],text[],text,text) TO authenticated;
