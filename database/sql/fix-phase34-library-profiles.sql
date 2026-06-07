-- ══════════════════════════════════════════════════════════════════════
-- fix-phase34-library-profiles.sql — Sebago, coconut, cardamom, coriander,
-- dutch oven, pork shoulder, lacto-fermentation
-- Safe to re-run. Run after fix-phase34-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.ingredient_profiles (
  slug, name, also_known_as, category, flavour_profile, how_to_buy, how_to_store,
  how_to_prep, chefs_notes, did_you_know, status, visibility, governed_ingredient_id
) VALUES
('sebago-potato', 'Sebago Potato', 'Sebago, white washed', 'Produce',
 'Floury, fluffy mash; breaks down in soups if overcooked.',
 'Firm, even skin; no green patches. Popular Australian all-rounder.',
 'Cool, dark, dry pantry — not the fridge.',
 'Peel for mash; scrub and roast whole or halved with skin on.',
 'Best known Australian white potato — mash and roast benchmark.',
 'Sebago is the default link for generic potato profiles on CJ.',
 'published', 'public', 248),
('coconut', 'Coconut', 'Fresh coconut, mature coconut', 'Produce',
 'Sweet, tropical, rich — water, flesh, milk and oil from one fruit.',
 'Heavy for size; slosh of water inside; no cracks or mould.',
 'Whole coconut at room temp a few days; refrigerate grated flesh; freeze milk.',
 'Pierce soft eyes for water; crack shell; peel brown skin from white flesh.',
 'Fresh grated coconut beats desiccated for curries and sweets.',
 'Coconut palms can produce fruit for up to 80 years in tropical climates.',
 'published', 'public', NULL)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name, governed_ingredient_id = COALESCE(EXCLUDED.governed_ingredient_id, ingredient_profiles.governed_ingredient_id),
  flavour_profile = EXCLUDED.flavour_profile, how_to_buy = EXCLUDED.how_to_buy,
  how_to_store = EXCLUDED.how_to_store, how_to_prep = EXCLUDED.how_to_prep,
  chefs_notes = EXCLUDED.chefs_notes, did_you_know = EXCLUDED.did_you_know,
  status = EXCLUDED.status, updated_at = now();

INSERT INTO public.spice_profiles (slug, name, also_known_as, heat_level, flavour_wheel, how_to_toast, when_to_add, chefs_notes, did_you_know, status, visibility) VALUES
('cardamom', 'Cardamom', 'Green cardamom, elaichi', 0, 'Sweet, floral, eucalyptus notes — warm and aromatic.', 'Lightly toast whole pods in dry pan; crush pods to release seeds.', 'Add whole pods to rice and stews; grind seeds for baking and chai.', 'Green for sweet/savoury; black cardamom is smokier — do not swap blindly.', 'Cardamom is the third most expensive spice by weight after saffron and vanilla.', 'published', 'public'),
('coriander-seed', 'Coriander Seed', 'Dhania, cilantro seed', 0, 'Citrusy, nutty, warm — different from fresh coriander leaf.', 'Toast until fragrant; grind fresh for curry bases.', 'Bloom in oil with cumin at start of Indian-style dishes.', 'Whole seeds in pickles; ground in spice blends.', 'The same plant gives cilantro leaves and coriander seeds — different flavour profiles.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, also_known_as=EXCLUDED.also_known_as, heat_level=EXCLUDED.heat_level,
  flavour_wheel=EXCLUDED.flavour_wheel, how_to_toast=EXCLUDED.how_to_toast, when_to_add=EXCLUDED.when_to_add,
  chefs_notes=EXCLUDED.chefs_notes, did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

INSERT INTO public.tool_profiles (slug, name, tool_category, what_its_for, how_to_use, how_to_care, chefs_notes, did_you_know, status, visibility) VALUES
('dutch-oven', 'Dutch Oven', 'Cookware', 'Braising, bread baking, stews, deep frying — retains heat beautifully.', 'Preheat for bread; low steady heat for braises; use lid for oven steam.', 'Cast iron: dry thoroughly, oil wipe. Enamel: avoid thermal shock and metal scouring.', 'A heavy lid seals moisture — ideal for slow Sunday sauces.', 'Dutch ovens were essential on hearth cooking before modern ovens.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, tool_category=EXCLUDED.tool_category, what_its_for=EXCLUDED.what_its_for,
  how_to_use=EXCLUDED.how_to_use, how_to_care=EXCLUDED.how_to_care, chefs_notes=EXCLUDED.chefs_notes,
  did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

INSERT INTO public.cut_profiles (slug, name, protein_type, characteristics, how_to_prep, best_cooking_methods, chefs_notes, did_you_know, status, visibility) VALUES
('pork-shoulder', 'Pork Shoulder', 'pork', 'Fat-marbled, forgiving, rich — slow cooking transforms connective tissue.', 'Trim excessive fat cap if desired; score skin for crackling roasts; bring to room temp.', 'Low slow roast, braise, pulled pork, curry — not for quick grilling.', 'Bone-in adds flavour; boneless easier to carve for pulled pork.', 'Also called Boston butt in US butchery — it is the shoulder, not the rear.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, protein_type=EXCLUDED.protein_type, characteristics=EXCLUDED.characteristics,
  how_to_prep=EXCLUDED.how_to_prep, best_cooking_methods=EXCLUDED.best_cooking_methods, chefs_notes=EXCLUDED.chefs_notes,
  did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

INSERT INTO public.preservation_profiles (slug, name, technique_type, what_it_is, best_for, safety_notes, shelf_life, chefs_notes, did_you_know, status, visibility) VALUES
('lacto-fermentation', 'Lacto-Fermentation', 'fermenting', 'Salt creates environment where beneficial bacteria preserve vegetables and develop tang.', 'Sauerkraut, kimchi, pickles, hot sauce — complex flavour without vinegar shortcut.', 'Use correct salt %; keep veg submerged under brine; discard if mould (not kahm) spreads.', 'Months refrigerated when properly fermented and sealed', 'Burp jars during active ferment; move to fridge when flavour and bubble slow.', 'Lacto-fermentation predates written history — every cuisine has a version.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, technique_type=EXCLUDED.technique_type, what_it_is=EXCLUDED.what_it_is,
  best_for=EXCLUDED.best_for, safety_notes=EXCLUDED.safety_notes, shelf_life=EXCLUDED.shelf_life,
  chefs_notes=EXCLUDED.chefs_notes, did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

-- Link coconut to governed ingredient by name
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) LIKE '%coconut%'
    AND lower(trim("Ingredient Name")) NOT LIKE '%cream%'
    AND lower(trim("Ingredient Name")) NOT LIKE '%milk%'
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) = 'coconut' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'coconut' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

SELECT 'ingredient' AS type, slug, name, status FROM public.ingredient_profiles WHERE slug IN ('sebago-potato', 'coconut')
UNION ALL SELECT 'spice', slug, name, status FROM public.spice_profiles WHERE slug IN ('cardamom', 'coriander-seed')
UNION ALL SELECT 'tool', slug, name, status FROM public.tool_profiles WHERE slug = 'dutch-oven'
UNION ALL SELECT 'cut', slug, name, status FROM public.cut_profiles WHERE slug = 'pork-shoulder'
UNION ALL SELECT 'preservation', slug, name, status FROM public.preservation_profiles WHERE slug = 'lacto-fermentation'
ORDER BY type, slug;
