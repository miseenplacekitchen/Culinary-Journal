-- garden-v4-07-seed-tomato-varieties.sql — auto-generated from _extracted_tomato.txt
-- Safe to re-run. Publishes cultivars for humid-subtropical + tropical-monsoon.

DO $$
DECLARE
  v_plant uuid;
  v_climate uuid;
  v_var uuid;
  v_ing integer;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'tomato' LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'tomato plant missing — run RUN-GARDEN-V3.sql first'; END IF;
  SELECT "ID" INTO v_ing FROM public.ingredients WHERE lower("Ingredient Name") LIKE '%tomato%' ORDER BY "ID" LIMIT 1;

  -- Grosse Lisse (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'grosse-lisse', 'Grosse Lisse', 'open_pollinated', 'Australia, 1970s standard', 'Indeterminate 2-3.5m, medium-large 6-10cm oblate', 'Smooth, firm, tangy sun-ripened', '80 days from seedlings, 15-20 tons/ha', 'Brisbane: Excellent subtropical. Sets fruit hot conditions. Improved disease resistance. Australian standard 50+ years.', 'Widely available: Qld nurseries, Bunnings, Diggers, Eden', 0, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'grosse-lisse');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'grosse-lisse' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent subtropical. Sets fruit hot conditions. Improved disease resistance. Australian standard 50+ years.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Grosse Lisse')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Tommy Toe (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'tommy-toe', 'Tommy Toe', 'heirloom', 'USA Ozark, early 1900s', 'Indeterminate 2.2-2.7m, cherry 2-3cm', 'Sweet, rich, firm, superior taste', 'Mid-late, 10kg+/plant, trusses 7-9', 'Brisbane: Outstanding subtropical, humidity adapted, disease tolerant. Diggers winner since 1993. Must-have for Brisbane.', 'Qld nurseries, Diggers, Eden, Green Harvest', 1, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tommy-toe');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tommy-toe' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Outstanding subtropical, humidity adapted, disease tolerant. Diggers winner since 1993. Must-have for Brisbane.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Tommy Toe')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Green Zebra (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'green-zebra', 'Green Zebra', 'heirloom', 'USA, Tom Wagner 1983', 'Indeterminate 1.5-2m, round 5-7cm striped', 'Rich, creamy, tangy-sweet, yellow-green ripe', 'Mid-season, excellent winter cropper', 'Brisbane: Good winter cropper, tolerates cooler temps. Distinctive appearance, good disease resistance humidity.', 'Specialty nurseries, Diggers, Seed Collection', 2, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'green-zebra');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'green-zebra' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Good winter cropper, tolerates cooler temps. Distinctive appearance, good disease resistance humidity.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Green Zebra')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Tigerella (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'tigerella', 'Tigerella', 'heirloom', 'UK 1970s', 'Indeterminate, medium red-orange stripes', 'Sweet-tangy balanced, firm, colorful', 'Early-mid, productive', 'Brisbane: Performs well subtropical. Good disease resistance. Attractive striped. Reliable garden variety.', 'Qld nurseries, online suppliers', 3, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tigerella');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tigerella' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Performs well subtropical. Good disease resistance. Attractive striped. Reliable garden variety.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Tigerella')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Roma / Mini Roma (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'roma-mini-roma', 'Roma / Mini Roma', 'open_pollinated', 'Italy, traditional paste', 'Determinate bush, plum, thick walls', 'Meaty, low moisture, mild, few seeds', 'Heavy yields, ripens together', 'Brisbane: Excellent subtropical, heat/humidity tolerant. Ideal sauces, canning. Mini Roma compact. Good disease resistance.', 'Very common - all Qld nurseries, Bunnings', 4, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'roma-mini-roma');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'roma-mini-roma' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent subtropical, heat/humidity tolerant. Ideal sauces, canning. Mini Roma compact. Good disease resistance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Roma / Mini Roma')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Black Russian (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'black-russian', 'Black Russian', 'heirloom', 'Russia/Ukraine', 'Indeterminate 1.5-2m, almost black, 4-6cm', 'Dark, sweet, pulpy plum-like, rich', 'Mid-season, moderate', 'Brisbane: Grows well but fruit fly prone - exclusion netting essential. Distinctive dark, excellent flavor. Best netted humid summers.', 'Specialty, Diggers, heirloom suppliers', 5, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-russian');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-russian' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Grows well but fruit fly prone - exclusion netting essential. Distinctive dark, excellent flavor. Best netted humid summers.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Black Russian')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Mortgage Lifter (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'mortgage-lifter', 'Mortgage Lifter', 'heirloom', 'USA, WV 1930s', 'Indeterminate, beefsteak to 500g', 'Pink-red, meaty, sweet low acidity', 'Mid-late, large need support', 'Brisbane: Personal best performer. Strong staking required. Good subtropical. Excellent slicing.', 'Heirloom suppliers, Diggers, Eden', 6, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'mortgage-lifter');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'mortgage-lifter' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Personal best performer. Strong staking required. Good subtropical. Excellent slicing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Mortgage Lifter')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Black Cherry (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'black-cherry', 'Black Cherry', 'heirloom', 'USA Florida, V.Sapp modern', 'Indeterminate, cherry 3cm, purple-black', 'Rich, sweet, smoky, complex', '10-12 weeks, prolific clusters', 'Brisbane: Bred for warm humid Florida - perfect! Excellent disease/heat tolerance. Vigorous, productive. Sow Mar-Sep.', 'Succeed Heirlooms, Seed Collection', 7, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-cherry');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-cherry' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Bred for warm humid Florida - perfect! Excellent disease/heat tolerance. Vigorous, productive. Sow Mar-Sep.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Black Cherry')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Apollo Improved (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'apollo-improved', 'Apollo Improved', 'hybrid', 'Australia, F1', 'Indeterminate, early, firm', 'Mild, low acid', 'Sets at 10°C, early producer', 'Brisbane: Excellent mild winters. Improved bacterial wilt, nematode resistance. Firmer fruit. Good all-season subtropical.', 'Qld nurseries, commercial suppliers', 8, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'apollo-improved');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'apollo-improved' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent mild winters. Improved bacterial wilt, nematode resistance. Firmer fruit. Good all-season subtropical.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Apollo Improved')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Beefsteak (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'beefsteak', 'Beefsteak', 'open_pollinated', 'Traditional large', 'Open-pollinated, 1-1.5m, 10-12cm oblate', 'Meaty, firm, rich, classic slicing', 'Mid-season, sturdy, moderate', 'Brisbane: Performs well with support. Heavy fruits need staking. Good heat. Excellent fresh, sandwiches.', 'Common Qld nurseries', 9, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'beefsteak');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'beefsteak' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Performs well with support. Heavy fruits need staking. Good heat. Excellent fresh, sandwiches.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Beefsteak')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Scorpio (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'scorpio', 'Scorpio', 'indigenous', 'Queensland, bred for subtropical/tropical', 'Indeterminate, standard red', 'Tasty, firm, good quality', '10-12 weeks, good yields', 'Brisbane: BRED FOR QUEENSLAND! Tolerates humid subtropical/tropical. Resistant bacterial/fusarium wilts. Local adaptation excellent.', 'Succeed Heirlooms, Qld suppliers', 10, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scorpio');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scorpio' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: BRED FOR QUEENSLAND! Tolerates humid subtropical/tropical. Resistant bacterial/fusarium wilts. Local adaptation excellent.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Scorpio')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Scoresby Dwarf (KY1) (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'scoresby-dwarf-ky1', 'Scoresby Dwarf (KY1)', 'heirloom', 'Australian heirloom', 'Determinate, compact, round 5cm', 'Rich, ideal sauces', 'Very productive, good disease resistance', 'Brisbane: Australian heritage, locally adapted. Compact for small gardens/containers. Good disease resistance humidity. Excellent sauces.', 'Succeed Heirlooms Australia', 11, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scoresby-dwarf-ky1');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scoresby-dwarf-ky1' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Australian heritage, locally adapted. Compact for small gardens/containers. Good disease resistance humidity. Excellent sauces.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Scoresby Dwarf (KY1)')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Cherokee Purple (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'cherokee-purple', 'Cherokee Purple', 'heirloom', 'USA Cherokee, pre-1890', 'Indeterminate, 10-12oz, mahogany green shoulders', 'Classic old-time, sweet rich', 'Mid-season, moderate large', 'Brisbane: Loves wet heat - perfect humid summers! Not dry heat. Excellent disease resistance. Solid production. Rich complex. Green shoulders normal.', 'Heirloom suppliers, Diggers, widely available', 12, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'cherokee-purple');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'cherokee-purple' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Loves wet heat - perfect humid summers! Not dry heat. Excellent disease resistance. Solid production. Rich complex. Green shoulders normal.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Cherokee Purple')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- San Marzano (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'san-marzano', 'San Marzano', 'heirloom', 'Italy, traditional paste', 'Indeterminate, plum, thick-walled', 'Classic Italian, ideal sauces, meaty', 'Very productive long hot, excellent disease', 'Brisbane: Top heat-tolerant performer. Incredibly productive long hot seasons. Excellent disease resistance humidity. Perfect canning, roasting, sauces.', 'Common - most Qld nurseries, Italian', 13, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'san-marzano');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'san-marzano' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Top heat-tolerant performer. Incredibly productive long hot seasons. Excellent disease resistance humidity. Perfect canning, roasting, sauces.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: San Marzano')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Chadwick Cherry / Camp Joy (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'chadwick-cherry-camp-joy', 'Chadwick Cherry / Camp Joy', 'heirloom', 'Extreme heat-tolerant', 'Cherry, extreme heat tolerance', 'Sets fruit to 45°C (115°F)', 'Continues producing extreme heat', 'Brisbane: Excellent hottest summer (Jan-Feb). Rare ability set fruit extreme temps. Good backup heat waves.', 'Specialty heat-tolerant suppliers', 14, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'chadwick-cherry-camp-joy');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'chadwick-cherry-camp-joy' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent hottest summer (Jan-Feb). Rare ability set fruit extreme temps. Good backup heat waves.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Chadwick Cherry / Camp Joy')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Bite Size (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'bite-size', 'Bite Size', 'hybrid', 'F1 hybrid', 'Indeterminate 2.2-2.7m, cherry 3cm', 'Sweet, firm, thick-skinned', '77-84 days, 20-50 per truss', 'Brisbane: Disease resistance package. Train to three leaders. Vigorous long season.', 'Seedlings, commercial nurseries', 15, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bite-size');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bite-size' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Disease resistance package. Train to three leaders. Vigorous long season.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Bite Size')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Sun Gold (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'sun-gold', 'Sun Gold', 'hybrid', 'Hybrid', 'Indeterminate 2m, golden cherry 1.5-2cm', 'Extremely sweet, bright golden', '100+ per truss, mid-late', 'Brisbane: Popular subtropical. Very sweet, children love. Prolific warm season. Good humidity.', 'Common - Qld nurseries, Bunnings', 16, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sun-gold');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sun-gold' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Popular subtropical. Very sweet, children love. Prolific warm season. Good humidity.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Sun Gold')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Sugarlump Cherry (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'sugarlump-cherry', 'Sugarlump Cherry', 'open_pollinated', 'Heritage', 'Cherry ombre color, large trusses', 'Sweet, colorful, attractive', 'Prolific, heavy trusses', 'Brisbane: Extensively tested excellent autumn. One of best for Brisbane. Good subtropical. Attractive ombre.', 'Love of Dirt (Brisbane), specialty', 17, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sugarlump-cherry');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sugarlump-cherry' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Extensively tested excellent autumn. One of best for Brisbane. Good subtropical. Attractive ombre.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Sugarlump Cherry')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Thai Pink Egg (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'thai-pink-egg', 'Thai Pink Egg', 'heirloom', 'Thailand, Asian', 'Egg-shaped, white to rich pink', 'Distinctive pink, unique shape', 'Good warm climates', 'Brisbane: Asian tropical origin excellent subtropical. Heat/humidity adapted. Unique appearance. Good warm humid performance.', 'Succeed Heirlooms, Asian variety', 18, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thai-pink-egg');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thai-pink-egg' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Asian tropical origin excellent subtropical. Heat/humidity adapted. Unique appearance. Good warm humid performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Thai Pink Egg')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Amish Paste (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'amish-paste', 'Amish Paste', 'heirloom', 'USA Amish, pre-1900', 'Indeterminate, large paste plum', 'Meaty, thick-walled, few seeds', '12-14 weeks, heavy producer', 'Brisbane: One of best for sauces. Performs subtropical with disease management. Heat tolerant. Excellent cooking, canning.', 'Succeed Heirlooms, heirloom suppliers', 19, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'amish-paste');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'amish-paste' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: One of best for sauces. Performs subtropical with disease management. Heat tolerant. Excellent cooking, canning.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Amish Paste')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Pink Brandywine (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pink-brandywine', 'Pink Brandywine', 'heirloom', 'USA, Brandywine heat strain', 'Indeterminate, large to 2 pounds', 'Creamy, rich, perfect balance, pink', 'Large, moderate, long season', 'Brisbane: Better heat tolerance. Needs consistent watering, partial shade hottest months. Continues setting fruit heat. Best heat-tolerant heirloom flavor.', 'Heirloom suppliers, heat-tolerant specialists', 20, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pink-brandywine');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pink-brandywine' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Better heat tolerance. Needs consistent watering, partial shade hottest months. Continues setting fruit heat. Best heat-tolerant heirloom flavor.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pink Brandywine')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Pruden's Purple (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pruden-s-purple', 'Pruden''s Purple', 'heirloom', 'USA, potato-leaf', 'Early maturity, large smooth pink', 'Rich, tangy, firm, pink', 'Early, good before peak heat', 'Brisbane: Early maturity ideal - harvest before intense heat. Lower cracking humidity. Solid disease. Good autumn for spring harvest.', 'Heirloom suppliers, early-season', 21, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pruden-s-purple');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pruden-s-purple' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Early maturity ideal - harvest before intense heat. Lower cracking humidity. Solid disease. Good autumn for spring harvest.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pruden''s Purple')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Black Krim (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'black-krim', 'Black Krim', 'heirloom', 'Crimea, Ukraine', 'Indeterminate, beefsteak, dark mahogany', 'Slightly salty, rich, dark', 'Mid-late, good large', 'Brisbane: Performs well subtropical. Attractive dark. Rich complex. Good heat. Needs netting birds/fruit fly humidity.', 'Common heirloom - Diggers, most suppliers', 22, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-krim');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-krim' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Performs well subtropical. Attractive dark. Rich complex. Good heat. Needs netting birds/fruit fly humidity.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Black Krim')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Costoluto Genovese (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'costoluto-genovese', 'Costoluto Genovese', 'heirloom', 'Italy Genoa, traditional', 'Highly ribbed/fluted, indeterminate', 'Rich, intense, meaty', 'Good yields, mid-season', 'Brisbane: Italian warm climates similar Brisbane. Distinctive ribbed attractive. Excellent fresh/cooking. Good subtropical.', 'Italian variety specialists, heirloom', 23, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'costoluto-genovese');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'costoluto-genovese' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Italian warm climates similar Brisbane. Distinctive ribbed attractive. Excellent fresh/cooking. Good subtropical.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Costoluto Genovese')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Gardener's Delight (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'gardener-s-delight', 'Gardener''s Delight', 'heirloom', 'German, Sugar Lump', 'Indeterminate, sweet cherry', 'Exceptional sweetness, balanced', 'Very prolific, long harvesting', 'Brisbane: Excellent subtropical. Long harvesting extended season. Sweet family favorite. Reliable producer.', 'Common heirloom - widely available', 24, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'gardener-s-delight');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'gardener-s-delight' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent subtropical. Long harvesting extended season. Sweet family favorite. Reliable producer.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Gardener''s Delight')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Pusa Ruby (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-ruby', 'Pusa Ruby', 'open_pollinated', 'IARI Delhi, widely grown', 'Semi-determinate, round, thick glossy skin, yellow stem end', 'Deep red, firm, balanced sugar-acid', '25-32 tons/ha, 90-100 days transplanting', 'Kerala: Highly popular, most widely grown India. Adaptable to climatic changes and soil types. Good pest resistance, thrives extreme conditions. Suitable spring-summer, autumn-winter. Both table and processing.', 'Widely available all Kerala nurseries, IARI', 0, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-ruby');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-ruby' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Highly popular, most widely grown India. Adaptable to climatic changes and soil types. Good pest resistance, thrives extreme conditions. Suitable spring-summer, autumn-winter. Both table and processing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Ruby')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Rakshak (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-rakshak', 'Arka Rakshak', 'hybrid', 'IIHR Bangalore', 'Indeterminate, disease-resistant', 'Round, firm, good quality', '19 kg per plant, excellent yields', 'Kerala: HIGH-YIELDING &amp; DISEASE-RESISTANT. Crossing high-yielding F1. Resistant to ToLCV, bacterial wilt, early blight. Specifically developed for South India. Excellent tropical monsoon performance.', 'Kerala nurseries, IIHR, Indian Agricultural suppliers', 1, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-rakshak');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-rakshak' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: HIGH-YIELDING &amp; DISEASE-RESISTANT. Crossing high-yielding F1. Resistant to ToLCV, bacterial wilt, early blight. Specifically developed for South India. Excellent tropical monsoon performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Rakshak')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Abhijith (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-abhijith', 'Arka Abhijith', 'hybrid', 'IIHR Bangalore, F1 hybrid', 'Medium plant, bright red, 65-70g fruits', 'Good taste, suitable fresh and processing', '65 tons/ha in 140 days', 'Kerala: High-yielding for fresh market. Developed by IIHR specifically for Indian conditions. Good disease resistance. Performs well tropical monsoon.', 'Kerala nurseries, IIHR Bangalore', 2, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-abhijith');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-abhijith' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding for fresh market. Developed by IIHR specifically for Indian conditions. Good disease resistance. Performs well tropical monsoon.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Abhijith')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Samrat (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-samrat', 'Arka Samrat', 'hybrid', 'IIHR Bangalore', 'Determinate, uniform firm fruits', 'Rich taste, texture ideal for ketchup/puree', 'Good yields', 'Kerala: Popular for making ketchup and puree. Determinate - all fruit ripens together for processing. Good tropical adaptation. Uniform quality.', 'Kerala nurseries, IIHR', 3, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-samrat');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-samrat' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Popular for making ketchup and puree. Determinate - all fruit ripens together for processing. Good tropical adaptation. Uniform quality.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Samrat')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Saurabh (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-saurabh', 'Arka Saurabh', 'hybrid', 'IIHR Bangalore hybrid', 'High-yielding, medium-sized juicy', 'Juicy, good quality', 'Adaptable to various climates', 'Kerala: High-yielding hybrid. Medium-sized juicy fruits. Preferred for adaptability to various climatic conditio', '', 4, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-saurabh');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-saurabh' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding hybrid. Medium-sized juicy fruits. Preferred for adaptability to various climatic conditio')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Saurabh')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
END $$;

INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload)
VALUES ('brainstorm-inbox/_extracted_tomato.txt', 'Tomato', 'tomato', 'multi', 'approved', 30,
 '{"generated": true, "variety_count": 30}'::jsonb)
;

SELECT 'garden-v4-07-seed-tomato-varieties ready — 30 varieties' AS status;