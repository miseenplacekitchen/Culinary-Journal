/**
 * Unified sub-category taxonomy registry (Garden A, Feather B, Pasture C, Ocean D).
 */
var TCJ_CATEGORY_SUB_TAXONOMY = {
  'Garden & Earth': typeof TCJ_GARDEN_TAXONOMY !== 'undefined' ? TCJ_GARDEN_TAXONOMY : [],
  'Feather & Flock': typeof TCJ_FEATHER_TAXONOMY !== 'undefined' ? TCJ_FEATHER_TAXONOMY : [],
  'Pasture & Hoof': typeof TCJ_PASTURE_TAXONOMY !== 'undefined' ? TCJ_PASTURE_TAXONOMY : [],
  'Ocean & River': typeof TCJ_OCEAN_TAXONOMY !== 'undefined' ? TCJ_OCEAN_TAXONOMY : []
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
