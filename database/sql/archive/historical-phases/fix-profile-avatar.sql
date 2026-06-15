-- Run once in Supabase SQL Editor to fix avatar/profile RPC issues.
-- Safe to re-run.

-- 1) Return avatar_url + last_seen from get_my_profile (fixes stale/missing avatars)
DO $$ DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_my_profile'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id                  uuid,
  full_name           text,
  username            text,
  email               text,
  is_active           boolean,
  is_admin            boolean,
  theme_preference    text,
  dietary_preferences text[],
  allergies           text[],
  health_conditions   text[],
  cooking_style       text,
  font_size           text,
  avatar_url          text,
  created_at          timestamptz,
  last_seen           timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT p.id,
           p.full_name::text,
           p.username::text,
           u.email::text,
           p.is_active,
           p.is_admin,
           p.theme_preference::text,
           COALESCE(p.dietary_preferences, '{}')::text[],
           COALESCE(p.allergies, '{}')::text[],
           COALESCE(p.health_conditions, '{}')::text[],
           COALESCE(p.cooking_style, '')::text,
           COALESCE(p.font_size, 'medium')::text,
           p.avatar_url::text,
           u.created_at,
           p.last_seen
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END;
$$;

-- 2) Bump last_seen when avatar changes (cache-bust signal for browsers)
CREATE OR REPLACE FUNCTION public.update_avatar_url(p_url text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE public.profiles SET avatar_url = p_url, last_seen = now() WHERE id = auth.uid();
END;
$$;

-- 3) Admin display name / username
UPDATE public.profiles
   SET username = 'miseenplacekitchen',
       full_name = 'miseenplacekitchen'
 WHERE email = 'miseenplacekitchen.official@gmail.com';

SELECT pg_notify('pgrst', 'reload schema');
