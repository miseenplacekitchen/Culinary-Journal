-- ══════════════════════════════════════════════════════════════════
-- Site Management RPC Functions
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── Site Pages ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_site_pages()
RETURNS SETOF public.site_pages
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.site_pages ORDER BY sort_order;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_save_site_page(
  p_path TEXT, p_visibility TEXT DEFAULT 'public',
  p_meta_title TEXT DEFAULT NULL, p_coming_soon BOOLEAN DEFAULT false
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.site_pages
  SET visibility=p_visibility, meta_title=p_meta_title, coming_soon=p_coming_soon, updated_at=now()
  WHERE path=p_path;
END; $$;

-- ── Site Features ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_site_features()
RETURNS SETOF public.site_features
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.site_features ORDER BY sort_order;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_toggle_site_feature(p_key TEXT, p_enabled BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.site_features SET enabled=p_enabled WHERE key=p_key;
END; $$;

-- ── Announcements ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_announcements()
RETURNS SETOF public.site_announcements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.site_announcements ORDER BY created_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_add_announcement(p_text TEXT, p_type TEXT DEFAULT 'info')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.site_announcements (text, type, active) VALUES (p_text, p_type, true);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_delete_announcement(p_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.site_announcements WHERE id=p_id;
END; $$;

-- ── Site Settings ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_site_settings()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_object_agg(key, value) INTO result FROM public.site_settings;
  RETURN COALESCE(result, '{}'::json);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_save_site_setting(p_key TEXT, p_value TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.site_settings (key, value) VALUES (p_key, p_value)
  ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now();
END; $$;

-- ── Email Templates ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_email_templates()
RETURNS SETOF public.email_templates
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.email_templates ORDER BY key;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_save_email_template(p_key TEXT, p_subject TEXT, p_body TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.email_templates (key, subject, body) VALUES (p_key, p_subject, p_body)
  ON CONFLICT (key) DO UPDATE SET subject=EXCLUDED.subject, body=EXCLUDED.body, updated_at=now();
END; $$;

-- ── Grants ───────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_get_site_pages()                             TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_site_page(text,text,text,boolean)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_site_features()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_site_feature(text,boolean)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_announcements()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_announcement(text,text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_announcement(bigint)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_site_settings()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_site_setting(text,text)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_email_templates()                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_email_template(text,text,text)          TO authenticated;

NOTIFY pgrst, 'reload schema';
