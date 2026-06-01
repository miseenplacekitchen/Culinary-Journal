/**
 * page-guard.js — The Culinary Journal
 * Include in the <head> of every public page (not login.html, not dashboard.html).
 *
 * Visibility rules:
 *   hidden  → redirect to homepage silently. No explanation. Page doesn't exist to the public.
 *   members → redirect to members-only.html with sign-in prompt.
 *   public  → no action.
 *
 * coming_soon → redirect to coming-soon.html regardless of visibility.
 */
(function() {
  var SUPA_URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';

  // Resolve the current page filename
  var raw  = window.location.pathname;
  var path = raw.split('/').pop() || 'index.html';
  if (!path || raw === '/') path = 'index.html';

  // Don't guard the guard targets themselves
  var guardExempt = ['index.html', 'login.html', 'coming-soon.html', 'members-only.html', '404.html', 'reset-password.html', 'dashboard.html'];
  if (guardExempt.indexOf(path) !== -1) return;

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
    if (!Array.isArray(rows) || !rows.length) return; // Not in table = no restriction

    var page = rows[0];

    // Coming soon takes priority over visibility
    if (page.coming_soon) {
      window.location.replace('coming-soon.html?from=' + encodeURIComponent(path));
      return;
    }

    // Hidden = silently redirect to homepage. No explanation — page doesn't exist to them.
    if (page.visibility === 'hidden') {
      window.location.replace('index.html');
      return;
    }

    // Members only = inform the visitor and give them a path to sign up / sign in
    if (page.visibility === 'members' && !isLoggedIn) {
      window.location.replace('members-only.html?next=' + encodeURIComponent(path));
      return;
    }
  })
  .catch(function() {}); // Never break a page over a guard error
})();
