/**
 * Sips & Stories — sub-category + division inference (Parts A–D).
 * Loaded by submit-recipe.html; mirrored in RecipeExtraction/tcj_extract.py
 */
(function (root) {
  'use strict';

  /** Ordered rules: first match wins. { re, sub, div } */
  var RULES = [
    /* C — Foundations */
    { re: /\b(how to shake|how to stir|shaking technique|stirring technique|muddling technique|layering technique)\b/, sub: 'Techniques & Reference', div: 'Mixing Techniques' },
    { re: /\b(batching drinks|scale.*cocktail|batch.*punch recipe)\b/, sub: 'Techniques & Reference', div: 'Batching & Scaling' },
    { re: /\b(measurement conversion|oz to ml|bar measurements guide)\b/, sub: 'Techniques & Reference', div: 'Measurements & Conversions' },
    { re: /\b(clear ice|crushed ice|ice cube|flavoured ice cube|glassware guide|bar tools)\b/, sub: 'Garnishes, Ice & Glassware', div: 'Ice' },
    { re: /\b(garnish|rim salt|sugar rim|dehydrated fruit|edible flower garnish)\b/, sub: 'Garnishes, Ice & Glassware', div: 'Garnishes' },
    { re: /\b(oleo saccharum|grenadine|orgeat|falernum)\b/, sub: 'Syrups & Sweeteners', div: 'Classic Bar Syrups' },
    { re: /\b(vanilla syrup|ginger syrup|spiced syrup|herbal syrup|fruit syrup recipe)\b/, sub: 'Syrups & Sweeteners', div: 'Flavoured Syrups' },
    { re: /\b(simple syrup|demerara syrup|honey syrup|agave syrup)\b/, sub: 'Syrups & Sweeteners', div: 'Simple & Demerara Syrups' },
    { re: /\b(shrub|drinking vinegar)\b/, sub: 'Shrubs, Bitters & Infusions', div: 'Drinking-Vinegar Shrubs' },
    { re: /\b(homemade bitters|aromatic bitters|angostura style)\b/, sub: 'Shrubs, Bitters & Infusions', div: 'Homemade Bitters' },
    { re: /\b(tincture|botanical infusion concentrate)\b/, sub: 'Shrubs, Bitters & Infusions', div: 'Tinctures & Botanical Infusions' },
    { re: /\b(fruit cordial|squash concentrate|barley water concentrate)\b/, sub: 'Cordials, Squash & Concentrates', div: 'Fruit Cordials & Squash' },
    { re: /\b(agua fresca concentrate|horchata concentrate)\b/, sub: 'Cordials, Squash & Concentrates', div: 'Agua Fresca & Horchata Concentrates' },
    { re: /\b(sour mix|fruit purée|puree concentrate)\b/, sub: 'Cordials, Squash & Concentrates', div: 'Purées & Sour Mixes' },

    /* D3 — For Kids */
    { re: /\b(kids|kid.?friendly|children|toddler|babyccino)\b.*\b(mocktail|fizz|punch)\b/, sub: 'For Kids', div: 'Fun Mocktails & Fizzes' },
    { re: /\b(kids|children)\b.*\b(cocoa|hot chocolate|milk drink)\b/, sub: 'For Kids', div: 'Hot Cocoa & Milk Drinks' },
    { re: /\b(kids|children)\b.*\b(smoothie|juice|milkshake|shake)\b/, sub: 'For Kids', div: 'Juice Blends, Smoothies & Milkshakes' },
    { re: /\b(kids|children|kid.?friendly)\b.*\b(punch)\b/, sub: 'For Kids', div: 'Party Punches (Alcohol-Free)' },

    /* D4 — Mocktails */
    { re: /\b(zero.?proof|non.?alcoholic spirit|seedlip|spirit.?free|af gin|af rum)\b/, sub: 'Mocktails & Zero-Proof', div: 'Zero-Proof Spirits' },
    { re: /\b(botanical elixir|adaptogen drink|af spritz|alcohol.?free spritz)\b/, sub: 'Mocktails & Zero-Proof', div: 'Botanical Elixirs & AF Spritzes' },
    { re: /\b(mocktail|virgin cocktail|no.?alcohol cocktail|sans alcohol|virgin mojito|virgin margarita)\b/, sub: 'Mocktails & Zero-Proof', div: 'Craft Mocktails' },
    { re: /\b(alcohol.?free (old fashioned|negroni|martini|margarita|moscow mule))\b/, sub: 'Mocktails & Zero-Proof', div: 'Alcohol-Free Classics' },

    /* B4 — Cocktails */
    { re: /\b(margarita|daiquiri|whiskey sour|sidecar|amaretto sour)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Sours' },
    { re: /\b(gin and tonic|gin & tonic|mojito|paloma|cuba libre|moscow mule|highball)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Highballs & Long Drinks' },
    { re: /\b(french 75|tom collins|aperol spritz|spritz cocktail)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Bubbles & Spritzes' },
    { re: /\b(mai tai|piña colada|pina colada|painkiller|zombie|tiki)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Tiki & Tropical' },
    { re: /\b(espresso martini|white russian|flip cocktail)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Creamy & Flips' },
    { re: /\b(old fashioned|negroni|manhattan|martini|boulevardier)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Spirit-Forward & Stirred' },
    { re: /\b(hot toddy|irish coffee|hot buttered rum)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Hot Cocktails' },
    { re: /\b(frozen daiquiri|frozen margarita|blended cocktail|frozen cocktail)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Frozen & Blended' },
    { re: /\b(party punch|batch cocktail|hard seltzer|rtd|ready.?to.?drink|alcopop)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Punches, Batched & RTDs' },
    { re: /\b(cocktail|mixed drink)\b/, sub: 'Cocktails & Mixed Drinks', div: 'Highballs & Long Drinks' },

    /* B3 — Spirits */
    { re: /\b(limoncello|infused vodka|infused gin|homemade liqueur)\b/, sub: 'Spirits & Liqueurs', div: 'Homemade Infusions' },
    { re: /\b(campari|aperol|amaretto|chartreuse|triple sec|cointreau|kahlua|amaro|schnapps|liqueur)\b/, sub: 'Spirits & Liqueurs', div: 'Liqueurs & Amari' },
    { re: /\b(vodka|gin|rum|cachaça|cachaca|tequila|mezcal|whiskey|whisky|bourbon|scotch|rye|brandy|cognac|pisco|aquavit|absinthe|spirit)\b/, sub: 'Spirits & Liqueurs', div: 'Base Spirits' },

    /* B2 — Wine */
    { re: /\b(sangria|mimosa|bellini|kir|wine spritz|mulled wine|glühwein|gluhwein)\b/, sub: 'Wine, Cider & Fermented Fruit', div: 'Wine Drinks' },
    { re: /\b(sake|makgeolli|soju|rice wine)\b/, sub: 'Wine, Cider & Fermented Fruit', div: 'Rice & Grain Wines' },
    { re: /\b(mead|honey wine)\b/, sub: 'Wine, Cider & Fermented Fruit', div: 'Mead' },
    { re: /\b(cider|perry|hard cider)\b/, sub: 'Wine, Cider & Fermented Fruit', div: 'Cider & Perry' },
    { re: /\b(port|sherry|madeira|marsala|vermouth|fortified wine)\b/, sub: 'Wine, Cider & Fermented Fruit', div: 'Fortified Wines' },
    { re: /\b(wine|prosecco|champagne|rosé|rose wine|red wine|white wine|pinot|merlot|shiraz|cava)\b/, sub: 'Wine, Cider & Fermented Fruit', div: 'Wine' },

    /* B1 — Beer */
    { re: /\b(shandy|radler|michelada|black and tan|black & tan)\b/, sub: 'Beer & Brewing', div: 'Beer Drinks' },
    { re: /\b(homebrew|home.?brew|brew your own beer)\b/, sub: 'Beer & Brewing', div: 'Homebrew' },
    { re: /\b(ginger ale|ginger beer)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Ginger Ale & Ginger Beer' },
    { re: /\b(beer|lager|ale|pilsner|ipa|stout|porter|hefeweizen|wheat beer|sour beer|saison|bock)\b/, sub: 'Beer & Brewing', div: 'Beer Styles' },

    /* A8 — Functional */
    { re: /\b(kombucha|water kefir|jun|fermented soda|wild soda)\b/, sub: 'Functional & Fermented', div: 'Kombucha & Fermented Sodas' },
    { re: /\b(switchel|sekanjabin|fire cider)\b/, sub: 'Functional & Fermented', div: 'Switchel & Sekanjabin' },
    { re: /\b(energy drink|monster|red bull|pre.?workout)\b/, sub: 'Functional & Fermented', div: 'Energy Drinks' },
    { re: /\b(sports drink|electrolyte|gatorade|rehydration|isotonic)\b/, sub: 'Functional & Fermented', div: 'Electrolyte & Sports Drinks' },
    { re: /\b(probiotic tonic|adaptogen|wellness tonic|wellness drink)\b/, sub: 'Functional & Fermented', div: 'Wellness Tonics' },

    /* A5 — Juices, Smoothies & Blends */
    { re: /\b(protein shake|protein drink|whey|mass gainer|meal replacement shake)\b/, sub: 'Juices, Smoothies & Blends', div: 'Protein & Functional Shakes' },
    { re: /\b(smoothie|smoothie bowl|açaí|acai bowl|green smoothie|breakfast smoothie)\b/, sub: 'Juices, Smoothies & Blends', div: 'Smoothies' },
    { re: /\b(milkshake|milk shake|malt drink|malted shake)\b/, sub: 'Juices, Smoothies & Blends', div: 'Milkshakes & Malts' },
    { re: /\b(juice|nectar|cold.?pressed|fresh pressed|green juice|vegetable juice|citrus juice)\b/, sub: 'Juices, Smoothies & Blends', div: 'Fresh & Cold-Pressed Juices' },

    /* A7 — Sodas */
    { re: /\b(cola|lemon.?lime soda|root beer|cream soda|egg cream|soft drink)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Soft Drinks' },
    { re: /\b(craft soda|small.?batch soda|artisan soda)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Craft & Small-Batch Sodas' },
    { re: /\b(italian soda|flavoured soda|flavored soda)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Italian & Flavoured Sodas' },
    { re: /\b(tonic water|quinine tonic)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Tonic Waters & Mixers' },
    { re: /\b(lemonade|limeade|agua fresca)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Lemonades & Limeades' },

    /* A6 — Milk & cultured */
    { re: /\b(lassi|ayran|doogh|drinking kefir|chaas|buttermilk drink)\b/, sub: 'Milk, Plant Milks & Cultured Drinks', div: 'Yogurt & Cultured Drinks' },
    { re: /\b(oat milk|almond milk|soy milk|coconut milk|rice milk|cashew milk|hemp milk|pea milk|nut milk|plant milk)\b/, sub: 'Milk, Plant Milks & Cultured Drinks', div: 'Plant Milks' },
    { re: /\b(chocolate milk|flavoured milk|buttermilk|dairy milk|glass of milk)\b/, sub: 'Milk, Plant Milks & Cultured Drinks', div: 'Dairy Milks' },

    /* A4 — Hot chocolate */
    { re: /\b(hot chocolate|drinking chocolate)\b/, sub: 'Hot Chocolate & Warm Comforts', div: 'Classic Cocoa & Drinking Chocolate' },
    { re: /\b(mexican hot chocolate|champurrado|spiced cocoa|spiced hot chocolate)\b/, sub: 'Hot Chocolate & Warm Comforts', div: 'Spiced Hot Chocolate' },
    { re: /\b(golden milk|turmeric latte|haldi doodh|steamer drink)\b/, sub: 'Hot Chocolate & Warm Comforts', div: 'Golden Milk & Steamers' },
    { re: /\b(sahlab|salep|malted warmer)\b/, sub: 'Hot Chocolate & Warm Comforts', div: 'Sahlab & Malted Warmers' },

    /* A3 — Tea */
    { re: /\b(bubble tea|boba|pearl milk tea)\b/, sub: 'Tea & Infusions', div: 'Bubble / Boba Tea' },
    { re: /\b(matcha latte|matcha drink|ceremonial matcha)\b/, sub: 'Tea & Infusions', div: 'Matcha' },
    { re: /\b(masala chai|hong kong milk tea|thai iced tea|butter tea|milk tea)\b/, sub: 'Tea & Infusions', div: 'Spiced & Milk Teas' },
    { re: /\b(iced tea|ice tea|tea cooler)\b/, sub: 'Tea & Infusions', div: 'Iced Teas & Coolers' },
    { re: /\b(peppermint tea|chamomile|rooibos|hibiscus tea|tisane|herbal tea|fruit tea blend)\b/, sub: 'Tea & Infusions', div: 'Herbal & Tisanes' },
    { re: /\b(black tea|green tea|white tea|oolong|pu.?erh|puerh)\b/, sub: 'Tea & Infusions', div: 'True Teas' },
    { re: /\b(yerba mate|mate cocido)\b/, sub: 'Tea & Infusions', div: 'Herbal & Tisanes' },
    { re: /\b(tea|chai)\b/, sub: 'Tea & Infusions', div: 'True Teas' },

    /* A2 — Coffee */
    { re: /\b(affogato|bulletproof coffee|spiced latte|pumpkin spice latte)\b/, sub: 'Coffee', div: 'Specialty Coffee' },
    { re: /\b(cold brew|nitro coffee|iced latte|frappé|frappe|dalgona|whipped coffee)\b/, sub: 'Coffee', div: 'Cold Coffee' },
    { re: /\b(espresso|americano|latte|cappuccino|flat white|cortado|macchiato|mocha)\b/, sub: 'Coffee', div: 'Espresso-Based' },
    { re: /\b(filter coffee|pour.?over|french press|turkish coffee|vietnamese coffee|cà phê|ca phe|drip coffee)\b/, sub: 'Coffee', div: 'Brewed Coffee' },
    { re: /\b(coffee|iced coffee)\b/, sub: 'Coffee', div: 'Brewed Coffee' },

    /* A1 — Water */
    { re: /\b(spa water|detox water)\b/, sub: 'Water & Sparkling', div: 'Spa & Detox Waters' },
    { re: /\b(vitamin water|flavoured water|flavored water)\b/, sub: 'Water & Sparkling', div: 'Flavoured & Vitamin Waters' },
    { re: /\b(infused water|cucumber water|fruit water|berry water|citrus water)\b/, sub: 'Water & Sparkling', div: 'Infused & Fruit Waters' },
    { re: /\b(sparkling water|seltzer|carbonated water|club soda)\b/, sub: 'Water & Sparkling', div: 'Sparkling Water' },
    { re: /\b(mineral water|still water|spring water)\b/, sub: 'Water & Sparkling', div: 'Still & Mineral Water' },

    /* D2 — Season */
    { re: /\b(summer cooler|summer drink)\b/, sub: 'By Season & Occasion', div: 'Summer Coolers' },
    { re: /\b(winter warmer|winter drink|cozy drink)\b/, sub: 'By Season & Occasion', div: 'Winter Warmers' },
    { re: /\b(brunch drink|brunch cocktail|brunch mocktail)\b/, sub: 'By Season & Occasion', div: 'Brunch' },
    { re: /\b(eggnog|coquito|festive punch|celebration drink)\b/, sub: 'By Season & Occasion', div: 'Celebration & Festive' },
    { re: /\b(nightcap|wind.?down|bedtime drink)\b/, sub: 'By Season & Occasion', div: 'Nightcaps & Wind-Downs' },

    /* D1 — World drinks */
    { re: /\b(chicha|tepache|mauby|sorrel drink|atole|horchata)\b/, sub: 'World Drinks', div: 'The Americas' },
    { re: /\b(kvass|sbiten|kompot)\b/, sub: 'World Drinks', div: 'Europe' },
    { re: /\b(bissap|moroccan mint tea|jallab|tamr hindi)\b/, sub: 'World Drinks', div: 'Africa & Middle East' },
    { re: /\b(jamu|sharbat|sherbet drink)\b/, sub: 'World Drinks', div: 'South & Central Asia' },
    { re: /\b(vietnamese egg coffee|ca phe trung|ramune|calpis)\b/, sub: 'World Drinks', div: 'East & Southeast Asia' },

    { re: /\b(cocktail|spirit|wine|beer)\b/, sub: 'Cocktails & Mixed Drinks', div: '' },
    { re: /\b(mocktail)\b/, sub: 'Mocktails & Zero-Proof', div: '' },
    { re: /\b(smoothie|shake|milkshake)\b/, sub: 'Juices, Smoothies & Blends', div: '' },
    { re: /\b(juice|lemonade)\b/, sub: 'Juices, Smoothies & Blends', div: '' },

    { re: /\b(drink|beverage|sip|thirst|refreshment)\b/, sub: 'Sodas, Tonics & Fizz', div: 'Lemonades & Limeades' }
  ];

  function infer(blob) {
    var text = String(blob || '').toLowerCase().replace(/\s+/g, ' ');
    var out = { sub: '', div: '' };
    if (!text) return out;
    for (var i = 0; i < RULES.length; i++) {
      if (RULES[i].re.test(text)) {
        out.sub = RULES[i].sub;
        out.div = RULES[i].div || '';
        return out;
      }
    }
    return out;
  }

  function inferCategory(blob) {
    var text = String(blob || '').toLowerCase();
    var drinkRe = /\b(water|coffee|tea|espresso|latte|matcha|juice|smoothie|shake|milkshake|milk|drink|beverage|cocktail|mocktail|spirit|wine|beer|cider|liqueur|vodka|gin|rum|whiskey|whisky|tequila|kombucha|kefir|lassi|tonic|soda|cordial|squash|shrub|agua fresca|horchata|yerba mate|kvass|chicha|protein shake|energy drink|lemonade|refresher|hot chocolate|cocoa|sharbat|bubble tea|boba|syrup|bitters|sake|soju|mead|spritz|negroni|mojito)\b/;
    return drinkRe.test(text) ? 'Sips & Stories' : '';
  }

  root.DrinkTaxonomyInfer = { infer: infer, inferCategory: inferCategory, RULES: RULES };
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this);
