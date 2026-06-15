// Shared admin inbox / badge counts — one RPC when live, parallel fallbacks otherwise.
(function (global) {
  'use strict';

  var _cache = null;
  var _cacheAt = 0;
  var CACHE_MS = 30000;

  function restCount(table, filterQuery) {
    if (global.AdminTabNav && AdminTabNav.restCount) {
      return AdminTabNav.restCount(table, filterQuery);
    }
    if (typeof apiFetch === 'undefined' || typeof SUPABASE_URL === 'undefined') {
      return Promise.resolve(0);
    }
    var q = table + '?select=id';
    if (filterQuery) q += '&' + filterQuery;
    return apiFetch(SUPABASE_URL + '/rest/v1/' + q, {
      headers: { Prefer: 'count=exact', Range: '0-0' }
    }).then(function (res) {
      if (!res || !res.ok) return 0;
      var range = res.headers.get('Content-Range') || res.headers.get('content-range') || '';
      var slash = range.lastIndexOf('/');
      if (slash < 0) return 0;
      return parseInt(range.slice(slash + 1), 10) || 0;
    }).catch(function () { return 0; });
  }

  function normalize(raw) {
    if (!raw || typeof raw !== 'object') return null;
    return {
      pending_recipes: parseInt(raw.pending_recipes, 10) || 0,
      pending_users: parseInt(raw.pending_users, 10) || 0,
      new_feedback: parseInt(raw.new_feedback, 10) || 0,
      feedback_actionable: parseInt(raw.feedback_actionable, 10) || 0,
      feedback_action_required: parseInt(raw.feedback_action_required, 10) || 0,
      appeals_pending: parseInt(raw.appeals_pending, 10) || 0,
      reports_pending: parseInt(raw.reports_pending, 10) || 0,
      print_orders_pending: parseInt(raw.print_orders_pending, 10) || 0,
      pending_notes: parseInt(raw.pending_notes, 10) || 0,
      pending_ingredients: parseInt(raw.pending_ingredients, 10) || 0,
      library_submissions_pending: parseInt(raw.library_submissions_pending, 10) || 0
    };
  }

  async function fetchFallback() {
    var res = await Promise.all([
      rpc('admin_get_stats', {}).catch(function () { return {}; }),
      rpc('admin_count_pending_users', {}).catch(function () { return 0; }),
      restCount('user_feedback', 'status=eq.new'),
      restCount('user_feedback', 'voc_category=eq.actionable'),
      restCount('user_feedback', 'action_required=eq.true'),
      restCount('appeals', 'status=eq.pending'),
      restCount('user_reports', 'status=eq.pending'),
      rpc('admin_count_print_orders', { p_status: 'pending' }).catch(function () { return 0; }),
      restCount('recipe_public_notes', 'status=eq.pending'),
      restCount('pending_ingredients', 'status=eq.pending'),
      restCount('library_profile_submissions', 'status=eq.pending')
    ]);
    return normalize({
      pending_recipes: (res[0] && res[0].pending) || 0,
      pending_users: res[1] || 0,
      new_feedback: res[2] || 0,
      feedback_actionable: res[3] || 0,
      feedback_action_required: res[4] || 0,
      appeals_pending: res[5] || 0,
      reports_pending: res[6] || 0,
      print_orders_pending: res[7] || 0,
      pending_notes: res[8] || 0,
      pending_ingredients: res[9] || 0,
      library_submissions_pending: res[10] || 0
    });
  }

  async function fetchInboxCounts(force) {
    if (!force && _cache && (Date.now() - _cacheAt) < CACHE_MS) {
      return _cache;
    }
    try {
      var rpcCounts = await rpc('admin_get_inbox_counts', {});
      var normalized = normalize(rpcCounts);
      if (normalized) {
        _cache = normalized;
        _cacheAt = Date.now();
        return _cache;
      }
    } catch (e) { /* RPC not deployed yet — fall back */ }
    _cache = await fetchFallback();
    _cacheAt = Date.now();
    return _cache;
  }

  function invalidate() {
    _cache = null;
    _cacheAt = 0;
  }

  global.TcjAdminCounts = {
    CACHE_MS: CACHE_MS,
    restCount: restCount,
    fetchInboxCounts: fetchInboxCounts,
    invalidate: invalidate
  };
})(typeof window !== 'undefined' ? window : this);
