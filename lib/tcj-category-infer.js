/**
 * Recipe category inference (A–K) + user-friendly tag suggestions.
 * Breakfast, baby food, nourishing/recovery → tags (meal_type / health), not main categories.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.TcjCategoryInfer = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function () {

  var CATS = (typeof TCJ_CATEGORY_NAMES !== 'undefined' && TCJ_CATEGORY_NAMES.length)
    ? TCJ_CATEGORY_NAMES.slice()
    : [
      'Garden & Earth', 'Feather & Flock', 'Pasture & Hoof', 'Ocean & River',
      'The Grain Field', 'Wrapped & Stuffed', 'Curds, Creams & Eggs', 'Breads & Bakery',
      'Sweet Serenades', 'Sips & Stories', 'Preserved & Pantry'
    ];

  var LEGACY_TO_V2 = {
    'Rise & Shine': 'Curds, Creams & Eggs',
    'The Evening Table': 'Wrapped & Stuffed',
    'Meat & Fire': 'Feather & Flock',
    'Slow & Soulful': 'Pasture & Hoof',
    'Grains & Comfort': 'The Grain Field',
    'Breads & Bakes': 'Breads & Bakery',
    'Preserved & Cherished': 'Preserved & Pantry',
    'Little Ones': 'Garden & Earth',
    'Feast Days': 'Pasture & Hoof',
    'Nourish & Heal': 'Garden & Earth'
  };

  var MEAL_TAG_IDS = {
    'Breakfast': 'tag-mt-breakfast',
    'Brunch': 'tag-mt-brunch',
    'Lunch': 'tag-mt-lunch',
    'Dinner': 'tag-mt-dinner',
    'Snack': 'tag-mt-snack',
    'Drink': 'tag-mt-drink',
    'Soup': 'tag-mt-soup',
    'Salad': 'tag-mt-salad',
    'Main Course': 'tag-mt-main',
    'Side Dish': 'tag-mt-side',
    'Appetizer': 'tag-mt-appetizer',
    'Bread': 'tag-mt-bread',
    'Rice Dish': 'tag-mt-rice',
    'Dessert': 'tag-mt-dessert',
    'Frozen Treat': 'tag-mt-frozen',
    'Preserve / Pickle': 'tag-mt-preserve'
  };

  var HEALTH_TAG_IDS = {
    'High Protein': 'tag-hp',
    'Low Carb': 'tag-lc',
    'Low Fat': 'tag-lf',
    'Low Sodium': 'tag-ls',
    'Diabetic Friendly': 'tag-diab',
    'Baby Friendly': 'tag-bf',
    'Kid Friendly': 'tag-kf',
    'Recovery Food': 'tag-recovery'
  };

  var CATEGORY_RULES = [
    { re: /\b(biriyani|biryani|pilaf|pulao|fried rice)\b/i, cat: 'The Grain Field', meal: ['Rice Dish'] },
    { re: /\b(puttu|idiyappam)\b/i, cat: 'Breads & Bakery', meal: ['Breakfast', 'Bread'] },
    { re: /\b(idli|dosa|appam)\b/i, cat: 'Breads & Bakery', meal: ['Breakfast'] },
    { re: /\b(roti|rotti|chapati|paratha|naan|flatbread|bread|loaf|roll|pita|kulcha)\b/i, cat: 'Breads & Bakery', meal: ['Bread'] },
    { re: /\b(waffle|pancake|omelette|porridge|congee|kanji|upma|cereal)\b/i, cat: 'Curds, Creams & Eggs', meal: ['Breakfast'] },
    { re: /\b(cake|cookie|brownie|muffin|cupcake|halwa|ladoo|barfi|kheer|pudding|dessert|sweet|pie|tart)\b/i, cat: 'Sweet Serenades', meal: ['Dessert'] },
    { re: /\b(soup|rasam|shorba|broth|stew|khichdi)\b/i, cat: 'Pasture & Hoof', meal: ['Soup'] },
    { re: /\b(pickle|chutney|jam|preserve|ferment|canning)\b/i, cat: 'Preserved & Pantry', meal: ['Preserve / Pickle'] },
    { re: /\b(dumpling|empanada|samosa|wonton|gyoza|momos|mandu|spring roll)\b/i, cat: 'Wrapped & Stuffed', meal: ['Appetizer'] },
    { re: /\b(mocktail|cocktail|martini|margarita|mojito|daiquiri|sangria|spritz|negroni|liqueur|spirit|vodka|gin|rum|whiskey|whisky|bourbon|tequila|brandy|wine|beer|cider|prosecco|champagne|mezcal|aperol|campari|bitters|shandy|rtd|hard seltzer)\b/i, cat: 'Sips & Stories', meal: ['Drink'] },
    { re: /\b(water|sparkling water|coffee|espresso|latte|cappuccino|matcha|tea|herbal tea|tisane|juice|nectar|smoothie|milkshake|shake|protein shake|kombucha|kefir|lassi|chaas|bubble tea|boba|tonic|soda|lemonade|hot chocolate|cocoa|drink|beverage)\b/i, cat: 'Sips & Stories', meal: ['Drink'] },
    { re: /\b(salad|raita|vegetable|sabzi|thoran|aubergine|eggplant|potato|legume|dal|lentil)\b/i, cat: 'Garden & Earth', meal: ['Side Dish'] },
    { re: /\b(fish|prawn|shrimp|crab|lobster|salmon|tuna|seafood|meen)\b/i, cat: 'Ocean & River', meal: ['Main Course'] },
    { re: /\b(chicken|duck|turkey|poultry)\b/i, cat: 'Feather & Flock', meal: ['Main Course'] },
    { re: /\b(mutton|lamb|beef|pork|meat|steak|bacon|sausage|goat)\b/i, cat: 'Pasture & Hoof', meal: ['Main Course'] },
    { re: /\b(cheese|paneer|yogurt|curd|cream|butter|egg)\b/i, cat: 'Curds, Creams & Eggs', meal: [] },
    { re: /\b(rice|nasi|grain|pasta|noodle)\b/i, cat: 'The Grain Field', meal: ['Rice Dish'] }
  ];

  function normalizeCategory(cat) {
    if (!cat) return null;
    var c = String(cat).trim();
    if (CATS.indexOf(c) >= 0) return c;
    return LEGACY_TO_V2[c] || null;
  }

  function blobFrom(name, ingredientLines) {
    var lines = ingredientLines || [];
    var parts = [String(name || '')];
    for (var i = 0; i < lines.length; i++) {
      parts.push(typeof lines[i] === 'string' ? lines[i] : String(lines[i] || ''));
    }
    return parts.join(' ').toLowerCase();
  }

  function inferUserFriendlyTags(name, ingredientLines, category) {
    var blob = blobFrom(name, ingredientLines);
    var mealType = [];
    var health = [];
    var occasion = [];
    var tagIds = [];

    if (/\b(baby|infant|weaning|puree|toddler)\b/i.test(blob) || category === 'Little Ones') {
      health.push('Baby Friendly');
      if (/\b(toddler|finger food)\b/i.test(blob)) health.push('Kid Friendly');
    }
    if (/\b(kid.?friendly|kids|children)\b/i.test(blob)) health.push('Kid Friendly');

    if (/\b(recovery|convalescen|postpartum|nursing|pathila|pathiam|okayu|nourish|healing|gentle|light meal|sick.?day|wellness)\b/i.test(blob)
        || category === 'Nourish & Heal') {
      health.push('Recovery Food');
    }
    if (/\b(diabetic|low.?gi|low glycemic)\b/i.test(blob)) health.push('Diabetic Friendly');
    if (/\b(high.?protein|protein.?rich)\b/i.test(blob)) health.push('High Protein');
    if (/\b(low.?carb|keto)\b/i.test(blob)) health.push('Low Carb');
    if (/\b(low.?sodium|low.?salt)\b/i.test(blob)) health.push('Low Sodium');

    if (/\b(breakfast|brunch|morning)\b/i.test(blob) || category === 'Rise & Shine') mealType.push('Breakfast');
    if (/\b(lunch)\b/i.test(blob)) mealType.push('Lunch');
    if (/\b(dinner|supper)\b/i.test(blob)) mealType.push('Dinner');

    if (/\b(onam|sadya|payasam)\b/i.test(blob)) occasion.push('Onam');
    if (/\b(eid|ramadan)\b/i.test(blob)) occasion.push('Eid');
    if (/\b(christmas|xmas)\b/i.test(blob)) occasion.push('Christmas');
    if (/\b(diwali|deepavali)\b/i.test(blob)) occasion.push('Diwali');
    if (/\b(wedding)\b/i.test(blob)) occasion.push('Wedding');
    if (/\b(party|feast|celebration)\b/i.test(blob) || category === 'Feast Days') occasion.push('Party');

    mealType.forEach(function (m) { if (MEAL_TAG_IDS[m]) tagIds.push(MEAL_TAG_IDS[m]); });
    health.forEach(function (h) { if (HEALTH_TAG_IDS[h]) tagIds.push(HEALTH_TAG_IDS[h]); });

    return { mealType: mealType, health: health, occasion: occasion, tagIds: tagIds };
  }

  function inferFromBlob(name, ingredientLines) {
    var blob = blobFrom(name, ingredientLines);
    var category = 'The Grain Field';
    var mealType = [];

    for (var i = 0; i < CATEGORY_RULES.length; i++) {
      if (CATEGORY_RULES[i].re.test(blob)) {
        category = CATEGORY_RULES[i].cat;
        mealType = (CATEGORY_RULES[i].meal || []).slice();
        break;
      }
    }

    if (typeof DrinkTaxonomyInfer !== 'undefined' && DrinkTaxonomyInfer.inferCategory) {
      var drinkCat = DrinkTaxonomyInfer.inferCategory(blob);
      if (drinkCat) category = normalizeCategory(drinkCat) || category;
    }

    if (/\b(breakfast|brunch)\b/i.test(blob) && mealType.indexOf('Breakfast') < 0) {
      mealType.push('Breakfast');
    }

    var tags = inferUserFriendlyTags(name, ingredientLines, null);
    tags.mealType.forEach(function (m) {
      if (mealType.indexOf(m) < 0) mealType.push(m);
    });

    tags.mealType = mealType;
    tags.category = category;
    tags.mealType.forEach(function (m) {
      if (MEAL_TAG_IDS[m] && tags.tagIds.indexOf(MEAL_TAG_IDS[m]) < 0) tags.tagIds.push(MEAL_TAG_IDS[m]);
    });

    return tags;
  }

  function inferRecipeCategoryFromBlob(name, ingredientLines) {
    return inferFromBlob(name, ingredientLines).category;
  }

  return {
    TCJ_INFER_CATEGORIES: CATS,
    LEGACY_TO_V2: LEGACY_TO_V2,
    MEAL_TAG_IDS: MEAL_TAG_IDS,
    HEALTH_TAG_IDS: HEALTH_TAG_IDS,
    normalizeCategory: normalizeCategory,
    inferFromBlob: inferFromBlob,
    inferRecipeCategoryFromBlob: inferRecipeCategoryFromBlob,
    inferUserFriendlyTags: inferUserFriendlyTags
  };
});
