/**
 * Recipe taxonomy helpers — no hardcoded category/sub lists.
 * Browse and admin load taxonomy from Supabase (categories table + get_recipe_taxonomy RPC).
 */
function getCanonicalCategoryTaxonomy(categoryName) {
  return null;
}

function getCategorySubMeta(categoryName, subName) {
  return null;
}

function browseSubPillLabel(subName, categoryName) {
  return subName || '';
}

function categoryIngredientDisplay(categoryName, subOrName) {
  return '';
}

function parseIngredientHintText(text) {
  return String(text || '').split(/[,;\n]+/).map(function (s) { return s.trim(); }).filter(Boolean);
}

function formatIngredientHints(hints) {
  if (!hints || !hints.length) return '';
  return hints.join(', ');
}

function inferCategorySubFromBlob(categoryName, blob) {
  return { sub: '', div: '' };
}

if (typeof window !== 'undefined') {
  window.getCanonicalCategoryTaxonomy = getCanonicalCategoryTaxonomy;
  window.getCategorySubMeta = getCategorySubMeta;
  window.browseSubPillLabel = browseSubPillLabel;
  window.categoryIngredientDisplay = categoryIngredientDisplay;
  window.parseIngredientHintText = parseIngredientHintText;
  window.formatIngredientHints = formatIngredientHints;
  window.inferCategorySubFromBlob = inferCategorySubFromBlob;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    getCanonicalCategoryTaxonomy, getCategorySubMeta,
    browseSubPillLabel, categoryIngredientDisplay, parseIngredientHintText,
    formatIngredientHints, inferCategorySubFromBlob
  };
}
