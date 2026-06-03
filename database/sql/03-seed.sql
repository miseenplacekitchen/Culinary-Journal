-- ══════════════════════════════════════════════════════════════════════
-- IMPORTANT: Admin email is miseenplacekitchen.official@gmail.com
-- If your admin account uses a different email, update it here AND
-- in any profile row in Supabase before signing in as admin.
-- ══════════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 03-seed.sql
-- Seed data only. Run AFTER 01-schema.sql and 02-functions.sql.
-- Safe to re-run — all inserts use ON CONFLICT DO NOTHING.
-- ═══════════════════════════════════════════════════════════════

-- ── SUBSTITUTIONS ────────────────────────────────────────────────
INSERT INTO public.substitutions (category, original, substitute, ratio, notes, dietary_benefit) VALUES
-- BAKING
('Baking','Butter','Coconut Oil','1:1','Adds slight coconut flavour. Best for muffins and quick breads.','Vegan, Dairy-Free'),
('Baking','Butter','Applesauce','1:1','Reduces fat, adds moisture and mild sweetness. Best in cakes.','Vegan, Lower Fat'),
('Baking','Eggs','Flax Egg (1 tbsp ground flax + 3 tbsp water)','1 egg = 1 flax egg','Let sit 5 minutes until gel forms. Best in dense baked goods.','Vegan'),
('Baking','Eggs','Chia Egg (1 tbsp chia seeds + 3 tbsp water)','1 egg = 1 chia egg','Let sit 10 minutes. Slightly crunchier texture.','Vegan'),
('Baking','Eggs','Unsweetened Applesauce','1 egg = ¼ cup','Best in moist cakes and muffins. Not suitable for meringues.','Vegan'),
('Baking','Baking Powder','Baking Soda + Cream of Tartar','¼ tsp baking soda + ½ tsp cream of tartar = 1 tsp','Use immediately after mixing.',''),
('Baking','Plain Flour','Almond Flour','1:1 by weight','Denser texture. Adds nutty flavour. Not suitable for bread.','Gluten-Free'),
('Baking','Plain Flour','Gluten-Free Plain Flour Blend','1:1','Best results with blends that include xanthan gum.','Gluten-Free'),
('Baking','Buttermilk','Milk + White Vinegar','1 cup milk + 1 tbsp vinegar','Let stand 5 minutes until slightly curdled.',''),
('Baking','Buttermilk','Plain Yoghurt thinned with milk','3:1 ratio','Use full-fat yoghurt for best results.',''),
-- DAIRY
('Dairy','Milk','Oat Milk','1:1','Closest to whole milk in baking. Mild flavour.','Vegan, Dairy-Free'),
('Dairy','Milk','Almond Milk','1:1','Thinner consistency. Use unsweetened for savoury dishes.','Vegan, Dairy-Free'),
('Dairy','Milk','Soy Milk','1:1','Highest protein of plant milks. Best for baking.','Vegan, Dairy-Free'),
('Dairy','Milk','Coconut Milk (canned, full fat)','1:1','Richer and creamier. Best in soups, curries and desserts.','Vegan, Dairy-Free'),
('Dairy','Heavy Cream','Coconut Cream','1:1','Chill overnight, use solid part. Whips well. Slight coconut flavour.','Vegan, Dairy-Free'),
('Dairy','Heavy Cream','Cashew Cream','1:1','Blend soaked cashews with water until smooth.','Vegan, Dairy-Free'),
('Dairy','Butter','Vegan Butter Block','1:1','Best for baking where butter flavour matters.','Vegan, Dairy-Free'),
('Dairy','Yoghurt','Coconut Yoghurt','1:1','Full-fat works best. Slight coconut flavour.','Vegan, Dairy-Free'),
('Dairy','Cheese (soft)','Cashew Cheese','1:1','Blend soaked cashews with nutritional yeast, lemon and salt.','Vegan, Dairy-Free'),
-- OILS & FATS
('Oils & Fats','Olive Oil','Avocado Oil','1:1','Higher smoke point. Neutral flavour. Ideal for high-heat cooking.',''),
('Oils & Fats','Olive Oil','Coconut Oil','1:1','Adds coconut flavour. Solid at room temperature.','Vegan'),
('Oils & Fats','Vegetable Oil','Sunflower Oil','1:1','Neutral flavour. Good all-purpose substitute.',''),
('Oils & Fats','Butter','Olive Oil','¾ cup per 1 cup butter','Reduces saturated fat. Changes texture slightly.','Dairy-Free'),
('Oils & Fats','Ghee','Clarified Butter','1:1','Nearly identical. Same smoke point and flavour profile.',''),
('Oils & Fats','Ghee','Coconut Oil','1:1','Best for Indian cooking. Adds slight coconut note.','Vegan, Dairy-Free'),
-- SPICES
('Spices','Fresh Ginger','Ground Ginger','1 tsp fresh = ¼ tsp ground','Ground is more concentrated. Less aromatic than fresh.',''),
('Spices','Fresh Garlic','Garlic Powder','1 clove = ⅛ tsp powder','Less pungent than fresh. Add at start of cooking.',''),
('Spices','Fresh Turmeric','Ground Turmeric','1 tsp fresh = ¼ tsp ground','Ground is more concentrated. Earthy flavour.',''),
('Spices','Smoked Paprika','Sweet Paprika + drop of Liquid Smoke','1:1 paprika + 1 drop','Use liquid smoke sparingly — a little goes a long way.',''),
('Spices','Chilli Flakes','Cayenne Pepper','½ tsp cayenne = 1 tsp flakes','Cayenne is hotter. Adjust to taste.',''),
('Spices','Cumin Seeds','Ground Cumin','1 tsp seeds = ¾ tsp ground','Toast ground cumin briefly to develop flavour.',''),
('Spices','Coriander Seeds','Ground Coriander','1 tsp seeds = ¾ tsp ground','',''),
-- VINEGARS
('Vinegars','White Wine Vinegar','Apple Cider Vinegar','1:1','Slightly fruity. Works well in dressings and marinades.',''),
('Vinegars','Red Wine Vinegar','Balsamic Vinegar','1:1 but use less','Sweeter and thicker. Not suitable for delicate dressings.',''),
('Vinegars','Apple Cider Vinegar','Lemon Juice','1:1','Brighter, more citrus flavour. Less complex.',''),
('Vinegars','Rice Wine Vinegar','White Wine Vinegar','1:1','White wine vinegar is slightly more acidic.',''),
-- SWEETENERS
('Sweeteners','White Sugar','Honey','¾ cup honey per 1 cup sugar','Reduce liquid in recipe by ¼ cup. Adds moisture and distinct flavour.',''),
('Sweeteners','White Sugar','Maple Syrup','¾ cup per 1 cup sugar','Reduce other liquids slightly. Adds warm flavour.','Vegan'),
('Sweeteners','White Sugar','Coconut Sugar','1:1','Slightly less sweet. Contains trace minerals. Lower glycaemic index.',''),
('Sweeteners','White Sugar','Stevia','1 tsp per 1 cup sugar','Very sweet — use sparingly. Does not caramelise.','Diabetic Friendly'),
('Sweeteners','Brown Sugar','Coconut Sugar','1:1','Similar caramel notes. Slightly less sweet.',''),
('Sweeteners','Icing Sugar','Blended Coconut Sugar','1:1','Blend coconut sugar until fine. May be slightly less white.','')
ON CONFLICT DO NOTHING;

-- ── PAGE SETTINGS ─────────────────────────────────────────────────
INSERT INTO public.page_settings (page_id, visibility) VALUES
  ('recipes',         'live'),
  ('submit-recipe',   'live'),
  ('recipe-page',     'live'),
  ('grocery',         'live'),
  ('meal-planner',    'live'),
  ('pantry',          'live'),
  ('table-planner',   'live'),
  ('print-studio',    'live'),
  ('collections',     'live'),
  ('family-profiles', 'live'),
  ('baby',            'live'),
  ('preservation',    'live'),
  ('conversions',     'live'),
  ('chefs',           'live'),
  ('search',          'live'),
  ('my-dashboard',    'live'),
  ('profile',         'live')
ON CONFLICT (page_id) DO NOTHING;

-- ── GRANT ADMIN ACCESS ────────────────────────────────────────────
-- Sets your account as admin. Run once after signing up.
UPDATE public.profiles
   SET is_admin = true
 WHERE email = 'miseenplacekitchen.official@gmail.com';
