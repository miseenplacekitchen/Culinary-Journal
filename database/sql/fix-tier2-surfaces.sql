-- ══════════════════════════════════════════════════════════════════════
-- fix-tier2-surfaces.sql
-- Notifications page + dietary-card guest links (safe to re-run).
-- Run in Supabase SQL Editor after fix-all-live.sql if those pages fail.
-- ══════════════════════════════════════════════════════════════════════

-- ── Notifications table + user RPCs ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  type        text NOT NULL,
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

-- Drop stale signatures before recreate (return type cannot change via CREATE OR REPLACE)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN (
               'get_notification_count',
               'get_my_notifications',
               'mark_notification_read',
               'mark_all_notifications_read',
               'get_guest_card',
               'submit_guest_dietary'
             )
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.get_notification_count()
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN 0; END IF;
  RETURN (SELECT COUNT(*) FROM public.notifications
          WHERE user_id = auth.uid() AND read = false);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_notification_count() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_notifications()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(n ORDER BY n.created_at DESC)
     FROM (SELECT * FROM public.notifications WHERE user_id = auth.uid()
           ORDER BY created_at DESC LIMIT 50) n),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_notifications() TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE id = p_id AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE user_id = auth.uid() AND read = false;
END;
$$;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

-- ── Table planner tables (needed for dietary-card links) ───────────
CREATE TABLE IF NOT EXISTS public.events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       text NOT NULL,
  event_type text,
  event_date date,
  venue_name text,
  notes      text,
  layout     jsonb NOT NULL DEFAULT '{"tables":[]}',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.events ADD COLUMN IF NOT EXISTS user_id     uuid;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS name       text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_type  text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS event_date date;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS venue_name text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS notes      text;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS layout     jsonb;
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT NOW();

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own events" ON public.events;
CREATE POLICY "users manage own events" ON public.events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.event_guests (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id             uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  dietary_requirements jsonb NOT NULL DEFAULT '[]',
  dietary_submitted    boolean DEFAULT false,
  dietary_submitted_at timestamptz,
  rsvp_status          text DEFAULT 'pending',
  group_name           text,
  plus_one             boolean NOT NULL DEFAULT false,
  plus_one_name        text,
  seat                 text,
  notes                text,
  created_at           timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.event_guests ADD COLUMN IF NOT EXISTS dietary_submitted    boolean DEFAULT false;
ALTER TABLE public.event_guests ADD COLUMN IF NOT EXISTS dietary_submitted_at  timestamptz;

ALTER TABLE public.event_guests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own event guests" ON public.event_guests;
CREATE POLICY "users manage own event guests" ON public.event_guests FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.events e WHERE e.id = event_id AND e.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.events e WHERE e.id = event_id AND e.user_id = auth.uid()));

-- ── Public dietary-card RPCs (guest id = bearer token) ───────────────
CREATE OR REPLACE FUNCTION public.get_guest_card(p_token uuid)
RETURNS TABLE (
  guest_name           text,
  event_name           text,
  event_date           date,
  event_type           text,
  dietary_requirements jsonb,
  already_submitted    boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT g.name, e.name, e.event_date, e.event_type,
           COALESCE(g.dietary_requirements, '[]'::jsonb),
           COALESCE(g.dietary_submitted, false)
    FROM public.event_guests g
    JOIN public.events e ON e.id = g.event_id
    WHERE g.id = p_token;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_guest_card(uuid) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_guest_dietary(p_token uuid, p_dietary jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.event_guests SET
    dietary_requirements = COALESCE(p_dietary, '[]'::jsonb),
    dietary_submitted    = true,
    dietary_submitted_at = now()
  WHERE id = p_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'guest_not_found';
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_guest_dietary(uuid, jsonb) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-tier2-surfaces.sql complete' AS status;
