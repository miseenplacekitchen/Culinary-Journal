-- ═══════════════════════════════════════════════════════════════
-- Fix: infinite recursion in submitted_recipes admin policy
--
-- The policy checked profiles.is_admin via a subquery, but
-- profiles has its own RLS policies → circular evaluation.
--
-- Fix: replace the subquery with a SECURITY DEFINER function
-- that reads profiles bypassing RLS entirely.
-- ═══════════════════════════════════════════════════════════════

-- Step 2: Recreate the admin policy using the safe function
DROP POLICY IF EXISTS "admin full access to submissions" ON submitted_recipes;
CREATE POLICY "admin full access to submissions"
  ON submitted_recipes FOR ALL TO authenticated
  USING     (is_admin())
  WITH CHECK (is_admin());

-- Step 3: Verify — should return your admin status (true for Betty)
SELECT is_admin() AS am_i_admin;
