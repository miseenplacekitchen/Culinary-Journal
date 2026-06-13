-- garden-v4-15-batch-apply-imports.sql
-- Apply all import-queue payloads that have a matching species shell.
-- Requires: garden-v4-14 species shells + garden-v4-09 import RPCs.
-- Safe to re-run — skips rows already approved.

-- Allow SQL Editor (postgres) as well as authenticated admin sessions
CREATE OR REPLACE FUNCTION public.admin_apply_garden_import(p_queue_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row garden_import_queue%ROWTYPE;
  v_plant uuid;
  v_climate uuid;
  v_var uuid;
  v_ing integer;
  v_item jsonb;
  v_slug text;
  v_inserted int := 0;
  v_updated int := 0;
BEGIN
  IF NOT is_admin() AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  SELECT * INTO v_row FROM garden_import_queue WHERE id = p_queue_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'import queue row not found';
  END IF;
  IF v_row.payload IS NULL OR v_row.payload->'varieties' IS NULL THEN
    RAISE EXCEPTION 'payload missing varieties array';
  END IF;

  SELECT id INTO v_plant FROM plants WHERE slug = COALESCE(v_row.species_slug, v_row.payload->>'species_slug') LIMIT 1;
  IF v_plant IS NULL THEN
    RAISE EXCEPTION 'species plant row missing for slug % — seed species before applying cultivars',
      COALESCE(v_row.species_slug, v_row.payload->>'species_slug');
  END IF;

  SELECT "ID" INTO v_ing FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%' || lower(COALESCE(v_row.species_slug, '')) || '%'
  ORDER BY "ID" LIMIT 1;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_row.payload->'varieties')
  LOOP
    v_slug := v_item->>'slug';
    IF v_slug IS NULL OR v_slug = '' THEN
      CONTINUE;
    END IF;

    INSERT INTO plant_varieties (
      plant_id, slug, name, lineage_type, origin, traits, flesh_fruit,
      yield_notes, growing_notes, availability, sort_order, is_published
    ) VALUES (
      v_plant,
      v_slug,
      COALESCE(v_item->>'name', v_slug),
      COALESCE(v_item->>'lineage_type', 'open_pollinated'),
      v_item->>'origin',
      v_item->>'traits',
      COALESCE(v_item->>'flesh_fruit', v_item->>'flesh'),
      COALESCE(v_item->>'yield_notes', v_item->>'yield'),
      COALESCE(v_item->>'growing_notes', v_item->>'notes'),
      v_item->>'availability',
      COALESCE((v_item->>'sort_order')::int, 0),
      true
    )
    ON CONFLICT (plant_id, slug) DO UPDATE SET
      name = EXCLUDED.name,
      lineage_type = EXCLUDED.lineage_type,
      origin = EXCLUDED.origin,
      traits = EXCLUDED.traits,
      flesh_fruit = EXCLUDED.flesh_fruit,
      yield_notes = EXCLUDED.yield_notes,
      growing_notes = EXCLUDED.growing_notes,
      availability = EXCLUDED.availability,
      sort_order = EXCLUDED.sort_order,
      is_published = true,
      updated_at = now()
    RETURNING id INTO v_var;

    v_inserted := v_inserted + 1;

    SELECT id INTO v_climate FROM climate_zones WHERE slug = v_item->>'climate_slug' LIMIT 1;
    IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
      INSERT INTO variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
      VALUES (
        v_var, v_climate, 'recommended',
        left(COALESCE(v_item->>'growing_notes', v_item->>'notes', ''), 500)
      )
      ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
      v_updated := v_updated + 1;

      IF v_ing IS NOT NULL THEN
        INSERT INTO variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
        VALUES (v_var, v_ing, 'fruit', true, 'Variety: ' || COALESCE(v_item->>'name', v_slug))
        ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
      END IF;
    END IF;
  END LOOP;

  UPDATE garden_import_queue
  SET status = 'approved', processed_at = now(), variety_count = v_inserted
  WHERE id = p_queue_id;

  RETURN jsonb_build_object(
    'queue_id', p_queue_id,
    'species_slug', v_row.species_slug,
    'varieties_upserted', v_inserted,
    'climate_links', v_updated
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_all_garden_imports()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_result jsonb;
  v_ok int := 0;
  v_fail int := 0;
  v_errors jsonb := '[]'::jsonb;
BEGIN
  IF NOT is_admin() AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  FOR r IN
    SELECT q.id, q.species_slug, q.species_name
    FROM public.garden_import_queue q
    WHERE q.payload IS NOT NULL
      AND q.payload->'varieties' IS NOT NULL
      AND jsonb_array_length(q.payload->'varieties') > 0
      AND q.status IN ('pending', 'parsed', 'staging')
      AND EXISTS (
        SELECT 1 FROM public.plants p
        WHERE p.slug = COALESCE(q.species_slug, q.payload->>'species_slug')
      )
    ORDER BY q.species_name
  LOOP
    BEGIN
      v_result := public.admin_apply_garden_import(r.id);
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'species_slug', r.species_slug,
        'species_name', r.species_name,
        'error', SQLERRM
      ));
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'applied', v_ok,
    'failed', v_fail,
    'errors', v_errors
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_apply_garden_import(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_apply_all_garden_imports() TO authenticated;

SELECT public.admin_apply_all_garden_imports() AS batch_result;

SELECT status, count(*) AS rows
FROM public.garden_import_queue
GROUP BY status
ORDER BY status;

SELECT count(*) AS published_cultivars
FROM public.plant_varieties
WHERE is_published = true;

SELECT 'garden-v4-15-batch-apply-imports ready' AS status;
