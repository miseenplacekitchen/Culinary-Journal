/* Optional free-tier caps — off until enforce_free_limits=true in site_settings */
(function (global) {
  var cache = null;
  var cacheAt = 0;
  var TTL = 60000;

  async function loadSettings(apiFetch, baseUrl) {
    if (cache && Date.now() - cacheAt < TTL) return cache;
    if (typeof apiFetch !== 'function') return {};
    var res = await apiFetch(
      baseUrl + '/rest/v1/site_settings?select=key,value&key=in.(enforce_free_limits,free_max_recipes,free_max_photo_imports_month,free_max_tables)'
    );
    if (!res || !res.ok) return {};
    var rows = await res.json();
    var s = {};
    if (Array.isArray(rows)) rows.forEach(function (r) { s[r.key] = r.value; });
    cache = s;
    cacheAt = Date.now();
    return s;
  }

  async function countUserRecipes(apiFetch, baseUrl, userId) {
    if (!userId) return 0;
    var res = await apiFetch(
      baseUrl + '/rest/v1/submitted_recipes?user_id=eq.' + encodeURIComponent(userId) + '&select=id'
    );
    if (!res || !res.ok) return 0;
    var rows = await res.json();
    return Array.isArray(rows) ? rows.length : 0;
  }

  async function assertCanSubmitRecipe(apiFetch, baseUrl, userId) {
    var s = await loadSettings(apiFetch, baseUrl);
    if (s.enforce_free_limits !== 'true') return null;
    var max = parseInt(s.free_max_recipes, 10) || 10;
    var n = await countUserRecipes(apiFetch, baseUrl, userId);
    if (n >= max) {
      return 'Free plan limit: ' + max + ' recipes. You have ' + n + '. Upgrade or contact support.';
    }
    return null;
  }

  global.TcjPlanLimits = {
    loadSettings: loadSettings,
    assertCanSubmitRecipe: assertCanSubmitRecipe
  };
})(typeof window !== 'undefined' ? window : globalThis);
