/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — theme-init.js
   Applies the user's saved theme — but ONLY when they are signed in.

   Why the sign-in check:
   A theme is a personal preference. When you're signed OUT (login,
   sign-up, password reset, or just browsing logged out), the site
   reverts to the default "Midnight Slate" theme, which is the dark,
   always-readable baseline. This guarantees pages like the login
   screen are never washed-out by a light theme a user picked earlier.

   Include on every page (in <head>, before the body renders):
     <script src="theme-init.js"><\/script>
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
      // Fallback: read from stored profile if tcj_theme not set yet
      if (!t) {
        try {
          var prof = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
          if (prof && prof.theme_preference) {
            t = prof.theme_preference;
            localStorage.setItem('tcj_theme', t); // cache it for next time
          }
        } catch (_) {}
      }
    }

    // No session, no saved theme, or the default → leave the page on the
    // default theme (style.css :root) and stop.
    if (!t || t === 'midnight-slate') return;

    function apply() {
      if (document.body && !document.body.classList.contains('theme-' + t)) {
        document.body.classList.add('theme-' + t);
      }
    }
    if (document.body) apply();
    else document.addEventListener('DOMContentLoaded', apply);
  } catch (_) {}
})();
