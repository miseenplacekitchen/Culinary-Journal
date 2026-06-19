/**
 * Recipe taxonomy helpers — no hardcoded category/sub lists.
 * Browse and admin load taxonomy from Supabase (categories table + get_recipe_taxonomy RPC).
 */

function parseIngredientHintText(text) {
  return String(text || '').split(/[,;\n]+/).map(function (s) { return s.trim(); }).filter(Boolean);
}

function formatIngredientHints(hints) {
  if (!hints || !hints.length) return '';
  return hints.join(', ');
}

if (typeof window !== 'undefined') {
  window.parseIngredientHintText = parseIngredientHintText;
  window.formatIngredientHints = formatIngredientHints;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    parseIngredientHintText,
    formatIngredientHints
  };
}
