-- ── Security note: Guest Dietary Cards use UUID bearer tokens ───────────
-- get_guest_card(uuid) and submit_guest_dietary(uuid, text) are callable
-- by anon. The guest ID acts as a bearer token. This is intentional for
-- the guest dietary card sharing workflow. Tokens have no server-side expiry.
-- Mitigations: UUIDs are 128-bit random (not guessable), and the data 
-- exposed (dietary requirements) is not sensitive PII. If expiry is needed,
-- add an expires_at column to family_profiles and check it in the function.
-- ─────────────────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — Family Profiles + Guest Dietary Cards
-- Run in Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── FAMILY PROFILES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.family_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name             text NOT NULL,
  relationship     text DEFAULT 'guest',
    -- self | partner | child | toddler | baby | elderly | regular_guest | other
  age_group        text DEFAULT 'adult',
    -- adult | child | toddler | baby | elderly
  allergies        jsonb  NOT NULL DEFAULT '[]',
  spice_preference text DEFAULT 'medium',
    -- none | mild | medium | hot | very_hot
  dietary_needs    jsonb  NOT NULL DEFAULT '[]',
  health_conditions text[] DEFAULT '{}',
  notes            text,
  created_at       timestamptz DEFAULT now()
);
ALTER TABLE public.family_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own family profiles" ON public.family_profiles;
CREATE POLICY "Users manage own family profiles"
  ON public.family_profiles FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── GUEST DIETARY CARD TRACKING ──────────────────────────────────
-- Add submitted flag to existing guests table
-- dietary_submitted columns are in table_planner.sql

-- ── FAMILY PROFILE RPCs ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.upsert_family_profile(uuid,text,text,text,jsonb,text,jsonb,text[],text);
CREATE OR REPLACE FUNCTION upsert_family_profile(
  p_id               uuid    DEFAULT NULL,
  p_name             text    DEFAULT '',
  p_relationship     text    DEFAULT 'guest',
  p_age_group        text    DEFAULT 'adult',
  p_allergies        jsonb   DEFAULT '[]',
  p_spice_preference text    DEFAULT 'medium',
  p_dietary_needs    jsonb   DEFAULT '[]',
  p_health_conditions text[] DEFAULT '{}',
  p_notes            text    DEFAULT ''
)
RETURNS public.family_profiles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.family_profiles;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.family_profiles
      (user_id, name, relationship, age_group, allergies, spice_preference, dietary_needs, health_conditions, notes)
    VALUES
      (auth.uid(), p_name, p_relationship, p_age_group, p_allergies, p_spice_preference, p_dietary_needs, p_health_conditions, p_notes)
    RETURNING * INTO result;
  ELSE
    UPDATE public.family_profiles SET
      name=p_name, relationship=p_relationship, age_group=p_age_group,
      allergies=p_allergies, spice_preference=p_spice_preference,
      dietary_needs=p_dietary_needs, health_conditions=p_health_conditions, notes=p_notes
    WHERE id=p_id AND user_id=auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END; $$;
GRANT EXECUTE ON FUNCTION upsert_family_profile(uuid,text,text,text,jsonb,text,jsonb,text[],text) TO authenticated;

CREATE OR REPLACE FUNCTION delete_family_profile(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.family_profiles WHERE id=p_id AND user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION delete_family_profile(uuid) TO authenticated;

-- ── DIETARY CARD PUBLIC RPCs (no auth) ───────────────────────────
-- Allows a guest to submit dietary requirements via their token
CREATE OR REPLACE FUNCTION submit_guest_dietary(
  p_token   uuid,
  p_dietary text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE event_guests SET
    dietary_requirements  = p_dietary,
    dietary_submitted     = true,
    dietary_submitted_at  = now()
  WHERE id = p_token;
END; $$;
GRANT EXECUTE ON FUNCTION submit_guest_dietary(uuid,text) TO anon, authenticated;
