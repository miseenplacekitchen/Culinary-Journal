-- fix-login-info-leak.sql — Stop returning is_admin from pre-auth login lookup.
-- Run once in Supabase SQL Editor. Safe to re-run.

DROP FUNCTION IF EXISTS public.get_login_info(text);

CREATE OR REPLACE FUNCTION public.get_login_info(identifier text)
RETURNS TABLE (
  email          text,
  username       text,
  is_active      boolean,
  account_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Reads canonical email from auth.users so this works
  -- even if profiles.email is missing or stale.
  -- is_admin is intentionally omitted — use is_admin() after sign-in only.
  RETURN QUERY
    SELECT
      u.email::text,
      p.username,
      p.is_active,
      CASE WHEN p.is_active = false THEN 'deactivated' ELSE 'active' END::text
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE LOWER(u.email)    = LOWER(identifier)
       OR LOWER(p.username) = LOWER(identifier)
    LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.get_login_info(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_login_info(text) TO anon, authenticated;

SELECT 'fix-login-info-leak applied' AS status;
