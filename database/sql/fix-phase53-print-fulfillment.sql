-- ══════════════════════════════════════════════════════════════════════
-- fix-phase53-print-fulfillment.sql — Print & Post ops (admin inbox + member orders)
-- Safe to re-run. Run after fix-phase31-print-orders.sql.
-- ══════════════════════════════════════════════════════════════════════

-- ── Status workflow: pending → processing → shipped | cancelled ───────
ALTER TABLE public.print_order_requests
  ADD COLUMN IF NOT EXISTS admin_notes text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.print_order_requests SET status = 'processing' WHERE status = 'contacted';
UPDATE public.print_order_requests SET status = 'shipped'    WHERE status = 'fulfilled';

ALTER TABLE public.print_order_requests DROP CONSTRAINT IF EXISTS print_order_requests_status_check;
ALTER TABLE public.print_order_requests ADD CONSTRAINT print_order_requests_status_check
  CHECK (status IN ('pending', 'processing', 'shipped', 'cancelled'));

DROP TRIGGER IF EXISTS print_order_requests_updated_at ON public.print_order_requests;
CREATE TRIGGER print_order_requests_updated_at
  BEFORE UPDATE ON public.print_order_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── Email templates ───────────────────────────────────────────────────
INSERT INTO public.email_templates (key, name, subject, body, updated_at) VALUES
(
  'print_order_received',
  'Print Order Received',
  'We received your Print & Post order — The Culinary Journal',
  '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Print & Post order received</h2>'
  || '<p>Hi {{name}},</p>'
  || '<p>Thank you — we have your order for <strong>{{recipe_name}}</strong> ({{card_count}} cards, {{card_quality}}).</p>'
  || '<p>Reference: <code>{{order_id}}</code></p>'
  || '<p>We will contact you about payment and dispatch before printing. No payment has been taken yet.</p>'
  || '<p><a href="https://www.theculinaryjournal.site/print-studio.html">View Print Studio →</a></p>',
  NOW()
),
(
  'print_order_shipped',
  'Print Order Shipped',
  'Your recipe cards are on their way — The Culinary Journal',
  '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Your cards have shipped</h2>'
  || '<p>Hi {{name}},</p>'
  || '<p>Your Print & Post order for <strong>{{recipe_name}}</strong> ({{card_count}} cards) has been dispatched.</p>'
  || '<p>Reference: <code>{{order_id}}</code></p>'
  || '<p>Thank you for using The Culinary Journal Print Studio.</p>',
  NOW()
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  updated_at = NOW();

-- ── Submit order (confirmation email) ─────────────────────────────────
DROP FUNCTION IF EXISTS public.submit_print_order_request(jsonb);
CREATE OR REPLACE FUNCTION public.submit_print_order_request(p_payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
  v_name text;
  v_recipe text;
  v_count int;
  v_quality text;
BEGIN
  v_recipe  := COALESCE(NULLIF(trim(p_payload->>'recipe_name'), ''), 'Recipe cards');
  v_count   := GREATEST(1, LEAST(COALESCE((p_payload->>'card_count')::int, 10), 500));
  v_quality := COALESCE(NULLIF(trim(p_payload->>'card_quality'), ''), 'standard');

  INSERT INTO print_order_requests (
    user_id, recipe_id, recipe_name, card_count, card_quality, card_size, layout_style,
    delivery, preview_meta, status
  ) VALUES (
    auth.uid(),
    NULLIF(trim(p_payload->>'recipe_id'), '')::uuid,
    v_recipe,
    v_count,
    v_quality,
    NULLIF(trim(p_payload->>'card_size'), ''),
    NULLIF(trim(p_payload->>'layout_style'), ''),
    COALESCE(p_payload->'delivery', '{}'),
    COALESCE(p_payload->'preview_meta', '{}'),
    'pending'
  )
  RETURNING id INTO v_id;

  IF auth.uid() IS NOT NULL THEN
    SELECT COALESCE(u.email, p.email), COALESCE(p.full_name, p.username, 'Member')
    INTO v_email, v_name
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();

    IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
      PERFORM public.tcj_queue_member_email(
        'print_order_received',
        v_email,
        v_name,
        jsonb_build_object(
          'name', v_name,
          'recipe_name', v_recipe,
          'card_count', v_count::text,
          'card_quality', v_quality,
          'order_id', v_id::text
        )
      );
    END IF;
  END IF;

  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_print_order_request(jsonb) TO authenticated, anon;

-- ── Member: my orders ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_my_print_orders();
CREATE OR REPLACE FUNCTION public.get_my_print_orders()
RETURNS SETOF public.print_order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
  SELECT *
  FROM public.print_order_requests
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 50;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_print_orders() TO authenticated;

-- ── Admin: enriched list ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_print_orders(text, int);
CREATE OR REPLACE FUNCTION public.admin_get_print_orders(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(x) ORDER BY x.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      o.id,
      o.user_id,
      o.recipe_id,
      o.recipe_name,
      o.card_count,
      o.card_quality,
      o.card_size,
      o.layout_style,
      o.delivery,
      o.preview_meta,
      o.status,
      o.admin_notes,
      o.created_at,
      o.updated_at,
      COALESCE(u.email, p.email) AS member_email,
      COALESCE(p.full_name, p.username, 'Guest') AS member_name
    FROM public.print_order_requests o
    LEFT JOIN public.profiles p ON p.id = o.user_id
    LEFT JOIN auth.users u ON u.id = o.user_id
    WHERE p_status IS NULL OR btrim(p_status) = '' OR o.status = p_status
    ORDER BY o.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 100), 200))
  ) x;

  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_print_orders(text, int) TO authenticated;

-- Keep legacy RPC (maps to enriched filter)
DROP FUNCTION IF EXISTS public.admin_get_print_order_requests(text, int);
CREATE OR REPLACE FUNCTION public.admin_get_print_order_requests(p_status text DEFAULT 'pending', p_limit int DEFAULT 50)
RETURNS SETOF public.print_order_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  RETURN QUERY
  SELECT * FROM public.print_order_requests
  WHERE (p_status IS NULL OR btrim(p_status) = '' OR status = p_status)
  ORDER BY created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_print_order_requests(text, int) TO authenticated;

-- ── Admin: update status (+ shipped email) ───────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_print_order_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_update_print_order_status(
  p_order_id uuid,
  p_status text,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.print_order_requests%ROWTYPE;
  v_email text;
  v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  IF p_status NOT IN ('pending', 'processing', 'shipped', 'cancelled') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.print_order_requests
  SET status = p_status,
      admin_notes = COALESCE(NULLIF(btrim(p_admin_notes), ''), admin_notes)
  WHERE id = p_order_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN RAISE EXCEPTION 'order_not_found'; END IF;

  IF p_status = 'shipped' AND v_row.user_id IS NOT NULL THEN
    SELECT COALESCE(u.email, p.email), COALESCE(p.full_name, p.username, 'Member')
    INTO v_email, v_name
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_row.user_id;

    IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
      PERFORM public.tcj_queue_member_email(
        'print_order_shipped',
        v_email,
        v_name,
        jsonb_build_object(
          'name', v_name,
          'recipe_name', COALESCE(v_row.recipe_name, 'Recipe cards'),
          'card_count', v_row.card_count::text,
          'card_quality', v_row.card_quality,
          'order_id', v_row.id::text
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status,
    'admin_notes', v_row.admin_notes
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_print_order_status(uuid, text, text) TO authenticated;

-- ── Admin: counts for dashboard badge ─────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_count_print_orders(text);
CREATE OR REPLACE FUNCTION public.admin_count_print_orders(p_status text DEFAULT 'pending')
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  SELECT count(*)::int INTO v_n
  FROM public.print_order_requests
  WHERE p_status IS NULL OR status = p_status;
  RETURN COALESCE(v_n, 0);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_count_print_orders(text) TO authenticated;

SELECT 'fix-phase53-print-fulfillment.sql complete' AS status;
