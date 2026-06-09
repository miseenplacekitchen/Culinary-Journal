/**
 * Shared submit/import validation helpers (Node + browser).
 */
(function (root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.RecipeImportValidate = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function () {

  function ingredientBlob(names) {
    return (names || []).join(' ').toLowerCase();
  }

  function dietaryContradictions(ingredientNames, dietaryTags) {
    var tags = dietaryTags || [];
    var blob = ingredientBlob(ingredientNames);
    var issues = [];
    if (tags.indexOf('tag-gf') >= 0 || tags.indexOf('Gluten Free') >= 0) {
      if (/\b(wheat|atta|all purpose flour|all-purpose flour|maida|bread flour|semolina|barley|rye|whole wheat|gothambu)\b/.test(blob)) {
        issues.push('Gluten Free tag contradicts wheat/flour ingredients');
      }
    }
    if (tags.indexOf('tag-vegan') >= 0 || tags.indexOf('Vegan') >= 0) {
      if (/\b(chicken|mutton|lamb|beef|pork|bacon|sausage|ham|meat|fish|prawn|shrimp|crab|lobster|salmon|tuna|anchovy|egg|honey|ghee|butter|milk|cheese|paneer|yoghurt|yogurt|curd)\b/.test(blob)) {
        issues.push('Vegan tag contradicts animal/dairy ingredients');
      }
    }
    return issues;
  }

  function categoryContradictsTitle(category, title) {
    var t = String(title || '').toLowerCase();
    var c = String(category || '');
    if (!t || !c) return null;
    if (c === 'Ocean & River' && /\b(puttu|idli|idiyappam|dosa|appam|roti|rotti|chapati|paratha|naan|bread|wheat|atta)\b/.test(t)) {
      return 'Ocean & River category contradicts grain/bread title';
    }
    return null;
  }

  return {
    dietaryContradictions: dietaryContradictions,
    categoryContradictsTitle: categoryContradictsTitle
  };
});
