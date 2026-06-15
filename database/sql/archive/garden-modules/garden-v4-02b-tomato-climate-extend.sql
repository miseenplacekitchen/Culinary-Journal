-- garden-v4-02b-tomato-climate-extend.sql — mirror warm-temperate care/calendar to humid-subtropical for tomato

INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
SELECT p.id, cz_new.id, cc.field_key, cc.core, cc.risk, cc.fix
FROM public.plants p
JOIN public.plant_climate_care cc ON cc.plant_id = p.id
JOIN public.climate_zones cz_old ON cz_old.id = cc.climate_zone_id AND cz_old.slug = 'warm-temperate'
JOIN public.climate_zones cz_new ON cz_new.slug = 'humid-subtropical'
WHERE p.slug = 'tomato'
ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
  core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
SELECT p.id, cz_new.id, pc.activity, pc.month_start, pc.month_end, pc.notes
FROM public.plants p
JOIN public.plant_calendar pc ON pc.plant_id = p.id
JOIN public.climate_zones cz_old ON cz_old.id = pc.climate_zone_id AND cz_old.slug = 'warm-temperate'
JOIN public.climate_zones cz_new ON cz_new.slug = 'humid-subtropical'
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_calendar ex
    WHERE ex.plant_id = p.id AND ex.climate_zone_id = cz_new.id
      AND ex.activity = pc.activity AND ex.month_start = pc.month_start
  );

SELECT 'garden-v4-02b-tomato-climate-extend ready' AS status;
