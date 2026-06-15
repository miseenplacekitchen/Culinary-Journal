-- ══════════════════════════════════════════════════════════════════════
-- fix-phase35-library-profiles.sql — milk, capsicum, cinnamon, paprika,
-- wok, lamb shoulder, smoking
-- Safe to re-run. Run after fix-phase34-library-profiles.sql.
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.ingredient_profiles (
  slug, name, also_known_as, category, flavour_profile, how_to_buy, how_to_store,
  how_to_prep, chefs_notes, did_you_know, status, visibility
) VALUES
('milk', 'Milk', 'Full-cream milk, whole milk', 'Dairy',
 'Creamy, mild sweetness — backbone of sauces, baking, and breakfast.',
 'Check use-by; carton upright; no sour smell when opened.',
 'Fridge always; use within a few days of opening; freeze in measured portions for baking only.',
 'Scald gently for béchamel; room temp for yeast doughs if recipe calls for it.',
 'Whole milk gives richer results than skim in custards and mashed potato.',
 'Humans have consumed milk from domesticated animals for over nine thousand years.',
 'published', 'public'),
('capsicum', 'Capsicum', 'Bell pepper, sweet pepper', 'Produce',
 'Sweet, crisp, mild — colour signals ripeness more than heat.',
 'Firm, glossy skin; heavy for size; no soft spots or wrinkles.',
 'Fridge crisper 1–2 weeks; keep dry — moisture speeds mould.',
 'Remove seeds and white pith for salads; char skin for peeling in roasts.',
 'Red and yellow are riper and sweeter than green — all work, different flavour.',
 'Capsicums are botanically fruits but treated as vegetables in the kitchen.',
 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as, category = EXCLUDED.category,
  flavour_profile = EXCLUDED.flavour_profile, how_to_buy = EXCLUDED.how_to_buy,
  how_to_store = EXCLUDED.how_to_store, how_to_prep = EXCLUDED.how_to_prep,
  chefs_notes = EXCLUDED.chefs_notes, did_you_know = EXCLUDED.did_you_know,
  status = EXCLUDED.status, visibility = EXCLUDED.visibility, updated_at = now();

INSERT INTO public.spice_profiles (slug, name, also_known_as, heat_level, flavour_wheel, how_to_toast, when_to_add, chefs_notes, did_you_know, status, visibility) VALUES
('cinnamon', 'Cinnamon', 'Ceylon cinnamon, cassia', 0, 'Sweet, warm, woody — baking and savoury depth.', 'Toast quills briefly in dry pan; grind fresh for pastries.', 'Add early in slow braises; dust at end for aroma on desserts.', 'Ceylon is milder; cassia is common in supermarkets — both work, different intensity.', 'Cinnamon was among the first spices traded along ancient routes from Sri Lanka.', 'published', 'public'),
('paprika', 'Paprika', 'Sweet paprika, Hungarian paprika', 0, 'Mild, sweet-smoky to earthy — colour and gentle warmth.', 'Bloom in oil off heat — burns easily and turns bitter.', 'Stir into goulash and stews; sprinkle on finished dishes for colour.', 'Smoked paprika (pimentón) is a different accent — label your jar.', 'Hungarian paprika grades range from sweet (édes) to hot (erős).', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, also_known_as=EXCLUDED.also_known_as, heat_level=EXCLUDED.heat_level,
  flavour_wheel=EXCLUDED.flavour_wheel, how_to_toast=EXCLUDED.how_to_toast, when_to_add=EXCLUDED.when_to_add,
  chefs_notes=EXCLUDED.chefs_notes, did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

INSERT INTO public.tool_profiles (slug, name, tool_category, what_its_for, how_to_use, how_to_care, chefs_notes, did_you_know, status, visibility) VALUES
('wok', 'Wok', 'Cookware', 'High-heat stir-fry, deep fry, steam — curved sides keep food in motion.', 'Preheat until oil shimmers; work in small batches; keep ingredients moving.', 'Carbon steel: season like cast iron. Non-stick: avoid metal utensils and high empty heat.', 'Mise en place is essential — once you start, there is no pause.', 'Wok hei — the breath of the wok — comes from fierce heat and skilled tossing.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, tool_category=EXCLUDED.tool_category, what_its_for=EXCLUDED.what_its_for,
  how_to_use=EXCLUDED.how_to_use, how_to_care=EXCLUDED.how_to_care, chefs_notes=EXCLUDED.chefs_notes,
  did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

INSERT INTO public.cut_profiles (slug, name, protein_type, characteristics, how_to_prep, best_cooking_methods, chefs_notes, did_you_know, status, visibility) VALUES
('lamb-shoulder', 'Lamb Shoulder', 'lamb', 'Fat-marbled, forgiving, deep flavour — slow cooking shines.', 'Trim excessive sinew if desired; score fat cap; bring to room temp before roasting.', 'Low slow roast, braise, tagine, pulled lamb — not for quick grilling.', 'Bone-in adds richness; boneless easier to carve for pulled dishes.', 'Shoulder is often better value than leg with more connective tissue to melt.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, protein_type=EXCLUDED.protein_type, characteristics=EXCLUDED.characteristics,
  how_to_prep=EXCLUDED.how_to_prep, best_cooking_methods=EXCLUDED.best_cooking_methods, chefs_notes=EXCLUDED.chefs_notes,
  did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

INSERT INTO public.preservation_profiles (slug, name, technique_type, what_it_is, best_for, safety_notes, shelf_life, chefs_notes, did_you_know, status, visibility) VALUES
('smoking', 'Hot & Cold Smoking', 'smoking', 'Smoke flavours and preserves food — hot cooks, cold flavours only.', 'Fish, poultry, cheese, vegetables — hot for cooked results, cold for cured texture.', 'Cold smoking requires proper cure and temperature control — follow tested recipes.', 'Days to weeks refrigerated depending on product and method', 'Fruit woods (apple, cherry) are milder than hickory — match wood to protein.', 'Smoking food is one of the oldest preservation methods — predating written recipes.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name, technique_type=EXCLUDED.technique_type, what_it_is=EXCLUDED.what_it_is,
  best_for=EXCLUDED.best_for, safety_notes=EXCLUDED.safety_notes, shelf_life=EXCLUDED.shelf_life,
  chefs_notes=EXCLUDED.chefs_notes, did_you_know=EXCLUDED.did_you_know, status=EXCLUDED.status, visibility=EXCLUDED.visibility, updated_at=now();

-- Link governed ingredients by name
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) IN ('milk', 'full cream milk', 'whole milk')
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) = 'milk' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub
WHERE ip.slug = 'milk' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(trim("Ingredient Name")) LIKE '%capsicum%'
     OR lower(trim("Ingredient Name")) LIKE '%bell pepper%'
  ORDER BY CASE WHEN lower(trim("Ingredient Name")) LIKE 'capsicum%' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub
WHERE ip.slug = 'capsicum' AND ip.governed_ingredient_id IS NULL AND sub.ing_id IS NOT NULL;

SELECT 'ingredient' AS type, slug, name, status FROM public.ingredient_profiles WHERE slug IN ('milk', 'capsicum')
UNION ALL SELECT 'spice', slug, name, status FROM public.spice_profiles WHERE slug IN ('cinnamon', 'paprika')
UNION ALL SELECT 'tool', slug, name, status FROM public.tool_profiles WHERE slug = 'wok'
UNION ALL SELECT 'cut', slug, name, status FROM public.cut_profiles WHERE slug = 'lamb-shoulder'
UNION ALL SELECT 'preservation', slug, name, status FROM public.preservation_profiles WHERE slug = 'smoking'
ORDER BY type, slug;
