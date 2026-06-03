-- Fixes: admin panel access denied, profile page error, theme not loading.
-- Root cause: get_my_profile() declares text return types but profiles
-- table has varchar(255) columns. Explicit casts resolve the mismatch.
--
-- Run this directly in Supabase SQL Editor. Nothing else needed.

DROP FUNCTION IF EXISTS public.get_my_profile();
CREATE FUNCTION public.get_my_profile()
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
  created_at          timestamptz
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
           u.created_at
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
SELECT pg_notify('pgrst', 'reload schema');

-- Also fixes update_my_profile which has the same varchar/text mismatch
DROP FUNCTION IF EXISTS public.update_my_profile(text,text);
CREATE FUNCTION public.update_my_profile(new_full_name text, new_username text)
RETURNS TABLE (
  id uuid, full_name text, username text, email text,
  is_active boolean, theme_preference text, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF new_username IS NOT NULL THEN
    IF length(new_username) < 3 OR length(new_username) > 20
      THEN RAISE EXCEPTION 'username_invalid_length'; END IF;
    IF new_username !~ '^[A-Za-z0-9_-]+$'
      THEN RAISE EXCEPTION 'username_invalid_chars'; END IF;
    IF EXISTS (SELECT 1 FROM public.profiles
               WHERE LOWER(username) = LOWER(new_username) AND id <> auth.uid())
      THEN RAISE EXCEPTION 'username_taken'; END IF;
  END IF;
  IF new_full_name IS NOT NULL AND length(trim(new_full_name)) = 0
    THEN RAISE EXCEPTION 'name_empty'; END IF;
  UPDATE public.profiles
     SET full_name = COALESCE(new_full_name, full_name),
         username  = COALESCE(new_username,  username)
   WHERE id = auth.uid();
  RETURN QUERY
    SELECT p.id,
           p.full_name::text,
           p.username::text,
           u.email::text,
           p.is_active,
           p.theme_preference::text,
           u.created_at
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text,text) TO authenticated;
SELECT pg_notify('pgrst', 'reload schema');
