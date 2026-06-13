-- fix-phase57-garden-artichoke-profile.sql
-- Purple Romagna artichoke — Brisbane (humid-subtropical) full species profile.
-- Maps Excel cultivar label onto species shell `artichoke`. Safe to re-run.

DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'artichoke' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip artichoke — shell missing'; RETURN; END IF;

  UPDATE public.plants SET
    common_name = COALESCE(NULLIF(btrim(common_name), ''), 'Artichoke'),
    botanical_name = 'Cynara cardunculus var. scolymus',
    plant_family = 'Asteraceae',
    plant_type = 'Herbaceous perennial vegetable (often grown as annual in subtropics)',
    subspecies = 'Cynara cardunculus var. scolymus',
    taxonomic_authority = 'L.',
    genetic_lineage_type = 'Heirloom / open-pollinated Italian cultivar',
    variety_cultivar = 'Purple Romagna — Italian heirloom with violet-purple bracts and green tips; medium-large globes (8–12 cm); tender hearts; ornamental silver-grey foliage.',
    origin = 'Emilia-Romagna, Italy; traditional purple Italian globe artichoke adapted to Mediterranean climates.',
    growth_rate = 'Moderate — establishes in first season; peak bud production in year 2–3 in suitable climates.',
    size_height = '1.0–1.5 m height, 1.0–1.2 m spread under Brisbane conditions.',
    pollination_type = 'Cross-pollinated by bees; isolate varieties if saving seed.',
    flowering_season = 'Spring (September–November) when overwintered plants resume growth; flower buds harvested before opening.',
    propagation_methods = 'Division of suckers, root cuttings, or seed (seed-grown plants variable).',
    germination_time = '10–21 days at 18–24 °C when sown from seed.',
    time_to_harvest = '120–150 days from transplant to first harvestable buds (variety and season dependent).',
    planting_windows = 'Primary: March–May (autumn) transplant for spring harvest.
Secondary: July–August (late winter) for plants establishing through cool months.',
    harvest_season = 'Main harvest: August–November in Brisbane; side-shoot buds into early summer if plants persist.',
    harvesting_method = 'Cut central bud when tight and 8–12 cm, leaving 5–10 cm stem. Harvest side shoots (broccoli-sized) as they develop. Use sharp knife; wear gloves for spiny types (Purple Romagna is relatively soft-spined).',
    care_summary = 'Purple Romagna artichoke (Cynara cardunculus) is a silver-leaved perennial vegetable producing edible immature flower buds. In Brisbane''s humid subtropical climate it performs best as a cool-season crop: plant autumn to winter, harvest spring. Requires full sun, deep fertile soil, and consistent moisture. Perennial crowns can persist 3–5 years if drainage is excellent and summer humidity is managed.',
    edible_parts = 'Immature flower buds (hearts and fleshy bract bases); young leaf stalks (blanched cardoon-style).',
    culinary_applications = 'Steamed or grilled whole buds; marinated hearts; Roman-Jewish carciofi alla giudia; dips and antipasti.',
    updated_at = now()
  WHERE id = v_plant;

  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'climate', 'Brisbane humid subtropical suits autumn–spring cropping. Cool dry winters promote tight buds; mild springs extend harvest.', 'High summer humidity and heat cause stress, root rot, and aphid/botrytis pressure. Heavy summer rain rots dormant crowns.', 'Plant in autumn; harvest before peak humidity (Dec–Jan). Improve drainage; mulch lightly; allow partial shade in late spring heatwaves.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Deep, well-drained loam rich in organic matter; pH 6.0–7.5.', 'Clay soils waterlog crowns; sandy soils dry too fast.', 'Raised beds 30 cm deep; compost and gypsum on clay; drip irrigation on sand.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'ph', 'Optimal 6.5–7.0; tolerates 6.0–7.5.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', 'Full sun — minimum 6 hours direct light daily.', 'Weak buds in shade.', 'Open north-facing position; avoid overhanging trees.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Consistent moisture during bud formation; reduce slightly in dormant summer if crowns persist.', 'Irregular watering yields small or hollow buds; crown rot if waterlogged in heat.', 'Drip irrigation; mulch; ensure drainage in summer storms.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Light frost tolerant once established; young transplants need protection below 2 °C.', 'Severe frost damages new growth.', 'Cover with fleece on cold nights Mar–Aug.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'fertilisation', 'Compost at planting; balanced organic feed in spring bud swell; low nitrogen mid-summer.', 'Excess nitrogen → leafy growth, few buds.', 'Side-dress compost and potassium-rich fertiliser Aug–Sep.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'mulching', '5 cm organic mulch in spring; keep crown base clear to prevent rot.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pruning', 'Remove spent central bud to encourage side shoots; cut back dead foliage in summer dormancy.', 'Overcrowded foliage increases disease.', 'Trim to 4–6 healthy shoots per crown after main harvest.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'companions', 'Good: tarragon, nasturtium, yarrow, calendula (pollinator support).', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'incompatibles', 'Avoid potatoes and heavy feeders competing for same bed without rotation.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Aphids on buds; snails on young leaves; caterpillars occasionally.', 'Black aphid colonies in spring reduce bud quality.', 'Blast with water; encourage beneficials; organic soap if needed; snail traps after rain.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'seasonal_risk', 'Summer humidity → crown rot and reduced vigour; plan autumn replanting if crowns fail.', '', 'Lift and divide healthy crowns in autumn; discard rotted centres.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 3, 5, 'Autumn transplant of divisions or potted seedlings'
    WHERE NOT EXISTS (SELECT 1 FROM public.plant_calendar pc WHERE pc.plant_id = v_plant AND pc.activity = 'transplant' AND pc.month_start = 3 AND pc.month_end = 5);

    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'harvest', 8, 11, 'Main bud harvest — central then side shoots'
    WHERE NOT EXISTS (SELECT 1 FROM public.plant_calendar pc WHERE pc.plant_id = v_plant AND pc.activity = 'harvest' AND pc.month_start = 8 AND pc.month_end = 11);

    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'prune', 12, 2, 'Trim spent stems; divide overcrowded crowns if persisting as perennial'
    WHERE NOT EXISTS (SELECT 1 FROM public.plant_calendar pc WHERE pc.plant_id = v_plant AND pc.activity = 'prune' AND pc.month_start = 12 AND pc.month_end = 2);
  END IF;

  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
  SELECT v_plant, sub.ing_id, 'bud', true
  FROM (
    SELECT "ID" AS ing_id FROM public.ingredients
    WHERE lower("Ingredient Name") LIKE '%artichoke%'
    ORDER BY "ID" LIMIT 1
  ) sub
  WHERE sub.ing_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);
END $$;

SELECT 'fix-phase57-garden-artichoke-profile ready — Purple Romagna Brisbane' AS status;
