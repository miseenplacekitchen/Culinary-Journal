-- ══════════════════════════════════════════════════════════════════════
-- fix-phase31-print-orders.sql — Print & Post order intent queue (preview)
-- Safe to re-run. Fulfilment/payment not wired — captures intent for launch.
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.print_order_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recipe_id uuid,
  recipe_name text,
  card_count int NOT NULL DEFAULT 10 CHECK (card_count > 0 AND card_count <= 500),
  card_quality text NOT NULL DEFAULT 'standard' CHECK (card_quality IN ('standard','premium','laminated')),
  card_size text,
  layout_style text,
  delivery jsonb NOT NULL DEFAULT '{}',
  preview_meta jsonb NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','contacted','fulfilled','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_print_orders_status ON public.print_order_requests(status);
CREATE INDEX IF NOT EXISTS idx_print_orders_user ON public.print_order_requests(user_id);

ALTER TABLE public.print_order_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS print_orders_own ON public.print_order_requests;
CREATE POLICY print_orders_own ON public.print_order_requests
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS print_orders_insert ON public.print_order_requests;
CREATE POLICY print_orders_insert ON public.print_order_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP FUNCTION IF EXISTS public.submit_print_order_request(jsonb);
CREATE OR REPLACE FUNCTION public.submit_print_order_request(p_payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO print_order_requests (
    user_id, recipe_id, recipe_name, card_count, card_quality, card_size, layout_style,
    delivery, preview_meta, status
  ) VALUES (
    auth.uid(),
    NULLIF(trim(p_payload->>'recipe_id'), '')::uuid,
    NULLIF(trim(p_payload->>'recipe_name'), ''),
    GREATEST(1, LEAST(COALESCE((p_payload->>'card_count')::int, 10), 500)),
    COALESCE(NULLIF(trim(p_payload->>'card_quality'), ''), 'standard'),
    NULLIF(trim(p_payload->>'card_size'), ''),
    NULLIF(trim(p_payload->>'layout_style'), ''),
    COALESCE(p_payload->'delivery', '{}'),
    COALESCE(p_payload->'preview_meta', '{}'),
    'pending'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_print_order_request(jsonb) TO authenticated, anon;

DROP FUNCTION IF EXISTS public.admin_get_print_order_requests(text, int);
CREATE OR REPLACE FUNCTION public.admin_get_print_order_requests(p_status text DEFAULT 'pending', p_limit int DEFAULT 50)
RETURNS SETOF print_order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  RETURN QUERY
  SELECT * FROM print_order_requests
  WHERE (p_status IS NULL OR status = p_status)
  ORDER BY created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_print_order_requests(text, int) TO authenticated;
