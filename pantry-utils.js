/* Shared pantry helpers — archive grocery → stock pantry (Master list grocery gap) */
(function (global) {
  function loadPantry() {
    try { return JSON.parse(localStorage.getItem('tcj_pantry') || '[]'); }
    catch (_) { return []; }
  }

  var _pantrySyncTimer = null;

  function schedulePantryCloudSync() {
    var g = typeof global !== 'undefined' ? global : (typeof window !== 'undefined' ? window : null);
    if (!g || typeof g.getSession !== 'function') return;
    clearTimeout(_pantrySyncTimer);
    _pantrySyncTimer = setTimeout(async function () {
      try {
        var sess = g.getSession();
        if (!sess || !sess.access_token) return;
        var url = g.SUPA_URL || g.SUPABASE_URL;
        var key = g.SUPA_KEY || g.SUPABASE_KEY;
        if (!url || !key) return;
        var list = loadPantry();
        await fetch(url + '/rest/v1/rpc/save_my_pantry', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': key,
            'Authorization': 'Bearer ' + sess.access_token
          },
          body: JSON.stringify({ p_pantry_data: list })
        });
        localStorage.setItem('tcj_pantry_ts', String(Date.now()));
      } catch (_) {}
    }, 1500);
  }

  function savePantry(list) {
    localStorage.setItem('tcj_pantry', JSON.stringify(list));
    localStorage.setItem('tcj_pantry_ts', String(Date.now()));
    schedulePantryCloudSync();
  }

  /** Add or bump qty for items archived from grocery trip */
  function stockFromGroceryArchive(items) {
    if (!items || !items.length) return 0;
    var pantry = loadPantry();
    var added = 0;
    items.forEach(function (ing) {
      var name = String(ing.name || '').trim();
      if (!name) return;
      var key = name.toLowerCase();
      var existing = pantry.find(function (p) {
        return String(p.name || '').toLowerCase().trim() === key;
      });
      if (existing) {
        var q = parseFloat(existing.qty);
        existing.qty = (isNaN(q) ? 0 : q) + 1;
        existing.updated = new Date().toISOString();
      } else {
        pantry.push({
          id: 'pt_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6),
          name: name,
          ingredient_id: ing.ingredient_id || null,
          qty: 1,
          unit: ing.unit || '',
          category: ing.category || '',
          min_qty: null,
          expiry_date: null,
          location: 'pantry',
          is_staple: false,
          updated: new Date().toISOString()
        });
        added++;
      }
    });
    savePantry(pantry);
    return added;
  }

  global.PantryUtils = {
    loadPantry: loadPantry,
    savePantry: savePantry,
    stockFromGroceryArchive: stockFromGroceryArchive,
    schedulePantryCloudSync: schedulePantryCloudSync
  };
})(typeof window !== 'undefined' ? window : globalThis);
