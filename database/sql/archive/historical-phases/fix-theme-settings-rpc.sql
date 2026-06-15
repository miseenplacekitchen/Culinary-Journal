-- get_theme_settings — member-facing theme catalogue (pricing, enabled, colours metadata)
-- Safe to re-run. Run in Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.get_theme_settings()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE result json;
BEGIN
  SELECT json_object_agg(key, value) INTO result
  FROM public.site_settings
  WHERE key IN (
    'theme_catalog',
    'disabled_themes',
    'default_theme',
    'seasonal_default_theme',
    'currency_symbol'
  );
  RETURN COALESCE(result, '{}'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_theme_settings() TO authenticated;

-- Anonymous + signed-in: site default theme for login page and theme-init.js
CREATE OR REPLACE FUNCTION public.get_public_theme_default()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE result json;
BEGIN
  SELECT json_object_agg(key, value) INTO result
  FROM public.site_settings
  WHERE key IN ('default_theme', 'seasonal_default_theme', 'theme_catalog');
  RETURN COALESCE(result, '{}'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_theme_default() TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_theme_default() TO authenticated;
