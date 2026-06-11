/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — theme-init.js
   Site auth gate + theme/font prefs. Include in <head> on every page.
   Set TCJ_SITE_PRIVATE = false below to reopen public browsing.
═══════════════════════════════════════════════════════════════ */
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
  } catch (_) {}
  if (loggedIn) return;

  var returnTo = path;
  if (window.location.search) returnTo += window.location.search;
  window.location.replace('login.html?return_to=' + encodeURIComponent(returnTo));
})();

(function () {
  try {
    // Only honour a saved theme for a signed-in user.
    var session = null;
    try { session = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
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
        } catch (_) {}
      }
    }

    if (!t || t === 'midnight-slate') return;

    function applyTheme() {
      if (document.body && !document.body.classList.contains('theme-' + t)) {
        document.body.classList.add('theme-' + t);
      }
    }
    if (document.body) applyTheme();
    else document.addEventListener('DOMContentLoaded', applyTheme);
  } catch (_) {}
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
  } catch (_) {}
})();
