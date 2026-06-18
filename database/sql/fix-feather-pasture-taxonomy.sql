-- fix-feather-pasture-taxonomy.sql — Feather B1–B8 + Pasture C1–C8 (2026).
-- Full seed for a fresh DB. On a live DB with edits, prefer fix-feather-pasture-b8-c8.sql for new subs only.
-- WARNING: re-running this deactivates subs not in the list below, then re-seeds B1–B8 / C1–C8.

ALTER TABLE public.recipe_subcategories
  ADD COLUMN IF NOT EXISTS ingredient_hints text[] DEFAULT '{}';

-- ── Feather & Flock B1–B7 ────────────────────────────────────────────────────
UPDATE public.recipe_divisions SET is_active = false WHERE category = 'Feather & Flock';
UPDATE public.recipe_subcategories SET is_active = false WHERE category = 'Feather & Flock';

INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Feather & Flock', 'Chicken', 10, true),
  ('Feather & Flock', 'Duck & Waterfowl', 20, true),
  ('Feather & Flock', 'Turkey & Large Fowl', 30, true),
  ('Feather & Flock', 'Quail & Small Bush Fowl', 40, true),
  ('Feather & Flock', 'Pigeon & Squab', 50, true),
  ('Feather & Flock', 'Wild Game Birds', 60, true),
  ('Feather & Flock', 'Giant Flightless Birds', 70, true),
  ('Feather & Flock', 'Poultry Offal & Internal Treasures', 80, true)
ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Chicken','Bone-In Drumsticks','Chicken Wings','Thigh Fillets','Breasts','Minced Chicken'
] WHERE category = 'Feather & Flock' AND name = 'Chicken';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Duck','Duck Breasts (Magret)','Duck Legs','Rendered Duck Fat','Whole Christmas Goose'
] WHERE category = 'Feather & Flock' AND name = 'Duck & Waterfowl';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Turkey','Turkey Breasts','Large Turkey Wings','Drumsticks','Ground Turkey'
] WHERE category = 'Feather & Flock' AND name = 'Turkey & Large Fowl';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Quail','Spatchcocked Quail','Small Fowl Breasts','Petite Drumsticks'
] WHERE category = 'Feather & Flock' AND name = 'Quail & Small Bush Fowl';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Squab','Young Pigeon Breasts','Small Game Bird Crowns'
] WHERE category = 'Feather & Flock' AND name = 'Pigeon & Squab';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Pheasant','Wild Partridge Breasts','Woodcock','Grouse Crowns'
] WHERE category = 'Feather & Flock' AND name = 'Wild Game Birds';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Ostrich Fan Steaks','Emu Fillets','Ostrich Kebabs','Lean Strips'
] WHERE category = 'Feather & Flock' AND name = 'Giant Flightless Birds';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Chicken Livers','Duck Gizzards','Turkey Hearts','Poultry Necks','Cockscombs','Chicken Feet','Giblets','Foie Gras'
] WHERE category = 'Feather & Flock' AND name = 'Poultry Offal & Internal Treasures';

-- ── Pasture & Hoof C1–C8 ─────────────────────────────────────────────────────
UPDATE public.recipe_divisions SET is_active = false WHERE category = 'Pasture & Hoof';
UPDATE public.recipe_subcategories SET is_active = false WHERE category = 'Pasture & Hoof';

INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Pasture & Hoof', 'Bovine & Cattle', 10, true),
  ('Pasture & Hoof', 'Ovine & Caprine', 20, true),
  ('Pasture & Hoof', 'Porcine & Swine', 30, true),
  ('Pasture & Hoof', 'Heavy Herd Animals', 40, true),
  ('Pasture & Hoof', 'Wild Deer & Antelope', 50, true),
  ('Pasture & Hoof', 'Leporidae & Small Game', 60, true),
  ('Pasture & Hoof', 'Steppe & Arctic Mammals', 70, true),
  ('Pasture & Hoof', 'Variety Meats, Blood & Land Offal', 80, true)
ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Bone-In Ribs','Shanks','Brisket','Steaks','Minced Beef','Veal Cutlets'
] WHERE category = 'Pasture & Hoof' AND name = 'Bovine & Cattle';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Legs','Shoulder Cuts','Lamb Chops','Neck Rings','Goat Shanks','Diced Mutton'
] WHERE category = 'Pasture & Hoof' AND name = 'Ovine & Caprine';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Pork Belly','Loin Chops','Spare Ribs','Pork Shoulders','Tenderloin','Suckling Pig'
] WHERE category = 'Pasture & Hoof' AND name = 'Porcine & Swine';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Buffalo Striploin','Bison Patties','Camel Hump Fat','Camel Fillets','Heavy Stewing Cuts'
] WHERE category = 'Pasture & Hoof' AND name = 'Heavy Herd Animals';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Venison Loin','Haunch Cuts','Wild Antelope Steaks','Diced Game Meat'
] WHERE category = 'Pasture & Hoof' AND name = 'Wild Deer & Antelope';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Rabbit','Rabbit Saddles','Hare Thighs','Lean Game Joints'
] WHERE category = 'Pasture & Hoof' AND name = 'Leporidae & Small Game';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Horse Fillets','Reindeer Haunch','Horse Sausages','Arctic Land Mammal Cuts'
] WHERE category = 'Pasture & Hoof' AND name = 'Steppe & Arctic Mammals';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Beef Liver','Pork Tripe','Oxtail','Sweetbreads','Kidneys','Pork Blood','Lamb Tongue','Bone Marrow','Pig Trotters'
] WHERE category = 'Pasture & Hoof' AND name = 'Variety Meats, Blood & Land Offal';

SELECT category, name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category IN ('Feather & Flock', 'Pasture & Hoof') AND is_active = true
ORDER BY category, sort_order;
