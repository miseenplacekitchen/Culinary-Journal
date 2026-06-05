-- ══════════════════════════════════════════════════════════════════════
-- Grocery List — The Culinary Journal
-- Single-row-per-user storage matching grocery.html data structure
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS grocery_lists (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  list_data  jsonb NOT NULL DEFAULT '{"recipes":[]}',
  checked    jsonb NOT NULL DEFAULT '[]',
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE grocery_lists ADD COLUMN IF NOT EXISTS list_data  jsonb NOT NULL DEFAULT '{"recipes":[]}';
ALTER TABLE grocery_lists ADD COLUMN IF NOT EXISTS checked    jsonb NOT NULL DEFAULT '[]';
ALTER TABLE grocery_lists ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE grocery_lists ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own grocery list" ON grocery_lists;
CREATE POLICY "users manage own grocery list" ON grocery_lists
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── get_my_grocery_list() ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_my_grocery_list();
CREATE FUNCTION get_my_grocery_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_build_object('list_data', list_data, 'checked', checked, 'updated_at', updated_at)
     FROM grocery_lists WHERE user_id = auth.uid()),
    jsonb_build_object('list_data', '{"recipes":[]}'::jsonb, 'checked', '[]'::jsonb, 'updated_at', NOW())
  );
END; $$;
GRANT EXECUTE ON FUNCTION get_my_grocery_list() TO authenticated;

-- ── save_my_grocery_list(p_list_data, p_checked) ─────────────────────
DROP FUNCTION IF EXISTS save_my_grocery_list(jsonb, jsonb);
CREATE FUNCTION save_my_grocery_list(p_list_data jsonb, p_checked jsonb DEFAULT '[]')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  INSERT INTO grocery_lists (user_id, list_data, checked, updated_at)
  VALUES (auth.uid(), p_list_data, p_checked, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    list_data  = EXCLUDED.list_data,
    checked    = EXCLUDED.checked,
    updated_at = NOW();
END; $$;
GRANT EXECUTE ON FUNCTION save_my_grocery_list(jsonb, jsonb) TO authenticated;

SELECT 'Grocery list ready' AS status;

REVOKE ALL ON FUNCTION get_my_grocery_list() FROM PUBLIC;
REVOKE ALL ON FUNCTION save_my_grocery_list(jsonb, jsonb) FROM PUBLIC;
