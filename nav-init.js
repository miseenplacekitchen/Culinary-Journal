/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — nav-init.js  (shared top-right nav)

   Renders the auth/action area into any element with id="nav-btns".
   This is the SINGLE source of truth for the nav buttons — every page
   that includes <div id="nav-btns"></div> + this script gets the same
   look and behaviour, and a change here updates every page at once.

   Signed IN  →  [ @username ▾ ]  opens a dropdown:
                   • header (full name + @username)
                   • My Profile
                   • Submit a Recipe
                   • Browse Recipes
                   • ─────────────
                   • Sign Out
   Signed OUT →  [ Sign In ]  [ Hub ▾ ]   Hub opens:
                   • Submit a Recipe
                   • Browse Recipes

   Everything is theme-aware (uses style.css CSS variables) and the
   dropdown closes on outside-click or Escape.
═══════════════════════════════════════════════════════════════ */
(function () {

  // ── Icons (inline SVG, inherit currentColor) ──────────────────
  var IC = {
    chevron: '<svg class="cj-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>',
    profile: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    submit:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
    book:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>',
    signout: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
    dashboard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/></svg>',
    drafts: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="13" y2="17"/></svg>'
  };

  // ── One-time stylesheet injection (keeps the nav self-contained) ─
  function injectStyles() {
    if (document.getElementById('cj-nav-style')) return;
    var css = ''
      + '.cj-menu-wrap{position:relative;display:inline-block}'
      + '.cj-trigger{display:inline-flex;align-items:center;gap:7px;cursor:pointer;'
        + 'font-family:"DM Sans",sans-serif;font-size:13px;font-weight:500;line-height:1;'
        + 'padding:9px 15px;border-radius:22px;text-decoration:none;'
        + 'background:var(--card-bg);border:1px solid var(--border);color:var(--text-high);'
        + 'transition:background .18s,border-color .18s,color .18s}'
      + '.cj-trigger:hover{border-color:var(--accent-border);background:var(--accent-glow);color:var(--text-high)}'
      + '.cj-trigger.cj-primary{background:var(--accent);border-color:var(--accent);color:#fff}'
      + '.cj-trigger.cj-primary:hover{filter:brightness(.94)}'
      + '.cj-trigger .cj-chev{width:12px;height:12px;opacity:.7;transition:transform .2s}'
      + '.cj-menu-wrap.open .cj-chev{transform:rotate(180deg)}'
      + '.cj-handle{color:var(--accent);font-weight:500}'
      + '.cj-menu{position:absolute;top:calc(100% + 8px);right:0;min-width:212px;'
        + 'background:var(--overlay-dark);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);'
        + 'border:1px solid var(--border);border-radius:12px;box-shadow:0 16px 40px rgba(0,0,0,.5);'
        + 'padding:6px;z-index:2000;display:none;opacity:0;transform:translateY(-6px);'
        + 'transition:opacity .15s ease,transform .15s ease}'
      + '.cj-menu-wrap.open .cj-menu{display:block;opacity:1;transform:translateY(0)}'
      + '.cj-menu-head{padding:9px 12px 7px}'
      + '.cj-menu-name{font-family:"DM Sans",sans-serif;font-size:13px;font-weight:600;color:var(--text-high)}'
      + '.cj-menu-handle{font-family:"DM Sans",sans-serif;font-size:11px;color:var(--accent);margin-top:1px}'
      + '.cj-menu-sep{height:1px;background:var(--border);margin:6px 4px}'
      + '.cj-menu-item{display:flex;align-items:center;gap:10px;width:100%;box-sizing:border-box;'
        + 'padding:9px 12px;border-radius:8px;border:none;background:none;cursor:pointer;'
        + 'font-family:"DM Sans",sans-serif;font-size:13px;color:var(--text-high);'
        + 'text-decoration:none;text-align:left;transition:background .15s}'
      + '.cj-menu-item:hover{background:var(--card-bg)}'
      + '.cj-menu-item svg{width:15px;height:15px;opacity:.7;flex-shrink:0}'
      + '.cj-menu-danger{color:#e07070}.cj-menu-danger svg{opacity:.85}';
    var s = document.createElement('style');
    s.id = 'cj-nav-style';
    s.textContent = css;
    document.head.appendChild(s);
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function item(href, icon, label) {
    return '<a class="cj-menu-item" role="menuitem" href="' + href + '">' + icon + '<span>' + label + '</span></a>';
  }


  // ── Google OAuth Callback Handler ────────────────────────────
  // When Google redirects back, the session is in the URL hash.
  // Read it, store it in localStorage, then clean the URL.
  function handleOAuthCallback() {
    var hash = window.location.hash;
    if (!hash || hash.indexOf('access_token=') === -1) return;
    var params = {};
    hash.replace(/^#/, '').split('&').forEach(function(pair) {
      var kv = pair.split('=');
      params[decodeURIComponent(kv[0])] = decodeURIComponent((kv[1] || '').replace(/\+/g,' '));
    });
    var token = params.access_token;
    if (!token) return;
    try {
      var payload = JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));
      var stored = {
        access_token:   token,
        refresh_token:  params.refresh_token || '',
        user: {
          id:    payload.sub  || '',
          email: payload.email || ''
        },
        user_id:  payload.sub || '',
        username: ''
      };
      localStorage.setItem('tcj_session', JSON.stringify(stored));
      // Clean the URL so the hash disappears
      window.history.replaceState({}, document.title, window.location.pathname + window.location.search);
    } catch(e) { console.error('OAuth callback error:', e); }
  }
  handleOAuthCallback();

  function init() {
    var host = document.getElementById('nav-btns');
    if (!host) return;
    injectStyles();

    var session = null, profile = {};
    try { session = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
    try { profile = JSON.parse(localStorage.getItem('tcj_profile') || '{}') || {}; } catch (_) {}
    var loggedIn = !!(session && session.access_token);
    var username = (session && session.username) || profile.username || '';
    var fullName = profile.full_name || profile.name || '';

    var html;
    if (loggedIn) {
      html =
        '<div class="cj-menu-wrap" id="cj-user">' +
          '<button class="cj-trigger" id="cj-user-trigger" type="button" aria-haspopup="true" aria-expanded="false">' +
            '<span class="cj-handle">@' + escapeHtml(username || 'me') + '</span>' + IC.chevron +
          '</button>' +
          '<div class="cj-menu" role="menu" aria-label="Account menu">' +
            (fullName || username ?
              '<div class="cj-menu-head">' +
                (fullName ? '<div class="cj-menu-name">' + escapeHtml(fullName) + '</div>' : '') +
                '<div class="cj-menu-handle">@' + escapeHtml(username || 'me') + '</div>' +
              '</div><div class="cj-menu-sep"></div>' : '') +
            item('dashboard.html',     IC.dashboard,'Dashboard') +
            item('profile.html',       IC.profile, 'My Profile') +
            item('draft-recipes.html', IC.drafts,  'Draft Recipes') +
            item('submit-recipe.html', IC.submit,  'Submit a Recipe') +
            item('recipes.html',       IC.book,    'Browse Recipes') +
            '<div class="cj-menu-sep"></div>' +
            '<button class="cj-menu-item cj-menu-danger" id="cj-signout" type="button" role="menuitem">' + IC.signout + '<span>Sign Out</span></button>' +
          '</div>' +
        '</div>';
    } else {
      html =
        '<a href="login.html" class="cj-trigger cj-primary">Sign In</a>' +
        '<div class="cj-menu-wrap" id="cj-hub">' +
          '<button class="cj-trigger" id="cj-hub-trigger" type="button" aria-haspopup="true" aria-expanded="false">' +
            'Hub' + IC.chevron +
          '</button>' +
          '<div class="cj-menu" role="menu" aria-label="Hub menu">' +
            item('submit-recipe.html', IC.submit, 'Submit a Recipe') +
            item('recipes.html',       IC.book,   'Browse Recipes') +
          '</div>' +
        '</div>';
    }
    host.innerHTML = html;
    wire(host);
  }

  function wire(host) {
    var wraps = host.querySelectorAll('.cj-menu-wrap');

    function closeAll() {
      wraps.forEach(function (w) {
        w.classList.remove('open');
        var t = w.querySelector('.cj-trigger');
        if (t) t.setAttribute('aria-expanded', 'false');
      });
    }

    wraps.forEach(function (w) {
      var trigger = w.querySelector('.cj-trigger');
      if (!trigger) return;
      trigger.addEventListener('click', function (e) {
        e.stopPropagation();
        var willOpen = !w.classList.contains('open');
        closeAll();
        if (willOpen) { w.classList.add('open'); trigger.setAttribute('aria-expanded', 'true'); }
      });
    });

    // Close on outside click + Escape (bound once)
    if (!window.__cjNavClose) {
      window.__cjNavClose = true;
      document.addEventListener('click', function (e) {
        if (!e.target.closest || !e.target.closest('.cj-menu-wrap')) {
          document.querySelectorAll('.cj-menu-wrap.open').forEach(function (w) {
            w.classList.remove('open');
            var t = w.querySelector('.cj-trigger'); if (t) t.setAttribute('aria-expanded', 'false');
          });
        }
      });
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
          document.querySelectorAll('.cj-menu-wrap.open').forEach(function (w) {
            w.classList.remove('open');
            var t = w.querySelector('.cj-trigger'); if (t) t.setAttribute('aria-expanded', 'false');
          });
        }
      });
    }

    var signout = host.querySelector('#cj-signout');
    if (signout) {
      signout.addEventListener('click', function () {
        try { localStorage.removeItem('tcj_session'); } catch (_) {}
        try { localStorage.removeItem('tcj_profile'); } catch (_) {}
        window.location.href = 'index.html';
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
