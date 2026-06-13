-- fix-phase54-garden-kitchen-profiles.sql
-- Kitchen-priority species: care summary, humid-subtropical care fields, calendar, ingredient hinge.
-- Safe to re-run. Does NOT auto-publish — publish each species in GM when curated.

-- Bell Pepper / Capsicum (Capsicum annuum) (bell-pepper)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'bell-pepper' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip bell-pepper — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Capsicum annuum'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Solanaceae'),
    care_summary = 'Curated Bell Pepper / Capsicum (Capsicum annuum) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Bell Pepper / Capsicum (Capsicum annuum) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Start indoors or buy seedlings before peak heat'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 10, 11, 'Plant out after frost risk; stake or trellis as needed'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 10 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 12, 4, 'Pick regularly to keep plants productive'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 12 AND pc.month_end = 4
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%bell pepper%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Basil (Ocimum spp.) (basil)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'basil' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip basil — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Mint family'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Lamiaceae (Mint family)'),
    care_summary = 'Curated Basil (Ocimum spp.) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Basil (Ocimum spp.) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 11, 'Succession sow in pots or direct; partial shade in hot months'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 1, 12, 'Pick leaves regularly to encourage bushy growth'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 1 AND pc.month_end = 12
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'prune', 10, 2, 'Trim flower heads on leafy herbs to extend leaf harvest'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'prune'
        AND pc.month_start = 10 AND pc.month_end = 2
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%basil%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Cucumber (cucumber)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'cucumber' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip cucumber — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Cucumis sativus'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Cucurbitaceae | Scientific Name: Cucumis sativus'),
    care_summary = 'Curated Cucumber profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Cucumber profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Start indoors or buy seedlings before peak heat'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 10, 11, 'Plant out after frost risk; stake or trellis as needed'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 10 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 12, 4, 'Pick regularly to keep plants productive'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 12 AND pc.month_end = 4
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%cucumber%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Spinach (Spinacia oleracea) (spinach)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'spinach' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip spinach — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Spinacia oleracea'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Amaranthaceae'),
    care_summary = 'Curated Spinach (Spinacia oleracea) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Spinach (Spinacia oleracea) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 9, 'Follow seed packet timing for Brisbane subtropical windows'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 12, 'Harvest young and often for best quality'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 12
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%spinach%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Carrot (carrot)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'carrot' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip carrot — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), ''),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), ''),
    care_summary = 'Curated Carrot profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Carrot profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 5, 'Direct sow or punnets; keep seed bed moist'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 5
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Autumn succession sowing for cooler harvest window'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 11, 'Harvest when size and colour indicate maturity'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 11
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%carrot%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Potato (potato)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'potato' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip potato — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Solanum tuberosum'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Solanaceae (Nightshade family)'),
    care_summary = 'Curated Potato profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Potato profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 5, 'Direct sow or punnets; keep seed bed moist'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 5
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Autumn succession sowing for cooler harvest window'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 11, 'Harvest when size and colour indicate maturity'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 11
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%potato%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Pumpkin (pumpkin)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'pumpkin' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip pumpkin — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Maori heirloom'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Cucurbitaceae'),
    care_summary = 'Curated Pumpkin profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Pumpkin profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Start indoors or buy seedlings before peak heat'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 10, 11, 'Plant out after frost risk; stake or trellis as needed'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 10 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 12, 4, 'Pick regularly to keep plants productive'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 12 AND pc.month_end = 4
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%pumpkin%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Zucchini (Cucurbita pepo) (zucchini)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'zucchini' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip zucchini — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Cucurbita pepo'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Cucurbitaceae'),
    care_summary = 'Curated Zucchini (Cucurbita pepo) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Zucchini (Cucurbita pepo) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Start indoors or buy seedlings before peak heat'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 10, 11, 'Plant out after frost risk; stake or trellis as needed'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 10 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 12, 4, 'Pick regularly to keep plants productive'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 12 AND pc.month_end = 4
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%zucchini%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Onion (Allium cepa) (onion)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'onion' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip onion — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Allium cepa'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Amaryllidaceae (formerly Alliaceae)'),
    care_summary = 'Curated Onion (Allium cepa) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Onion (Allium cepa) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 9, 'Follow seed packet timing for Brisbane subtropical windows'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 12, 'Harvest young and often for best quality'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 12
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%onion%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Garlic (garlic)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'garlic' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip garlic — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Allium sativum'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Amaryllidaceae (formerly Alliaceae)'),
    care_summary = 'Curated Garlic profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Garlic profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 9, 'Follow seed packet timing for Brisbane subtropical windows'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 12, 'Harvest young and often for best quality'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 12
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%garlic%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Coriander (coriander)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'coriander' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip coriander — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Coriandrum sativum'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Apiaceae (Umbelliferae) - Carrot family'),
    care_summary = 'Curated Coriander profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Coriander profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 11, 'Succession sow in pots or direct; partial shade in hot months'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 1, 12, 'Pick leaves regularly to encourage bushy growth'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 1 AND pc.month_end = 12
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'prune', 10, 2, 'Trim flower heads on leafy herbs to extend leaf harvest'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'prune'
        AND pc.month_start = 10 AND pc.month_end = 2
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%coriander%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Peas (Pisum sativum) (peas)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'peas' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip peas — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Pisum sativum'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Fabaceae (Leguminosae)'),
    care_summary = 'Curated Peas (Pisum sativum) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Peas (Pisum sativum) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 9, 'Follow seed packet timing for Brisbane subtropical windows'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 12, 'Harvest young and often for best quality'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 12
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%peas%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Chilli (Capsicum spp.) (chili-pepper)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'chili-pepper' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip chili-pepper — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Nightshade family'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), ''),
    care_summary = 'Curated Chilli (Capsicum spp.) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Chilli (Capsicum spp.) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 9, 'Start indoors or buy seedlings before peak heat'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 10, 11, 'Plant out after frost risk; stake or trellis as needed'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 10 AND pc.month_end = 11
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 12, 4, 'Pick regularly to keep plants productive'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 12 AND pc.month_end = 4
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%chili pepper%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Strawberry (strawberry)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'strawberry' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip strawberry — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Fragaria vesca'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Rosaceae'),
    care_summary = 'Curated Strawberry profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Strawberry profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 9, 'Follow seed packet timing for Brisbane subtropical windows'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 12, 'Harvest young and often for best quality'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 12
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%strawberry%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

-- Broccoli (Brassica oleracea var. italica) (broccoli)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'broccoli' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip broccoli — plant shell missing'; RETURN; END IF;
  UPDATE public.plants SET
    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), 'Chinese broccoli'),
    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), 'Brassicaceae'),
    care_summary = 'Curated Broccoli (Brassica oleracea var. italica) profile — see cultivar notes for Brisbane and Kerala picks.',
    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),
    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', '6+ hours direct sun (partial shade in peak summer for delicate crops)', 'Leggy or scorched plants', 'Adjust position or use shade cloth Dec–Feb')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Even moisture; avoid wet foliage overnight', 'Split fruit, fungal issues', 'Mulch and water at soil level mornings')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Rich, well-drained compost; pH suited to crop', 'Poor drainage or nutrient lock-out', 'Raised beds or large pots with fresh mix')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Protect frost-tender crops in cool snaps', 'Blackened or stalled growth', 'Cover, move pots, or delay planting')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Curated Broccoli (Brassica oleracea var. italica) profile — see cultivar notes for Brisbane and Kerala picks.', 'Aphids, caterpillars, snails after rain', 'Inspect weekly; hand pick; hose blast early infestations')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 3, 9, 'Follow seed packet timing for Brisbane subtropical windows'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 3 AND pc.month_end = 9
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 6, 12, 'Harvest young and often for best quality'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'harvest'
        AND pc.month_start = 6 AND pc.month_end = 12
    );
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'fruit', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%broccoli%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

SELECT 'fix-phase54-garden-kitchen-profiles ready — 15 species' AS status;