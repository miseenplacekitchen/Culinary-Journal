-- ── Finance Management Tables ────────────────────────────────────────────
-- Run in Supabase SQL Editor

-- Pricing configuration (stored in site_settings, but also as dedicated table)
-- We use site_settings for prices so admin can change them without SQL

INSERT INTO public.site_settings (key, value) VALUES
  ('price_premium_monthly',    '4.00'),
  ('price_premium_annual',     '40.00'),
  ('price_event_monthly',      '12.00'),
  ('price_event_annual',       '120.00'),
  ('currency_symbol',          '$'),
  ('currency_code',            'USD')
ON CONFLICT (key) DO NOTHING;

-- Member subscription log (manual upgrades + future Stripe webhooks write here)
CREATE TABLE IF NOT EXISTS public.member_subscriptions (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tier            TEXT NOT NULL CHECK (tier IN ('free','premium','event')),
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','cancelled','expired','trialing')),
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  source          TEXT DEFAULT 'manual' CHECK (source IN ('manual','stripe','promo')),
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.member_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.member_subscriptions;
CREATE POLICY "Admin full access" ON public.member_subscriptions
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT, INSERT, UPDATE ON public.member_subscriptions TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.member_subscriptions_id_seq TO authenticated;

CREATE INDEX IF NOT EXISTS member_subscriptions_user_idx ON public.member_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS member_subscriptions_tier_idx ON public.member_subscriptions(tier, status);

-- RPC: admin get tier statistics
DROP FUNCTION IF EXISTS admin_get_tier_stats();
DROP FUNCTION IF EXISTS public.admin_get_tier_stats();
CREATE OR REPLACE FUNCTION public.admin_get_tier_stats()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'free',    (SELECT COUNT(*) FROM public.profiles WHERE subscription_tier = 'free'),
    'premium', (SELECT COUNT(*) FROM public.profiles WHERE subscription_tier = 'premium'),
    'event',   (SELECT COUNT(*) FROM public.profiles WHERE subscription_tier = 'event'),
    'total',   (SELECT COUNT(*) FROM public.profiles WHERE is_active = true)
  ) INTO result;
  RETURN result;
END; $$;

-- RPC: admin set member tier
CREATE OR REPLACE FUNCTION public.admin_set_member_tier(
  p_user_id UUID, p_tier TEXT, p_notes TEXT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_tier NOT IN ('free','premium','event') THEN RAISE EXCEPTION 'Invalid tier'; END IF;
  UPDATE public.profiles SET subscription_tier = p_tier WHERE id = p_user_id;
  INSERT INTO public.member_subscriptions (user_id, tier, status, source, notes)
  VALUES (p_user_id, p_tier, 'active', 'manual', p_notes);
END; $$;

-- RPC: admin get member subscriptions
DROP FUNCTION IF EXISTS public.admin_get_subscriptions(int, int);
CREATE OR REPLACE FUNCTION public.admin_get_subscriptions(
  p_limit INT DEFAULT 50, p_offset INT DEFAULT 0
)
RETURNS TABLE(
  user_id UUID, username TEXT, full_name TEXT, email TEXT,
  tier TEXT, status TEXT, started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ, source TEXT, notes TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
    SELECT ms.user_id, p.username, p.full_name, p.email,
           ms.tier, ms.status, ms.started_at, ms.expires_at, ms.source, ms.notes
    FROM public.member_subscriptions ms
    JOIN public.profiles p ON p.id = ms.user_id
    ORDER BY ms.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END; $$;

GRANT EXECUTE ON FUNCTION public.admin_get_tier_stats()                                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_member_tier(uuid,text,text)                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_subscriptions(int,int)                         TO authenticated;

NOTIFY pgrst, 'reload schema';
