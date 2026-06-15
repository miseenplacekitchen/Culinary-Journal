-- fix-phase58-garden-climate-copy.sql
-- Rewrite city-named care/profile copy → climate-first language (humid-subtropical / tropical-monsoon).
-- Inbox Excel/docx use Brisbane/Kerala as aliases only; live DB keys care by climate_zone_id.
-- Safe to re-run.

CREATE OR REPLACE FUNCTION public._garden_neutralize_city_copy(t text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(btrim(t), 'Brisbane''s humid subtropical', 'Humid subtropical'),
                      'Brisbane''s', 'Humid subtropical'
                    ),
                    'under Brisbane conditions', 'in humid subtropical conditions'
                  ),
                  'in Brisbane', 'in humid subtropical climates'
                ),
                'Brisbane summers', 'humid subtropical summers'
              ),
              'Brisbane conditions', 'humid subtropical conditions'
            ),
            'Brisbane:', 'Humid subtropical:'
          ),
          'Brisbane', 'humid subtropical climates'
        ),
        'Kerala''s', 'Tropical monsoon'
      ),
      'Kerala', 'tropical monsoon climates'
    ),
    ''
  );
$$;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT pcc.id
    FROM public.plant_climate_care pcc
    JOIN public.plants p ON p.id = pcc.plant_id
    WHERE p.slug IN ('tomato', 'artichoke')
  LOOP
    UPDATE public.plant_climate_care SET
      core = public._garden_neutralize_city_copy(core),
      risk = public._garden_neutralize_city_copy(risk),
      fix = public._garden_neutralize_city_copy(fix)
    WHERE id = r.id;
  END LOOP;

  UPDATE public.plants SET
    care_summary = public._garden_neutralize_city_copy(care_summary),
    size_height = public._garden_neutralize_city_copy(size_height),
    flowering_season = public._garden_neutralize_city_copy(flowering_season),
    germination_time = public._garden_neutralize_city_copy(germination_time),
    planting_windows = public._garden_neutralize_city_copy(planting_windows),
    harvest_season = public._garden_neutralize_city_copy(harvest_season),
    harvesting_method = public._garden_neutralize_city_copy(harvesting_method),
    propagation_methods = public._garden_neutralize_city_copy(propagation_methods),
    time_to_harvest = public._garden_neutralize_city_copy(time_to_harvest),
    updated_at = now()
  WHERE slug IN ('tomato', 'artichoke');

  UPDATE public.plant_calendar SET
    notes = public._garden_neutralize_city_copy(notes)
  WHERE plant_id IN (SELECT id FROM public.plants WHERE slug IN ('tomato', 'artichoke'));
END $$;

DROP FUNCTION IF EXISTS public._garden_neutralize_city_copy(text);

SELECT 'fix-phase58-garden-climate-copy ready — tomato + artichoke care copy climate-neutral' AS status;
