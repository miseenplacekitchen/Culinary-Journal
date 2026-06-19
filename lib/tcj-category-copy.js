/**
 * Recipe categories — loaded from Supabase `categories` table only (no hardcoded lists).
 * Active rows only (is_active = true), matching browse + admin taxonomy.
 */
var _tcjCategoriesCache = [];
var _tcjCatEmoji = {};
var _tcjCategoriesPromise = null;

function tcjCategoryRowIsActive(row) {
  return row && row.name && row.is_active !== false;
}

async function tcjFetchCategoryRowsFromApi(activeOnly) {
  var select = 'id,name,emoji,description,sort_order,is_active';
  var url = window.SUPA_URL + '/rest/v1/categories?select=' + select + '&order=sort_order';
  if (activeOnly) url += '&is_active=eq.true';
  var res = await fetch(url, {
    headers: { apikey: window.SUPA_KEY, Accept: 'application/json' }
  });
  if (!res.ok) throw new Error('categories ' + res.status);
  var rows = await res.json();
  return (rows || []).filter(function(r) {
    return activeOnly ? tcjCategoryRowIsActive(r) : (r && r.name && r.is_active !== false);
  });
}

function tcjFetchCategories() {
  if (_tcjCategoriesPromise) return _tcjCategoriesPromise;
  _tcjCategoriesPromise = (async function() {
    if (typeof window === 'undefined' || !window.SUPA_URL || !window.SUPA_KEY) return [];
    var rows = [];
    try {
      rows = await tcjFetchCategoryRowsFromApi(true);
    } catch (e) {
      console.warn('[TCJ] active categories filter failed — loading all DB categories', e.message || e);
      rows = await tcjFetchCategoryRowsFromApi(false);
    }
    _tcjCategoriesCache = rows;
    _tcjCatEmoji = {};
    _tcjCategoriesCache.forEach(function(c) {
      _tcjCatEmoji[c.name] = c.emoji || '🍽';
    });
    if (typeof window !== 'undefined') window.TCJ_CAT_EMOJI = _tcjCatEmoji;
    return _tcjCategoriesCache;
  })().catch(function(err) {
    console.warn('[TCJ] categories fetch error', err);
    _tcjCategoriesPromise = null;
    return [];
  });
  return _tcjCategoriesPromise;
}

function getRecipeCats() {
  return _tcjCategoriesCache.map(function(c) { return c.name; });
}

function taxonomyCategoryMatches(rowCategory, categoryName) {
  if (!rowCategory || !categoryName) return false;
  return String(rowCategory).trim() === String(categoryName).trim();
}

function normalizeRecipeCategory(cat) {
  if (!cat) return null;
  return String(cat).trim();
}

var TCJ_CAT_EMOJI = _tcjCatEmoji;
var TCJ_CATEGORY_NAMES = [];
var TCJ_CATEGORY_COPY = [];
var TCJ_CATEGORY_LEGACY_DB_NAMES = {};

if (typeof window !== 'undefined') {
  window.tcjFetchCategories = tcjFetchCategories;
  window.getRecipeCats = getRecipeCats;
  window.normalizeRecipeCategory = normalizeRecipeCategory;
  window.taxonomyCategoryMatches = taxonomyCategoryMatches;
  window.TCJ_CAT_EMOJI = TCJ_CAT_EMOJI;
  if (window.SUPA_URL) tcjFetchCategories();
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    tcjFetchCategories, getRecipeCats, normalizeRecipeCategory, taxonomyCategoryMatches,
    TCJ_CATEGORY_COPY, TCJ_CAT_EMOJI, TCJ_CATEGORY_NAMES, TCJ_CATEGORY_LEGACY_DB_NAMES
  };
}
