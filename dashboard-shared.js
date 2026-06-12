// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first


// SUPABASE_URL and SUPABASE_KEY are provided by supabase-config.js
let session = null;

function showSessionExpired() {
  var existing = document.getElementById('session-expired-banner');
  if (existing) return;
  var banner = document.createElement('div');
  banner.id = 'session-expired-banner';
  banner.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.85);z-index:99999;display:flex;align-items:center;justify-content:center';
  banner.innerHTML = '<div style="background:var(--bg);border:1px solid #dc5050;border-radius:16px;padding:40px 48px;text-align:center;max-width:440px"><div style="font-family:Cormorant Garamond,serif;font-size:1.5rem;font-weight:700;color:var(--text-high);margin-bottom:12px">Session Expired</div><div style="font-family:DM Sans,sans-serif;font-size:14px;color:var(--text-mid);margin-bottom:24px">Your login session has timed out. Please sign in again to continue.</div><button onclick="signOut()" style="padding:12px 32px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:14px;font-weight:600;cursor:pointer">Sign In Again</button></div>';
  document.body.appendChild(banner);
}

async function rpc(fn, params) {
  async function attempt(token) {
    const res = await fetch(SUPABASE_URL + '/rest/v1/rpc/' + fn, {
      method: 'POST',
      headers: { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify(params || {})
    });
    return res;
  }
  var res = await attempt(session.access_token);
  if (res.status === 401) {
    var refreshed = false;
    try { refreshed = await tryRefreshToken(); } catch(e) { console.warn('apiFetch token refresh', e); }
    if (refreshed) {
      res = await attempt(session.access_token);
    } else {
      showSessionExpired();
      throw new Error('Session expired. Please sign in again.');
    }
  }
  if (!res.ok) { const t = await res.text(); throw new Error(res.status + ': ' + t); }
  const t = await res.text();
  return t ? JSON.parse(t) : null;
}
window.tcjAdminRpc = rpc;

async function apiFetch(url, opts) {
  opts = opts || {};
  opts.headers = Object.assign({}, { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + session.access_token, 'Accept': 'application/json' }, opts.headers || {});
  var res = await fetch(url, opts);
  if (res.status === 401) {
    var refreshed = false;
    try { refreshed = await tryRefreshToken(); } catch(e) { console.warn('apiFetch token refresh', e); }
    if (refreshed) {
      opts.headers['Authorization'] = 'Bearer ' + session.access_token;
      res = await fetch(url, opts);
    } else {
      showSessionExpired();
      return null;
    }
  }
  return res;
}

// Shared fetch wrapper for direct table queries — handles 401 same as rpc()

async function tryRefreshToken() {
  try {
    const raw = localStorage.getItem('tcj_session');
    if (!raw) return false;
    const s = JSON.parse(raw);
    if (!s.refresh_token) return false;
    const res = await fetch(SUPABASE_URL + '/auth/v1/token?grant_type=refresh_token', {
      method: 'POST', headers: { 'apikey': SUPABASE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: s.refresh_token })
    });
    if (!res.ok) return false;
    const data = await res.json();
    if (!data.access_token) return false;
    const updated = Object.assign({}, s, { access_token: data.access_token, refresh_token: data.refresh_token || s.refresh_token });
    localStorage.setItem('tcj_session', JSON.stringify(updated));
    session = updated; return true;
  } catch(e) { return false; }
}

async function loadDashboard() {
  // ── Recipe + user + finance stats ────────────────────────
  try {
    var results = await Promise.all([
      rpc('admin_get_stats', {}),
      rpc('admin_count_users', {}),
      rpc('admin_count_ingredients', {}),
      rpc('admin_get_tier_stats', {}).catch(function(){ return null; })
    ]);
    var stats = results[0]; var userCount = results[1];
    var ingCount = results[2]; var tierStats = results[3];
    if (stats) {
      setEl('dash-total-recipes', (stats.total||0).toLocaleString());
      setEl('dash-pending',       stats.pending  || 0);
      setEl('dash-approved',      stats.approved || 0);
      setEl('dash-featured',      stats.featured || 0);
      setEl('badge-pending',      stats.pending  || 0);
      var tot = parseInt(stats.total)||0, appr = parseInt(stats.approved)||0;
      setEl('dash-approval-rate', tot>0 ? Math.round(appr/tot*100)+'%' : '—');
    }
    setEl('dash-users',       (parseInt(userCount)||0).toLocaleString());
    setEl('dash-ingredients', (parseInt(ingCount)||0).toLocaleString());
    if (tierStats) {
      setEl('dash-premium', (tierStats.premium||0).toLocaleString());
      setEl('dash-event',   (tierStats.event||0).toLocaleString());
      apiFetch(SUPABASE_URL+'/rest/v1/site_settings?select=key,value&key=in.(price_premium_monthly,price_event_monthly,currency_symbol)')
        .then(function(r){ return r&&r.ok?r.json():null; })
        .then(function(rows){
          if(!Array.isArray(rows)) return;
          var S={}; rows.forEach(function(r){ S[r.key]=r.value; });
          var mrr = (parseFloat(S.price_premium_monthly||'4')*(tierStats.premium||0)) +
                    (parseFloat(S.price_event_monthly||'12')*(tierStats.event||0));
          setEl('dash-mrr', (S.currency_symbol||'$')+mrr.toFixed(2));
        }).catch(function(e){ console.warn('dash stats badge', e); });
    }
  } catch(e) {
    console.warn('dash stats', e);
    var errEl = document.getElementById('dash-stats-error');
    if (!errEl) {
      errEl = document.createElement('div');
      errEl.id = 'dash-stats-error';
      errEl.style.cssText = 'margin:0 0 16px;padding:12px 16px;background:var(--danger-bg);border:1px solid rgb(from var(--danger) r g b / 0.35);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--danger)';
      var dash = document.getElementById('v-dashboard');
      if (dash && dash.firstChild) dash.insertBefore(errEl, dash.firstChild);
      else if (dash) dash.appendChild(errEl);
    }
    errEl.textContent = 'Dashboard stats could not load — ' + (e.message || 'check admin RPCs in Supabase').replace(/^\d+:\s*/, '');
  }

  // ── Recent Submissions ───────────────────────────────────
  try {
    var recipes = await rpc('admin_get_recipes', {p_status:null,p_search:null,p_category:null,p_limit:8,p_offset:0});
    var rEl = document.getElementById('dash-recent-recipes');
    if (rEl) {
      var list = Array.isArray(recipes) ? recipes : [];
      if (list.length) {
        rEl.innerHTML = list.map(function(r) {
          var sc = r.status==='pending'?'#d4a017':r.status==='approved'?'#4caf76':'#dc5050';
          return '<div style="display:flex;align-items:center;justify-content:space-between;padding:9px 18px;border-bottom:1px solid rgba(255,255,255,0.04);cursor:pointer" onclick="openRecipeModal('+r.id+')">' +
            '<div><div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)">'+esc(r.recipe_name)+'</div>' +
            '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">@'+esc(r.username||'')+(r.category?' · '+esc(r.category):'')+'</div></div>' +
            '<span style="font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;color:'+sc+';text-transform:uppercase;padding:2px 8px;border-radius:10px;background:rgba(0,0,0,0.2)">'+esc(r.status)+'</span></div>';
        }).join('');
      } else {
        rEl.innerHTML = '<div style="padding:20px 18px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);text-align:center">No submissions yet</div>';
      }
    }
  } catch(e) { console.warn('dash recipes', e); }

  // ── Recent Members ───────────────────────────────────────
  try {
    var users = await rpc('admin_get_users', {p_search:null,p_status:null,p_limit:6,p_offset:0});
    var uEl = document.getElementById('dash-recent-users');
    if (uEl) {
      var uList = Array.isArray(users) ? users : [];
      if (uList.length) {
        uEl.innerHTML = uList.map(function(u) {
          var ini = (u.full_name||u.username||'?').split(' ').map(function(w){return w[0]||'';}).join('').toUpperCase().slice(0,2);
          var avHtml = u.avatar_url
            ? '<img src="'+esc(typeof avatarBust==='function'?avatarBust(u.avatar_url,u.id,u.last_seen):u.avatar_url)+'" style="width:32px;height:32px;border-radius:50%;object-fit:cover;flex-shrink:0" alt="">'
            : '<div style="width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,var(--accent),#8a6a28);display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;color:#fff;flex-shrink:0">'+ini+'</div>';
          var joined = u.created_at ? new Date(u.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : '';
          var tierBadge = u.subscription_tier && u.subscription_tier !== 'free'
            ? '<span style="font-size:9px;padding:1px 6px;border-radius:8px;background:rgba(196,151,59,0.2);color:var(--accent);font-weight:700;margin-left:5px">'+u.subscription_tier.toUpperCase()+'</span>' : '';
          return '<div style="display:flex;align-items:center;gap:10px;padding:9px 18px;border-bottom:1px solid rgba(255,255,255,0.04)">' +
            avHtml +
            '<div style="flex:1"><div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high);display:flex;align-items:center">'+esc(u.full_name||u.username)+tierBadge+'</div>' +
            '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">Joined '+joined+'</div></div></div>';
        }).join('');
      } else {
        uEl.innerHTML = '<div style="padding:20px 18px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);text-align:center">No members yet</div>';
      }
    }
  } catch(e) { console.warn('dash users', e); }

  // ── Recipe of the Week ───────────────────────────────────
  try {
    var allRecs = [];
    if (typeof TcjAdminRecipes !== 'undefined') {
      allRecs = await TcjAdminRecipes.fetchAll({p_status:'approved',p_search:null,p_category:null});
    } else {
      allRecs = await rpc('admin_get_recipes', {p_status:'approved',p_search:null,p_category:null,p_limit:500,p_offset:0});
    }
    var rotw = Array.isArray(allRecs) ? allRecs.find(function(r){ return r.recipe_of_week; }) : null;
    var rotwEl = document.getElementById('dash-rotw');
    if (rotwEl) {
      if (rotw) {
        var exp = rotw.recipe_of_week_expires ? new Date(rotw.recipe_of_week_expires) : null;
        var expStr = exp ? exp.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : null;
        var daysLeft = exp ? Math.max(0, Math.ceil((exp - Date.now()) / 86400000)) : null;
        var urg = daysLeft !== null && daysLeft <= 1 ? '#dc5050' : daysLeft !== null && daysLeft <= 2 ? '#d4a017' : '#5B8FD4';
        rotwEl.innerHTML =
          '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;color:var(--text-high);margin-bottom:4px">'+esc(rotw.recipe_name)+'</div>'+
          '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:10px">'+esc(rotw.category||'')+(rotw.username?' · @'+esc(rotw.username):'')+'</div>'+
          (expStr?'<div style="font-family:DM Sans,sans-serif;font-size:11px;font-weight:600;color:'+urg+'">'+(daysLeft!==null?daysLeft+' day'+(daysLeft===1?'':'s')+' remaining · ':'')+' Expires '+expStr+'</div>':'')+
          '<button onclick="openRecipeModal('+rotw.id+')" style="margin-top:10px;padding:5px 14px;background:none;border:1px solid rgba(91,143,212,0.5);border-radius:6px;color:#5B8FD4;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer">View Recipe</button>';
      } else {
        rotwEl.innerHTML =
          '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);margin-bottom:12px">No Recipe of the Week is currently set.</div>'+
          '<button onclick="switchView(&quot;recipe-mgmt&quot;);switchRecipeTab(&quot;rotw&quot;)" style="padding:7px 16px;background:rgba(91,143,212,0.1);border:1px solid rgba(91,143,212,0.3);border-radius:7px;color:#5B8FD4;font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer">Choose from Approved Recipes &#8594;</button>';
      }
    }
  } catch(e) { console.warn('dash rotw', e); }

  // ── Admin Inbox ─────────────────────────────────────────
  try {
    var attEl = document.getElementById('dash-attention');
    if (attEl) {
      function asList(v) {
        if (Array.isArray(v)) return v;
        if (v && typeof v === 'object') return Object.values(v);
        return [];
      }
      var pending = parseInt((document.getElementById('dash-pending')||{}).textContent)||0;
      var inbox = await Promise.all([
        rpc('admin_get_appeals', {}).catch(function(){ return []; }),
        (typeof TcjAdminReports !== 'undefined'
          ? TcjAdminReports.fetchAll({ p_status: 'pending' })
          : rpc('admin_get_reports', { p_status: 'pending', p_limit: 200, p_offset: 0 })
        ).catch(function(){ return []; }),
        rpc('admin_get_pending_notes', {}).catch(function(){ return []; }),
        rpc('admin_get_pending_ingredients', {}).catch(function(){ return []; }),
        rpc('admin_get_library_submissions', {p_status:'pending', p_limit:50}).catch(function(){ return []; }),
        rpc('admin_count_pending_users', {}).catch(function(){ return 0; }),
        rpc('admin_get_audit_log', {p_limit:5, p_offset:0}).catch(function(){ return []; })
      ]);
      var appealCount = asList(inbox[0]).filter(function(a){ return a.status === 'pending'; }).length;
      var reportCount = asList(inbox[1]).length;
      var noteCount = asList(inbox[2]).length;
      var ingCount = asList(inbox[3]).length;
      var libSubCount = asList(inbox[4]).length;
      var pendingUsers = parseInt(inbox[5]) || 0;
      var auditRows = asList(inbox[6]);
      setEl('rtab-badge-notes', noteCount);
      setEl('badge-pending-users', pendingUsers);
      var items = [];
      if (pending > 0)
        items.push({icon:'&#9203;',color:'#d4a017',text:pending+' recipe'+(pending===1?'':'s')+' pending review',action:"switchView('recipe-mgmt');switchRecipeTab('pending')",label:'Review'});
      if (noteCount > 0)
        items.push({icon:'&#128221;',color:'#d4a017',text:noteCount+' cooking tip'+(noteCount===1?'':'s')+' awaiting approval',action:"switchView('recipe-mgmt');switchRecipeTab('notes')",label:'Review'});
      if (ingCount > 0)
        items.push({icon:'&#127807;',color:'#4caf76',text:ingCount+' ingredient submission'+(ingCount===1?'':'s')+' to review',action:"switchView('ingredients');switchIngTab('pending')",label:'Review'});
      if (libSubCount > 0)
        items.push({icon:'&#128218;',color:'#5B8FD4',text:libSubCount+' library profile submission'+(libSubCount===1?'':'s')+' to review',action:"switchView('library-mgmt')",label:'Review'});
      if (appealCount > 0)
        items.push({icon:'&#128231;',color:'#5B8FD4',text:appealCount+' deactivation appeal'+(appealCount===1?'':'s')+' waiting',action:"switchView('user-mgmt');switchUserTab('reports')",label:'View'});
      if (reportCount > 0)
        items.push({icon:'&#9888;',color:'#dc5050',text:reportCount+' member report'+(reportCount===1?'':'s')+' open',action:"switchView('user-mgmt');switchUserTab('reports')",label:'View'});
      if (pendingUsers > 0)
        items.push({icon:'&#128100;',color:'#d4a017',text:pendingUsers+' new member'+(pendingUsers===1?'':'s')+' awaiting approval',action:"switchView('user-mgmt');switchUserTab('pending')",label:'Review'});
      var rotwSet = !!(document.getElementById('dash-rotw')||{}).querySelector && document.getElementById('dash-rotw').querySelector('button[onclick*="openRecipeModal"]');
      if (!rotwSet)
        items.push({icon:'&#127942;',color:'#5B8FD4',text:'Recipe of the Week is not set',action:"switchView('recipe-mgmt');switchRecipeTab('rotw')",label:'Set Now'});
      if (!items.length)
        items.push({icon:'&#10003;',color:'#4caf76',text:'Inbox clear — no pending actions.',action:null,label:null});
      var html = items.map(function(item){
        return '<div style="display:flex;align-items:center;justify-content:space-between;padding:10px 18px;border-bottom:1px solid rgba(255,255,255,0.04)">' +
          '<div style="display:flex;align-items:center;gap:10px"><span style="font-size:14px">'+item.icon+'</span>' +
          '<span style="font-family:DM Sans,sans-serif;font-size:13px;color:'+item.color+'">'+item.text+'</span></div>'+
          (item.action?'<button onclick="'+item.action+'" style="padding:4px 12px;background:none;border:1px solid '+item.color+';border-radius:6px;color:'+item.color+';font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer;flex-shrink:0">'+item.label+'</button>':'')+
          '</div>';
      }).join('');
      if (auditRows.length) {
        html += '<div style="padding:10px 18px 4px;font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid)">Recent activity</div>';
        html += auditRows.slice(0,4).map(function(row){
          var when = row.created_at ? new Date(row.created_at).toLocaleString('en-GB',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}) : '';
          return '<div style="padding:6px 18px 6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);border-bottom:1px solid rgba(255,255,255,0.03)">' +
            esc(row.action || row.event_type || 'Action') + (row.target ? ' · ' + esc(row.target) : '') +
            '<span style="float:right;opacity:0.7">'+esc(when)+'</span></div>';
        }).join('');
      }
      attEl.innerHTML = html;
    }
  } catch(e) { console.warn('dash inbox', e); }

  try {
    var healthEl = document.getElementById('dash-system-health');
    if (healthEl && typeof loadDataIntegrityPanel === 'function') {
      loadDataIntegrityPanel(healthEl);
    }
  } catch(e) { console.warn('dash system health', e); }
}

async function init() {
  if (typeof purgeStaleProfileCache === 'function') purgeStaleProfileCache();
  if (location.protocol === 'file:') {
    document.body.innerHTML = '<div style="font-family:DM Sans,sans-serif;padding:40px;text-align:center;color:#fff;background:#0f1011;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px"><div style="font-family:Cormorant Garamond,serif;font-size:1.5rem">Admin Panel</div><p style="max-width:420px;color:#aaa;line-height:1.6">This page must be served over HTTP — not opened as a local file. Visit <a href="https://www.theculinaryjournal.site/dashboard.html" style="color:#C4973B">theculinaryjournal.site/dashboard.html</a> or run a local server in this folder.</p></div>';
    return;
  }
  try {
    var sess = null;
    try { sess = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch(e) { console.warn('dash session parse', e); }
    if (!sess || !sess.access_token) {
      window.location.href = 'login.html';
      return;
    }
    session = sess;
    // Try to refresh token silently — don't block if it fails
    try { await tryRefreshToken(); } catch(e) { console.warn('init token refresh', e); }
    var isAdmin = false;
    var adminName = 'miseenplacekitchen';
    try {
      // Always verify admin status server-side — never trust localStorage alone
      var rows = await rpc('get_my_profile', {});
      var pr = Array.isArray(rows) ? rows[0] : rows;
      if (pr) {
        if (typeof enrichProfile === 'function') pr = await enrichProfile(pr, sess);
        if (typeof fetchTcjIsAdmin === 'function') {
          var rpcAdmin = await fetchTcjIsAdmin(sess);
          if (rpcAdmin === true) pr.is_admin = true;
        }
        if (typeof normalizeTcjProfile === 'function') pr = normalizeTcjProfile(pr, sess);
        isAdmin = !!(pr.is_admin || (typeof isTcjAdmin === 'function' && isTcjAdmin(pr, sess)));
        adminName = pr.full_name || pr.username || 'miseenplacekitchen';
        if (pr.avatar_url && typeof avatarBust === 'function') {
          pr.avatar_url = avatarBust(pr.avatar_url, pr.id, pr.last_seen);
        }
        if (typeof saveTcjProfile === 'function') {
          saveTcjProfile(pr, sess);
        } else {
          localStorage.setItem('tcj_profile', JSON.stringify(pr));
        }
      }
    } catch(e) {
      if (String(e.message).indexOf('401') !== -1) {
        localStorage.removeItem('tcj_session');
        localStorage.removeItem('tcj_profile');
        window.location.href = 'login.html';
        return;
      }
      showFatalError('Profile error: ' + e.message);
      return;
    }
    if (!isAdmin) {
      var denied = document.getElementById('screen-denied');
      if (denied) denied.classList.add('open');
      return;
    }
    setEl('admin-name', adminName);
    var _sv = localStorage.getItem('tcj_active_view') || 'dashboard';
    if (!['dashboard','recipe-mgmt','user-mgmt','ingredients','site-mgmt','finance','library-mgmt'].includes(_sv)) {
      _sv = 'dashboard';
      localStorage.setItem('tcj_active_view','dashboard');
    }
    var _it = localStorage.getItem('tcj_active_ing_tab') || 'all';
    document.querySelectorAll('[id^="v-"]').forEach(function(el){ el.style.display = 'none'; });
    try { switchView(_sv, _it); } catch(e) { switchView('dashboard'); }
    document.getElementById('screen-main').style.display = 'flex';
    if (typeof window.loadTcjAnnouncements === 'function') window.loadTcjAnnouncements();
    rpc('admin_get_stats',{}).then(function(st){ if(st) setEl('badge-pending', st.pending||0); }).catch(function(e){ console.warn('badge pending recipes', e); });
    rpc('admin_count_pending_users',{}).then(function(n){ setEl('badge-pending-users', n||0); }).catch(function(e){ console.warn('badge pending users', e); });
    // Load unread feedback count
    rpc('admin_get_feedback',{p_status:'new'}).then(function(rows){
      var n = Array.isArray(rows) ? rows.length : 0;
      var el = document.getElementById('badge-feedback');
      if (el) { el.textContent = n||''; el.style.display = n ? 'inline-block' : 'none'; }
      var vocEl = document.getElementById('badge-voc');
      if (vocEl) { vocEl.textContent = n||''; vocEl.style.display = n ? 'inline-block' : 'none'; }
    }).catch(function(e){ console.warn('badge feedback', e); });
  } catch(e) {
    showFatalError('Dashboard error: ' + e.message);
  }
}

function showFatalError(msg) {
  document.body.innerHTML = '<div style="position:fixed;inset:0;background:#0f1011;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px;font-family:DM Sans,sans-serif">' +
    '<div style="font-family:Cormorant Garamond,serif;font-size:1.4rem;color:#fff">The Culinary Journal</div>' +
    '<div style="color:#dc5050;font-size:14px;max-width:400px;text-align:center">' + msg + '</div>' +
    '<a href="login.html" style="color:#C4973B;font-size:13px">← Sign in again</a></div>';
}

function signOut() {
  localStorage.removeItem('tcj_session'); localStorage.removeItem('tcj_profile'); localStorage.removeItem('tcj_theme');
  window.location.href = 'login.html';
}

const ALL_VIEWS = ['dashboard','recipe-mgmt','user-mgmt','ingredients','lane2','theme-sweep','site-mgmt','finance','library-mgmt','festival-mgmt','voc-mgmt'];

function loadAdminEmbedFrame(frameId, url) {
  var f = document.getElementById(frameId);
  if (!f || f.dataset.src === url) return;
  f.src = url;
  f.dataset.src = url;
}

function toggleApSide() {
  var side = document.querySelector('.ap-side');
  var bd = document.getElementById('ap-side-backdrop');
  if (!side) return;
  var open = side.classList.toggle('open');
  if (bd) bd.classList.toggle('open', open);
  document.body.classList.toggle('ap-side-open', open);
}

function closeApSide() {
  var side = document.querySelector('.ap-side');
  var bd = document.getElementById('ap-side-backdrop');
  if (side) side.classList.remove('open');
  if (bd) bd.classList.remove('open');
  document.body.classList.remove('ap-side-open');
}

function switchView(view, ingTab) {
  closeApSide();
  localStorage.setItem('tcj_active_view', view);
  document.querySelectorAll('.ap-nav-item').forEach(function(el) { el.classList.remove('active'); });
  const nb = document.getElementById('nav-' + view);
  if (nb) nb.classList.add('active');
  ALL_VIEWS.forEach(function(v) { const el = document.getElementById('v-' + v); if (el) el.style.display = (v===view)?'block':'none'; });
  const titles = { 'dashboard':'Dashboard', 'recipe-mgmt':'Recipe Management', 'user-mgmt':'User Management', 'ingredients':'Ingredients Management', 'lane2':'Lane 2 Spot-Check', 'theme-sweep':'Theme Sweep', 'site-mgmt':'Site Management', 'finance':'Finance Management', 'library-mgmt':'Library Management', 'festival-mgmt':'Festival Management', 'voc-mgmt':'Voice of the Customer' };
  const subs   = { 'dashboard':'Overview of site activity.', 'recipe-mgmt':'Review, approve and manage all submitted recipes.', 'user-mgmt':'Manage member registrations and accounts.', 'ingredients':'Browse, add and edit the ingredient database.', 'lane2':'Live verification checklist — core journeys A–F on production.', 'theme-sweep':'Review all 47 themes on key pages; mark pass or issue.', 'site-mgmt':'Control pages, features, announcements, themes, email templates and site settings.', 'finance':'Manage membership tiers, subscriptions, pricing and revenue.', 'library-mgmt':'Manage ingredient, spice, tool, cut and preservation profiles.', 'festival-mgmt':'Festivals, dish slots and recipe variants for occasion planners.', 'voc-mgmt':'Categorised member feedback — signals, noise and actionable items.' };
  setEl('page-title', titles[view] || view);
  setEl('page-sub',   subs[view]   || '');
  var mobileTitle = document.querySelector('.ap-mobile-title');
  if (mobileTitle) mobileTitle.textContent = titles[view] || 'Admin Panel';
  if (view === 'dashboard')   loadDashboard();
  if (view === 'recipe-mgmt') {
    var _srt = localStorage.getItem('tcj_active_recipe_tab') || 'all';
    switchRecipeTab(_srt);
  }
  var _savedUserTab=localStorage.getItem('tcj_active_user_tab')||'members';
  if (view === 'user-mgmt')   switchUserTab(_savedUserTab);
  if (view === 'ingredients') { loadImSettings(); switchIngTab(ingTab||'all'); }
  if (view === 'lane2')       loadAdminEmbedFrame('frame-lane2', 'lane2-spot-check.html?embed=1');
  if (view === 'theme-sweep') loadAdminEmbedFrame('frame-theme-sweep', 'theme-sweep.html?embed=1');
  if (view === 'site-mgmt')   { var _smt=localStorage.getItem('tcj_active_sm_tab')||'sm-pages'; switchSMTab(_smt); }
  if (view === 'finance')     { switchFinanceTab(localStorage.getItem('tcj_active_finance_tab')||'fi-overview'); }
  if (view === 'library-mgmt') { switchLibTab(localStorage.getItem('tcj_active_lib_tab')||'lm-interface'); }
  if (view === 'festival-mgmt') { switchFestTab(localStorage.getItem('tcj_active_fest_tab')||'fm-overview'); }
  if (view === 'voc-mgmt') { switchVocTab(localStorage.getItem('tcj_active_voc_tab')||'voc-inbox'); }
}

// ── RECIPE MANAGEMENT ─────────────────────────────────────────────
let currentRecipe = null;
let allRecipes    = [];

function closeModal() { closeRecipeModal(); }

function statusPill(s) { const c=s==='approved'?'#4caf76':s==='rejected'?'#dc5050':'#d4a017'; return '<span class="ap-modal-meta-tag" style="color:'+c+';border-color:'+c+'">'+s+'</span>'; }

async function openCollectionForm(c, container) {
  var existing = document.getElementById('rm-col-form');
  if (existing) existing.remove();
  var isEdit = c && c.id;
  function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
  var form = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
  form.id = 'rm-col-form';
  form.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px", isEdit ? 'Edit Collection' : 'New Collection'));
  var grid = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px');
  function inp(id, label, value, placeholder) {
    var w = mk('div',''); w.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",label));
    var i = mk('input','width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
    i.id = id; i.value = value || ''; if (placeholder) i.placeholder = placeholder;
    w.appendChild(i); return w;
  }
  var pubWrap = mk('div',''); pubWrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",'Status'));
  var pubSel = mk('select','width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
  pubSel.id = 'rc-published';
  [{v:'false',l:'Draft'},{v:'true',l:'Published'}].forEach(function(o){ var opt = mk('option','',o.l); opt.value = o.v; opt.selected = String(c&&c.published) === o.v; pubSel.appendChild(opt); });
  pubWrap.appendChild(pubSel);
  grid.appendChild(inp('rc-name','Collection Name *', c&&c.name));
  grid.appendChild(pubWrap);
  form.appendChild(grid);
  form.appendChild(inp('rc-desc','Description', c&&c.description,'e.g. Best Onam recipes'));
  document.getElementById('rc-desc').style.width = '100%';
  var btnRow = mk('div','display:flex;gap:8px;margin-top:12px');
  var saveBtn = mk('button','padding:8px 20px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer','Save');
  var cancelBtn = mk('button','padding:8px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer','Cancel');
  var saveMsg = mk('span','font-family:DM Sans,sans-serif;font-size:12px;color:#4caf76;align-self:center','');
  cancelBtn.addEventListener('click', function(){ form.remove(); });
  saveBtn.addEventListener('click', async function() {
    var name = (document.getElementById('rc-name').value||'').trim();
    if (!name) { alert('Name is required.'); return; }
    var desc = (document.getElementById('rc-desc').value||'').trim();
    var pub  = document.getElementById('rc-published').value === 'true';
    saveBtn.disabled = true; saveBtn.textContent = 'Saving\u2026';
    try {
      await rpc('admin_save_collection', {p_id:isEdit?c.id:0, p_name:name, p_description:desc||null, p_recipe_ids:isEdit?(c.recipe_ids||[]):[], p_published:pub});
      auditLog('Recipe Management > Collections', isEdit?'Collection Updated':'Collection Created', name, null, name, null);
      form.remove(); loadRMCollections(container);
    } catch(e) { saveBtn.disabled=false; saveBtn.textContent='Save'; alert('Error: '+e.message); }
  });
  btnRow.appendChild(saveBtn); btnRow.appendChild(cancelBtn); btnRow.appendChild(saveMsg);
  form.appendChild(btnRow);
  container.insertBefore(form, container.firstChild);
}

function setDeactDuration(days) {
  _deactDays = days;
  document.querySelectorAll('.deact-dur-btn').forEach(function(b){
    b.style.background = b.dataset.days == days ? 'var(--accent)' : 'none';
    b.style.color      = b.dataset.days == days ? '#fff' : 'var(--text-mid)';
    b.style.borderColor = b.dataset.days == days ? 'var(--accent)' : 'var(--border)';
  });
  document.getElementById('deact-custom-days').value = '';
}

async function confirmReactivate(uid, username) {
  if (!confirm('Reactivate @' + username + '?')) return;
  try {
    await rpc('admin_reactivate_user',{p_user_id:uid});
    auditLog('User Management','Account Reactivated',username,null,'active',null);
    loadMembers(_userPage);
    if (_userDetailOpen) openUserDetail(uid);
  } catch(e) { alert('Error: '+e.message); }
}

// ── USER DETAIL PANEL ─────────────────────────────────────────────

async function doAddNote(uid) {
  var inp = document.getElementById('ud-note-input');
  var note = inp ? inp.value.trim() : '';
  if (!note) { alert('Note cannot be empty.'); return; }
  try { await rpc('admin_add_user_note',{p_user_id:uid,p_note:note}); auditLog('User Management','Internal Note Added',null,null,null,note.slice(0,50)); openUserDetail(uid); }
  catch(e) { alert('Error: '+e.message); }
}

async function doToggleFlag(uid, currentFlagged) {
  var msg = currentFlagged ? 'Remove flag from this account?' : 'Flag this account for review?';
  if (!confirm(msg)) return;
  try { await rpc('admin_flag_user',{p_user_id:uid,p_flagged:!currentFlagged}); auditLog('User Management',currentFlagged?'Account Unflagged':'Account Flagged',null,null,(!currentFlagged).toString(),null); openUserDetail(uid); loadMembers(_userPage); }
  catch(e) { alert('Error: '+e.message); }
}

async function doToggleAdmin(uid, currentAdmin) {
  var msg = currentAdmin ? 'Remove admin access from this user?' : 'Grant admin access to this user?';
  if (!confirm(msg)) return;
  try { await rpc('admin_set_admin_status',{p_user_id:uid,p_is_admin:!currentAdmin}); auditLog('User Management',currentAdmin?'Admin Access Removed':'Admin Access Granted',null,null,(!currentAdmin).toString(),null); openUserDetail(uid); loadMembers(_userPage); }
  catch(e) { alert('Error: '+e.message); }
}

// ── PENDING PANEL ─────────────────────────────────────────────────

function buildPendingPanel(container) {
  if (!container) return;
  container.innerHTML = '';
  var note = document.createElement('div');
  note.style.cssText = 'margin:16px 0;padding:12px 16px;background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;font-family:\'DM Sans\',sans-serif;font-size:12px;color:var(--text-mid)';
  note.textContent = 'Registration is automatic — no manual approval needed. This tab monitors for unusual signup patterns such as spam waves or bot accounts.';
  container.appendChild(note);
  var tableWrap = document.createElement('div');
  tableWrap.style.cssText = 'overflow-x:auto;border:1px solid var(--border);border-radius:12px';
  tableWrap.innerHTML =
    '<table style="width:100%;border-collapse:collapse">' +
      '<thead><tr style="border-bottom:1px solid var(--border)">' +
        '<th class="ap-th">Member</th><th class="ap-th">Email</th><th class="ap-th">Joined</th>' +
        '<th class="ap-th">Status</th><th class="ap-th">Actions</th>' +
      '</tr></thead>' +
      '<tbody id="upending-tbody"><tr><td colspan="5" class="ap-empty-row">Loading\u2026</td></tr></tbody>' +
    '</table>';
  container.appendChild(tableWrap);
  loadPendingUsers();
}

function buildUMInterface(container) {
  if (!container) return;
  container.innerHTML = '';
  var savedUMTab = localStorage.getItem('tcj_active_um_tab') || 'deactivated';
  var UM_TABS = [
    {key:'deactivated',  label:'Deactivated Accounts'},
    {key:'reports',      label:'Reports'},
    {key:'requests',     label:'Recipe Requests'},
    {key:'notes',        label:'Personal Notes'},
    {key:'feedback',     label:'Feedback'},
    {key:'chefs',        label:'Chef Directory'},
    {key:'family-refs',  label:'Family Profile Lists'},
    {key:'invites',      label:'Invite System'},
    {key:'analytics',    label:'\uD83D\uDCCA Analytics'},
    {key:'audit',        label:'Audit Trail'}
  ];
  // Tab bar
  var topBar = document.createElement('div');
  topBar.style.cssText = 'display:flex;border-bottom:1px solid var(--border);margin-bottom:20px;overflow-x:auto;gap:0;padding-top:4px';
  var umPanels = {};
  UM_TABS.forEach(function(td){
    var btn = document.createElement('button');
    btn.textContent = td.label;
    btn.style.cssText = "padding:10px 16px;background:none;border:none;border-bottom:2px solid transparent;font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);cursor:pointer;white-space:nowrap;transition:all 0.15s";
    if (td.key === savedUMTab) { btn.style.borderBottomColor = 'var(--accent)'; btn.style.color = 'var(--accent)'; }
    var panel = document.createElement('div');
    panel.style.display = td.key === savedUMTab ? 'block' : 'none';
    panel.style.padding = '0';
    umPanels[td.key] = panel;
    btn.addEventListener('click', function(){
      localStorage.setItem('tcj_active_um_tab', td.key);
      topBar.querySelectorAll('button').forEach(function(b){ b.style.borderBottomColor='transparent'; b.style.color='var(--text-mid)'; });
      btn.style.borderBottomColor = 'var(--accent)'; btn.style.color = 'var(--accent)';
      Object.keys(umPanels).forEach(function(k){ umPanels[k].style.display = k===td.key?'block':'none'; });
      loadUMTab(td.key, umPanels[td.key]);
    });
    topBar.appendChild(btn);
    container.appendChild(topBar);
    container.appendChild(panel);
  });
  loadUMTab(savedUMTab, umPanels[savedUMTab]);
}

function loadUMTab(key, container) {
  if (!container) return;
  if (key === 'deactivated') loadUMDeactivated(container);
  else if (key === 'reports')   loadUMReports(container);
  else if (key === 'requests')  loadUMRequests(container);
  else if (key === 'notes') {
    if (typeof loadRecipeNotes === 'function') loadRecipeNotes(container);
    else buildUMStub(container, 'Personal Notes Approval', 'Cooking tips queue loads after dashboard modules finish loading.');
  }
  else if (key === 'feedback')  loadUMFeedback(container);
  else if (key === 'chefs')     loadUMChefs(container);
  else if (key === 'family-refs') loadUMFamilyRefs(container);
  else if (key === 'invites')   loadUMInvites(container);
  else if (key === 'analytics') loadUMAnalytics(container);
  else if (key === 'audit')     loadUMAudit(container);
}

// UM ops tabs → lib/dashboard-um-ops.js


// ── STANDALONE ANALYTICS ─────────────────────────────────────────

// ── UTILITIES ─────────────────────────────────────────────────────

function setEl(id,val){ const el=document.getElementById(id); if(el) el.textContent=val; }

function esc(s){ return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;'); }

function escH(s){ return esc(s); }

function escT(s){ return esc(s); }


// ── SITE MANAGEMENT ──────────────────────────────────────────────

function smSQLError(container, e) {
  container.innerHTML = '<div style="padding:20px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:12px;font-family:DM Sans,sans-serif"><div style="font-size:14px;font-weight:700;color:#dc5050;margin-bottom:8px">Error</div><div style="font-size:13px;color:var(--text-high);word-break:break-all">'+String((e&&e.message)||'Unknown error').replace(/</g,'&lt;')+'</div></div>';
}

async function buildSMContent(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var res = await apiFetch(SUPABASE_URL+'/rest/v1/site_settings?select=key,value');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var rows = await res.json(); var S={};
    if(Array.isArray(rows)) rows.forEach(function(r){S[r.key]=r.value;});
    async function ssSave(k,v){var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_settings',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify({key:k,value:v})});if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');}
    container.innerHTML='';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}
    var sec=mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
    sec.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px",'Homepage Display'));
    [{key:'homepage_show_featured',label:'Show Featured Recipes'},{key:'homepage_show_rotw',label:'Show Recipe of the Week'}].forEach(function(t){
      var row=mk('div','display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(255,255,255,0.04)');
      row.appendChild(mk('span','font-size:13px;color:var(--text-high)',t.label));
      var cb=document.createElement('input');cb.type='checkbox';cb.checked=S[t.key]!=='false';cb.style.cssText='width:16px;height:16px;accent-color:var(--accent);cursor:pointer';
      cb.addEventListener('change',(function(k){return async function(){var prev=this.checked;try{await ssSave(k,String(this.checked));}catch(e){this.checked=!prev;alert(e.message);}}})(t.key));
      row.appendChild(cb);sec.appendChild(row);
    });
    container.appendChild(sec);

    var _SM_DEFAULT_CATS = ['Main Courses','Appetizers','Desserts','Soups','Salads','Breads','Beverages','Sides','Snacks','Little Ones'];
    var cats = [];
    try { cats = JSON.parse(S.homepage_categories_order || '[]'); } catch (e) { console.warn('homepage categories parse', e); }
    if (!cats.length) cats = _SM_DEFAULT_CATS.slice();

    var catSec = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
    catSec.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:4px",'Category Display Order'));
    catSec.appendChild(mk('p','font-size:12px;color:var(--text-mid);margin-bottom:14px;line-height:1.5','Reorder recipe categories for browse pages. Rename labels inline; changes save immediately.'));
    var catList = mk('div','');
    function renderCats() {
      catList.innerHTML = '';
      cats.forEach(function(cat, i) {
        var row = mk('div','display:flex;align-items:center;gap:10px;padding:8px 12px;background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:8px;margin-bottom:6px');
        row.appendChild(mk('span','font-size:10px;color:var(--text-mid);width:22px;text-align:center',String(i + 1)));
        var nameInp = document.createElement('input');
        nameInp.value = cat;
        nameInp.style.cssText = 'flex:1;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)';
        nameInp.addEventListener('change', (function(idx, prev) { return async function() {
          var next = (this.value || '').trim();
          if (!next) { this.value = prev; return; }
          cats[idx] = next;
          try { await ssSave('homepage_categories_order', JSON.stringify(cats)); }
          catch (e) { cats[idx] = prev; this.value = prev; alert(e.message); }
        };})(i, cat));
        row.appendChild(nameInp);
        function moveCat(dir) {
          return async function() {
            var j = i + dir;
            if (j < 0 || j >= cats.length) return;
            var tmp = cats[i];
            cats[i] = cats[j];
            cats[j] = tmp;
            renderCats();
            try { await ssSave('homepage_categories_order', JSON.stringify(cats)); }
            catch (e) { alert(e.message); }
          };
        }
        var up = mk('button','padding:3px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-size:11px;cursor:pointer','\u25b2');
        up.addEventListener('click', moveCat(-1));
        var dn = mk('button','padding:3px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-size:11px;cursor:pointer','\u25bc');
        dn.addEventListener('click', moveCat(1));
        row.appendChild(up);
        row.appendChild(dn);
        catList.appendChild(row);
      });
    }
    renderCats();
    catSec.appendChild(catList);
    container.appendChild(catSec);

    container.dataset.built='1';
  } catch(e){container.dataset.built='';container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';}
}

// buildSMThemes() lives in lib/theme-admin-ui.js

async function buildFiOverview(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var stats = await rpc('admin_get_tier_stats', {});
    var settings_res = await apiFetch(SUPABASE_URL + '/rest/v1/site_settings?select=key,value&key=in.(price_premium_monthly,price_event_monthly,currency_symbol)');
    var S = {};
    if (settings_res && settings_res.ok) {
      var rows = await settings_res.json();
      if (Array.isArray(rows)) rows.forEach(function(r){ S[r.key] = r.value; });
    }
    var cur = S.currency_symbol || '$';
    var prem_price = S.price_premium_monthly || '4.00';
    var evt_price  = S.price_event_monthly   || '12.00';

    // Estimated MRR
    var mrr = (parseFloat(prem_price) * (stats.premium||0)) + (parseFloat(evt_price) * (stats.event||0));

    container.innerHTML = '';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}

    // Stat cards
    var statsRow = mk('div','display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:24px');
    [
      { label:'Total Active Members', value: (stats.total||0).toLocaleString(), accent: false },
      { label:'Free Members',         value: (stats.free||0).toLocaleString(),  accent: false },
      { label:'Premium Members',      value: (stats.premium||0).toLocaleString(), accent: true },
      { label:'Event Tier Members',   value: (stats.event||0).toLocaleString(),   accent: true },
      { label:'Est. Monthly Revenue', value: cur + mrr.toFixed(2),               accent: true }
    ].forEach(function(s){
      var card = mk('div','background:rgba(255,255,255,0.04);border:1px solid '+(s.accent?'var(--accent)':'var(--border)')+';border-radius:12px;padding:18px 20px');
      card.appendChild(mk('div','font-family:Cormorant Garamond,serif;font-size:1.7rem;font-weight:700;color:'+(s.accent?'var(--accent)':'var(--text-high)'),s.value));
      card.appendChild(mk('div','font-size:11px;color:var(--text-mid);margin-top:4px;text-transform:uppercase;letter-spacing:0.06em',s.label));
      statsRow.appendChild(card);
    });
    container.appendChild(statsRow);

    // Tier breakdown bar
    var total = (stats.total||0) || 1;
    var freePct    = Math.round((stats.free||0)    / total * 100);
    var premPct    = Math.round((stats.premium||0) / total * 100);
    var evtPct     = Math.round((stats.event||0)   / total * 100);
    var barCard = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:24px');
    barCard.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px",'Membership Breakdown'));
    var bar = mk('div','display:flex;height:10px;border-radius:10px;overflow:hidden;margin-bottom:12px');
    if (freePct > 0) { var s1=mk('div','flex:'+freePct+';background:var(--border)'); bar.appendChild(s1); }
    if (premPct > 0) { var s2=mk('div','flex:'+premPct+';background:var(--accent)'); bar.appendChild(s2); }
    if (evtPct  > 0) { var s3=mk('div','flex:'+evtPct+';background:#5B8FD4');        bar.appendChild(s3); }
    barCard.appendChild(bar);
    var legend = mk('div','display:flex;gap:20px;flex-wrap:wrap');
    [{label:'Free',color:'var(--border)',pct:freePct},{label:'Premium',color:'var(--accent)',pct:premPct},{label:'Event',color:'#5B8FD4',pct:evtPct}].forEach(function(l){
      var item=mk('div','display:flex;align-items:center;gap:6px;font-size:12px;color:var(--text-mid)');
      var dot=mk('div','width:10px;height:10px;border-radius:50%;background:'+l.color+';flex-shrink:0');
      item.appendChild(dot); item.appendChild(document.createTextNode(l.label+' '+l.pct+'%'));
      legend.appendChild(item);
    });
    barCard.appendChild(legend);
    container.appendChild(barCard);

    // Pricing info card
    var priceCard = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px');
    priceCard.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px",'Current Pricing'));
    [
      {tier:'Premium', monthly: cur+prem_price, annual: cur+(parseFloat(prem_price)*10).toFixed(2), desc:'Unlimited recipes, AI features, full print studio'},
      {tier:'Event / Wedding', monthly: cur+evt_price, annual: cur+(parseFloat(evt_price)*10).toFixed(2), desc:'Everything in Premium + event planning, seating, guest cards'}
    ].forEach(function(p){
      var row=mk('div','display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid rgba(255,255,255,0.05)');
      var left=mk('div','');
      left.appendChild(mk('div',"font-size:13px;font-weight:600;color:var(--text-high)",p.tier));
      left.appendChild(mk('div',"font-size:11px;color:var(--text-mid);margin-top:2px",p.desc));
      var right=mk('div','text-align:right;flex-shrink:0;padding-left:16px');
      right.appendChild(mk('div',"font-size:16px;font-weight:700;color:var(--accent)",p.monthly+'/mo'));
      right.appendChild(mk('div',"font-size:11px;color:var(--text-mid)",p.annual+'/yr'));
      row.appendChild(left); row.appendChild(right); priceCard.appendChild(row);
    });
    container.appendChild(priceCard);

    container.dataset.built = '1';
  } catch(e) { container.dataset.built=''; container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>'; }
}

async function buildFiPricing(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var res = await apiFetch(SUPABASE_URL + '/rest/v1/site_settings?select=key,value&key=in.(price_premium_monthly,price_premium_annual,price_event_monthly,price_event_annual,price_daily,price_weekly,price_yearly,currency_symbol,currency_code,stripe_enabled,stripe_publishable_key,stripe_price_daily,stripe_price_weekly,stripe_price_monthly,stripe_price_yearly)');
    if (!res||!res.ok) throw new Error(res?res.status:'Session expired');
    var rows = await res.json(); var S={};
    if(Array.isArray(rows)) rows.forEach(function(r){S[r.key]=r.value;});

    async function savePriceSetting(k,v){var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_settings',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify({key:k,value:v})});if(!r||!r.ok)throw new Error(r?r.status:'Failed');}

    container.innerHTML = '';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}
    function card(title,desc){var d=mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');d.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:"+(desc?'4':'14')+"px",title));if(desc)d.appendChild(mk('p','font-size:12px;color:var(--text-mid);margin-bottom:14px',desc));return d;}
    function inp(id,lbl,val,prefix){var w=mk('div','margin-bottom:12px');w.appendChild(mk('label','display:block;font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px',lbl));var row=mk('div','display:flex;align-items:center;gap:0');if(prefix){var pre=mk('span','padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid var(--border);border-right:none;border-radius:7px 0 0 7px;font-size:12px;color:var(--text-mid)',prefix);row.appendChild(pre);}var i=mk('input','flex:1;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:'+(prefix?'0 7px 7px 0':'7px')+';font-size:12px;color:var(--text-high)');i.id='fp-'+id;i.value=val||'';i.type='text';i.inputMode='decimal';row.appendChild(i);w.appendChild(row);return w;}
    function saveBtn(keys,lbl){var b=document.createElement('button');b.className='ing-add-btn';b.style.marginTop='4px';b.textContent=lbl||'Save Pricing';b.addEventListener('click',async function(){b.disabled=true;b.textContent='Saving\u2026';try{for(var k=0;k<keys.length;k++){var el=document.getElementById('fp-'+keys[k]);if(el)await savePriceSetting(keys[k],el.value||'');}b.textContent='\u2713 Saved';setTimeout(function(){b.textContent=lbl||'Save Pricing';b.disabled=false;var c=document.getElementById('upanel-fi-pricing');if(c){c.dataset.built='';buildFiPricing(c);}},2000);}catch(e){b.textContent=lbl||'Save Pricing';b.disabled=false;alert('Save failed: '+e.message);}});return b;}

    var cur = S.currency_symbol || '$';

    var currCard = card('Currency');
    var cg = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px');
    cg.appendChild(inp('currency_symbol','Symbol',S.currency_symbol));
    cg.appendChild(inp('currency_code','Code (e.g. USD)',S.currency_code));
    currCard.appendChild(cg); currCard.appendChild(saveBtn(['currency_symbol','currency_code'],'Save Currency')); container.appendChild(currCard);

    var premCard = card('Premium Plan','Unlimited recipes, AI features, full print studio, meal planning, pantry tracker.');
    var pg = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px');
    pg.appendChild(inp('price_premium_monthly','Monthly Price',S.price_premium_monthly,cur));
    pg.appendChild(inp('price_premium_annual','Annual Price',S.price_premium_annual,cur));
    premCard.appendChild(pg); premCard.appendChild(saveBtn(['price_premium_monthly','price_premium_annual'],'Save Premium Pricing')); container.appendChild(premCard);

    var evtCard = card('Event / Wedding Tier','Everything in Premium plus event planning, table layouts, guest dietary cards, seating manager.');
    var eg = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px');
    eg.appendChild(inp('price_event_monthly','Monthly Price',S.price_event_monthly,cur));
    eg.appendChild(inp('price_event_annual','Annual Price',S.price_event_annual,cur));
    evtCard.appendChild(eg); evtCard.appendChild(saveBtn(['price_event_monthly','price_event_annual'],'Save Event Pricing')); container.appendChild(evtCard);

    var stripeCard = card('Stripe Checkout','Enable automated checkout. Add STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET as Edge Function secrets, then deploy create-checkout-session and stripe-webhook.');
    var sg = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px');
    var enWrap = mk('div','display:flex;align-items:center;gap:10px;margin-bottom:12px');
    enWrap.appendChild(mk('span','font-size:13px;color:var(--text-high)','Enable Stripe checkout'));
    var enCb = mk('input','width:16px;height:16px;accent-color:var(--accent)'); enCb.type='checkbox'; enCb.id='fp-stripe_enabled'; enCb.checked=S.stripe_enabled==='true';
    enCb.addEventListener('change',async function(){var p=this.checked;try{await savePriceSetting('stripe_enabled',String(this.checked));}catch(e){this.checked=!p;alert(e.message);}});
    enWrap.appendChild(enCb); stripeCard.appendChild(enWrap);
    sg.appendChild(inp('stripe_publishable_key','Publishable key (pk_...)',S.stripe_publishable_key));
    sg.appendChild(inp('stripe_price_daily','Daily price',S.stripe_price_daily||S.price_daily,cur));
    sg.appendChild(inp('stripe_price_weekly','Weekly price',S.stripe_price_weekly||S.price_weekly,cur));
    sg.appendChild(inp('stripe_price_monthly','Monthly price',S.stripe_price_monthly||S.price_premium_monthly,cur));
    sg.appendChild(inp('stripe_price_yearly','Yearly price',S.stripe_price_yearly||S.price_yearly,cur));
    stripeCard.appendChild(sg);
    stripeCard.appendChild(mk('p','font-size:11px;color:var(--text-mid);line-height:1.55;margin-bottom:10px','Webhook URL: https://kzywmodvfbyexqgipcjt.supabase.co/functions/v1/stripe-webhook — event: checkout.session.completed'));
    stripeCard.appendChild(saveBtn(['stripe_publishable_key','stripe_price_daily','stripe_price_weekly','stripe_price_monthly','stripe_price_yearly'],'Save Stripe Settings'));
    container.appendChild(stripeCard);

    container.dataset.built = '1';
  } catch(e){ container.dataset.built=''; container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>'; }
}

async function buildFiHistory(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var subs = await rpc('admin_get_subscriptions', {p_limit:100, p_offset:0});
    if (!Array.isArray(subs)||!subs.length) { container.innerHTML='<div style="padding:16px;font-size:13px;color:var(--text-mid)">No subscription history yet. Changes made via Member Tiers will appear here.</div>'; container.dataset.built='1'; return; }
    container.innerHTML = '';
    var wrap = document.createElement('div'); wrap.style.cssText='overflow-x:auto;border:1px solid var(--border);border-radius:12px';
    var tbl  = document.createElement('table'); tbl.className='ap-table';
    tbl.innerHTML = '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Member</th><th class="ap-th">Tier</th><th class="ap-th">Status</th><th class="ap-th">Source</th><th class="ap-th">Started</th><th class="ap-th">Notes</th></tr></thead>';
    var tbody = document.createElement('tbody');
    var TIER_C={free:'var(--text-mid)',premium:'var(--accent)',event:'#5B8FD4'};
    var SRC_C={manual:'var(--text-mid)',stripe:'#4caf76',promo:'#d4a017'};
    subs.forEach(function(s){
      var tr=document.createElement('tr');tr.style.borderBottom='1px solid rgba(255,255,255,0.04)';
      var date=s.started_at?new Date(s.started_at).toLocaleDateString('en-AU',{day:'2-digit',month:'short',year:'numeric'}):'—';
      tr.innerHTML=
        '<td class="ap-td"><div style="font-size:13px;font-weight:500;color:var(--text-high)">'+(s.full_name||s.username||'—')+'</div><div style="font-size:11px;color:var(--text-mid)">@'+(s.username||'')+'</div></td>'+
        '<td class="ap-td"><span style="font-size:11px;font-weight:700;padding:3px 9px;border-radius:20px;background:rgba(255,255,255,0.07);color:'+(TIER_C[s.tier]||'var(--text-mid)')+'">'+s.tier+'</span></td>'+
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+s.status+'</td>'+
        '<td class="ap-td"><span style="font-size:11px;color:'+(SRC_C[s.source]||'var(--text-mid)')+'">'+s.source+'</span></td>'+
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+date+'</td>'+
        '<td class="ap-td" style="font-size:11px;color:var(--text-mid)">'+(s.notes||'')+'</td>';
      tbody.appendChild(tr);
    });
    tbl.appendChild(tbody); wrap.appendChild(tbl); container.appendChild(wrap);
    container.dataset.built='1';
  } catch(e){ container.dataset.built=''; container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>'; }
}

// ── FIND & REMOVE DUPLICATES ─────────────────────────────────────────────────

async function loadIngDuplicates(container) {
  if (!container) return;
  container.innerHTML = '';

  function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}

  // Header
  var hdr = mk('div','margin-bottom:16px');
  hdr.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1.1rem;font-weight:700;color:var(--text-high);margin-bottom:6px",'Duplicate Ingredient Finder'));
  hdr.appendChild(mk('p',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid);margin:0;line-height:1.6",
    'Finds ingredient names that appear more than once (case-insensitive). '+
    'The most complete record is kept — scored by how many fields are filled in. '+
    'Lowest ID wins any tie.'));
  container.appendChild(hdr);

  // Scan button
  var scanBtn = mk('button',"padding:9px 22px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;cursor:pointer;margin-right:10px",'🔍 Scan for Duplicates');
  var statusEl = mk('span',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid)",'');
  var resultsEl = mk('div','margin-top:20px','');
  container.appendChild(scanBtn);
  container.appendChild(statusEl);
  container.appendChild(resultsEl);

  scanBtn.addEventListener('click', async function() {
    scanBtn.disabled = true;
    scanBtn.textContent = 'Scanning…';
    statusEl.textContent = '';
    resultsEl.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading all ingredients…</div>';

    try {
      // Fetch all ingredients (paginate if needed)
      var allRows = [];
      var page = 0, pageSize = 1000;
      while (true) {
        var res = await apiFetch(SUPABASE_URL + '/rest/v1/ingredients?select="ID","Ingredient Name","Category","Also Known As","Sub Category","CJ Recommended Brand","Allergen","Notes","Standard Qty","Unit"&order="ID".asc&limit=' + pageSize + '&offset=' + (page * pageSize));
        if (!res || !res.ok) throw new Error('Fetch failed: ' + (res ? res.status : 'no response'));
        var rows = await res.json();
        if (!Array.isArray(rows) || !rows.length) break;
        allRows = allRows.concat(rows);
        if (rows.length < pageSize) break;
        page++;
      }

      statusEl.textContent = ' ' + allRows.length + ' ingredients loaded.';

      // Group by lowercase name
      var groups = {};
      allRows.forEach(function(r) {
        var key = (r['Ingredient Name'] || '').trim().toLowerCase();
        if (!key) return;
        if (!groups[key]) groups[key] = [];
        groups[key].push(r);
      });

      // Find duplicates
      var dupes = Object.values(groups).filter(function(g) { return g.length > 1; });

      resultsEl.innerHTML = '';
      if (!dupes.length) {
        var ok = mk('div','padding:20px;background:rgba(76,175,118,0.1);border:1px solid rgba(76,175,118,0.3);border-radius:10px;font-family:DM Sans,sans-serif;font-size:14px;color:#4caf76;text-align:center','✓ No duplicates found. Your ingredient list is clean.');
        resultsEl.appendChild(ok);
        scanBtn.disabled = false;
        scanBtn.textContent = '🔍 Scan for Duplicates';
        return;
      }

      // Score completeness
      function score(r) {
        var fields = ['Category','Also Known As','Sub Category','CJ Recommended Brand','Allergen','Notes','Standard Qty','Unit'];
        return fields.reduce(function(n, f) { return n + (r[f] && r[f] !== '' ? 1 : 0); }, 0);
      }

      // Sort each group: most complete first, then lowest ID
      dupes.forEach(function(g) {
        g.sort(function(a,b) { var sd = score(b) - score(a); return sd !== 0 ? sd : a['ID'] - b['ID']; });
      });

      // Summary bar
      var toDelete = dupes.reduce(function(n, g) { return n + g.length - 1; }, 0);
      var sumBar = mk('div','display:flex;align-items:center;justify-content:space-between;padding:14px 18px;background:rgba(220,80,80,0.08);border:1px solid rgba(220,80,80,0.3);border-radius:10px;margin-bottom:16px;flex-wrap:wrap;gap:10px');
      var sumText = mk('div','');
      sumText.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:14px;font-weight:600;color:#dc5050", dupes.length + ' duplicate group' + (dupes.length===1?'':'s') + ' found — ' + toDelete + ' record' + (toDelete===1?' can':' can') + ' be removed'));
      sumText.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);margin-top:2px",'Green row = will be KEPT. Red rows = will be DELETED.'));
      var delAllBtn = mk('button',"padding:9px 20px;background:#dc5050;border:none;border-radius:8px;color:#fff;font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;cursor:pointer",'🗑 Remove All Duplicates');
      delAllBtn.addEventListener('click', function() { removeAllDuplicates(dupes, resultsEl, delAllBtn, scanBtn); });
      sumBar.appendChild(sumText);
      sumBar.appendChild(delAllBtn);
      resultsEl.appendChild(sumBar);

      // Render each duplicate group
      dupes.forEach(function(group, gi) {
        var keepId = group[0]['ID'];
        var card = mk('div','background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:10px;margin-bottom:10px;overflow:hidden');
        var cardHdr = mk('div','padding:10px 16px;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between');
        cardHdr.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high)",group[0]['Ingredient Name']));
        cardHdr.appendChild(mk('span',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)", group.length + ' copies'));
        card.appendChild(cardHdr);

        group.forEach(function(row, ri) {
          var isKeep = row['ID'] === keepId;
          var rowEl = mk('div','display:grid;grid-template-columns:60px 1fr 120px 120px 100px 60px;gap:0 8px;align-items:center;padding:8px 16px;border-bottom:1px solid rgba(255,255,255,0.03);background:' + (isKeep ? 'rgba(76,175,118,0.06)' : 'rgba(220,80,80,0.06)'));
          function cell(t,s){var d=mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:"+(s||'var(--text-mid)')+";overflow:hidden;text-overflow:ellipsis;white-space:nowrap");d.textContent=t||'—';return d;}
          rowEl.appendChild(cell('ID #'+row['ID'], isKeep?'#4caf76':'#dc5050'));
          rowEl.appendChild(cell(row['Ingredient Name'], isKeep?'var(--text-high)':'var(--text-mid)'));
          rowEl.appendChild(cell(row['Category']));
          rowEl.appendChild(cell(row['Also Known As']));
          rowEl.appendChild(cell('Score: '+score(row), isKeep?'#4caf76':'var(--text-mid)'));
          var badge = mk('div',"font-size:9px;font-weight:700;padding:2px 7px;border-radius:10px;text-align:center;background:"+(isKeep?'rgba(76,175,118,0.15)':'rgba(220,80,80,0.15)')+";color:"+(isKeep?'#4caf76':'#dc5050'), isKeep ? 'KEEP' : 'DELETE');
          rowEl.appendChild(badge);
          card.appendChild(rowEl);
        });

        resultsEl.appendChild(card);
      });

      scanBtn.disabled = false;
      scanBtn.textContent = '🔍 Scan Again';
    } catch(e) {
      resultsEl.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
      scanBtn.disabled = false;
      scanBtn.textContent = '🔍 Scan for Duplicates';
    }
  });
}

async function removeAllDuplicates(dupes, resultsEl, delBtn, scanBtn) {
  var toDelete = [];
  dupes.forEach(function(group) {
    // First item is kept (highest score + lowest id), rest are deleted
    group.slice(1).forEach(function(r) { toDelete.push(r['ID']); });
  });
  if (!toDelete.length) return;
  if (!confirm('Delete ' + toDelete.length + ' duplicate record' + (toDelete.length===1?'':'s') + '? This cannot be undone.')) return;
  delBtn.disabled = true;
  delBtn.textContent = 'Deleting…';
  var errors = 0;
  // Delete in batches of 50
  for (var i = 0; i < toDelete.length; i += 50) {
    var batch = toDelete.slice(i, i + 50);
    var idList = batch.join(',');
    try {
      var res = await apiFetch(SUPABASE_URL + '/rest/v1/ingredients?id=in.(' + idList + ')', { method: 'DELETE' });
      if (!res || !res.ok) errors++;
    } catch(e) { errors++; }
  }
  if (errors === 0) {
    auditLog('Ingredients Management > Find Duplicates', 'Duplicates Removed', null, null, toDelete.length + ' records deleted', null);
    delBtn.textContent = '✓ Done';
    delBtn.style.background = '#2d5a2d';
    // Refresh ingredient table
    var c = document.getElementById('ipanel-all');
    if (c) loadIngredients(1);
    // Re-scan
    var scanBtn2 = resultsEl.previousElementSibling?.previousElementSibling;
    resultsEl.innerHTML = '<div style="padding:20px;background:rgba(76,175,118,0.1);border:1px solid rgba(76,175,118,0.3);border-radius:10px;font-family:DM Sans,sans-serif;font-size:14px;color:#4caf76;text-align:center">✓ ' + toDelete.length + ' duplicate' + (toDelete.length===1?'':'s') + ' removed. Run scan again to confirm.</div>';
  } else {
    delBtn.textContent = 'Done with ' + errors + ' error(s)';
    delBtn.disabled = false;
  }
}

document.addEventListener('DOMContentLoaded', init);
