/* Regional ingredient intelligence — grocery & pantry banners */
(function (global) {
  var _cache = null;
  var _cacheTs = 0;

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function normalizeRegion(s) {
    return String(s || '').toLowerCase().trim();
  }

  function matchRegion(country, hints) {
    var c = normalizeRegion(country);
    if (!c) return null;
    return (hints || []).find(function (h) {
      var key = normalizeRegion(h.region_key);
      var name = normalizeRegion(h.region_name);
      return c === key || c.indexOf(key) >= 0 || key.indexOf(c) >= 0 ||
        name.indexOf(c) >= 0 || c.indexOf(name) >= 0;
    }) || null;
  }

  async function loadHints() {
    if (_cache && Date.now() - _cacheTs < 300000) return _cache;
    var url = global.SUPA_URL || global.SUPABASE_URL;
    var key = global.SUPA_KEY || global.SUPABASE_KEY;
    if (!url || !key) return [];
    try {
      var res = await fetch(url + '/rest/v1/rpc/get_regional_ingredient_hints', {
        method: 'POST',
        headers: { 'apikey': key, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_region: null })
      });
      _cache = res.ok ? await res.json() : [];
      if (!Array.isArray(_cache)) _cache = [];
      _cacheTs = Date.now();
    } catch (_) { TcjErr.warn('regional-hints.js:39', _); }
    return _cache;
  }

  function detectRegionFromList(items) {
    var counts = {};
    (items || []).forEach(function (it) {
      var c = (it.origin_country || it.country || '').trim();
      if (c) counts[c] = (counts[c] || 0) + 1;
    });
    var top = Object.keys(counts).sort(function (a, b) { return counts[b] - counts[a]; })[0];
    return top || '';
  }

  function renderBanner(hostId, region, hintRow) {
    var host = document.getElementById(hostId);
    if (!host) return;
    if (!hintRow) { host.style.display = 'none'; host.innerHTML = ''; return; }
    var hints = hintRow.hints || [];
    host.style.display = 'block';
    host.innerHTML =
      '<div style="padding:12px 16px;background:rgba(91,143,212,0.08);border:1px solid rgba(91,143,212,0.22);border-radius:12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid)">' +
      '<strong style="color:var(--text-high)">🌍 ' + esc(hintRow.region_name || region) + ' staples</strong> — ' +
      esc(hintRow.tip || 'Regional picks for your list') +
      (hints.length ? '<div style="margin-top:8px;display:flex;flex-wrap:wrap;gap:6px">' +
        hints.slice(0, 10).map(function (h) {
          return '<span style="padding:3px 8px;border-radius:6px;background:var(--text-ghost);border:1px solid var(--border);font-size:11px">' + esc(h) + '</span>';
        }).join('') + '</div>' : '') +
      '</div>';
  }

  async function refreshBanner(hostId, regionOrItems) {
    var hints = await loadHints();
    var region = typeof regionOrItems === 'string' ? regionOrItems : detectRegionFromList(regionOrItems);
    var row = matchRegion(region, hints);
    if (!row && hints.length) {
      row = hints.find(function (h) { return normalizeRegion(h.region_key) === 'australia'; });
    }
    renderBanner(hostId, region, row);
  }

  global.RegionalHints = {
    loadHints: loadHints,
    matchRegion: matchRegion,
    detectRegionFromList: detectRegionFromList,
    refreshBanner: refreshBanner
  };
})(typeof window !== 'undefined' ? window : globalThis);
