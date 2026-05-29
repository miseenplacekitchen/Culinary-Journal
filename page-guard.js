/**
 * THE CULINARY JOURNAL — Page Guard
 * Checks page visibility settings from Supabase.
 * Included automatically via nav-init.js — no need to add separately.
 *
 * Page IDs are derived from the HTML filename automatically.
 * Settings managed from Site Settings → Page Visibility.
 */
(function() {
  'use strict';
  if (window.__pgLoaded) return;
  window.__pgLoaded = true;

  var SUPA_URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';
  var CACHE_KEY = 'tcj_page_vis';
  var CACHE_TTL = 5 * 60 * 1000; // 5 minutes

  // Pages that are never guarded (auth pages, home, legal)
  var EXEMPT = ['index', 'login', 'reset-password', 'privacy', 'terms',
                'ai-disclaimer', 'dietary-card', 'user'];

  // Derive page ID from filename (e.g. "meal-planner.html" → "meal-planner")
  function getPageId() {
    var path = window.location.pathname;
    var file = path.split('/').pop().replace('.html', '') || 'index';
    return file;
  }

  function getSession() {
    try { return JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch(_) { return null; }
  }
  function getProfile() {
    try { return JSON.parse(localStorage.getItem('tcj_profile') || 'null'); } catch(_) { return null; }
  }
  function isAdmin() {
    var p = getProfile();
    return p && (p.is_admin === true || p.email === 'miseenplacekitchen.official@gmail.com');
  }

  function showBlock(visibility, customMessage, pageId) {
    var messages = {
      'offline':       { icon:'🛠', title:'Under Maintenance', sub:'We\'re making improvements. Check back soon.', colour:'#888' },
      'admin-only':    { icon:'🔐', title:'Admin Access Only',  sub:'This page is currently restricted.', colour:'var(--accent,#c4973b)' },
      'members-only':  { icon:'👤', title:'Sign In Required',   sub:'This page is available to registered members.', colour:'var(--accent,#c4973b)' }
    };
    var info = messages[visibility] || messages['admin-only'];
    var msg  = customMessage || info.sub;

    var overlay = document.createElement('div');
    overlay.id  = 'pg-overlay';
    overlay.style.cssText = [
      'position:fixed', 'inset:0', 'background:var(--bg,#0f1011)', 'z-index:99999',
      'display:flex', 'align-items:center', 'justify-content:center',
      'flex-direction:column', 'padding:40px', 'text-align:center',
      'font-family:"DM Sans",sans-serif'
    ].join(';');

    var inner = [
      '<div style="font-size:48px;margin-bottom:16px">' + info.icon + '</div>',
      '<div style="font-family:\'Cormorant Garamond\',Georgia,serif;font-size:1.6rem;font-weight:700;color:var(--text-high,#e8e5e0);margin-bottom:8px">',
        'The Culinary Journal',
      '</div>',
      '<div style="font-size:1rem;font-weight:600;color:' + info.colour + ';margin-bottom:8px">' + info.title + '</div>',
      '<div style="font-size:13px;color:var(--text-mid,#7a736d);max-width:380px;line-height:1.6;margin-bottom:24px">' + msg + '</div>'
    ];

    if (visibility === 'members-only') {
      inner.push('<a href="login.html" style="display:inline-block;padding:11px 28px;background:var(--accent,#c4973b);color:#fff;text-decoration:none;border-radius:9px;font-family:\'DM Sans\',sans-serif;font-size:13px;font-weight:600">Sign In →</a>');
    }
    if (visibility !== 'offline') {
      inner.push('<a href="index.html" style="display:inline-block;margin-top:12px;font-size:12px;color:var(--text-mid,#7a736d);text-decoration:none">← Back to Home</a>');
    }

    overlay.innerHTML = inner.join('');
    // Hide page content immediately, show overlay
    document.documentElement.style.visibility = 'hidden';
    document.addEventListener('DOMContentLoaded', function() {
      document.documentElement.style.visibility = '';
      document.body.appendChild(overlay);
    });
  }

  async function check() {
    var pageId = getPageId();
    if (EXEMPT.indexOf(pageId) !== -1) return; // Never guard exempt pages

    try {
      // Check cache first
      var cached = null;
      try {
        var raw = sessionStorage.getItem(CACHE_KEY);
        if (raw) {
          var parsed = JSON.parse(raw);
          if (Date.now() - parsed.ts < CACHE_TTL) cached = parsed.data;
        }
      } catch(_) {}

      var settings = cached;
      if (!settings) {
        var res = await fetch(SUPA_URL + '/rest/v1/rpc/get_page_settings', {
          method: 'POST',
          headers: { 'apikey': SUPA_KEY, 'Content-Type': 'application/json' },
          body: '{}'
        });
        if (!res.ok) return; // Fail open — if can't load, allow access
        var rows = await res.json();
        settings = {};
        (rows || []).forEach(function(r) { settings[r.page_id] = {visibility: r.visibility, message: r.message}; });
        try { sessionStorage.setItem(CACHE_KEY, JSON.stringify({ts: Date.now(), data: settings})); } catch(_) {}
      }

      var pageSetting = settings[pageId];
      if (!pageSetting || pageSetting.visibility === 'live') return; // All good

      var vis = pageSetting.visibility;
      var msg = pageSetting.message || '';

      // Check permissions
      if (vis === 'admin-only')   { if (isAdmin()) return; }
      if (vis === 'members-only') { if (getSession()) return; }
      // offline: nobody gets in

      showBlock(vis, msg, pageId);

    } catch(_) {
      // Network error — fail open (allow access rather than block everyone)
    }
  }

  // Run immediately
  check();

})();
