-- ══════════════════════════════════════════════════════════════════════
-- Notification RPCs — The Culinary Journal
-- Written against the actual notifications table schema:
--   id, user_id, type, recipe_id, recipe_name, message, read, created_at
-- Does NOT alter the table — only creates/replaces functions
-- ══════════════════════════════════════════════════════════════════════

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
