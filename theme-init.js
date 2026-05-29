/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — theme-init.js
   Applies the user's saved theme BEFORE the page renders.
   Include in <head> on every page.
═══════════════════════════════════════════════════════════════ */
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
