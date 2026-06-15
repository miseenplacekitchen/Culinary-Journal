-- ══════════════════════════════════════════════════════════════════════
-- fix-phase21-batch.sql — Page tiers + billing periods + member tiers
-- Safe to re-run. Run in Supabase SQL editor after prior phase batches.
-- ══════════════════════════════════════════════════════════════════════

-- site_pages: minimum subscription tier when visibility = paid (or registered+gate)
ALTER TABLE public.site_pages
  ADD COLUMN IF NOT EXISTS min_tier text NOT NULL DEFAULT 'free';

DO $$ BEGIN
  ALTER TABLE public.site_pages
    ADD CONSTRAINT site_pages_min_tier_check
    CHECK (min_tier IN ('free','daily','weekly','monthly','yearly','premium','event'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- site_features: optional tier gate per feature toggle
ALTER TABLE public.site_features
  ADD COLUMN IF NOT EXISTS min_tier text NOT NULL DEFAULT 'free';

-- Policy text (admin-editable via Site Management → Settings)
INSERT INTO public.site_settings (key, value) VALUES
  ('refund_policy',
   'All subscription payments are final. We do not offer refunds. By subscribing you agree to this policy.'),
  ('billing_no_refunds_banner',
   'No refunds — all sales are final. Cancel anytime; access continues until period end.'),
  ('price_daily',  '0.99'),
  ('price_weekly', '2.99'),
  ('price_yearly', '40.00')
ON CONFLICT (key) DO NOTHING;

-- Extend admin_update_site_page with min_tier
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'admin_update_site_page'
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_update_site_page(
  p_path        text DEFAULT NULL,
  p_visibility  text DEFAULT NULL,
  p_meta_title  text DEFAULT NULL,
  p_meta_desc   text DEFAULT NULL,
  p_coming_soon boolean DEFAULT NULL,
  p_min_tier    text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  IF p_path IS NULL OR btrim(p_path) = '' THEN
    RAISE EXCEPTION 'p_path must not be null or empty';
  END IF;
  IF p_min_tier IS NOT NULL AND p_min_tier NOT IN ('free','daily','weekly','monthly','yearly','premium','event') THEN
    RAISE EXCEPTION 'invalid min_tier';
  END IF;

  INSERT INTO public.site_pages (path, name, visibility, meta_title, meta_desc, coming_soon, min_tier, updated_at)
  VALUES (
    btrim(p_path),
    btrim(p_path),
    COALESCE(p_visibility, 'public'),
    p_meta_title,
    p_meta_desc,
    COALESCE(p_coming_soon, false),
    COALESCE(p_min_tier, 'free'),
    now()
  )
  ON CONFLICT (path) DO UPDATE SET
    visibility  = CASE WHEN p_visibility IS NOT NULL THEN p_visibility ELSE site_pages.visibility END,
    meta_title  = COALESCE(EXCLUDED.meta_title, site_pages.meta_title),
    meta_desc   = COALESCE(EXCLUDED.meta_desc, site_pages.meta_desc),
    coming_soon = CASE WHEN p_coming_soon IS NOT NULL THEN p_coming_soon ELSE site_pages.coming_soon END,
    min_tier    = CASE WHEN p_min_tier IS NOT NULL THEN p_min_tier ELSE site_pages.min_tier END,
    updated_at  = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_site_page(text, text, text, text, boolean, text) TO authenticated;

-- Member tiers: daily / weekly / monthly / yearly (admin manual grant)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'admin_set_member_tier'
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_member_tier(
  p_user_id uuid, p_tier text, p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_tier NOT IN ('free','daily','weekly','monthly','yearly','premium','event') THEN
    RAISE EXCEPTION 'Invalid tier';
  END IF;
  UPDATE public.profiles SET subscription_tier = p_tier WHERE id = p_user_id;
  INSERT INTO public.member_subscriptions (user_id, tier, status, source, notes)
  VALUES (p_user_id, p_tier, 'active', 'manual', p_notes);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_member_tier(uuid, text, text) TO authenticated;

SELECT 'fix-phase21-batch.sql complete' AS status;
