/**
 * page-guard.js — The Culinary Journal
 * Include in the <head> of every public page.
 * Never include in: login.html, dashboard.html, coming-soon.html,
 *                   members-only.html, paid-members-only.html, 404.html
 *
 * Visibility levels:
 *   public     → everyone
 *   registered → any logged-in user (free or paid)
 *   paid       → paid subscribers only (subscription_tier = premium or event)
 *   hidden     → silently redirect to homepage — page doesn't exist to the public
 *
 * coming_soon  → redirect to coming-soon.html regardless of visibility
 */
(function() {
  var SUPA_URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';

  // Resolve current page filename
  var raw  = window.location.pathname;
  var path = raw.split('/').pop() || 'index.html';
  if (!path || raw === '/') path = 'index.html';

  // Pages that are exempt from the guard
  var exempt = ['index.html','login.html','coming-soon.html','members-only.html',
                'paid-members-only.html','404.html','reset-password.html','dashboard.html'];
  if (exempt.indexOf(path) !== -1) return;

  // Read session
  var accessToken  = null;
  var cachedTier   = 'free';
  try {
    var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
    if (sess && sess.access_token) accessToken = sess.access_token;
    var prof = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
    if (prof && prof.subscription_tier) cachedTier = prof.subscription_tier;
  } catch(e) {}

  var isLoggedIn = !!accessToken;
  var isPaid     = isLoggedIn && (cachedTier === 'premium' || cachedTier === 'event');

  fetch(SUPA_URL + '/rest/v1/site_pages?path=eq.' + encodeURIComponent(path) +
        '&select=visibility,coming_soon', {
    headers: { 'apikey': SUPA_KEY, 'Accept': 'application/json' }
  })
  .then(function(r) { return r.ok ? r.json() : null; })
  .then(function(rows) {
    if (!Array.isArray(rows) || !rows.length) return;
    var page = rows[0];

    // Coming soon takes priority
    if (page.coming_soon) {
      window.location.replace('coming-soon.html?from=' + encodeURIComponent(path));
      return;
    }

    switch (page.visibility) {
      case 'hidden':
        // No explanation — just go home. Page doesn't exist to the public.
        window.location.replace('index.html');
        break;

      case 'registered':
        // Any logged-in user. Redirect non-members to members-only.html.
        if (!isLoggedIn) {
          window.location.replace('members-only.html?next=' + encodeURIComponent(path));
        }
        break;

      case 'paid':
        // Paid subscribers only.
        if (!isLoggedIn) {
          window.location.replace('members-only.html?next=' + encodeURIComponent(path));
        } else if (!isPaid) {
          // Logged in but not paid — show upgrade page
          window.location.replace('paid-members-only.html?next=' + encodeURIComponent(path));
        }
        break;

      default:
        // public — no action
        break;
    }
  })
  .catch(function() {}); // Never break a page for a guard error
})();
