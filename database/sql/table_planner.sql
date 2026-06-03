-- Drop old SETOF versions before creating jsonb versions
DROP FUNCTION IF EXISTS public.get_my_events();
DROP FUNCTION IF EXISTS public.get_event_guests(uuid);
DROP FUNCTION IF EXISTS public.get_my_events(uuid);

-- ══════════════════════════════════════════════════════════════════════
-- Table Planner — The Culinary Journal
-- Supports table-planner.html exactly
-- Tables: events, event_guests
-- RPCs: get_my_events, upsert_event, delete_event,
--        get_event_guests, upsert_guest, delete_guest,
--        assign_seat, save_event_layout
-- ══════════════════════════════════════════════════════════════════════

-- ── Events table ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
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
-- Guards for existing events table
ALTER TABLE events ADD COLUMN IF NOT EXISTS user_id     uuid;
ALTER TABLE events ADD COLUMN IF NOT EXISTS name       text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_type  text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_date date;
ALTER TABLE events ADD COLUMN IF NOT EXISTS venue_name text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS notes      text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS layout     jsonb;
ALTER TABLE events ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE events ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT NOW();

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own events" ON events;
CREATE POLICY "users manage own events" ON events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Event guests table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_guests (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id             uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  dietary_requirements jsonb NOT NULL DEFAULT '[]',
  rsvp_status          text DEFAULT 'pending',
  group_name           text,
  plus_one             boolean NOT NULL DEFAULT false,
  plus_one_name        text,
  seat                 text,
  notes                text,
  created_at           timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS event_id             uuid;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS name                 text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS created_at             timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS dietary_requirements   jsonb NOT NULL DEFAULT '[]';
-- Migrate any existing text values to jsonb array
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='event_guests' AND column_name='dietary_requirements'
    AND data_type='text'
  ) THEN
    ALTER TABLE event_guests ALTER COLUMN dietary_requirements TYPE jsonb
      USING CASE WHEN dietary_requirements IS NULL OR dietary_requirements = ''
                 THEN '[]'::jsonb
                 ELSE to_jsonb(string_to_array(dietary_requirements, ','))
            END;
    ALTER TABLE event_guests ALTER COLUMN dietary_requirements SET DEFAULT '[]';
    ALTER TABLE event_guests ALTER COLUMN dietary_requirements SET NOT NULL;
  END IF;
END $$;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS dietary_submitted     boolean     DEFAULT false;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS dietary_submitted_at  timestamptz;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS rsvp_status          text DEFAULT 'pending';
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS group_name           text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS plus_one             boolean NOT NULL DEFAULT false;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS plus_one_name        text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS seat                 text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS notes                text;

ALTER TABLE event_guests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own event guests" ON event_guests;
CREATE POLICY "users manage own event guests" ON event_guests FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.user_id = auth.uid()));

-- ── get_my_events() ───────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_my_events();
CREATE FUNCTION get_my_events()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(e ORDER BY e.event_date ASC NULLS LAST, e.created_at DESC), '[]'::jsonb)
    FROM (
      SELECT id, name, event_type, event_date, venue_name, notes, layout, created_at,
             (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = events.id)::int AS guest_count
      FROM events WHERE user_id = auth.uid()
    ) e
  );
END; $$;
GRANT EXECUTE ON FUNCTION get_my_events() TO authenticated;

-- ── upsert_event(...) ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS upsert_event(uuid, text, text, date, text, text, jsonb);
CREATE FUNCTION upsert_event(
  p_id         uuid    DEFAULT NULL,
  p_name       text    DEFAULT NULL,
  p_event_type text    DEFAULT NULL,
  p_event_date date    DEFAULT NULL,
  p_venue_name text    DEFAULT NULL,
  p_notes      text    DEFAULT NULL,
  p_layout     jsonb   DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_id IS NOT NULL THEN
    UPDATE events SET
      name       = COALESCE(p_name, name),
      event_type = COALESCE(p_event_type, event_type),
      event_date = COALESCE(p_event_date, event_date),
      venue_name = COALESCE(p_venue_name, venue_name),
      notes      = COALESCE(p_notes, notes),
      layout     = CASE WHEN p_layout IS NOT NULL THEN p_layout ELSE layout END,
      updated_at = NOW()
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING id INTO v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
  ELSE
    INSERT INTO events (user_id, name, event_type, event_date, venue_name, notes, layout)
    VALUES (auth.uid(), p_name, p_event_type, p_event_date, p_venue_name, p_notes,
            COALESCE(p_layout, '{"tables":[]}'::jsonb))
    RETURNING id INTO v_id;
  END IF;
  RETURN (SELECT row_to_json(e)::jsonb FROM events e WHERE id = v_id);
END; $$;
GRANT EXECUTE ON FUNCTION upsert_event(uuid, text, text, date, text, text, jsonb) TO authenticated;

-- ── delete_event(p_id) ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS delete_event(uuid);
CREATE FUNCTION delete_event(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  DELETE FROM events WHERE id = p_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION delete_event(uuid) TO authenticated;

-- ── get_event_guests(p_event_id) ──────────────────────────────────────
DROP FUNCTION IF EXISTS get_event_guests(uuid);
CREATE FUNCTION get_event_guests(p_event_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Event not found';
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(g ORDER BY g.created_at ASC), '[]'::jsonb)
    FROM (
      SELECT id, event_id, name, dietary_requirements, rsvp_status,
             group_name, plus_one, plus_one_name, seat, notes, created_at
      FROM event_guests WHERE event_id = p_event_id
    ) g
  );
END; $$;
GRANT EXECUTE ON FUNCTION get_event_guests(uuid) TO authenticated;

-- ── upsert_guest(...) ─────────────────────────────────────────────────
-- Drop both old and new signatures to handle upgrades
DROP FUNCTION IF EXISTS upsert_guest(uuid, uuid, text, text, text, text, boolean, text, text);
DROP FUNCTION IF EXISTS upsert_guest(uuid, uuid, text, jsonb, text, text, boolean, text, text);
CREATE FUNCTION upsert_guest(
  p_id                   uuid    DEFAULT NULL,
  p_event_id             uuid    DEFAULT NULL,
  p_name                 text    DEFAULT NULL,
  p_dietary_requirements jsonb   DEFAULT NULL,
  p_rsvp_status          text    DEFAULT 'pending',
  p_group_name           text    DEFAULT NULL,
  p_plus_one             boolean DEFAULT false,
  p_plus_one_name        text    DEFAULT NULL,
  p_notes                text    DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Event not found';
  END IF;
  IF p_id IS NOT NULL THEN
    UPDATE event_guests SET
      name                 = COALESCE(p_name, name),
      dietary_requirements = p_dietary_requirements,
      rsvp_status          = COALESCE(p_rsvp_status, rsvp_status),
      group_name           = p_group_name,
      plus_one             = COALESCE(p_plus_one, plus_one),
      plus_one_name        = p_plus_one_name,
      notes                = p_notes
    WHERE id = p_id AND event_id = p_event_id
    RETURNING id INTO v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Guest not found'; END IF;
  ELSE
    INSERT INTO event_guests (event_id, name, dietary_requirements, rsvp_status,
                              group_name, plus_one, plus_one_name, notes)
    VALUES (p_event_id, p_name, p_dietary_requirements, p_rsvp_status,
            p_group_name, COALESCE(p_plus_one, false), p_plus_one_name, p_notes)
    RETURNING id INTO v_id;
  END IF;
  RETURN (SELECT row_to_json(g)::jsonb FROM event_guests g WHERE id = v_id);
END; $$;
GRANT EXECUTE ON FUNCTION upsert_guest(uuid, uuid, text, jsonb, text, text, boolean, text, text) TO authenticated;

-- ── delete_guest(p_id) ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS delete_guest(uuid);
CREATE FUNCTION delete_guest(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  DELETE FROM event_guests g
  USING events e
  WHERE g.id = p_id AND g.event_id = e.id AND e.user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Guest not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION delete_guest(uuid) TO authenticated;

-- ── assign_seat(p_guest_id, p_seat) ──────────────────────────────────
-- p_seat NULL = unassign
DROP FUNCTION IF EXISTS assign_seat(uuid, text);
CREATE FUNCTION assign_seat(p_guest_id uuid, p_seat text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE event_guests g SET seat = p_seat
  FROM events e
  WHERE g.id = p_guest_id AND g.event_id = e.id AND e.user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Guest not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION assign_seat(uuid, text) TO authenticated;

-- ── save_event_layout(p_id, p_layout) ────────────────────────────────
DROP FUNCTION IF EXISTS save_event_layout(uuid, jsonb);
CREATE FUNCTION save_event_layout(p_id uuid, p_layout jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE events SET layout = p_layout, updated_at = NOW()
  WHERE id = p_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION save_event_layout(uuid, jsonb) TO authenticated;


-- Revoke public execute on all table planner functions
REVOKE ALL ON FUNCTION get_my_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION upsert_event(uuid, text, text, date, text, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION delete_event(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_event_guests(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION upsert_guest(uuid, uuid, text, jsonb, text, text, boolean, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION delete_guest(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION assign_seat(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION save_event_layout(uuid, jsonb) FROM PUBLIC;

SELECT 'Table planner ready — ' ||
  (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN
   ('get_my_events','upsert_event','delete_event','get_event_guests',
    'upsert_guest','delete_guest','assign_seat','save_event_layout'))
  || '/8 RPCs installed' AS status;

SELECT pg_notify('pgrst', 'reload schema');
