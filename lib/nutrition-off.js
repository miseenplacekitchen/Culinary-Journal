/* Open Food Facts nutrition lookup with localStorage cache + TTL */
(function (global) {
  var CACHE_KEY = 'tcj_off_cache_v2';
  var TTL_MS = 7 * 24 * 60 * 60 * 1000;
  var MAX_ENTRIES = 400;

  var UNIT_TO_G = {
    'g': 1, 'gram': 1, 'grams': 1,
    'kg': 1000, 'kilogram': 1000,
    'ml': 1, 'millilitre': 1, 'milliliter': 1,
    'l': 1000, 'litre': 1000, 'liter': 1000,
    'cup': 240, 'cups': 240,
    'tbsp': 15, 'tablespoon': 15, 'tablespoons': 15,
    'tsp': 5, 'teaspoon': 5, 'teaspoons': 5,
    'oz': 28, 'ounce': 28, 'ounces': 28,
    'lb': 454, 'pound': 454, 'pounds': 454,
    'piece': 100, 'pieces': 100, 'slice': 30, 'slices': 30,
    'handful': 30, 'pinch': 1, 'dash': 1
  };

  function lsGet(k) {
    try { return localStorage.getItem(k); } catch (_) { return null; }
  }
  function lsSet(k, v) {
    try { localStorage.setItem(k, v); } catch (_) {}
  }

  function loadCache() {
    try {
      var raw = JSON.parse(lsGet(CACHE_KEY) || '{}');
      return raw && typeof raw === 'object' ? raw : {};
    } catch (_) { return {}; }
  }

  var cache = loadCache();

  function trimCache() {
    var keys = Object.keys(cache);
    if (keys.length <= MAX_ENTRIES) return;
    keys.sort(function (a, b) {
      return (cache[a].at || 0) - (cache[b].at || 0);
    });
    keys.slice(0, keys.length - MAX_ENTRIES).forEach(function (k) { delete cache[k]; });
  }

  function persistCache() {
    trimCache();
    try { lsSet(CACHE_KEY, JSON.stringify(cache)); } catch (_) {}
  }

  function normKey(name) {
    return String(name || '').toLowerCase().trim();
  }

  function readCached(key) {
    var row = cache[key];
    if (!row) return undefined;
    if (row.at && (Date.now() - row.at) > TTL_MS) {
      delete cache[key];
      return undefined;
    }
    if (row.miss) return null;
    return row.data || null;
  }

  async function fetchNutrition(ingredientName) {
    var key = normKey(ingredientName);
    if (!key) return null;
    var cached = readCached(key);
    if (cached !== undefined) return cached;

    try {
      var q = encodeURIComponent(key.replace(/[()]/g, '').trim());
      var res = await fetch(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=' + q +
        '&json=1&page_size=1&fields=product_name,nutriments&search_simple=1&action=process',
        { signal: AbortSignal.timeout(4000) }
      );
      var data = await res.json();
      if (data.products && data.products.length && data.products[0].nutriments) {
        var n = data.products[0].nutriments;
        var result = {
          calories: n['energy-kcal_100g'] || n['energy_100g'] / 4.184 || 0,
          protein: n['proteins_100g'] || 0,
          carbs: n['carbohydrates_100g'] || 0,
          fat: n['fat_100g'] || 0,
          fibre: n['fiber_100g'] || n['fibre_100g'] || 0,
          sugar: n['sugars_100g'] || 0,
          sodium: (n['sodium_100g'] || 0) * 1000
        };
        cache[key] = { data: result, at: Date.now() };
        return result;
      }
    } catch (e) {
      console.warn('OFF nutrition lookup failed for', ingredientName, e);
    }
    cache[key] = { miss: true, at: Date.now() };
    return null;
  }

  function toGrams(qty, unit) {
    var q = parseFloat(qty) || 0;
    if (!q) return 0;
    var u = String(unit || '').toLowerCase().trim();
    var factor = UNIT_TO_G[u] || (u ? 0 : 100);
    return q * factor;
  }

  async function aggregateRecipeNutrition(ingredients, servings, onProgress) {
    var all = [];
    (ingredients || []).forEach(function (sec) {
      (sec.items || []).forEach(function (item) { all.push(item); });
    });
    var totals = { calories: 0, protein: 0, carbs: 0, fat: 0, fibre: 0, sugar: 0, sodium: 0 };
    var found = 0;
    var done = 0;
    var concurrency = 5;
    var next = 0;

    async function worker() {
      while (next < all.length) {
        var item = all[next++];
        var name = item.ingredient || item.name || '';
        var n = await fetchNutrition(name);
        done++;
        if (typeof onProgress === 'function') onProgress(done, all.length);
        if (!n) continue;
        var grams = toGrams(item.qty, item.unit);
        if (!grams) continue;
        var scale = grams / 100;
        Object.keys(totals).forEach(function (k) { totals[k] += (n[k] || 0) * scale; });
        found++;
      }
    }

    await Promise.all(Array.from({ length: Math.min(concurrency, all.length || 1) }, worker));
    persistCache();

    if (!found) return null;

    var perServing = servings || 1;
    var ps = {};
    Object.keys(totals).forEach(function (k) { ps[k] = Math.round(totals[k] / perServing); });

    return {
      calories: ps.calories,
      protein: ps.protein,
      carbs: ps.carbs,
      fat: ps.fat,
      fibre: ps.fibre,
      sugar: ps.sugar,
      sodium: ps.sodium,
      details: [
        { label: 'Total Recipe (all servings)', value: Math.round(totals.calories) + ' kcal' },
        { label: 'Based on', value: found + ' of ' + all.length + ' ingredients' },
        { label: 'Source', value: 'Open Food Facts (approximate)' }
      ]
    };
  }

  global.TcjNutritionOff = {
    fetchNutrition: fetchNutrition,
    toGrams: toGrams,
    aggregateRecipeNutrition: aggregateRecipeNutrition,
    persistCache: persistCache,
    clearCache: function () { cache = {}; try { localStorage.removeItem(CACHE_KEY); } catch (_) {} }
  };
})(typeof window !== 'undefined' ? window : globalThis);
