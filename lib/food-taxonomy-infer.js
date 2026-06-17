/**
 * Food categories — sub-category + division inference from recipe name/ingredients.
 * Loaded by submit-recipe.html; Sips & Stories uses drink-taxonomy-infer.js instead.
 */
(function (root) {
  'use strict';

  var RULES = {
    'Rise & Shine': [
      { re: /\b(congee|jook|kanji|okayu|khao tom|champorado)\b/, sub: 'Rice Porridges', div: 'Congee / jook' },
      { re: /\b(oat|overnight oat|bircher|steel.?cut oat|dalia)\b/, sub: 'Oat & Grain Porridges', div: 'Rolled oat porridge' },
      { re: /\b(upma|rava upma|semolina porridge|cream of wheat)\b/, sub: 'Semolina & Flour Porridges', div: 'Upma' },
      { re: /\b(grits|polenta porridge|ogi|akamu|ragi porridge|millet porridge)\b/, sub: 'Cornmeal & Other Grain Porridges', div: 'Grits' },
      { re: /\b(idli|rava idli|kanchipuram idli)\b/, sub: 'Idlis', div: 'Plain idli' },
      { re: /\b(dosa|masala dosa|neer dosa|rava dosa|pesarattu)\b/, sub: 'Dosas', div: 'Plain dosa' },
      { re: /\b(appam|vellayappam|idiyappam|string hopper)\b/, sub: 'Appams & Hoppers', div: 'Appam (lacy bowl hoppers)' },
      { re: /\b(puttu|kozhukatta|ada)\b/, sub: 'Puttu & Steamed Rice Dishes', div: 'Puttu (rice & coconut)' },
      { re: /\b(baozi|cheung fun|steamed bun)\b/, sub: 'Steamed Buns & Dumplings (Breakfast)', div: 'Baozi (plain & filled)' },
      { re: /\b(chawanmushi|steamed egg)\b/, sub: 'Steamed Egg Dishes', div: 'Chawanmushi' },
      { re: /\b(pancake|waffle|crepe|french toast|dutch baby)\b/, sub: 'Griddled & Fried Batters', div: 'Pancakes' },
      { re: /\b(omelette|omelet|frittata|scrambled egg|shakshuka|eggs benedict)\b/, sub: 'Eggs & Savory Skillets', div: 'Omelettes' },
      { re: /\b(paratha|thepla|msemen|roti canai|breakfast wrap)\b/, sub: 'Flatbreads & Wraps (Breakfast)', div: 'Stuffed parathas' },
      { re: /\b(smoothie bowl|breakfast smoothie|acai bowl)\b/, sub: 'Smoothie Bowls & Blended Breakfasts', div: 'Smoothie bowls' },
      { re: /\b(breakfast|brunch|morning)\b/, sub: 'Eggs & Savory Skillets', div: 'Scrambles & skillets' }
    ],
    'The Evening Table': [
      { re: /\b(roast chicken|roast beef|roast lamb|sunday roast)\b/, sub: 'Roasts & Baked Mains', div: 'Roast poultry' },
      { re: /\b(steak|grilled steak|beef tenderloin)\b/, sub: 'Grilled & Pan-Seared Mains', div: 'Beef steaks' },
      { re: /\b(pasta|spaghetti|penne|carbonara|bolognese|lasagna)\b/, sub: 'Pasta & Noodles (Evening)', div: 'Long pasta' },
      { re: /\b(risotto|paella|pilaf|jambalaya)\b/, sub: 'Rice & Grain Mains (Evening)', div: 'Risotto' },
      { re: /\b(curry|korma|vindaloo|tikka masala|butter chicken)\b/, sub: 'Curries & Stews (Evening)', div: 'Chicken curries' },
      { re: /\b(stir.?fry|wok|fried rice)\b/, sub: 'Stir-Fries & Wok Dishes', div: 'Vegetable stir-fries' },
      { re: /\b(soup|bisque|chowder|minestrone)\b/, sub: 'Soups & Broths (Evening)', div: 'Clear soups' },
      { re: /\b(salad|caesar|nicoise|cobb)\b/, sub: 'Salads (Evening)', div: 'Green salads' },
      { re: /\b(casserole|gratin|shepherd|hotpot|pot pie)\b/, sub: 'Casseroles & Bakes', div: 'Meat casseroles' },
      { re: /\b(finger sandwich|tea sandwich|high tea)\b/, sub: 'High Tea Finger Sandwiches', div: 'Classic finger sandwiches' },
      { re: /\b(dinner|supper|evening meal|main course)\b/, sub: 'Roasts & Baked Mains', div: '' }
    ],
    'Meat & Fire': [
      { re: /\b(mutton|goat curry|goat stew|goat roast)\b/, sub: 'Mutton & Goat', div: 'Mutton curries' },
      { re: /\b(lamb chop|lamb shank|lamb roast|rack of lamb)\b/, sub: 'Lamb', div: 'Lamb roasts' },
      { re: /\b(chicken|poultry|turkey|duck)\b/, sub: 'Poultry', div: 'Roast chicken' },
      { re: /\b(beef|steak|brisket|short rib|burger patty)\b/, sub: 'Beef', div: 'Steaks & chops' },
      { re: /\b(pork|bacon|ham|sausage|prosciutto)\b/, sub: 'Pork', div: 'Pork roasts' },
      { re: /\b(bbq|barbecue|smoked|smoker|pulled pork|ribs)\b/, sub: 'BBQ & Smoking', div: 'Low & slow BBQ' },
      { re: /\b(kebab|seekh|shish|satay|yakitori)\b/, sub: 'Kebabs & Skewers', div: 'Grilled kebabs' },
      { re: /\b(venison|game|wild boar|rabbit)\b/, sub: 'Game & Offal', div: 'Game meats' },
      { re: /\b(meatball|meatloaf|mince|ground beef)\b/, sub: 'Mince & Patties', div: 'Meatballs' }
    ],
    'Ocean & River': [
      { re: /\b(salmon|trout|cod|halibut|sea bass|snapper|mackerel)\b/, sub: 'Finfish', div: 'Salmon & trout' },
      { re: /\b(shrimp|prawn|lobster|crab|crayfish)\b/, sub: 'Shellfish & Crustaceans', div: 'Shrimp & prawns' },
      { re: /\b(oyster|mussel|clam|scallop)\b/, sub: 'Bivalves & Molluscs', div: 'Oysters' },
      { re: /\b(sushi|sashimi|ceviche|poke|tartare)\b/, sub: 'Raw & Cured Seafood', div: 'Sushi & sashimi' },
      { re: /\b(fish curry|fish stew|bouillabaisse|cioppino)\b/, sub: 'Fish Stews & Curries', div: 'Fish curries' },
      { re: /\b(fried fish|fish and chips|fish fry|tempura fish)\b/, sub: 'Fried & Battered Fish', div: 'Fish & chips' },
      { re: /\b(grilled fish|baked fish|poached fish|en papillote)\b/, sub: 'Grilled, Baked & Poached Fish', div: 'Grilled whole fish' },
      { re: /\b(anchovy|sardine|herring|pickled fish)\b/, sub: 'Small Fish & Preserved Seafood', div: 'Anchovies & sardines' },
      { re: /\b(fish|seafood|shellfish)\b/, sub: 'Finfish', div: '' }
    ],
    'Slow & Soulful': [
      { re: /\b(dal|lentil soup|sambar|rasam)\b/, sub: 'Lentils & Legume Soups', div: 'Dal' },
      { re: /\b(chili|chilli con carne|bean stew)\b/, sub: 'Bean & Legume Stews', div: 'Chili' },
      { re: /\b(miso soup|ramen|pho|udon soup|bone broth)\b/, sub: 'Broths & Noodle Soups', div: 'Miso soup' },
      { re: /\b(stew|ragu|ragout|pot roast|braised)\b/, sub: 'Stews & Braises', div: 'Meat stews' },
      { re: /\b(soup|chowder|bisque|gumbo|minestrone)\b/, sub: 'Soups & Chowders', div: 'Hearty soups' },
      { re: /\b(casserole|hotpot|tagine|dutch oven)\b/, sub: 'One-Pot Comfort', div: 'Baked casseroles' },
      { re: /\b(curry|korma|massaman|rendang)\b/, sub: 'Slow Curries', div: 'Meat curries' },
      { re: /\b(slow cook|crockpot|instant pot stew)\b/, sub: 'Slow Cooker & Pressure Cooker', div: 'Slow-cooked mains' }
    ],
    'Grains & Comfort': [
      { re: /\b(biryani|biriyani|pilaf|pulao|tahdig)\b/, sub: 'Biryanis & Pilafs', div: 'Chicken Biryani' },
      { re: /\b(fried rice|nasi goreng|biryani rice)\b/, sub: 'Fried & Stir-Fried Rice', div: 'Classic fried rice' },
      { re: /\b(risotto|paella|jambalaya|arroz)\b/, sub: 'Risottos & Paellas', div: 'Risotto' },
      { re: /\b(khichdi|kitchari|congee savory|porridge savory)\b/, sub: 'Khichdi & Savory Porridges', div: 'Khichdi' },
      { re: /\b(polenta|grits|cornmeal mush)\b/, sub: 'Polenta & Cornmeal Dishes', div: 'Creamy polenta' },
      { re: /\b(couscous|bulgur|quinoa|farro|barley bowl)\b/, sub: 'Whole Grains & Ancient Grains', div: 'Grain bowls' },
      { re: /\b(stuffing|dressing|grain salad)\b/, sub: 'Stuffings & Grain Salads', div: 'Bread stuffings' },
      { re: /\b(rice bowl|grain bowl|comfort rice)\b/, sub: 'Rice Bowls & Platters', div: 'Rice bowls' }
    ],
    'Breads & Bakes': [
      { re: /\b(sourdough|ciabatta|baguette|focaccia|loaf bread)\b/, sub: 'Yeast Breads', div: 'Sourdough' },
      { re: /\b(naan|roti|paratha|chapati|pita|lavash|flatbread)\b/, sub: 'Flatbreads', div: 'Naan' },
      { re: /\b(croissant|danish|pain au chocolat|viennoiserie)\b/, sub: 'Pastries & Viennoiserie', div: 'Croissants' },
      { re: /\b(muffin|scone|biscuit quick|quick bread)\b/, sub: 'Quick Breads & Muffins', div: 'Muffins' },
      { re: /\b(pizza|calzone|focaccia pizza)\b/, sub: 'Pizza & Flatbread Bakes', div: 'Classic pizza' },
      { re: /\b(pie|quiche|tart savory|galette)\b/, sub: 'Pies & Savory Tarts', div: 'Quiche' },
      { re: /\b(pretzel|bagel|bun|roll)\b/, sub: 'Rolls, Buns & Pretzels', div: 'Dinner rolls' },
      { re: /\b(bread|bake|baking|dough)\b/, sub: 'Yeast Breads', div: '' }
    ],
    'Sweet Serenades': [
      { re: /\b(chocolate cake|vanilla cake|layer cake|birthday cake|sponge cake)\b/, sub: 'Cakes & Layer Cakes', div: 'Chocolate cakes' },
      { re: /\b(cheesecake|tiramisu|panna cotta|mousse)\b/, sub: 'Custards, Mousses & Cheesecakes', div: 'Cheesecakes' },
      { re: /\b(cookie|biscuit sweet|shortbread|macaron|madeleine)\b/, sub: 'Cookies & Biscuits', div: 'Drop cookies' },
      { re: /\b(pie sweet|tart sweet|galette sweet|cobbler|crumble)\b/, sub: 'Pies, Tarts & Cobblers', div: 'Fruit pies' },
      { re: /\b(ice cream|gelato|sorbet|frozen dessert|semifreddo)\b/, sub: 'Ice Cream & Frozen Desserts', div: 'Ice cream' },
      { re: /\b(pudding|custard|flan|creme brulee|rice pudding)\b/, sub: 'Puddings & Custards', div: 'Rice puddings' },
      { re: /\b(fudge|truffle|caramel|toffee|brittle|confection)\b/, sub: 'Confections & Candies', div: 'Fudge & truffles' },
      { re: /\b(ladoo|barfi|halwa|gulab jamun|jalebi|rasgulla)\b/, sub: 'Indian & South Asian Sweets', div: 'Milk sweets' },
      { re: /\b(dessert|sweet|pastry sweet|treat)\b/, sub: 'Cakes & Layer Cakes', div: '' }
    ],
    'Preserved & Cherished': [
      { re: /\b(pickle|achar|pickled|brined vegetable)\b/, sub: 'Pickles & Ferments', div: 'Vegetable pickles' },
      { re: /\b(jam|jelly|marmalade|preserve fruit|compote)\b/, sub: 'Jams, Jellies & Fruit Preserves', div: 'Berry jams' },
      { re: /\b(chutney|relish|mostarda|atjar)\b/, sub: 'Chutneys & Relishes', div: 'Fruit chutneys' },
      { re: /\b(sauerkraut|kimchi|fermented vegetable|lacto)\b/, sub: 'Ferments & Cultures', div: 'Sauerkraut' },
      { re: /\b(spice blend|masala powder|garam masala|curry powder|dukkah)\b/, sub: 'Spice Blends & Seasoning Mixes', div: 'Curry powders' },
      { re: /\b(cured meat|jerky|bacon cure|salumi|smoked fish preserve)\b/, sub: 'Cured & Smoked Preserves', div: 'Cured meats' },
      { re: /\b(canning|bottling|shelf.?stable|lacto.?ferment)\b/, sub: 'Canning & Bottling', div: 'Water-bath canning' }
    ],
    'Feast Days': [
      { re: /\b(thanksgiving|turkey feast|christmas|easter|diwali|eid|lunar new year|passover|hanukkah)\b/, sub: 'Holiday & Religious Feasts', div: 'Celebration mains' },
      { re: /\b(wedding feast|banquet|party spread|festive platter)\b/, sub: 'Celebration Spreads', div: 'Feast platters' },
      { re: /\b(stuffing|gravy|cranberry|festive side)\b/, sub: 'Festive Sides & Trimmings', div: 'Holiday sides' },
      { re: /\b(festive dessert|yule log|panettone|stollen|fruitcake)\b/, sub: 'Festive Sweets', div: 'Holiday desserts' },
      { re: /\b(feast|festive|celebration|special occasion)\b/, sub: 'Holiday & Religious Feasts', div: '' }
    ],
    'Little Ones': [
      { re: /\b(baby food|weaning|first food|puree baby|infant)\b/, sub: 'First Foods & Purees (6–9 months)', div: 'Single-ingredient purees' },
      { re: /\b(toddler|finger food kid|baby led weaning|blw)\b/, sub: 'Finger Foods & BLW (9–12 months)', div: 'Soft finger foods' },
      { re: /\b(kids lunch|school lunch|lunchbox|bento kid)\b/, sub: 'Lunchboxes & School Meals', div: 'Sandwich lunches' },
      { re: /\b(hidden veg|sneaky veg|kid.?friendly dinner)\b/, sub: 'Hidden-Veg & Family Dinners', div: 'Pasta with hidden veg' },
      { re: /\b(kids snack|after school snack)\b/, sub: 'Snacks & Treats (Kids)', div: 'Healthy snacks' },
      { re: /\b(baby|toddler|kid|children|family favourite)\b/, sub: 'Family Favourites', div: '' }
    ],
    'Nourish & Heal': [
      { re: /\b(keto|low.?carb|atkins)\b/, sub: 'Low-Carb & Keto', div: 'Keto mains' },
      { re: /\b(paleo|whole30|grain.?free)\b/, sub: 'Paleo & Whole-Food', div: 'Paleo bowls' },
      { re: /\b(vegan protein|plant.?based protein|tofu bowl)\b/, sub: 'Plant-Based Protein', div: 'Tofu & tempeh mains' },
      { re: /\b(gluten.?free|celiac|gf bread|gf pasta)\b/, sub: 'Gluten-Free', div: 'GF baking' },
      { re: /\b(dairy.?free|lactose.?free|vegan dairy)\b/, sub: 'Dairy-Free', div: 'Dairy-free alternatives' },
      { re: /\b(anti.?inflammatory|gut health|probiotic food|bone broth heal)\b/, sub: 'Gut Health & Anti-Inflammatory', div: 'Healing broths' },
      { re: /\b(diabetic|low.?sugar|blood sugar|insulin friendly)\b/, sub: 'Blood-Sugar Friendly', div: 'Low-GI meals' },
      { re: /\b(recovery|post.?workout|high.?protein heal|therapeutic)\b/, sub: 'Recovery & Therapeutic', div: 'Protein recovery meals' },
      { re: /\b(healthy|nourish|healing|wellness|diet)\b/, sub: 'Dietary & Health Tags', div: '' }
    ],
    'Garden & Earth': [
      { re: /\b(salad|greens|lettuce|kale|spinach)\b/, sub: 'Salads & Raw Preparations', div: 'Green salads' },
      { re: /\b(stir.?fry vegetable|sabzi|poriyal|thoran|bhaji)\b/, sub: 'Cooked Vegetable Dishes', div: 'Stir-fried vegetables' },
      { re: /\b(curry vegetable|vegetable korma|paneer|tofu)\b/, sub: 'Vegetable Curries & Stews', div: 'Paneer dishes' },
      { re: /\b(fruit salad|fruit dessert fresh|compote fresh)\b/, sub: 'Fruits & Fruit Dishes', div: 'Fresh fruit preparations' },
      { re: /\b(legume|bean|lentil vegetarian|dal veg)\b/, sub: 'Legumes & Pulses (Plant-Based)', div: 'Bean dishes' },
      { re: /\b(vegetable|vegan|veggie|plant.?based)\b/, sub: 'Cooked Vegetable Dishes', div: '' }
    ]
  };

  function infer(category, blob) {
    var text = String(blob || '').toLowerCase().replace(/\s+/g, ' ');
    var out = { sub: '', div: '' };
    if (!category || !text) return out;
    var list = RULES[category];
    if (!list) return out;
    for (var i = 0; i < list.length; i++) {
      if (list[i].re.test(text)) {
        out.sub = list[i].sub;
        out.div = list[i].div || '';
        return out;
      }
    }
    return out;
  }

  root.FoodTaxonomyInfer = { infer: infer, RULES: RULES };
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this);
