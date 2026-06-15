-- garden-v4-03-user-climate.sql — climate-first member preference (direct climate, region optional)

ALTER TABLE public.user_regions
  ADD COLUMN IF NOT EXISTS climate_zone_id uuid REFERENCES public.climate_zones(id) ON DELETE SET NULL;

-- region_id optional when climate set directly
ALTER TABLE public.user_regions ALTER COLUMN region_id DROP NOT NULL;

DROP FUNCTION IF EXISTS public.set_my_garden_climate(uuid);
CREATE OR REPLACE FUNCTION public.set_my_garden_climate(p_climate_zone_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.climate_zones WHERE id = p_climate_zone_id) THEN
    RAISE EXCEPTION 'climate_not_found';
  END IF;
  INSERT INTO public.user_regions (user_id, climate_zone_id, region_id)
  VALUES (auth.uid(), p_climate_zone_id, NULL)
  ON CONFLICT (user_id) DO UPDATE SET climate_zone_id = EXCLUDED.climate_zone_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_my_garden_climate(uuid) TO authenticated;

-- Resolve member climate: direct preference → region cascade
CREATE OR REPLACE FUNCTION public.garden_user_climate_id(p_user_id uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(ur.climate_zone_id, r.climate_zone_id)
  FROM public.user_regions ur
  LEFT JOIN public.regions r ON r.id = ur.region_id
  WHERE ur.user_id = p_user_id
  LIMIT 1;
$$;

SELECT 'garden-v4-03-user-climate ready' AS status;
