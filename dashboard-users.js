var _detailUser = null; // Stores current user detail — action buttons read from here
// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

var _UM_OPS_TABS = ['deactivated','reports','requests','chefs','family-refs','invites'];
var _UM_INTERFACE_TABS = ['settings','analytics','audit'];

function formatBadgeLabel(badge) {
  return badge === "Betty's Pick" ? 'Journal Pick' : badge;
}

function userHasBadge(badges, badgeName) {
  if (!badges || !badgeName) return false;
  if (badges.indexOf(badgeName) !== -1) return true;
  if (badgeName === 'Journal Pick' && badges.indexOf("Betty's Pick") !== -1) return true;
  return false;
}

function switchUserTab(tab) {
  if (tab === 'feedback') {
    switchView('voc-mgmt');
    return;
  }
  if (_UM_INTERFACE_TABS.indexOf(tab) !== -1 && tab !== 'umsettings') {
    localStorage.setItem('tcj_um_interface_tab', tab);
    tab = 'umsettings';
  }
  localStorage.setItem('tcj_active_user_tab', tab);
  _currentUserTab = tab;
  document.querySelectorAll('#v-user-mgmt .ap-inner-tab').forEach(function(t){
    t.classList.toggle('active', t.dataset.tab === tab);
  });
  ['members','pending','umsettings'].concat(_UM_OPS_TABS).forEach(function(p){
    var el = document.getElementById('upanel-' + p);
    if (el) el.style.display = p === tab ? 'block' : 'none';
  });
  if (tab === 'members')    { buildMembersPanel(document.getElementById('upanel-members')); return; }
  if (tab === 'pending')    { buildPendingPanel(document.getElementById('upanel-pending')); return; }
  if (tab === 'umsettings') { loadUMInterfaceSettings(); return; }
  if (_UM_OPS_TABS.indexOf(tab) !== -1) {
    var panel = document.getElementById('upanel-' + tab);
    if (panel) loadUMTab(tab, panel);
  }
}

function loadUMInterfaceSettings() {
  var container = document.getElementById('upanel-umsettings');
  if (!container || typeof AdminTabNav === 'undefined') {
    if (container) container.textContent = 'Admin tab navigation failed to load.';
    return;
  }

  AdminTabNav.buildInterfaceShell(container, {
    storageKey: 'tcj_um_interface_tab',
    defaultKey: 'hub',
    banner: 'Member policy and insights — member queues stay in the tabs above.',
    sections: [
      {
        key: 'hub',
        label: 'Hub',
        group: 'Overview',
        subtitle: 'Shortcuts to work queues and related panels',
        render: function (panel, ctx) {
          panel.innerHTML = '<div class="admin-if-loading">Loading…</div>';
          return Promise.all([
            rpc('admin_count_pending_users', {}).catch(function () { return 0; }),
            AdminTabNav.restCount('appeals', 'status=eq.pending'),
            AdminTabNav.restCount('user_reports', 'status=eq.pending')
          ]).then(function (res) {
            AdminTabNav.renderHub(panel, {
              stats: [
                { num: res[0] || 0, label: 'Pending members' },
                { num: res[1] || 0, label: 'Appeals' },
                { num: res[2] || 0, label: 'Open reports' }
              ],
              actions: [
                { label: 'Review pending members', desc: 'Approval queue', onClick: function () { switchUserTab('pending'); } },
                { label: 'Reports & appeals', desc: 'Moderation inbox', onClick: function () { switchUserTab('reports'); } },
                { label: 'Voice of the Customer', desc: 'Site feedback inbox', onClick: function () { switchView('voc-mgmt'); } },
                { label: 'Member tiers', desc: 'Finance → grant tiers', onClick: function () { switchView('finance'); switchFinanceTab('fi-members'); } },
                { label: 'Analytics', desc: 'Member insights', onClick: function () { ctx.activate('analytics'); } },
                { label: 'Audit trail', desc: 'User admin log', onClick: function () { ctx.activate('audit'); } }
              ]
            });
          });
        }
      },
      { key: 'analytics', label: 'Analytics', group: 'Insights', subtitle: 'Member and engagement stats', render: function (p) { loadUMAnalytics(p); } },
      { key: 'audit', label: 'Audit trail', group: 'Insights', subtitle: 'User management actions', render: function (p) { loadUMTab('audit', p); } }
    ]
  });
}

// ── MEMBERS PANEL ─────────────────────────────────────────────────

function buildMembersPanel(container) {
  if (!container || container.dataset.built === 'members') { loadMembers(1); return; }
  container.dataset.built = 'members';
  container.innerHTML = '';

  // Toolbar
  var toolbar = document.createElement('div');
  toolbar.style.cssText = 'display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:16px;padding:16px 0 0';
  toolbar.innerHTML =
    '<span id="umgmt-count" style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid)"></span>' +
    '<input type="text" id="umgmt-search" placeholder="Search by name, username or email..." style="flex:1;min-width:200px;padding:8px 14px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-high);outline:none">' +
    '<select id="umgmt-filter" style="padding:8px 14px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-high);cursor:pointer">' +
      '<option value="">All Members</option>' +
      '<option value="active">Active</option>' +
      '<option value="admin">Administrators</option>' +
      '<option value="flagged">Flagged</option>' +
      '<option value="deactivated">Deactivated</option>' +
    '</select>' +
    '<button id="umgmt-bulk-deact" onclick="bulkDeactivateUsers()" style="display:none;padding:7px 14px;background:none;border:1px solid #dc5050;border-radius:7px;color:#dc5050;font-family:\'DM Sans\',sans-serif;font-size:12px;cursor:pointer">Deactivate Selected</button>' +
    '<button id="umgmt-bulk-badge" onclick="bulkAwardBadge()" style="display:none;padding:7px 14px;background:none;border:1px solid var(--accent);border-radius:7px;color:var(--accent);font-family:\'DM Sans\',sans-serif;font-size:12px;cursor:pointer">Award Badge</button>';
  container.appendChild(toolbar);

  document.getElementById('umgmt-search').addEventListener('input', function(){
    _userSearch = this.value; _userPage = 1; loadMembers(1);
  });
  document.getElementById('umgmt-filter').addEventListener('change', function(){
    _userStatus = this.value; _userPage = 1; loadMembers(1);
  });

  // Table
  var tableWrap = document.createElement('div');
  tableWrap.style.cssText = 'overflow-x:auto;border:1px solid var(--border);border-radius:12px;margin-bottom:16px';
  tableWrap.innerHTML =
    '<table id="umgmt-table" style="width:100%;border-collapse:collapse">' +
      '<thead><tr style="border-bottom:1px solid var(--border)">' +
        '<th class="ap-th" style="width:32px"><input type="checkbox" id="umgmt-select-all" onchange="toggleSelectAllUsers(this.checked)"></th>' +
        '<th class="ap-th">Member</th>' +
        '<th class="ap-th">Email</th>' +
        '<th class="ap-th">Joined</th>' +
        '<th class="ap-th" style="text-align:center">Recipes</th>' +
        '<th class="ap-th">Status</th>' +
        '<th class="ap-th">Plan</th>' +
        '<th class="ap-th">Actions</th>' +
      '</tr></thead>' +
      '<tbody id="umgmt-tbody"><tr><td colspan="8" class="ap-empty-row">Loading\u2026</td></tr></tbody>' +
    '</table>';
  container.appendChild(tableWrap);

  // Pagination
  var pag = document.createElement('div');
  pag.id = 'umgmt-pagination';
  pag.style.cssText = 'display:flex;gap:6px;align-items:center;flex-wrap:wrap;padding-bottom:16px';
  container.appendChild(pag);

  loadMembers(1);
}

async function loadMembers(page) {
  _userPage = page || 1;
  var tbody = document.getElementById('umgmt-tbody');
  var countEl = document.getElementById('umgmt-count');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Loading\u2026</td></tr>';
  try {
    var off  = (_userPage - 1) * _userPageSize;
    var rows = await rpc('admin_get_users',{p_search:_userSearch||null,p_status:_userStatus||null,p_limit:_userPageSize,p_offset:off});
    var tot  = await rpc('admin_count_users',{p_search:_userSearch||null,p_status:_userStatus||null});
    _userTotal = parseInt(tot) || 0;
    var list = rows || [];
    var start = off + 1, end = Math.min(_userPage * _userPageSize, _userTotal);
    if (countEl) countEl.textContent = _userTotal + ' member' + (_userTotal===1?'':'s') + (_userTotal > 0 ? ' (showing ' + start + '\u2013' + end + ')' : '');
    setEl('badge-all-users', _userTotal);
    if (!list.length) {
      tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">No members found.</td></tr>';
      buildUserPagination(_userTotal); return;
    }
    tbody.innerHTML = list.map(function(u){ return renderMemberRow(u); }).join('');
    buildUserPagination(_userTotal);
  } catch(e) { tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Error: ' + esc(e.message) + '</td></tr>'; }
}

function renderMemberRow(u) {
  var ini = ((u.full_name||u.username||'?').split(' ').map(function(w){return w[0]||'';})).join('').toUpperCase().slice(0,2);
  var av  = u.avatar_url
    ? '<img src="'+esc(typeof avatarBust==='function'?avatarBust(u.avatar_url,u.id,u.last_seen):u.avatar_url)+'" style="width:34px;height:34px;border-radius:50%;object-fit:cover;flex-shrink:0">'
    : '<div style="width:34px;height:34px;border-radius:50%;background:linear-gradient(135deg,var(--accent),#8a6a28);display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;color:#fff;flex-shrink:0">'+ini+'</div>';
  var jd = u.created_at ? new Date(u.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : '\u2014';
  var statusColor = {
    'Active':'#4caf76','Administrator':'var(--accent)','Flagged':'#E86D4A',
    'Temporarily Deactivated':'#d4a017','Permanently Deactivated':'#dc5050','Deactivated':'#dc5050'
  }[u.account_status] || 'var(--text-mid)';
  var badges = (u.badges||[]).map(function(b){ return '<span style="font-size:9px;padding:2px 6px;border-radius:10px;background:rgba(255,255,255,0.08);color:var(--accent);margin-right:3px">'+esc(formatBadgeLabel(b))+'</span>'; }).join('');
  var planBadge = u.plan === 'premium'
    ? '<span style="font-size:9px;padding:2px 7px;border-radius:10px;background:var(--accent);color:#fff;font-weight:700">PREMIUM</span>'
    : '<span style="font-size:9px;padding:2px 7px;border-radius:10px;background:rgba(255,255,255,0.06);color:var(--text-mid)">FREE</span>';
  return '<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">' +
    '<td class="ap-td"><input type="checkbox" data-uid="'+esc(u.id)+'" class="user-checkbox" onchange="toggleUserSelect(this)"></td>' +
    '<td class="ap-td"><div style="display:flex;align-items:center;gap:10px">'+av+'<div>' +
      '<div style="font-weight:500;color:var(--text-high)">'+esc(u.full_name||u.username||'\u2014')+'</div>' +
      '<div style="font-size:11px;color:var(--text-mid)">@'+esc(u.username||'')+'</div>' +
      (badges ? '<div style="margin-top:3px">'+badges+'</div>' : '') +
    '</div></div></td>' +
    '<td class="ap-td" style="font-size:12px">'+esc(u.email)+'</td>' +
    '<td class="ap-td" style="font-size:12px;color:var(--text-mid);white-space:nowrap">'+jd+'</td>' +
    '<td class="ap-td" style="text-align:center;font-size:12px"><span title="Submitted / Approved" style="color:var(--text-high)">'+(u.recipe_count||0)+'</span> <span style="color:var(--text-mid)">/ '+(u.approved_count||0)+'</span></td>' +
    '<td class="ap-td"><span style="font-size:11px;font-weight:600;color:'+statusColor+'">'+esc(u.account_status||'Active')+'</span>' +
      (u.deactivation_expires_at ? '<br><span style="font-size:10px;color:var(--text-mid)">until '+new Date(u.deactivation_expires_at).toLocaleDateString('en-GB',{day:'numeric',month:'short'})+'</span>' : '') + '</td>' +
    '<td class="ap-td">'+planBadge+'</td>' +
    '<td class="ap-td"><button data-action="view-user" data-uid="'+esc(u.id)+'" style="padding:5px 12px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer;margin-right:4px">View</button>' +
    (u.is_active
      ? '<button data-action="deactivate-user" data-uid="'+esc(u.id)+'" style="padding:5px 12px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer">Deactivate</button>'
      : '<button data-action="reactivate-user" data-uid="'+esc(u.id)+'" style="padding:5px 12px;background:none;border:1px solid #4caf76;border-radius:6px;color:#4caf76;font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer">Reactivate</button>'
    ) + '</td></tr>';
}

function buildUserPagination(total) {
  var wrap = document.getElementById('umgmt-pagination');
  if (!wrap) return;
  wrap.innerHTML = '';
  var totalPages = Math.ceil(total / _userPageSize);
  if (totalPages <= 1) { wrap.style.display = 'none'; return; }
  wrap.style.display = 'flex';
  var btnStyle = "padding:6px 12px;background:none;border:1px solid var(--border);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);cursor:pointer";
  var activeStyle = "padding:6px 12px;background:var(--accent);border:1px solid var(--accent);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:12px;color:#fff;cursor:default";
  function btn(label, page, disabled, active) {
    var b = document.createElement('button');
    b.textContent = label; b.style.cssText = active ? activeStyle : btnStyle;
    b.disabled = disabled || active;
    if (!disabled && !active) b.addEventListener('click', function(){ loadMembers(page); });
    return b;
  }
  wrap.appendChild(btn('\u2190 Prev', _userPage-1, _userPage<=1, false));
  var pages = totalPages <= 7 ? Array.from({length:totalPages},function(_,i){return i+1;})
    : [1,2].concat(_userPage>4?['...']:[]).concat(
        Array.from({length:3},function(_,i){return Math.max(3,_userPage-1)+i;}).filter(function(p){return p>2&&p<totalPages-1;})
      ).concat(_userPage<totalPages-3?['...']:[]).concat([totalPages-1,totalPages]);
  pages.forEach(function(p){
    if(p==='...'){var s=document.createElement('span');s.textContent='\u2026';s.style.cssText="padding:6px 4px;font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)";wrap.appendChild(s);}
    else wrap.appendChild(btn(String(p),p,false,p===_userPage));
  });
  wrap.appendChild(btn('Next \u2192', _userPage+1, _userPage>=totalPages, false));
  var info = document.createElement('span');
  info.style.cssText = "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);margin-left:8px;align-self:center";
  info.textContent = 'Page ' + _userPage + ' of ' + totalPages;
  wrap.appendChild(info);
}

// ── BULK ACTIONS ──────────────────────────────────────────────────

function toggleSelectAllUsers(checked) {
  document.querySelectorAll('.user-checkbox').forEach(function(cb){
    cb.checked = checked;
    toggleUserSelect(cb);
  });
}

function toggleUserSelect(cb) {
  var uid = cb.dataset.uid;
  if (cb.checked) _selectedUsers[uid] = true; else delete _selectedUsers[uid];
  var count = Object.keys(_selectedUsers).length;
  var bulkBtn = document.getElementById('umgmt-bulk-deact');
  if (bulkBtn) { bulkBtn.style.display = count > 0 ? 'block' : 'none'; bulkBtn.textContent = 'Deactivate ' + count + ' Selected'; }
  var badgeBtn = document.getElementById('umgmt-bulk-badge');
  if (badgeBtn) badgeBtn.style.display = count > 0 ? 'block' : 'none';
}

async function bulkDeactivateUsers() {
  var ids = Object.keys(_selectedUsers);
  if (!ids.length) return;
  if (!confirm('Permanently deactivate ' + ids.length + ' user' + (ids.length===1?'':'s') + '?')) return;
  var reason = prompt('Reason for bulk deactivation (required):');
  if (!reason || !reason.trim()) { alert('Reason is required.'); return; }
  try {
    for (var i=0; i<ids.length; i++) {
      await rpc('admin_deactivate_user',{p_user_id:ids[i],p_type:'permanent',p_days:null,p_reason:reason.trim()});
    }
    _selectedUsers = {};
    auditLog('User Management','Bulk Deactivation',null,null,ids.length+' users',reason.trim());
    loadMembers(_userPage);
  } catch(e) { alert('Error: '+e.message); }
}

// ── DEACTIVATION MODAL ────────────────────────────────────────────
var _deactUserId = null;

function showDeactivateModal(uid, username) {
  _deactUserId = uid;
  var overlay = document.createElement('div');
  overlay.id = 'deact-overlay';
  overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:10000;display:flex;align-items:center;justify-content:center';
  overlay.innerHTML =
    '<div style="background:var(--bg);border:1px solid var(--border);border-radius:14px;padding:28px 32px;width:460px;max-width:95vw;font-family:\'DM Sans\',sans-serif">' +
      '<div style="font-family:\'Cormorant Garamond\',serif;font-size:1.1rem;font-weight:700;color:var(--text-high);margin-bottom:4px">Deactivate Account</div>' +
      '<div style="font-size:12px;color:var(--text-mid);margin-bottom:20px">@'+esc(username)+'</div>' +
      '<div style="margin-bottom:16px">' +
        '<div style="font-size:11px;font-weight:600;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:8px">Type</div>' +
        '<div style="display:flex;gap:10px">' +
          '<label style="flex:1;display:flex;align-items:center;gap:8px;padding:10px 14px;border:1px solid var(--border);border-radius:8px;cursor:pointer;font-size:13px;color:var(--text-high)">' +
            '<input type="radio" name="deact-type" value="temporary" id="deact-temp" style="accent-color:var(--accent)"> Temporary' +
          '</label>' +
          '<label style="flex:1;display:flex;align-items:center;gap:8px;padding:10px 14px;border:1px solid var(--border);border-radius:8px;cursor:pointer;font-size:13px;color:var(--text-high)">' +
            '<input type="radio" name="deact-type" value="permanent" id="deact-perm" checked style="accent-color:var(--accent)"> Permanent' +
          '</label>' +
        '</div>' +
      '</div>' +
      '<div id="deact-duration" style="margin-bottom:16px;display:none">' +
        '<div style="font-size:11px;font-weight:600;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:8px">Duration</div>' +
        '<div style="display:flex;gap:8px;flex-wrap:wrap">' +
          '<button onclick="setDeactDuration(7)"  class="deact-dur-btn" data-days="7"  style="padding:7px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:12px;cursor:pointer">7 days</button>' +
          '<button onclick="setDeactDuration(14)" class="deact-dur-btn" data-days="14" style="padding:7px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:12px;cursor:pointer">14 days</button>' +
          '<button onclick="setDeactDuration(30)" class="deact-dur-btn" data-days="30" style="padding:7px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:12px;cursor:pointer">30 days</button>' +
          '<input type="number" id="deact-custom-days" placeholder="Custom days" min="1" max="365" style="width:120px;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:\'DM Sans\',sans-serif;font-size:12px;color:var(--text-high)">' +
        '</div>' +
      '</div>' +
      '<div style="margin-bottom:20px">' +
        '<div style="font-size:11px;font-weight:600;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:8px">Reason <span style="color:#dc5050">*</span></div>' +
        '<textarea id="deact-reason" placeholder="Internal reason — not shown to user" rows="3" style="width:100%;box-sizing:border-box;padding:10px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-high);resize:vertical"></textarea>' +
      '</div>' +
      '<div style="display:flex;gap:10px;justify-content:flex-end">' +
        '<button onclick="closeDeactivateModal()" style="padding:8px 20px;background:none;border:1px solid var(--border);border-radius:8px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:13px;cursor:pointer">Cancel</button>' +
        '<button onclick="confirmDeactivation()" style="padding:8px 20px;background:#dc5050;border:none;border-radius:8px;color:#fff;font-family:\'DM Sans\',sans-serif;font-size:13px;font-weight:600;cursor:pointer">Deactivate</button>' +
      '</div>' +
    '</div>';
  document.body.appendChild(overlay);
  // Toggle duration panel on type change
  document.querySelectorAll('input[name="deact-type"]').forEach(function(r){
    r.addEventListener('change', function(){
      document.getElementById('deact-duration').style.display = r.value === 'temporary' ? 'block' : 'none';
    });
  });
}
var _deactDays = null;

function closeDeactivateModal() {
  var el = document.getElementById('deact-overlay');
  if (el) el.remove();
  _deactDays = null;
}

async function confirmDeactivation() {
  var type   = document.querySelector('input[name="deact-type"]:checked').value;
  var reason = (document.getElementById('deact-reason').value||'').trim();
  var custom = parseInt(document.getElementById('deact-custom-days').value||'0');
  var days   = type === 'temporary' ? (custom > 0 ? custom : _deactDays) : null;
  if (!reason) { alert('Reason is required.'); return; }
  if (type === 'temporary' && !days) { alert('Please select or enter a duration.'); return; }
  var confirmBtn = document.querySelector('#deact-overlay button:last-child');
  if (confirmBtn) { confirmBtn.disabled = true; confirmBtn.textContent = 'Deactivating\u2026'; }
  try {
    await rpc('admin_deactivate_user',{p_user_id:_deactUserId,p_type:type,p_days:days,p_reason:reason});
    auditLog('User Management','Account Deactivated',null,_deactUserId,type,reason);
    closeDeactivateModal();
    loadMembers(_userPage);
    if (_userDetailOpen) { openUserDetail(_deactUserId); }
  } catch(e) { if(confirmBtn){confirmBtn.disabled=false;confirmBtn.textContent='Deactivate';} alert('Error: '+e.message); }
}

async function openUserDetail(uid) {
  _detailUser = { id: uid }; // Will be populated with full profile below
  _userDetailOpen = true;
  var existing = document.getElementById('user-detail-panel');
  if (existing) existing.remove();
  var panel = document.createElement('div');
  panel.id = 'user-detail-panel';
  panel.style.cssText = 'position:fixed;top:0;right:0;width:500px;max-width:100vw;height:100vh;background:var(--bg);border-left:1px solid var(--border);z-index:9999;overflow-y:auto;box-shadow:-8px 0 32px rgba(0,0,0,0.4)';
  panel.innerHTML = '<div style="padding:24px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  document.body.appendChild(panel);
  try {
    var raw  = await rpc('admin_get_user_detail', {p_user_id: uid});
    var data = Array.isArray(raw) ? raw[0] : raw;
    var p    = data.profile || {};
    var ini  = ((p.full_name||p.username||'?').split(' ').map(function(w){return w[0]||'';})).join('').toUpperCase().slice(0,2);
    var statusColor = {'Active':'#4caf76','Administrator':'var(--accent)','Flagged':'#E86D4A','Temporarily Deactivated':'#d4a017','Permanently Deactivated':'#dc5050','Deactivated':'#dc5050'}[p.account_status]||'var(--text-mid)';
    var badges = p.badges || [];
    var allBadges = ['Trusted Contributor','Guest Chef','100 Recipes','50 Recipes','Early Member','Journal Pick'];
    var loginMethodLabel = p.login_method === 'google' ? '\uD83D\uDD35 Google OAuth' : '\uD83D\uDCE7 Email / Password';

    panel.innerHTML =
      '<div style="display:flex;align-items:center;justify-content:space-between;padding:18px 20px 0;border-bottom:1px solid var(--border);padding-bottom:14px">' +
        '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;color:var(--text-high)">Member Profile</div>' +
        '<button onclick="closeUserDetail()" style="background:none;border:none;color:var(--text-mid);font-size:18px;cursor:pointer;padding:4px 8px">\u2715</button>' +
      '</div>' +
      '<div style="padding:18px 20px;display:flex;align-items:center;gap:14px;border-bottom:1px solid var(--border)">' +
        (p.avatar_url ? '<img src="'+esc(typeof avatarBust==='function'?avatarBust(p.avatar_url,p.id,p.last_seen):p.avatar_url)+'" style="width:54px;height:54px;border-radius:50%;object-fit:cover">'
          : '<div style="width:54px;height:54px;border-radius:50%;background:linear-gradient(135deg,var(--accent),#8a6a28);display:flex;align-items:center;justify-content:center;font-size:18px;font-weight:700;color:#fff">'+ini+'</div>') +
        '<div>' +
          '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;color:var(--text-high)">'+esc(p.full_name||p.username||'\u2014')+'</div>' +
          '<div style="font-size:12px;color:var(--text-mid)">@'+esc(p.username||'')+'</div>' +
          '<div style="margin-top:5px;display:flex;gap:8px;flex-wrap:wrap">' +
            '<span style="font-size:11px;font-weight:600;color:'+statusColor+'">'+esc(p.account_status||'Active')+'</span>' +
            '<span style="font-size:11px;color:var(--text-mid)">'+loginMethodLabel+'</span>' +
            (p.email_verified?'<span style="font-size:11px;color:#4caf76">\u2713 Email Verified</span>':'<span style="font-size:11px;color:#d4a017">\u26a0 Unverified</span>') +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:0;border-bottom:1px solid var(--border)">' +
        _uStat('Submitted',data.recipe_count||0) +_uStat('Approved',data.approved_count||0) +
        _uStat('Rejected',data.rejected_count||0) +_uStat('Pending',data.pending_count||0) +
      '</div>' +
      '<div style="padding:14px 20px;border-bottom:1px solid var(--border)">' +
        _uRow('Email', esc(p.email||'\u2014')) +
        _uRow('Joined', p.created_at?new Date(p.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'long',year:'numeric'}):'\u2014') +
        _uRow('Plan', (p.plan||'free').charAt(0).toUpperCase()+(p.plan||'free').slice(1)) +
        _uRow('Admin', p.is_admin?'<span style="color:var(--accent)">Yes</span>':'No') +
        _uRow('Theme', esc(p.theme_preference||'\u2014')) +
        (p.deactivation_reason?_uRow('Deactivation Reason','<span style="color:#dc5050">'+esc(p.deactivation_reason)+'</span>'):'')+
      '</div>' +
      '<div style="padding:14px 20px;border-bottom:1px solid var(--border)">' +
        '<div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:10px">Badges</div>' +
        '<div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:8px">' +
          (badges.length?badges.map(function(b){return '<span style="display:inline-flex;align-items:center;gap:5px;padding:4px 10px;border-radius:12px;background:rgba(255,255,255,0.08);color:var(--accent);font-size:11px">'+esc(formatBadgeLabel(b))+'<button data-action="remove-badge" data-uid="'+esc(uid)+'" data-badge="'+esc(b)+'" style="background:none;border:none;color:var(--text-mid);cursor:pointer;font-size:12px;padding:0;line-height:1">\u2715</button></span>';}).join(''):
            '<span style="font-size:12px;color:var(--text-mid)">No badges yet</span>') +
        '</div>' +
        '<div style="display:flex;gap:5px;flex-wrap:wrap">' +
          allBadges.filter(function(b){return !userHasBadge(badges, b);}).map(function(b){
            return '<button data-action="award-badge" data-uid="'+esc(uid)+'" data-badge="'+esc(b)+'" style="padding:3px 9px;background:none;border:1px solid var(--border);border-radius:9px;color:var(--text-mid);font-size:10px;cursor:pointer">+ '+esc(b)+'</button>';
          }).join('') +
        '</div>' +
      '</div>' +
      (data.recent_recipes&&data.recent_recipes.length?
        '<div style="padding:14px 20px;border-bottom:1px solid var(--border)">' +
          '<div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:10px">Recent Recipes</div>' +
          data.recent_recipes.map(function(r){
            var sc={'approved':'#4caf76','rejected':'#dc5050','pending':'#d4a017'}[r.status]||'var(--text-mid)';
            return '<div style="display:flex;justify-content:space-between;padding:4px 0;border-bottom:1px solid rgba(255,255,255,0.03)">' +
              '<span style="font-size:12px;color:var(--text-high)">'+esc(r.title||'\u2014')+'</span>' +
              '<span style="font-size:11px;font-weight:600;color:'+sc+'">'+esc(r.status)+'</span></div>';
          }).join('')+
        '</div>':'') +
      '<div style="padding:14px 20px;border-bottom:1px solid var(--border)">' +
        '<div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:8px">Internal Notes</div>' +
        (data.notes&&data.notes.length?data.notes.map(function(n){
          var nd=new Date(n.created_at);var MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          return '<div style="padding:7px 10px;background:rgba(255,255,255,0.04);border-radius:7px;margin-bottom:6px">' +
            '<div style="font-size:12px;color:var(--text-high)">'+esc(n.note)+'</div>' +
            '<div style="font-size:10px;color:var(--text-mid);margin-top:3px">'+nd.getDate()+' '+MONTHS[nd.getMonth()]+' '+nd.getFullYear()+(n.created_by?' by @'+esc(n.created_by):'')+'</div></div>';
        }).join(''):'<div style="font-size:12px;color:var(--text-mid)">No notes.</div>') +
        '<div style="display:flex;gap:7px;margin-top:8px">' +
          '<textarea id="ud-note-input" placeholder="Add internal note..." rows="2" style="flex:1;padding:7px 9px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);resize:none"></textarea>' +
          '<button onclick="doAddNote(\''+esc(uid)+'\')" style="padding:8px 14px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;align-self:flex-end">Add</button>' +
        '</div>' +
      '</div>' +
      '<div style="padding:14px 20px">' +
        '<div style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:10px">Actions</div>' +
        '<div style="display:flex;flex-direction:column;gap:7px">' +
          (p.is_active!==false
            ?'<button onclick="showDeactivateModal_current();closeUserDetail()" style="padding:8px 14px;background:none;border:1px solid #dc5050;border-radius:7px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;text-align:left">Deactivate Account</button>'
            :'<button onclick="confirmReactivate_current()" style="padding:8px 14px;background:none;border:1px solid #4caf76;border-radius:7px;color:#4caf76;font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;text-align:left">Reactivate Account</button>') +
          '<button onclick="doToggleFlag(\''+esc(uid)+'\','+(p.flagged?'true':'false')+')" style="padding:8px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;text-align:left">'+(p.flagged?'Remove Flag':'Flag Account')+'</button>' +
          '<button onclick="doToggleAdmin(\''+esc(uid)+'\','+(p.is_admin?'true':'false')+')" style="padding:8px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;text-align:left">'+(p.is_admin?'Remove Admin Access':'Grant Admin Access')+'</button>' +
          '<button onclick="doSendEmailToUser_current()" style="padding:8px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;text-align:left">\u2709\ufe0f Send Email</button>' +
          '<button onclick="doExportUserData_current()" style="padding:8px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;text-align:left">\uD83D\uDCC4 Export Data (GDPR)</button>' +
        '</div>' +
      '</div>';
  } catch(e) {
    panel.innerHTML = '<div style="padding:24px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>';
  }
}

function _uStat(label, val) {
  return '<div style="padding:14px 16px;text-align:center;border-right:1px solid var(--border)">' +
    '<div style="font-family:\'Cormorant Garamond\',serif;font-size:1.4rem;font-weight:700;color:var(--accent)">'+val+'</div>' +
    '<div style="font-family:\'DM Sans\',sans-serif;font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid)">'+label+'</div>' +
  '</div>';
}

function _uRow(label, val) {
  return '<div style="display:flex;justify-content:space-between;align-items:flex-start;padding:4px 0;border-bottom:1px solid rgba(255,255,255,0.04)">' +
    '<span style="font-family:\'DM Sans\',sans-serif;font-size:11px;color:var(--text-mid)">'+label+'</span>' +
    '<span style="font-family:\'DM Sans\',sans-serif;font-size:12px;color:var(--text-high);text-align:right;max-width:250px">'+val+'</span>' +
  '</div>';
}

function closeUserDetail() {
  _userDetailOpen = false;
  var el = document.getElementById('user-detail-panel');
  if (el) el.remove();
}

async function doAwardBadge(uid, badge) {
  try { await rpc('admin_award_badge',{p_user_id:uid,p_badge:badge}); auditLog('User Management','Badge Awarded',null,null,badge,null); openUserDetail(uid); loadMembers(_userPage); }
  catch(e) { alert('Error: '+e.message); }
}

async function doRemoveBadge(uid, badge) {
  if (!confirm('Remove badge "'+badge+'"?')) return;
  try { await rpc('admin_remove_badge',{p_user_id:uid,p_badge:badge}); auditLog('User Management','Badge Removed',null,badge,null,null); openUserDetail(uid); loadMembers(_userPage); }
  catch(e) { alert('Error: '+e.message); }
}

async function loadPendingUsers() {
  var tbody = document.getElementById('upending-tbody');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="5" class="ap-empty-row">Loading\u2026</td></tr>';
  try {
    var rows = await rpc('admin_get_users',{p_search:null,p_status:null,p_limit:100,p_offset:0});
    var list = (rows||[]).filter(function(u){ return !u.is_active; });
    setEl('badge-pending-users', list.length);
    if (!list.length) { tbody.innerHTML = '<tr><td colspan="5" class="ap-empty-row">No inactive accounts.</td></tr>'; return; }
    tbody.innerHTML = list.map(function(u){
      var ini = ((u.full_name||u.username||'?').split(' ').map(function(w){return w[0]||'';})).join('').toUpperCase().slice(0,2);
      var av  = u.avatar_url ? '<img src="'+esc(typeof avatarBust==='function'?avatarBust(u.avatar_url,u.id,u.last_seen):u.avatar_url)+'" style="width:30px;height:30px;border-radius:50%;object-fit:cover">'
        : '<div style="width:30px;height:30px;border-radius:50%;background:linear-gradient(135deg,var(--accent),#8a6a28);display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;color:#fff">'+ini+'</div>';
      var jd = u.created_at ? new Date(u.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : '\u2014';
      return '<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">' +
        '<td class="ap-td"><div style="display:flex;align-items:center;gap:8px">'+av+'<div><div style="font-size:13px;font-weight:500;color:var(--text-high)">'+esc(u.full_name||u.username)+'</div><div style="font-size:11px;color:var(--text-mid)">@'+esc(u.username)+'</div></div></div></td>' +
        '<td class="ap-td" style="font-size:12px">'+esc(u.email)+'</td>' +
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+jd+'</td>' +
        '<td class="ap-td"><span style="font-size:11px;font-weight:600;color:#dc5050">'+esc(u.account_status||'Deactivated')+'</span></td>' +
        '<td class="ap-td">' +
          '<button onclick="openUserDetail(\''+esc(u.id)+'\')" style="padding:5px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer;margin-right:4px">View</button>' +
          '<button data-action="reactivate-user" data-uid=""+esc(u.id)+"" style="padding:5px 10px;background:none;border:1px solid #4caf76;border-radius:6px;color:#4caf76;font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer">Reactivate</button>' +
        '</td></tr>';
    }).join('');
  } catch(e) { tbody.innerHTML = '<tr><td colspan="5" class="ap-empty-row">Error: '+esc(e.message)+'</td></tr>'; }
}

// ── UM INTERFACE ──────────────────────────────────────────────────

async function loadUMDeactivated(container) {
  container.innerHTML = '<div style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = [];
    if (typeof TcjAdminUsers !== 'undefined') {
      rows = await TcjAdminUsers.fetchAll({p_search:null,p_status:'deactivated'});
    } else {
      rows = await rpc('admin_get_users',{p_search:null,p_status:'deactivated',p_limit:200,p_offset:0});
    }
    var list = rows || [];
    container.innerHTML = '';
    var title = document.createElement('div');
    title.style.cssText = "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:16px";
    title.textContent = list.length + ' deactivated account' + (list.length===1?'':'s');
    container.appendChild(title);
    if (!list.length) { container.innerHTML += '<div style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid)">No deactivated accounts.</div>'; return; }
    var tbl = document.createElement('div');
    tbl.style.cssText = 'overflow-x:auto;border:1px solid var(--border);border-radius:12px';
    tbl.innerHTML = '<table style="width:100%;border-collapse:collapse">' +
      '<thead><tr style="border-bottom:1px solid var(--border)">' +
        '<th class="ap-th">Member</th><th class="ap-th">Type</th><th class="ap-th">Reason</th><th class="ap-th">Expires</th><th class="ap-th">Actions</th>' +
      '</tr></thead>' +
      '<tbody>' + list.map(function(u){
        var exp = u.deactivation_expires_at ? new Date(u.deactivation_expires_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : 'Never';
        return '<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">' +
          '<td class="ap-td"><div style="font-size:13px;font-weight:500;color:var(--text-high)">'+esc(u.full_name||u.username)+'</div><div style="font-size:11px;color:var(--text-mid)">@'+esc(u.username)+'</div></td>' +
          '<td class="ap-td"><span style="font-size:11px;font-weight:600;color:'+((u.deactivation_type==='permanent')?'#dc5050':'#d4a017')+'">'+esc(u.deactivation_type||'N/A')+'</span></td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid);max-width:200px">'+esc(u.deactivation_reason||'\u2014')+'</td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+exp+'</td>' +
          '<td class="ap-td"><button data-action="reactivate-user" data-uid=""+esc(u.id)+"" style="padding:5px 12px;background:none;border:1px solid #4caf76;border-radius:6px;color:#4caf76;font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer">Reactivate</button></td>' +
        '</tr>';
      }).join('') + '</tbody></table>';
    container.appendChild(tbl);
  } catch(e) { container.innerHTML = '<div style="color:#dc5050;font-family:\'DM Sans\',sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>'; }
}

// Chef Directory

async function loadUMChefs(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var current = await rpc('get_chef_of_month', {});
    if (current === null) current = null;
    var users = [];
    if (typeof TcjAdminUsers !== 'undefined') {
      users = await TcjAdminUsers.fetchAll({ p_search: null, p_status: 'active' });
    } else {
      console.warn('Chef directory: TcjAdminUsers not loaded — reload dashboard');
    }
    if (!users.length && typeof TcjAdminProfiles !== 'undefined') {
      users = await TcjAdminProfiles.fetchAllActiveRest(apiFetch, SUPABASE_URL);
    }

    container.innerHTML = '';
    function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }

    var title = mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:16px", 'Chef Directory');
    container.appendChild(title);

    var comCard = mk('div', 'padding:20px;background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;margin-bottom:16px');
    comCard.appendChild(mk('div', 'font-size:1.4rem;margin-bottom:8px', '\uD83C\uDFC6'));
    comCard.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:#C4973B;margin-bottom:6px", 'Chef of the Month'));
    comCard.appendChild(mk('p', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin:0 0 14px;line-height:1.6', 'Featured contributor on the homepage. Expires automatically after 30 days.'));

    if (current && current.username) {
      var cur = mk('div', 'padding:10px 14px;background:rgba(196,151,59,0.08);border:1px solid rgba(196,151,59,0.25);border-radius:8px;margin-bottom:12px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)');
      cur.innerHTML = 'Current: <strong>@' + esc(current.username) + '</strong>' +
        (current.recipe_count ? ' \u00b7 ' + current.recipe_count + ' recipes' : '') +
        (current.chef_of_month_expires ? '<div style="font-size:11px;color:var(--text-mid);margin-top:4px">Expires ' + new Date(current.chef_of_month_expires).toLocaleDateString('en-GB') + '</div>' : '');
      comCard.appendChild(cur);
      var clearBtn = mk('button', 'margin-bottom:14px;padding:6px 14px;background:none;border:1px solid #dc5050;border-radius:7px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer', 'Clear Chef of the Month');
      clearBtn.addEventListener('click', async function () {
        if (!confirm('Clear Chef of the Month?')) return;
        try { await rpc('admin_set_chef_of_month', { p_user_id: null }); loadUMChefs(container); } catch (e) { alert(e.message); }
      });
      comCard.appendChild(clearBtn);
    }

    var sel = document.createElement('select');
    sel.style.cssText = 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);margin-bottom:10px';
    var blank = document.createElement('option'); blank.value = ''; blank.textContent = '\u2014 Select contributor \u2014'; sel.appendChild(blank);
    (users || []).forEach(function (u) {
      if (!u.id || !u.username) return;
      var o = document.createElement('option');
      o.value = u.id;
      o.textContent = '@' + u.username + (u.full_name ? ' (' + u.full_name + ')' : '');
      if (current && current.id === u.id) o.selected = true;
      sel.appendChild(o);
    });
    comCard.appendChild(sel);
    var setBtn = mk('button', 'padding:8px 18px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer', 'Set Chef of the Month');
    setBtn.addEventListener('click', async function () {
      var uid = sel.value;
      if (!uid) { alert('Select a contributor first.'); return; }
      if (!confirm('Set this contributor as Chef of the Month for 30 days?')) return;
      try {
        await rpc('admin_set_chef_of_month', { p_user_id: uid });
        loadUMChefs(container);
      } catch (e) { alert(e.message); }
    });
    comCard.appendChild(setBtn);
    container.appendChild(comCard);

    var guestCard = mk('div', 'padding:20px;background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px');
    guestCard.innerHTML = '<div style="font-size:1.4rem;margin-bottom:8px">\uD83D\uDC68\u200D\uD83C\uDF73</div>' +
      '<div style="font-family:\'Cormorant Garamond\',serif;font-size:1rem;font-weight:700;color:#5B8FD4;margin-bottom:6px">Guest Chefs</div>' +
      '<div style="font-family:\'DM Sans\',sans-serif;font-size:12px;color:var(--text-mid)">Award the Guest Chef badge via User Management. Invite professionals via the Invite System tab.</div>';
    container.appendChild(guestCard);
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

// Family Profile reference lists (E 1.4 / 1.5)

async function loadUMFamilyRefs(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  var CATS = [
    {key:'relationship', label:'Relationship'},
    {key:'age_group', label:'Age Group (Range)'},
    {key:'dietary_needs', label:'Dietary Needs'},
    {key:'allergies', label:'Allergies'},
    {key:'health_conditions', label:'Health Conditions'}
  ];
  try {
    var rows = await rpc('get_family_reference_lists', {p_category: null}) || [];
    container.innerHTML = '';
    var note = document.createElement('div');
    note.style.cssText = 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.6';
    note.textContent = 'Admin-managed picklists for Family Profiles. Changes apply to new edits; existing saved values are kept. Age groups use the seven standard ranges plus 65+.';
    container.appendChild(note);
    CATS.forEach(function(cat) {
      var items = rows.filter(function(r){ return r.category === cat.key; });
      var box = document.createElement('div');
      box.style.cssText = 'margin-bottom:20px;padding:16px;background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:12px';
      box.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:var(--accent);margin-bottom:10px">'+esc(cat.label)+'</div>';
      var list = document.createElement('div');
      list.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin-bottom:10px';
      items.forEach(function(it) {
        var pill = document.createElement('span');
        pill.style.cssText = 'display:inline-flex;align-items:center;gap:6px;padding:6px 12px;border:1px solid var(--border);border-radius:20px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
        pill.textContent = it.value;
        list.appendChild(pill);
      });
      if (!items.length) list.innerHTML = '<span style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid)">No items</span>';
      box.appendChild(list);
      var addRow = document.createElement('div');
      addRow.style.cssText = 'display:flex;gap:8px;flex-wrap:wrap';
      var inp = document.createElement('input');
      inp.placeholder = 'Add ' + cat.label.toLowerCase() + '\u2026';
      inp.style.cssText = 'flex:1;min-width:160px;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
      var btn = document.createElement('button');
      btn.textContent = 'Add';
      btn.style.cssText = 'padding:8px 16px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer';
      btn.addEventListener('click', async function() {
        var v = inp.value.trim();
        if (!v) return;
        try {
          await rpc('admin_upsert_family_reference', {p_id: null, p_category: cat.key, p_value: v, p_sort_order: items.length + 1});
          loadUMFamilyRefs(container);
        } catch (e) { alert(e.message); }
      });
      addRow.appendChild(inp);
      addRow.appendChild(btn);
      box.appendChild(addRow);
      container.appendChild(box);
    });
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

// Invite System

async function buildFiMembers(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var res = await apiFetch(SUPABASE_URL + '/rest/v1/profiles?select=id,username,full_name,email,subscription_tier,is_active&order=subscription_tier.desc,created_at.desc&limit=100');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var members = await res.json();
    if (!Array.isArray(members)||!members.length) { container.innerHTML='<div style="padding:16px;font-size:13px;color:var(--text-mid)">No members found.</div>'; return; }

    container.innerHTML = '';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}

    // Search + filter
    var toolbar = mk('div','display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap');
    var search = mk('input','flex:1;min-width:180px;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
    search.placeholder = 'Search by name or email\u2026';
    var filter = mk('select','padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
    ['All Tiers','free','daily','weekly','monthly','yearly','premium','event'].forEach(function(t){var o=document.createElement('option');o.value=t==='All Tiers'?'':t;o.textContent=t==='All Tiers'?'All Tiers':t.charAt(0).toUpperCase()+t.slice(1);filter.appendChild(o);});
    toolbar.appendChild(search); toolbar.appendChild(filter);
    container.appendChild(toolbar);

    var wrap = mk('div','overflow-x:auto;border:1px solid var(--border);border-radius:12px');
    var tbl  = document.createElement('table'); tbl.className='ap-table';
    tbl.innerHTML = '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Member</th><th class="ap-th">Email</th><th class="ap-th">Current Tier</th><th class="ap-th">Change Tier</th><th class="ap-th">Save</th></tr></thead>';
    var tbody = document.createElement('tbody');

    var TIER_COLOR = { free:'var(--text-mid)', daily:'#8ab4d4', weekly:'#6a9fd4', monthly:'#5B8FD4', yearly:'var(--accent)', premium:'var(--accent)', event:'#5B8FD4' };

    function renderRow(m) {
      var tr = document.createElement('tr'); tr.style.borderBottom='1px solid rgba(255,255,255,0.04)';
      tr.dataset.name  = (m.full_name||'').toLowerCase();
      tr.dataset.email = (m.email||'').toLowerCase();
      tr.dataset.tier  = m.subscription_tier||'free';

      var tier = m.subscription_tier || 'free';
      var sel = '<select id="fit-'+m.id+'" style="padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
        ['free','daily','weekly','monthly','yearly','premium','event'].map(function(t){return '<option value="'+t+'"'+(tier===t?' selected':'')+'>'+t.charAt(0).toUpperCase()+t.slice(1)+'</option>';}).join('')+'</select>';
      tr.innerHTML =
        '<td class="ap-td"><div style="font-size:13px;font-weight:500;color:var(--text-high)">'+(m.full_name||m.username||'—')+'</div><div style="font-size:11px;color:var(--text-mid)">@'+(m.username||'')+'</div></td>'+
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+(m.email||'')+'</td>'+
        '<td class="ap-td"><span style="font-size:11px;font-weight:700;padding:3px 10px;border-radius:20px;background:rgba(255,255,255,0.07);color:'+TIER_COLOR[tier]+'">'+tier+'</span></td>'+
        '<td class="ap-td">'+sel+'</td>'+
        '<td class="ap-td"></td>';

      var btn = document.createElement('button'); btn.textContent='Save'; btn.style.cssText="padding:5px 12px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-size:11px;cursor:pointer";
      btn.addEventListener('click', (function(uid,b,row){return async function(){
        b.disabled=true;b.textContent='\u2026';
        var newTier = document.getElementById('fit-'+uid).value;
        var notesVal = newTier !== (row.dataset.tier) ? 'Changed from '+row.dataset.tier+' to '+newTier+' by admin' : null;
        try {
          await rpc('admin_set_member_tier',{p_user_id:uid,p_tier:newTier,p_notes:notesVal});
          row.dataset.tier = newTier;
          var badge = row.querySelector('td:nth-child(3) span');
          if(badge){badge.textContent=newTier;badge.style.color=TIER_COLOR[newTier]||'var(--text-mid)';}
          b.textContent='\u2713';setTimeout(function(){b.textContent='Save';b.disabled=false;},2000);
        } catch(e){b.textContent='Save';b.disabled=false;alert('Error: '+e.message);}
      };})(m.id,btn,tr));
      tr.lastElementChild.appendChild(btn);
      tbody.appendChild(tr);
    }

    members.forEach(renderRow);
    tbl.appendChild(tbody); wrap.appendChild(tbl); container.appendChild(wrap);

    // Live search + filter
    function filterTable() {
      var q = search.value.toLowerCase();
      var t = filter.value;
      tbody.querySelectorAll('tr').forEach(function(row){
        var matchQ = !q || row.dataset.name.includes(q) || row.dataset.email.includes(q);
        var matchT = !t || row.dataset.tier === t;
        row.style.display = (matchQ && matchT) ? '' : 'none';
      });
    }
    search.addEventListener('input', filterTable);
    filter.addEventListener('change', filterTable);

    container.dataset.built = '1';
  } catch(e){ container.dataset.built=''; container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>'; }
}

async function loadUserAnalytics() {
  try {
    var all = [];
    if (typeof TcjAdminUsers !== 'undefined') {
      all = await TcjAdminUsers.fetchAll({p_search:null,p_status:null});
    } else {
      all = await rpc('admin_get_users', {p_search:null,p_limit:500,p_offset:0,p_status:null});
    }
    const total= (all||[]).length;
    const act  = (all||[]).filter(function(u){ return u.account_status==='active'; }).length;
    const pend = (all||[]).filter(function(u){ return u.account_status==='pending'; }).length;
    const deac = (all||[]).filter(function(u){ return u.account_status==='deactivated'; }).length;
    setElT('ua-total',       total);
    setElT('ua-active',      act);
    setElT('ua-pending',     pend);
    setElT('ua-deactivated', deac);
    renderBarChart('ua-status-chart',[
      {label:'Active',      value:act},
      {label:'Pending',     value:pend},
      {label:'Deactivated', value:deac}
    ], 'var(--accent)');
    const contribs = (all||[]).filter(function(u){ return u.recipe_count>0; }).sort(function(a,b){ return b.recipe_count-a.recipe_count; }).slice(0,8);
    renderBarChart('ua-contributors-chart', contribs.map(function(u){ return {label:u.username||u.full_name,value:u.recipe_count}; }), '#4caf76');
  } catch(e) { console.warn('user analytics', e); }
}

async function doExportUserData(uid, username) {
  try {
    var data = await rpc('admin_export_user_data', {p_user_id: uid});
    var blob = new Blob([JSON.stringify(data, null, 2)], {type:'application/json'});
    var a = document.createElement('a'); a.href = URL.createObjectURL(blob);
    a.download = 'user-data-'+esc(username).replace(/[^a-z0-9]/gi,'-')+'-'+new Date().toISOString().slice(0,10)+'.json';
    a.click(); URL.revokeObjectURL(a.href);
    auditLog('User Management','GDPR Export',username,uid,null,'User data exported');
  } catch(e) { alert('Error: '+e.message); }
}

async function bulkAwardBadge() {
  var ids = Object.keys(_selectedUsers);
  if (!ids.length) return;
  var badge = prompt('Award badge to '+ids.length+' selected users.\n\nChoose badge:\n1. Trusted Contributor\n2. Guest Chef\n3. 100 Recipes\n4. 50 Recipes\n5. Early Member\n6. Journal Pick\n\nType the badge name exactly:');
  if (!badge || !badge.trim()) return;
  try {
    var n = await rpc('admin_bulk_award_badge', {p_user_ids: ids, p_badge: badge.trim()});
    auditLog('User Management','Bulk Badge Award',null,null,badge.trim(),n+' users');
    alert('\u2713 Badge "'+badge.trim()+'" awarded to '+n+' users.');
    _selectedUsers = {};
    loadMembers(_userPage);
  } catch(e) { alert('Error: '+e.message); }
}

function doSendEmailToUser(uid, email, name) {
  var subject = prompt('Email subject:');
  if (!subject) return;
  var body = prompt('Email message body (plain text):');
  if (!body) return;
  if (!confirm('Send email to ' + name + ' <' + email + '>?')) return;

  // Queue via Supabase email queue if available, otherwise open mail client
  (async function() {
    try {
      var res = await rpc('queue_email', {
        p_template_key: 'custom',
        p_to_email:     email,
        p_to_name:      name,
        p_variables:    { name: name, subject: subject, message: body }
      });
      showToast('Email queued for ' + name);
      auditLog('User Management', 'Email Sent', name, uid, subject, null);
    } catch(e) {
      // Fallback: open default mail client
      window.location.href = 'mailto:' + encodeURIComponent(email) +
        '?subject=' + encodeURIComponent(subject) +
        '&body=' + encodeURIComponent(body);
    }
  })();
}
// ── Action wrappers reading from _detailUser (no user data in onclick) ──
function showDeactivateModal_current() {
  if (_detailUser) showDeactivateModal(_detailUser.id, _detailUser.full_name||_detailUser.username||'this user');
}
function confirmReactivate_current() {
  if (_detailUser) confirmReactivate(_detailUser.id, _detailUser.full_name||_detailUser.username||'this user');
}
function doToggleFlag_current() {
  if (_detailUser) doToggleFlag(_detailUser.id, !!_detailUser.flagged);
}
function doToggleAdmin_current() {
  if (_detailUser) doToggleAdmin(_detailUser.id, !!_detailUser.is_admin);
}
function doSendEmailToUser_current() {
  if (_detailUser) doSendEmailToUser(_detailUser.id, _detailUser.email||'', _detailUser.full_name||_detailUser.username||'');
}
function doExportUserData_current() {
  if (_detailUser) doExportUserData(_detailUser.id, _detailUser.full_name||_detailUser.username||'');
}
function doAddNote_current() {
  if (_detailUser) doAddNote(_detailUser.id);
}

// ── Table-level event delegation for user row action buttons ──────────
document.addEventListener('click', function(e) {
  var btn = e.target.closest('[data-action][data-uid]');
  if (!btn) return;
  var action = btn.dataset.action;
  var uid    = btn.dataset.uid;
  if (action === 'view-user')       openUserDetail(uid);
  if (action === 'deactivate-user') showDeactivateModal(uid, '');
  if (action === 'reactivate-user') confirmReactivate(uid, '');
});
