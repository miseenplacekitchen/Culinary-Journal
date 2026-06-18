-- fix-feather-pasture-b8-c8.sql — Add B8 + C8 offal subs only (incremental).
-- Safe to re-run. Does NOT deactivate your other subs.
-- Run fix-admin-taxonomy-editor.sql first if tagline/description columns are missing.

INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Feather & Flock', 'Poultry Offal & Internal Treasures', 80, true),
  ('Pasture & Hoof', 'Variety Meats, Blood & Land Offal', 80, true)
ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = true;

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Chicken Livers','Duck Gizzards','Turkey Hearts','Poultry Necks','Cockscombs','Chicken Feet','Giblets','Foie Gras'
] WHERE category = 'Feather & Flock' AND name = 'Poultry Offal & Internal Treasures';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Beef Liver','Pork Tripe','Oxtail','Sweetbreads','Kidneys','Pork Blood','Lamb Tongue','Bone Marrow','Pig Trotters'
] WHERE category = 'Pasture & Hoof' AND name = 'Variety Meats, Blood & Land Offal';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Bone-In Ribs','Shanks','Brisket','Steaks','Minced Beef','Veal Cutlets'
] WHERE category = 'Pasture & Hoof' AND name = 'Bovine & Cattle';

UPDATE public.recipe_subcategories SET
  tagline = 'Honoring the whole bird through zero-waste heritages, rich organ meats, and deeply flavorful internal delicacies.',
  description = 'Utilizing the whole animal from head to tail is a massive, celebrated tradition across Asia, Europe, and Africa. This sub-category provides an undisputed, premium home for French chicken liver mousses, delicate duck foie gras, East Asian dim sum chicken feet, and skewered gizzards over charcoal.',
  emoji = '🫁'
WHERE category = 'Feather & Flock' AND name = 'Poultry Offal & Internal Treasures';

UPDATE public.recipe_subcategories SET
  tagline = 'Honoring time-honoured thrift, deep nose-to-tail traditions, and nutrient-dense internal delicacies of the pasture.',
  description = 'From the rich black puddings and savory tripe stews of Europe to the fiery liver fries, comforting trotters, and slow-simmered bone marrow broths of Asia and Africa. This card provides an undisputed, premium home for land offal without cluttering your main muscle-cut categories.',
  emoji = '🫁'
WHERE category = 'Pasture & Hoof' AND name = 'Variety Meats, Blood & Land Offal';

SELECT category, name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category IN ('Feather & Flock', 'Pasture & Hoof') AND is_active = true
ORDER BY category, sort_order;
