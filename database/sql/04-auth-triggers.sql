-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 04-auth-triggers.sql
-- Two missing pieces that were never written.
-- Run in Supabase → SQL Editor AFTER the other 4 files.
-- ═══════════════════════════════════════════════════════════════

-- ── 2. handle_new_user trigger ───────────────────────────────────
-- Fires automatically when a new user is created in auth.users.
-- Creates the matching profile row using metadata from signup.
-- This is what connects Supabase Auth to the profiles table.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
