-- =============================================================================
-- THE CULINARY JOURNAL — RUN ALL REMAINING LIVE STEPS
-- Paste entire file in Supabase SQL Editor after site code deploy.
-- Order: library batch 44 → site fill 45 → health verification.
-- =============================================================================


-- ########## BEGIN: fix-phase44-library-profiles.sql ##########
-- fix-phase44-library-profiles.sql
-- Carrot, celery, honey, spinach, coriander (unified library_profiles).
-- Safe to re-run. Run in Supabase SQL Editor after RUN-LIVE-CLEANUP.sql.

INSERT INTO public.library_profiles (
  profile_type, slug, name, also_known_as, status, visibility, details
) VALUES
('ingredient', 'carrot', 'Carrot', 'Gajar', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Sweet, earthy, crisp when raw; mellow and sweet when roasted.',
  'how_to_buy', 'Firm, bright colour; tops fresh if attached; avoid rubbery or cracked.',
  'how_to_store', 'Fridge crisper 2–3 weeks; remove tops to stop moisture loss.',
  'how_to_prep', 'Scrub or peel; cut even sizes for even cooking.',
  'chefs_notes', 'Roast at high heat to concentrate sugars; raw adds crunch and colour.',
  'did_you_know', 'Carrots were originally purple and yellow before orange varieties dominated.'
)),
('ingredient', 'celery', 'Celery', 'Celery stalks', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Clean, grassy, mildly bitter — backbone of mirepoix and stocks.',
  'how_to_buy', 'Crisp stalks that snap; pale green to green; leaves perky.',
  'how_to_store', 'Fridge upright in water or wrapped; use leaves in stock.',
  'how_to_prep', 'Stringy outer stalks fine for stock; tender inner for salads.',
  'chefs_notes', 'Salt draws moisture — balance in dressings; never overcook to grey mush.',
  'did_you_know', 'Celery was a luxury in Victorian times and used as a table centrepiece.'
)),
('ingredient', 'honey', 'Honey', 'Pure honey', 'published', 'public', jsonb_build_object(
  'category', 'Pantry',
  'flavour_profile', 'Floral sweetness — flavour varies by flower source.',
  'how_to_buy', 'Clear labelling of origin; avoid crystallised unless you want it.',
  'how_to_store', 'Cool pantry; crystallisation is natural — warm gently to reliquefy.',
  'how_to_prep', 'Measure with oiled spoon; add off heat to preserve aroma.',
  'chefs_notes', 'Never feed honey to infants under twelve months.',
  'did_you_know', 'Honey is one of the few foods that does not spoil when sealed properly.'
)),
('ingredient', 'spinach', 'Spinach', 'Palak, baby spinach', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Mild, mineral, tender — wilts to almost nothing.',
  'how_to_buy', 'Dry leaves, no slime; baby spinach for salads; bunches for cooking.',
  'how_to_store', 'Fridge in bag with paper towel; use within a few days.',
  'how_to_prep', 'Wash grit away; stem thick bunches; add huge volume — it collapses.',
  'chefs_notes', 'Blanch and shock for bright green; squeeze dry for fillings.',
  'did_you_know', 'Spinach iron content was overstated in early nutrition tables due to a decimal error.'
)),
('spice', 'coriander', 'Coriander', 'Cilantro seed, dhania', 'published', 'public', jsonb_build_object(
  'heat_level', 0,
  'flavour_wheel', 'Citrus, floral, warm — seed and leaf are different ingredients.',
  'how_to_toast', 'Toast seeds in dry pan until fragrant; grind fresh for curries.',
  'when_to_add', 'Ground early in wet masalas; whole seeds in pickles and tempering.',
  'chefs_notes', 'Leaves (cilantro) bolt in heat — grow in partial shade if gardening.',
  'did_you_know', 'Coriander is one of the oldest spices in recorded cuisine.'
))
ON CONFLICT (profile_type, slug) DO UPDATE SET
  name = EXCLUDED.name,
  also_known_as = EXCLUDED.also_known_as,
  status = EXCLUDED.status,
  visibility = EXCLUDED.visibility,
  details = EXCLUDED.details,
  updated_at = now();

-- Fuzzy governed-ingredient links
UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('carrot', 'carrots')
     OR lower("Ingredient Name") LIKE 'carrot,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'carrot' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'carrot' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('celery', 'celery stalks')
     OR lower("Ingredient Name") LIKE 'celery%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'celery' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'celery' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) = 'honey'
     OR lower("Ingredient Name") LIKE 'honey,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'honey' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'honey' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('spinach', 'baby spinach')
     OR lower("Ingredient Name") LIKE 'spinach%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'spinach' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'spinach' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('coriander', 'coriander seeds', 'coriander seed')
     OR lower("Ingredient Name") LIKE 'coriander%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) LIKE 'coriander seed%' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'spice' AND lp.slug = 'coriander' AND sub.ing_id IS NOT NULL;

SELECT profile_type, slug, name, status, governed_ingredient_id
FROM public.library_profiles
WHERE slug IN ('carrot', 'celery', 'honey', 'spinach', 'coriander')
ORDER BY profile_type, slug;
-- ########## END: fix-phase44-library-profiles.sql ##########

-- ########## BEGIN: fix-phase45-site-fill.sql ##########
-- fix-phase45-site-fill.sql
-- Festival dish slots, approve pending recipes, free-tier limit settings (off by default).
-- Safe to re-run. Run after fix-phase44-library-profiles.sql on live Supabase.

-- ── Festival dish slots (beyond Onam sadya) ───────────────────────────
INSERT INTO public.festival_dishes (festival_id, dish_name, section_label, sort_order)
SELECT f.id, d.name, d.section, d.ord
FROM public.festivals f
CROSS JOIN (VALUES
  ('eid', 'Dates & water', 'Iftar', 1),
  ('eid', 'Soup / shorba', 'Iftar', 2),
  ('eid', 'Samosas / pakoras', 'Iftar', 3),
  ('eid', 'Biryani or pilaf', 'Main', 4),
  ('eid', 'Grilled meat / kebabs', 'Main', 5),
  ('eid', 'Salad & raita', 'Sides', 6),
  ('eid', 'Dessert / sheer khurma', 'Sweet', 7),
  ('christmas', 'Roast main', 'Main', 1),
  ('christmas', 'Roast potatoes', 'Sides', 2),
  ('christmas', 'Steamed vegetables', 'Sides', 3),
  ('christmas', 'Gravy / jus', 'Sides', 4),
  ('christmas', 'Christmas pudding', 'Dessert', 5),
  ('christmas', 'Mince pies', 'Dessert', 6),
  ('diwali', 'Mithai / sweets platter', 'Sweets', 1),
  ('diwali', 'Savouries / namkeen', 'Snacks', 2),
  ('diwali', 'Main feast curry', 'Main', 3),
  ('diwali', 'Rice or bread', 'Main', 4),
  ('diwali', 'Chutney & pickle', 'Sides', 5),
  ('wedding', 'Welcome drinks', 'Reception', 1),
  ('wedding', 'Appetisers', 'Reception', 2),
  ('wedding', 'Main course — vegetarian', 'Feast', 3),
  ('wedding', 'Main course — non-vegetarian', 'Feast', 4),
  ('wedding', 'Rice / bread service', 'Feast', 5),
  ('wedding', 'Dessert table', 'Sweet', 6),
  ('thanksgiving', 'Roast turkey', 'Main', 1),
  ('thanksgiving', 'Stuffing', 'Sides', 2),
  ('thanksgiving', 'Cranberry sauce', 'Sides', 3),
  ('thanksgiving', 'Mashed potatoes', 'Sides', 4),
  ('thanksgiving', 'Pumpkin pie', 'Dessert', 5),
  ('easter', 'Roast lamb or ham', 'Main', 1),
  ('easter', 'Hot cross buns', 'Bakery', 2),
  ('easter', 'Spring vegetables', 'Sides', 3),
  ('easter', 'Simnel cake', 'Dessert', 4),
  ('lunar-new-year', 'Dumplings', 'Main', 1),
  ('lunar-new-year', 'Nian gao / rice cake', 'Sweet', 2),
  ('lunar-new-year', 'Fish dish', 'Main', 3),
  ('lunar-new-year', 'Longevity noodles', 'Main', 4),
  ('lunar-new-year', 'Tray of togetherness', 'Snacks', 5)
) AS d(slug, name, section, ord)
WHERE f.slug = d.slug
  AND NOT EXISTS (
    SELECT 1 FROM public.festival_dishes fd
    WHERE fd.festival_id = f.id AND fd.dish_name = d.name
  );

-- ── Approve all pending recipes (increases public browse content) ─────
UPDATE public.submitted_recipes
SET status = 'approved',
    approved_at = COALESCE(approved_at, now()),
    updated_at = now()
WHERE status = 'pending';

-- ── Free-tier limit settings (disabled until admin enables) ───────────
INSERT INTO public.site_settings (key, value) VALUES
  ('enforce_free_limits', 'false'),
  ('free_max_recipes', '10'),
  ('free_max_photo_imports_month', '5'),
  ('free_max_tables', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

SELECT jsonb_build_object(
  'status', 'fix-phase45-site-fill ready',
  'approved_now', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
  'pending_remaining', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'pending'),
  'festival_dish_counts', (
    SELECT jsonb_object_agg(f.slug, cnt)
    FROM (
      SELECT f2.slug, count(fd.id)::int AS cnt
      FROM public.festivals f2
      LEFT JOIN public.festival_dishes fd ON fd.festival_id = f2.id
      GROUP BY f2.slug
    ) f
  )
) AS phase45_summary;
-- ########## END: fix-phase45-site-fill.sql ##########

-- ########## BEGIN: SQL-EDITOR-health-check.sql ##########
-- =============================================================================
-- RUN IN SUPABASE SQL EDITOR (no login required)
-- Copy all → paste → Run. Turn OFF "limit 100" if Supabase shows that option.
-- Or run RUN-LIVE-CLEANUP.sql for the full live sequence.
-- =============================================================================

SELECT jsonb_build_object(
  'totals', jsonb_build_object(
    'recipes', (SELECT count(*)::int FROM public.submitted_recipes),
    'approved_recipes', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
    'ingredients', (SELECT count(*)::int FROM public.ingredients)
  ),
  'issues', jsonb_build_object(
    'invalid_governed_links', (
      SELECT count(*)::int FROM public.library_profiles lp
      WHERE lp.profile_type = 'ingredient'
        AND lp.governed_ingredient_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id
        )
    ),
    'library_name_mismatches', (
      SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients i ON i."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"))
    ),
    'duplicate_ingredient_names', (
      SELECT count(*)::int FROM (
        SELECT lower(btrim("Ingredient Name")) AS n
        FROM public.ingredients
        WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
        GROUP BY 1 HAVING count(*) > 1
      ) d
    ),
    'starter_library_wrong_links', (
      SELECT count(*)::int
      FROM public.library_profiles lp
      JOIN public.ingredients gi ON gi."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND (
          (lp.slug = 'butter' AND (
            lower(gi."Ingredient Name") LIKE '%buttermilk%'
            OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
          ))
          OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
          OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
        )
    ),
    'orphan_recipe_ingredient_names', (
      SELECT count(DISTINCT x.ing_name)::int
      FROM (
        SELECT lower(btrim(item->>'ingredient')) AS ing_name
        FROM public.submitted_recipes sr,
             jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE sr.status = 'approved'
          AND btrim(COALESCE(item->>'ingredient', '')) <> ''
      ) x
      WHERE NOT EXISTS (
        SELECT 1 FROM public.ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
           OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
      )
    )
  ),
  'healthy', (
    (SELECT count(*)::int FROM public.library_profiles lp
      WHERE lp.profile_type = 'ingredient'
        AND lp.governed_ingredient_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id)
    ) = 0
    AND (SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients i ON i."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"))
    ) = 0
    AND (SELECT count(*)::int FROM (
      SELECT lower(btrim("Ingredient Name")) AS n FROM public.ingredients
      WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
      GROUP BY 1 HAVING count(*) > 1
    ) d) = 0
    AND (SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients gi ON gi."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND (
          (lp.slug = 'butter' AND (lower(gi."Ingredient Name") LIKE '%buttermilk%' OR lower(gi."Ingredient Name") LIKE '%peanut butter%'))
          OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
          OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
        )
    ) = 0
    AND (SELECT count(DISTINCT x.ing_name)::int
      FROM (
        SELECT lower(btrim(item->>'ingredient')) AS ing_name
        FROM public.submitted_recipes sr,
             jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE sr.status = 'approved' AND btrim(COALESCE(item->>'ingredient', '')) <> ''
      ) x
      WHERE NOT EXISTS (
        SELECT 1 FROM public.ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
           OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
      )
    ) = 0
  )
) AS health_report;
-- ########## END: SQL-EDITOR-health-check.sql ##########
