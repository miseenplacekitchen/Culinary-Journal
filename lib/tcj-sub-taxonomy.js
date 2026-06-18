/**
 * Unified sub-category taxonomy registry (Garden A, Feather B, Pasture C, Ocean D, Grain E, Sips J).
 */
var TCJ_CATEGORY_SUB_TAXONOMY = {
  'Garden & Earth': typeof TCJ_GARDEN_TAXONOMY !== 'undefined' ? TCJ_GARDEN_TAXONOMY : [],
  'Feather & Flock': typeof TCJ_FEATHER_TAXONOMY !== 'undefined' ? TCJ_FEATHER_TAXONOMY : [],
  'Pasture & Hoof': typeof TCJ_PASTURE_TAXONOMY !== 'undefined' ? TCJ_PASTURE_TAXONOMY : [],
  'Ocean & River': typeof TCJ_OCEAN_TAXONOMY !== 'undefined' ? TCJ_OCEAN_TAXONOMY : [],
  'The Grain Field': typeof TCJ_GRAIN_FIELD_TAXONOMY !== 'undefined' ? TCJ_GRAIN_FIELD_TAXONOMY : [],
  'Sips & Stories': typeof TCJ_SIPS_STORIES_TAXONOMY !== 'undefined' ? TCJ_SIPS_STORIES_TAXONOMY : []
};

function getCanonicalCategoryTaxonomy(categoryName) {
  return TCJ_CATEGORY_SUB_TAXONOMY[categoryName] || null;
}

function getCategorySubMeta(categoryName, subName) {
  if (!subName) return null;
  var list = categoryName ? TCJ_CATEGORY_SUB_TAXONOMY[categoryName] : null;
  if (list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].name === subName) return list[i];
    }
  }
  var cats = Object.keys(TCJ_CATEGORY_SUB_TAXONOMY);
  for (var c = 0; c < cats.length; c++) {
    list = TCJ_CATEGORY_SUB_TAXONOMY[cats[c]];
    for (var j = 0; j < list.length; j++) {
      if (list[j].name === subName) return list[j];
    }
  }
  return null;
}

function browseSubPillLabel(subName, categoryName) {
  var sub = getCategorySubMeta(categoryName, subName);
  if (sub && sub.shortName) return sub.shortName;
  return subName || '';
}

function categoryIngredientDisplay(categoryName, subOrName) {
  var sub = typeof subOrName === 'string' ? getCategorySubMeta(categoryName, subOrName) : subOrName;
  if (!sub) return '';
  if (sub.ingredients && sub.ingredients.length) return sub.ingredients.join(', ');
  return sub.examples || '';
}

function parseIngredientHintText(text) {
  return String(text || '').split(/[,;\n]+/).map(function (s) { return s.trim(); }).filter(Boolean);
}

function formatIngredientHints(hints) {
  if (!hints || !hints.length) return '';
  return hints.join(', ');
}

var SUB_TAXONOMY_INFER_ALIASES = {
  'Garden & Earth': typeof GARDEN_INFER_ALIASES !== 'undefined' ? GARDEN_INFER_ALIASES : [],
  'Feather & Flock': [
    [/\b(chicken breast|chicken thigh|drumstick|whole chicken|chicken wing)\b/i, 'Chicken'],
    [/\b(duck breast|magret|duck leg|goose)\b/i, 'Duck & Waterfowl'],
    [/\b(turkey breast|ground turkey|whole turkey)\b/i, 'Turkey & Large Fowl'],
    [/\b(quail|spatchcock)\b/i, 'Quail & Small Bush Fowl'],
    [/\b(squab|pigeon)\b/i, 'Pigeon & Squab'],
    [/\b(pheasant|partridge|woodcock|grouse)\b/i, 'Wild Game Birds'],
    [/\b(ostrich|emu)\b/i, 'Giant Flightless Birds']
  ],
  'Pasture & Hoof': [
    [/\b(brisket|oxtail|ribeye|sirloin|veal|minced beef|ground beef)\b/i, 'Bovine & Cattle'],
    [/\b(lamb chop|goat shank|mutton|lamb leg|lamb shoulder)\b/i, 'Ovine & Caprine'],
    [/\b(pork belly|spare rib|tenderloin|suckling pig|bacon)\b/i, 'Porcine & Swine'],
    [/\b(buffalo|bison|camel)\b/i, 'Heavy Herd Animals'],
    [/\b(venison|antelope|elk)\b/i, 'Wild Deer & Antelope'],
    [/\b(rabbit|hare)\b/i, 'Leporidae & Small Game'],
    [/\b(horse meat|reindeer|basashi)\b/i, 'Steppe & Arctic Mammals']
  ],
  'Ocean & River': [
    [/\b(cod|sea bass|snapper|halibut|haddock)\b/i, 'White & Delicate Finfish'],
    [/\b(salmon|tuna|mackerel|sardine|anchov)\b/i, 'Oily & Robust Finfish'],
    [/\b(rohu|tilapia|catfish|pangasius|snakehead|carp|perch|basa|trout)\b/i, 'Freshwater & River Species'],
    [/\b(prawn|shrimp|lobster|crab|crayfish)\b/i, 'Crustaceans & Crawlers'],
    [/\b(mussel|oyster|clam|scallop|cockle)\b/i, 'Bivalves & Shelled Molluscs'],
    [/\b(squid|calamari|octopus|cuttlefish)\b/i, 'Cephalopods & Soft Tissues'],
    [/\b(shark|swordfish|skate|ray wing)\b/i, 'Cartilaginous & Heavy Marine Giants'],
    [/\b(nori|wakame|kelp|kombu|sea grape|seaweed)\b/i, 'Sea Vegetables & Aquatic Flora']
  ],
  'The Grain Field': [
    [/\b(biryani|pilaf|pulao|fried rice|risotto|congee|khichdi)\b/i, 'Rice & Paddy Grains (Oryza)'],
    [/\b(basmati|jasmine rice|sticky rice|glutinous rice|wild rice)\b/i, 'Rice & Paddy Grains (Oryza)'],
    [/\b(bulgur|couscous|farro|freekeh|wheat berry|spelt|kamut|einkorn|seitan)\b/i, 'Wheat & Triticum Derivatives'],
    [/\b(cornmeal|hominy|polenta|grits|masa harina|cornstarch)\b/i, 'Maize & Corn Starch Kernels (Zea mays)'],
    [/\b(rolled oat|steel.?cut oat|pearl barley|pot barley|rye grain|triticale)\b/i, 'Oats, Barley & Rye (Northern Cereals)'],
    [/\b(bajra|ragi|foxtail millet|kodo millet|jowar|sorghum|teff|fonio|millet)\b/i, 'Millets, Sorghum & Teff (Ancient Dryland Grains)'],
    [/\b(quinoa|amaranth|buckwheat|kasha|chia seed)\b/i, 'Pseudocereals (Quinoa, Amaranth & Buckwheat)'],
    [/\b(wheat bran|oat bran|rice bran|wheat germ|sago|sabudana|tapioca pearl|potato starch)\b/i, 'Grain Brans, Germs & Isolated Starches'],
    [/\b(spaghetti|ramen|vermicelli|glass noodle|soba|udon|pasta|noodle|pho|rice stick)\b/i, 'Milled Strands & Extruded Shapes']
  ],
  'Sips & Stories': [
    [/\b(matcha|earl grey|english breakfast|oolong|rooibos|chamomile|hibiscus tea|tisane|herbal tea|moroccan mint)\b/i, 'True Teas & Botanical Infusions'],
    [/\b(black tea|green tea|white tea|iced tea)\b/i, 'True Teas & Botanical Infusions'],
    [/\b(espresso|cappuccino|pour.?over|turkish coffee|cold brew|nitro coffee|latte|coffee bean)\b/i, 'Coffee Beans & Specialty Brews'],
    [/\b(bubble tea|boba|pearl milk tea|lassi|ayran|chaas|oat milk|almond milk|kefir|yogurt drink|hot chocolate|golden milk|haldi doodh|chocolate milk)\b/i, 'Crafted Milks, Boba & Cultured Dairy'],
    [/\b(smoothie|acai bowl|orange juice|cold.?pressed|green juice|celery juice|fruit juice|milkshake)\b/i, 'Pressed Fruits, Juices & Blended Smoothies'],
    [/\b(lemonade|limeade|shrub|nimbu pani|jaljeera|rose sharbat|simple syrup|cordial|squash concentrate)\b/i, 'Cordials, Syrups & Regional Coolers'],
    [/\b(ginger ale|root beer|craft cola|tonic water|sparkling water|carbonated water|still water|mineral water|soda)\b/i, 'Sodas, Tonics & Effervescent Fizzes'],
    [/\b(kombucha|water kefir|ginger shot|apple cider vinegar|coconut water|electrolyte)\b/i, 'Living Cultures & Functional Tonics (Non-Alcoholic)'],
    [/\b(mocktail|virgin mojito|shirley temple|zero.?proof|non.?alcoholic spirit|seedlip|af gin)\b/i, 'Mocktails & Zero-Proof Mixology'],
    [/\b(cocktail|margarita|mojito|negroni|old fashioned|highball|sour cocktail|tiki)\b/i, 'Wines, Beers & Crafted Spirits (Alcoholic)'],
    [/\b(beer|lager|ipa|stout|wine|sake|soju|cider|vodka|gin|rum|whiskey|whisky|tequila|liqueur|amaro)\b/i, 'Wines, Beers & Crafted Spirits (Alcoholic)']
  ]
};

function buildCategoryInferRules(categoryName) {
  var list = TCJ_CATEGORY_SUB_TAXONOMY[categoryName] || [];
  var rules = [];
  list.forEach(function (sub) {
    (sub.ingredients || []).forEach(function (ing) {
      var term = String(ing).trim();
      if (!term) return;
      var parts = term.split(/\s+/).map(function (w) {
        return w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      });
      var re = new RegExp('\\b' + parts.join('\\s+') + 's?\\b', 'i');
      rules.push({ re: re, sub: sub.name, len: term.length });
    });
  });
  rules.sort(function (a, b) { return b.len - a.len; });
  var out = rules.map(function (r) { return [r.re, r.sub]; });
  var aliases = SUB_TAXONOMY_INFER_ALIASES[categoryName] || [];
  aliases.forEach(function (pair) { out.push(pair); });
  return out;
}

function inferCategorySubFromBlob(categoryName, blob) {
  var text = String(blob || '');
  var out = { sub: '', div: '' };
  if (!text || !categoryName) return out;
  if (categoryName === 'Garden & Earth' && typeof inferGardenSubFromBlob === 'function') {
    return inferGardenSubFromBlob(text);
  }
  var rules = buildCategoryInferRules(categoryName);
  for (var i = 0; i < rules.length; i++) {
    if (rules[i][0].test(text)) {
      out.sub = rules[i][1];
      return out;
    }
  }
  if (categoryName === 'Feather & Flock' && /\b(chicken|poultry)\b/i.test(text)) out.sub = 'Chicken';
  if (categoryName === 'Pasture & Hoof' && /\b(beef|steak)\b/i.test(text)) out.sub = 'Bovine & Cattle';
  if (categoryName === 'Ocean & River' && /\b(fish|seafood)\b/i.test(text)) out.sub = 'White & Delicate Finfish';
  if (categoryName === 'The Grain Field' && /\b(rice|grain)\b/i.test(text)) out.sub = 'Rice & Paddy Grains (Oryza)';
  if (categoryName === 'The Grain Field' && /\b(noodle|pasta)\b/i.test(text)) out.sub = 'Milled Strands & Extruded Shapes';
  if (categoryName === 'Sips & Stories' && /\b(tea|chai)\b/i.test(text)) out.sub = 'True Teas & Botanical Infusions';
  if (categoryName === 'Sips & Stories' && /\b(coffee)\b/i.test(text)) out.sub = 'Coffee Beans & Specialty Brews';
  if (categoryName === 'Sips & Stories' && /\b(juice|smoothie)\b/i.test(text)) out.sub = 'Pressed Fruits, Juices & Blended Smoothies';
  if (categoryName === 'Sips & Stories' && /\b(mocktail)\b/i.test(text)) out.sub = 'Mocktails & Zero-Proof Mixology';
  if (categoryName === 'Sips & Stories' && /\b(cocktail|wine|beer|spirit)\b/i.test(text)) out.sub = 'Wines, Beers & Crafted Spirits (Alcoholic)';
  return out;
}

if (typeof window !== 'undefined') {
  window.TCJ_CATEGORY_SUB_TAXONOMY = TCJ_CATEGORY_SUB_TAXONOMY;
  window.getCanonicalCategoryTaxonomy = getCanonicalCategoryTaxonomy;
  window.getCategorySubMeta = getCategorySubMeta;
  window.browseSubPillLabel = function (subName, categoryName) {
    return browseSubPillLabel(subName, categoryName || (typeof curCatName !== 'undefined' ? curCatName : null));
  };
  window.categoryIngredientDisplay = categoryIngredientDisplay;
  window.parseIngredientHintText = parseIngredientHintText;
  window.formatIngredientHints = formatIngredientHints;
  window.inferCategorySubFromBlob = inferCategorySubFromBlob;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    TCJ_CATEGORY_SUB_TAXONOMY, getCanonicalCategoryTaxonomy, getCategorySubMeta,
    browseSubPillLabel, categoryIngredientDisplay, parseIngredientHintText,
    formatIngredientHints, inferCategorySubFromBlob
  };
}
