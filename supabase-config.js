// ══════════════════════════════════════════════════════════════════════
// supabase-config.js — The Culinary Journal
// Single source of truth for Supabase connection.
// Include this before any page script that calls Supabase.
// Usage: window.SUPA_URL, window.SUPA_KEY, window.supaFetch(), window.rpc()
// ══════════════════════════════════════════════════════════════════════

(function () {
  if (typeof window.TcjErr === 'undefined') {
    window.TcjErr = {
      warn: function (ctx, err) { console.warn('[TCJ:' + ctx + ']', err); },
      ignore: function () {},
      lsGet: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
      lsSet: function (k, v) { try { localStorage.setItem(k, v); return true; } catch (e) { return false; } },
      lsRemove: function (k) { try { localStorage.removeItem(k); return true; } catch (e) { return false; } },
      parseJson: function (r, f) { try { return JSON.parse(r); } catch (e) { return f; } },
      rpcFallback: function (ctx, err, fb) { console.warn('[TCJ:' + ctx + ']', err); return fb; },
      toast: function (m) { console.warn('[TCJ:toast]', m); },
      bannerOnce: function (id, m) { console.warn('[TCJ:' + id + ']', m); },
      sectionError: function (id, m) { console.warn('[TCJ:' + id + ']', m); }
    };
  }
})();

(function() {
  var URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';

  // Expose globally
  window.SUPA_URL      = URL;
  window.SUPA_KEY      = KEY;
  window.SUPABASE_URL  = URL;  // alias used by some pages
  window.SUPABASE_KEY  = KEY;  // alias used by some pages

  // ── Session helpers ──────────────────────────────────────────────────
  window.getSession = function() {
    try { return JSON.parse(localStorage.getItem('tcj_session') || 'null'); }
    catch (_) { TcjErr.warn('getSession', _); return null; }
  };

  window.getAuthHeaders = function() {
    var sess = window.getSession();
    var h = { 'apikey': KEY, 'Content-Type': 'application/json' };
    if (sess && sess.access_token) h['Authorization'] = 'Bearer ' + sess.access_token;
    return h;
  };

  // ── REST fetch wrapper ───────────────────────────────────────────────
  window.supaFetch = function(path, options) {
    var opts = options || {};
    opts.headers = Object.assign({}, window.getAuthHeaders(), opts.headers || {});
    return fetch(URL + path, opts);
  };

  // ── RPC wrapper ──────────────────────────────────────────────────────
  window.rpc = async function(fnName, params) {
    var res = await fetch(URL + '/rest/v1/rpc/' + fnName, {
      method:  'POST',
      headers: window.getAuthHeaders(),
      body:    JSON.stringify(params || {})
    });
    if (!res.ok) {
      var err = await res.text().catch(function(e){ TcjErr.warn('supabase-config.js', e); });
      throw new Error(err);
    }
    var text = await res.text();
    return text ? JSON.parse(text) : null;
  };

  // ── Profile / avatar cache helpers ───────────────────────────────────
  var ADMIN_EMAIL = 'miseenplacekitchen.official@gmail.com';

  window.TCJ_ADMIN_EMAIL = ADMIN_EMAIL;

  window.sessionEmail = function(session) {
    if (session && session.user && session.user.email) return session.user.email;
    try {
      var token = session && session.access_token;
      if (!token) return '';
      var payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
      return payload.email || '';
    } catch (_) { TcjErr.warn('supabase-config.js:65', _); }
  };

  window.isTcjAdmin = function(profile, session) {
    if (profile && profile.is_admin === true) return true;
    var admin = ADMIN_EMAIL.toLowerCase();
    var emails = [];
    if (profile && profile.email) emails.push(String(profile.email).toLowerCase());
    var se = window.sessionEmail(session);
    if (se) emails.push(String(se).toLowerCase());
    return emails.some(function(e) { return e === admin; });
  };

  window.normalizeTcjProfile = function(profile, session) {
    profile = profile || {};
    session = session || window.getSession();
    if (!profile.email && window.sessionEmail(session)) profile.email = window.sessionEmail(session);
    if (profile.is_admin !== true && window.isTcjAdmin(profile, session)) profile.is_admin = true;
    return profile;
  };

  window.saveTcjProfile = function(profile, session) {
    profile = window.normalizeTcjProfile(profile, session);
    try { localStorage.setItem('tcj_profile', JSON.stringify(profile)); } catch(_) { TcjErr.ignore(_); }
    try {
      window.dispatchEvent(new CustomEvent('tcj-profile-updated', { detail: profile }));
    } catch(_) { TcjErr.warn('supabase-config.js', _); }
    return profile;
  };

  window.fetchTcjIsAdmin = async function(session) {
    session = session || window.getSession();
    if (!session || !session.access_token) return null;
    try {
      var res = await fetch(URL + '/rest/v1/rpc/is_admin', {
        method: 'POST',
        headers: {
          apikey: KEY,
          Authorization: 'Bearer ' + session.access_token,
          'Content-Type': 'application/json'
        },
        body: '{}'
      });
      if (!res.ok) return null;
      return (await res.json()) === true;
    } catch (_) { TcjErr.warn('supabase-config.js:110', _); }
  };

  var ANN_TYPE_STYLES = {
    info:    { accent: '#5B8FD4', bg: 'rgba(91,143,212,0.12)',  border: 'rgba(91,143,212,0.35)' },
    success: { accent: '#4caf76', bg: 'rgba(76,175,118,0.12)',  border: 'rgba(76,175,118,0.35)' },
    warning: { accent: '#d4a017', bg: 'rgba(212,160,23,0.12)',  border: 'rgba(212,160,23,0.35)' },
    error:   { accent: '#dc5050', bg: 'rgba(220,80,80,0.12)',   border: 'rgba(220,80,80,0.35)' }
  };

  window.loadTcjAnnouncements = function() {
    if (window.__tcjAnnLoading) return;
    window.__tcjAnnLoading = true;

    var headers = { apikey: KEY, Accept: 'application/json' };
    var sess = window.getSession();
    if (sess && sess.access_token) headers.Authorization = 'Bearer ' + sess.access_token;

    fetch(
      URL + '/rest/v1/site_announcements?active=eq.true&select=id,text,type,link_url,link_label,expires_at&order=created_at.desc',
      { headers: headers }
    )
      .then(function(res) { return res.ok ? res.json() : []; })
      .then(function(rows) {
        window.__tcjAnnLoading = false;
        if (!Array.isArray(rows) || !rows.length) return;

        var now = Date.now();
        var dismissed = [];
        try { dismissed = JSON.parse(localStorage.getItem('tcj_ann_dismissed') || '[]'); } catch(_) { TcjErr.ignore(_); }

        var live = rows.filter(function(a) {
          if (!a || !a.text) return false;
          if (dismissed.indexOf(a.id) !== -1) return false;
          if (a.expires_at && new Date(a.expires_at).getTime() < now) return false;
          return true;
        });
        if (!live.length) return;

        var existing = document.getElementById('tcj-ann-wrap');
        if (existing) existing.remove();

        var wrap = document.createElement('div');
        wrap.id = 'tcj-ann-wrap';
        wrap.setAttribute('role', 'region');
        wrap.setAttribute('aria-label', 'Site announcements');

        live.forEach(function(a) {
          var style = ANN_TYPE_STYLES[a.type] || ANN_TYPE_STYLES.info;
          var bar = document.createElement('div');
          bar.className = 'tcj-ann-bar';
          bar.style.cssText =
            'display:flex;align-items:center;gap:12px;padding:10px 20px;' +
            'background:' + style.bg + ';border-bottom:1px solid ' + style.border + ';' +
            'font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high);';

          var label = document.createElement('span');
          label.style.cssText = 'font-size:10px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:' + style.accent + ';flex-shrink:0';
          label.textContent = (a.type || 'info').toUpperCase();

          var text = document.createElement('span');
          text.style.cssText = 'flex:1;line-height:1.45';
          text.textContent = a.text;

          if (a.link_url) {
            var link = document.createElement('a');
            link.href = a.link_url;
            link.textContent = a.link_label || 'Learn more';
            link.style.cssText = 'margin-left:8px;color:' + style.accent + ';font-weight:600;text-decoration:none';
            text.appendChild(document.createTextNode(' '));
            text.appendChild(link);
          }

          var close = document.createElement('button');
          close.type = 'button';
          close.setAttribute('aria-label', 'Dismiss announcement');
          close.textContent = '\u00d7';
          close.style.cssText = 'background:none;border:none;color:var(--text-mid);font-size:20px;line-height:1;cursor:pointer;padding:0 4px;flex-shrink:0';
          close.addEventListener('click', function() {
            bar.remove();
            try {
              var d = JSON.parse(localStorage.getItem('tcj_ann_dismissed') || '[]');
              if (d.indexOf(a.id) === -1) d.push(a.id);
              localStorage.setItem('tcj_ann_dismissed', JSON.stringify(d));
            } catch (_) { TcjErr.warn('degrade', _); }
            if (!wrap.querySelector('.tcj-ann-bar')) wrap.remove();
          });

          bar.appendChild(label);
          bar.appendChild(text);
          bar.appendChild(close);
          wrap.appendChild(bar);
        });

        var nav = document.querySelector('.nav');
        var apMain = document.getElementById('screen-main') || document.querySelector('.ap-wrap');
        if (nav && nav.parentNode) {
          nav.parentNode.insertBefore(wrap, nav.nextSibling);
        } else if (apMain) {
          apMain.insertBefore(wrap, apMain.firstChild);
        } else {
          document.body.insertBefore(wrap, document.body.firstChild);
        }
      })
      .catch(function(e){ TcjErr.warn('supabase-config.js', e); });
  };

  window.purgeStaleProfileCache = function() {
    try {
      var s = window.getSession();
      var p = JSON.parse(localStorage.getItem('tcj_profile') || 'null');
      if (!s || !s.user_id) {
        localStorage.removeItem('tcj_profile');
        return;
      }
      if (p && p.id && p.id !== s.user_id) {
        localStorage.removeItem('tcj_profile');
      }
    } catch (_) {
      try { localStorage.removeItem('tcj_profile'); } catch(e) { TcjErr.ignore(e); }
    }
  };

  window.avatarCacheKey = function(userId) {
    var uid = userId || (window.getSession() && window.getSession().user_id) || '';
    return 'tcj_avatar_v_' + uid;
  };

  window.bumpAvatarCache = function(userId) {
    var uid = userId || (window.getSession() && window.getSession().user_id) || '';
    if (uid) localStorage.setItem(window.avatarCacheKey(uid), String(Date.now()));
  };

  window.avatarBust = function(url, userId, serverStamp) {
    if (!url || url.indexOf('data:') === 0) return url;
    var sep = url.indexOf('?') >= 0 ? '&' : '?';
    var uid = userId || (window.getSession() && window.getSession().user_id) || '';
    var v = serverStamp
      ? String(new Date(serverStamp).getTime())
      : (localStorage.getItem(window.avatarCacheKey(uid)) || String(Date.now()));
    return url + sep + 'v=' + v;
  };

  window.enrichProfile = async function(profile, session) {
    profile = profile || {};
    session = session || window.getSession();
    if (!session || !session.access_token) return profile;
    if (profile.avatar_url) return profile;
    try {
      var uid = profile.id || session.user_id;
      if (!uid) return profile;
      var res = await fetch(
        URL + '/rest/v1/profiles?id=eq.' + encodeURIComponent(uid) + '&select=avatar_url,last_seen',
        { headers: { apikey: KEY, Authorization: 'Bearer ' + session.access_token } }
      );
      if (res.ok) {
        var rows = await res.json();
        if (rows[0]) {
          if (rows[0].avatar_url) profile.avatar_url = rows[0].avatar_url;
          if (rows[0].last_seen) profile.last_seen = rows[0].last_seen;
        }
      }
    } catch(_) { TcjErr.warn('supabase-config.js', _); }
    return profile;
  };

  window.purgeStaleProfileCache();
})();
