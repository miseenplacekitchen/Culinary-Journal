-- Ensure is_admin() exists before RLS policies use it
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM profiles WHERE id = auth.uid() LIMIT 1),
    false
  );
$$;

-- ══════════════════════════════════════════════════════════════════════
-- Library / submitted_recipes RLS
-- Ensures approved recipes are publicly readable
-- Unapproved recipes are never exposed to the public
-- ══════════════════════════════════════════════════════════════════════

-- Confirm RLS is enabled on submitted_recipes
ALTER TABLE submitted_recipes ENABLE ROW LEVEL SECURITY;

-- Public can read approved recipes only
DROP POLICY IF EXISTS "public reads approved recipes" ON submitted_recipes;
CREATE POLICY "public reads approved recipes"
  ON submitted_recipes FOR SELECT
  USING (status = 'approved' AND visibility = 'Public');

-- Authenticated users can read their own recipes regardless of status
DROP POLICY IF EXISTS "users read own recipes" ON submitted_recipes;
CREATE POLICY "users read own recipes"
  ON submitted_recipes FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Authenticated users can insert their own recipes
DROP POLICY IF EXISTS "users insert own recipes" ON submitted_recipes;
CREATE POLICY "users insert own recipes"
  ON submitted_recipes FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- Authenticated users can update their own pending recipes
DROP POLICY IF EXISTS "users update own pending recipes" ON submitted_recipes;
CREATE POLICY "users update own pending recipes"
  ON submitted_recipes FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND status = 'pending')
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- Admins can do everything
DROP POLICY IF EXISTS "admin manages all recipes" ON submitted_recipes;
CREATE POLICY "admin manages all recipes"
  ON submitted_recipes FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

SELECT 'submitted_recipes RLS in place — approved recipes public, others private' AS status;
