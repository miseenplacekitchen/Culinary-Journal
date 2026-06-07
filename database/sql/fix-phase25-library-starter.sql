-- ══════════════════════════════════════════════════════════════════════
-- fix-phase25-library-starter.sql — Starter ingredient library profiles
-- Safe to re-run. Publishes profiles and links to governed ingredients by name.
-- Run after fix-phase22-batch.sql (governed_ingredient_id column).
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.ingredient_profiles (
  slug, name, also_known_as, category, flavour_profile, how_to_buy, how_to_store,
  how_to_prep, when_to_add, common_mistakes, chefs_notes, did_you_know,
  status, visibility
) VALUES
('garlic', 'Garlic',
 'Allium sativum',
 'Produce', 'Pungent, savoury, warming — mellows and sweetens with slow cooking.',
 'Choose firm, heavy bulbs with tight papery skin. Avoid sprouting or soft cloves.',
 'Cool, dry, airy spot — not the fridge. Break into cloves only when needed.',
 'Crush for maximum flavour in marinades; slice for gentle sauté; whole cloves for roasts.',
 'Add crushed garlic early in oil for depth; add sliced garlic later to avoid bitterness.',
 'Burning garlic in hot oil — it turns acrid in seconds. Lower heat or add with onion.',
 'If garlic sprouts green, it is still usable — remove the green shoot for milder flavour.',
 'China grows roughly two-thirds of the world''s garlic — yet most home cooks only know one variety.',
 'published', 'public'),

('onion', 'Onion',
 'Brown / yellow onion',
 'Produce', 'Sweet-savoury base note — backbone of countless dishes.',
 'Firm, dry skins, no soft spots. Larger onions suit long cooking; smaller for higher flavour per gram.',
 'Whole onions in a cool dark place. Cut onion wrapped in fridge — use within a few days.',
 'Dice evenly for sauce bases; slice thin for caramelising; wedge for roasts.',
 'Start onions before garlic — they need longer to soften and release sweetness.',
 'Rushing caramelisation on high heat — you get brown edges, not sweet depth.',
 'A cut onion at room temp is fine for a few hours; refrigerate if prepping ahead for long sessions.',
 'Onions make you cry because slicing releases a sulphur compound that irritates the eyes — chill the onion 10 minutes to help.',
 'published', 'public'),

('butter', 'Butter',
 'Unsalted / salted',
 'Dairy', 'Rich, creamy, carries flavour — browns into nutty beurre noisette.',
 'Unsalted for baking control; salted for finishing toast and vegetables. Check freshness date.',
 'Refrigerate; freeze wrapped for months. Keep a small portion at room temp only if used daily.',
 'Cut cold butter into flour for pastry; soften for creaming; clarify for higher smoke point.',
 'Finish sauces and vegetables off heat so butter emulsifies rather than splitting.',
 'High heat with plain butter alone — milk solids burn. Use ghee, clarified butter, or mix with oil.',
 'Room-temperature butter creams better with sugar — cold butter will not aerate properly in cakes.',
 'European-style butters often have higher fat % than standard — less water, flakier pastry.',
 'published', 'public'),

('olive-oil', 'Olive Oil',
 'EVOO, extra virgin',
 'Pantry', 'Fruity, peppery, bitter notes — quality varies hugely by region and harvest.',
 'Extra virgin for dressings and finishing; everyday olive oil for cooking. Dark bottle, harvest date if possible.',
 'Cool dark cupboard — not above the stove. Use within 12–18 months of opening.',
 'Drizzle to finish; whisk into dressings; gentle heat for soffrito — not always for deep frying.',
 'Finish dishes with good oil; cook everyday dishes with standard grade.',
 'Using delicate EVOO over high heat — smoke and bitterness waste good oil.',
 'If oil smells waxy or flat, it is past prime — fine for cooking, not for dressing.',
 'Olive oil is a fruit juice — freshness matters more than age on the label alone.',
 'published', 'public'),

('rice', 'Rice',
 'Long-grain, basmati, jasmine',
 'Pantry', 'Neutral canvas — aroma and texture depend on variety.',
 'Match variety to dish: basmati for pilaf, arborio for risotto, short-grain for sticky rice.',
 'Airtight container in a cool pantry. Protect from moisture and pests.',
 'Rinse until water runs clearer for separated grains; soak basmati 20–30 min for length.',
 'Toast rice in fat before adding liquid for pilaf-style dishes.',
 'Lifting the lid and stirring constantly — releases steam and makes rice gluey.',
 'Rest cooked rice off heat 5–10 minutes, then fork — grains finish evenly.',
 'Rice feeds more than half the world — yet each cuisine treats it almost like a different ingredient.',
 'published', 'public'),

('tomato', 'Tomato',
 'Fresh tomato',
 'Produce', 'Bright acidity, umami when ripe — transforms with heat into sweetness.',
 'Heavy, fragrant, deep colour for eating fresh. Firmer fruit fine for slow sauces.',
 'Never refrigerate ripe tomatoes — cold kills flavour and texture. Use ripe fruit quickly.',
 'Remove core; score and peel for fine sauces; roast halves for concentrated flavour.',
 'Fresh tomato for salads and quick sauces; longer cooking for depth in stews.',
 'Adding very ripe tomatoes to a screaming-hot pan — splatter and lost sweetness.',
 'Salt tomatoes just before serving — salt draws water and dulls fresh salads if left too long.',
 'Tomatoes are botanically a fruit — legally a vegetable in US trade law since 1893.',
 'published', 'public'),

('chicken-breast', 'Chicken Breast',
 'Chicken fillet',
 'Protein', 'Mild, lean — dries out easily without care.',
 'Pale pink, no grey sliminess, no strong odour. Even thickness cooks more evenly.',
 'Refrigerate 1–2 days; freeze well-wrapped. Thaw in fridge, not counter.',
 'Pound thick ends for even cooking; brine briefly for juiciness; rest after cooking.',
 'Cook to safe internal temperature then rest — carryover heat finishes the centre.',
 'High heat until dry throughout — breast needs gentler heat than thighs.',
 'Slice against the grain for tender mouthfeel on carved breast.',
 'Chicken breast became a diet staple in the 1980s — thighs often give more flavour for less fuss.',
 'published', 'public'),

('salt', 'Salt',
 'Table salt, sea salt, kosher salt',
 'Pantry', 'Amplifies flavour — different crystal sizes measure differently by volume.',
 'Diamond crystal kosher for pinching; fine sea salt for baking; flaky salt for finishing.',
 'Dry airtight container — salt itself does not expire; additives may clump in humidity.',
 'Season in layers through cooking, not only at the end.',
 'Salt pasta water generously — it should taste like mild seawater.',
 'Measuring salts interchangeably by tablespoon — densities differ by brand.',
 'Taste as you go — you can add salt, not easily remove it.',
 'Kosher salt is named for its use in koshering meat, not because it is kosher-certified only.',
 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  also_known_as = EXCLUDED.also_known_as,
  category = EXCLUDED.category,
  flavour_profile = EXCLUDED.flavour_profile,
  how_to_buy = EXCLUDED.how_to_buy,
  how_to_store = EXCLUDED.how_to_store,
  how_to_prep = EXCLUDED.how_to_prep,
  when_to_add = EXCLUDED.when_to_add,
  common_mistakes = EXCLUDED.common_mistakes,
  chefs_notes = EXCLUDED.chefs_notes,
  did_you_know = EXCLUDED.did_you_know,
  status = EXCLUDED.status,
  visibility = EXCLUDED.visibility,
  updated_at = now();

-- Link profiles to governed ingredients
-- ingredients table uses CSV column names: "ID", "Ingredient Name" (see 01-schema.sql)
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) = 'garlic' ORDER BY "ID" LIMIT 1
) sub
WHERE ip.slug = 'garlic' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) IN ('onion', 'onions', 'brown onion', 'yellow onion')
  ORDER BY "ID" LIMIT 1
) sub
WHERE ip.slug = 'onion' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%butter%'
    AND lower("Ingredient Name") NOT LIKE '%peanut%'
    AND lower("Ingredient Name") NOT LIKE '%cocoa%'
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) = 'butter' THEN 0 ELSE 1 END, length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'butter' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) LIKE '%olive oil%' ORDER BY "ID" LIMIT 1
) sub
WHERE ip.slug = 'olive-oil' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%rice%'
    AND lower("Ingredient Name") NOT LIKE '%rice vinegar%'
    AND lower("Ingredient Name") NOT LIKE '%rice paper%'
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) = 'rice' THEN 0 ELSE 1 END, length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'rice' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%tomato%'
    AND lower("Ingredient Name") NOT LIKE '%paste%'
    AND lower("Ingredient Name") NOT LIKE '%sauce%'
    AND lower("Ingredient Name") NOT LIKE '%ketchup%'
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) IN ('tomato','tomatoes') THEN 0 ELSE 1 END, length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'tomato' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) LIKE '%chicken breast%' ORDER BY "ID" LIMIT 1
) sub
WHERE ip.slug = 'chicken-breast' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%salt%'
    AND lower("Ingredient Name") NOT LIKE '%celery%'
    AND lower("Ingredient Name") NOT LIKE '%garlic salt%'
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) = 'salt' THEN 0 ELSE 1 END, length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'salt' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

SELECT slug, name, governed_ingredient_id, status
FROM public.ingredient_profiles
WHERE slug IN ('garlic','onion','butter','olive-oil','rice','tomato','chicken-breast','salt')
ORDER BY slug;
