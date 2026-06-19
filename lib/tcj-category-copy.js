/**
 * Canonical TCJ recipe categories (A–K, 2026 v2) — titles and browse copy.
 * Live browse cards load from Supabase `categories`; run fix-categories-v2.sql to sync DB.
 */
var TCJ_CATEGORY_COPY = [
  { id: 'garden-earth', name: 'Garden & Earth', emoji: '🥬', description: 'Fresh vegetables, nourishing legumes, earthy roots, and wild greens that connect you to the land and seasons.' },
  { id: 'feather-flock', name: 'Feather & Flock', emoji: '🐓', description: 'Poultry in every form. Chicken, duck, turkey prepared with skill across cultures.' },
  { id: 'pasture-hoof', name: 'Pasture & Hoof', emoji: '🍖', description: 'Rich meats grilled, roasted, braised, or slow-cooked to bring depth and satisfaction. Each cut tells its own story.' },
  { id: 'ocean-river', name: 'Ocean & River', emoji: '🌊', description: 'The sea\u2019s generous gifts. Fresh finfish, shellfish, and crustaceans that carry the salt and soul of coastal traditions.' },
  { id: 'grain-field', name: 'The Grain Field', emoji: '🌾', description: 'The foundation of home cooking. Rice, noodles, pasta, pilafs, and grain bowls that anchor meals and nourish the body.' },
  { id: 'wrapped-stuffed', name: 'Wrapped & Stuffed', emoji: '🥟', description: 'Crafted with intention and care. Dumplings, empanadas, samosas, and hand-folded doughs filled with tradition.' },
  { id: 'curds-creams-eggs', name: 'Curds, Creams & Eggs', emoji: '🥛', description: 'Eggs that bind and nourish. Cheese that flavours. Dairy that enriches everything it touches.' },
  { id: 'breads-bakery', name: 'Breads & Bakery', emoji: '🫓', description: 'The smell of home baking. Flatbreads, yeasted loaves, and savoury pastries that warm the kitchen and the heart.' },
  { id: 'sweet-serenades', name: 'Sweet Serenades', emoji: '🍮', description: 'Moments of joy and celebration. Desserts, cakes, puddings, and confections that sweeten life.' },
  { id: 'sips-stories', name: 'Sips & Stories', emoji: '🥂', description: 'Where rituals are born and people gather. Teas, coffees, broths, juices, and cocktails that connect us.' },
  { id: 'preserved-pantry', name: 'Preserved & Pantry', emoji: '🏺', description: 'Time honoured flavours held close. Pickles, chutneys, spice blends, and sauces that carry seasons in a jar.' }
];

var TCJ_CAT_EMOJI = {};
var TCJ_CATEGORY_NAMES = [];
TCJ_CATEGORY_COPY.forEach(function (c) {
  TCJ_CAT_EMOJI[c.name] = c.emoji;
  TCJ_CATEGORY_NAMES.push(c.name);
});

/** Legacy names — recipes until migration fully reviewed */
Object.assign(TCJ_CAT_EMOJI, {
  'Rise & Shine': '🌅',
  'The Evening Table': '☕',
  'Meat & Fire': '🍖',
  'Slow & Soulful': '🥘',
  'Grains & Comfort': '🌾',
  'Breads & Bakes': '🫓',
  'Preserved & Cherished': '🫙',
  'Little Ones': '👶',
  'Feast Days': '🎉',
  'Nourish & Heal': '💚'
});

var TCJ_CATEGORY_LEGACY_DB_NAMES = {
  'Feather & Flock': ['Meat & Fire'],
  'Pasture & Hoof': ['Slow & Soulful'],
  'The Grain Field': ['Grains & Comfort'],
  'Wrapped & Stuffed': ['The Evening Table'],
  'Curds, Creams & Eggs': ['Rise & Shine'],
  'Breads & Bakery': ['Breads & Bakes'],
  'Preserved & Pantry': ['Preserved & Cherished']
};

/** Match RPC/DB category column to canonical card name (e.g. Grains & Comfort ↔ The Grain Field). */
function taxonomyCategoryMatches(rowCategory, categoryName) {
  if (!rowCategory || !categoryName) return false;
  if (rowCategory === categoryName) return true;
  var legacy = TCJ_CATEGORY_LEGACY_DB_NAMES[categoryName] || [];
  for (var i = 0; i < legacy.length; i++) {
    if (rowCategory === legacy[i]) return true;
  }
  if (normalizeRecipeCategory(rowCategory) === categoryName) return true;
  if (normalizeRecipeCategory(categoryName) === rowCategory) return true;
  return false;
}

/** Recipe browse/admin dropdown — eleven A–K categories only */
function getRecipeCats() {
  return TCJ_CATEGORY_NAMES.slice();
}

/** Map legacy category string to A–K (or null) */
function normalizeRecipeCategory(cat) {
  if (!cat) return null;
  var c = String(cat).trim();
  if (TCJ_CATEGORY_NAMES.indexOf(c) >= 0) return c;
  var legacy = {
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
  return legacy[c] || null;
}

if (typeof window !== 'undefined') {
  window.getRecipeCats = getRecipeCats;
  window.normalizeRecipeCategory = normalizeRecipeCategory;
  window.taxonomyCategoryMatches = taxonomyCategoryMatches;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    TCJ_CATEGORY_COPY, TCJ_CAT_EMOJI, TCJ_CATEGORY_NAMES, TCJ_CATEGORY_LEGACY_DB_NAMES,
    getRecipeCats, normalizeRecipeCategory, taxonomyCategoryMatches
  };
}
