/**
 * page-guard.js — The Culinary Journal
 * Include in the <head> of every public page (not login.html, not dashboard.html).
 * Checks site_pages visibility and redirects accordingly.
 */
(function() {
  var SUPA_URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';

  // Get the current page filename
  var raw  = window.location.pathname;
  var path = raw.split('/').pop() || 'index.html';
  if (path === '' || raw === '/') path = 'index.html';

  // Is the visitor logged in?
  var isLoggedIn = false;
  try {
    var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
    isLoggedIn = !!(sess && sess.access_token);
  } catch(e) {}

  fetch(SUPA_URL + '/rest/v1/site_pages?path=eq.' + encodeURIComponent(path) + '&select=visibility,coming_soon', {
    headers: { 'apikey': SUPA_KEY, 'Accept': 'application/json' }
  })
  .then(function(r) { return r.ok ? r.json() : null; })
  .then(function(rows) {
    if (!Array.isArray(rows) || !rows.length) return; // Page not in table = no restriction

    var page = rows[0];

    // Coming soon takes priority
    if (page.coming_soon) {
      window.location.replace('coming-soon.html?from=' + encodeURIComponent(path));
      return;
    }

    // Hidden = not publicly accessible
    if (page.visibility === 'hidden') {
      window.location.replace('404.html');
      return;
    }

    // Members only = must be logged in
    if (page.visibility === 'members' && !isLoggedIn) {
      window.location.replace('login.html?next=' + encodeURIComponent(path));
      return;
    }
  })
  .catch(function() {}); // Fail silently — never break the page for a guard error
})();
