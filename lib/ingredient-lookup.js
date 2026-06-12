/* Shared governed-ingredient index — replaces hardcoded limit=500 REST fetches */
(function (global) {
  var _cache = null;
  var _cacheAt = 0;
  var TTL = 5 * 60 * 1000;

  function norm(s) {
    return String(s || '').toLowerCase().trim();
  }

  function buildIndex(rows) {
    var byName = {};
    var byId = {};
    var allergenNames = {};
    (rows || []).forEach(function (r) {
      var id = r.id != null ? r.id : r.ID;
      var name = r.name || r['Ingredient Name'] || '';
      var n = norm(name);
      if (!n) return;
      var meta = {
        id: id,
        name: name,
        category: r.category || r.Category || '',
        unit: r.unit || r.Unit || '',
        allergen: r.allergen || r.Allergen || '',
        brand: r.brand || r['CJ Recommended Brand'] || ''
      };
      byName[n] = meta;
      if (id != null) byId[String(id)] = meta;
      if (meta.allergen && String(meta.allergen).trim()) allergenNames[n] = meta.allergen;
      var aka = r.aka || r['Also Known As'] || '';
      if (aka) {
        aka.split(/[,;|]/).forEach(function (a) {
          var ak = norm(a);
          if (ak && !byName[ak]) byName[ak] = meta;
        });
      }
    });
    return { byName: byName, byId: byId, allergenNames: allergenNames, rows: rows || [] };
  }

  async function fetchIndex(force) {
    if (!force && _cache && (Date.now() - _cacheAt) < TTL) return _cache;
    var url = (global.SUPABASE_URL || global.SUPA_URL || '') + '/rest/v1/rpc/get_ingredient_lookup_index';
    var key = global.SUPABASE_KEY || global.SUPA_KEY || '';
    if (!url || !key) return _cache || buildIndex([]);
    try {
      var res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: key },
        body: '{}'
      });
      if (!res.ok) return _cache || buildIndex([]);
      var rows = await res.json();
      _cache = buildIndex(Array.isArray(rows) ? rows : []);
      _cacheAt = Date.now();
      return _cache;
    } catch (_) {
      return _cache || buildIndex([]);
    }
  }

  function resolveByName(name, index) {
    index = index || _cache;
    if (!index) return null;
    return index.byName[norm(name)] || null;
  }

  function clearCache() {
    _cache = null;
    _cacheAt = 0;
  }

  global.TcjIngredientLookup = {
    fetchIndex: fetchIndex,
    buildIndex: buildIndex,
    resolveByName: resolveByName,
    clearCache: clearCache,
    norm: norm
  };
})(typeof window !== 'undefined' ? window : globalThis);
