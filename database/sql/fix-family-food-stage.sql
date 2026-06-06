-- Baby / toddler food stage on family profiles (Master list §1)

ALTER TABLE public.family_profiles
  ADD COLUMN IF NOT EXISTS baby_food_stage text;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'upsert_family_profile' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.upsert_family_profile(
  p_id                uuid    DEFAULT NULL,
  p_name              text    DEFAULT '',
  p_relationship      text    DEFAULT 'guest',
  p_age_group         text    DEFAULT 'adult',
  p_allergies         jsonb   DEFAULT '[]',
  p_spice_preference  text    DEFAULT 'medium',
  p_dietary_needs     jsonb   DEFAULT '[]',
  p_health_conditions text[]  DEFAULT '{}',
  p_notes             text    DEFAULT '',
  p_baby_food_stage   text    DEFAULT NULL
)
RETURNS public.family_profiles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.family_profiles;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.family_profiles (
      user_id, name, relationship, age_group, allergies, spice_preference,
      dietary_needs, health_conditions, notes, baby_food_stage
    ) VALUES (
      auth.uid(), p_name, p_relationship, p_age_group, p_allergies, p_spice_preference,
      p_dietary_needs, p_health_conditions, p_notes, p_baby_food_stage
    ) RETURNING * INTO result;
  ELSE
    UPDATE public.family_profiles SET
      name = p_name, relationship = p_relationship, age_group = p_age_group,
      allergies = p_allergies, spice_preference = p_spice_preference,
      dietary_needs = p_dietary_needs, health_conditions = p_health_conditions,
      notes = p_notes, baby_food_stage = p_baby_food_stage
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_family_profile(
  uuid, text, text, text, jsonb, text, jsonb, text[], text, text
) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-family-food-stage.sql complete' AS status;
