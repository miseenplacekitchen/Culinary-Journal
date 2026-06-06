-- TCJ Verify test account — run after creating user in Supabase Auth
-- Safe to re-run.

-- 1) Ensure profile row exists (manual Auth user creation may skip the trigger)
INSERT INTO public.profiles (id, username, full_name, email, is_active, is_admin)
SELECT
  u.id,
  'tcj-verify',
  'TCJ Verify',
  u.email,
  true,
  true
FROM auth.users u
WHERE LOWER(u.email) = LOWER('tcj.verify@outlook.com')
ON CONFLICT (id) DO UPDATE SET
  username   = EXCLUDED.username,
  full_name  = EXCLUDED.full_name,
  email      = EXCLUDED.email,
  is_active  = true,
  is_admin   = true;

-- 2) Confirm email so password login works (if still unconfirmed)
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    confirmed_at       = COALESCE(confirmed_at, NOW())
WHERE LOWER(email) = LOWER('tcj.verify@outlook.com');

-- 3) Signup RPC (still missing on live — fixes Create Account form)
DROP FUNCTION IF EXISTS public.is_username_taken(text);
CREATE OR REPLACE FUNCTION public.is_username_taken(uname text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
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

SELECT id, username, email, is_admin, is_active
FROM public.profiles
WHERE LOWER(email) = LOWER('tcj.verify@outlook.com');
