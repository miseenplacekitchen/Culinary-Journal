// ══════════════════════════════════════════════════════════════════════
// supabase-config.js — The Culinary Journal
// Single source of truth for Supabase connection.
// Include this before any page script that calls Supabase.
// Usage: window.SUPA_URL, window.SUPA_KEY, window.supaFetch(), window.rpc()
// ══════════════════════════════════════════════════════════════════════

(function() {
  var URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';

  // Expose globally
  window.SUPA_URL      = URL;
  window.SUPA_KEY      = KEY;
  window.SUPABASE_URL  = URL;  // alias used by some pages
  window.SUPABASE_KEY  = KEY;  // alias used by some pages

  // ── Session helpers ──────────────────────────────────────────────────
  window.getSession = function() {
    try { return JSON.parse(localStorage.getItem('tcj_session') || 'null'); }
    catch(_) { return null; }
  };

  window.getAuthHeaders = function() {
    var sess = window.getSession();
    var h = { 'apikey': KEY, 'Content-Type': 'application/json' };
    if (sess && sess.access_token) h['Authorization'] = 'Bearer ' + sess.access_token;
    return h;
  };

  // ── REST fetch wrapper ───────────────────────────────────────────────
  window.supaFetch = function(path, options) {
    var opts = options || {};
    opts.headers = Object.assign({}, window.getAuthHeaders(), opts.headers || {});
    return fetch(URL + path, opts);
  };

  // ── RPC wrapper ──────────────────────────────────────────────────────
  window.rpc = async function(fnName, params) {
    var res = await fetch(URL + '/rest/v1/rpc/' + fnName, {
      method:  'POST',
      headers: window.getAuthHeaders(),
      body:    JSON.stringify(params || {})
    });
    if (!res.ok) {
      var err = await res.text().catch(function() { return String(res.status); });
      throw new Error(err);
    }
    var text = await res.text();
    return text ? JSON.parse(text) : null;
  };

  // ── Profile / avatar cache helpers ───────────────────────────────────
  window.purgeStaleProfileCache = function() {
    try {
      var s = window.getSession();
      var p = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
      if (!s || !s.user_id) {
        localStorage.removeItem('tcj_profile');
        return;
      }
      if (p && p.id && p.id !== s.user_id) {
        localStorage.removeItem('tcj_profile');
      }
    } catch (_) {
      try { localStorage.removeItem('tcj_profile'); } catch (e) {}
    }
  };

  window.avatarCacheKey = function(userId) {
    var uid = userId || (window.getSession() && window.getSession().user_id) || '';
    return 'tcj_avatar_v_' + uid;
  };

  window.bumpAvatarCache = function(userId) {
    var uid = userId || (window.getSession() && window.getSession().user_id) || '';
    if (uid) localStorage.setItem(window.avatarCacheKey(uid), String(Date.now()));
  };

  window.avatarBust = function(url, userId, serverStamp) {
    if (!url || url.indexOf('data:') === 0) return url;
    var sep = url.indexOf('?') >= 0 ? '&' : '?';
    var uid = userId || (window.getSession() && window.getSession().user_id) || '';
    var v = serverStamp
      ? String(new Date(serverStamp).getTime())
      : (localStorage.getItem(window.avatarCacheKey(uid)) || String(Date.now()));
    return url + sep + 'v=' + v;
  };

  window.enrichProfile = async function(profile, session) {
    profile = profile || {};
    session = session || window.getSession();
    if (!session || !session.access_token) return profile;
    if (profile.avatar_url) return profile;
    try {
      var uid = profile.id || session.user_id;
      if (!uid) return profile;
      var res = await fetch(
        URL + '/rest/v1/profiles?id=eq.' + encodeURIComponent(uid) + '&select=avatar_url,last_seen',
        { headers: { apikey: KEY, Authorization: 'Bearer ' + session.access_token } }
      );
      if (res.ok) {
        var rows = await res.json();
        if (rows[0]) {
          if (rows[0].avatar_url) profile.avatar_url = rows[0].avatar_url;
          if (rows[0].last_seen) profile.last_seen = rows[0].last_seen;
        }
      }
    } catch (_) {}
    return profile;
  };

  window.purgeStaleProfileCache();
})();
