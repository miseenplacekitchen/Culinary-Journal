-- fix-sips-drinks-taxonomy.sql
-- Sips & Stories drink taxonomy (Parts A–D). Safe to re-run.
-- Run in Supabase SQL Editor once (re-run after taxonomy updates).

-- Deactivate superseded sub-categories from earlier drafts (legacy names kept active)
UPDATE public.recipe_subcategories SET is_active = false
WHERE category = 'Sips & Stories'
  AND name IN (
    'Non-Alcoholic Drinks', 'Functional Beverages', 'Alcoholic Drinks',
    'Traditional & Regional Drinks', 'Mocktails & Non-Alcoholic Spirits',
    'Syrups, Cordials & Concentrates', 'Carbonated Sodas & Tonics',
    'Protein Drinks', 'Refreshment Drinks', 'Kids'' Drinks'
  );

-- ── Part A: Non-alcoholic ─────────────────────────────────────────────────────
INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Sips & Stories', 'Water & Sparkling', 10, true),
  ('Sips & Stories', 'Coffee', 20, true),
  ('Sips & Stories', 'Tea & Infusions', 30, true),
  ('Sips & Stories', 'Hot Chocolate & Warm Comforts', 40, true),
  ('Sips & Stories', 'Juices, Smoothies & Blends', 50, true),
  ('Sips & Stories', 'Milk, Plant Milks & Cultured Drinks', 60, true),
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 70, true),
  ('Sips & Stories', 'Functional & Fermented', 80, true),
  -- Part B: With alcohol
  ('Sips & Stories', 'Beer & Brewing', 100, true),
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 110, true),
  ('Sips & Stories', 'Spirits & Liqueurs', 120, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 130, true),
  -- Part C: Foundations
  ('Sips & Stories', 'Syrups & Sweeteners', 200, true),
  ('Sips & Stories', 'Cordials, Squash & Concentrates', 210, true),
  ('Sips & Stories', 'Shrubs, Bitters & Infusions', 220, true),
  ('Sips & Stories', 'Garnishes, Ice & Glassware', 230, true),
  ('Sips & Stories', 'Techniques & Reference', 240, true),
  -- Part D: Collections
  ('Sips & Stories', 'World Drinks', 300, true),
  ('Sips & Stories', 'By Season & Occasion', 310, true),
  ('Sips & Stories', 'For Kids', 320, true),
  ('Sips & Stories', 'Mocktails & Zero-Proof', 330, true),
  -- Legacy (existing recipes)
  ('Sips & Stories', 'Cocktails & Spirits', 401, true),
  ('Sips & Stories', 'Mocktails', 402, true),
  ('Sips & Stories', 'Smoothies & Shakes', 403, true),
  ('Sips & Stories', 'Tea & Coffee', 404, true),
  ('Sips & Stories', 'Juices & Refreshers', 405, true)
ON CONFLICT (category, name) DO UPDATE SET
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

-- ── Divisions ─────────────────────────────────────────────────────────────────
INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, sort_order, is_active) VALUES
  -- A1 Water & Sparkling
  ('Sips & Stories', 'Water & Sparkling', 'Still & Mineral Water', '💧', 'Pure hydration', 'Still and mineral waters.', 1, true),
  ('Sips & Stories', 'Water & Sparkling', 'Sparkling Water', '🫧', 'Effervescent', 'Sparkling and carbonated waters.', 2, true),
  ('Sips & Stories', 'Water & Sparkling', 'Infused & Fruit Waters', '🍋', 'Light flavour', 'Cucumber-mint, citrus, berry and fruit-infused waters.', 3, true),
  ('Sips & Stories', 'Water & Sparkling', 'Flavoured & Vitamin Waters', '🥤', 'Fortified', 'Flavoured and vitamin-enhanced waters.', 4, true),
  ('Sips & Stories', 'Water & Sparkling', 'Spa & Detox Waters', '🌿', 'Wellness', 'Spa and detox-style infused waters.', 5, true),
  -- A2 Coffee
  ('Sips & Stories', 'Coffee', 'Espresso-Based', '☕', 'Bar classics', 'Espresso, americano, latte, cappuccino, flat white, cortado, macchiato, mocha.', 1, true),
  ('Sips & Stories', 'Coffee', 'Brewed Coffee', '☕', 'Slow brew', 'Filter, pour-over, French press, Turkish, Vietnamese cà phê.', 2, true),
  ('Sips & Stories', 'Coffee', 'Cold Coffee', '🧊', 'Chilled', 'Cold brew, nitro, iced latte, frappé, Dalgona.', 3, true),
  ('Sips & Stories', 'Coffee', 'Specialty Coffee', '✨', 'Seasonal & rich', 'Affogato, spiced lattes, bulletproof and specialty serves.', 4, true),
  -- A3 Tea & Infusions
  ('Sips & Stories', 'Tea & Infusions', 'True Teas', '🍵', 'Camellia sinensis', 'Black, green, white, oolong and pu-erh.', 1, true),
  ('Sips & Stories', 'Tea & Infusions', 'Spiced & Milk Teas', '🫖', 'Chai & milk tea', 'Masala chai, Hong Kong milk tea, Thai iced tea, butter tea.', 2, true),
  ('Sips & Stories', 'Tea & Infusions', 'Matcha', '🍃', 'Powdered green', 'Hot, iced and matcha lattes.', 3, true),
  ('Sips & Stories', 'Tea & Infusions', 'Herbal & Tisanes', '🌸', 'Caffeine-free', 'Peppermint, chamomile, rooibos, hibiscus and fruit blends.', 4, true),
  ('Sips & Stories', 'Tea & Infusions', 'Bubble / Boba Tea', '🧋', 'Tapioca & tea', 'Bubble tea and boba drinks.', 5, true),
  ('Sips & Stories', 'Tea & Infusions', 'Iced Teas & Coolers', '🧊', 'Chilled tea', 'Iced teas and tea-based coolers.', 6, true),
  -- A4 Hot Chocolate & Warm Comforts
  ('Sips & Stories', 'Hot Chocolate & Warm Comforts', 'Classic Cocoa & Drinking Chocolate', '🍫', 'Rich & creamy', 'Classic cocoa and drinking chocolate.', 1, true),
  ('Sips & Stories', 'Hot Chocolate & Warm Comforts', 'Spiced Hot Chocolate', '🌶', 'Warm spice', 'Mexican chocolate, champurrado and spiced cocoa.', 2, true),
  ('Sips & Stories', 'Hot Chocolate & Warm Comforts', 'Golden Milk & Steamers', '🥛', 'Warm & soothing', 'Golden milk, turmeric latte and steamers.', 3, true),
  ('Sips & Stories', 'Hot Chocolate & Warm Comforts', 'Sahlab & Malted Warmers', '🌾', 'Traditional warmers', 'Sahlab, malted warmers and similar.', 4, true),
  -- A5 Juices, Smoothies & Blends
  ('Sips & Stories', 'Juices, Smoothies & Blends', 'Fresh & Cold-Pressed Juices', '🍊', 'Extracted', 'Fruit, citrus, vegetable and green juices.', 1, true),
  ('Sips & Stories', 'Juices, Smoothies & Blends', 'Smoothies', '🥤', 'Blended', 'Fruit, green, breakfast/oats and açaí-style smoothies.', 2, true),
  ('Sips & Stories', 'Juices, Smoothies & Blends', 'Milkshakes & Malts', '🍨', 'Thick & creamy', 'Milkshakes and malt drinks.', 3, true),
  ('Sips & Stories', 'Juices, Smoothies & Blends', 'Protein & Functional Shakes', '💪', 'Fortified blends', 'Protein and functional shake blends.', 4, true),
  -- A6 Milk, Plant Milks & Cultured Drinks
  ('Sips & Stories', 'Milk, Plant Milks & Cultured Drinks', 'Dairy Milks', '🥛', 'Cow & dairy', 'Plain and flavoured milk, buttermilk, chocolate milk.', 1, true),
  ('Sips & Stories', 'Milk, Plant Milks & Cultured Drinks', 'Plant Milks', '🌱', 'Non-dairy', 'Oat, almond, soy, coconut, rice, cashew, hemp, pea and homemade nut milks.', 2, true),
  ('Sips & Stories', 'Milk, Plant Milks & Cultured Drinks', 'Yogurt & Cultured Drinks', '🫙', 'Probiotic dairy', 'Lassi, ayran, doogh and drinking kefir.', 3, true),
  -- A7 Sodas, Tonics & Fizz
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 'Soft Drinks', '🥤', 'Classic soda', 'Cola, lemon-lime, root beer, cream soda, egg cream.', 1, true),
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 'Craft & Small-Batch Sodas', '🍾', 'Artisan fizz', 'Craft and small-batch sodas.', 2, true),
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 'Italian & Flavoured Sodas', '🍒', 'Syrup & soda', 'Italian sodas and flavoured soda serves.', 3, true),
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 'Tonic Waters & Mixers', '🫧', 'Bar mixers', 'Tonic waters and non-alcoholic mixers.', 4, true),
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 'Ginger Ale & Ginger Beer', '🫚', 'Spicy fizz', 'Ginger ale and non-alcoholic ginger beer.', 5, true),
  ('Sips & Stories', 'Sodas, Tonics & Fizz', 'Lemonades & Limeades', '🍋', 'Citrus refreshers', 'Homemade lemonades and limeades.', 6, true),
  -- A8 Functional & Fermented
  ('Sips & Stories', 'Functional & Fermented', 'Kombucha & Fermented Sodas', '🫙', 'Live culture', 'Kombucha, water kefir, jun and wild fermented sodas.', 1, true),
  ('Sips & Stories', 'Functional & Fermented', 'Switchel & Sekanjabin', '🍯', 'Vinegar & honey', 'Switchel, sekanjabin and similar.', 2, true),
  ('Sips & Stories', 'Functional & Fermented', 'Energy Drinks', '⚡', 'Boost', 'Commercial and homemade energy drinks.', 3, true),
  ('Sips & Stories', 'Functional & Fermented', 'Electrolyte & Sports Drinks', '🏃', 'Rehydration', 'Electrolyte and sports recovery drinks.', 4, true),
  ('Sips & Stories', 'Functional & Fermented', 'Wellness Tonics', '🌿', 'Gut & adaptogens', 'Probiotic, adaptogenic and fire-cider tonics.', 5, true),
  -- B1 Beer & Brewing
  ('Sips & Stories', 'Beer & Brewing', 'Beer Styles', '🍺', 'Ales & lagers', 'Ale, lager, pilsner, IPA, stout, porter, wheat, sour, saison, bock.', 1, true),
  ('Sips & Stories', 'Beer & Brewing', 'Homebrew', '🏠', 'Brew your own', 'Homebrew basics and recipes.', 2, true),
  ('Sips & Stories', 'Beer & Brewing', 'Beer Drinks', '🍻', 'Mixed beer', 'Shandy, radler, michelada, black & tan.', 3, true),
  -- B2 Wine, Cider & Fermented Fruit
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 'Wine', '🍷', 'Still & sparkling', 'Red, white, rosé, orange, sparkling and dessert wines.', 1, true),
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 'Fortified Wines', '🍷', 'Port & sherry', 'Port, sherry, madeira, marsala, vermouth.', 2, true),
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 'Cider & Perry', '🍎', 'Apple & pear', 'Cider and perry.', 3, true),
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 'Mead', '🍯', 'Honey wine', 'Mead and honey ferments.', 4, true),
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 'Rice & Grain Wines', '🍶', 'East Asian', 'Sake, makgeolli, soju.', 5, true),
  ('Sips & Stories', 'Wine, Cider & Fermented Fruit', 'Wine Drinks', '🥂', 'Mixed wine', 'Sangria, mimosa, bellini, kir, spritz, mulled wine.', 6, true),
  -- B3 Spirits & Liqueurs
  ('Sips & Stories', 'Spirits & Liqueurs', 'Base Spirits', '🥃', 'Distilled', 'Vodka, gin, rum, tequila, whiskey, brandy, pisco, aquavit, absinthe.', 1, true),
  ('Sips & Stories', 'Spirits & Liqueurs', 'Liqueurs & Amari', '🍸', 'Sweet & bitter', 'Triple sec, amaretto, Campari, Aperol, Chartreuse, cream liqueurs.', 2, true),
  ('Sips & Stories', 'Spirits & Liqueurs', 'Homemade Infusions', '🫙', 'DIY spirits', 'Limoncello, flavoured vodkas and infused gins.', 3, true),
  -- B4 Cocktails & Mixed Drinks
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Sours', '🍋', 'Citrus-shaken', 'Margarita, daiquiri, whiskey sour, sidecar.', 1, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Highballs & Long Drinks', '🥤', 'Tall & easy', 'Gin & tonic, mojito, paloma, Cuba libre, Moscow mule.', 2, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Spirit-Forward & Stirred', '🥃', 'Strong & stirred', 'Old fashioned, negroni, Manhattan, martini, boulevardier.', 3, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Bubbles & Spritzes', '🫧', 'Sparkling serves', 'French 75, Tom Collins, Aperol spritz.', 4, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Tiki & Tropical', '🌺', 'Island style', 'Mai tai, piña colada, painkiller, zombie.', 5, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Creamy & Flips', '🍦', 'Rich & velvety', 'Espresso martini, white Russian, flips.', 6, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Hot Cocktails', '🔥', 'Warm serve', 'Hot toddy, Irish coffee, hot buttered rum.', 7, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Frozen & Blended', '🧊', 'Blended cocktails', 'Frozen daiquiris and blended mixed drinks.', 8, true),
  ('Sips & Stories', 'Cocktails & Mixed Drinks', 'Punches, Batched & RTDs', '🎉', 'Crowd serves', 'Party punch, hard seltzer, canned classics.', 9, true),
  -- C1 Syrups & Sweeteners
  ('Sips & Stories', 'Syrups & Sweeteners', 'Simple & Demerara Syrups', '🍯', 'Bar basics', 'Simple, demerara, honey and agave syrups.', 1, true),
  ('Sips & Stories', 'Syrups & Sweeteners', 'Flavoured Syrups', '🌿', 'Infused sweet', 'Vanilla, ginger, spiced, herbal and fruit syrups.', 2, true),
  ('Sips & Stories', 'Syrups & Sweeteners', 'Classic Bar Syrups', '🍒', 'Cocktail staples', 'Oleo saccharum, grenadine, orgeat, falernum.', 3, true),
  -- C2 Cordials, Squash & Concentrates
  ('Sips & Stories', 'Cordials, Squash & Concentrates', 'Fruit Cordials & Squash', '🍋', 'Diluted drinks', 'Fruit cordials and squash concentrates.', 1, true),
  ('Sips & Stories', 'Cordials, Squash & Concentrates', 'Agua Fresca & Horchata Concentrates', '🌺', 'Latin bases', 'Agua fresca and horchata concentrate bases.', 2, true),
  ('Sips & Stories', 'Cordials, Squash & Concentrates', 'Purées & Sour Mixes', '🍊', 'Bar prep', 'Fruit purées and sour mix concentrates.', 3, true),
  -- C3 Shrubs, Bitters & Infusions
  ('Sips & Stories', 'Shrubs, Bitters & Infusions', 'Drinking-Vinegar Shrubs', '🫙', 'Sweet-sour', 'Fruit and herb drinking-vinegar shrubs.', 1, true),
  ('Sips & Stories', 'Shrubs, Bitters & Infusions', 'Homemade Bitters', '🌿', 'Aromatic', 'Homemade and aromatic bitters.', 2, true),
  ('Sips & Stories', 'Shrubs, Bitters & Infusions', 'Tinctures & Botanical Infusions', '💧', 'Concentrated', 'Tinctures and botanical infusions.', 3, true),
  -- C4 Garnishes, Ice & Glassware
  ('Sips & Stories', 'Garnishes, Ice & Glassware', 'Ice', '🧊', 'Clear & crushed', 'Clear, crushed, shaped and flavoured ice.', 1, true),
  ('Sips & Stories', 'Garnishes, Ice & Glassware', 'Garnishes', '🍋', 'Finishing touches', 'Rims, twists, dehydrated fruit, edible flowers.', 2, true),
  ('Sips & Stories', 'Garnishes, Ice & Glassware', 'Glassware & Tools', '🥂', 'Serve right', 'Glassware guide and bar tools.', 3, true),
  -- C5 Techniques & Reference
  ('Sips & Stories', 'Techniques & Reference', 'Mixing Techniques', '🔄', 'How to mix', 'Shaking, stirring, building, layering, muddling.', 1, true),
  ('Sips & Stories', 'Techniques & Reference', 'Batching & Scaling', '📋', 'For crowds', 'Batching and scaling drinks for groups.', 2, true),
  ('Sips & Stories', 'Techniques & Reference', 'Measurements & Conversions', '📐', 'Reference', 'Measurements and conversion guides.', 3, true),
  -- D1 World Drinks
  ('Sips & Stories', 'World Drinks', 'The Americas', '🌎', 'Regional heritage', 'Chicha, agua fresca, horchata, atole, tepache, mauby, sorrel.', 1, true),
  ('Sips & Stories', 'World Drinks', 'South America (Southern Cone)', '🧉', 'Mate country', 'Yerba mate, mate cocido.', 2, true),
  ('Sips & Stories', 'World Drinks', 'Europe', '🏰', 'Old World', 'Kvass, glühwein, sbiten, kompot.', 3, true),
  ('Sips & Stories', 'World Drinks', 'Africa & Middle East', '🕌', 'Regional classics', 'Bissap, Moroccan mint tea, ayran, doogh, sahlab, salep.', 4, true),
  ('Sips & Stories', 'World Drinks', 'South & Central Asia', '🕌', 'Subcontinent', 'Lassi, masala chai, jamu.', 5, true),
  ('Sips & Stories', 'World Drinks', 'East & Southeast Asia', '🍵', 'Asian serves', 'Bubble tea, egg coffee, Thai iced tea, sake, soju, ramune, Calpis.', 6, true),
  -- D2 By Season & Occasion
  ('Sips & Stories', 'By Season & Occasion', 'Summer Coolers', '☀️', 'Hot weather', 'Lemonades, aguas frescas, iced teas, spritzes.', 1, true),
  ('Sips & Stories', 'By Season & Occasion', 'Winter Warmers', '❄️', 'Cold weather', 'Cocoa, mulled wine, toddies, sahlab.', 2, true),
  ('Sips & Stories', 'By Season & Occasion', 'Brunch', '🥂', 'Morning celebration', 'Mimosas, fresh juices, coffee drinks.', 3, true),
  ('Sips & Stories', 'By Season & Occasion', 'Celebration & Festive', '🎉', 'Special days', 'Punches, sparkling, eggnog, coquito.', 4, true),
  ('Sips & Stories', 'By Season & Occasion', 'Nightcaps & Wind-Downs', '🌙', 'Evening calm', 'Nightcap and wind-down drinks.', 5, true),
  -- D3 For Kids
  ('Sips & Stories', 'For Kids', 'Fun Mocktails & Fizzes', '🎈', 'Special treats', 'Colourful mocktails and fizzy fun for children.', 1, true),
  ('Sips & Stories', 'For Kids', 'Hot Cocoa & Milk Drinks', '🍼', 'Warm & mild', 'Hot cocoa and milk drinks for kids.', 2, true),
  ('Sips & Stories', 'For Kids', 'Juice Blends, Smoothies & Milkshakes', '🧃', 'Everyday sips', 'Juice blends, smoothies and milkshakes for children.', 3, true),
  ('Sips & Stories', 'For Kids', 'Party Punches (Alcohol-Free)', '🎉', 'Sharing', 'Large-batch alcohol-free punches for kids.', 4, true),
  -- D4 Mocktails & Zero-Proof
  ('Sips & Stories', 'Mocktails & Zero-Proof', 'Craft Mocktails', '🍹', 'Premium zero-proof', 'Layered craft mocktails.', 1, true),
  ('Sips & Stories', 'Mocktails & Zero-Proof', 'Zero-Proof Spirits', '🌱', 'Spirit alternatives', 'Non-alcoholic gin, rum, whiskey and how to use them.', 2, true),
  ('Sips & Stories', 'Mocktails & Zero-Proof', 'Botanical Elixirs & AF Spritzes', '🌸', 'Herbal & calm', 'Botanical elixirs and alcohol-free spritzes.', 3, true),
  ('Sips & Stories', 'Mocktails & Zero-Proof', 'Alcohol-Free Classics', '🍸', 'Classic without ABV', 'Alcohol-free versions of classic cocktails.', 4, true)
ON CONFLICT (category, subcategory, name) DO UPDATE SET
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  subtitle = EXCLUDED.subtitle,
  description = EXCLUDED.description;

-- Verify
SELECT subcategory_name, count(*)::int AS divisions
FROM (
  SELECT DISTINCT subcategory AS subcategory_name, name
  FROM public.recipe_divisions
  WHERE category = 'Sips & Stories' AND is_active = true
) d
GROUP BY subcategory_name
ORDER BY subcategory_name;
