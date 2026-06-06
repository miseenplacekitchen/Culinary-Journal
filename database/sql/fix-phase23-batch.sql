-- ══════════════════════════════════════════════════════════════════════
-- fix-phase23-batch.sql — Shared pantry, Stripe, library admin, promos
-- Safe to re-run. Run after fix-phase22-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

-- ── Shared household pantry ───────────────────────────────────────────
ALTER TABLE public.households
  ADD COLUMN IF NOT EXISTS pantry_items jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.households
  ADD COLUMN IF NOT EXISTS pantry_updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public._merge_pantry_items(a jsonb, b jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE out jsonb := COALESCE(a, '[]'::jsonb);
  it jsonb;
BEGIN
  IF b IS NULL OR jsonb_typeof(b) <> 'array' THEN RETURN out; END IF;
  FOR it IN SELECT * FROM jsonb_array_elements(b)
  LOOP
    out := out || it;
  END LOOP;
  RETURN out;
END;
$$;

DROP FUNCTION IF EXISTS public.get_my_pantry();
CREATE FUNCTION public.get_my_pantry()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
  h_row public.households%ROWTYPE;
  items jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    SELECT * INTO h_row FROM public.households WHERE id = h_id;
    RETURN jsonb_build_object(
      'items', COALESCE(h_row.pantry_items, '[]'::jsonb),
      'updated_at', h_row.pantry_updated_at,
      'shared', true,
      'household_id', h_id,
      'household_name', h_row.name
    );
  END IF;
  items := COALESCE((SELECT p.items FROM public.pantry p WHERE p.user_id = auth.uid()), '[]'::jsonb);
  RETURN jsonb_build_object(
    'items', items,
    'updated_at', COALESCE((SELECT p.updated_at FROM public.pantry p WHERE p.user_id = auth.uid()), now()),
    'shared', false,
    'household_id', null,
    'household_name', null
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_pantry() TO authenticated;

DROP FUNCTION IF EXISTS public.save_my_pantry(jsonb);
CREATE FUNCTION public.save_my_pantry(p_items jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    UPDATE public.households SET pantry_items = COALESCE(p_items, '[]'::jsonb), pantry_updated_at = now()
    WHERE id = h_id;
    RETURN;
  END IF;
  INSERT INTO public.pantry (user_id, items, updated_at)
  VALUES (auth.uid(), COALESCE(p_items, '[]'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE SET items = EXCLUDED.items, updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_pantry(jsonb) TO authenticated;

-- Household create/accept: include pantry merge
CREATE OR REPLACE FUNCTION public.create_household(p_name text DEFAULT 'Our Kitchen')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
  personal jsonb; personal_checked jsonb; personal_pantry jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF public._my_household_id() IS NOT NULL THEN RAISE EXCEPTION 'Already in a household'; END IF;
  SELECT list_data, checked INTO personal, personal_checked FROM public.grocery_lists WHERE user_id = auth.uid();
  SELECT items INTO personal_pantry FROM public.pantry WHERE user_id = auth.uid();
  INSERT INTO public.households (name, owner_id, grocery_list_data, grocery_checked, pantry_items)
  VALUES (COALESCE(NULLIF(btrim(p_name), ''), 'Our Kitchen'), auth.uid(),
          COALESCE(personal, '{"version":2,"recipes":[],"items":[]}'::jsonb),
          COALESCE(personal_checked, '[]'::jsonb),
          COALESCE(personal_pantry, '[]'::jsonb))
  RETURNING id INTO h_id;
  INSERT INTO public.household_members (household_id, user_id, role) VALUES (h_id, auth.uid(), 'owner');
  RETURN h_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_household_invite(p_invite_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv public.household_invites%ROWTYPE;
  my_email text; personal jsonb; personal_checked jsonb; personal_pantry jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF public._my_household_id() IS NOT NULL THEN RAISE EXCEPTION 'Already in a household'; END IF;
  SELECT lower(email) INTO my_email FROM public.profiles WHERE id = auth.uid();
  SELECT * INTO inv FROM public.household_invites
  WHERE id = p_invite_id AND status = 'pending' AND expires_at > now();
  IF NOT FOUND THEN RAISE EXCEPTION 'Invite not found or expired'; END IF;
  IF lower(inv.invitee_email) <> my_email THEN RAISE EXCEPTION 'Invite is for a different email'; END IF;
  SELECT list_data, checked INTO personal, personal_checked FROM public.grocery_lists WHERE user_id = auth.uid();
  SELECT items INTO personal_pantry FROM public.pantry WHERE user_id = auth.uid();
  UPDATE public.households SET
    grocery_list_data = public._merge_grocery_lists(grocery_list_data, personal),
    grocery_checked = grocery_checked || COALESCE(personal_checked, '[]'::jsonb),
    pantry_items = public._merge_pantry_items(pantry_items, personal_pantry),
    grocery_updated_at = now(), pantry_updated_at = now()
  WHERE id = inv.household_id;
  INSERT INTO public.household_members (household_id, user_id, role) VALUES (inv.household_id, auth.uid(), 'member');
  UPDATE public.household_invites SET status = 'accepted' WHERE id = p_invite_id;
  DELETE FROM public.grocery_lists WHERE user_id = auth.uid();
  DELETE FROM public.pantry WHERE user_id = auth.uid();
END;
$$;

-- ── Library admin: governed_ingredient_id in listing ──────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
CREATE FUNCTION public.admin_get_library_profiles(
  p_type text, p_status text DEFAULT NULL, p_limit int DEFAULT 50, p_offset int DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb; v_extra text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  v_extra := CASE WHEN p_type = 'ingredient' THEN ', governed_ingredient_id' ELSE '' END;
  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.updated_at DESC), ''[]''::jsonb)
     FROM (SELECT id, slug, name, image_url, status, visibility, updated_at%s
           FROM %I WHERE ($1 IS NULL OR status = $1)
           ORDER BY updated_at DESC LIMIT $2 OFFSET $3) p',
    v_extra, p_type || '_profiles'
  ) INTO v_result USING p_status, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_library_profiles(text, text, int, int) TO authenticated;

DROP FUNCTION IF EXISTS public.get_library_profile_by_ingredient_name(text);
CREATE FUNCTION public.get_library_profile_by_ingredient_name(p_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN RETURN NULL; END IF;
  SELECT row_to_json(p)::jsonb INTO v_result FROM public.ingredient_profiles p
  WHERE status = 'published'
    AND (lower(name) = lower(btrim(p_name)) OR lower(also_known_as) = lower(btrim(p_name)))
  LIMIT 1;
  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_library_profile_by_ingredient_name(text) TO anon, authenticated;

-- ── Promo codes ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.promo_codes (
  code          text PRIMARY KEY,
  discount_type text NOT NULL DEFAULT 'percent' CHECK (discount_type IN ('percent','flat','free_month')),
  discount_value numeric NOT NULL DEFAULT 0,
  tier_grant    text DEFAULT 'monthly',
  max_uses      int,
  uses_count    int NOT NULL DEFAULT 0,
  active        boolean NOT NULL DEFAULT true,
  expires_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages promos" ON public.promo_codes;
CREATE POLICY "admin manages promos" ON public.promo_codes
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP FUNCTION IF EXISTS public.admin_upsert_promo_code(text, text, numeric, text, int, timestamptz);
CREATE FUNCTION public.admin_upsert_promo_code(
  p_code text, p_discount_type text, p_discount_value numeric,
  p_tier_grant text DEFAULT 'monthly', p_max_uses int DEFAULT NULL, p_expires_at timestamptz DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.promo_codes (code, discount_type, discount_value, tier_grant, max_uses, expires_at)
  VALUES (upper(btrim(p_code)), p_discount_type, p_discount_value, p_tier_grant, p_max_uses, p_expires_at)
  ON CONFLICT (code) DO UPDATE SET
    discount_type = EXCLUDED.discount_type, discount_value = EXCLUDED.discount_value,
    tier_grant = EXCLUDED.tier_grant, max_uses = EXCLUDED.max_uses, expires_at = EXCLUDED.expires_at,
    active = true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_promo_code(text, text, numeric, text, int, timestamptz) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_promo_code(text);
CREATE FUNCTION public.admin_delete_promo_code(p_code text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.promo_codes WHERE code = upper(btrim(p_code));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_promo_code(text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_promo_codes();
CREATE FUNCTION public.admin_get_promo_codes()
RETURNS SETOF public.promo_codes LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.promo_codes ORDER BY created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_promo_codes() TO authenticated;

DROP FUNCTION IF EXISTS public.validate_promo_code(text);
CREATE FUNCTION public.validate_promo_code(p_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.promo_codes%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.promo_codes
  WHERE code = upper(btrim(p_code)) AND active = true
    AND (expires_at IS NULL OR expires_at > now())
    AND (max_uses IS NULL OR uses_count < max_uses);
  IF NOT FOUND THEN RETURN jsonb_build_object('valid', false); END IF;
  RETURN jsonb_build_object(
    'valid', true, 'code', r.code, 'discount_type', r.discount_type,
    'discount_value', r.discount_value, 'tier_grant', r.tier_grant
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.validate_promo_code(text) TO authenticated;

-- ── Stripe checkout session log ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stripe_checkout_sessions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_session_id text UNIQUE,
  tier            text NOT NULL,
  amount_cents    int,
  currency        text DEFAULT 'usd',
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','expired','failed')),
  promo_code      text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  completed_at    timestamptz
);

ALTER TABLE public.stripe_checkout_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users read own checkout sessions" ON public.stripe_checkout_sessions;
CREATE POLICY "users read own checkout sessions" ON public.stripe_checkout_sessions
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_admin());

INSERT INTO public.site_settings (key, value) VALUES
  ('stripe_publishable_key', ''),
  ('stripe_price_daily', '0.99'),
  ('stripe_price_weekly', '2.99'),
  ('stripe_price_monthly', '4.00'),
  ('stripe_price_yearly', '40.00'),
  ('checkout_success_url', 'https://www.theculinaryjournal.site/checkout-success.html'),
  ('checkout_cancel_url', 'https://www.theculinaryjournal.site/paid-members-only.html')
ON CONFLICT (key) DO NOTHING;

DROP FUNCTION IF EXISTS public.get_public_stripe_config();
CREATE FUNCTION public.get_public_stripe_config()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE S jsonb;
BEGIN
  SELECT jsonb_object_agg(key, value) INTO S FROM public.site_settings
  WHERE key IN ('stripe_enabled','stripe_publishable_key','stripe_checkout_mode',
                'price_daily','price_weekly','price_premium_monthly','price_yearly',
                'currency_symbol','billing_no_refunds_banner');
  RETURN COALESCE(S, '{}'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_stripe_config() TO anon, authenticated;

DROP FUNCTION IF EXISTS public.apply_stripe_subscription(uuid, text, text, text);
CREATE FUNCTION public.apply_stripe_subscription(
  p_user_id uuid, p_tier text, p_stripe_session_id text DEFAULT NULL, p_notes text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_tier NOT IN ('daily','weekly','monthly','yearly','premium','event') THEN
    RAISE EXCEPTION 'Invalid tier';
  END IF;
  UPDATE public.profiles SET subscription_tier = p_tier WHERE id = p_user_id;
  INSERT INTO public.member_subscriptions (user_id, tier, status, source, notes)
  VALUES (p_user_id, p_tier, 'active', 'stripe', COALESCE(p_notes, p_stripe_session_id));
  IF p_stripe_session_id IS NOT NULL THEN
    UPDATE public.stripe_checkout_sessions SET status = 'completed', completed_at = now()
    WHERE stripe_session_id = p_stripe_session_id;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_stripe_subscription(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_stripe_subscription(uuid, text, text, text) TO service_role;

DROP FUNCTION IF EXISTS public.increment_promo_use(text);
CREATE FUNCTION public.increment_promo_use(p_code text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.promo_codes SET uses_count = uses_count + 1
  WHERE code = upper(btrim(p_code));
END;
$$;
GRANT EXECUTE ON FUNCTION public.increment_promo_use(text) TO service_role;

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Checkout Success', 'checkout-success.html', 'registered', 16, 'free')
ON CONFLICT (path) DO NOTHING;

SELECT 'fix-phase23-batch.sql complete' AS status;
