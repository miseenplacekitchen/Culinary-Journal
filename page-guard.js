/**
 * page-guard.js — The Culinary Journal
 * Include in <head> after theme-init.js on gated pages.
 * Never include in: login.html, dashboard.html, coming-soon.html,
 *                   members-only.html, paid-members-only.html, 404.html
 *
 * Site-wide sign-in is enforced by theme-init.js (TCJ_SITE_PRIVATE).
 * This file only applies per-page visibility / tier rules for signed-in users.
 *
 * Visibility levels:
 *   public     → everyone (unless min_tier gate on registered/paid)
 *   registered → logged-in user meeting min_tier (default free)
 *   paid       → subscriber meeting min_tier (default monthly)
 *   hidden     → silently redirect to homepage
 *
 * Tier hierarchy: free < daily < weekly < monthly < yearly < premium/event
 * Admins bypass all restrictions.
 * coming_soon → redirect to coming-soon.html regardless of visibility
 */
(function() {
  var SUPA_URL = window.SUPA_URL || 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = window.SUPA_KEY || '';

  var TIER_RANK = { free: 0, daily: 1, weekly: 2, monthly: 3, yearly: 4, premium: 5, event: 5 };

  function userMeetsTier(userTier, requiredTier) {
    if (!requiredTier || requiredTier === 'free') return true;
    var u = TIER_RANK[userTier] !== undefined ? TIER_RANK[userTier] : 0;
    var r = TIER_RANK[requiredTier] !== undefined ? TIER_RANK[requiredTier] : 0;
    return u >= r;
  }

  var raw  = window.location.pathname;
  var path = raw.split('/').pop() || 'index.html';
  if (!path || raw === '/') path = 'index.html';

  var exempt = ['login.html','onboarding.html','coming-soon.html','members-only.html',
                'paid-members-only.html','404.html','reset-password.html','dashboard.html',
                'email-confirm.html','email-reset.html'];
  if (exempt.indexOf(path) !== -1) return;

  var accessToken = null;
  var isAdmin     = false;
  var userTier    = 'free';
  var isLoggedIn  = false;

  try {
    var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
    if (sess && sess.access_token) {
      accessToken = sess.access_token;
      isLoggedIn  = true;
    }
    var prof = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
    if (prof) {
      isAdmin  = !!(prof.is_admin || (typeof isTcjAdmin === 'function' && isTcjAdmin(prof, sess)));
      userTier = prof.subscription_tier || 'free';
    }
  } catch(e) {}

  // theme-init.js already sent anonymous visitors to login.html
  if (window.TCJ_SITE_PRIVATE && !isLoggedIn) return;

  if (isAdmin) return;

  fetch(SUPA_URL + '/rest/v1/site_pages?path=eq.' + encodeURIComponent(path) +
        '&select=visibility,coming_soon,min_tier', {
    headers: { 'apikey': SUPA_KEY, 'Accept': 'application/json' }
  })
  .then(function(r) { return r.ok ? r.json() : null; })
  .then(function(rows) {
    if (!Array.isArray(rows) || !rows.length) return;

    var page = rows[0];
    var minTier = page.min_tier || 'free';

    if (page.coming_soon) {
      window.location.replace('coming-soon.html?from=' + encodeURIComponent(path));
      return;
    }

    switch (page.visibility) {

      case 'hidden':
        window.location.replace('index.html');
        break;

      case 'registered':
        if (!isLoggedIn) {
          window.location.replace('members-only.html?next=' + encodeURIComponent(path));
          return;
        }
        if (!userMeetsTier(userTier, minTier)) {
          window.location.replace('paid-members-only.html?next=' + encodeURIComponent(path) + '&tier=' + encodeURIComponent(minTier));
        }
        break;

      case 'paid':
        var required = (minTier && minTier !== 'free') ? minTier : 'monthly';
        if (!isLoggedIn || !userMeetsTier(userTier, required)) {
          window.location.replace('paid-members-only.html?next=' + encodeURIComponent(path) + '&tier=' + encodeURIComponent(required));
        }
        break;

      default:
        break;
    }
  })
  .catch(function() {});
})();
