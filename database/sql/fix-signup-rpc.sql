-- Signup fix: is_username_taken RPC (login.html sends { uname: "..." })
-- Safe to re-run. Run in Supabase SQL Editor.

DROP FUNCTION IF EXISTS public.is_username_taken(text);

CREATE OR REPLACE FUNCTION public.is_username_taken(uname text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE LOWER(username) = LOWER(TRIM(uname))
  );
END;
$$;

REVOKE ALL ON FUNCTION public.is_username_taken(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_username_taken(text) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-signup-rpc.sql complete' AS status;
