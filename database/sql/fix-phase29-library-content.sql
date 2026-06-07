-- ══════════════════════════════════════════════════════════════════════
-- fix-phase29-library-content.sql — 5 more ingredient starters
-- Safe to re-run. Run after fix-phase25/26
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.ingredient_profiles (slug, name, also_known_as, category_group, flavour_profile, how_to_select, how_to_store, how_to_prep, chefs_notes, did_you_know, status, visibility) VALUES
('ginger', 'Ginger', 'Adrak, fresh ginger root', 'Produce', 'Warm, peppery, aromatic — fresh vs dried are different animals.', 'Firm, smooth skin; heavy for size; no wrinkling or mould.', 'Unpeeled in fridge crisper 2–3 weeks; freeze grated in ice cube trays.', 'Scrape skin with spoon; grate fine for marinades; slice for infusions.', 'Young ginger is milder with thinner skin — great for pickles.', 'Ginger has been cultivated in Asia for over three thousand years.', 'published', 'public'),
('lemon', 'Lemon', 'Nimbu, citrus', 'Produce', 'Bright acid and aromatic oils — finish and balance.', 'Heavy for size; thin skin often means more juice.', 'Room temp for a week; fridge extends life; zest before cutting if you need both.', 'Roll before juicing; zest with microplane; remove seeds from dressings.', 'A squeeze at the end beats cooking away volatile aroma.', 'Lemons reached Europe via trade routes from South Asia.', 'published', 'public'),
('potato', 'Potato', 'Aloo, spud', 'Produce', 'Starchy to waxy — variety drives mash vs roast vs salad.', 'Firm, no green tint or sprouts; eyes are fine if shallow.', 'Cool, dark, dry — not fridge (starch converts to sugar).', 'Waxy hold shape; floury fluff when mashed; scrub skin on for roasts.', 'Match variety to dish — all-purpose works but specialists shine.', 'Potatoes were domesticated in the Andes over eight thousand years ago.', 'published', 'public'),
('egg', 'Egg', 'Hen egg', 'Dairy & Eggs', 'Structure, emulsify, bind, leaven — kitchen workhorse.', 'Sell-by ok if shells intact; float test for very old eggs.', 'Fridge; pointed-end down if your tray allows.', 'Room temp for baking; cold for frying if you prefer tight whites.', 'Fresh eggs whip higher; older peel easier when boiled.', 'A single egg contains every nutrient needed to grow a chick except vitamin C.', 'published', 'public'),
('flour', 'Flour', 'Plain flour, all-purpose', 'Pantry', 'Gluten network builder — protein % drives chew vs tenderness.', 'Dry, no smell, no weevils; sealed bag.', 'Airtight cool pantry; freeze long-term in humid climates.', 'Sift only when recipe insists; spoon-and-level for consistent baking.', 'Strong bread flour vs soft cake flour — swapping changes texture.', 'Milling grain into flour is among humanity''s oldest food technologies.', 'published', 'public')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as, category_group = EXCLUDED.category_group,
  flavour_profile = EXCLUDED.flavour_profile, how_to_select = EXCLUDED.how_to_select,
  how_to_store = EXCLUDED.how_to_store, how_to_prep = EXCLUDED.how_to_prep,
  chefs_notes = EXCLUDED.chefs_notes, did_you_know = EXCLUDED.did_you_know,
  status = EXCLUDED.status, visibility = EXCLUDED.visibility, updated_at = now();

SELECT slug, name, status FROM public.ingredient_profiles
WHERE slug IN ('ginger','lemon','potato','egg','flour') ORDER BY slug;
