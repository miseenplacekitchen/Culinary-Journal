/**
 * Recipe categories — loaded from Supabase `categories` table only (no hardcoded lists).
 */
var _tcjCategoriesCache = [];
var _tcjCatEmoji = {};
var _tcjCategoriesPromise = null;

function tcjFetchCategories() {
  if (_tcjCategoriesPromise) return _tcjCategoriesPromise;
  _tcjCategoriesPromise = (async function() {
    if (typeof window === 'undefined' || !window.SUPA_URL || !window.SUPA_KEY) return [];
    var url = window.SUPA_URL + '/rest/v1/categories?select=id,name,emoji,description,sort_order&order=sort_order';
    var res = await fetch(url, {
      headers: { apikey: window.SUPA_KEY, Accept: 'application/json' }
    });
    if (!res.ok) {
      console.warn('[TCJ] categories fetch failed', res.status);
      return [];
    }
    var rows = await res.json();
    _tcjCategoriesCache = (rows || []).filter(function(r) { return r && r.name; });
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
