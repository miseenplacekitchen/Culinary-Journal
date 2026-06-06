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
