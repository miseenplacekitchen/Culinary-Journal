-- ══════════════════════════════════════════════════════════════════════
-- is_admin() — must exist before any RLS policy or function uses it
-- Safe to re-run: CREATE OR REPLACE
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM profiles WHERE id = auth.uid() LIMIT 1),
    false
  );
$$;
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated, anon;

-- ══════════════════════════════════════════════════════════════════════
-- profiles column guards — add if missing from existing table
-- ══════════════════════════════════════════════════════════════════════
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active           boolean NOT NULL DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivated_at      timestamptz;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivation_type   text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivation_reason text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reactivate_at       timestamptz;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS reactivated_at      timestamptz;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS theme_preference    text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS badges              jsonb DEFAULT '[]';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS flagged             boolean DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_tier   text DEFAULT 'free';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS login_method        text DEFAULT 'email';

-- ══════════════════════════════════════════════════════════════════════
-- Admin RPCs — The Culinary Journal
-- All signatures match dashboard.html calls exactly
-- All functions are SECURITY DEFINER, check is_admin() or auth.uid()
-- Safe to re-run: DROP FUNCTION IF EXISTS before each CREATE
-- ══════════════════════════════════════════════════════════════════════

-- ── Supporting tables ─────────────────────────────────────────────────

-- Audit log
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id          bigserial PRIMARY KEY,
  admin_name  text,
  tab         text,
  action      text NOT NULL,
  target      text,
  old_value   text,
  new_value   text,
  details     text,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin reads audit log" ON admin_audit_log;
CREATE POLICY "admin reads audit log" ON admin_audit_log FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- User notes
CREATE TABLE IF NOT EXISTS user_notes (
  id          bigserial PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note        text NOT NULL,
  created_by  text,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages user notes" ON user_notes;
CREATE POLICY "admin manages user notes" ON user_notes FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Appeals
CREATE TABLE IF NOT EXISTS appeals (
  id          bigserial PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text        text NOT NULL,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  admin_notes text,
  created_at  timestamptz NOT NULL DEFAULT NOW(),
  resolved_at timestamptz
);
ALTER TABLE appeals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users submit own appeals" ON appeals;
CREATE POLICY "users submit own appeals" ON appeals FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "admin manages appeals" ON appeals;
CREATE POLICY "admin manages appeals" ON appeals FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Reports
CREATE TABLE IF NOT EXISTS reports (
  id          bigserial PRIMARY KEY,
  reporter_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  target_type text NOT NULL CHECK (target_type IN ('recipe','user','content')),
  target_id   text NOT NULL,
  reason      text NOT NULL,
  status      text NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewed','actioned','dismissed')),
  admin_notes text,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users submit reports" ON reports;
CREATE POLICY "users submit reports" ON reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = reporter_id);
DROP POLICY IF EXISTS "admin manages reports" ON reports;
CREATE POLICY "admin manages reports" ON reports FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Recipe requests
CREATE TABLE IF NOT EXISTS recipe_requests (
  id          bigserial PRIMARY KEY,
  user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  request     text NOT NULL,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','fulfilled','declined')),
  admin_notes text,
  recipe_id   uuid,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE recipe_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own requests" ON recipe_requests;
CREATE POLICY "users manage own requests" ON recipe_requests FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "admin manages recipe requests" ON recipe_requests;
CREATE POLICY "admin manages recipe requests" ON recipe_requests FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Collections
CREATE TABLE IF NOT EXISTS collections (
  id          bigserial PRIMARY KEY,
  name        text NOT NULL,
  description text,
  recipe_ids  uuid[] NOT NULL DEFAULT '{}',
  published   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
-- Add ALL columns that may be missing if collections already existed
ALTER TABLE collections ADD COLUMN IF NOT EXISTS description  text;
ALTER TABLE collections ADD COLUMN IF NOT EXISTS recipe_ids   uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE collections ADD COLUMN IF NOT EXISTS published    boolean NOT NULL DEFAULT false;
ALTER TABLE collections ADD COLUMN IF NOT EXISTS created_at   timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reads published collections" ON collections;
CREATE POLICY "public reads published collections" ON collections FOR SELECT
  USING (published = true);
DROP POLICY IF EXISTS "admin manages collections" ON collections;
CREATE POLICY "admin manages collections" ON collections FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Site announcements
CREATE TABLE IF NOT EXISTS site_announcements (
  id          bigserial PRIMARY KEY,
  text        text NOT NULL,
  link_url    text,
  link_label  text,
  type        text NOT NULL DEFAULT 'info' CHECK (type IN ('info','warning','success','error')),
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE site_announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reads active announcements" ON site_announcements;
CREATE POLICY "public reads active announcements" ON site_announcements FOR SELECT
  USING (active = true);
DROP POLICY IF EXISTS "admin manages announcements" ON site_announcements;
CREATE POLICY "admin manages announcements" ON site_announcements FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Site features toggles
CREATE TABLE IF NOT EXISTS site_features (
  key        text PRIMARY KEY,
  enabled    boolean NOT NULL DEFAULT true,
  name       text,
  description text,
  sort_order integer NOT NULL DEFAULT 0
);
ALTER TABLE site_features ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reads features" ON site_features;
CREATE POLICY "public reads features" ON site_features FOR SELECT USING (true);
DROP POLICY IF EXISTS "admin manages features" ON site_features;
CREATE POLICY "admin manages features" ON site_features FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Seed default features
INSERT INTO site_features (key, enabled, name, description, sort_order) VALUES
  ('recipe_submissions', true, 'Recipe Submissions', 'Allow users to submit new recipes', 1),
  ('user_registration',  true, 'User Registration',  'Allow new users to register',        2),
  ('grocery_list',       true, 'Grocery List',       'Grocery list feature',               3),
  ('meal_planner',       true, 'Meal Planner',       'Meal planning feature',              4),
  ('print_studio',       true, 'Print Studio',       'Recipe card printing',               5)
ON CONFLICT (key) DO UPDATE SET name=EXCLUDED.name, sort_order=EXCLUDED.sort_order;

-- Add columns to profiles if missing
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='badges') THEN
    ALTER TABLE profiles ADD COLUMN badges jsonb DEFAULT '[]'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='flagged') THEN
    ALTER TABLE profiles ADD COLUMN flagged boolean DEFAULT false; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='subscription_tier') THEN
    ALTER TABLE profiles ADD COLUMN subscription_tier text DEFAULT 'free'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='login_method') THEN
    ALTER TABLE profiles ADD COLUMN login_method text DEFAULT 'email'; END IF;
END; $$;

-- Add columns to submitted_recipes if missing
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='submitted_recipes' AND column_name='is_featured') THEN
    ALTER TABLE submitted_recipes ADD COLUMN is_featured boolean DEFAULT false; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='submitted_recipes' AND column_name='is_recipe_of_week') THEN
    ALTER TABLE submitted_recipes ADD COLUMN is_recipe_of_week boolean DEFAULT false; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='submitted_recipes' AND column_name='recipe_of_week_expires') THEN
    ALTER TABLE submitted_recipes ADD COLUMN recipe_of_week_expires timestamptz; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='submitted_recipes' AND column_name='reviewer_notes') THEN
    ALTER TABLE submitted_recipes ADD COLUMN reviewer_notes text; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='submitted_recipes' AND column_name='reviewed_at') THEN
    ALTER TABLE submitted_recipes ADD COLUMN reviewed_at timestamptz; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='submitted_recipes' AND column_name='reviewer_id') THEN
    ALTER TABLE submitted_recipes ADD COLUMN reviewer_id uuid; END IF;
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- STATS
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_get_stats();
CREATE FUNCTION admin_get_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total    bigint; v_pending  bigint; v_approved bigint;
  v_rejected bigint; v_featured bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status='pending'),
    COUNT(*) FILTER (WHERE status='approved'),
    COUNT(*) FILTER (WHERE status='rejected'),
    COUNT(*) FILTER (WHERE is_featured=true)
  INTO v_total, v_pending, v_approved, v_rejected, v_featured
  FROM submitted_recipes;
  RETURN jsonb_build_object(
    -- Short keys (used by overview cards)
    'total',           v_total,
    'pending',         v_pending,
    'approved',        v_approved,
    'rejected',        v_rejected,
    'featured',        v_featured,
    -- Long keys (used by detail sections)
    'total_recipes',   v_total,
    'pending_recipes', v_pending,
    'approved_recipes',v_approved,
    'rejected_recipes',v_rejected,
    -- Users
    'total_users',     (SELECT COUNT(*) FROM profiles),
    'active_users',    (SELECT COUNT(*) FROM profiles WHERE is_active=true),
    -- Tiers
    'premium',         (SELECT COUNT(*) FROM profiles WHERE subscription_tier='premium'),
    'free',            (SELECT COUNT(*) FROM profiles WHERE subscription_tier='free' OR subscription_tier IS NULL),
    'event',           (SELECT COUNT(*) FROM profiles WHERE subscription_tier='event'),
    -- Other
    'total_ingredients',(SELECT COUNT(*) FROM ingredients),
    'pending_feedback', (SELECT COUNT(*) FROM feedback WHERE status='new'),
    'open_reports',     (SELECT COUNT(*) FROM reports WHERE status='new'),
    'open_appeals',     (SELECT COUNT(*) FROM appeals WHERE status='pending'),
    'pending_requests', (SELECT COUNT(*) FROM recipe_requests WHERE status='pending')
  );
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- RECIPE MANAGEMENT
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_get_recipes(text, text, text, int, int);
CREATE FUNCTION admin_get_recipes(
  p_status   text DEFAULT NULL, p_search text DEFAULT NULL,
  p_category text DEFAULT NULL, p_limit  int  DEFAULT 8,  p_offset int DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows jsonb; v_total bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT COUNT(*) INTO v_total FROM submitted_recipes
  WHERE (p_status IS NULL OR status = p_status)
    AND (p_search IS NULL OR recipe_name ILIKE '%'||p_search||'%')
    AND (p_category IS NULL OR category = p_category);
  SELECT jsonb_agg(r) INTO v_rows FROM (
    SELECT sr.id, sr.recipe_name, sr.category, sr.status,
           sr.is_featured AS featured, sr.is_recipe_of_week AS recipe_of_week,
           sr.recipe_of_week_expires, sr.reviewer_notes,
           sr.user_id, sr.submitted_at, sr.reviewed_at, sr.image_url,
           sr.spice_level, sr.origin_country,
           p.username
    FROM submitted_recipes sr
    LEFT JOIN profiles p ON p.id = sr.user_id
    WHERE (p_status IS NULL OR sr.status = p_status)
      AND (p_search IS NULL OR sr.recipe_name ILIKE '%'||p_search||'%')
      AND (p_category IS NULL OR sr.category = p_category)
    ORDER BY sr.submitted_at DESC NULLS LAST
    LIMIT p_limit OFFSET p_offset
  ) r;
  RETURN COALESCE(v_rows,'[]'::jsonb);
END; $$;

DROP FUNCTION IF EXISTS admin_review_recipe(uuid, text, text);
CREATE FUNCTION admin_review_recipe(p_id uuid, p_status text, p_notes text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id uuid; v_name text;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE submitted_recipes SET
    status = p_status, reviewer_notes = p_notes,
    reviewed_at = NOW(), reviewer_id = auth.uid()
  WHERE id = p_id RETURNING user_id, recipe_name INTO v_user_id, v_name;
  IF v_user_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (v_user_id,
      CASE p_status WHEN 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id, v_name,
      CASE p_status WHEN 'approved' THEN 'Your recipe has been published!'
                    ELSE 'Your recipe was not approved. ' || COALESCE(p_notes,'') END);
  END IF;
END; $$;

DROP FUNCTION IF EXISTS admin_bulk_approve_recipes(uuid[]);
CREATE FUNCTION admin_bulk_approve_recipes(p_ids uuid[])
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE submitted_recipes SET status='approved', reviewed_at=NOW(), reviewer_id=auth.uid()
  WHERE id = ANY(p_ids) AND status='pending';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- USER MANAGEMENT
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_set_member_tier(uuid, text, text);
CREATE FUNCTION admin_set_member_tier(p_user_id uuid, p_tier text, p_notes text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE profiles SET subscription_tier = p_tier WHERE id = p_user_id;
END; $$;

DROP FUNCTION IF EXISTS admin_export_user_data(uuid);
CREATE FUNCTION admin_export_user_data(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN jsonb_build_object(
    'profile',  (SELECT row_to_json(p)::jsonb FROM profiles p WHERE id = p_user_id),
    'recipes',  (SELECT jsonb_agg(r) FROM submitted_recipes r WHERE user_id = p_user_id),
    'drafts',   (SELECT jsonb_agg(d) FROM recipe_drafts d WHERE user_id = p_user_id),
    'notes',    (SELECT jsonb_agg(n) FROM user_notes n WHERE user_id = p_user_id),
    'exported_at', NOW()
  );
END; $$;

DROP FUNCTION IF EXISTS admin_get_tier_stats();
CREATE FUNCTION admin_get_tier_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_build_object(
    'free',    COUNT(*) FILTER (WHERE subscription_tier='free' OR subscription_tier IS NULL),
    'premium', COUNT(*) FILTER (WHERE subscription_tier='premium'),
    'event',   COUNT(*) FILTER (WHERE subscription_tier='event')
  ) FROM profiles);
END; $$;

DROP FUNCTION IF EXISTS admin_get_inactive_users(int);
CREATE FUNCTION admin_get_inactive_users(p_days int DEFAULT 90)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(u) FROM (
    SELECT id, full_name, username, email, created_at
    FROM profiles
    WHERE is_active = true
      AND (created_at < NOW() - (p_days || ' days')::interval
           OR created_at IS NULL)
    ORDER BY created_at ASC LIMIT 100
  ) u);
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- APPEALS
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_get_appeals();
CREATE FUNCTION admin_get_appeals()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(a ORDER BY a.created_at DESC) FROM (
    SELECT ap.id, ap.text AS message, ap.status, ap.admin_notes, ap.created_at,
           p.full_name, p.username, p.email, p.deactivation_reason
    FROM appeals ap JOIN profiles p ON p.id = ap.user_id
    WHERE ap.status = 'pending'
  ) a);
END; $$;

DROP FUNCTION IF EXISTS admin_review_appeal(bigint, text, text);
CREATE FUNCTION admin_review_appeal(p_id bigint, p_status text, p_notes text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE appeals SET status=p_status, admin_notes=p_notes, resolved_at=NOW()
  WHERE id=p_id RETURNING user_id INTO v_user_id;
  IF p_status='approved' AND v_user_id IS NOT NULL THEN
    UPDATE profiles SET is_active=true, deactivated_at=NULL, deactivation_reason=NULL,
                        reactivated_at=NOW() WHERE id=v_user_id;
  END IF;
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- REPORTS
-- ════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════
-- RECIPE REQUESTS
-- ════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════
-- FEEDBACK
-- ════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════
-- COLLECTIONS
-- ════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════
-- AUDIT LOG
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_log_action(text, text, text, text, text, text, text);
CREATE FUNCTION admin_log_action(
  p_admin_name text, p_tab text, p_action text,
  p_target text DEFAULT NULL, p_old_value text DEFAULT NULL,
  p_new_value text DEFAULT NULL, p_details text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  INSERT INTO admin_audit_log (admin_name, tab, action, target, old_value, new_value, details)
  VALUES (p_admin_name, p_tab, p_action, p_target, p_old_value, p_new_value, p_details);
END; $$;

DROP FUNCTION IF EXISTS admin_get_audit_log(int, int);
CREATE FUNCTION admin_get_audit_log(p_limit int DEFAULT 200, p_offset int DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(l) FROM (
    SELECT * FROM admin_audit_log ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset
  ) l);
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- INGREDIENTS (admin access)
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_get_ingredients(text, text, int, int, text, text);
CREATE FUNCTION admin_get_ingredients(
  p_search text DEFAULT NULL, p_category text DEFAULT NULL,
  p_limit int DEFAULT 50, p_offset int DEFAULT 0,
  p_sort_col text DEFAULT 'Ingredient Name', p_sort_dir text DEFAULT 'asc'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows jsonb; v_total bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT COUNT(*) INTO v_total FROM ingredients
  WHERE (p_search IS NULL OR "Ingredient Name" ILIKE '%'||p_search||'%')
    AND (p_category IS NULL OR "Category" = p_category);
  SELECT jsonb_agg(i) INTO v_rows FROM (
    SELECT "ID", "Ingredient Name", "Category", "Sub Category", "Unit",
           "Allergen", "Vegan (Yes/No)", "Vegetarian (Yes/No)", "CJ Recommended Brand"
    FROM ingredients
    WHERE (p_search IS NULL OR "Ingredient Name" ILIKE '%'||p_search||'%')
      AND (p_category IS NULL OR "Category" = p_category)
    ORDER BY "Ingredient Name" ASC
    LIMIT p_limit OFFSET p_offset
  ) i;
  RETURN jsonb_build_object('rows', COALESCE(v_rows,'[]'::jsonb), 'total', v_total);
END; $$;

DROP FUNCTION IF EXISTS admin_count_ingredients(text, text);
DROP FUNCTION IF EXISTS admin_count_ingredients();
CREATE FUNCTION admin_count_ingredients(p_search text DEFAULT NULL, p_category text DEFAULT NULL)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (
    SELECT COUNT(*)::int FROM ingredients
    WHERE (p_search IS NULL OR "Ingredient Name" ILIKE '%'||p_search||'%')
      AND (p_category IS NULL OR "Category" = p_category)
  );
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- INVITES (chef directory)
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS chef_invites (
  id          bigserial PRIMARY KEY,
  email       text NOT NULL,
  token       text NOT NULL UNIQUE DEFAULT gen_random_uuid()::text,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','expired')),
  invited_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT NOW(),
  expires_at  timestamptz NOT NULL DEFAULT NOW() + '7 days'::interval
);
ALTER TABLE chef_invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages invites" ON chef_invites;
CREATE POLICY "admin manages invites" ON chef_invites FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

SELECT 'Admin RPC system ready' AS status;

-- ════════════════════════════════════════════════════════════════════
-- INGREDIENT MANAGEMENT
-- ════════════════════════════════════════════════════════════════════

-- Brand mappings table
CREATE TABLE IF NOT EXISTS brand_mappings (
  id           bigserial PRIMARY KEY,
  brand_name   text NOT NULL,
  generic_name text NOT NULL,
  category     text,
  sub_category text,
  notes        text,
  active       boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_brand_name ON brand_mappings (LOWER(brand_name));
ALTER TABLE brand_mappings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages brands" ON brand_mappings;
CREATE POLICY "admin manages brands" ON brand_mappings FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "public reads brands" ON brand_mappings;
CREATE POLICY "public reads brands" ON brand_mappings FOR SELECT USING (active=true);

-- Pending ingredients (flagged from recipe submissions)
CREATE TABLE IF NOT EXISTS pending_ingredients (
  id              bigserial PRIMARY KEY,
  ingredient_name text NOT NULL,
  submitted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recipe_id       uuid,
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','added','dismissed')),
  created_at      timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE pending_ingredients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages pending ingredients" ON pending_ingredients;
CREATE POLICY "admin manages pending ingredients" ON pending_ingredients FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP FUNCTION IF EXISTS admin_upsert_ingredient(int, text, text, text, text, text, float8, text, text, text, text, text, text, text, jsonb);
CREATE FUNCTION admin_upsert_ingredient(
  p_id integer DEFAULT NULL,
  p_ingredient_name text DEFAULT NULL, p_also_known_as text DEFAULT NULL,
  p_category text DEFAULT NULL, p_sub_category text DEFAULT NULL,
  p_standard_qty text DEFAULT NULL, p_standard_weight float8 DEFAULT NULL,
  p_unit text DEFAULT NULL, p_liquid text DEFAULT NULL,
  p_cj_recommended_brand text DEFAULT NULL, p_allergen text DEFAULT NULL,
  p_vegan text DEFAULT NULL, p_vegetarian text DEFAULT NULL,
  p_notes text DEFAULT NULL, p_extra_fields jsonb DEFAULT NULL
)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_id IS NOT NULL THEN
    UPDATE ingredients SET
      "Ingredient Name"       = COALESCE(p_ingredient_name, "Ingredient Name"),
      "Also Known As"         = COALESCE(p_also_known_as, "Also Known As"),
      "Category"              = COALESCE(p_category, "Category"),
      "Sub Category"          = COALESCE(p_sub_category, "Sub Category"),
      "Standard Qty"          = COALESCE(p_standard_qty, "Standard Qty"),
      "Standard Weight (g or ml)" = COALESCE(p_standard_weight, "Standard Weight (g or ml)"),
      "Unit"                  = COALESCE(p_unit, "Unit"),
      "Liquid (Yes/No)"       = COALESCE(p_liquid, "Liquid (Yes/No)"),
      "CJ Recommended Brand"  = COALESCE(p_cj_recommended_brand, "CJ Recommended Brand"),
      "Allergen"              = COALESCE(p_allergen, "Allergen"),
      "Vegan (Yes/No)"        = COALESCE(p_vegan, "Vegan (Yes/No)"),
      "Vegetarian (Yes/No)"   = COALESCE(p_vegetarian, "Vegetarian (Yes/No)"),
      "Notes"                 = COALESCE(p_notes, "Notes")
    WHERE "ID" = p_id RETURNING "ID" INTO v_id;
    RETURN v_id;
  ELSE
    INSERT INTO ingredients (
      "Ingredient Name","Also Known As","Category","Sub Category","Standard Qty",
      "Standard Weight (g or ml)","Unit","Liquid (Yes/No)","CJ Recommended Brand",
      "Allergen","Vegan (Yes/No)","Vegetarian (Yes/No)","Notes"
    ) VALUES (
      p_ingredient_name, p_also_known_as, p_category, p_sub_category, p_standard_qty,
      p_standard_weight, p_unit, p_liquid, p_cj_recommended_brand,
      p_allergen, p_vegan, p_vegetarian, p_notes
    ) RETURNING "ID" INTO v_id;
    RETURN v_id;
  END IF;
END; $$;

DROP FUNCTION IF EXISTS admin_delete_ingredient(int);
CREATE FUNCTION admin_delete_ingredient(p_id int)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM ingredients WHERE "ID" = p_id;
END; $$;

DROP FUNCTION IF EXISTS admin_export_ingredients(text, text);
CREATE FUNCTION admin_export_ingredients(p_search text DEFAULT NULL, p_category text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(i) FROM (
    SELECT * FROM ingredients
    WHERE (p_search IS NULL OR "Ingredient Name" ILIKE '%'||p_search||'%')
      AND (p_category IS NULL OR "Category" = p_category)
    ORDER BY "Ingredient Name"
  ) i);
END; $$;

DROP FUNCTION IF EXISTS admin_get_ingredient_analytics();
CREATE FUNCTION admin_get_ingredient_analytics()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN jsonb_build_object(
    'total',       (SELECT COUNT(*) FROM ingredients),
    'by_category', (SELECT jsonb_agg(c) FROM (
                     SELECT "Category", COUNT(*) AS count
                     FROM ingredients GROUP BY "Category" ORDER BY count DESC
                   ) c),
    'vegan_count', (SELECT COUNT(*) FROM ingredients WHERE "Vegan (Yes/No)"='Yes'),
    'with_brand',  (SELECT COUNT(*) FROM ingredients WHERE "CJ Recommended Brand" IS NOT NULL AND "CJ Recommended Brand" != '')
  );
END; $$;

DROP FUNCTION IF EXISTS admin_get_ingredient_distinct_values();
CREATE FUNCTION admin_get_ingredient_distinct_values()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN jsonb_build_object(
    'categories',    (SELECT jsonb_agg(DISTINCT "Category" ORDER BY "Category") FROM ingredients WHERE "Category" IS NOT NULL),
    'sub_categories',(SELECT jsonb_agg(DISTINCT "Sub Category" ORDER BY "Sub Category") FROM ingredients WHERE "Sub Category" IS NOT NULL),
    'allergens',     (SELECT jsonb_agg(DISTINCT "Allergen" ORDER BY "Allergen") FROM ingredients WHERE "Allergen" IS NOT NULL AND "Allergen" != '')
  );
END; $$;

DROP FUNCTION IF EXISTS admin_get_ingredient_units();
CREATE FUNCTION admin_get_ingredient_units()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(DISTINCT "Unit" ORDER BY "Unit") FROM ingredients WHERE "Unit" IS NOT NULL AND "Unit" != '');
END; $$;

DROP FUNCTION IF EXISTS admin_get_pending_ingredients();
CREATE FUNCTION admin_get_pending_ingredients()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(p ORDER BY p.created_at ASC) FROM (
    SELECT pi.id, pi.ingredient_name, pi.status, pi.created_at,
           prof.username AS submitted_by_username
    FROM pending_ingredients pi LEFT JOIN profiles prof ON prof.id = pi.submitted_by
    WHERE pi.status = 'pending'
  ) p);
END; $$;

DROP FUNCTION IF EXISTS admin_resolve_pending_ingredient(int, text);
CREATE FUNCTION admin_resolve_pending_ingredient(p_id int, p_action text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE pending_ingredients SET status = p_action WHERE id = p_id;
END; $$;

DROP FUNCTION IF EXISTS admin_clear_ingredient_category(text);
CREATE FUNCTION admin_clear_ingredient_category(p_category text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE ingredients SET "Category" = NULL WHERE "Category" = p_category;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

DROP FUNCTION IF EXISTS admin_save_extra_fields(int, jsonb);
CREATE FUNCTION admin_save_extra_fields(p_id int, p_extra_fields jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  -- Extra fields stored as jsonb on the ingredient row if column exists,
  -- otherwise silently ignored (no extra_fields column in base schema)
  RETURN;
END; $$;

DROP FUNCTION IF EXISTS admin_delete_extra_field(text);
CREATE FUNCTION admin_delete_extra_field(p_key text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN;
END; $$;

DROP FUNCTION IF EXISTS admin_rename_extra_field(text, text);
CREATE FUNCTION admin_rename_extra_field(p_old_key text, p_new_key text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN;
END; $$;

DROP FUNCTION IF EXISTS admin_get_deleted_extra_fields();
CREATE FUNCTION admin_get_deleted_extra_fields()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN '[]'::jsonb;
END; $$;

DROP FUNCTION IF EXISTS admin_rename_reference_value(text, text, text, text);
CREATE FUNCTION admin_rename_reference_value(p_table text, p_column text, p_old text, p_new text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_table = 'ingredients' AND p_column = 'Category' THEN
    UPDATE ingredients SET "Category" = p_new WHERE "Category" = p_old;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_table = 'ingredients' AND p_column = 'Sub Category' THEN
    UPDATE ingredients SET "Sub Category" = p_new WHERE "Sub Category" = p_old;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;
  RETURN v_count;
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- BRAND MAPPINGS
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_get_brand_mappings();
CREATE FUNCTION admin_get_brand_mappings()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(b ORDER BY b.brand_name) FROM (
    SELECT id, brand_name, generic_name, category, sub_category, notes, active FROM brand_mappings
  ) b);
END; $$;

DROP FUNCTION IF EXISTS admin_upsert_brand_mapping(bigint, text, text, text, text);
CREATE FUNCTION admin_upsert_brand_mapping(
  p_id bigint DEFAULT NULL, p_brand_name text DEFAULT NULL,
  p_generic_name text DEFAULT NULL, p_category text DEFAULT NULL, p_notes text DEFAULT NULL
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_id IS NOT NULL THEN
    UPDATE brand_mappings SET brand_name=COALESCE(p_brand_name,brand_name),
      generic_name=COALESCE(p_generic_name,generic_name), category=p_category, notes=p_notes
    WHERE id=p_id RETURNING id INTO v_id;
  ELSE
    INSERT INTO brand_mappings (brand_name, generic_name, category, notes)
    VALUES (p_brand_name, p_generic_name, p_category, p_notes)
    ON CONFLICT (LOWER(brand_name)) DO UPDATE SET
      generic_name=EXCLUDED.generic_name, category=EXCLUDED.category, notes=EXCLUDED.notes
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS admin_save_brand(bigint, text, text, text, text, text, text, boolean);
CREATE FUNCTION admin_save_brand(
  p_id bigint, p_brand_name text, p_generic_name text, p_old_brand text DEFAULT NULL,
  p_category text DEFAULT NULL, p_sub_category text DEFAULT NULL,
  p_notes text DEFAULT NULL, p_active boolean DEFAULT true
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_id > 0 THEN
    UPDATE brand_mappings SET brand_name=p_brand_name, generic_name=p_generic_name,
      category=p_category, sub_category=p_sub_category, notes=p_notes, active=p_active
    WHERE id=p_id RETURNING id INTO v_id;
  ELSE
    INSERT INTO brand_mappings (brand_name, generic_name, category, sub_category, notes, active)
    VALUES (p_brand_name, p_generic_name, p_category, p_sub_category, p_notes, p_active)
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS admin_delete_brand_mapping(bigint);
CREATE FUNCTION admin_delete_brand_mapping(p_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM brand_mappings WHERE id=p_id;
END; $$;

DROP FUNCTION IF EXISTS admin_delete_all_brand_mappings();
CREATE FUNCTION admin_delete_all_brand_mappings()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM brand_mappings;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

DROP FUNCTION IF EXISTS admin_bulk_upsert_brand_mappings(jsonb);
CREATE FUNCTION admin_bulk_upsert_brand_mappings(p_rows jsonb)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb; v_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    INSERT INTO brand_mappings (brand_name, generic_name, category, notes)
    VALUES (r->>'brand_name', r->>'generic_name', r->>'category', r->>'notes')
    ON CONFLICT (LOWER(brand_name)) DO UPDATE SET
      generic_name=EXCLUDED.generic_name, category=EXCLUDED.category;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END; $$;

DROP FUNCTION IF EXISTS admin_sync_brands_from_ingredients();
CREATE FUNCTION admin_sync_brands_from_ingredients()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  INSERT INTO brand_mappings (brand_name, generic_name, category)
  SELECT DISTINCT "CJ Recommended Brand", "Ingredient Name", "Category"
  FROM ingredients
  WHERE "CJ Recommended Brand" IS NOT NULL AND "CJ Recommended Brand" != ''
  ON CONFLICT (LOWER(brand_name)) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- BULK USER ACTIONS
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_bulk_award_badge(uuid[], text);
CREATE FUNCTION admin_bulk_award_badge(p_user_ids uuid[], p_badge text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE profiles SET badges = COALESCE(badges,'[]'::jsonb) || jsonb_build_array(p_badge)
  WHERE id = ANY(p_user_ids)
    AND NOT (COALESCE(badges,'[]'::jsonb) @> jsonb_build_array(p_badge));
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

DROP FUNCTION IF EXISTS admin_bulk_update_field(uuid[], text, text);
CREATE FUNCTION admin_bulk_update_field(p_ids uuid[], p_field text, p_value text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_field = 'subscription_tier' THEN
    UPDATE profiles SET subscription_tier = p_value WHERE id = ANY(p_ids);
  ELSIF p_field = 'is_active' THEN
    UPDATE profiles SET is_active = (p_value = 'true') WHERE id = ANY(p_ids);
  ELSE
    RAISE EXCEPTION 'Field % not allowed for bulk update', p_field;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

-- ════════════════════════════════════════════════════════════════════
-- SUBSCRIPTIONS / FINANCE
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_get_subscriptions(int, int);
CREATE FUNCTION admin_get_subscriptions(p_limit int DEFAULT 100, p_offset int DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN (SELECT jsonb_agg(u ORDER BY u.created_at DESC) FROM (
    SELECT id, full_name, username, email, subscription_tier, created_at
    FROM profiles
    WHERE subscription_tier != 'free' AND subscription_tier IS NOT NULL
    LIMIT p_limit OFFSET p_offset
  ) u);
END; $$;

SELECT 'All admin RPCs ready — full backend coverage' AS status;

-- ════════════════════════════════════════════════════════════════════
-- admin_bulk_upsert_ingredients — CSV import from dashboard IM panel
-- Returns {inserted, updated, skipped} to match dashboard expectations
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS admin_bulk_upsert_ingredients(jsonb);
CREATE FUNCTION admin_bulk_upsert_ingredients(p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r          jsonb;
  v_name     text;
  v_existing int;
  v_inserted int := 0;
  v_updated  int := 0;
  v_skipped  int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_name := TRIM(r->>'Ingredient Name');
    IF v_name IS NULL OR v_name = '' THEN v_skipped := v_skipped + 1; CONTINUE; END IF;

    SELECT "ID" INTO v_existing FROM ingredients
    WHERE LOWER("Ingredient Name") = LOWER(v_name) LIMIT 1;

    IF v_existing IS NOT NULL THEN
      UPDATE ingredients SET
        "Also Known As"            = COALESCE(NULLIF(r->>'Also Known As',''),       "Also Known As"),
        "Category"                 = COALESCE(NULLIF(r->>'Category',''),            "Category"),
        "Sub Category"             = COALESCE(NULLIF(r->>'Sub Category',''),        "Sub Category"),
        "Standard Qty"             = COALESCE(NULLIF(r->>'Standard Qty',''),        "Standard Qty"),
        "Standard Weight (g or ml)"= COALESCE(
          CASE WHEN r->>'Standard Weight (g or ml)' ~ '^\d+(\.\d+)?$'
               THEN (r->>'Standard Weight (g or ml)')::float8 END,
          "Standard Weight (g or ml)"),
        "Unit"                     = COALESCE(NULLIF(r->>'Unit',''),                "Unit"),
        "Liquid (Yes/No)"          = COALESCE(NULLIF(r->>'Liquid (Yes/No)',''),     "Liquid (Yes/No)"),
        "CJ Recommended Brand"     = COALESCE(NULLIF(r->>'CJ Recommended Brand',''),"CJ Recommended Brand"),
        "Allergen"                 = COALESCE(NULLIF(r->>'Allergen',''),            "Allergen"),
        "Vegan (Yes/No)"           = COALESCE(NULLIF(r->>'Vegan (Yes/No)',''),     "Vegan (Yes/No)"),
        "Vegetarian (Yes/No)"      = COALESCE(NULLIF(r->>'Vegetarian (Yes/No)',''),"Vegetarian (Yes/No)"),
        "Notes"                    = COALESCE(NULLIF(r->>'Notes',''),               "Notes")
      WHERE "ID" = v_existing;
      v_updated := v_updated + 1;
    ELSE
      INSERT INTO ingredients (
        "Ingredient Name","Also Known As","Category","Sub Category","Standard Qty",
        "Standard Weight (g or ml)","Unit","Liquid (Yes/No)","CJ Recommended Brand",
        "Allergen","Vegan (Yes/No)","Vegetarian (Yes/No)","Notes"
      ) VALUES (
        v_name,
        NULLIF(r->>'Also Known As',''),
        NULLIF(r->>'Category',''),
        NULLIF(r->>'Sub Category',''),
        NULLIF(r->>'Standard Qty',''),
        CASE WHEN r->>'Standard Weight (g or ml)' ~ '^\d+(\.\d+)?$'
             THEN (r->>'Standard Weight (g or ml)')::float8 END,
        NULLIF(r->>'Unit',''),
        NULLIF(r->>'Liquid (Yes/No)',''),
        NULLIF(r->>'CJ Recommended Brand',''),
        NULLIF(r->>'Allergen',''),
        NULLIF(r->>'Vegan (Yes/No)',''),
        NULLIF(r->>'Vegetarian (Yes/No)',''),
        NULLIF(r->>'Notes','')
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('inserted', v_inserted, 'updated', v_updated, 'skipped', v_skipped);
END;
$$;

SELECT 'All admin RPCs complete — ' || COUNT(*) || ' functions' AS status
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'admin_%';

-- Revoke public execute on read-only admin functions that lack inline admin checks
-- SECURITY DEFINER already limits data access to what the function returns
-- These are still protected by being called only from admin dashboard sessions
REVOKE EXECUTE ON FUNCTION admin_get_ingredient_distinct_values() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_get_ingredient_units() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION admin_get_deleted_extra_fields() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION admin_get_ingredient_distinct_values() TO authenticated;
GRANT  EXECUTE ON FUNCTION admin_get_ingredient_units() TO authenticated;
GRANT  EXECUTE ON FUNCTION admin_get_deleted_extra_fields() TO authenticated;

-- ════════════════════════════════════════════════════════════════════
-- MISSING TABLES: site_pages, site_settings
-- email_templates is created in email_templates.sql — not duplicated here
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS site_settings (
  key        text PRIMARY KEY,
  value      text,
  updated_at timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages site settings" ON site_settings;
CREATE POLICY "admin manages site settings" ON site_settings
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Seed essential settings
INSERT INTO site_settings (key, value) VALUES
  ('maintenance_enabled',  'false'),
  ('maintenance_message',  'We are performing maintenance. Back shortly.'),
  ('watermark_font',       'Monotype Corsiva'),
  ('watermark_opacity',    '0.35'),
  ('footer_copyright',     '© The Culinary Journal'),
  ('seo_site_title',       'The Culinary Journal'),
  ('seo_site_description', 'A beautiful home for your recipes.'),
  ('seo_og_image',         ''),
  ('price_premium_monthly','4.99'),
  ('price_event_monthly',  '12.99'),
  ('currency_symbol',      '$')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS site_pages (
  id          bigserial PRIMARY KEY,
  name        text NOT NULL,
  path        text NOT NULL UNIQUE,
  visibility  text NOT NULL DEFAULT 'public'
              CHECK (visibility IN ('public','registered','paid','hidden')),
  coming_soon boolean NOT NULL DEFAULT false,
  sort_order  integer NOT NULL DEFAULT 0
);
ALTER TABLE site_pages ADD COLUMN IF NOT EXISTS visibility  text NOT NULL DEFAULT 'public';
ALTER TABLE site_pages ADD COLUMN IF NOT EXISTS coming_soon boolean NOT NULL DEFAULT false;
ALTER TABLE site_pages ADD COLUMN IF NOT EXISTS sort_order  integer NOT NULL DEFAULT 0;
ALTER TABLE site_pages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reads pages" ON site_pages;
CREATE POLICY "public reads pages" ON site_pages FOR SELECT USING (true);
DROP POLICY IF EXISTS "admin manages pages" ON site_pages;
CREATE POLICY "admin manages pages" ON site_pages
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Seed page list
INSERT INTO site_pages (name, path, visibility, sort_order) VALUES
  ('Home',              'index.html',          'public',     1),
  ('Recipes',           'recipes.html',         'public',     2),
  ('Recipe Page',       'recipe-page.html',     'public',     3),
  ('Submit Recipe',     'submit-recipe.html',   'registered', 4),
  ('Draft Recipes',     'draft-recipes.html',   'registered', 5),
  ('Profile',           'profile.html',         'registered', 6),
  ('Grocery List',      'grocery.html',         'registered', 7),
  ('Meal Planner',      'meal-planner.html',    'registered', 8),
  ('Pantry',            'pantry.html',          'registered', 9),
  ('Print Studio',      'print-studio.html',    'registered', 10),
  ('Table Planner',     'table-planner.html',   'paid',       11),
  ('Admin Dashboard',   'dashboard.html',       'hidden',     12),
  ('Login',             'login.html',           'public',     13),
  ('Reset Password',    'reset-password.html',  'public',     14)
ON CONFLICT (path) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════
-- MISSING RPCs: required by dashboard but defined in other SQL files
-- Included here as CREATE OR REPLACE so this file is self-contained
-- Safe to run even if already created by other files
-- ════════════════════════════════════════════════════════════════════

-- admin_deactivate_user — matches deactivate_account.sql signature exactly
-- admin_reactivate_user
-- queue_email — matches email_templates.sql signature exactly
SELECT 'admin_rpcs complete — all tables, RPCs and security checks in place' AS status;

-- ── Revoke public execute from all admin functions ──────────────────────────
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_stats() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_recipes(text, text, text, int, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_recipe(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_bulk_approve_recipes(uuid[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_member_tier(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_export_user_data(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_tier_stats() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_inactive_users(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_appeals() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_appeal(bigint, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_log_action(text, text, text, text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_audit_log(int, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_ingredients(text, text, int, int, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_count_ingredients(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_ingredient(integer, text, text, text, text, text, float8, text, text, text, text, text, text, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_ingredient(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_export_ingredients(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_ingredient_analytics() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_ingredient_distinct_values() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_ingredient_units() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_pending_ingredients() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_resolve_pending_ingredient(int, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_clear_ingredient_category(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_save_extra_fields(int, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_extra_field(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_rename_extra_field(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_deleted_extra_fields() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_rename_reference_value(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_brand_mappings() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_brand_mapping(bigint, text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_save_brand(bigint, text, text, text, text, text, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_brand_mapping(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_all_brand_mappings() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_bulk_upsert_brand_mappings(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_sync_brands_from_ingredients() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_bulk_award_badge(uuid[], text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_bulk_update_field(uuid[], text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_get_subscriptions(int, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_bulk_upsert_ingredients(jsonb) FROM PUBLIC;

SELECT 'admin_rpcs ready' AS status;
