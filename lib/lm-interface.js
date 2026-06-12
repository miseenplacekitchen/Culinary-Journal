/* Library Management — LM Interface */

var LIB_CURRENT_TYPE = 'ingredient';
var LIB_CURRENT_STATUS = null;
var LIB_IMAGE_STATUS = null;
var LIB_SEARCH = '';
var LIB_SORT = 'updated_desc';
var LIB_OFFSET = 0;
var LIB_PAGE_SIZE = 25;
var LIB_TOTAL = 0;
var LIB_SELECTED = {};
var _libIngSearchTimer = null;
var _libCsvData = null;

var _lmPendingEditId = null;
var _lmEditType = 'ingredient';
var _lmEditSlug = null;
var _lmPrefill = null;
var _lmProfiles = [];
var _lmMiseEditor = null;

function lmEnsureStyles() {
  if (document.getElementById('lm-interface-styles')) return;
  var style = document.createElement('style');
  style.id = 'lm-interface-styles';
  style.textContent =
    '.ls-panel-toolbar-btn{font-family:DM Sans,sans-serif;font-size:11px;padding:6px 12px;border-radius:7px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer}' +
    '.ls-panel-toolbar-btn:hover{border-color:var(--accent);color:var(--accent)}' +
    '.ls-panel{border:1px solid var(--border);border-radius:12px;margin-bottom:12px;overflow:hidden;background:rgba(255,255,255,0.02)}' +
    '.ls-panel-head{width:100%;display:flex;align-items:center;gap:10px;padding:14px 18px;background:rgba(255,255,255,0.04);border:none;cursor:pointer;text-align:left;color:inherit}' +
    '.ls-panel-head:hover{background:rgba(255,255,255,0.06)}' +
    '.ls-panel-chevron{font-size:12px;color:var(--accent);transition:transform .15s;flex-shrink:0}' +
    '.ls-panel.collapsed .ls-panel-chevron{transform:rotate(-90deg)}' +
    '.ls-panel-titles{min-width:0;flex:1}' +
    '.ls-panel-title{display:block;font-family:Cormorant Garamond,serif;font-size:1.15rem;font-weight:600;color:var(--text-high)}' +
    '.ls-panel-desc{display:block;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);margin-top:2px;line-height:1.4}' +
    '.ls-panel-body{padding:16px 18px 18px}' +
    '.ls-panel.collapsed .ls-panel-body{display:none}' +
    '.ls-row{margin-bottom:12px}' +
    '.ls-label{display:block;font-family:DM Sans,sans-serif;font-size:10px;color:var(--text-mid);text-transform:uppercase;letter-spacing:.08em;margin-bottom:6px}' +
    '.ls-label span{color:var(--accent)}' +
    '.ls-input,.ls-textarea,.ls-select{width:100%;box-sizing:border-box;padding:9px 10px;border:1px solid var(--border);border-radius:8px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px}' +
    '.ls-textarea{min-height:100px;resize:vertical}' +
    '.ls-2col{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:12px}' +
    '.ls-hidden{display:none}' +
    '.ls-img-box{min-height:120px;border:1px dashed var(--border);border-radius:10px;padding:12px;display:flex;align-items:center;justify-content:center;cursor:pointer;background:rgba(255,255,255,0.01)}' +
    '.ls-img-box:hover{border-color:var(--accent)}' +
    '.ls-img-text{font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid)}';
  document.head.appendChild(style);
}

var LIB_TYPE_MAP = {
  'lm-ingredients': { type: 'ingredient', label: 'Ingredients', emoji: '🌿' },
  'lm-spices': { type: 'spice', label: 'Spices', emoji: '🌶' },
  'lm-tools': { type: 'tool', label: 'Tools', emoji: '🔪' },
  'lm-cuts': { type: 'cut', label: 'Cuts & Prep', emoji: '🥩' },
  'lm-preservation': { type: 'preservation', label: 'Preservation', emoji: '🫙' }
};

function switchLibTab(tab) {
  localStorage.setItem('tcj_active_lib_tab', tab);
  document.querySelectorAll('#v-library-mgmt .ap-inner-tab').forEach(function (b) {
    b.classList.toggle('active', b.dataset.tab === tab);
  });
  LIB_OFFSET = 0;
  LIB_SELECTED = {};
  if (tab === 'lm-submissions') { loadLibSubmissions(); return; }
  if (tab === 'lm-coverage') { loadLibCoverage(); return; }
  if (tab === 'lm-interface') { loadLmInterface(); return; }
  var info = LIB_TYPE_MAP[tab];
  if (info) {
    LIB_CURRENT_TYPE = info.type;
    loadLibProfiles();
  }
}

function libSelectedIds() {
  return Object.keys(LIB_SELECTED).filter(function (k) { return LIB_SELECTED[k]; });
}

function libToggleSelectAll(checked) {
  document.querySelectorAll('#lm-panel [data-lib-check]').forEach(function (cb) {
    cb.checked = checked;
    LIB_SELECTED[cb.dataset.lid] = checked;
  });
  libUpdateBulkBar();
}

function libUpdateBulkBar() {
  var n = libSelectedIds().length;
  var bar = document.getElementById('lib-bulk-bar');
  if (bar) {
    bar.classList.toggle('visible', n > 0);
    var cnt = document.getElementById('lib-bulk-count');
    if (cnt) cnt.textContent = n + ' selected';
  }
}

async function loadLibSubmissions(status) {
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading submissions…</div>';
  var filter = status || 'pending';
  try {
    var rows = await rpc('admin_get_library_submissions', { p_status: filter, p_limit: 50 });
    buildLibSubmissionsPanel(panel, Array.isArray(rows) ? rows : [], filter);
  } catch (e) {
    panel.innerHTML = '<div class="ap-empty">Error: ' + esc(e.message || e) + '</div>';
  }
}

function buildLibSubmissionsPanel(panel, items, filter) {
  var html = '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:8px">' +
    '<div style="display:flex;gap:8px">' +
    ['pending', 'approved', 'rejected'].map(function (s) {
      return '<button onclick="loadLibSubmissions(\'' + s + '\')" style="font-family:DM Sans,sans-serif;font-size:12px;padding:5px 12px;border-radius:6px;border:1px solid var(--border);background:' +
        (filter === s ? 'var(--accent)' : 'none') + ';color:' + (filter === s ? '#0C0702' : 'var(--text-mid)') + ';cursor:pointer">' +
        s.charAt(0).toUpperCase() + s.slice(1) + '</button>';
    }).join('') +
    '</div><span style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">Approve publishes profile live</span></div>';
  if (!items.length) {
    panel.innerHTML = html + '<div class="ap-empty">No ' + filter + ' submissions.</div>';
    return;
  }
  html += '<div class="ap-table"><table style="width:100%;border-collapse:collapse"><thead><tr>' +
    ['Type', 'Name', 'Submitted', 'Preview', 'Actions'].map(function (h) {
      return '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">' + h + '</th>';
    }).join('') + '</tr></thead><tbody>';
  items.forEach(function (sub) {
    var p = sub.payload || {};
    var name = p.name || sub.slug || '—';
    var when = sub.created_at ? new Date(sub.created_at).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—';
    var preview = [p.flavour_profile, p.flavour_wheel, p.what_its_for, p.characteristics].filter(Boolean)[0] || p.chefs_notes || '';
    preview = String(preview).slice(0, 120) + (String(preview).length > 120 ? '…' : '');
    var actions = '<button data-action="lib-sub-view" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--accent);cursor:pointer;margin-right:6px">View</button>';
    if (filter === 'pending') {
      actions += '<button data-action="lib-sub-approve" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid #6dc86d;background:rgba(100,200,100,.1);color:#6dc86d;cursor:pointer;margin-right:6px">Approve</button>' +
        '<button data-action="lib-sub-reject" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Reject</button>';
    } else {
      actions += '<span style="font-size:11px;color:var(--text-mid)">' + esc(sub.status) + '</span>';
    }
    html += '<tr style="border-bottom:1px solid rgba(255,255,255,.04)">' +
      '<td style="padding:8px 12px;font-size:12px;color:var(--text-mid)">' + esc(sub.profile_type || '') + '</td>' +
      '<td style="padding:8px 12px;font-size:13px;color:var(--text-high)">' + esc(name) + '</td>' +
      '<td style="padding:8px 12px;font-size:11px;color:var(--text-mid)">' + esc(when) + '</td>' +
      '<td style="padding:8px 12px;font-size:11px;color:var(--text-mid);max-width:240px">' + esc(preview) + '</td>' +
      '<td style="padding:8px 12px">' + actions + '</td></tr>';
  });
  html += '</tbody></table></div>';
  panel.innerHTML = html;
  panel._libSubItems = items;
  panel.onclick = function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    var sid = btn.dataset.sid;
    if (btn.dataset.action === 'lib-sub-view') openLibSubReview(sid);
    if (btn.dataset.action === 'lib-sub-approve') reviewLibSubmission(sid, 'approve');
    if (btn.dataset.action === 'lib-sub-reject') reviewLibSubmission(sid, 'reject', true);
  };
}

function openLibSubReview(sid) {
  var panel = document.getElementById('lm-panel');
  var sub = (panel && panel._libSubItems || []).find(function (s) { return s.id === sid; });
  if (!sub) return;
  var overlay = document.getElementById('lib-sub-overlay');
  if (!overlay) return;
  var p = sub.payload || {};
  document.getElementById('lib-sub-title').textContent = (p.name || sub.slug || 'Submission') + ' (' + (sub.profile_type || '') + ')';
  document.getElementById('lib-sub-body').textContent = JSON.stringify(p, null, 2);
  document.getElementById('lib-sub-notes').value = '';
  overlay.dataset.sid = sid;
  overlay.classList.add('open');
}

function closeLibSubReview() {
  var overlay = document.getElementById('lib-sub-overlay');
  if (overlay) overlay.classList.remove('open');
}

async function reviewLibSubmission(id, action, fromModal) {
  var notes = '';
  if (action === 'reject') {
    if (fromModal) {
      notes = (document.getElementById('lib-sub-notes') || {}).value || '';
    } else {
      notes = prompt('Rejection notes for submitter (optional):', '');
      if (notes === null) return;
    }
  }
  if (action === 'approve' && !confirm('Approve and publish this profile to the library?')) return;
  try {
    await rpc('admin_review_library_submission', { p_id: id, p_action: action, p_notes: notes || null });
    closeLibSubReview();
    alert(action === 'approve' ? 'Published to library.' : 'Submission rejected.');
    loadLibSubmissions('pending');
  } catch (e) { alert('Error: ' + (e.message || e)); }
}

async function loadLibProfiles(status, imageStatus, resetPage) {
  if (status !== undefined) LIB_CURRENT_STATUS = status || null;
  if (imageStatus !== undefined) LIB_IMAGE_STATUS = imageStatus || null;
  if (resetPage) LIB_OFFSET = 0;
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading…</div>';
  try {
    var stats = await rpc('admin_get_library_image_stats', { p_type: LIB_CURRENT_TYPE }).catch(function () { return null; });
    var data = await rpc('admin_get_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_status: LIB_CURRENT_STATUS,
      p_limit: LIB_PAGE_SIZE,
      p_offset: LIB_OFFSET,
      p_image_status: LIB_IMAGE_STATUS,
      p_search: LIB_SEARCH || null,
      p_sort: LIB_SORT
    });
    var items = Array.isArray(data) ? data : (data && data.items) || [];
    LIB_TOTAL = Array.isArray(data) ? items.length : ((data && data.total) || items.length);
    buildLibPanel(panel, items, stats);
  } catch (e) {
    panel.innerHTML = '<div class="ap-empty">Error loading profiles: ' + esc(e.message || e) +
      '<div style="margin-top:8px;font-size:11px">Run <code>fix-library-management.sql</code> in Supabase if RPCs are missing.</div></div>';
  }
}

function buildLibPanel(panel, items, stats) {
  var info = Object.values(LIB_TYPE_MAP).find(function (t) { return t.type === LIB_CURRENT_TYPE; }) || {};
  var statsHtml = '';
  if (stats && stats.total) {
    statsHtml = '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:12px;display:flex;gap:12px;flex-wrap:wrap">' +
      '<span>Mise coverage: <strong style="color:var(--text-high)">' + (stats.approved || 0) + '</strong> / ' + stats.total + ' approved</span>' +
      '<span style="color:var(--text-muted)">' + (stats.missing || 0) + ' missing · ' + (stats.draft || 0) + ' draft</span></div>';
  }
  var pageStart = LIB_TOTAL ? LIB_OFFSET + 1 : 0;
  var pageEnd = Math.min(LIB_OFFSET + items.length, LIB_TOTAL);
  var pageHtml = '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);display:flex;align-items:center;gap:8px">' +
    '<span>' + pageStart + '–' + pageEnd + ' of <strong>' + LIB_TOTAL + '</strong></span>' +
    '<button data-action="lib-page-prev" ' + (LIB_OFFSET <= 0 ? 'disabled' : '') +
    ' style="font-size:11px;padding:3px 10px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--text-mid);cursor:pointer">Prev</button>' +
    '<button data-action="lib-page-next" ' + (LIB_OFFSET + LIB_PAGE_SIZE >= LIB_TOTAL ? 'disabled' : '') +
    ' style="font-size:11px;padding:3px 10px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--text-mid);cursor:pointer">Next</button></div>';

  var html = statsHtml +
    '<div id="lib-bulk-bar" class="bulk-toolbar">' +
    '<span class="bulk-count" id="lib-bulk-count">0 selected</span>' +
    '<button class="bulk-apply-btn" data-action="lib-bulk-publish">Publish</button>' +
    '<button class="bulk-clear-btn" data-action="lib-bulk-unpublish">Unpublish</button>' +
    '<button class="bulk-clear-btn" data-action="lib-bulk-approve-img">Approve mise</button>' +
    '<select class="bulk-field-sel" id="lib-bulk-vis"><option value="public">Visibility: public</option><option value="members">members</option><option value="paid">paid</option></select>' +
    '<button class="bulk-apply-btn" data-action="lib-bulk-vis">Set visibility</button>' +
    '<button class="bulk-del-btn" data-action="lib-bulk-delete">Delete</button>' +
    '<button class="bulk-clear-btn" data-action="lib-bulk-clear">Clear</button></div>' +
    '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;flex-wrap:wrap;gap:8px">' +
    '<div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">' +
    '<input type="search" id="lib-search-inp" placeholder="Search name, AKA, slug…" value="' + esc(LIB_SEARCH) + '" ' +
    'style="font-family:DM Sans,sans-serif;font-size:12px;padding:6px 12px;border-radius:8px;border:1px solid var(--border);background:var(--input-bg);color:var(--text-high);min-width:200px">' +
    '<select id="lib-sort-sel" style="font-family:DM Sans,sans-serif;font-size:12px;padding:6px 10px;border-radius:8px;border:1px solid var(--border);background:var(--bg);color:var(--text-high)">' +
    '<option value="updated_desc"' + (LIB_SORT === 'updated_desc' ? ' selected' : '') + '>Updated ↓</option>' +
    '<option value="updated_asc"' + (LIB_SORT === 'updated_asc' ? ' selected' : '') + '>Updated ↑</option>' +
    '<option value="name_asc"' + (LIB_SORT === 'name_asc' ? ' selected' : '') + '>Name A–Z</option>' +
    '<option value="name_desc"' + (LIB_SORT === 'name_desc' ? ' selected' : '') + '>Name Z–A</option>' +
    '<option value="status_asc"' + (LIB_SORT === 'status_asc' ? ' selected' : '') + '>Status</option></select>' +
    ['All', 'draft', 'published'].map(function (s) {
      return '<button data-action="lib-filter-status" data-status="' + (s === 'All' ? '' : s) + '" ' +
        'style="font-family:DM Sans,sans-serif;font-size:12px;padding:5px 12px;border-radius:6px;border:1px solid var(--border);background:' +
        ((s === 'All' && !LIB_CURRENT_STATUS) || (s === LIB_CURRENT_STATUS) ? 'var(--accent)' : 'none') +
        ';color:' + (((s === 'All' && !LIB_CURRENT_STATUS) || (s === LIB_CURRENT_STATUS)) ? '#0C0702' : 'var(--text-mid)') +
        ';cursor:pointer">' + s + '</button>';
    }).join('') +
    '</div>' +
    '<div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">' + pageHtml +
    '<button data-action="lib-import-csv" style="font-family:DM Sans,sans-serif;font-size:12px;padding:8px 14px;border-radius:8px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Import CSV</button>' +
    '<button data-action="lib-new" style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;padding:8px 16px;border-radius:8px;background:var(--accent);color:#0C0702;border:none;cursor:pointer">+ New Profile</button></div></div>' +
    '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:16px">' +
    ['All', 'missing', 'draft', 'approved'].map(function (s) {
      var active = (s === 'All' && !LIB_IMAGE_STATUS) || s === LIB_IMAGE_STATUS;
      return '<button data-action="lib-filter-img" data-img="' + (s === 'All' ? '' : s) + '" ' +
        'style="font-family:DM Sans,sans-serif;font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:' +
        (active ? 'rgba(196,151,59,0.15)' : 'none') + ';color:' + (active ? 'var(--accent)' : 'var(--text-mid)') + ';cursor:pointer">' +
        (s === 'All' ? 'All images' : s) + '</button>';
    }).join('') + '</div>';

  if (!items.length) {
    html += '<div class="ap-empty">No ' + (info.label || 'profiles') + ' found.</div>';
    panel.innerHTML = html;
    libBindPanelEvents(panel);
    return;
  }

  var ingCol = LIB_CURRENT_TYPE === 'ingredient'
    ? '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">Governed link</th>'
    : '';
  html += '<div class="ap-table"><table style="width:100%;border-collapse:collapse">' +
    '<thead><tr>' +
    '<th style="padding:8px 6px;border-bottom:1px solid var(--border)"><input type="checkbox" class="ing-check" data-action="lib-check-all" title="Select all on page"></th>' +
    ['Mise', 'Hero', 'Name', 'Mise status', 'Status', 'Visibility', 'Updated'].map(function (h) {
      return '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">' + h + '</th>';
    }).join('') + ingCol +
    '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">Actions</th>' +
    '</tr></thead><tbody>';

  items.forEach(function (p) {
    var statusColor = p.status === 'published' ? '#6dc86d' : 'var(--text-muted)';
    var imgSt = p.image_status || (p.mise_image_url ? 'draft' : 'missing');
    var imgStColor = imgSt === 'approved' ? '#6dc86d' : (imgSt === 'draft' ? '#c4973b' : 'var(--text-muted)');
    var info2 = TCJ_LIB_TYPE_META[LIB_CURRENT_TYPE] || {};
    var miseThumb = p.mise_image_url
      ? '<img src="' + esc(p.mise_image_url) + '" style="width:100%;height:100%;object-fit:cover;border-radius:50%">'
      : '<span style="font-size:18px">' + (info2.emoji || '·') + '</span>';
    var heroThumb = p.image_url
      ? '<img src="' + esc(p.image_url) + '" style="width:100%;height:100%;object-fit:cover">'
      : '<span style="font-size:14px;opacity:0.5">' + (info2.emoji || '') + '</span>';
    var approveBtn = (imgSt === 'draft' && p.mise_image_url)
      ? '<button data-action="lib-mise-approve" data-lid="' + esc(p.id) + '" style="font-size:10px;padding:3px 8px;border:1px solid #6dc86d;background:none;color:#6dc86d;border-radius:5px;cursor:pointer;margin-left:4px">Approve</button>'
      : '';
    var checked = LIB_SELECTED[p.id] ? ' checked' : '';
    var ingCell = '';
    if (LIB_CURRENT_TYPE === 'ingredient') {
      var gid = p.governed_ingredient_id || '';
      ingCell = '<td style="padding:8px 12px;position:relative;min-width:200px">' +
        '<input type="hidden" id="lib-ing-id-' + esc(p.id) + '" value="' + esc(gid) + '">' +
        '<input type="text" id="lib-ing-q-' + esc(p.id) + '" placeholder="Search ingredient…" autocomplete="off" ' +
        'data-action="lib-ing-search" data-lid="' + esc(p.id) + '" ' +
        'style="width:100%;padding:4px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)">' +
        '<div id="lib-ing-ac-' + esc(p.id) + '" style="display:none;position:absolute;z-index:20;background:var(--bg);border:1px solid var(--border);border-radius:8px;max-height:160px;overflow-y:auto;min-width:220px;box-shadow:0 8px 24px rgba(0,0,0,.35)"></div>' +
        '<div id="lib-ing-prev-' + esc(p.id) + '" style="font-size:10px;color:var(--text-muted);margin-top:4px"></div>' +
        '<button data-action="lib-link" data-lid="' + esc(p.id) + '" style="margin-top:4px;font-size:10px;padding:3px 8px;border:1px solid var(--accent);background:none;color:var(--accent);border-radius:5px;cursor:pointer">Link</button></td>';
    }
    html += '<tr style="border-bottom:1px solid rgba(255,255,255,.04)">' +
      '<td style="padding:8px 6px"><input type="checkbox" class="ing-check" data-lib-check data-lid="' + esc(p.id) + '"' + checked + '></td>' +
      '<td style="padding:8px 12px"><div style="width:44px;height:44px;border-radius:50%;background:var(--surface);overflow:hidden;display:flex;align-items:center;justify-content:center;border:1px solid var(--border)">' + miseThumb + '</div></td>' +
      '<td style="padding:8px 12px"><div style="width:40px;height:40px;border-radius:6px;background:var(--surface);overflow:hidden;display:flex;align-items:center;justify-content:center">' + heroThumb + '</div></td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)">' + esc(p.name) + '</td>' +
      '<td style="padding:8px 12px"><span style="font-size:10px;font-family:DM Sans,sans-serif;color:' + imgStColor + ';text-transform:uppercase;letter-spacing:.06em">' + esc(imgSt) + '</span>' + approveBtn + '</td>' +
      '<td style="padding:8px 12px"><span style="font-size:11px;font-family:DM Sans,sans-serif;color:' + statusColor + ';text-transform:uppercase;letter-spacing:.06em">' + esc(p.status) + '</span></td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted)">' + esc(p.visibility || 'public') + '</td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted)">' + (p.updated_at ? new Date(p.updated_at).toLocaleDateString() : '—') + '</td>' +
      ingCell +
      '<td style="padding:8px 12px;white-space:nowrap">' +
      '<button data-action="lib-edit" data-lid="' + esc(p.id) + '" style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--accent);margin-right:8px">Edit</button>' +
      '<button data-action="lib-toggle" data-lid="' + esc(p.id) + '" data-lstatus="' + esc(p.status) + '" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--text-mid)">' +
      (p.status === 'published' ? 'Unpublish' : 'Publish') + '</button>' +
      '<button data-action="lib-delete" data-lid="' + esc(p.id) + '" data-lname="' + esc(p.name) + '" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--text-danger);margin-left:8px">Delete</button>' +
      '</td></tr>';
  });

  html += '</tbody></table></div>';
  panel.innerHTML = html;
  libBindPanelEvents(panel);
  if (LIB_CURRENT_TYPE === 'ingredient') {
    items.forEach(function (p) { if (p.governed_ingredient_id) libRefreshGovernedPreview(p.id); });
  }
  libUpdateBulkBar();
}

function libBindPanelEvents(panel) {
  panel.onclick = function (e) {
    var btn = e.target.closest('[data-action]');
    if (btn) {
      var action = btn.dataset.action;
      var lid = btn.dataset.lid;
      var lstatus = btn.dataset.lstatus;
      var lname = btn.dataset.lname;
      if (action === 'lib-new') { openLibEditor(null); return; }
      if (action === 'lib-import-csv') { openLibCsvModal(); return; }
      if (action === 'lib-edit' && lid) { openLibEditor(lid); return; }
      if (action === 'lib-toggle' && lid) libTogglePublish(lid, lstatus);
      if (action === 'lib-delete' && lid) libDelete(lid, lname);
      if (action === 'lib-link' && lid) libLinkGoverned(lid);
      if (action === 'lib-mise-approve' && lid) {
        rpc('admin_set_library_image_status', { p_type: LIB_CURRENT_TYPE, p_id: lid, p_status: 'approved' })
          .then(function () { loadLibProfiles(undefined, undefined, false); })
          .catch(function (err) { alert(err.message); });
      }
      if (action === 'lib-filter-status') {
        LIB_CURRENT_STATUS = btn.dataset.status || null;
        loadLibProfiles(undefined, undefined, true);
      }
      if (action === 'lib-filter-img') {
        LIB_IMAGE_STATUS = btn.dataset.img || null;
        loadLibProfiles(undefined, undefined, true);
      }
      if (action === 'lib-page-prev') {
        LIB_OFFSET = Math.max(0, LIB_OFFSET - LIB_PAGE_SIZE);
        loadLibProfiles();
      }
      if (action === 'lib-page-next') {
        LIB_OFFSET += LIB_PAGE_SIZE;
        loadLibProfiles();
      }
      if (action === 'lib-check-all') libToggleSelectAll(btn.checked);
      if (action === 'lib-bulk-publish') libBulkAction('publish');
      if (action === 'lib-bulk-unpublish') libBulkAction('unpublish');
      if (action === 'lib-bulk-approve-img') libBulkAction('approve_image');
      if (action === 'lib-bulk-vis') {
        var vis = (document.getElementById('lib-bulk-vis') || {}).value || 'public';
        libBulkAction('set_visibility', vis);
      }
      if (action === 'lib-bulk-delete') libBulkAction('delete');
      if (action === 'lib-bulk-clear') { LIB_SELECTED = {}; libToggleSelectAll(false); }
    }
    var cb = e.target.closest('[data-lib-check]');
    if (cb && cb.dataset.lid) {
      LIB_SELECTED[cb.dataset.lid] = cb.checked;
      libUpdateBulkBar();
    }
  };
  var searchInp = document.getElementById('lib-search-inp');
  if (searchInp) {
    searchInp.onkeydown = function (ev) {
      if (ev.key === 'Enter') {
        LIB_SEARCH = searchInp.value.trim();
        loadLibProfiles(undefined, undefined, true);
      }
    };
    searchInp.onchange = function () {
      LIB_SEARCH = searchInp.value.trim();
      loadLibProfiles(undefined, undefined, true);
    };
  }
  var sortSel = document.getElementById('lib-sort-sel');
  if (sortSel) {
    sortSel.onchange = function () {
      LIB_SORT = sortSel.value;
      loadLibProfiles(undefined, undefined, true);
    };
  }
  panel.oninput = function (e) {
    var inp = e.target.closest('[data-action="lib-ing-search"]');
    if (!inp) return;
    clearTimeout(_libIngSearchTimer);
    _libIngSearchTimer = setTimeout(function () { libIngAutocomplete(inp.dataset.lid, inp.value); }, 280);
  };
}

async function libIngAutocomplete(profileId, query) {
  var ac = document.getElementById('lib-ing-ac-' + profileId);
  if (!ac) return;
  if (!query || query.length < 2) { ac.style.display = 'none'; return; }
  try {
    var rows = await rpc('admin_get_ingredients', { p_search: query, p_limit: 8, p_offset: 0 });
    var list = Array.isArray(rows) ? rows : [];
    if (!list.length) { ac.style.display = 'none'; return; }
    ac.innerHTML = list.map(function (r) {
      var id = r.ID || r.id;
      var name = r['Ingredient Name'] || r.ingredient_name || '';
      return '<div data-ing-pick="' + id + '" data-ing-name="' + esc(name) + '" data-lid="' + esc(profileId) + '" ' +
        'style="padding:8px 12px;font-size:12px;cursor:pointer;border-bottom:1px solid var(--border)">' +
        esc(name) + ' <span style="color:var(--text-muted);font-size:10px">#' + id + '</span></div>';
    }).join('');
    ac.style.display = 'block';
    ac.onclick = function (ev) {
      var pick = ev.target.closest('[data-ing-pick]');
      if (!pick) return;
      var hid = document.getElementById('lib-ing-id-' + pick.dataset.lid);
      var q = document.getElementById('lib-ing-q-' + pick.dataset.lid);
      if (hid) hid.value = pick.dataset.ingPick;
      if (q) q.value = pick.dataset.ingName + ' (#' + pick.dataset.ingPick + ')';
      ac.style.display = 'none';
    };
  } catch (_) { ac.style.display = 'none'; }
}

async function libRefreshGovernedPreview(profileId) {
  var el = document.getElementById('lib-ing-prev-' + profileId);
  if (!el) return;
  try {
    var prev = await rpc('admin_get_library_governed_preview', { p_profile_id: profileId });
    if (!prev || !prev.linked) { el.textContent = 'No governed link'; return; }
    if (!prev.valid) { el.textContent = 'Invalid ID #' + (prev.ingredient_id || '?'); el.style.color = '#dc5050'; return; }
    el.style.color = 'var(--text-muted)';
    el.textContent = '📚 ' + (prev.recipe_count || 0) + ' recipes match "' + (prev.ingredient_name || '') + '"';
  } catch (_) {}
}

async function libLinkGoverned(profileId) {
  var hid = document.getElementById('lib-ing-id-' + profileId);
  var ingId = hid ? parseInt(hid.value, 10) : 0;
  if (!ingId) { alert('Search and select a governed ingredient first'); return; }
  try {
    var res = await rpc('admin_link_library_ingredient', { p_profile_id: profileId, p_ingredient_id: ingId });
    alert('Linked to ' + (res.ingredient_name || 'ingredient') + ' (#' + ingId + ')');
    libRefreshGovernedPreview(profileId);
    loadLibProfiles(undefined, undefined, false);
  } catch (err) { alert(err.message || err); }
}

async function libBulkAction(action, value) {
  var ids = libSelectedIds();
  if (!ids.length) { alert('Select profiles first'); return; }
  if (action === 'delete' && !confirm('Delete ' + ids.length + ' profile(s)? This cannot be undone.')) return;
  try {
    var res = await rpc('admin_bulk_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_ids: ids,
      p_action: action,
      p_value: value || null
    });
    LIB_SELECTED = {};
    alert('Updated ' + (res.updated || 0) + ' profile(s).');
    loadLibProfiles(undefined, undefined, false);
  } catch (e) { alert(e.message || e); }
}

async function libTogglePublish(id, currentStatus) {
  var newStatus = currentStatus === 'published' ? 'draft' : 'published';
  try {
    await rpc('admin_publish_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id, p_status: newStatus });
    loadLibProfiles(undefined, undefined, false);
  } catch (e) { alert('Error: ' + (e.message || e)); }
}

async function libDelete(id, name) {
  if (!confirm('Delete "' + name + '"? This cannot be undone.')) return;
  try {
    await rpc('admin_delete_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id });
    loadLibProfiles(undefined, undefined, false);
  } catch (e) { alert('Error: ' + (e.message || e)); }
}

function openLibEditor(id) {
  _lmPendingEditId = id || null;
  _lmEditType = LIB_CURRENT_TYPE;
  _lmEditSlug = null;
  _lmPrefill = null;
  switchLibTab('lm-interface');
}

function closeLibEditor() {
  _lmPendingEditId = null;
  _lmEditSlug = null;
  var overlay = document.getElementById('lib-ed-overlay');
  if (overlay) overlay.classList.remove('open');
}

function lmSetMsg(msg, tone) {
  var box = document.getElementById('lm-intf-msg');
  if (!box) return;
  box.textContent = msg || '';
  box.style.display = msg ? 'block' : 'none';
  box.style.color = tone === 'error' ? '#dc5050' : (tone === 'success' ? '#6dc86d' : 'var(--text-mid)');
}

async function loadLmInterface() {
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  lmEnsureStyles();
  panel.innerHTML = '<div class="ap-loading">Loading LM Interface…</div>';
  var type = _lmEditType || LIB_CURRENT_TYPE || 'ingredient';
  var typeMeta = TCJ_LIB_TYPE_META[type] || {};
  try {
    if (typeof TcjAdminLibrary !== 'undefined') {
      _lmProfiles = await TcjAdminLibrary.fetchAll({
        p_type: type,
        p_status: null,
        p_image_status: null,
        p_search: null,
        p_sort: 'name_asc'
      });
    } else {
      var data = await rpc('admin_get_library_profiles', {
        p_type: type,
        p_status: null,
        p_limit: 500,
        p_offset: 0,
        p_image_status: null,
        p_search: null,
        p_sort: 'name_asc'
      });
      _lmProfiles = Array.isArray(data) ? data : ((data && data.items) || []);
    }
  } catch (e) {
    console.warn('lm interface profiles', e);
    _lmProfiles = [];
  }

  panel.innerHTML =
    '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:12px;line-height:1.55">' +
    '<strong style="color:var(--text-high)">LM Interface.</strong> ' + esc(typeMeta.tagline || 'Build and edit library profiles with panel-based fields.') + '</div>' +
    '<div style="display:flex;gap:10px;flex-wrap:wrap;align-items:end;margin-bottom:12px">' +
    '<div><label style="display:block;font-size:10px;color:var(--text-mid);text-transform:uppercase;letter-spacing:.08em;margin-bottom:5px">Type</label>' +
    '<select id="lm-type-sel" style="padding:8px 12px;border:1px solid var(--border);border-radius:8px;background:var(--bg);color:var(--text-high);font-size:12px;min-width:180px"></select></div>' +
    '<div style="flex:1;min-width:220px"><label style="display:block;font-size:10px;color:var(--text-mid);text-transform:uppercase;letter-spacing:.08em;margin-bottom:5px">Profile</label>' +
    '<select id="lm-profile-sel" style="width:100%;padding:8px 12px;border:1px solid var(--border);border-radius:8px;background:var(--bg);color:var(--text-high);font-size:12px"></select></div>' +
    '<button type="button" id="lm-load-btn" style="padding:8px 16px;border-radius:8px;border:1px solid var(--accent);background:var(--accent);color:#0C0702;font-family:DM Sans,sans-serif;font-size:12px;font-weight:700;cursor:pointer">Load</button>' +
    '</div>' +
    '<div id="lm-tagline" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:10px"></div>' +
    '<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px">' +
    '<button type="button" class="ls-panel-toolbar-btn" onclick="lmExpandPanels(true)">Expand all</button>' +
    '<button type="button" class="ls-panel-toolbar-btn" onclick="lmExpandPanels(false)">Collapse all</button>' +
    '</div>' +
    '<div id="lm-panels-root"></div>' +
    '<div id="lm-intf-msg" style="display:none;font-family:DM Sans,sans-serif;font-size:12px;margin-top:10px"></div>' +
    '<div style="display:flex;justify-content:flex-end;gap:8px;margin-top:14px">' +
    '<button type="button" id="lm-new-btn" style="padding:8px 14px;border:1px solid var(--border);border-radius:8px;background:none;color:var(--text-mid);font-size:12px;cursor:pointer">New profile</button>' +
    '<button type="button" id="lm-save-btn" style="padding:8px 16px;border:none;border-radius:8px;background:var(--accent);color:#0C0702;font-size:12px;font-weight:700;cursor:pointer">Save profile</button>' +
    '</div>';

  lmPopulateTypeSelect(type);
  lmPopulateProfileSelect(_lmPendingEditId || '');
  lmRenderEditorPanels(type);
  lmApplyTypeMeta(type);
  lmBindInterfaceEvents();

  if (_lmPendingEditId) {
    await lmLoadProfileById(_lmPendingEditId, type);
  } else {
    lmResetEditor(type, true);
    lmApplyPrefill();
  }
}

function lmPopulateTypeSelect(type) {
  var sel = document.getElementById('lm-type-sel');
  if (!sel) return;
  sel.innerHTML = ['ingredient', 'spice', 'tool', 'cut', 'preservation'].map(function (t) {
    var m = TCJ_LIB_TYPE_META[t] || {};
    return '<option value="' + t + '"' + (t === type ? ' selected' : '') + '>' + esc((m.emoji || '') + ' ' + (m.short || t)) + '</option>';
  }).join('');
}

function lmPopulateProfileSelect(selectedId) {
  var sel = document.getElementById('lm-profile-sel');
  if (!sel) return;
  var opts = ['<option value="">— New profile —</option>'];
  _lmProfiles.forEach(function (p) {
    opts.push('<option value="' + esc(p.id) + '"' + (String(p.id) === String(selectedId) ? ' selected' : '') + '>' + esc(p.name || p.slug || p.id) + '</option>');
  });
  sel.innerHTML = opts.join('');
}

function lmMakePanel(id, title, desc, nodes, open) {
  var panel = document.createElement('div');
  panel.className = 'ls-panel' + (open ? '' : ' collapsed');
  if (id) panel.id = id;
  var head = document.createElement('button');
  head.type = 'button';
  head.className = 'ls-panel-head';
  head.setAttribute('aria-expanded', open ? 'true' : 'false');
  var chev = document.createElement('span');
  chev.className = 'ls-panel-chevron';
  chev.textContent = '▾';
  var titles = document.createElement('span');
  titles.className = 'ls-panel-titles';
  var tTitle = document.createElement('span');
  tTitle.className = 'ls-panel-title';
  tTitle.textContent = title;
  var tDesc = document.createElement('span');
  tDesc.className = 'ls-panel-desc';
  tDesc.textContent = desc || '';
  titles.appendChild(tTitle);
  titles.appendChild(tDesc);
  head.appendChild(chev);
  head.appendChild(titles);
  head.onclick = function () {
    var collapsed = panel.classList.toggle('collapsed');
    head.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
  };
  var body = document.createElement('div');
  body.className = 'ls-panel-body';
  (nodes || []).forEach(function (n) { if (n) body.appendChild(n); });
  panel.appendChild(head);
  panel.appendChild(body);
  return panel;
}

function lmMakeFieldRow(type, f) {
  var row = document.createElement('div');
  row.className = 'ls-row';
  var id = 'lm-' + f.id;
  var hint = tcjLibFieldHint(type, f.id);
  if (f.type === 'checkbox') {
    row.style.cssText = 'display:flex;align-items:center;gap:10px';
    var cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.id = id;
    cb.style.cssText = 'width:16px;height:16px;accent-color:var(--accent)';
    var lblCb = document.createElement('label');
    lblCb.className = 'ls-label';
    lblCb.htmlFor = id;
    lblCb.style.margin = '0';
    lblCb.textContent = f.label;
    row.appendChild(cb);
    row.appendChild(lblCb);
    return row;
  }
  var lbl = document.createElement('label');
  lbl.className = 'ls-label';
  lbl.htmlFor = id;
  lbl.textContent = f.label;
  row.appendChild(lbl);
  if (f.type === 'select') {
    var sel = document.createElement('select');
    sel.className = 'ls-select';
    sel.id = id;
    (f.opts || []).forEach(function (o) {
      var opt = document.createElement('option');
      opt.value = o;
      opt.textContent = o;
      sel.appendChild(opt);
    });
    row.appendChild(sel);
  } else if (f.type === 'textarea') {
    var ta = document.createElement('textarea');
    ta.className = 'ls-textarea';
    ta.id = id;
    if (hint) ta.placeholder = hint;
    row.appendChild(ta);
  } else {
    var inp = document.createElement('input');
    inp.className = 'ls-input';
    inp.id = id;
    inp.type = 'text';
    inp.placeholder = f.ph || hint || '';
    row.appendChild(inp);
  }
  return row;
}

function lmRenderEditorPanels(type) {
  var root = document.getElementById('lm-panels-root');
  if (!root) return;
  root.replaceChildren();

  var identity = document.createElement('div');
  identity.className = 'ls-2col';
  identity.innerHTML =
    '<div class="ls-row"><label class="ls-label" for="lm-f-name">Name <span>*</span></label><input class="ls-input" id="lm-f-name" type="text"></div>' +
    '<div class="ls-row"><label class="ls-label" for="lm-f-aka">Also known as</label><input class="ls-input" id="lm-f-aka" type="text"></div>';
  var localRow = document.createElement('div');
  localRow.className = 'ls-row';
  localRow.innerHTML = '<label class="ls-label" for="lm-f-local">Local / regional names <span style="font-weight:400;text-transform:none;letter-spacing:0">(comma separated)</span></label><input class="ls-input" id="lm-f-local" type="text">';
  root.appendChild(lmMakePanel('lm-panel-identity', 'Identity', 'Official name, aliases, and regional names', [identity, localRow], true));

  var photos = document.createElement('div');
  photos.innerHTML =
    '<div class="ls-row"><label class="ls-label">Hero image <span>*</span></label>' +
    '<div class="ls-img-box" onclick="document.getElementById(\'lm-f-img-file\').click()"><div id="lm-f-img-preview"></div><div class="ls-img-text">Click to upload hero image</div></div>' +
    '<input type="file" id="lm-f-img-file" accept="image/*" class="ls-hidden" onchange="lmPreviewHeroImage(this)">' +
    '<input class="ls-input" id="lm-f-img-url" type="text" style="margin-top:8px" placeholder="Or paste image URL"></div>' +
    '<div class="ls-row"><label class="ls-label">Mise circle photo</label>' +
    '<div id="lm-mise-empty" class="ls-img-box" onclick="document.getElementById(\'lm-f-mise-file\').click()" style="max-width:340px;margin:0 auto"><div class="ls-img-text">Click to upload mise photo</div></div>' +
    '<div id="lm-mise-editor" style="display:none"><div class="lib-mise-editor-wrap"><div class="sr-img-hero-ring-wrap" id="lm-mise-ring-wrap"></div></div>' +
    '<div class="lib-mise-zoom"><button type="button" onclick="lmMiseZoom(-1)">−</button><span id="lm-mise-zoom-val">100%</span><button type="button" onclick="lmMiseZoom(1)">+</button></div>' +
    '<p style="font-size:11px;color:var(--text-muted);text-align:center;margin-top:8px">Drag to reposition within the ring</p>' +
    '<div style="text-align:center;margin-top:10px"><button type="button" class="ls-btn ls-btn-secondary" style="font-size:12px;padding:8px 16px" onclick="lmClearMiseImage()">Remove mise photo</button></div></div>' +
    '<input type="file" id="lm-f-mise-file" accept="image/*" class="ls-hidden" onchange="lmHandleMiseFile(this)">' +
    '<input type="hidden" id="lm-f-mise-url">' +
    '<select class="ls-select" id="lm-f-image-status" style="margin-top:12px;max-width:360px">' +
    '<option value="missing">No mise image</option><option value="draft">Draft — not shown publicly</option><option value="approved">Approved — visible in Library & print</option></select></div>';
  root.appendChild(lmMakePanel('lm-panel-photos', 'Photos', 'Hero image and optional circular mise image', [photos], false));

  var specs = TCJ_LIB_FIELD_PANELS[type] || [];
  specs.forEach(function (spec, i) {
    var nodes = (spec.fields || []).map(function (fid) {
      var f = tcjLibGetField(type, fid);
      return f ? lmMakeFieldRow(type, f) : null;
    }).filter(Boolean);
    root.appendChild(lmMakePanel('lm-panel-type-' + i, spec.title, spec.desc, nodes, !!spec.open));
  });

  var voice = document.createElement('div');
  voice.innerHTML =
    '<div class="ls-row"><label class="ls-label" for="lm-f-chefs">Chef\'s notes</label><textarea class="ls-textarea" id="lm-f-chefs"></textarea></div>' +
    '<div class="ls-row"><label class="ls-label" for="lm-f-brand">Recommended brand</label><input class="ls-input" id="lm-f-brand" type="text"></div>' +
    '<div class="ls-row"><label class="ls-label" for="lm-f-dyk">Did you know?</label><textarea class="ls-textarea" id="lm-f-dyk" style="min-height:72px"></textarea></div>';
  root.appendChild(lmMakePanel('lm-panel-voice', 'From the Journal', 'Kitchen notes, brand pick, and one surprising fact', [voice], false));

  var publishGrid = document.createElement('div');
  publishGrid.className = 'ls-2col';
  publishGrid.innerHTML =
    '<div class="ls-row"><label class="ls-label" for="lm-f-status">Status</label><select class="ls-select" id="lm-f-status"><option value="draft">Draft — not visible</option><option value="published">Published — visible</option></select></div>' +
    '<div class="ls-row"><label class="ls-label" for="lm-f-visibility">Visibility</label><select class="ls-select" id="lm-f-visibility"><option value="public">Public — everyone</option><option value="members">Members only</option><option value="paid">Paid members only</option></select></div>';
  if (type === 'ingredient') {
    var gov = document.createElement('div');
    gov.className = 'ls-row';
    gov.style.gridColumn = '1 / -1';
    gov.innerHTML = '<label class="ls-label" for="lm-f-governed-id">Governed ingredient ID</label><input class="ls-input" id="lm-f-governed-id" type="text" placeholder="e.g. 123">';
    publishGrid.appendChild(gov);
  }
  root.appendChild(lmMakePanel('lm-panel-publish', 'Publishing', 'Draft vs published and who can see this profile', [publishGrid], false));

  var adminNotes = document.createElement('div');
  adminNotes.className = 'ls-row';
  adminNotes.innerHTML = '<label class="ls-label" for="lm-f-internal-notes">Internal notes (admin only)</label><textarea class="ls-textarea" id="lm-f-internal-notes" style="min-height:110px"></textarea>';
  root.appendChild(lmMakePanel('lm-panel-admin', 'Admin internal notes', 'Internal notes for editorial and moderation context', [adminNotes], false));
}

function lmApplyTypeMeta(type) {
  var meta = TCJ_LIB_TYPE_META[type] || {};
  var ex = meta.ex || {};
  var tag = document.getElementById('lm-tagline');
  if (tag) {
    tag.innerHTML = meta.tagline
      ? ('<em>' + esc(meta.short || type) + '.</em> ' + esc(meta.tagline))
      : 'Complete profile details and save.';
  }
  var name = document.getElementById('lm-f-name');
  var aka = document.getElementById('lm-f-aka');
  var local = document.getElementById('lm-f-local');
  var chefs = document.getElementById('lm-f-chefs');
  var brand = document.getElementById('lm-f-brand');
  var dyk = document.getElementById('lm-f-dyk');
  var imgUrl = document.getElementById('lm-f-img-url');
  if (name) name.placeholder = 'e.g. ' + (ex.name || '');
  if (aka) aka.placeholder = 'e.g. ' + (ex.aka || '');
  if (local) local.placeholder = 'e.g. ' + (ex.local || '');
  if (chefs && !chefs.value) chefs.placeholder = meta.chefs || '';
  if (brand) brand.placeholder = meta.brand || '';
  if (dyk && !dyk.value) dyk.placeholder = meta.dyk || '';
  if (imgUrl) imgUrl.placeholder = 'Paste URL — ' + (ex.img || 'clear photo on neutral background');
}

function lmBindInterfaceEvents() {
  var typeSel = document.getElementById('lm-type-sel');
  var profileSel = document.getElementById('lm-profile-sel');
  var loadBtn = document.getElementById('lm-load-btn');
  var saveBtn = document.getElementById('lm-save-btn');
  var newBtn = document.getElementById('lm-new-btn');
  if (typeSel) {
    typeSel.onchange = function () {
      _lmEditType = typeSel.value;
      LIB_CURRENT_TYPE = typeSel.value;
      _lmPendingEditId = null;
      loadLmInterface();
    };
  }
  if (loadBtn) {
    loadBtn.onclick = function () {
      var pick = profileSel ? profileSel.value : '';
      if (!pick) {
        _lmPendingEditId = null;
        _lmEditSlug = null;
        lmResetEditor(_lmEditType || LIB_CURRENT_TYPE, true);
        lmApplyPrefill();
        lmSetMsg('Ready for a new profile.', 'info');
        return;
      }
      _lmPendingEditId = pick;
      lmLoadProfileById(pick, _lmEditType || LIB_CURRENT_TYPE);
    };
  }
  if (saveBtn) saveBtn.onclick = saveLibEditor;
  if (newBtn) {
    newBtn.onclick = function () {
      _lmPendingEditId = null;
      _lmEditSlug = null;
      if (profileSel) profileSel.value = '';
      lmResetEditor(_lmEditType || LIB_CURRENT_TYPE, true);
      lmApplyPrefill();
      lmSetMsg('Started a new profile.', 'info');
    };
  }
}

function lmResetEditor(type, clearIds) {
  var root = document.getElementById('lm-panels-root');
  if (!root) return;
  root.querySelectorAll('input, textarea, select').forEach(function (el) {
    if (!el.id) return;
    if (el.type === 'checkbox') el.checked = false;
    else if (el.tagName === 'SELECT') {
      if (el.id === 'lm-f-status') el.value = 'draft';
      else if (el.id === 'lm-f-visibility') el.value = 'public';
      else if (el.id === 'lm-f-image-status') el.value = 'missing';
      else if (el.options.length) el.selectedIndex = 0;
    } else {
      el.value = '';
    }
  });
  var prev = document.getElementById('lm-f-img-preview');
  if (prev) prev.innerHTML = '';
  var f = document.getElementById('lm-f-img-file');
  if (f) f.value = '';
  lmShowMiseEditor(false);
  if (clearIds) {
    _lmPendingEditId = null;
    _lmEditSlug = null;
    var psel = document.getElementById('lm-profile-sel');
    if (psel) psel.value = '';
  }
  lmApplyTypeMeta(type);
}

function lmApplyPrefill() {
  if (!_lmPrefill) return;
  var nm = document.getElementById('lm-f-name');
  if (nm && _lmPrefill.name) nm.value = _lmPrefill.name;
  if (_lmPrefill.governedId) {
    var gid = document.getElementById('lm-f-governed-id');
    if (gid) gid.value = _lmPrefill.governedId;
  }
  _lmPrefill = null;
}

function lmSetVal(fid, value) {
  var el = document.getElementById('lm-' + fid);
  if (!el || value === null || value === undefined) return;
  if (el.type === 'checkbox') el.checked = !!value;
  else el.value = value;
}

function lmFormGetVal(fid) {
  var el = document.getElementById('lm-' + fid);
  if (!el) return null;
  if (el.type === 'checkbox') return el.checked;
  return String(el.value || '').trim();
}

async function lmLoadProfileById(id, type) {
  if (!id) return;
  lmSetMsg('Loading profile…', 'info');
  try {
    var profile = await rpc('admin_get_library_profile', { p_type: type, p_id: id });
    if (!profile) throw new Error('Profile not found');
    _lmPendingEditId = id;
    _lmEditSlug = profile.slug || null;
    tcjLibFillForm(profile, lmSetVal, type);
    lmSetVal('f-internal-notes', profile.internal_notes || '');
    if (profile.image_url) {
      var heroPrev = document.getElementById('lm-f-img-preview');
      if (heroPrev) {
        heroPrev.innerHTML = '<img src="' + esc(profile.image_url) + '" style="max-height:140px;border-radius:6px">';
      }
    }
    if (profile.mise_image_url) {
      lmInitMiseEditor();
      lmShowMiseEditor(true);
      if (_lmMiseEditor) _lmMiseEditor.loadFromUrl(profile.mise_image_url);
    } else {
      lmShowMiseEditor(false);
    }
    lmApplyTypeMeta(type);
    var psel = document.getElementById('lm-profile-sel');
    if (psel) psel.value = String(id);
    lmSetMsg('Loaded "' + (profile.name || profile.slug || 'profile') + '".', 'success');
  } catch (e) {
    lmSetMsg('Could not load profile: ' + (e.message || e), 'error');
  }
}

function lmExpandPanels(open) {
  document.querySelectorAll('#lm-panels-root .ls-panel').forEach(function (p) {
    p.classList.toggle('collapsed', !open);
    var head = p.querySelector('.ls-panel-head');
    if (head) head.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
}

function lmGetSessionToken() {
  try {
    var raw = localStorage.getItem('tcj_session');
    var s = raw ? JSON.parse(raw) : null;
    return s && s.access_token ? s.access_token : '';
  } catch (_) {
    return '';
  }
}

async function lmUploadStorageBlob(blobOrFile, relativePath, contentType) {
  var token = lmGetSessionToken();
  if (!token || !window.SUPA_URL) throw new Error('Missing Supabase session');
  var res = await fetch(window.SUPA_URL + '/storage/v1/object/library-images/' + relativePath, {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': contentType || 'image/jpeg',
      'x-upsert': 'true'
    },
    body: blobOrFile
  });
  if (!res.ok) throw new Error('Upload failed');
  return window.SUPA_URL + '/storage/v1/object/public/library-images/' + relativePath;
}

async function lmPreviewHeroImage(input) {
  if (!input.files || !input.files[0]) return;
  var file = input.files[0];
  var preview = document.getElementById('lm-f-img-preview');
  var urlField = document.getElementById('lm-f-img-url');
  var reader = new FileReader();
  reader.onload = function (e) {
    if (preview) preview.innerHTML = '<img src="' + esc(e.target.result) + '" style="max-height:140px;border-radius:6px">';
  };
  reader.readAsDataURL(file);
  try {
    var ext = file.name.split('.').pop().toLowerCase() || 'jpg';
    var path = 'library/' + (_lmEditType || LIB_CURRENT_TYPE) + '/' + Date.now() + '-' + Math.random().toString(36).slice(2) + '.' + ext;
    var publicUrl = await lmUploadStorageBlob(file, path, file.type || 'image/jpeg');
    if (urlField) urlField.value = publicUrl;
    if (preview) preview.innerHTML = '<img src="' + esc(publicUrl) + '" style="max-height:140px;border-radius:6px">';
    lmSetMsg('Hero image uploaded.', 'success');
  } catch (_) {
    lmSetMsg('Hero upload failed — paste URL manually.', 'error');
  }
  input.value = '';
}

function lmInitMiseEditor() {
  var wrap = document.getElementById('lm-mise-ring-wrap');
  if (!wrap || wrap._miseInited) return;
  wrap._miseInited = true;
  wrap.innerHTML =
    (window.LibraryMise && LibraryMise.ringSvg ? LibraryMise.ringSvg : '') +
    '<div class="sr-img-hero-circle lib-mise-circle" id="lm-mise-circle">' +
    '<img id="lm-mise-img" class="sr-img-hero-img" alt="Mise preview" draggable="false" decoding="async">' +
    '<div id="lm-mise-drag" class="ls-mise-drag" title="Drag to reposition"></div></div>';
  _lmMiseEditor = window.CircularHeroEditor && CircularHeroEditor.create ? CircularHeroEditor.create({
    imgEl: document.getElementById('lm-mise-img'),
    circleEl: document.getElementById('lm-mise-circle'),
    overlayEl: document.getElementById('lm-mise-drag'),
    zoomValEl: document.getElementById('lm-mise-zoom-val'),
    ringWrapEl: wrap
  }) : null;
}

function lmShowMiseEditor(show) {
  var empty = document.getElementById('lm-mise-empty');
  var editor = document.getElementById('lm-mise-editor');
  if (empty) empty.style.display = show ? 'none' : 'block';
  if (editor) editor.style.display = show ? 'block' : 'none';
}

function lmHandleMiseFile(input) {
  if (!input.files || !input.files[0]) return;
  lmInitMiseEditor();
  lmShowMiseEditor(true);
  if (_lmMiseEditor && _lmMiseEditor.loadFromFile) _lmMiseEditor.loadFromFile(input.files[0]);
  var st = document.getElementById('lm-f-image-status');
  if (st && st.value === 'missing') st.value = 'draft';
  input.value = '';
}

function lmMiseZoom(dir) {
  if (_lmMiseEditor && _lmMiseEditor.adjustZoom) _lmMiseEditor.adjustZoom(dir);
}

function lmClearMiseImage() {
  var urlField = document.getElementById('lm-f-mise-url');
  if (urlField) urlField.value = '';
  lmShowMiseEditor(false);
  var st = document.getElementById('lm-f-image-status');
  if (st) st.value = 'missing';
  if (_lmMiseEditor && _lmMiseEditor.state) _lmMiseEditor.state.hasImage = false;
}

async function lmUploadMiseImage(dataUrl) {
  if (!dataUrl) return '';
  if (!dataUrl.startsWith('data:')) return dataUrl;
  try {
    var blob = await fetch(dataUrl).then(function (r) { return r.blob(); });
    var ext = (blob.type && blob.type.indexOf('png') >= 0) ? 'png' : 'jpg';
    var path = 'library/mise/' + (_lmEditType || LIB_CURRENT_TYPE) + '/' + Date.now() + '-mise.' + ext;
    return await lmUploadStorageBlob(blob, path, blob.type || 'image/jpeg');
  } catch (_) {
    return '';
  }
}

async function saveLibEditor() {
  var type = _lmEditType || LIB_CURRENT_TYPE;
  var name = lmFormGetVal('f-name');
  if (!name) { lmSetMsg('Name is required.', 'error'); return; }
  if (!lmFormGetVal('f-img-url')) { lmSetMsg('Hero image URL is required.', 'error'); return; }
  var saveBtn = document.getElementById('lm-save-btn');
  if (saveBtn) { saveBtn.disabled = true; saveBtn.textContent = 'Saving…'; }
  try {
    var miseUrl = lmFormGetVal('f-mise-url');
    if (_lmMiseEditor && _lmMiseEditor.hasImage && _lmMiseEditor.hasImage()) {
      if (saveBtn) saveBtn.textContent = 'Baking mise…';
      var baked = await _lmMiseEditor.bake();
      if (baked) {
        var uploaded = await lmUploadMiseImage(baked);
        if (uploaded) {
          miseUrl = uploaded;
          lmSetVal('f-mise-url', uploaded);
        }
      }
      if (saveBtn) saveBtn.textContent = 'Saving…';
    }

    var payload = tcjLibBuildPayload(type, lmFormGetVal, { slug: _lmEditSlug || undefined });
    payload.mise_image_url = miseUrl || null;
    var notes = lmFormGetVal('f-internal-notes');
    if (notes) payload.internal_notes = notes;

    var wasNew = !_lmPendingEditId;
    await rpc('admin_upsert_library_profile', {
      p_type: type,
      p_id: _lmPendingEditId || null,
      p_payload: payload
    });
    lmSetMsg('Profile saved successfully.', 'success');
    if (wasNew) {
      _lmPendingEditId = null;
      _lmEditSlug = payload.slug || null;
    }
    await loadLmInterface();
    if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = 'Save profile'; }
  } catch (e) {
    lmSetMsg('Save error: ' + (e.message || e), 'error');
    if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = 'Save profile'; }
  }
}

function openLibCsvModal() {
  _libCsvData = null;
  var modal = document.getElementById('lib-csv-modal');
  if (!modal) return;
  document.getElementById('lib-csv-type-label').textContent = LIB_CURRENT_TYPE;
  document.getElementById('lib-csv-preview-section').style.display = 'none';
  document.getElementById('lib-csv-error').style.display = 'none';
  document.getElementById('lib-csv-import-btn').disabled = true;
  document.getElementById('lib-csv-status').textContent = '';
  document.getElementById('lib-csv-file-input').value = '';
  modal.classList.add('open');
}

function closeLibCsvModal() {
  var modal = document.getElementById('lib-csv-modal');
  if (modal) modal.classList.remove('open');
  _libCsvData = null;
}

function handleLibCsvFile(file) {
  if (!file || !file.name.endsWith('.csv')) {
    document.getElementById('lib-csv-error').textContent = 'Please upload a .csv file.';
    document.getElementById('lib-csv-error').style.display = 'block';
    return;
  }
  if (typeof Papa === 'undefined') {
    alert('CSV parser not loaded');
    return;
  }
  document.getElementById('lib-csv-error').style.display = 'none';
  Papa.parse(file, {
    header: true, skipEmptyLines: true,
    complete: function (results) {
      if (results.errors.length) {
        document.getElementById('lib-csv-error').textContent = results.errors[0].message;
        document.getElementById('lib-csv-error').style.display = 'block';
        return;
      }
      if (!results.data.length) {
        document.getElementById('lib-csv-error').textContent = 'No data rows found.';
        document.getElementById('lib-csv-error').style.display = 'block';
        return;
      }
      _libCsvData = results.data.map(function (row) {
        return tcjLibCsvRowToPayload(LIB_CURRENT_TYPE, row);
      }).filter(function (p) { return p.name; });
      var prev = document.getElementById('lib-csv-preview-table');
      var cols = Object.keys(results.data[0] || {}).slice(0, 8);
      prev.innerHTML = '<thead><tr>' + cols.map(function (c) {
        return '<th style="padding:6px 10px;text-align:left;font-size:11px;border-bottom:1px solid var(--border)">' + esc(c) + '</th>';
      }).join('') + '</tr></thead><tbody>' +
        results.data.slice(0, 5).map(function (row) {
          return '<tr>' + cols.map(function (c) {
            return '<td style="padding:6px 10px;font-size:11px;border-bottom:1px solid rgba(255,255,255,.04)">' + esc(String(row[c] || '').slice(0, 40)) + '</td>';
          }).join('') + '</tr>';
        }).join('') + '</tbody>';
      document.getElementById('lib-csv-row-count').textContent = _libCsvData.length + ' profiles ready';
      document.getElementById('lib-csv-preview-section').style.display = 'block';
      document.getElementById('lib-csv-import-btn').disabled = !_libCsvData.length;
    }
  });
}

async function importLibCsv() {
  if (!_libCsvData || !_libCsvData.length) return;
  var btn = document.getElementById('lib-csv-import-btn');
  var status = document.getElementById('lib-csv-status');
  btn.disabled = true;
  btn.textContent = 'Importing…';
  try {
    var result = await rpc('admin_bulk_upsert_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_rows: _libCsvData
    });
    status.style.color = '#6dc86d';
    status.textContent = 'Done — ' + (result.inserted || 0) + ' inserted, ' + (result.updated || 0) + ' updated.';
    setTimeout(function () {
      closeLibCsvModal();
      loadLibProfiles(undefined, undefined, true);
    }, 1500);
  } catch (e) {
    status.style.color = '#dc5050';
    status.textContent = e.message || String(e);
    btn.disabled = false;
    btn.textContent = 'Import';
  }
}

async function loadLibCoverage() {
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading coverage…</div>';
  try {
    var types = ['ingredient', 'spice', 'tool', 'cut', 'preservation'];
    var results = await Promise.all(types.map(function (t) {
      return rpc('admin_get_library_coverage', { p_type: t, p_limit: 30 }).then(function (d) {
        return { type: t, data: d };
      });
    }));
    buildLibCoveragePanel(panel, results);
  } catch (e) {
    panel.innerHTML = '<div class="ap-empty">Coverage unavailable: ' + esc(e.message || e) +
      '<div style="margin-top:8px;font-size:11px">Run <code>fix-library-unified.sql</code> in Supabase.</div></div>';
  }
}

function buildLibCoveragePanel(panel, results) {
  var typeLabels = { ingredient: '🌿 Ingredients', spice: '🌶 Spices', tool: '🔪 Tools', cut: '🥩 Cuts', preservation: '🫙 Preservation' };
  var html = '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.55">' +
    'Prioritised worklist: published profiles matching <strong>zero</strong> approved recipes, and governed ingredients used in recipes with no library link.</div>';
  results.forEach(function (r) {
    var s = r.data.summary || {};
    var zero = r.data.zero_recipe_profiles || [];
    var gaps = r.data.ingredient_gaps || [];
    html += '<div style="background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:16px">' +
      '<div style="font-family:Cormorant Garamond,serif;font-size:1.15rem;font-weight:700;color:var(--text-high);margin-bottom:10px">' + (typeLabels[r.type] || r.type) + '</div>' +
      '<div style="display:flex;gap:16px;flex-wrap:wrap;font-size:11px;color:var(--text-mid);margin-bottom:12px">' +
      '<span>Published: <strong style="color:var(--text-high)">' + (s.published || 0) + '</strong></span>' +
      '<span>With recipes: <strong style="color:#6dc86d">' + (s.with_recipes || 0) + '</strong></span>' +
      '<span>Zero matches: <strong style="color:#c4973b">' + (s.zero_recipes || 0) + '</strong></span>';
    if (r.type === 'ingredient') {
      html += '<span>Ingredient gaps: <strong style="color:#dc5050">' + (s.ingredient_gaps || 0) + '</strong></span>';
    }
    html += '</div>';
    if (zero.length) {
      html += '<div style="font-size:10px;font-weight:700;text-transform:uppercase;color:#c4973b;margin-bottom:6px">Dead published profiles (no recipe matches)</div>' +
        '<ul style="margin:0 0 12px;padding-left:18px;font-size:12px;color:var(--text-high)">' +
        zero.map(function (p) {
          return '<li style="margin-bottom:4px">' + esc(p.name) +
            ' <button data-action="lib-cov-edit" data-lid="' + esc(p.id) + '" data-ltype="' + esc(r.type) + '" ' +
            'style="font-size:10px;padding:2px 8px;border:1px solid var(--accent);background:none;color:var(--accent);border-radius:5px;cursor:pointer;margin-left:6px">Edit</button></li>';
        }).join('') + '</ul>';
    }
    if (r.type === 'ingredient' && gaps.length) {
      html += '<div style="font-size:10px;font-weight:700;text-transform:uppercase;color:#dc5050;margin-bottom:6px">Recipe ingredients missing a library profile</div>' +
        '<ul style="margin:0;padding-left:18px;font-size:12px;color:var(--text-high)">' +
        gaps.map(function (g) {
          return '<li style="margin-bottom:4px">' + esc(g.ingredient_name) + ' <span style="color:var(--text-muted);font-size:10px">#' + g.ingredient_id + ' · ' + g.recipe_count + ' recipes</span>' +
            ' <button data-action="lib-cov-new" data-prefill="' + esc(g.ingredient_name) + '" data-ingid="' + g.ingredient_id + '" ' +
            'style="font-size:10px;padding:2px 8px;border:1px solid var(--border);background:none;color:var(--text-mid);border-radius:5px;cursor:pointer;margin-left:6px">+ Draft</button></li>';
        }).join('') + '</ul>';
    }
    if (!zero.length && !(r.type === 'ingredient' && gaps.length)) {
      html += '<div style="font-size:11px;color:var(--text-muted)">No gaps in this slice.</div>';
    }
    html += '</div>';
  });
  panel.innerHTML = html;
  panel.onclick = function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    if (btn.dataset.action === 'lib-cov-edit') {
      LIB_CURRENT_TYPE = btn.dataset.ltype;
      openLibEditor(btn.dataset.lid);
    }
    if (btn.dataset.action === 'lib-cov-new') {
      LIB_CURRENT_TYPE = 'ingredient';
      _lmEditType = 'ingredient';
      _lmPendingEditId = null;
      _lmPrefill = {
        name: btn.dataset.prefill || '',
        governedId: btn.dataset.ingid || ''
      };
      switchLibTab('lm-interface');
    }
  };
}

window.lmExpandPanels = lmExpandPanels;
window.lmPreviewHeroImage = lmPreviewHeroImage;
window.lmHandleMiseFile = lmHandleMiseFile;
window.lmMiseZoom = lmMiseZoom;
window.lmClearMiseImage = lmClearMiseImage;
