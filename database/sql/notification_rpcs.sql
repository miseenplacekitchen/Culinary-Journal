-- ══════════════════════════════════════════════════════════════════════
-- Notification RPCs — The Culinary Journal
-- Written against the actual notifications table schema:
--   id, user_id, type, recipe_id, recipe_name, message, read, created_at
-- Does NOT alter the table — only creates/replaces functions
-- ══════════════════════════════════════════════════════════════════════

-- ── get_notification_count() ──────────────────────────────────────────
-- Returns count of unread notifications for the current user
DROP FUNCTION IF EXISTS get_notification_count();
CREATE FUNCTION get_notification_count()
RETURNS integer
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT COUNT(*)::integer
  FROM notifications
  WHERE user_id = auth.uid()
    AND COALESCE(read, false) = false;
$$;

-- ── get_my_notifications() ────────────────────────────────────────────
-- Returns up to 50 most recent notifications for the current user
DROP FUNCTION IF EXISTS get_my_notifications();
CREATE FUNCTION get_my_notifications()
RETURNS TABLE (
  id          uuid,
  type        text,
  recipe_id   uuid,
  recipe_name text,
  message     text,
  read        boolean,
  created_at  timestamptz
)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT id, type, recipe_id, recipe_name, message, read, created_at
  FROM notifications
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 50;
$$;

-- ── mark_notification_read(p_id uuid) ────────────────────────────────
-- Marks a single notification as read — only if it belongs to the caller
DROP FUNCTION IF EXISTS mark_notification_read(uuid);
CREATE FUNCTION mark_notification_read(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE notifications SET read = true
  WHERE id = p_id AND user_id = auth.uid();
END;
$$;

-- ── mark_all_notifications_read() ────────────────────────────────────
-- Marks all unread notifications as read for the current user
DROP FUNCTION IF EXISTS mark_all_notifications_read();
CREATE FUNCTION mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE notifications SET read = true
  WHERE user_id = auth.uid()
    AND COALESCE(read, false) = false;
END;
$$;

-- ── send_notification — ADMIN ONLY ────────────────────────────────────
-- Inserts a notification for any user — admin only
DROP FUNCTION IF EXISTS send_notification(uuid, text, uuid, text, text);
CREATE FUNCTION send_notification(
  p_user_id    uuid,
  p_type       text,
  p_recipe_id  uuid    DEFAULT NULL,
  p_recipe_name text   DEFAULT NULL,
  p_message    text    DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  INSERT INTO notifications (user_id, type, recipe_id, recipe_name, message)
  VALUES (p_user_id, p_type, p_recipe_id, p_recipe_name, p_message);
END;
$$;

SELECT 'Notification RPCs ready' AS status;
