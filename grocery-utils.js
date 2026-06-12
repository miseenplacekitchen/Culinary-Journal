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

  var _grocerySyncTimer = null;

  function getGroceryChecked() {
    try { return JSON.parse(localStorage.getItem('tcj_grocery_checked') || '[]'); }
    catch (_) { return []; }
  }

  /** Debounced Supabase sync — works from recipe page, meal planner, pantry, grocery */
  function scheduleGroceryCloudSync() {
    var g = typeof global !== 'undefined' ? global : (typeof window !== 'undefined' ? window : null);
    if (!g || typeof g.getSession !== 'function') return;
    clearTimeout(_grocerySyncTimer);
    _grocerySyncTimer = setTimeout(async function() {
      try {
        var sess = g.getSession();
        if (!sess || !sess.access_token) return;
        var url = g.SUPA_URL || g.SUPABASE_URL;
        var key = g.SUPA_KEY || g.SUPABASE_KEY;
        if (!url || !key) return;
        var list = loadGrocery();
        var checked = getGroceryChecked();
        var serverTs = null;
        if (g.SharedSyncUtils) serverTs = g.SharedSyncUtils.getServerTs('tcj_grocery_server_ts');
        var res = await fetch(url + '/rest/v1/rpc/save_my_grocery_list', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': key,
            'Authorization': 'Bearer ' + sess.access_token
          },
          body: JSON.stringify({
            p_list_data: list,
            p_checked: checked,
            p_client_updated_at: serverTs
          })
        });
        var bodyText = await res.text();
        var parsed = g.SharedSyncUtils ? g.SharedSyncUtils.parseSaveResult(res, bodyText) : { ok: res.ok };
        if (parsed.conflict && g.SharedSyncUtils) {
          var choice = await g.SharedSyncUtils.showConflict({
            householdName: parsed.data && parsed.data.household_name
          });
          if (choice === 'theirs' && parsed.data) {
            var remote = g.normalizeGroceryList(parsed.data.list_data || {});
            localStorage.setItem('tcj_grocery', JSON.stringify(remote));
            localStorage.setItem('tcj_grocery_checked', JSON.stringify(parsed.data.checked || []));
            if (parsed.data.updated_at) g.SharedSyncUtils.storeServerTs('tcj_grocery_server_ts', parsed.data.updated_at);
            if (typeof g.onGroceryConflictResolved === 'function') g.onGroceryConflictResolved('theirs');
          } else if (choice === 'mine') {
            await fetch(url + '/rest/v1/rpc/save_my_grocery_list', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'apikey': key,
                'Authorization': 'Bearer ' + sess.access_token
              },
              body: JSON.stringify({ p_list_data: list, p_checked: checked, p_client_updated_at: null })
            });
          }
        } else if (parsed.ok) {
          localStorage.setItem('tcj_grocery_ts', String(Date.now()));
          if (parsed.updated_at && g.SharedSyncUtils) g.SharedSyncUtils.storeServerTs('tcj_grocery_server_ts', parsed.updated_at);
        }
      } catch (_) {}
    }, 1500);
  }

  function saveGrocery(data) {
    localStorage.setItem('tcj_grocery', JSON.stringify(normalizeGroceryList(data)));
    localStorage.setItem('tcj_grocery_ts', String(Date.now()));
    scheduleGroceryCloudSync();
  }

  /** Add manual lines (event planners, meal planner) — skips duplicate names */
  function addManualItems(names, meta) {
    meta = meta || {};
    var list = loadGrocery();
    var added = 0;
    (names || []).forEach(function (name) {
      name = String(name || '').trim();
      if (!name) return;
      var key = name.toLowerCase();
      var dup = list.items.some(function (i) { return (i.name || '').toLowerCase().trim() === key; });
      if (dup) return;
      list.items.push(enrichIngredient({ name: name, qty: '', unit: '' }, {
        source: meta.source || 'manual',
        source_ref: meta.source_ref || '',
        source_label: meta.source_label || 'Manual add'
      }));
      added++;
    });
    if (added) saveGrocery(list);
    return added;
  }

  var UNICODE_FRACTIONS = {'½':0.5,'⅓':1/3,'⅔':2/3,'¼':0.25,'¾':0.75,'⅛':0.125,'⅜':0.375,'⅝':0.625,'⅞':0.875};

  function parseFraction(v) {
    if (v == null || v === '') return 0;
    v = String(v).trim();
    if (UNICODE_FRACTIONS[v] !== undefined) return UNICODE_FRACTIONS[v];
    for (var uf in UNICODE_FRACTIONS) {
      if (v.endsWith(uf)) return parseFloat(v.slice(0, -uf.length) || 0) + UNICODE_FRACTIONS[uf];
    }
    var slash = v.match(/^(\d+)\s+(\d+)\/(\d+)$|^(\d+)\/(\d+)$/);
    if (slash) {
      if (slash[1]) return parseInt(slash[1], 10) + parseInt(slash[2], 10) / parseInt(slash[3], 10);
      return parseInt(slash[4], 10) / parseInt(slash[5], 10);
    }
    return parseFloat(v) || 0;
  }

  var DB_CATEGORY_MAP = {
    vegetables: 'Produce', fruits: 'Produce', herbs: 'Produce',
    meat: 'Meat & Seafood', poultry: 'Meat & Seafood', seafood: 'Meat & Seafood',
    'dairy & eggs': 'Dairy & Eggs', baking: 'Pantry', spices: 'Spices & Herbs',
    'oils & fats': 'Oils & Sauces', 'condiments & sauces': 'Oils & Sauces',
    'canned & preserved': 'Canned & Preserved', 'grains, pasta & noodles': 'Pantry',
    'breads & flatbreads': 'Bakery', legumes: 'Pantry', 'nuts & seeds': 'Pantry'
  };

  function mapDbCategory(dbCat) {
    if (!dbCat) return 'Other';
    var key = String(dbCat).toLowerCase().trim();
    return DB_CATEGORY_MAP[key] || dbCat;
  }

  /** GL-05: combine by name; sum qty only when unit matches */
  function buildCombinedLines(rawEntries) {
    var byName = {};
    rawEntries.forEach(function(e) {
      var key = (e.name || '').toLowerCase().trim();
      if (!key) return;
      if (!byName[key]) {
        byName[key] = { name: e.name, category: e.category || 'Other', unitGroups: {}, sources: [] };
      }
      var ukey = (e.unit || '').toLowerCase().trim() || '__none__';
      if (!byName[key].unitGroups[ukey]) {
        byName[key].unitGroups[ukey] = { unit: e.unit || '', total: 0, sources: [] };
      }
      byName[key].unitGroups[ukey].total = Math.round((byName[key].unitGroups[ukey].total + parseFraction(e.qty)) * 10000) / 10000;
      var src = e.source_label || e.recipe || e.source || '';
      if (src && byName[key].unitGroups[ukey].sources.indexOf(src) < 0) {
        byName[key].unitGroups[ukey].sources.push(src);
      }
      if (e.category && e.category !== 'Other') byName[key].category = e.category;
    });
    return Object.values(byName);
  }

  /** Immediate cloud sync (Lane 2 — sign-out / tab close persistence) */
  function flushGroceryCloudSync() {
    clearTimeout(_grocerySyncTimer);
    _grocerySyncTimer = null;
    var g = typeof global !== 'undefined' ? global : (typeof window !== 'undefined' ? window : null);
    if (!g || typeof g.getSession !== 'function') return Promise.resolve();
    return (async function() {
      try {
        var sess = g.getSession();
        if (!sess || !sess.access_token) return;
        var url = g.SUPA_URL || g.SUPABASE_URL;
        var key = g.SUPA_KEY || g.SUPABASE_KEY;
        if (!url || !key) return;
        var list = loadGrocery();
        var checked = getGroceryChecked();
        var serverTs = g.SharedSyncUtils ? g.SharedSyncUtils.getServerTs('tcj_grocery_server_ts') : null;
        await fetch(url + '/rest/v1/rpc/save_my_grocery_list', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'apikey': key, 'Authorization': 'Bearer ' + sess.access_token },
          body: JSON.stringify({ p_list_data: list, p_checked: checked, p_client_updated_at: serverTs })
        });
      } catch (_) {}
    })();
  }

  global.GroceryUtils = {
    makeItemId: makeItemId,
    enrichIngredient: enrichIngredient,
    normalizeGroceryList: normalizeGroceryList,
    itemCheckKey: itemCheckKey,
    sourceBadge: sourceBadge,
    SOURCE_LABELS: SOURCE_LABELS,
    loadGrocery: loadGrocery,
    saveGrocery: saveGrocery,
    addManualItems: addManualItems,
    getGroceryChecked: getGroceryChecked,
    scheduleGroceryCloudSync: scheduleGroceryCloudSync,
    flushGroceryCloudSync: flushGroceryCloudSync,
    parseFraction: parseFraction,
    mapDbCategory: mapDbCategory,
    buildCombinedLines: buildCombinedLines
  };
})(typeof window !== 'undefined' ? window : globalThis);
