-- fix-subcategory-categories.sql
-- Reassign recipe_subcategories.category (and divisions) by BOOK sub name.
-- Fixes fix-categories-v2.sql bulk move of ALL 'Meat & Fire' rows → Feather & Flock.
-- Run once in Supabase SQL Editor. Safe to re-run.

-- ── 1. Before (audit) ─────────────────────────────────────────────────────
SELECT name, category
FROM public.recipe_subcategories
WHERE is_active = true
ORDER BY category, name;

-- ── 2. Mapping table (246 book sub-categories) ─────────────
CREATE TEMP TABLE IF NOT EXISTS tcj_sub_category_fix (
  sub_name text PRIMARY KEY,
  canon_category text NOT NULL
) ON COMMIT DROP;
TRUNCATE tcj_sub_category_fix;

INSERT INTO tcj_sub_category_fix (sub_name, canon_category) VALUES
  ('Baked Egg Dishes', 'Breads & Bakery'),
  ('Bars & Slices', 'Breads & Bakery'),
  ('Biscuits (Crisp & Snapping)', 'Breads & Bakery'),
  ('Celebration & Special Cakes', 'Breads & Bakery'),
  ('Cheesecakes', 'Breads & Bakery'),
  ('Chinese Breads & Doughs', 'Breads & Bakery'),
  ('Chocolate Cakes', 'Breads & Bakery'),
  ('Choux (Savoury)', 'Breads & Bakery'),
  ('Choux (Sweet)', 'Breads & Bakery'),
  ('Cinnamon Rolls & Sweet Buns', 'Breads & Bakery'),
  ('Classic Layer Cakes', 'Breads & Bakery'),
  ('Cookies (Soft & Chewy)', 'Breads & Bakery'),
  ('Croissants & Danish', 'Breads & Bakery'),
  ('Doughnuts & Fried Dough', 'Breads & Bakery'),
  ('Enriched & Festive Breads', 'Breads & Bakery'),
  ('European Flatbreads', 'Breads & Bakery'),
  ('Everyday Flatbreads (Dry-Cooked)', 'Breads & Bakery'),
  ('Fermented & Layered Flatbreads', 'Breads & Bakery'),
  ('Filo & Layered Pastry (Savoury)', 'Breads & Bakery'),
  ('Flatbreads', 'Breads & Bakery'),
  ('Fried Indian Breads', 'Breads & Bakery'),
  ('Gratins & Baked Dishes', 'Breads & Bakery'),
  ('Japanese Breads', 'Breads & Bakery'),
  ('Korean Breads', 'Breads & Bakery'),
  ('Layered Pastry (Sweet)', 'Breads & Bakery'),
  ('Pies & Baked Casseroles', 'Breads & Bakery'),
  ('Puff Pastry (Savoury)', 'Breads & Bakery'),
  ('Regional & Traditional Cakes', 'Breads & Bakery'),
  ('Rolls & Small Breads', 'Breads & Bakery'),
  ('Sandwich Cookies & Filled Biscuits', 'Breads & Bakery'),
  ('Short & Hot Water Crust Pastry', 'Breads & Bakery'),
  ('Small Cakes & Individual Portions', 'Breads & Bakery'),
  ('South Asian Pastry (Savoury)', 'Breads & Bakery'),
  ('South Indian & Kerala Breads', 'Breads & Bakery'),
  ('South-East Asian & Filipino Breads', 'Breads & Bakery'),
  ('Stuffed Parathas', 'Breads & Bakery'),
  ('Tandoor Breads', 'Breads & Bakery'),
  ('Tarts & Tartlets (Sweet)', 'Breads & Bakery'),
  ('Yeasted Loaves', 'Breads & Bakery'),
  ('Appams & Hoppers', 'Curds, Creams & Eggs'),
  ('Boiled Eggs', 'Curds, Creams & Eggs'),
  ('Breakfast Meats & Sides', 'Curds, Creams & Eggs'),
  ('Chutneys & Dips (Breakfast)', 'Curds, Creams & Eggs'),
  ('Cold Bowls & Parfaits', 'Curds, Creams & Eggs'),
  ('Cornmeal & Other Grain Porridges', 'Curds, Creams & Eggs'),
  ('Dosas', 'Curds, Creams & Eggs'),
  ('French Toast & Eggy Breads', 'Curds, Creams & Eggs'),
  ('Fried & Basted Eggs', 'Curds, Creams & Eggs'),
  ('Fruit Salads & Morning Platters', 'Curds, Creams & Eggs'),
  ('Full Breakfasts & Plated Sets', 'Curds, Creams & Eggs'),
  ('Granola & Muesli', 'Curds, Creams & Eggs'),
  ('Idlis', 'Curds, Creams & Eggs'),
  ('Indian Flatbreads (Breakfast)', 'Curds, Creams & Eggs'),
  ('Morning Pastries & Bakes', 'Curds, Creams & Eggs'),
  ('Oat & Grain Porridges', 'Curds, Creams & Eggs'),
  ('Omelettes', 'Curds, Creams & Eggs'),
  ('Pancakes & Crepes', 'Curds, Creams & Eggs'),
  ('Poached & Baked Eggs', 'Curds, Creams & Eggs'),
  ('Puttu & Steamed Rice Dishes', 'Curds, Creams & Eggs'),
  ('Rice Porridges', 'Curds, Creams & Eggs'),
  ('Scrambled Eggs', 'Curds, Creams & Eggs'),
  ('Semolina & Flour Porridges', 'Curds, Creams & Eggs'),
  ('Spreads & Toppings', 'Curds, Creams & Eggs'),
  ('Steamed Buns & Dumplings (Breakfast)', 'Curds, Creams & Eggs'),
  ('Steamed Egg Dishes', 'Curds, Creams & Eggs'),
  ('Sweet Porridges & Warm Sweets', 'Curds, Creams & Eggs'),
  ('Toast & Open-Face Dishes', 'Curds, Creams & Eggs'),
  ('Waffles', 'Curds, Creams & Eggs'),
  ('Chicken', 'Feather & Flock'),
  ('Duck & Waterfowl', 'Feather & Flock'),
  ('Giant Flightless Birds', 'Feather & Flock'),
  ('Pigeon & Squab', 'Feather & Flock'),
  ('Poultry Offal & Internal Treasures', 'Feather & Flock'),
  ('Quail & Small Bush Fowl', 'Feather & Flock'),
  ('Turkey & Large Fowl', 'Feather & Flock'),
  ('Wild Game Birds', 'Feather & Flock'),
  ('Alliums', 'Garden & Earth'),
  ('Bean Sprout & Mushroom Dishes', 'Garden & Earth'),
  ('Brassicas', 'Garden & Earth'),
  ('Corn & Fresh Maize', 'Garden & Earth'),
  ('Culinary Herbs & Edible Flowers', 'Garden & Earth'),
  ('Filipino & South-East Asian Vegetable Dishes', 'Garden & Earth'),
  ('Gourds & Squashes', 'Garden & Earth'),
  ('Indian Legume Stir-Fries', 'Garden & Earth'),
  ('Leafy Green Stir-Fries', 'Garden & Earth'),
  ('Leafy Greens', 'Garden & Earth'),
  ('Legumes & Pulses', 'Garden & Earth'),
  ('Mezhukkupuratti (Stir-Fried in Oil)', 'Garden & Earth'),
  ('Mixed Vegetable Stir-Fries', 'Garden & Earth'),
  ('Mushrooms & Fungi', 'Garden & Earth'),
  ('Nightshades & Hanging Pods', 'Garden & Earth'),
  ('North Indian Dry Sabzis', 'Garden & Earth'),
  ('Other Regional Dry Dishes', 'Garden & Earth'),
  ('Pan-Cooked Mediterranean Dishes', 'Garden & Earth'),
  ('Pan-Fried Egg Dishes', 'Garden & Earth'),
  ('Poriyal & Varuval (Tamil Style)', 'Garden & Earth'),
  ('Potato Dishes (Dry)', 'Garden & Earth'),
  ('Rhizomes & Fresh Aromatics', 'Garden & Earth'),
  ('Roasted Vegetable Dishes', 'Garden & Earth'),
  ('Roasted Vegetables', 'Garden & Earth'),
  ('Root Vegetable & Firm Veg Stir-Fries', 'Garden & Earth'),
  ('Roots & Tubers', 'Garden & Earth'),
  ('Sauteed & Pan-Fried Vegetables', 'Garden & Earth'),
  ('Savoury Fruits & Flora', 'Garden & Earth'),
  ('Scrambled & Bhurji Style', 'Garden & Earth'),
  ('Sprouted & Cooked Legumes', 'Garden & Earth'),
  ('Stems, Shoots & Sprouts', 'Garden & Earth'),
  ('Stuffed Vegetables (Dry / Baked)', 'Garden & Earth'),
  ('Thoran & Stir-Fries (Coconut-Based)', 'Garden & Earth'),
  ('Tofu Stir-Fries', 'Garden & Earth'),
  ('Bivalves & Shelled Molluscs', 'Ocean & River'),
  ('Cartilaginous & Heavy Marine Giants', 'Ocean & River'),
  ('Cephalopods & Soft Tissues', 'Ocean & River'),
  ('Crustaceans & Crawlers', 'Ocean & River'),
  ('Freshwater & River Species', 'Ocean & River'),
  ('Oily & Robust Finfish', 'Ocean & River'),
  ('Sea Vegetables & Aquatic Flora', 'Ocean & River'),
  ('White & Delicate Finfish', 'Ocean & River'),
  ('Bovine & Cattle', 'Pasture & Hoof'),
  ('Heavy Herd Animals', 'Pasture & Hoof'),
  ('Leporidae & Small Game', 'Pasture & Hoof'),
  ('Ovine & Caprine', 'Pasture & Hoof'),
  ('Porcine & Swine', 'Pasture & Hoof'),
  ('Steppe & Arctic Mammals', 'Pasture & Hoof'),
  ('Variety Meats, Blood & Land Offal', 'Pasture & Hoof'),
  ('Wild Deer & Antelope', 'Pasture & Hoof'),
  ('British & Western Chutneys', 'Preserved & Pantry'),
  ('Chinese Pickles', 'Preserved & Pantry'),
  ('Citrus Pickles', 'Preserved & Pantry'),
  ('Cooked & Bottled Chutneys (Indian)', 'Preserved & Pantry'),
  ('East & South-East Asian Blends', 'Preserved & Pantry'),
  ('European Pickles', 'Preserved & Pantry'),
  ('Fermented Pastes & Sauces', 'Preserved & Pantry'),
  ('Fermented Staples', 'Preserved & Pantry'),
  ('Flavoured Vinegars', 'Preserved & Pantry'),
  ('Fresh Chutneys (South Indian)', 'Preserved & Pantry'),
  ('Indian Bases & Pastes', 'Preserved & Pantry'),
  ('Infused Oils', 'Preserved & Pantry'),
  ('Jams', 'Preserved & Pantry'),
  ('Japanese Tsukemono', 'Preserved & Pantry'),
  ('Jellies & Curds', 'Preserved & Pantry'),
  ('Kerala Spice Blends', 'Preserved & Pantry'),
  ('Korean Kimchi', 'Preserved & Pantry'),
  ('Mango Pickles', 'Preserved & Pantry'),
  ('Marmalades', 'Preserved & Pantry'),
  ('Middle Eastern & North African Blends', 'Preserved & Pantry'),
  ('Middle Eastern Pickles', 'Preserved & Pantry'),
  ('Middle Eastern Sauces & Pastes', 'Preserved & Pantry'),
  ('North Indian Spice Blends', 'Preserved & Pantry'),
  ('Other Regional Pickles', 'Preserved & Pantry'),
  ('Seafood & Meat Pickles (Kerala)', 'Preserved & Pantry'),
  ('South Indian Spice Blends', 'Preserved & Pantry'),
  ('South-East Asian Pastes & Sauces', 'Preserved & Pantry'),
  ('South-East Asian Pickles', 'Preserved & Pantry'),
  ('Vegetable Pickles', 'Preserved & Pantry'),
  ('Western Blends & Rubs', 'Preserved & Pantry'),
  ('Western Condiments', 'Preserved & Pantry'),
  ('Coffee Beans & Specialty Brews', 'Sips & Stories'),
  ('Cordials, Syrups & Regional Coolers', 'Sips & Stories'),
  ('Crafted Milks, Boba & Cultured Dairy', 'Sips & Stories'),
  ('Living Cultures & Functional Tonics (Non-Alcoholic)', 'Sips & Stories'),
  ('Mocktails & Zero-Proof Mixology', 'Sips & Stories'),
  ('Pressed Fruits, Juices & Blended Smoothies', 'Sips & Stories'),
  ('Sodas, Tonics & Effervescent Fizzes', 'Sips & Stories'),
  ('True Teas & Botanical Infusions', 'Sips & Stories'),
  ('Wines, Beers & Crafted Spirits (Alcoholic)', 'Sips & Stories'),
  ('American Desserts', 'Sweet Serenades'),
  ('Barfi & Fudge', 'Sweet Serenades'),
  ('Bark & Clusters', 'Sweet Serenades'),
  ('Bread & Sponge Puddings', 'Sweet Serenades'),
  ('British Desserts', 'Sweet Serenades'),
  ('Caramel & Toffee', 'Sweet Serenades'),
  ('Central & Eastern European Desserts', 'Sweet Serenades'),
  ('Chinese Desserts', 'Sweet Serenades'),
  ('Confectionery', 'Sweet Serenades'),
  ('Custard-Based Desserts', 'Sweet Serenades'),
  ('East & West African Desserts', 'Sweet Serenades'),
  ('Filipino Desserts', 'Sweet Serenades'),
  ('French Desserts', 'Sweet Serenades'),
  ('Fried & Syrup Sweets', 'Sweet Serenades'),
  ('Fried & Syrup-Soaked Sweets', 'Sweet Serenades'),
  ('Frozen Novelties', 'Sweet Serenades'),
  ('Halwa', 'Sweet Serenades'),
  ('Ice Cream', 'Sweet Serenades'),
  ('Indian Frozen Desserts', 'Sweet Serenades'),
  ('Italian Desserts', 'Sweet Serenades'),
  ('Japanese Desserts', 'Sweet Serenades'),
  ('Jellies & Wobbly Desserts', 'Sweet Serenades'),
  ('Kerala Sweets', 'Sweet Serenades'),
  ('Korean Desserts', 'Sweet Serenades'),
  ('Latin American Desserts', 'Sweet Serenades'),
  ('Milk-Based Sweets & Puddings', 'Sweet Serenades'),
  ('Mousse & Light Set Desserts', 'Sweet Serenades'),
  ('Nordic Desserts', 'Sweet Serenades'),
  ('Nut & Pastry Sweets', 'Sweet Serenades'),
  ('Puddings & Set Sweets', 'Sweet Serenades'),
  ('Rice & Grain Puddings', 'Sweet Serenades'),
  ('Semolina & Grain Sweets', 'Sweet Serenades'),
  ('Sorbets & Granitas', 'Sweet Serenades'),
  ('South Indian Sweets', 'Sweet Serenades'),
  ('Southern African Desserts', 'Sweet Serenades'),
  ('Spanish & Portuguese Desserts', 'Sweet Serenades'),
  ('Thai & South-East Asian Desserts', 'Sweet Serenades'),
  ('Traditional Confectionery', 'Sweet Serenades'),
  ('Truffles & Bonbons', 'Sweet Serenades'),
  ('Grain Brans, Germs & Isolated Starches', 'The Grain Field'),
  ('Maize & Corn Starch Kernels (Zea mays)', 'The Grain Field'),
  ('Milled Strands & Extruded Shapes', 'The Grain Field'),
  ('Millets, Sorghum & Teff (Ancient Dryland Grains)', 'The Grain Field'),
  ('Oats, Barley & Rye (Northern Cereals)', 'The Grain Field'),
  ('Pseudocereals (Quinoa, Amaranth & Buckwheat)', 'The Grain Field'),
  ('Rice & Paddy Grains (Oryza)', 'The Grain Field'),
  ('Wheat & Triticum Derivatives', 'The Grain Field'),
  ('Fruits', 'Vegetables'),
  ('Asian Dumplings (Fried & Pan-Fried)', 'Wrapped & Stuffed'),
  ('Asian Dumplings (Steamed)', 'Wrapped & Stuffed'),
  ('Asian Fritters & Fried Bites', 'Wrapped & Stuffed'),
  ('Banana & Fruit Fritters', 'Wrapped & Stuffed'),
  ('Bread & Dough Fritters', 'Wrapped & Stuffed'),
  ('Breads & Accompaniments for Dipping', 'Wrapped & Stuffed'),
  ('Dips & Spreads', 'Wrapped & Stuffed'),
  ('Energy Balls & Bars', 'Wrapped & Stuffed'),
  ('Finger Sandwiches', 'Wrapped & Stuffed'),
  ('Fried & Baked Street Snacks', 'Wrapped & Stuffed'),
  ('High Tea Finger Sandwiches', 'Wrapped & Stuffed'),
  ('Indian Dry Snacks', 'Wrapped & Stuffed'),
  ('Lentil & Legume Fritters', 'Wrapped & Stuffed'),
  ('Open Sandwiches & Tartines', 'Wrapped & Stuffed'),
  ('Paneer & Cheese Fritters', 'Wrapped & Stuffed'),
  ('Popcorn & Grain Snacks', 'Wrapped & Stuffed'),
  ('Puri-Based Chaat', 'Wrapped & Stuffed'),
  ('Rice Cake & Dough Bites', 'Wrapped & Stuffed'),
  ('Salads & Cold Plates (Snack Style)', 'Wrapped & Stuffed'),
  ('Savoury Pancakes & Jeon', 'Wrapped & Stuffed'),
  ('Savoury Pastry Bites', 'Wrapped & Stuffed'),
  ('Savoury Tea Items', 'Wrapped & Stuffed'),
  ('Scones', 'Wrapped & Stuffed'),
  ('Seafood & Meat Fritters', 'Wrapped & Stuffed'),
  ('Skewers & Satay', 'Wrapped & Stuffed'),
  ('Spiced Nuts & Seeds', 'Wrapped & Stuffed'),
  ('Stuffed Buns & Rolls', 'Wrapped & Stuffed'),
  ('Tea Pastries & Cakes', 'Wrapped & Stuffed'),
  ('Toasts & Bruschetta', 'Wrapped & Stuffed'),
  ('Tossed & Assembled Chaat', 'Wrapped & Stuffed'),
  ('Vegetable Fritters & Pakoras', 'Wrapped & Stuffed'),
  ('Wraps & Rolls (Snack Size)', 'Wrapped & Stuffed');

-- ── 3. Deactivate duplicate wrong-category rows when correct row exists ──
UPDATE public.recipe_subcategories wrong
SET is_active = false
FROM tcj_sub_category_fix m
WHERE wrong.name = m.sub_name
  AND wrong.is_active = true
  AND wrong.category IS DISTINCT FROM m.canon_category
  AND EXISTS (
    SELECT 1 FROM public.recipe_subcategories right_row
    WHERE right_row.name = m.sub_name
      AND right_row.category = m.canon_category
      AND right_row.is_active = true
      AND right_row.id <> wrong.id
  );

-- ── 4. Move remaining misassigned subs to canonical category ───────────────
UPDATE public.recipe_subcategories rs
SET category = m.canon_category
FROM tcj_sub_category_fix m
WHERE rs.name = m.sub_name
  AND rs.is_active = true
  AND rs.category IS DISTINCT FROM m.canon_category;

-- ── 5. Align recipe_divisions.category with sub name mapping ───────────────
UPDATE public.recipe_divisions rd
SET category = m.canon_category
FROM tcj_sub_category_fix m
WHERE rd.subcategory = m.sub_name
  AND rd.is_active = true
  AND rd.category IS DISTINCT FROM m.canon_category;

-- ── 6. After (verify) ───────────────────────────────────────────────────────
SELECT name, category
FROM public.recipe_subcategories
WHERE is_active = true
ORDER BY category, name;

-- Misassigned: active subs whose category does not match book mapping
SELECT rs.name, rs.category AS current_category, m.canon_category AS should_be
FROM public.recipe_subcategories rs
LEFT JOIN tcj_sub_category_fix m ON m.sub_name = rs.name
WHERE rs.is_active = true
  AND (m.canon_category IS NULL OR rs.category IS DISTINCT FROM m.canon_category)
ORDER BY rs.category, rs.name;

SELECT category, COUNT(*) AS sub_count
FROM public.recipe_subcategories
WHERE is_active = true
GROUP BY category
ORDER BY category;
