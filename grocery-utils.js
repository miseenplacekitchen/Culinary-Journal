/* Shared grocery list helpers — GL-01 per-item model */
(function (global) {
  function makeItemId() {
    return 'gi_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 8);
  }

  function enrichIngredient(ing, meta) {
    meta = meta || {};
    var name = ing.name || ing.ingredient || '';
    return {
      id: ing.id || makeItemId(),
      name: name,
      qty: ing.qty != null ? ing.qty : '',
      unit: ing.unit || '',
      category: ing.category || meta.category || 'Other',
      section: ing.section || '',
      source: ing.source || meta.source || 'recipe',
      source_ref: ing.source_ref != null ? ing.source_ref : (meta.source_ref || ''),
      source_label: ing.source_label || meta.source_label || '',
      ingredient_id: ing.ingredient_id || null,
      store: ing.store || ''
    };
  }

  function normalizeGroceryList(raw) {
    if (!raw || typeof raw !== 'object') return { recipes: [], items: [], version: 2 };
    var out = { recipes: [], items: [], version: 2 };
    (raw.recipes || []).forEach(function (recipe) {
      var ings = (recipe.ingredients || []).map(function (ing) {
        return enrichIngredient(ing, {
          source: ing.source || recipe.source || 'recipe',
          source_ref: recipe.id,
          source_label: recipe.name || ''
        });
      });
      var copy = {};
      Object.keys(recipe).forEach(function (k) { copy[k] = recipe[k]; });
      copy.ingredients = ings;
      out.recipes.push(copy);
    });
    (raw.items || []).forEach(function (ing) {
      out.items.push(enrichIngredient(ing, {
        source: ing.source || 'manual',
        source_ref: ing.source_ref || '',
        source_label: ing.source_label || ''
      }));
    });
    return out;
  }

  function itemCheckKey(item, recipeId) {
    if (item && item.id) return 'item:' + item.id;
    if (recipeId && item && item.name) return recipeId + ':' + item.name;
    if (item && item.name) return 'combined:' + item.name.toLowerCase().trim();
    return '';
  }

  var SOURCE_LABELS = {
    recipe: 'Recipe',
    'meal-plan': 'Meal plan',
    manual: 'Manual',
    'pantry-low': 'Restock'
  };

  function sourceBadge(source) {
    var labels = {
      recipe: '📖',
      'meal-plan': '📅',
      manual: '✏️',
      'pantry-low': '🫙'
    };
    return (labels[source] || '') + ' ' + (SOURCE_LABELS[source] || source || '');
  }

  function loadGrocery() {
    try {
      return normalizeGroceryList(JSON.parse(localStorage.getItem('tcj_grocery') || '{}'));
    } catch (_) {
      return { recipes: [], items: [], version: 2 };
    }
  }

  function saveGrocery(data) {
    localStorage.setItem('tcj_grocery', JSON.stringify(normalizeGroceryList(data)));
  }

  global.GroceryUtils = {
    makeItemId: makeItemId,
    enrichIngredient: enrichIngredient,
    normalizeGroceryList: normalizeGroceryList,
    itemCheckKey: itemCheckKey,
    sourceBadge: sourceBadge,
    SOURCE_LABELS: SOURCE_LABELS,
    loadGrocery: loadGrocery,
    saveGrocery: saveGrocery
  };
})(typeof window !== 'undefined' ? window : globalThis);
