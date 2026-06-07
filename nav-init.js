// ══════════════════════════════════════════════════════
// THE CULINARY JOURNAL — Navigation
// CJ_SECTIONS is the single source of truth for all navigation.
// Edit here → every page updates automatically.
// ══════════════════════════════════════════════════════

// Each section has a primary page — clicking the label navigates there directly.
// The dropdown (sub-pages) appears on hover; the chevron toggles it for touch/keyboard.
var CJ_SECTIONS = [
  {
    id:'recipebook', label:'The Recipe Book', emoji:'📖', primaryPage:'recipes.html',
    pages:['recipes.html','chefs.html','search.html','submit-recipe.html','draft-recipes.html','food-map.html','festival-calendar.html'],
    links:[
      {href:'recipes.html',      emoji:'🍽', label:'Browse Recipes'},
      {href:'chefs.html',        emoji:'👨‍🍳', label:'Chef Directory'},
      {href:'food-map.html',     emoji:'🌍', label:'Food by Map'},
      {href:'festival-calendar.html', emoji:'🎉', label:'Festival Calendar'},
      {href:'submit-recipe.html',emoji:'📝', label:'Submit a Recipe'},
    ]
  },
  {
    id:'miseenplace', label:'Mise en Place', emoji:'🍳', primaryPage:'meal-planner.html',
    pages:['meal-planner.html','grocery.html','pantry.html','print-studio.html','family-profiles.html','household.html'],
    links:[
      {href:'family-profiles.html', emoji:'👨‍👩‍👧', label:'Family Profiles'},
      {href:'household.html',     emoji:'🏠', label:'Household'},
      {href:'meal-planner.html', emoji:'🗓', label:'Meal Planner'},
      {href:'grocery.html',      emoji:'🛒', label:'Grocery List'},
      {href:'pantry.html',       emoji:'🫙', label:'Pantry & Fridge'},
      {href:'print-studio.html', emoji:'🖨', label:'Print Studio'},
    ]
  },
  {
    id:'guestlist', label:'The Guest List', emoji:'🪑', primaryPage:'table-planner.html',
    pages:['table-planner.html','dietary-card.html'],
    links:[
      {href:'table-planner.html',   emoji:'🪑', label:'Table Planner'},
    ]
  },
  {
    id:'library', label:'The Library', emoji:'📚', primaryPage:'library-directory.html',
    pages:['library-directory.html','library-profile.html','preservation.html','conversions.html','baby.html'],
    links:[
      {href:'library-directory.html?type=ingredient', emoji:'🌿', label:'Ingredients'},
      {href:'library-directory.html?type=spice',      emoji:'🌶', label:'Spice Directory'},
      {href:'library-directory.html?type=tool',       emoji:'🔪', label:'Tools & Appliances'},
      {href:'library-directory.html?type=cut',        emoji:'🥩', label:'Cuts & Prep'},
      {href:'library-directory.html?type=preservation',emoji:'🫙', label:'Preservation Academy'},
      {href:'conversions.html',                       emoji:'⚖️', label:'Conversions & Weights'},
      {href:'baby.html',                              emoji:'👶', label:'Baby & Toddler'},
    ]
  },
  {
    // AP-05: member-personal pages. signedInOnly — hidden when logged out
    // (the logged-out account dropdown trigger was renamed Explore to avoid
    // the label collision). Primary page = Analytics per D-3 assumption.
    id:'myhub', label:'My Hub', emoji:'✨', primaryPage:'my-dashboard.html', signedInOnly:true,
    pages:['culinary-life.html','collections.html','draft-recipes.html','diary.html','my-dashboard.html'],
    links:[
      {href:'culinary-life.html', emoji:'✨', label:'Culinary Life'},
      {href:'collections.html',   emoji:'📁', label:'My Collections'},
      {href:'draft-recipes.html', emoji:'📝', label:'My Recipes & Drafts'},
      {href:'diary.html',         emoji:'📔', label:'My Diary'},
      {href:'my-dashboard.html',  emoji:'📊', label:'Analytics'},
    ]
  }
];


// ── CANONICAL LOGO ────────────────────────────────────────────────
// Ensures the logo is always correct regardless of what the page HTML
// has hardcoded. Single source of truth for logo content.
function canonicalizeLogo() {
  var logo = document.querySelector('a.nav-logo, .nav-logo');
  if (!logo) return;
  logo.setAttribute('href', 'index.html');
  logo.innerHTML =
    '<img src="favicon.svg" alt="The Culinary Journal" class="nav-logo-icon" ' +
    'style="width:32px;height:32px;border-radius:8px;flex-shrink:0;">' +
    '<span class="nav-logo-text">The Culinary Journal</span>' +
    '<span class="nav-logo-badge">Est. 2025</span>';
}

function buildSectionNav() {
  var tabNav = document.querySelector('.tab-nav');
  if (!tabNav) return;

  var page = window.location.pathname.split('/').pop() || 'index.html';
  var activeSection = null;
  CJ_SECTIONS.forEach(function(s) {
    if (s.pages.indexOf(page) > -1) activeSection = s.id;
  });
  if (activeSection) document.body.classList.add('section-' + activeSection);

  var wrapper = document.createElement('div');
  wrapper.style.cssText = 'display:flex;align-items:center;gap:2px;padding:0 20px';

  var homeA = document.createElement('a');
  homeA.href = 'index.html';
  homeA.textContent = 'Home';
  homeA.style.cssText = 'padding:10px 14px;font-family:DM Sans,sans-serif;font-size:13px;font-weight:500;text-decoration:none;border-radius:8px;white-space:nowrap;color:' + (page === 'index.html' ? 'var(--accent)' : 'var(--text-low)');
  wrapper.appendChild(homeA);

  var drop = document.getElementById('_cj_nav_drop');
  if (!drop) {
    drop = document.createElement('div');
    drop.id = '_cj_nav_drop';
    drop.style.cssText = 'display:none;position:fixed;background:#0f1011;border:1px solid rgba(255,255,255,0.12);border-radius:12px;padding:6px;min-width:220px;box-shadow:0 16px 48px rgba(0,0,0,0.8);z-index:99999';
    document.body.appendChild(drop);
  }

  var currentBtn = null;

  CJ_SECTIONS.forEach(function(section) {
    // AP-05: member-personal sections render only for signed-in users
    if (section.signedInOnly) {
      var _s = null;
      try { _s = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
      if (!_s || !_s.access_token) return;
    }
    var isActive = activeSection === section.id;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = section.emoji ? section.emoji + ' ' + section.label : section.label;
    btn.style.cssText = 'padding:10px 14px;font-family:DM Sans,sans-serif;font-size:13px;font-weight:' + (isActive ? '600' : '500') + ';color:' + (isActive ? 'var(--accent)' : 'var(--text-low)') + ';background:none;border:none;border-radius:8px;cursor:pointer;white-space:nowrap';

    var links = section.links.slice();
    btn.addEventListener('click', function(evt) {
      evt.stopPropagation();
      if (drop.style.display !== 'none' && currentBtn === btn) {
        drop.style.display = 'none';
        currentBtn = null;
        return;
      }
      drop.innerHTML = '';
      links.forEach(function(link) {
        var a = document.createElement('a');
        a.href = link.href;
        var icon = document.createElement('span');
        icon.textContent = link.emoji || '';
        icon.style.cssText = 'font-size:15px;margin-right:8px;flex-shrink:0';
        var txt = document.createTextNode(link.label);
        a.appendChild(icon);
        a.appendChild(txt);
        a.style.cssText = 'display:flex;align-items:center;padding:10px 14px;border-radius:8px;font-family:DM Sans,sans-serif;font-size:13px;color:' + (link.href === page ? 'var(--accent)' : 'rgba(255,255,255,0.75)') + ';text-decoration:none;white-space:nowrap';
        a.onmouseover = function(){ this.style.background = 'rgba(255,255,255,0.07)'; };
        a.onmouseout  = function(){ this.style.background = ''; };
        drop.appendChild(a);
      });
      var r = btn.getBoundingClientRect();
      drop.style.top  = Math.round(r.bottom + 8) + 'px';
      drop.style.left = Math.round(r.left) + 'px';
      drop.style.display = 'block';
      currentBtn = btn;
    });

    wrapper.appendChild(btn);
  });

  document.addEventListener('click', function() {
    if (drop.style.display !== 'none') {
      drop.style.display = 'none';
      currentBtn = null;
    }
  });

  tabNav.innerHTML = '';
  tabNav.appendChild(wrapper);
}

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
    drafts: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="8" y1="13" x2="16" y2="13"/><line x1="8" y1="17" x2="13" y2="17"/></svg>',
    bell:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>'
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
      + '.cj-menu-danger{color:#e07070}.cj-menu-danger svg{opacity:.85}'
      + '.sec-nav{display:flex;align-items:center;height:100%;gap:2px;flex-wrap:nowrap;overflow-x:auto;overflow-y:visible}'+'.sec-nav::-webkit-scrollbar{display:none}'+'.sec-nav-home{display:flex;align-items:center;gap:6px;padding:10px 14px;font-family:DM Sans,sans-serif;font-size:13px;font-weight:500;color:var(--text-low);text-decoration:none;border-radius:8px;transition:all .2s;white-space:nowrap}'+'.sec-nav-home:hover,.sec-nav-home.active{color:var(--accent);background:var(--accent-glow)}'+'.sec-nav-item{position:relative;display:flex;align-items:center}'+'.sec-nav-btn{display:flex;align-items:center;gap:6px;padding:10px 12px;font-family:DM Sans,sans-serif;font-size:13px;font-weight:500;color:var(--text-low);text-decoration:none;border-radius:8px;transition:all .2s;white-space:nowrap}'+'.sec-nav-btn:hover,.sec-nav-btn.active{color:var(--accent);background:var(--accent-glow)}'+'.sec-nav-chevron-btn{display:none}'+'.sec-nav-chevron{font-size:10px;display:inline-block;transition:transform .2s}'+'.sec-nav-item.open .sec-nav-chevron{transform:rotate(180deg)}'+'.sec-nav-dropdown{position:absolute;top:calc(100% + 8px);left:0;min-width:210px;background:var(--overlay-dark,rgba(15,16,17,.97));border:1px solid var(--border);border-radius:12px;padding:6px;backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);box-shadow:0 12px 40px rgba(0,0,0,.6);display:none;z-index:5000}'+'.sec-nav-item:hover .sec-nav-dropdown,.sec-nav-item.open .sec-nav-dropdown{display:block}'+'.sec-nav-link{display:flex;align-items:center;gap:9px;padding:9px 12px;border-radius:8px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);text-decoration:none;transition:all .15s;white-space:nowrap}'+'.sec-nav-link:hover{background:rgba(255,255,255,.05);color:var(--text-high)}'+'.sec-nav-link.active{color:var(--accent);background:var(--accent-glow)}'+'.sec-nav-link-icon{font-size:14px;flex-shrink:0}'+'@media(max-width:768px){.sec-nav-btn,.sec-nav-home{padding:8px 8px;font-size:12px}.sec-nav-dropdown{position:fixed;bottom:0;left:0;right:0;top:auto;border-radius:16px 16px 0 0;max-height:60vh;overflow-y:auto}}';
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
      // Fetch profile (includes is_admin) and store it
      fetch(window.SUPA_URL + '/rest/v1/rpc/get_my_profile', {
        method: 'POST',
        headers: {
          'apikey':        window.SUPA_KEY,
          'Authorization': 'Bearer ' + token,
          'Content-Type':  'application/json'
        },
        body: JSON.stringify({})
      }).then(function(r){ return r.json(); }).then(async function(d){
        var p = Array.isArray(d) ? d[0] : d;
        if (!p) return;
        if (typeof enrichProfile === 'function') {
          p = await enrichProfile(p, stored);
        }
        stored.username = p.username || stored.username || '';
        localStorage.setItem('tcj_session', JSON.stringify(stored));
        localStorage.setItem('tcj_profile', JSON.stringify(p));
      }).catch(function(){});
    } catch(e) { console.error('OAuth callback error:', e); }
  }
  handleOAuthCallback();

  function injectSkipLink() {
    if (document.getElementById('cj-skip-link')) return;
    var main = document.querySelector('main, [role="main"], .gl-wrap, .ch-wrap, .rp-wrap, .legal-wrap, .nf-wrap, #rp-wrap');
    if (!main) return;
    if (!main.id) main.id = 'main-content';
    if (!main.getAttribute('tabindex')) main.setAttribute('tabindex', '-1');
    var a = document.createElement('a');
    a.id = 'cj-skip-link';
    a.className = 'cj-skip-link';
    a.href = '#' + main.id;
    a.textContent = 'Skip to content';
    document.body.insertBefore(a, document.body.firstChild);
  }

  function init() {
    injectSkipLink();
    canonicalizeLogo();
    buildSectionNav();
    var host = document.getElementById('nav-btns') || document.querySelector('[data-nav-host]');
    if (!host) return;
    injectStyles();

    // Inject search icon into nav logo area
    var navLogo = document.querySelector('.nav-logo');
    if (navLogo && !document.getElementById('cj-search-btn')) {
      var searchBtn = document.createElement('a');
      searchBtn.id = 'cj-search-btn';
      searchBtn.href = 'search.html';
      searchBtn.title = 'Search';
      searchBtn.style.cssText = 'display:inline-flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:8px;background:none;color:var(--text-mid);text-decoration:none;font-size:16px;margin-left:8px;transition:color 0.15s,background 0.15s;border:1px solid var(--border)';
      searchBtn.innerHTML = '🔍';
      searchBtn.addEventListener('mouseover', function(){this.style.color='var(--accent)';this.style.borderColor='var(--accent)';});
      searchBtn.addEventListener('mouseout',  function(){this.style.color='var(--text-mid)';this.style.borderColor='var(--border)';});
      navLogo.parentNode.insertBefore(searchBtn, host);
    }

    var session = null, profile = {};
    try { session = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
    try { profile = JSON.parse(localStorage.getItem('tcj_profile') || '{}') || {}; } catch (_) {}
    var loggedIn = !!(session && session.access_token);
    var username = (session && session.username) || profile.username || '';
    var fullName = profile.full_name || profile.name || '';
    var isAdmin  = !!(loggedIn && profile.is_admin);

    var html;
    if (loggedIn) {
      html =
        '<button class="cj-notif-bell" id="nav-notif-btn" onclick="toggleNotifPanel()" title="Notifications" style="position:relative;background:none;border:1px solid var(--border);border-radius:8px;width:34px;height:34px;cursor:pointer;color:var(--text-mid);font-size:16px;display:inline-flex;align-items:center;justify-content:center;margin-right:8px;transition:color 0.15s,border-color 0.15s">🔔<span id="nav-notif-badge" style="display:none;position:absolute;top:-4px;right:-4px;background:var(--accent);color:#0f1117;border-radius:10px;font-size:10px;font-weight:700;padding:1px 5px;font-family:DM Sans,sans-serif;min-width:16px;text-align:center"></span></button>' +
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
            (isAdmin ? item('dashboard.html', IC.dashboard, 'Admin Panel') : '') +
            item('submit-recipe.html', IC.submit, 'Submit a Recipe') +
            (isAdmin ? item('library-submit.html', IC.drafts, '📚 Submit Library Profile') : '') +
            '<div class="cj-menu-sep"></div>' +
            item('notifications.html', IC.bell, 'Notifications') +
            item('profile.html',       IC.profile, 'My Profile') +
            '<div class="cj-menu-sep"></div>' +
            '<button class="cj-menu-item cj-menu-danger" id="cj-signout" type="button" role="menuitem">' + IC.signout + '<span>Sign Out</span></button>' +
          '</div>' +
        '</div>';
    } else {
      html =
        '<a href="login.html" class="cj-trigger cj-primary">Sign In</a>' +
        '<div class="cj-menu-wrap" id="cj-hub">' +
          '<button class="cj-trigger" id="cj-hub-trigger" type="button" aria-haspopup="true" aria-expanded="false">' +
            'Explore' + IC.chevron +
          '</button>' +
          '<div class="cj-menu" role="menu" aria-label="Explore menu">' +
            item('submit-recipe.html', IC.submit, 'Submit a Recipe') +
            item('recipes.html',       IC.book,   'Browse Recipes') +
          '</div>' +
        '</div>';
    }
    host.innerHTML = html;
    wire(host);

    if (loggedIn && session && session.access_token) {
      refreshNavProfile(session, host);
    }
  }

  function refreshNavProfile(session, host) {
    fetch(window.SUPA_URL + '/rest/v1/rpc/get_my_profile', {
      method: 'POST',
      headers: {
        'apikey':        window.SUPA_KEY,
        'Authorization': 'Bearer ' + session.access_token,
        'Content-Type':  'application/json'
      },
      body: JSON.stringify({})
    }).then(function(r){ return r.ok ? r.json() : null; }).then(async function(d){
      if (!d) return;
      var p = Array.isArray(d) ? d[0] : d;
      if (!p) return;
      if (typeof enrichProfile === 'function') {
        p = await enrichProfile(p, session);
      }
      localStorage.setItem('tcj_profile', JSON.stringify(p));
      if (p.username && p.username !== session.username) {
        session.username = p.username;
        localStorage.setItem('tcj_session', JSON.stringify(session));
      }
      var trigger = host.querySelector('#cj-user-trigger .cj-handle');
      if (trigger) trigger.textContent = '@' + (p.username || session.username || 'me');
      var menuName = host.querySelector('.cj-menu-name');
      if (menuName && p.full_name) menuName.textContent = p.full_name;
      var menuHandle = host.querySelector('.cj-menu-handle');
      if (menuHandle) menuHandle.textContent = '@' + (p.username || session.username || 'me');
    }).catch(function(){});
  }

  function wire(host) {
    var wraps = host.querySelectorAll('.cj-menu-wrap');

    function closeAll() {
      // Document-wide: the section nav and the profile/account nav are
      // separate hosts; closing only this host's menus let two dropdowns
      // stay open at once.
      document.querySelectorAll('.cj-menu-wrap.open').forEach(function (w) {
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
        try { localStorage.removeItem('tcj_theme');   } catch (_) {}
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

// ── NOTIFICATIONS ────────────────────────────────────────────────
(function() {
  var NOTIF_CSS = '.nav-notif-panel{position:absolute;top:56px;right:16px;background:var(--bg);border:1px solid var(--border);border-radius:13px;width:340px;max-height:400px;overflow-y:auto;z-index:9999;box-shadow:0 8px 32px rgba(0,0,0,0.3)}' +
    '.nav-notif-head{padding:12px 16px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center}' +
    '.nav-notif-title{font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:600;color:var(--text-high)}' +
    '.nav-notif-clear{font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent);background:none;border:none;cursor:pointer}' +
    '.nav-notif-item{padding:11px 16px;border-bottom:1px solid rgba(255,255,255,0.05);cursor:pointer;display:flex;gap:10px;align-items:flex-start;text-decoration:none}' +
    '.nav-notif-item:hover{background:var(--text-ghost)}' +
    '.nav-notif-item.unread{background:rgb(from var(--accent) r g b / 0.05)}' +
    '.nav-notif-dot{width:7px;height:7px;border-radius:50%;background:var(--accent);flex-shrink:0;margin-top:4px}' +
    '.nav-notif-dot.read{background:transparent}' +
    '.nav-notif-msg{font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);line-height:1.4}' +
    '.nav-notif-time{font-family:DM Sans,sans-serif;font-size:10px;color:var(--text-mid);margin-top:2px}' +
    '.nav-notif-empty{padding:24px 16px;text-align:center;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)}';
  var s = document.createElement('style'); s.textContent = NOTIF_CSS;
  document.head.appendChild(s);
})();

var _notifOpen = false;
var _notifPanel = null;
var SUPA_URL_N = window.SUPA_URL;
var SUPA_KEY_N = window.SUPA_KEY;
async function notifRpc(fn, params) {
  var session = JSON.parse(localStorage.getItem('tcj_session')||'null');
  if (!session) return null;
  try {
    var res = await fetch(SUPA_URL_N + '/rest/v1/rpc/' + fn, {
      method:'POST',
      headers:{'apikey':SUPA_KEY_N,'Content-Type':'application/json','Authorization':'Bearer '+session.access_token},
      body:JSON.stringify(params||{})
    });
    if (!res.ok) return null;   // 404 = RPC not built yet, 401 = not authorised — both silent
    return res.json();
  } catch(_) { return null; }
}

async function loadNotifCount() {
  var session = JSON.parse(localStorage.getItem('tcj_session')||'null');
  if (!session) return;
  try {
    var count = await notifRpc('get_notification_count',{});
    var badge = document.getElementById('nav-notif-badge');
    var n = parseInt(count)||0;
    if (badge) { badge.textContent = n>9?'9+':n; badge.style.display = n>0?'inline':'none'; }
  } catch(_) {}
}

async function toggleNotifPanel() {
  if (_notifOpen) { closeNotifPanel(); return; }
  _notifOpen = true;
  var btn = document.getElementById('nav-notif-btn');
  if (!btn) return;
  if (_notifPanel) _notifPanel.remove();
  _notifPanel = document.createElement('div');
  _notifPanel.className = 'nav-notif-panel';
  _notifPanel.innerHTML = '<div class="nav-notif-head"><div class="nav-notif-title">Notifications</div><button class="nav-notif-clear" onclick="markAllRead()">Mark all read</button></div><div class="nav-notif-empty">Loading...</div>';
  document.body.appendChild(_notifPanel);
  positionPanel();
  setTimeout(function(){document.addEventListener('click', outsideNotifClick, {once:true});},50);
  var notifs = await notifRpc('get_my_notifications',{});
  renderNotifPanel(notifs||[]);
}

function positionPanel() {
  if (!_notifPanel) return;
  _notifPanel.style.cssText = 'position:fixed;top:56px;right:16px;background:var(--bg);border:1px solid var(--border);border-radius:13px;width:340px;max-height:400px;overflow-y:auto;z-index:99999;box-shadow:0 8px 32px rgba(0,0,0,0.4)';
}

function renderNotifPanel(notifs) {
  if (!_notifPanel) return;
  var head = _notifPanel.querySelector('.nav-notif-head');
  _notifPanel.innerHTML = '';
  _notifPanel.appendChild(head);
  if (!notifs.length) {
    var empty = document.createElement('div');
    empty.className = 'nav-notif-empty';
    empty.textContent = 'No notifications yet';
    _notifPanel.appendChild(empty);
    var foot0 = document.createElement('div');
    foot0.style.cssText = 'padding:8px 14px 12px;border-top:1px solid var(--border);text-align:center';
    foot0.innerHTML = '<a href="notifications.html" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent);text-decoration:none;font-weight:600">View all notifications →</a>';
    _notifPanel.appendChild(foot0);
    return;
  }
  notifs.forEach(function(n) {
    var timeStr = '';
    var diff = Date.now() - new Date(n.created_at).getTime();
    if (diff < 3600000) timeStr = Math.round(diff/60000)+'m ago';
    else if (diff < 86400000) timeStr = Math.round(diff/3600000)+'h ago';
    else timeStr = Math.round(diff/86400000)+'d ago';
    var icon = n.type==='recipe_approved'?'✅':n.type==='recipe_rejected'?'❌':'⏳';
    var item = document.createElement('a');
    item.className = 'nav-notif-item' + (n.read?'':' unread');
    item.href = n.recipe_id ? 'recipe-page.html?id=' + n.recipe_id : '#';
    // Build notification item using DOM — no innerHTML with user data
    var dot = document.createElement('div');
    dot.className = 'nav-notif-dot' + (n.read ? ' read' : '');
    var inner = document.createElement('div');
    var msg = document.createElement('div');
    msg.className = 'nav-notif-msg';
    msg.textContent = (icon ? icon + ' ' : '') + (n.recipe_name || n.message || 'Notification');
    var time = document.createElement('div');
    time.className = 'nav-notif-time';
    time.textContent = timeStr;
    inner.appendChild(msg);
    inner.appendChild(time);
    item.appendChild(dot);
    item.appendChild(inner);
    item.addEventListener('click', async function(e) {
      e.preventDefault();
      try { await notifRpc('mark_notification_read', {p_id: n.id}); } catch(_) {}
      loadNotifCount();
      var dest = n.recipe_id ? 'recipe-page.html?id=' + n.recipe_id : null;
      if (dest) window.location.href = dest;
    });
    _notifPanel.appendChild(item);
  });
  var foot = document.createElement('div');
  foot.style.cssText = 'padding:8px 14px 12px;border-top:1px solid var(--border);text-align:center';
  foot.innerHTML = '<a href="notifications.html" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent);text-decoration:none;font-weight:600">View all notifications →</a>';
  _notifPanel.appendChild(foot);
  loadNotifCount();
}

async function markAllRead() {
  await notifRpc('mark_all_notifications_read',{});
  var badge = document.getElementById('nav-notif-badge');
  if (badge) badge.style.display = 'none';
  if (_notifPanel) renderNotifPanel([]);
  closeNotifPanel();
}

function closeNotifPanel() {
  if (_notifPanel) { _notifPanel.remove(); _notifPanel = null; }
  _notifOpen = false;
}

function outsideNotifClick(e) {
  var btn = document.getElementById('nav-notif-btn');
  if (_notifPanel && !_notifPanel.contains(e.target) && btn && !btn.contains(e.target)) {
    closeNotifPanel();
  }
}

// Notification RPCs now exist — polling enabled
setTimeout(function() { if(typeof loadNotifCount === "function") loadNotifCount(); }, 800);



// ══════════════════════════════════════════════════════
// FEEDBACK WIDGET — The Culinary Journal
// Floating ✉ button on all pages except: recipe-page, dashboard, login
// Submissions stored in Supabase feedback table.
// Betty reviews from Admin Panel → User Management → Feedback.
// ══════════════════════════════════════════════════════
(function initFeedbackWidget() {
  var path = window.location.pathname;
  if (path.includes('recipe-page') || path.includes('dashboard') || path.includes('login')) return;

      var style = document.createElement('style');
  style.textContent = [
    /* Floating button */
    '.tcj-fb-btn{position:fixed;bottom:24px;right:24px;z-index:8888;display:flex;align-items:center;gap:8px;padding:8px 16px;background:rgba(255,255,255,0.1);color:var(--text-mid,rgba(255,255,255,0.5));border:1px solid rgba(255,255,255,0.15);border-radius:50px;font-family:"DM Sans",sans-serif;font-size:12px;font-weight:500;cursor:pointer;box-shadow:0 2px 12px rgba(0,0,0,0.2);transition:all .2s;backdrop-filter:blur(6px)}',
    '.tcj-fb-btn:hover{background:var(--accent,#C4973B);color:#fff;border-color:transparent;opacity:1;transform:translateY(-2px);box-shadow:0 4px 16px rgba(0,0,0,0.3)}',
    /* Overlay + box */
    '.tcj-fb-ov{position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:9990;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px)}',
    '.tcj-fb-box{background:var(--bg,#0f1117);border:1px solid var(--border,rgba(255,255,255,.12));border-radius:14px;padding:28px 30px;width:92%;max-width:480px;font-family:"DM Sans",sans-serif}',
    '.tcj-fb-title{font-family:"Cormorant Garamond",serif;font-size:1.25rem;font-weight:700;color:var(--text-high,#fff);margin:0 0 6px}',
    '.tcj-fb-sub{font-size:13px;color:var(--text-mid,rgba(255,255,255,.5));margin:0 0 18px;line-height:1.6}',
    '.tcj-fb-lbl{display:block;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--text-mid,rgba(255,255,255,.5));margin-bottom:4px}',
    '.tcj-fb-req{color:#e05555;margin-left:2px}',
    /* Inputs */
    '.tcj-fb-inp,.tcj-fb-ta{width:100%;box-sizing:border-box;padding:9px 12px;background:rgba(255,255,255,.05);border:1px solid var(--border,rgba(255,255,255,.12));border-radius:8px;font-family:"DM Sans",sans-serif;font-size:13px;color:var(--text-high,#fff);outline:none;margin-bottom:14px;transition:border-color .2s}',
    '.tcj-fb-inp:focus,.tcj-fb-ta:focus{border-color:var(--accent,#C4973B)}',
    '.tcj-fb-ta{resize:vertical;min-height:100px}',
    /* Custom type dropdown */
    '.tcj-fb-dd-wrap{position:relative;margin-bottom:14px}',
    '.tcj-fb-dd-trigger{width:100%;box-sizing:border-box;padding:9px 12px;background:var(--bg,#0f1117);border:1px solid var(--border,rgba(255,255,255,.12));border-radius:8px;font-family:"DM Sans",sans-serif;font-size:13px;color:var(--text-high,#fff);cursor:pointer;display:flex;align-items:center;justify-content:space-between;transition:border-color .2s;user-select:none}',
    '.tcj-fb-dd-trigger:hover,.tcj-fb-dd-trigger.open{border-color:var(--accent,#C4973B)}',
    '.tcj-fb-dd-arrow{font-size:9px;color:var(--text-mid);transition:transform .2s}',
    '.tcj-fb-dd-trigger.open .tcj-fb-dd-arrow{transform:rotate(180deg)}',
    '.tcj-fb-dd-list{position:absolute;top:calc(100% + 2px);left:0;right:0;background:var(--bg,#0f1117);border:1px solid var(--accent,#C4973B);border-radius:8px;z-index:9999;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.5)}',
    '.tcj-fb-dd-opt{padding:9px 14px;font-family:"DM Sans",sans-serif;font-size:13px;color:var(--text-high,#fff);cursor:pointer;transition:background .12s}',
    '.tcj-fb-dd-opt:hover,.tcj-fb-dd-opt.active{background:var(--accent,#C4973B);color:#fff}',
    '.tcj-fb-2col{display:grid;grid-template-columns:1fr 1fr;gap:12px}',
    '.tcj-fb-btns{display:flex;gap:10px;margin-top:4px}',
    '.tcj-fb-send{flex:1;padding:11px;background:var(--accent,#C4973B);border:none;border-radius:8px;color:#fff;font-family:"DM Sans",sans-serif;font-size:13px;font-weight:600;cursor:pointer}',
    '.tcj-fb-cancel{padding:11px 18px;background:none;border:1px solid var(--border,rgba(255,255,255,.12));border-radius:8px;color:var(--text-mid,rgba(255,255,255,.5));font-family:"DM Sans",sans-serif;font-size:13px;cursor:pointer}',
    '.tcj-fb-msg{font-size:12px;text-align:center;min-height:16px;margin-top:10px}'
  ].join('');
  document.head.appendChild(style);

  /* Type options */
  var TYPE_OPTS = [
    { value:'general',    label:'General feedback'       },
    { value:'suggestion', label:'Suggestion or idea'     },
    { value:'bug',        label:'Something isn\u2019t working' },
    { value:'recipe',     label:'Recipe feedback'        },
    { value:'other',      label:'Other'                  }
  ];

  /* Floating button */
  var btn = document.createElement('button');
  btn.className = 'tcj-fb-btn';
  btn.innerHTML = '\u2709\ufe0e&ensp;Feedback';
  btn.title = 'Send feedback to The Culinary Journal';
  document.body.appendChild(btn);

  btn.addEventListener('click', function() {
    var prof = null, sess = null;
    try { prof = JSON.parse(localStorage.getItem('tcj_profile')||'null'); } catch(_){}
    try { sess = JSON.parse(localStorage.getItem('tcj_session')||'null'); } catch(_){}

    var selectedType = 'general';

    var ov = document.createElement('div');
    ov.className = 'tcj-fb-ov';

    var box = document.createElement('div');
    box.className = 'tcj-fb-box';

    /* Build custom type dropdown HTML */
    var ddOpts = TYPE_OPTS.map(function(o) {
      return '<div class="tcj-fb-dd-opt' + (o.value==='general'?' active':'') + '" data-value="' + o.value + '">' + o.label + '</div>';
    }).join('');

    box.innerHTML =
      '<div class="tcj-fb-title">Feedback to The Culinary Journal</div>' +
      '<p class="tcj-fb-sub">Got a suggestion, spotted something wrong, or just want to say hello? We read everything.</p>' +

      '<label class="tcj-fb-lbl">Type <span class="tcj-fb-req">*</span></label>' +
      '<div class="tcj-fb-dd-wrap">' +
        '<div class="tcj-fb-dd-trigger" id="tcj-dd-t">' +
          '<span id="tcj-dd-label">General feedback</span>' +
          '<span class="tcj-fb-dd-arrow">\u25be</span>' +
        '</div>' +
        '<div class="tcj-fb-dd-list" id="tcj-dd-list" style="display:none">' + ddOpts + '</div>' +
      '</div>' +

      '<label class="tcj-fb-lbl">Message <span class="tcj-fb-req">*</span></label>' +
      '<textarea class="tcj-fb-ta" id="tcj-m" placeholder="Tell us anything\u2026"></textarea>' +

      '<div class="tcj-fb-2col">' +
        '<div><label class="tcj-fb-lbl">Name <span class="tcj-fb-req">*</span></label>' +
        '<input class="tcj-fb-inp" id="tcj-n" type="text" placeholder="Your name"></div>' +
        '<div><label class="tcj-fb-lbl">Email <span class="tcj-fb-req">*</span></label>' +
        '<input class="tcj-fb-inp" id="tcj-e" type="email" placeholder="your@email.com"></div>' +
      '</div>' +

      '<div class="tcj-fb-btns">' +
        '<button class="tcj-fb-cancel" id="tcj-c">Cancel</button>' +
        '<button class="tcj-fb-send"   id="tcj-s">Send Feedback</button>' +
      '</div>' +
      '<div class="tcj-fb-msg" id="tcj-msg"></div>';

    ov.appendChild(box);
    document.body.appendChild(ov);

    /* Pre-fill if logged in */
    if (prof) {
      if (prof.full_name) box.querySelector('#tcj-n').value = prof.full_name;
      if (prof.email)     box.querySelector('#tcj-e').value = prof.email;
    }

    /* Custom dropdown logic */
    var ddTrigger = box.querySelector('#tcj-dd-t');
    var ddList    = box.querySelector('#tcj-dd-list');
    var ddLabel   = box.querySelector('#tcj-dd-label');

    ddTrigger.addEventListener('click', function(e) {
      e.stopPropagation();
      var open = ddList.style.display !== 'none';
      ddList.style.display = open ? 'none' : 'block';
      ddTrigger.classList.toggle('open', !open);
    });

    ddList.querySelectorAll('.tcj-fb-dd-opt').forEach(function(opt) {
      opt.addEventListener('click', function() {
        selectedType = opt.dataset.value;
        ddLabel.textContent = opt.textContent;
        ddList.querySelectorAll('.tcj-fb-dd-opt').forEach(function(o){ o.classList.remove('active'); });
        opt.classList.add('active');
        ddList.style.display = 'none';
        ddTrigger.classList.remove('open');
      });
    });

    document.addEventListener('click', function closeDD(e) {
      if (!ddTrigger.contains(e.target) && !ddList.contains(e.target)) {
        ddList.style.display = 'none';
        ddTrigger.classList.remove('open');
        document.removeEventListener('click', closeDD);
      }
    });

    /* Cancel */
    box.querySelector('#tcj-c').addEventListener('click', function(){ ov.remove(); });
    ov.addEventListener('click', function(e){ if(e.target===ov) ov.remove(); });

    /* Send */
    box.querySelector('#tcj-s').addEventListener('click', function() {
      var msg   = (box.querySelector('#tcj-m').value||'').trim();
      var name  = (box.querySelector('#tcj-n').value||'').trim();
      var email = (box.querySelector('#tcj-e').value||'').trim();
      var msgEl =  box.querySelector('#tcj-msg');
      var sendBtn= box.querySelector('#tcj-s');

      /* Validate all required fields */
      if (!msg) {
        msgEl.style.color='#e05555';
        msgEl.textContent='Please write a message.';
        box.querySelector('#tcj-m').focus();
        return;
      }
      if (!name) {
        msgEl.style.color='#e05555';
        msgEl.textContent='Please enter your name.';
        box.querySelector('#tcj-n').focus();
        return;
      }
      if (!email || !email.includes('@')) {
        msgEl.style.color='#e05555';
        msgEl.textContent='Please enter a valid email address.';
        box.querySelector('#tcj-e').focus();
        return;
      }

      sendBtn.disabled = true;
      sendBtn.textContent = 'Sending\u2026';
      msgEl.textContent = '';

      var authHeader = (sess&&sess.access_token) ? 'Bearer '+sess.access_token : 'Bearer '+SUPA_KEY;
      fetch(SUPA_URL+'/rest/v1/feedback', {
        method:'POST',
        headers:{
          'apikey':SUPA_KEY,
          'Authorization':authHeader,
          'Content-Type':'application/json',
          'Prefer':'return=minimal'
        },
        body: JSON.stringify({
          type:     selectedType,
          feedback: msg,
          name:     name,
          email:    email,
          username: prof ? (prof.username||null) : null,
          user_id:  (sess&&sess.user) ? sess.user.id : null,
          status:   'new'
        })
      })
      .then(function(res){
        if(res.ok||res.status===201){
          msgEl.style.color='#4caf76';
          msgEl.textContent='\u2713 Thank you! We\u2019ll read your message.';
          sendBtn.textContent='\u2713 Sent';
          setTimeout(function(){ ov.remove(); }, 2000);
        } else { throw new Error('Error '+res.status); }
      })
      .catch(function(){
        msgEl.style.color='#e05555';
        msgEl.textContent='Couldn\u2019t send right now. Please try again.';
        sendBtn.disabled=false;
        sendBtn.textContent='Send Feedback';
      });
    });
  });
})();


/* ══════════════════════════════════════════════════════
   SESSION KEEP-ALIVE (CJ-003/004 root cause, CJ-022)
   Supabase access tokens expire (~1h). Only profile.html
   refreshed them; every other page failed silently after
   expiry. This shared keep-alive refreshes the stored
   token before it lapses, so the per-page helpers — which
   all read tcj_session from localStorage on every call —
   always find a fresh token. Modelled on profile.html's
   proven refreshSession().
══════════════════════════════════════════════════════ */
(function () {
  function tcjGetSession() {
    try { return JSON.parse(localStorage.getItem('tcj_session') || 'null'); }
    catch (_) { return null; }
  }
  function tcjJwtExp(token) {
    try {
      var p = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      return (JSON.parse(atob(p)).exp || 0) * 1000;
    } catch (_) { return 0; }
  }
  async function tcjRefreshSession() {
    // SUPA_URL / SUPA_KEY are page globals; static pages don't define them.
    if (typeof SUPA_URL === 'undefined' || typeof SUPA_KEY === 'undefined') return false;
    var s = tcjGetSession();
    if (!s || !s.refresh_token) return false;
    try {
      var res = await fetch(SUPA_URL + '/auth/v1/token?grant_type=refresh_token', {
        method:  'POST',
        headers: { 'apikey': SUPA_KEY, 'Content-Type': 'application/json' },
        body:    JSON.stringify({ refresh_token: s.refresh_token })
      });
      if (!res.ok) return false;
      var data = await res.json();
      if (!data.access_token) return false;
      var updated = Object.assign({}, s, {
        access_token:  data.access_token,
        refresh_token: data.refresh_token || s.refresh_token
      });
      localStorage.setItem('tcj_session', JSON.stringify(updated));
      return true;
    } catch (_) { return false; }
  }
  async function tcjKeepAlive() {
    var s = tcjGetSession();
    if (!s || !s.access_token) return;
    var msLeft = tcjJwtExp(s.access_token) - Date.now();
    if (msLeft < 10 * 60 * 1000) await tcjRefreshSession();   // refresh when <10 min remain (or already expired)
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', tcjKeepAlive);
  } else { tcjKeepAlive(); }
  setInterval(tcjKeepAlive, 5 * 60 * 1000);                    // re-check every 5 minutes
  window.tcjRefreshSession = tcjRefreshSession;                // available to pages that want an on-demand refresh
})();
