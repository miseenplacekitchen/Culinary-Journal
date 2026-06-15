-- fix-phase59-garden-cultivar-climate-copy.sql
-- Neutralize Brisbane/Kerala city labels in all cultivar text + climate suitability notes.
-- Climate-first policy: member UI filters by climate_zone; city names are ingest aliases only.
-- Safe to re-run.

CREATE OR REPLACE FUNCTION public.garden_neutralize_city_copy(t text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN t IS NULL OR btrim(t) = '' THEN t ELSE
    replace(
      replace(
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
        'Thiruvalla''s', 'Tropical monsoon'
      ),
      'Thiruvalla', 'tropical monsoon climates'
    )
  END;
$$;

UPDATE public.plant_varieties SET
  origin = public.garden_neutralize_city_copy(origin),
  traits = public.garden_neutralize_city_copy(traits),
  flesh_fruit = public.garden_neutralize_city_copy(flesh_fruit),
  yield_notes = public.garden_neutralize_city_copy(yield_notes),
  growing_notes = public.garden_neutralize_city_copy(growing_notes),
  availability = public.garden_neutralize_city_copy(availability),
  updated_at = now();

UPDATE public.variety_climate_suitability SET
  climate_notes = public.garden_neutralize_city_copy(climate_notes)
WHERE climate_notes IS NOT NULL AND btrim(climate_notes) <> '';

SELECT 'fix-phase59-garden-cultivar-climate-copy ready — '
  || (SELECT count(*)::text FROM public.plant_varieties)
  || ' cultivar row(s), '
  || (SELECT count(*)::text FROM public.variety_climate_suitability)
  || ' climate suitability row(s)' AS status;
