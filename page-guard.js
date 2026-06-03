/**
 * page-guard.js — The Culinary Journal
 * Include in <head> of every public page.
 * Never include in: login.html, dashboard.html, coming-soon.html,
 *                   members-only.html, paid-members-only.html, 404.html
 *
 * Visibility levels:
 *   public     → everyone
 *   registered → any logged-in user (free or paid)
 *   paid       → paid subscribers only — ALL others (including free members
 *                and the public) are sent to paid-members-only.html
 *   hidden     → silently redirect to homepage — page doesn't exist to anyone
 *
 * Admins (is_admin = true) bypass all restrictions and see everything.
 * coming_soon → redirect to coming-soon.html regardless of visibility
 */
(function() {
  var SUPA_URL = window.SUPA_URL || 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = window.SUPA_KEY || '';

  // Resolve current page filename
  var raw  = window.location.pathname;
  var path = raw.split('/').pop() || 'index.html';
  if (!path || raw === '/') path = 'index.html';

  // Pages exempt from the guard (always accessible)
  var exempt = ['index.html','login.html','coming-soon.html','members-only.html',
                'paid-members-only.html','404.html','reset-password.html','dashboard.html'];
  if (exempt.indexOf(path) !== -1) return;

  // Read session and profile from localStorage
  var accessToken = null;
  var isAdmin     = false;
  var isPaid      = false;
  var isLoggedIn  = false;

  try {
    var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
    if (sess && sess.access_token) {
      accessToken = sess.access_token;
      isLoggedIn  = true;
    }
    var prof = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
    if (prof) {
      isAdmin = !!prof.is_admin;
      isPaid  = prof.subscription_tier === 'premium' || prof.subscription_tier === 'event';
    }
  } catch(e) {}

  // Admins bypass every restriction — they always see everything
  if (isAdmin) return;

  fetch(SUPA_URL + '/rest/v1/site_pages?path=eq.' + encodeURIComponent(path) +
        '&select=visibility,coming_soon', {
    headers: { 'apikey': SUPA_KEY, 'Accept': 'application/json' }
  })
  .then(function(r) { return r.ok ? r.json() : null; })
  .then(function(rows) {
    if (!Array.isArray(rows) || !rows.length) return; // Not in table = no restriction

    var page = rows[0];

    // Coming soon takes priority over all visibility settings
    if (page.coming_soon) {
      window.location.replace('coming-soon.html?from=' + encodeURIComponent(path));
      return;
    }

    switch (page.visibility) {

      case 'hidden':
        // No explanation — silently redirect to homepage.
        // The page does not exist to the public.
        window.location.replace('index.html');
        break;

      case 'registered':
        // Requires login. Free and paid members can both access this.
        if (!isLoggedIn) {
          window.location.replace('members-only.html?next=' + encodeURIComponent(path));
        }
        break;

      case 'paid':
        // Paid subscribers only.
        // Everyone who is not on a paid tier — whether logged in or not —
        // sees the paid-members-only page with pricing information.
        if (!isPaid) {
          window.location.replace('paid-members-only.html?next=' + encodeURIComponent(path));
        }
        break;

      default:
        // public — no action needed
        break;
    }
  })
  .catch(function() {}); // Never break a page for a guard error
})();
