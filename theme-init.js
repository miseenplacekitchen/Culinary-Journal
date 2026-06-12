/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — theme-init.js
   Site auth gate + theme/font prefs. Include in <head> on every page.
   Set TCJ_SITE_PRIVATE = false below to reopen public browsing.
═══════════════════════════════════════════════════════════════ */
if (typeof window.TcjErr === 'undefined') {
  window.TcjErr = {
    warn: function (c, e) { console.warn('[TCJ:' + c + ']', e); },
    ignore: function () {},
    rpcFallback: function (c, e, f) { console.warn('[TCJ:' + c + ']', e); return f; },
    lsGet: function (k) { try { return localStorage.getItem(k); } catch (x) { return null; } },
    lsSet: function (k, v) { try { localStorage.setItem(k, v); return true; } catch (x) { return false; } },
    lsRemove: function (k) { try { localStorage.removeItem(k); return true; } catch (x) { return false; } },
    parseJson: function (r, f) { try { return JSON.parse(r); } catch (x) { return f; } },
    toast: function (m) { console.warn('[TCJ:toast]', m); },
    bannerOnce: function (id, m) { console.warn('[TCJ:' + id + ']', m); },
    sectionError: function (id, m) { console.warn('[TCJ:' + id + ']', m); }
  };
}

(function () {
  if (window.__tcjAuthGateRan) return;
  window.__tcjAuthGateRan = true;
  window.TCJ_SITE_PRIVATE = true;
  if (!window.TCJ_SITE_PRIVATE) return;

  var raw = window.location.pathname || '';
  var path = raw.split('/').pop() || '';
  if (!path || path === '/' || raw === '/') path = 'index.html';
  if (window.location.hash && window.location.hash.indexOf('access_token=') !== -1) return;

  var PUBLIC = {
    'login.html': true,
    'reset-password.html': true,
    'email-confirm.html': true,
    'email-reset.html': true,
    '404.html': true
  };
  if (PUBLIC[path]) return;

  var loggedIn = false;
  try {
    var s = JSON.parse(localStorage.getItem('tcj_session') || 'null');
    loggedIn = !!(s && s.access_token);
  } catch (_) { TcjErr.warn('degrade', _); }
  if (loggedIn) return;

  var returnTo = path;
  if (window.location.search) returnTo += window.location.search;
  window.location.replace('login.html?return_to=' + encodeURIComponent(returnTo));
})();

(function () {
  function applyBodyTheme(key) {
    if (!key || key === 'midnight-slate') return;
    function applyTheme() {
      if (document.body && !document.body.classList.contains('theme-' + key)) {
        document.body.classList.add('theme-' + key);
      }
    }
    if (document.body) applyTheme();
    else document.addEventListener('DOMContentLoaded', applyTheme);
  }

  function normalizeThemeKey(v) {
    if (!v) return '';
    if (typeof window.TCJ_nameOrKeyToThemeKey === 'function') return window.TCJ_nameOrKeyToThemeKey(v);
    if (String(v).indexOf('-') >= 0) return String(v);
    return String(v).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  }

  function resolveEffectiveThemeKey(settings) {
    if (!settings || typeof settings !== 'object') return 'midnight-slate';
    var catalog = settings.theme_catalog;
    if (typeof catalog === 'string') {
      try { catalog = JSON.parse(catalog); } catch (_) { TcjErr.warn('theme-init.js:61', _); }
    }
    var def = normalizeThemeKey(settings.default_theme || (catalog && catalog.default_theme) || 'midnight-slate');
    var seasonal = normalizeThemeKey(settings.seasonal_default_theme || (catalog && catalog.seasonal_default) || '');
    return seasonal || def || 'midnight-slate';
  }

  function fetchPublicSiteTheme(cb) {
    var url = window.SUPA_URL || window.SUPABASE_URL;
    var key = window.SUPA_KEY || window.SUPABASE_KEY;
    if (!url || !key) return cb(null);
    fetch(url + '/rest/v1/rpc/get_public_theme_default', {
      method: 'POST',
      headers: { 'apikey': key, 'Content-Type': 'application/json' },
      body: '{}'
    })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) { cb(resolveEffectiveThemeKey(data)); })
      .catch(function(e){ TcjErr.warn('theme-init.js', e); });
  }

  try {
    var session = null;
    try { session = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch(_) { TcjErr.ignore(_); }
    var loggedIn = !!(session && session.access_token);

    var t = null;
    if (loggedIn) {
      t = localStorage.getItem('tcj_theme');
      if (!t) {
        try {
          var prof = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
          if (prof && prof.theme_preference) {
            t = prof.theme_preference;
            localStorage.setItem('tcj_theme', t);
          }
        } catch (_) { TcjErr.warn('degrade', _); }
      }
      if (t) applyBodyTheme(t);
      return;
    }

    function bootAnonTheme() {
      fetchPublicSiteTheme(function (siteKey) {
        if (siteKey) applyBodyTheme(siteKey);
      });
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', bootAnonTheme);
    } else {
      bootAnonTheme();
    }
  } catch(_) { TcjErr.warn('theme-init.js', _); }
})();

// ── FONT SIZE ─────────────────────────────────────────────────────
// FIX: always defer to DOMContentLoaded — body may not exist yet
// when this script runs inside <head>.
(function () {
  try {
    var fs = localStorage.getItem('tcj_fontsize');
    if (!fs || fs === 'medium') return;
    function applyFontSize() {
      if (document.body) document.body.classList.add('fs-' + fs);
    }
    if (document.body) applyFontSize();
    else document.addEventListener('DOMContentLoaded', applyFontSize);
  } catch(_) { TcjErr.warn('theme-init.js', _); }
})();
