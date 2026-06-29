// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

var _RM_LIST_TABS = ['all','pending','approved','rejected'];
var _RM_OPS_TABS  = ['taxonomy','sourcelinks','nutrition','printqueue','collections','audit'];
var _RM_SPOTLIGHT_TABS = ['rotw','featured','notes'];
var _rmPage = 1;
var _RM_PAGE_SIZE = 50;
var _rmListTotal = 0;

function getRejectReasons() {
  try {
    var s = localStorage.getItem('tcj_rm_reject_reasons');
    if (s) { var a = JSON.parse(s); if (Array.isArray(a) && a.length) return a; }
  } catch(e) { console.warn('reject reasons cache', e); }
  return ['Incomplete ingredients','Unclear method','Duplicate recipe','Inappropriate content','Missing source credit','Poor formatting','Other'];
}

function ensureRmCatFilter() {
  var sel = document.getElementById('rmgmt-cat-filter');
  if (!sel || sel.dataset.init === '1') return Promise.resolve();
  return (typeof tcjFetchCategories === 'function' ? tcjFetchCategories() : Promise.resolve([]))
    .then(function(rows) {
      if (sel.dataset.init === '1') return;
      sel.dataset.init = '1';
      (rows || []).forEach(function(c) {
        var name = c.name || c;
        if (!name) return;
        var o = document.createElement('option');
        o.value = name;
        o.textContent = name;
        sel.appendChild(o);
      });
    });
}

function switchRecipeTab(tab) {
  if (_RM_OPS_TABS.indexOf(tab) !== -1) {
    localStorage.setItem('tcj_rm_interface_tab', tab);
    tab = 'rmsettings';
  }
  if (_currentRecipeTab !== tab) _rmPage = 1;
  _currentRecipeTab = tab;
  localStorage.setItem('tcj_active_recipe_tab', tab);
  document.querySelectorAll('#v-recipe-mgmt .ap-inner-tab').forEach(function(t) {
    t.classList.toggle('active', t.dataset.tab === tab);
  });
  var listPanel = document.getElementById('rmgmt-list-panel');
  var anaPanel  = document.getElementById('rmgmt-analytics-panel');
  var opsPanel  = document.getElementById('rmgmt-ops-panel');
  var setPanel  = document.getElementById('rmgmt-rmsettings-panel');
  var extPanel  = document.getElementById('rmgmt-extra-panel');
  var bulkPanel = document.getElementById('rmgmt-bulkrecipes-panel');
  if (listPanel) listPanel.style.display = _RM_LIST_TABS.indexOf(tab) !== -1 ? 'block' : 'none';
  if (bulkPanel) bulkPanel.style.display = tab === 'bulkrecipes' ? 'block' : 'none';
  if (_RM_LIST_TABS.indexOf(tab) !== -1) ensureRmCatFilter();
  if (anaPanel)  anaPanel.style.display  = tab === 'analytics' ? 'block' : 'none';
  if (opsPanel)  opsPanel.style.display  = 'none';
  if (setPanel)  setPanel.style.display  = tab === 'rmsettings' ? 'block' : 'none';
  if (extPanel)  extPanel.style.display  = _RM_SPOTLIGHT_TABS.indexOf(tab) !== -1 ? 'block' : 'none';
  var bulkAgentBtn = document.getElementById('rm-bulk-agent-btn');
  if (bulkAgentBtn) bulkAgentBtn.style.display = tab === 'pending' ? 'inline-flex' : 'none';
  var bulkApproveBtn = document.getElementById('rm-bulk-approve-btn');
  if (bulkApproveBtn) bulkApproveBtn.style.display = tab === 'pending' ? 'inline-flex' : 'none';
  var bulkRejectBtn = document.getElementById('rm-bulk-reject-btn');
  if (bulkRejectBtn) bulkRejectBtn.style.display = tab === 'pending' ? 'inline-flex' : 'none';
  if (tab === 'analytics')  { loadRecipeAnalytics(); return; }
  if (tab === 'rmsettings') { loadRMInterfaceSettings(); return; }
  if (tab === 'bulkrecipes') {
    var bulkPanel = document.getElementById('rmgmt-bulkrecipes-panel');
    if (bulkPanel) bulkPanel.style.display = 'block';
    if (typeof window.bulkRecipeEditor !== 'undefined' &&
        window.bulkRecipeEditor.loadBulkRecipesTab) {
      window.bulkRecipeEditor.loadBulkRecipesTab();
    } else {
      console.warn('Bulk Recipe Editor not loaded');
    }
    return;
  }
  if (tab === 'rotw')  { loadROTW(); return; }
  if (tab === 'featured') {
    if (opsPanel) opsPanel.style.display = 'block';
    var opsElF = document.getElementById('rm-ops-content');
    if (opsElF) loadRMTab('featured', opsElF);
    return;
  }
  if (tab === 'notes') { loadRecipeNotes(); return; }
  loadRecipeMgmt(tab);
}

function renderRmPagination() {
  var el = document.getElementById('rmgmt-pagination');
  if (!el) return;
  var totalPages = Math.max(1, Math.ceil(_rmListTotal / _RM_PAGE_SIZE));
  if (_rmListTotal <= _RM_PAGE_SIZE) { el.style.display = 'none'; return; }
  el.style.display = 'flex';
  el.innerHTML =
    '<button type="button" class="ap-pg-btn" ' + (_rmPage <= 1 ? 'disabled' : '') + ' data-rm-pg="prev">Prev</button>' +
    '<span style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);padding:0 12px">Page ' + _rmPage + ' of ' + totalPages + ' (' + _rmListTotal + ' recipes)</span>' +
    '<button type="button" class="ap-pg-btn" ' + (_rmPage >= totalPages ? 'disabled' : '') + ' data-rm-pg="next">Next</button>';
  el.querySelectorAll('[data-rm-pg]').forEach(function(btn) {
    btn.addEventListener('click', function() {
      if (btn.dataset.rmPg === 'prev' && _rmPage > 1) { _rmPage--; loadRecipeMgmt(_currentRecipeTab); }
      if (btn.dataset.rmPg === 'next' && _rmPage < totalPages) { _rmPage++; loadRecipeMgmt(_currentRecipeTab); }
    });
  });
}

function getRmStatNum(id) {
  var el = document.getElementById(id);
  if (!el) return 0;
  var n = parseInt(String(el.textContent).replace(/[^\d]/g, ''), 10);
  return isNaN(n) ? 0 : n;
}

function bumpRmStats(fromStatus, toStatus) {
  if (!fromStatus || !toStatus || fromStatus === toStatus) return;
  var keys = {
    pending: ['rmgmt-pending', 'badge-pending', 'rtab-badge-pending'],
    approved: ['rmgmt-approved'],
    rejected: ['rmgmt-rejected']
  };
  function adjust(status, delta) {
    var list = keys[status];
    if (!list) return;
    list.forEach(function(statId) {
      setEl(statId, Math.max(0, getRmStatNum(statId) + delta));
    });
  }
  adjust(fromStatus, -1);
  adjust(toStatus, 1);
}

function findRecipeRow(id) {
  var tbody = document.getElementById('rmgmt-tbody');
  return tbody ? tbody.querySelector('tr[data-recipe-id="' + id + '"]') : null;
}

function removeRecipeRowAnimated(tr, cb) {
  if (!tr) { if (cb) cb(); return; }
  tr.style.transition = 'opacity 0.18s ease, transform 0.18s ease';
  tr.style.opacity = '0';
  tr.style.transform = 'translateX(10px)';
  tr.style.pointerEvents = 'none';
  setTimeout(function() {
    tr.remove();
    if (cb) cb();
  }, 180);
}

function afterRecipeReviewInList(id, prevStatus, newStatus) {
  var tab = _currentRecipeTab;
  var tr = findRecipeRow(id);
  var removesFromTab = (tab !== 'all' && tab !== newStatus);
  bumpRmStats(prevStatus, newStatus);
  if (removesFromTab && _rmListTotal > 0) _rmListTotal--;

  if (removesFromTab && tr) {
    removeRecipeRowAnimated(tr, function() {
      var tbody = document.getElementById('rmgmt-tbody');
      if (tbody && !tbody.querySelector('tr[data-recipe-id]')) {
        tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">No recipes found.</td></tr>';
      }
      renderRmPagination();
    });
    return;
  }
  if (tr && tab === 'all') {
    var statusTd = tr.children[5];
    if (statusTd) {
      var sc = newStatus === 'approved' ? '#4caf76' : newStatus === 'rejected' ? '#dc5050' : '#d4a017';
      statusTd.innerHTML = '<span style="padding:3px 9px;border-radius:20px;font-size:11px;font-weight:600;background:rgba(0,0,0,.2);color:' + sc + '">' + esc(newStatus) + '</span>';
    }
    return;
  }
  loadRecipeMgmt(tab, { silent: true });
}

async function loadRecipeMgmt(tab, opts) {
  opts = opts || {};
  var status = (tab === 'all') ? null : tab;
  var tbody  = document.getElementById('rmgmt-tbody');
  if (!tbody) return;
  _currentRecipeTab = tab;
  if (!opts.silent) {
    tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Loading\u2026</td></tr>';
  } else {
    tbody.style.opacity = '0.6';
  }
  try {
    var search   = (document.getElementById('rmgmt-search')   || {}).value || '';
    var catFilter = (document.getElementById('rmgmt-cat-filter') || {}).value || '';
    var stats = await rpc('admin_get_stats', {});
    _rmListTotal = (status === 'pending') ? (stats.pending || 0)
      : (status === 'approved') ? (stats.approved || 0)
      : (status === 'rejected') ? (stats.rejected || 0)
      : (stats.total || 0);
    var results = await rpc('admin_get_recipes', {
      p_status:   status,
      p_search:   search   || null,
      p_category: catFilter || null,
      p_limit: _RM_PAGE_SIZE,
      p_offset: (_rmPage - 1) * _RM_PAGE_SIZE
    });
    var rows  = Array.isArray(results) ? results : [];
    setEl('rmgmt-total',    stats.total    || 0);
    setEl('rmgmt-pending',  stats.pending  || 0);
    setEl('rmgmt-approved', stats.approved || 0);
    setEl('rmgmt-rejected', stats.rejected || 0);
    setEl('badge-pending',      stats.pending || 0);
    setEl('rtab-badge-pending', stats.pending || 0);
    allRecipes = rows;
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">No recipes found.</td></tr>';
      return;
    }
    tbody.innerHTML = '';
    rows.forEach(function(r) {
      var sc = r.status === 'approved' ? '#4caf76' : r.status === 'rejected' ? '#dc5050' : '#d4a017';
      var dt = r.submitted_at
        ? new Date(r.submitted_at).toLocaleDateString('en-GB', {day:'numeric',month:'short',year:'numeric'})
        : '\u2014';
      var tr = document.createElement('tr');
      tr.setAttribute('data-recipe-id', r.id);
      tr.style.cssText = 'cursor:pointer;border-bottom:1px solid rgba(255,255,255,0.04)';
      tr.addEventListener('click', (function(id){ return function(e){
        if (e.target.closest('.rm-row-actions')) return;
        openRecipeModal(id);
      }; })(r.id));
      tr.innerHTML =
        '<td class="ap-td" style="width:36px">' +
          '<div style="width:32px;height:32px;background:var(--text-ghost);border:1px solid var(--border);border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:14px">\uD83D\uDCD6</div>' +
        '</td>' +
        '<td class="ap-td">' +
          '<div style="font-weight:500;color:var(--text-high)">' + esc(r.recipe_name) +
            (r.featured ? '<span style="margin-left:6px;font-size:10px;padding:1px 6px;border-radius:8px;background:rgba(196,151,59,0.2);color:var(--accent)">\u2b50 Featured</span>' : '') +
            (r.recipe_of_week ? '<span style="margin-left:4px;font-size:10px;padding:1px 6px;border-radius:8px;background:rgba(91,143,212,0.2);color:#5B8FD4">\uD83C\uDFC6 Week</span>' : '') +
          '</div>' +
          '<div style="font-size:11px;color:var(--text-mid)">' + esc(r.category || '') + '</div>' +
        '</td>' +
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">@' + esc(r.username || '') + '</td>' +
        '<td class="ap-td" style="font-size:12px">' + esc([r.origin_country, r.origin_continent].filter(Boolean).join(', ')) + '</td>' +
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid);white-space:nowrap">' + dt + '</td>' +
        '<td class="ap-td">' +
          '<span style="padding:3px 9px;border-radius:20px;font-size:11px;font-weight:600;background:rgba(0,0,0,.2);color:' + sc + '">' + esc(r.status) + '</span>' +
        '</td>' +
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid);max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(r.reviewer_notes || '') + '</td>' +
        '<td class="ap-td"><div class="rm-row-actions"></div></td>';
      tbody.appendChild(tr);
      var actions = tr.querySelector('.rm-row-actions');
      if (r.status === 'pending') {
        var approveBtn = document.createElement('button');
        approveBtn.type = 'button';
        approveBtn.className = 'rm-quick-btn approve';
        approveBtn.textContent = '\u2713 Approve';
        approveBtn.title = 'Quick approve';
        approveBtn.addEventListener('click', (function(id, st){ return function(e){ quickReviewRecipe(id, 'approved', e, st); }; })(r.id, r.status));
        actions.appendChild(approveBtn);
        var rejectBtn = document.createElement('button');
        rejectBtn.type = 'button';
        rejectBtn.className = 'rm-quick-btn reject';
        rejectBtn.textContent = '\u2715 Reject';
        rejectBtn.title = 'Quick reject';
        rejectBtn.addEventListener('click', (function(id, st){ return function(e){ quickReviewRecipe(id, 'rejected', e, st); }; })(r.id, r.status));
        actions.appendChild(rejectBtn);
      } else if (r.status === 'approved') {
        var rejectApprovedBtn = document.createElement('button');
        rejectApprovedBtn.type = 'button';
        rejectApprovedBtn.className = 'rm-quick-btn reject';
        rejectApprovedBtn.textContent = '\u2715 Reject';
        rejectApprovedBtn.title = 'Reject approved recipe';
        rejectApprovedBtn.addEventListener('click', (function(id, st){ return function(e){ quickReviewRecipe(id, 'rejected', e, st); }; })(r.id, r.status));
        actions.appendChild(rejectApprovedBtn);
      } else if (r.status === 'rejected') {
        var approveRejectedBtn = document.createElement('button');
        approveRejectedBtn.type = 'button';
        approveRejectedBtn.className = 'rm-quick-btn approve';
        approveRejectedBtn.textContent = '\u2713 Approve';
        approveRejectedBtn.title = 'Approve rejected recipe';
        approveRejectedBtn.addEventListener('click', (function(id, st){ return function(e){ quickReviewRecipe(id, 'approved', e, st); }; })(r.id, r.status));
        actions.appendChild(approveRejectedBtn);
      }
      var featBtn = document.createElement('button');
      featBtn.type = 'button';
      featBtn.className = 'rm-feat-btn';
      featBtn.textContent = r.featured ? '\u2b50' : '\u2606';
      featBtn.title = r.featured ? 'Unfeature' : 'Feature';
      featBtn.addEventListener('click', (function(id, featured){ return function(e){ e.stopPropagation(); toggleFeature(id, featured); }; })(r.id, r.featured));
      actions.appendChild(featBtn);
    });
    renderRmPagination();
  } catch(e) {
    tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Error: ' + esc(e.message) + '</td></tr>';
  } finally {
    tbody.style.opacity = '';
  }
}

async function openRecipeModal(id) {
  closeRecipeModal();
  var overlay = document.createElement('div');
  overlay.id = 'rm-review-overlay';
  overlay.className = 'rm-review-overlay';
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-label', 'Recipe review');
  overlay.addEventListener('click', function(e) {
    if (e.target === overlay) closeRecipeModal();
  });
  var panel = document.createElement('div');
  panel.id = 'rm-detail-panel';
  panel.className = 'rm-review-modal';
  panel.addEventListener('click', function(e) { e.stopPropagation(); });
  panel.innerHTML = '<div style="padding:24px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  overlay.appendChild(panel);
  document.body.appendChild(overlay);
  document.body.style.overflow = 'hidden';
  if (window._rmReviewEscHandler) document.removeEventListener('keydown', window._rmReviewEscHandler);
  window._rmReviewEscHandler = function(e) {
    if (e.key === 'Escape') closeRecipeModal();
  };
  document.addEventListener('keydown', window._rmReviewEscHandler);
  try {
    var raw = await rpc('admin_get_recipe_detail', {p_id: id});
    var r   = Array.isArray(raw) ? raw[0] : raw;
    if (!r) throw new Error('Recipe not found');
    currentRecipe = r;
    var sc = r.status === 'approved' ? '#4caf76' : r.status === 'rejected' ? '#dc5050' : '#d4a017';
    var dt = r.submitted_at
      ? new Date(r.submitted_at).toLocaleDateString('en-GB', {day:'numeric',month:'long',year:'numeric'})
      : '\u2014';
    var REJECT_REASONS = getRejectReasons();

    // Build panel with DOM (avoids all quote nesting issues)
    panel.innerHTML = '';
    function mk(tag, style, text) {
      var el = document.createElement(tag);
      if (style) el.style.cssText = style;
      if (text !== undefined) el.textContent = text;
      return el;
    }
    function field(label, value) {
      return '<div style="padding:4px 0;border-bottom:1px solid rgba(255,255,255,0.04);display:flex;justify-content:space-between">' +
        '<span style="font-size:11px;color:var(--text-mid)">' + esc(label) + '</span>' +
        '<span style="font-size:12px;color:var(--text-high);text-align:right;max-width:350px">' + esc(String(value||'')) + '</span></div>';
    }

    // Sticky header
    var hdr = mk('div','display:flex;align-items:center;justify-content:space-between;padding:18px 20px;border-bottom:1px solid var(--border);position:sticky;top:0;background:var(--bg);z-index:1');
    hdr.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1.1rem;font-weight:700;color:var(--text-high)",'Recipe Review'));
    var closeBtn = mk('button','background:none;border:none;color:var(--text-mid);font-size:18px;cursor:pointer;padding:4px 8px','\u2715');
    closeBtn.addEventListener('click', closeRecipeModal);
    hdr.appendChild(closeBtn);
    panel.appendChild(hdr);

    // Title block
    var titleBlock = mk('div','padding:18px 20px;border-bottom:1px solid var(--border)');
    titleBlock.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1.5rem;font-weight:700;color:var(--text-high);margin-bottom:4px", r.recipe_name || ''));
    if (r.native_title) titleBlock.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;color:var(--accent);font-style:italic;margin-bottom:8px", r.native_title));
    // Tags row
    var tags = mk('div','display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px');
    function tag(text, color) { var s=mk('span','font-size:11px;padding:2px 8px;border-radius:8px;background:rgba(255,255,255,0.08);color:'+color,text); tags.appendChild(s); }
    tag(r.status, sc);
    if (r.category) tag(r.category, 'var(--text-mid)');
    if (r.origin_country) tag(r.origin_country, 'var(--text-mid)');
    if (r.spice_level && r.spice_level !== 'Not Applicable') tag('\uD83C\uDF36 '+r.spice_level, 'var(--text-mid)');
    if (r.featured) tag('\u2b50 Featured', 'var(--accent)');
    if (r.recipe_of_week) tag('\uD83C\uDFC6 Recipe of the Week', '#5B8FD4');
    titleBlock.appendChild(tags);
    // Submitter + timing row
    var metaRow = mk('div','display:flex;gap:16px;flex-wrap:wrap');
    metaRow.appendChild(mk('span',"font-size:11px;color:var(--text-mid)", 'Submitted by @' + (r.username||'') + ' on ' + dt));
    if (r.servings) metaRow.appendChild(mk('span',"font-size:11px;color:var(--text-mid)", 'Serves ' + r.servings));
    if (r.prep_time_minutes) metaRow.appendChild(mk('span',"font-size:11px;color:var(--text-mid)", 'Prep: ' + r.prep_time_minutes + 'm'));
    if (r.cook_time_minutes) metaRow.appendChild(mk('span',"font-size:11px;color:var(--text-mid)", 'Cook: ' + r.cook_time_minutes + 'm'));
    titleBlock.appendChild(metaRow);
    // Agent + full editor — every Submit a Recipe field (ingredients, procedure, dropdowns)
    var editFullBar = mk('div','margin-top:14px;padding:12px 14px;border-radius:10px;background:rgba(91,143,212,0.12);border:1px solid rgba(91,143,212,0.35)');
    editFullBar.appendChild(mk('div',"font-size:12px;color:var(--text-high);line-height:1.55;margin-bottom:10px",
      'Agent Review cleans all fields and saves — you approve when the content looks right. Junk is auto-rejected; gaps open the editor.'));
    var agentBtnRow = mk('div','display:flex;flex-wrap:wrap;gap:10px;align-items:center');
    var agentReviewBtn = mk('button','padding:10px 18px;background:#7c5cbf;border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;cursor:pointer',
      '\uD83E\uDD16 Agent Review');
    agentReviewBtn.type = 'button';
    agentReviewBtn.title = 'Rule-based cleanup, then open all fields in a popup if needed';
    agentReviewBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      if (typeof runAgentReviewRecipe === 'function') runAgentReviewRecipe(r.id, r.recipe_name);
    });
    var editFullBtn = mk('button','padding:10px 18px;background:#5B8FD4;border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;cursor:pointer',
      'Edit all fields \u2192');
    editFullBtn.type = 'button';
    editFullBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      if (typeof openAdminFullEditorPopup === 'function') {
        openAdminFullEditorPopup(r.id, { title: 'Edit all fields', subtitle: 'Same form as Submit a Recipe — save, then approve below.' });
      } else {
        window.open('submit-recipe.html?adminReview=' + encodeURIComponent(r.id), '_blank', 'noopener');
      }
    });
    agentBtnRow.appendChild(agentReviewBtn);
    agentBtnRow.appendChild(editFullBtn);
    editFullBar.appendChild(agentBtnRow);
    titleBlock.appendChild(editFullBar);
    panel.appendChild(titleBlock);

    var bodyScroll = mk('div','flex:1;overflow-y:auto;min-height:0');
    panel.appendChild(bodyScroll);
    function bodyAppend(el) { bodyScroll.appendChild(el); }

    // Introduction & notes (batch imports often have empty intro — show either way)
    var introBlock = mk('div','padding:14px 20px;border-bottom:1px solid var(--border)');
    introBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:8px",'Introduction'));
    var introText = (r.introduction || '').trim();
    if (introText && introText !== 'Imported from Personal book collection.') {
      introBlock.appendChild(mk('div',"font-size:13px;color:var(--text-high);line-height:1.65", introText));
    } else {
      introBlock.appendChild(mk('div',"font-size:12px;color:var(--text-mid);font-style:italic",'No introduction yet — run Agent Review or edit below / full form.'));
    }
    if (r.cooking_notes) {
      introBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin:14px 0 8px",'Cooking Notes'));
      introBlock.appendChild(mk('div',"font-size:12px;color:var(--text-mid);line-height:1.65", r.cooking_notes));
    }
    bodyAppend(introBlock);

    bodyAppend(mk('div','padding:8px 20px;border-bottom:1px solid var(--border);background:rgba(91,143,212,0.08);font-size:11px;color:#5B8FD4;line-height:1.5',
      'Quick edits below, or use Edit full recipe above for ingredients & procedure. Approve/Reject stays fixed at the bottom.'));

    // Recipe image — admin can replace before approving
    var imgBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
    imgBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:10px",'Recipe Image'));
    var imgPreview = document.createElement('img');
    imgPreview.id = 'rm-edit-image-preview';
    imgPreview.alt = r.recipe_name || 'Recipe image';
    imgPreview.style.cssText = 'width:100%;max-height:220px;object-fit:cover;border-radius:10px;border:1px solid var(--border);background:var(--bg);margin-bottom:10px';
    if (r.image_url) {
      imgPreview.src = r.image_url;
    } else {
      imgPreview.style.display = 'none';
      imgBlock.appendChild(mk('div',"font-size:12px;color:var(--text-mid);margin-bottom:10px",'No image uploaded'));
    }
    if (r.image_url) imgBlock.appendChild(imgPreview);
    var imgFile = document.createElement('input');
    imgFile.type = 'file';
    imgFile.accept = 'image/jpeg,image/png,image/webp';
    imgFile.id = 'rm-edit-image-file';
    imgFile.style.display = 'none';
    var imgBtnRow = mk('div','display:flex;align-items:center;gap:10px;flex-wrap:wrap');
    var pickImgBtn = mk('button','padding:6px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--accent);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer', r.image_url ? 'Replace Image' : 'Upload Image');
    var saveImgBtn = mk('button','padding:6px 14px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;display:none','Save Image');
    saveImgBtn.id = 'rm-save-image-btn';
    var imgMsg = mk('span','font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)','');
    imgMsg.id = 'rm-image-msg';
    imgFile.addEventListener('change', function() {
      var f = imgFile.files && imgFile.files[0];
      if (!f) return;
      if (f.size > 5 * 1024 * 1024) {
        imgMsg.textContent = 'Image must be under 5 MB';
        imgMsg.style.color = '#dc5050';
        imgFile.value = '';
        return;
      }
      var reader = new FileReader();
      reader.onload = function(ev) {
        if (!imgPreview.parentNode) imgBlock.insertBefore(imgPreview, imgBtnRow);
        imgPreview.src = ev.target.result;
        imgPreview.style.display = 'block';
        imgPreview.dataset.pendingDataUrl = ev.target.result;
        saveImgBtn.style.display = 'inline-block';
        imgMsg.textContent = '';
      };
      reader.readAsDataURL(f);
    });
    pickImgBtn.addEventListener('click', function() { imgFile.click(); });
    saveImgBtn.addEventListener('click', function() { saveRecipeImage(r.id); });
    imgBtnRow.appendChild(pickImgBtn);
    imgBtnRow.appendChild(saveImgBtn);
    imgBtnRow.appendChild(imgMsg);
    imgBlock.appendChild(imgBtnRow);
    imgBlock.appendChild(imgFile);
    bodyAppend(imgBlock);

    // Ingredients
    if (r.ingredients) {
      var ingBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
      ingBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px",'Ingredients'));
      ingBlock.appendChild(mk('div',"font-size:11px;color:var(--text-mid);margin-bottom:8px;font-style:italic",'Preview only — use Edit full recipe above to change sections and rows.'));
      try {
        var ings = typeof r.ingredients === 'string' ? JSON.parse(r.ingredients) : r.ingredients;
        if (Array.isArray(ings)) {
          ings.forEach(function(section) {
            var items = Array.isArray(section) ? section : (section.items || [section]);
            var secName = section.section || section.section_name;
            if (secName) ingBlock.appendChild(mk('div',"font-size:12px;font-weight:600;color:var(--text-high);margin:8px 0 4px", secName));
            items.forEach(function(item) {
              var name = typeof item === 'string' ? item : (item.ingredient || item.name || '');
              var qty  = typeof item === 'object' ? ((item.qty || item.quantity || '') + ' ' + (item.unit || '')).trim() : '';
              var line = mk('div',"font-size:12px;color:var(--text-mid);padding:2px 0");
              line.innerHTML = '\u25a1 ' + (qty ? '<strong style="color:var(--text-high)">' + esc(qty) + '</strong> ' : '') + esc(name);
              ingBlock.appendChild(line);
            });
          });
        }
      } catch(e) { console.warn('recipe modal ingredients render', e); ingBlock.appendChild(mk('div',"font-size:12px;color:var(--text-mid)",'Ingredients present')); }
      bodyAppend(ingBlock);
    }

    // Method — section blocks with steps (not raw JSON per section)
    if (r.method) {
      var methBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
      methBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px",'Procedure'));
      methBlock.appendChild(mk('div',"font-size:11px;color:var(--text-mid);margin-bottom:8px;font-style:italic",'Preview only — use Edit full recipe above to edit steps.'));
      var methScroll = mk('div','max-height:240px;overflow-y:auto');
      try {
        var blocks = (typeof RecipeProcedure !== 'undefined') ? RecipeProcedure.parseBlocks(r.method) : [];
        var stepNum = 0;
        if (blocks.length) {
          blocks.forEach(function (block) {
            if (block.section) {
              methScroll.appendChild(mk('div',"font-size:12px;font-weight:600;color:var(--text-high);margin:10px 0 6px", block.section));
            }
            var lines = (typeof RecipeProcedure !== 'undefined') ? RecipeProcedure.stepLines(block.steps) : [];
            lines.forEach(function (text) {
              stepNum++;
              var line = mk('div',"font-size:12px;color:var(--text-mid);margin-bottom:6px;line-height:1.6");
              line.innerHTML = '<span style="color:var(--accent);font-weight:600">' + stepNum + '.</span> ' + esc(text);
              methScroll.appendChild(line);
            });
          });
        }
        if (!stepNum) methScroll.appendChild(mk('div',"font-size:12px;color:var(--text-mid)",'No procedure steps listed'));
      } catch(e) { console.warn('recipe modal method render', e); methScroll.appendChild(mk('div',"font-size:12px;color:var(--text-mid)",'Method present')); }
      methBlock.appendChild(methScroll);
      bodyAppend(methBlock);
    }

    // Source
    if (r.source_type || r.credit_name) {
      var srcBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
      srcBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:8px",'Source & Credits'));
      srcBlock.innerHTML += field('Type', r.source_type);
      if (r.credit_name)   srcBlock.innerHTML += field('Credit', r.credit_name);
      if (r.credit_handle) srcBlock.innerHTML += field('Handle', '@'+r.credit_handle);
      bodyAppend(srcBlock);
    }

    // Import audit trail (Wave 3)
    if (r.import_confidence_score != null || r.parser_version || (r.import_warnings && r.import_warnings.length) || r.import_paste_snapshot) {
      var iaBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(91,143,212,0.06);border-left:3px solid #5B8FD4');
      iaBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#5B8FD4;margin-bottom:10px",'Import audit'));
      if (r.import_source_url) {
        var srcLine = mk('div', 'font-size:12px;color:var(--text-mid);margin-top:6px;line-height:1.6');
        srcLine.innerHTML = 'Source: <a href="' + String(r.import_source_url).replace(/"/g, '&quot;') + '" target="_blank" rel="noopener" style="color:#5B8FD4">' + String(r.import_source_url) + '</a>';
        iaBlock.appendChild(srcLine);
      }
      if (r.parser_version) iaBlock.innerHTML += field('Parser', r.parser_version);
      if (r.extractor_version) iaBlock.innerHTML += field('Extractor version', r.extractor_version);
      if (r.import_extractor) iaBlock.innerHTML += field('Extractor', r.import_extractor);
      if (r.import_path) iaBlock.innerHTML += field('Import path', r.import_path);
      if (r.import_confidence_score != null) iaBlock.innerHTML += field('Confidence', String(r.import_confidence_score) + '/100');
      if (r.imported_at) iaBlock.innerHTML += field('Imported', new Date(r.imported_at).toLocaleString());
      if (r.procedure_rewritten) iaBlock.innerHTML += field('Procedure', 'Rewritten after import');
      if (r.import_merge_mode) iaBlock.innerHTML += field('Merge mode', 'Schema + blog text');
      var warns = [];
      try {
        warns = Array.isArray(r.import_warnings) ? r.import_warnings : (r.import_warnings ? JSON.parse(r.import_warnings) : []);
      } catch(e) { console.warn('import warnings parse', e); }
      if (warns.length) {
        var wEl = mk('div',"font-size:12px;color:var(--text-mid);margin-top:8px;line-height:1.6");
        wEl.textContent = 'Warnings: ' + warns.join(' · ');
        iaBlock.appendChild(wEl);
      }
      if (r.import_raw_article_text) {
        var raw = mk('details','margin-top:10px');
        raw.innerHTML = '<summary style="cursor:pointer;font-size:12px;color:var(--text-high)">Raw article text (truncated)</summary>';
        var rawPre = mk('pre','margin-top:8px;padding:10px;background:var(--bg);border-radius:8px;font-size:11px;white-space:pre-wrap;max-height:180px;overflow:auto;color:var(--text-mid)');
        rawPre.textContent = String(r.import_raw_article_text).slice(0, 4000);
        raw.appendChild(rawPre);
        iaBlock.appendChild(raw);
      }
      if (r.import_paste_snapshot) {
        var snap = mk('details','margin-top:10px');
        snap.innerHTML = '<summary style="cursor:pointer;font-size:12px;color:var(--text-high)">Paste snapshot (post-extract)</summary>';
        var pre = mk('pre','margin-top:8px;padding:10px;background:var(--bg);border-radius:8px;font-size:11px;white-space:pre-wrap;max-height:180px;overflow:auto;color:var(--text-mid)');
        pre.textContent = String(r.import_paste_snapshot).slice(0, 4000);
        snap.appendChild(pre);
        iaBlock.appendChild(snap);
      }
      bodyAppend(iaBlock);
    }

    // Unknown ingredients — ingredients submitted that aren't in the database yet
    var unknowns = [];
    try {
      unknowns = Array.isArray(r.unknown_ingredients) ? r.unknown_ingredients
                 : (r.unknown_ingredients ? JSON.parse(r.unknown_ingredients) : []);
    } catch(e) { console.warn('unknown ingredients parse', e); }
    if (unknowns.length) {
      var uBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(212,160,23,0.05);border-left:3px solid #d4a017');
      uBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#d4a017;margin-bottom:10px",'âš  New Ingredients Not Yet in Database'));
      uBlock.appendChild(mk('p',"font-size:12px;color:var(--text-mid);margin:0 0 12px;line-height:1.6",'These ingredient names were flagged when the recipe was submitted. Review and add any that are legitimate.'));
      unknowns.forEach(function(name) {
        var row = mk('div','display:flex;align-items:center;justify-content:space-between;padding:7px 0;border-bottom:1px solid rgba(255,255,255,0.04)');
        row.appendChild(mk('span',"font-size:13px;color:var(--text-high)", name));
        var addBtn = mk('button',"padding:4px 14px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;cursor:pointer",'+ Add to Ingredients');
        addBtn.addEventListener('click', (function(n) { return function() {
          // Pre-fill the ingredient modal with the name and open it
          closeRecipeModal();
          switchView('ingredients');
          setTimeout(function() { openIngModal({ 'Ingredient Name': n }); }, 300);
        }; })(name));
        row.appendChild(addBtn);
        uBlock.appendChild(row);
      });
      bodyAppend(uBlock);
    }

    // Unknown utensils — tools not yet in the Tools & Appliances library
    var unknownTools = [];
    try {
      unknownTools = Array.isArray(r.unknown_utensils) ? r.unknown_utensils
        : (r.unknown_utensils ? JSON.parse(r.unknown_utensils) : []);
    } catch(e) { console.warn('unknown utensils parse', e); }
    if (unknownTools.length) {
      var tBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(212,160,23,0.05);border-left:3px solid #d4a017');
      tBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#d4a017;margin-bottom:10px",'âš  New Tools Not Yet in Library'));
      tBlock.appendChild(mk('p',"font-size:12px;color:var(--text-mid);margin:0 0 12px;line-height:1.6",'These utensil names were flagged because they are not published in Tools & Appliances yet. Review and publish a profile, or ask the contributor to submit one.'));
      unknownTools.forEach(function(name) {
        var row = mk('div','display:flex;align-items:center;justify-content:space-between;gap:10px;padding:7px 0;border-bottom:1px solid rgba(255,255,255,0.04);flex-wrap:wrap');
        row.appendChild(mk('span',"font-size:13px;color:var(--text-high)", name));
        var actions = mk('div','display:flex;gap:6px;flex-wrap:wrap');
        var subBtn = mk('a',"padding:4px 14px;background:var(--accent);border:none;border-radius:6px;color:#1a1a1a;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;cursor:pointer;text-decoration:none",'Submit tool profile');
        subBtn.href = 'library-submit.html?type=tool&name=' + encodeURIComponent(name);
        subBtn.target = '_blank';
        actions.appendChild(subBtn);
        var libBtn = mk('button',"padding:4px 14px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:'DM Sans',sans-serif;font-size:11px;cursor:pointer",'Open Tools admin');
        libBtn.addEventListener('click', function() {
          closeRecipeModal();
          switchView('library-mgmt');
          setTimeout(function() {
            try { switchLibTab('lm-tools'); } catch(e) { console.warn('switchLibTab lm-tools', e); }
          }, 300);
        });
        actions.appendChild(libBtn);
        row.appendChild(actions);
        tBlock.appendChild(row);
      });
      bodyAppend(tBlock);
    }

    // Suggested taxonomy — sub-categories / divisions not yet in the database
    var taxSug = [];
    try {
      taxSug = Array.isArray(r.taxonomy_suggestions) ? r.taxonomy_suggestions
        : (r.taxonomy_suggestions ? JSON.parse(r.taxonomy_suggestions) : []);
    } catch(e) { console.warn('taxonomy suggestions parse', e); }
    if (taxSug.length) {
      var tBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(212,160,23,0.05);border-left:3px solid #d4a017');
      tBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#d4a017;margin-bottom:10px",'âš  Suggested Taxonomy Not Yet in Database'));
      tBlock.appendChild(mk('p',"font-size:12px;color:var(--text-mid);margin:0 0 12px;line-height:1.6",'The contributor typed sub-categories or divisions that are not in the master list. Review and add any that should be available site-wide.'));
      taxSug.forEach(function(sug) {
        var label = sug.field === 'sub_category'
          ? 'Sub-category: ' + (sug.value || '') + ' · ' + (sug.category || '')
          : 'Division: ' + (sug.value || '') + ' · ' + (sug.sub_category || '—') + ' · ' + (sug.category || '');
        var row = mk('div','display:flex;align-items:center;justify-content:space-between;gap:10px;padding:7px 0;border-bottom:1px solid rgba(255,255,255,0.04)');
        row.appendChild(mk('span',"font-size:13px;color:var(--text-high);flex:1", label));
        var addBtn = mk('button',"padding:4px 14px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;cursor:pointer;flex-shrink:0",'+ Add to Taxonomy');
        addBtn.addEventListener('click', (function(s) { return function() {
          var btn = this;
          btn.disabled = true;
          btn.textContent = 'Adding…';
          var p;
          if (s.field === 'sub_category') {
            p = rmTaxUpsertSubcategory(
              { p_id: null, p_category: s.category, p_name: s.value, p_sort_order: 99 },
              {
                action: 'Sub-category Created',
                target: s.category + ' > ' + s.value,
                oldVal: null,
                newVal: s.category + ' > ' + s.value,
                details: 'Added from missing-taxonomy backfill'
              }
            );
          } else if (s.field === 'division') {
            if (!s.sub_category) {
              alert('Add the sub-category first (or use Sub-cats & Divisions tab), then add this division.');
              btn.disabled = false;
              btn.textContent = '+ Add to Taxonomy';
              return;
            }
            p = rmTaxUpsertDivision({
              p_id: null, p_category: s.category, p_subcategory: s.sub_category, p_name: s.value,
              p_emoji: '🍽', p_subtitle: '', p_description: null, p_tags: [], p_sort_order: 99
            }, {
              action: 'Division Created',
              target: s.category + ' > ' + s.sub_category + ' > ' + s.value,
              oldVal: null,
              newVal: s.category + ' > ' + s.sub_category + ' > ' + s.value,
              details: 'Added from missing-taxonomy backfill'
            });
          } else {
            btn.disabled = false;
            btn.textContent = '+ Add to Taxonomy';
            return;
          }
          p.then(function() {
            btn.textContent = 'âœ“ Added';
            btn.style.background = '#2d8a4e';
          }).catch(function(e) {
            alert(e.message || 'Could not add taxonomy entry');
            btn.disabled = false;
            btn.textContent = '+ Add to Taxonomy';
          });
        }; })(sug));
        row.appendChild(addBtn);
        tBlock.appendChild(row);
      });
      var manageBtn = mk('button',"margin-top:10px;padding:6px 14px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--accent);font-family:'DM Sans',sans-serif;font-size:11px;cursor:pointer",'Manage all taxonomy →');
      manageBtn.addEventListener('click', function() {
        closeRecipeModal();
        switchRecipeTab('taxonomy');
      });
      tBlock.appendChild(manageBtn);
      bodyAppend(tBlock);
    }

    // Edit before approving
    var editBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
    editBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:12px",'Edit Before Approving'));
    var editGrid = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px');
    function editField(label, inputId, value, type) {
      var wrap = mk('div','');
      wrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",label));
      var inp = document.createElement(type === 'select' ? 'select' : 'input');
      inp.id = inputId;
      inp.style.cssText = 'width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
      if (type !== 'select') inp.value = value || '';
      wrap.appendChild(inp);
      return wrap;
    }
    var nameWrap  = editField('Recipe Name', 'rm-edit-name', r.recipe_name, 'text');
    var nativeWrap = editField('Also Known As', 'rm-edit-native', r.native_title, 'text');
    nativeWrap.querySelector('input').placeholder = 'e.g. Paal Payasam';
    // Category select
    var catWrap = mk('div','');
    catWrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",'Category'));
    var catSel = document.createElement('select');
    catSel.id = 'rm-edit-cat';
    catSel.style.cssText = 'width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
    var blankOpt = document.createElement('option'); blankOpt.value = ''; blankOpt.textContent = '— Select —'; catSel.appendChild(blankOpt);
    var rmCatRows = (typeof tcjFetchCategories === 'function') ? await tcjFetchCategories() : [];
    rmCatRows.forEach(function(c) {
      var o = document.createElement('option');
      o.value = c.name;
      o.textContent = c.name;
      catSel.appendChild(o);
    });
    catWrap.appendChild(catSel);
    if (r.category) {
      catSel.value = String(r.category).trim();
      if (!catSel.value) {
        var extra = document.createElement('option');
        extra.value = r.category;
        extra.textContent = r.category;
        extra.selected = true;
        catSel.appendChild(extra);
      }
    }
    // Spice select
    var spiceWrap = mk('div','');
    spiceWrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",'Spice Level'));
    var spiceSel = document.createElement('select');
    spiceSel.id = 'rm-edit-spice';
    spiceSel.style.cssText = catSel.style.cssText;
    ['Not Applicable','Mild','Medium','Hot','Very Hot','Extremely Hot'].forEach(function(s) { var o = document.createElement('option'); o.value = s; o.textContent = s; o.selected = (r.spice_level === s); spiceSel.appendChild(o); });
    spiceWrap.appendChild(spiceSel);
    var sweetWrap = mk('div','');
    sweetWrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",'Sweet Level'));
    var sweetSel = document.createElement('select');
    sweetSel.id = 'rm-edit-sweet';
    sweetSel.style.cssText = catSel.style.cssText;
    ['Not Applicable','Subtly Sweet','Lightly Sweet','Sweet','Very Sweet','Extremely Sweet'].forEach(function(s) {
      var o = document.createElement('option'); o.value = s; o.textContent = s; o.selected = (r.sweet_level === s); sweetSel.appendChild(o);
    });
    sweetWrap.appendChild(sweetSel);
    var servWrap = editField('Servings', 'rm-edit-servings', r.servings, 'text');
    var prepWrap = editField('Prep (minutes)', 'rm-edit-prep', r.prep_time_minutes, 'text');
    var cookWrap = editField('Cook (minutes)', 'rm-edit-cook', r.cook_time_minutes, 'text');
    var locWrap = editField('Origin locality (village/area)', 'rm-edit-locality', r.origin_locality, 'text');
    var stateWrap = editField('Origin state/region', 'rm-edit-state', r.origin_state, 'text');
    var countryWrap = editField('Origin country', 'rm-edit-country', r.origin_country, 'text');
    editGrid.appendChild(nameWrap); editGrid.appendChild(nativeWrap);
    editGrid.appendChild(catWrap);  editGrid.appendChild(spiceWrap);
    editGrid.appendChild(sweetWrap); editGrid.appendChild(servWrap);
    editGrid.appendChild(prepWrap); editGrid.appendChild(cookWrap);
    editGrid.appendChild(locWrap); editGrid.appendChild(stateWrap);
    editGrid.appendChild(countryWrap);
    editBlock.appendChild(editGrid);
    var introWrap = mk('div','margin-top:10px');
    introWrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",'Introduction'));
    var introTa = document.createElement('textarea');
    introTa.id = 'rm-edit-intro';
    introTa.rows = 3;
    introTa.value = r.introduction || '';
    introTa.style.cssText = 'width:100%;box-sizing:border-box;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);resize:vertical';
    introWrap.appendChild(introTa);
    editBlock.appendChild(introWrap);
    var notesWrap = mk('div','margin-top:10px');
    notesWrap.appendChild(mk('label',"display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px",'Cooking Notes'));
    var notesTa = document.createElement('textarea');
    notesTa.id = 'rm-edit-cooking-notes';
    notesTa.rows = 2;
    notesTa.value = r.cooking_notes || '';
    notesTa.style.cssText = introTa.style.cssText;
    notesWrap.appendChild(notesTa);
    editBlock.appendChild(notesWrap);
    var saveEditBtn = mk('button','margin-top:10px;padding:6px 16px;background:none;border:1px solid var(--accent);border-radius:7px;color:var(--accent);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer','Save Edits');
    saveEditBtn.addEventListener('click', function(){ saveRecipeEdits(r.id); });
    var editMsg = mk('span','margin-left:10px;font-family:DM Sans,sans-serif;font-size:11px;color:#4caf76','');
    editMsg.id = 'rm-edit-msg';
    editBlock.appendChild(saveEditBtn); editBlock.appendChild(editMsg);
    bodyAppend(editBlock);

    // Sticky review footer — always visible
    var reviewBlock = mk('div','padding:16px 20px;border-top:1px solid var(--border);background:var(--bg);flex-shrink:0;box-shadow:0 -8px 24px rgba(0,0,0,0.25)');
    reviewBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:12px",'Review'));
    // Rejection reason dropdown
    var rejectSel = document.createElement('select');
    rejectSel.id = 'rm-reject-reason';
    rejectSel.style.cssText = 'width:100%;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);margin-bottom:8px';
    var noReason = document.createElement('option'); noReason.value = ''; noReason.textContent = '— Rejection reason (optional) —'; rejectSel.appendChild(noReason);
    ['Incomplete ingredients','Unclear method','Duplicate recipe','Inappropriate content','Missing source credit','Poor formatting','Other'].forEach(function(reason) {
      var o = document.createElement('option'); o.value = reason; o.textContent = reason; rejectSel.appendChild(o);
    });
    reviewBlock.appendChild(rejectSel);
    // Notes textarea
    var notesArea = document.createElement('textarea');
    notesArea.id = 'rm-notes-input';
    notesArea.rows = 3;
    notesArea.placeholder = 'Additional notes for the submitter\u2026';
    notesArea.style.cssText = 'width:100%;box-sizing:border-box;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);resize:vertical;margin-bottom:12px';
    notesArea.value = r.reviewer_notes || '';
    reviewBlock.appendChild(notesArea);
    // Action buttons row
    var btnRow = mk('div','display:flex;gap:8px;flex-wrap:wrap;align-items:center');
    function actionBtn(label, color, bg, handler) {
      var b = mk('button','padding:9px 20px;background:'+bg+';border:1px solid '+color+';border-radius:8px;color:'+(bg==='none'?color:'#fff')+';font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;cursor:pointer', label);
      b.addEventListener('click', handler);
      return b;
    }
    btnRow.appendChild(actionBtn('\u2713 Approve', '#2e7d4f', '#2e7d4f', function(){ doReviewRecipe(r.id, 'approved'); }));
    btnRow.appendChild(actionBtn('\u2715 Reject',  '#8e2d2d', '#8e2d2d', function(){ doReviewRecipe(r.id, 'rejected'); }));
    btnRow.appendChild(actionBtn('\u21ba Reset',   'var(--border)', 'none', function(){ doReviewRecipe(r.id, 'pending'); }));
    btnRow.appendChild(actionBtn('\uD83C\uDFC6 Recipe of Week', '#5B8FD4', 'none', function(){ doSetRecipeOfWeek(r.id); }));
    btnRow.appendChild(actionBtn((r.featured ? '\u2b50 Unfeature' : '\u2606 Feature'), 'var(--accent)', 'none', function(){ toggleFeature(r.id, r.featured); closeRecipeModal(); }));
    var reviewMsg = mk('span','font-family:DM Sans,sans-serif;font-size:12px;color:#4caf76','');
    reviewMsg.id = 'rm-review-msg';
    btnRow.appendChild(reviewMsg);
    reviewBlock.appendChild(btnRow);
    panel.appendChild(reviewBlock);

  } catch(e) {
    panel.innerHTML = '<div style="padding:24px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

async function reviewRecipe(newStatus) { doReviewRecipe(currentRecipe && currentRecipe.id, newStatus); }

async function quickReviewRecipe(id, status, e, prevStatus) {
  if (e) { e.stopPropagation(); e.preventDefault(); }
  if (!id) return;
  var btn = e && e.currentTarget;
  if (btn) { btn.disabled = true; btn.style.opacity = '0.45'; }
  try {
    await rpc('admin_review_recipe', {
      p_id: id,
      p_status: status,
      p_notes: status === 'rejected' ? 'Quick reject from list' : ''
    });
    auditLog('Recipe Management', 'Recipe ' + status.charAt(0).toUpperCase() + status.slice(1), null, id, status, status === 'rejected' ? 'Quick reject from list' : null);
    afterRecipeReviewInList(id, prevStatus || status, status);
  } catch (err) {
    if (btn) { btn.disabled = false; btn.style.opacity = ''; }
    alert('Error: ' + err.message);
  }
}

async function toggleFeature(id, currentFeatured) {
  try {
    await rpc('admin_feature_recipe', {p_id: id, p_featured: !currentFeatured});
    auditLog('Recipe Management', currentFeatured ? 'Recipe Unfeatured' : 'Recipe Featured', null, id, String(!currentFeatured), null);
    loadRecipeMgmt(_currentRecipeTab);
  } catch(e) { alert('Error: ' + e.message); }
}

function closeRecipeModal() {
  if (window._rmReviewEscHandler) {
    document.removeEventListener('keydown', window._rmReviewEscHandler);
    window._rmReviewEscHandler = null;
  }
  var overlay = document.getElementById('rm-review-overlay');
  if (overlay) overlay.remove();
  document.body.style.overflow = '';
  currentRecipe = null;
}

async function doReviewRecipe(id, status) {
  var reasonEl = document.getElementById('rm-reject-reason');
  var notesEl  = document.getElementById('rm-notes-input');
  var msg      = document.getElementById('rm-review-msg');
  var reason   = reasonEl ? reasonEl.value : '';
  var notes    = notesEl  ? notesEl.value.trim() : '';
  var combined = reason ? (reason + (notes ? ': ' + notes : '')) : notes;
  document.querySelectorAll('#rm-detail-panel button').forEach(function(b){ b.disabled = true; });
  if (msg) { msg.textContent = 'Saving\u2026'; msg.style.color = 'var(--text-mid)'; }
  try {
    var prevStatus = currentRecipe ? currentRecipe.status : null;
    await rpc('admin_review_recipe', {p_id: id, p_status: status, p_notes: combined || null});
    auditLog('Recipe Management', 'Recipe ' + status.charAt(0).toUpperCase() + status.slice(1), null, id, status, combined || null);
    closeRecipeModal();
    afterRecipeReviewInList(id, prevStatus, status);
  } catch(e) {
    document.querySelectorAll('#rm-detail-panel button').forEach(function(b){ b.disabled = false; });
    if (msg) { msg.textContent = 'Error: ' + e.message; msg.style.color = '#dc5050'; }
  }
}

async function uploadAdminRecipeImage(dataUrl, recipeId) {
  if (!dataUrl || !dataUrl.startsWith('data:')) return dataUrl || '';
  if (!session || !session.access_token) throw new Error('Session expired');
  var userId = (session.user && session.user.id) || session.id;
  if (!userId) throw new Error('Not signed in');
  var blob = await fetch(dataUrl).then(function(res) { return res.blob(); });
  var ext = 'jpg';
  if (blob.type && blob.type.indexOf('png') >= 0) ext = 'png';
  else if (blob.type && blob.type.indexOf('webp') >= 0) ext = 'webp';
  var path = userId + '/admin-' + recipeId + '-' + Date.now() + '.' + ext;
  var res = await fetch(SUPABASE_URL + '/storage/v1/object/recipe-images/' + path, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': 'Bearer ' + session.access_token,
      'Content-Type': blob.type || 'image/jpeg',
      'x-upsert': 'true'
    },
    body: blob
  });
  if (!res.ok) throw new Error('Upload failed (' + res.status + ')');
  return SUPABASE_URL + '/storage/v1/object/public/recipe-images/' + path;
}

async function saveRecipeImage(id) {
  var preview = document.getElementById('rm-edit-image-preview');
  var fileIn = document.getElementById('rm-edit-image-file');
  var msg = document.getElementById('rm-image-msg');
  var saveBtn = document.getElementById('rm-save-image-btn');
  var dataUrl = preview && preview.dataset.pendingDataUrl;
  if (!dataUrl) {
    if (msg) { msg.textContent = 'Choose an image first'; msg.style.color = '#dc5050'; }
    return;
  }
  if (saveBtn) { saveBtn.disabled = true; saveBtn.textContent = 'Uploading\u2026'; }
  if (msg) msg.textContent = '';
  try {
    var url = await uploadAdminRecipeImage(dataUrl, id);
    await rpc('admin_edit_recipe', {
      p_id: id,
      p_image_url: url
    });
    if (preview) {
      preview.src = url;
      delete preview.dataset.pendingDataUrl;
    }
    if (fileIn) fileIn.value = '';
    if (saveBtn) { saveBtn.style.display = 'none'; saveBtn.disabled = false; saveBtn.textContent = 'Save Image'; }
    if (msg) { msg.textContent = '\u2713 Image updated'; msg.style.color = '#4caf76'; }
    auditLog('Recipe Management', 'Recipe Image Updated', null, id, url, null);
    if (currentRecipe) currentRecipe.image_url = url;
  } catch(e) {
    if (msg) { msg.textContent = 'Error: ' + e.message; msg.style.color = '#dc5050'; }
    if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = 'Save Image'; }
  }
}

async function saveRecipeEdits(id) {
  var name   = (document.getElementById('rm-edit-name')   || {}).value || '';
  var native = (document.getElementById('rm-edit-native') || {}).value || '';
  var cat    = (document.getElementById('rm-edit-cat')    || {}).value || '';
  var spice   = (document.getElementById('rm-edit-spice')  || {}).value || '';
  var sweet   = (document.getElementById('rm-edit-sweet')  || {}).value || '';
  var intro   = (document.getElementById('rm-edit-intro') || {}).value || '';
  var cookN   = (document.getElementById('rm-edit-cooking-notes') || {}).value || '';
  var servRaw = (document.getElementById('rm-edit-servings') || {}).value || '';
  var prepRaw = (document.getElementById('rm-edit-prep') || {}).value || '';
  var cookRaw = (document.getElementById('rm-edit-cook') || {}).value || '';
  var locality = (document.getElementById('rm-edit-locality') || {}).value || '';
  var state   = (document.getElementById('rm-edit-state')   || {}).value || '';
  var country = (document.getElementById('rm-edit-country') || {}).value || '';
  var serv = servRaw ? parseInt(String(servRaw).replace(/\D/g, ''), 10) : null;
  var prep = prepRaw ? parseInt(String(prepRaw).replace(/\D/g, ''), 10) : null;
  var cook = cookRaw ? parseInt(String(cookRaw).replace(/\D/g, ''), 10) : null;
  var msg    = document.getElementById('rm-edit-msg');
  try {
    await rpc('admin_edit_recipe', {
      p_id: id, p_recipe_name: name || null, p_category: cat || null,
      p_spice_level: spice || null, p_sweet_level: sweet || null,
      p_native_title: native || null,
      p_introduction: intro, p_cooking_notes: cookN,
      p_servings: isNaN(serv) ? null : serv,
      p_prep_time_minutes: isNaN(prep) ? null : prep,
      p_cook_time_minutes: isNaN(cook) ? null : cook,
      p_origin_locality: locality || null, p_origin_state: state || null,
      p_origin_country: country || null
    });
    auditLog('Recipe Management', 'Recipe Edited', name, id, name, 'Before approval');
    if (msg) { msg.textContent = '\u2713 Saved'; msg.style.color = '#4caf76'; setTimeout(function(){ if (msg) msg.textContent = ''; }, 3000); }
  } catch(e) {
    if (msg) { msg.textContent = 'Error: ' + e.message; msg.style.color = '#dc5050'; }
  }
}

async function doSetRecipeOfWeek(id) {
  if (!confirm('Set this as Recipe of the Week? It expires automatically after 7 days.')) return;
  try {
    await rpc('admin_set_recipe_of_week', {p_id: id});
    auditLog('Recipe Management', 'Recipe of the Week Set', null, id, 'recipe_of_week', null);
    var msg = document.getElementById('rm-review-msg');
    if (msg) { msg.textContent = '\uD83C\uDFC6 Recipe of the Week set!'; msg.style.color = '#5B8FD4'; }
    setTimeout(function(){ closeRecipeModal(); loadRecipeMgmt(_currentRecipeTab); }, 1200);
  } catch(e) { alert('Error: ' + e.message); }
}

function loadRMInterfaceSettings() {
  var el = document.getElementById('rm-interface-content');
  if (!el || typeof AdminTabNav === 'undefined') {
    if (el) el.textContent = 'Admin tab navigation failed to load.';
    return;
  }

  AdminTabNav.buildInterfaceShell(el, {
    storageKey: 'tcj_rm_interface_tab',
    defaultKey: 'hub',
    banner: 'Recipe configuration — queues and spotlight stay in the tabs above.',
    sections: [
      AdminTabNav.hubSection({
        subtitle: 'Jump to work or open an operations screen',
        loadHub: function (panel, ctx) {
          return rpc('admin_get_stats', {}).then(function (stats) {
            stats = stats || {};
            return {
              intro: 'Taxonomy, collections, nutrition, print queue, and audit — pick a section in the sidebar or use a shortcut below.',
              stats: [
                { num: stats.pending || 0, label: 'Pending' },
                { num: stats.approved || 0, label: 'Approved' },
                { num: stats.rejected || 0, label: 'Rejected' },
                { num: stats.total || 0, label: 'Total' }
              ],
              actions: [
                { label: 'Review pending', desc: 'Open pending queue', onClick: function () { switchRecipeTab('pending'); } },
                { label: 'Recipe of the Week', desc: 'Set or change ROTW', onClick: function () { switchRecipeTab('rotw'); } },
                { label: 'Taxonomy', desc: 'Sub-categories & divisions', onClick: function () { ctx.activate('taxonomy'); } },
                { label: 'Print queue', desc: 'Print & Post requests', onClick: function () { ctx.activate('printqueue'); } },
                { label: 'Collections', desc: 'Curated recipe sets', onClick: function () { ctx.activate('collections'); } },
                { label: 'Audit trail', desc: 'Admin action log', onClick: function () { ctx.activate('audit'); } }
              ]
            };
          }).catch(function () {
            return {
              actions: [
                { label: 'Review pending', desc: 'Open pending queue', onClick: function () { switchRecipeTab('pending'); } },
                { label: 'Taxonomy', desc: 'Sub-categories & divisions', onClick: function () { ctx.activate('taxonomy'); } }
              ]
            };
          });
        }
      }),
      {
        key: 'settings',
        label: 'Rejection reasons',
        group: 'Policy',
        subtitle: 'Shown when rejecting a recipe submission',
        render: function (panel) {
          panel.innerHTML = '';
          function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
          var ta = mk('textarea', 'width:100%;box-sizing:border-box;min-height:160px;padding:10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);resize:vertical');
          ta.value = getRejectReasons().join('\n');
          panel.appendChild(mk('p', 'font-size:11px;color:var(--text-mid);margin:0 0 10px', 'One reason per line.'));
          panel.appendChild(ta);
          var btn = mk('button', "margin-top:10px;padding:8px 18px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:'DM Sans',sans-serif;font-size:12px;cursor:pointer", 'Save reasons');
          btn.addEventListener('click', function () {
            var lines = ta.value.split('\n').map(function (s) { return s.trim(); }).filter(Boolean);
            if (!lines.length) { alert('Add at least one reason.'); return; }
            localStorage.setItem('tcj_rm_reject_reasons', JSON.stringify(lines));
            btn.textContent = '\u2713 Saved';
            setTimeout(function () { btn.textContent = 'Save reasons'; }, 2000);
            auditLog('RM Interface', 'Rejection Reasons Updated', null, null, null, lines.length + ' reasons');
          });
          panel.appendChild(btn);
        }
      },
      { key: 'taxonomy', label: 'Taxonomy', group: 'Operations', subtitle: 'Sub-categories and divisions', refreshOnShow: true, render: function (p) { loadRMTab('taxonomy', p); } },
      { key: 'sourcelinks', label: 'Source links', group: 'Operations', subtitle: 'Recipe attribution URLs', render: function (p) { loadRMTab('sourcelinks', p); } },
      { key: 'websitesources', label: 'Website sources', group: 'Operations', subtitle: 'Import on/off + chef credits', render: function (p) { loadRMTab('websitesources', p); } },
      { key: 'nutrition', label: 'Nutrition queue', group: 'Operations', subtitle: 'Pending nutrition entries', render: function (p) { loadRMTab('nutrition', p); } },
      { key: 'printqueue', label: 'Print queue', group: 'Operations', subtitle: 'Print & Post workflow', render: function (p) { loadRMTab('printqueue', p); } },
      { key: 'collections', label: 'Collections', group: 'Operations', subtitle: 'Curated recipe groups', render: function (p) { loadRMTab('collections', p); } },
      { key: 'audit', label: 'Audit trail', group: 'System', subtitle: 'Recipe admin actions', render: function (p) { loadRMTab('audit', p); } }
    ]
  });
}

function loadRMTab(key, container) {
  if (!container) return;
  if (key === 'analytics')   loadRMAnalytics(container);
  else if (key === 'taxonomy')    loadRMTaxonomy(container);
  else if (key === 'collections') loadRMCollections(container);
  else if (key === 'featured')    loadRMFeatured(container);
  else if (key === 'sourcelinks') loadRMSourceLinks(container);
  else if (key === 'websitesources') loadRMWebsiteSources(container);
  else if (key === 'nutrition')   loadRMNutritionQueue(container);
  else if (key === 'printqueue')  loadRMPrintQueue(container);
  else if (key === 'audit')       loadRMAudit(container);
}

async function renderOwnerAnalyticsExtras(host, data) {
  if (!host || !data) return;
  function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
  var m = data.members || {};
  var e = data.engagement || {};
  var lib = data.library || {};
  var pipe = data.pipeline || {};
  var row = mk('div', 'display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px');
  [{ n: m.households || 0, l: 'Households' }, { n: e.total_saves || 0, l: 'Recipe saves' }, { n: lib.ingredient || 0, l: 'Library ingredients' }, { n: pipe.pending_library_submissions || 0, l: 'Library inbox' }].forEach(function(c) {
    var card = mk('div', 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:14px');
    card.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1.5rem;font-weight:700;color:var(--accent)", String(c.n)));
    card.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:10px;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em", c.l));
    row.appendChild(card);
  });
  host.appendChild(row);
  var top = e.top_saved || [];
  if (top.length) {
    var tc = mk('div', 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px;margin-bottom:16px');
    tc.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:10px", 'Most saved recipes'));
    top.forEach(function(r) {
      tc.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);padding:3px 0", (r.recipe_name || 'Recipe') + ' — ' + (r.save_count || 0) + ' saves'));
    });
    host.appendChild(tc);
  }
}

async function loadRMAnalytics(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var ownerRaw = await rpc('admin_get_owner_analytics', {}).catch(function() { return null; });
    var owner = ownerRaw && typeof ownerRaw === 'object' ? ownerRaw : null;
    var stats   = (owner && owner.recipes) ? owner.recipes : (await rpc('admin_get_stats', {}) || {});
    var allRecs = [];
    if (typeof TcjAdminRecipes !== 'undefined') {
      allRecs = await TcjAdminRecipes.fetchAll({ p_status: null, p_search: null, p_category: null });
    } else {
      allRecs = await rpc('admin_get_recipes', {p_status:null,p_search:null,p_category:null,p_limit:500,p_offset:0}) || [];
    }
    if (!Array.isArray(allRecs)) allRecs = [];
    var total = parseInt(stats.total) || 0;
    var pend  = parseInt(stats.pending)  || 0;
    var appr  = parseInt(stats.approved) || 0;
    var rej   = parseInt(stats.rejected) || 0;
    var feat  = parseInt(stats.featured) || 0;
    var rate  = total > 0 ? Math.round(appr / total * 100) : 0;
    container.innerHTML = '';
    function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
    var cards = mk('div','display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px');
    [{num:total,label:'Total'},{num:appr,label:'Approved'},{num:pend,label:'Pending'},{num:rate+'%',label:'Approval Rate'}].forEach(function(c){
      var card = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px');
      card.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:2rem;font-weight:700;color:var(--accent);line-height:1", String(c.num)));
      card.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:10px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);margin-top:4px", c.label));
      cards.appendChild(card);
    });
    container.appendChild(cards);
    // By category — prefer server aggregates (no row cap)
    var catCounts = {};
    if (owner && owner.recipes && Array.isArray(owner.recipes.by_category)) {
      owner.recipes.by_category.forEach(function(c) {
        if (c && c.category) catCounts[c.category] = parseInt(c.count, 10) || 0;
      });
    } else {
      allRecs.forEach(function(r){ if (r.category) catCounts[r.category] = (catCounts[r.category]||0) + 1; });
    }
    var catKeys = Object.keys(catCounts).sort(function(a,b){ return catCounts[b]-catCounts[a]; }).slice(0,14);
    if (catKeys.length) {
      var catCard = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
      catCard.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px",'Recipes by Category'));
      var maxC = catCounts[catKeys[0]] || 1;
      catKeys.forEach(function(c) {
        var pct = Math.round(catCounts[c] / maxC * 100);
        var row = mk('div','display:grid;grid-template-columns:160px 1fr 36px;gap:6px 10px;align-items:center;margin-bottom:6px');
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);text-align:right;overflow:hidden;text-overflow:ellipsis;white-space:nowrap", c));
        var bw = mk('div','background:rgba(255,255,255,0.06);border-radius:4px;height:14px;overflow:hidden');
        bw.appendChild(mk('div','height:100%;border-radius:4px;background:var(--accent);width:'+pct+'%',''));
        row.appendChild(bw);
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)", String(catCounts[c])));
        catCard.appendChild(row);
      });
      container.appendChild(catCard);
    }
    // Featured + ROTW
    var row2 = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:16px');
    var fc = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px');
    fc.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px",'\u2b50 Featured ('+feat+')'));
    allRecs.filter(function(r){return r.featured;}).slice(0,6).forEach(function(r){
      fc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-high);padding:3px 0;border-bottom:1px solid rgba(255,255,255,0.04)", r.recipe_name));
    });
    if (!feat) fc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'No featured recipes yet.'));
    var rc = mk('div','background:rgba(91,143,212,0.06);border:1px solid rgba(91,143,212,0.25);border-radius:12px;padding:20px');
    rc.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:#5B8FD4;margin-bottom:12px",'\uD83C\uDFC6 Recipe of the Week'));
    var rotw = allRecs.find(function(r){ return r.recipe_of_week; });
    if (rotw) {
      rc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-high);margin-bottom:4px", rotw.recipe_name));
      if (rotw.recipe_of_week_expires) {
        var exp = new Date(rotw.recipe_of_week_expires);
        rc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)",'Expires: ' + exp.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'})));
      }
    } else {
      rc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'Not set. Open any approved recipe and click \uD83C\uDFC6 Recipe of Week.'));
    }
    row2.appendChild(fc); row2.appendChild(rc);
    container.appendChild(row2);
    if (owner) {
      var miss = owner.recipes && owner.recipes.missing_taxonomy;
      if (miss > 0) {
        container.appendChild(mk('div', 'margin-bottom:14px;padding:10px 14px;background:rgba(196,151,59,0.1);border:1px solid var(--accent);border-radius:10px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid)',
          miss + ' approved recipe(s) missing taxonomy — open Taxonomy tab to backfill.'));
      }
      await renderOwnerAnalyticsExtras(container, owner);
    }
  } catch(e) { container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>'; }
}

async function loadRMCollections(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var collections = await rpc('admin_get_collections', {}) || [];
    if (!Array.isArray(collections)) collections = [];
    container.innerHTML = '';
    function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
    var addBar = mk('div','display:flex;justify-content:flex-end;margin-bottom:16px');
    var addBtn = mk('button','padding:7px 18px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer','+ New Collection');
    addBtn.addEventListener('click', function(){ openCollectionForm(null, container); });
    addBar.appendChild(addBtn); container.appendChild(addBar);
    if (!collections.length) { container.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid)",'No collections yet.')); return; }
    collections.forEach(function(c) {
      var card = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:12px');
      var row  = mk('div','display:flex;align-items:flex-start;justify-content:space-between');
      var info = mk('div','');
      info.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high)", c.name));
      if (c.description) info.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);margin-top:2px", c.description));
      info.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);margin-top:4px",
        (c.recipe_ids||[]).length + ' recipe' + ((c.recipe_ids||[]).length === 1 ? '' : 's') + ' \u2022 ' + (c.published ? '\u2705 Published' : '\uD83D\uDD12 Draft')));
      var btns = mk('div','display:flex;gap:6px');
      var editBtn = mk('button','padding:5px 12px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Edit');
      editBtn.addEventListener('click', (function(col){ return function(){ openCollectionForm(col, container); }; })(c));
      var delBtn = mk('button','padding:5px 12px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Delete');
      delBtn.addEventListener('click', (function(col){ return async function(){
        if (!confirm('Delete "' + col.name + '"?')) return;
        try { await rpc('admin_delete_collection', {p_id: col.id}); loadRMCollections(container); }
        catch(e){ alert('Error: '+e.message); }
      }; })(c));
      btns.appendChild(editBtn); btns.appendChild(delBtn);
      row.appendChild(info); row.appendChild(btns);
      card.appendChild(row); container.appendChild(card);
    });
  } catch(e) { container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>'; }
}

async function loadRMFeatured(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = [];
    if (typeof TcjAdminRecipes !== 'undefined') {
      rows = await TcjAdminRecipes.fetchAll({ p_status: 'approved', p_search: null, p_category: null });
    } else {
      rows = await rpc('admin_get_recipes', {p_status:'approved',p_search:null,p_category:null,p_limit:500,p_offset:0}) || [];
    }
    if (!Array.isArray(rows)) rows = [];
    var featured = rows.filter(function(r){ return r.featured; });
    var rotw     = rows.find(function(r){ return r.recipe_of_week; });
    container.innerHTML = '';
    function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
    // ROTW card
    var rotwCard = mk('div','background:rgba(91,143,212,0.06);border:1px solid rgba(91,143,212,0.3);border-radius:12px;padding:20px;margin-bottom:20px');
    rotwCard.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:#5B8FD4;margin-bottom:10px",'\uD83C\uDFC6 Recipe of the Week'));
    if (rotw) {
      rotwCard.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-high);margin-bottom:4px", rotw.recipe_name));
      if (rotw.recipe_of_week_expires) {
        rotwCard.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)",'Expires: ' + new Date(rotw.recipe_of_week_expires).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'})));
      }
      var clearBtn = mk('button','margin-top:10px;padding:6px 14px;background:none;border:1px solid #dc5050;border-radius:7px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Clear Recipe of the Week');
      clearBtn.addEventListener('click', async function(){
        if (!confirm('Clear Recipe of the Week?')) return;
        try {
          await rpc('admin_set_recipe_of_week', {p_id: null});
          loadRMFeatured(container);
        } catch(e) { alert('Error: '+e.message); }
      });
      rotwCard.appendChild(clearBtn);
    } else {
      rotwCard.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'Not set. Open any approved recipe and click \uD83C\uDFC6 Recipe of Week.'));
    }
    container.appendChild(rotwCard);
    // Featured list
    var featCard = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px');
    featCard.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px",'\u2b50 Featured Recipes (' + featured.length + ')'));
    if (!featured.length) {
      featCard.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'No featured recipes. Open any approved recipe and click \u2606 Feature.'));
    } else {
      featured.forEach(function(r) {
        var row = mk('div','display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.04)');
        var info = mk('div','');
        info.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-high)", r.recipe_name));
        info.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)", (r.category||'') + (r.username?' \u2022 @'+r.username:'')));
        var unfeatBtn = mk('button','padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Unfeature');
        unfeatBtn.addEventListener('click', (function(id){ return function(){
          toggleFeature(id, true);
          setTimeout(function(){ loadRMFeatured(container); }, 600);
        }; })(r.id));
        row.appendChild(info); row.appendChild(unfeatBtn);
        featCard.appendChild(row);
      });
    }
    container.appendChild(featCard);
  } catch(e) { container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>'; }
}

async function loadRMPrintQueue(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = await rpc('admin_get_recipes', { p_status: 'approved', p_search: null, p_category: null, p_limit: 100, p_offset: 0 }) || [];
    if (!Array.isArray(rows)) rows = [];
    container.innerHTML = '';
    function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }
    container.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:14px;line-height:1.6',
      'Approved recipes ready for Print Studio. Open a recipe to preview cards, booklet sheets, or PDF export.'));
    if (!rows.length) {
      container.appendChild(mk('div', 'font-size:13px;color:var(--text-mid)', 'No approved recipes yet.'));
      return;
    }
    var wrap = mk('div', 'overflow-x:auto');
    var tbl = mk('table', 'width:100%;border-collapse:collapse;font-size:12px;min-width:640px');
    tbl.innerHTML = '<thead><tr style="text-align:left;color:var(--text-mid);font-size:10px;text-transform:uppercase;letter-spacing:0.08em"><th style="padding:8px">Recipe</th><th style="padding:8px">Category</th><th style="padding:8px">Print</th><th style="padding:8px">Recipe page</th></tr></thead>';
    var tbody = mk('tbody');
    rows.forEach(function(r) {
      var tr = mk('tr');
      tr.style.borderTop = '1px solid rgba(255,255,255,0.06)';
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-high);font-weight:500', r.recipe_name || 'Recipe'));
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-mid)', r.category || '\u2014'));
      var printTd = mk('td', 'padding:8px');
      var printLink = mk('a', 'color:var(--accent);text-decoration:none;font-weight:500');
      printLink.href = 'print-studio.html?id=' + encodeURIComponent(r.id);
      printLink.target = '_blank';
      printLink.textContent = 'Open in Print Studio';
      printTd.appendChild(printLink);
      tr.appendChild(printTd);
      var pageTd = mk('td', 'padding:8px');
      var pageLink = mk('a', 'color:var(--text-mid);text-decoration:none');
      pageLink.href = 'recipe-page.html?id=' + encodeURIComponent(r.id);
      pageLink.target = '_blank';
      pageLink.textContent = 'View';
      pageTd.appendChild(pageLink);
      tr.appendChild(pageTd);
      tbody.appendChild(tr);
    });
    tbl.appendChild(tbody);
    wrap.appendChild(tbl);
    container.appendChild(wrap);
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

async function loadRMNutritionQueue(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = await rpc('admin_get_recipes', { p_status: 'approved', p_search: null, p_category: null, p_limit: 100, p_offset: 0 }) || [];
    if (!Array.isArray(rows)) rows = [];
    container.innerHTML = '';
    function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }
    container.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:14px;line-height:1.6',
      'Approved recipes — open the Nutrition tab to run Open Food Facts lookup per recipe. Results are approximate and cached in the browser.'));
    if (!rows.length) {
      container.appendChild(mk('div', 'font-size:13px;color:var(--text-mid)', 'No approved recipes yet.'));
      return;
    }
    var wrap = mk('div', 'overflow-x:auto');
    var tbl = mk('table', 'width:100%;border-collapse:collapse;font-size:12px;min-width:560px');
    tbl.innerHTML = '<thead><tr style="text-align:left;color:var(--text-mid);font-size:10px;text-transform:uppercase;letter-spacing:0.08em"><th style="padding:8px">Recipe</th><th style="padding:8px">Category</th><th style="padding:8px">Check OFF nutrition</th></tr></thead>';
    var tbody = mk('tbody');
    rows.forEach(function(r) {
      var tr = mk('tr');
      tr.style.borderTop = '1px solid rgba(255,255,255,0.06)';
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-high);font-weight:500', r.recipe_name || 'Recipe'));
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-mid)', r.category || '\u2014'));
      var actTd = mk('td', 'padding:8px');
      var link = mk('a', 'color:var(--accent);text-decoration:none;font-weight:500');
      link.href = 'recipe-page.html?id=' + encodeURIComponent(r.id) + '&tab=nutrition';
      link.target = '_blank';
      link.textContent = 'Open Nutrition tab';
      actTd.appendChild(link);
      tr.appendChild(actTd);
      tbody.appendChild(tr);
    });
    tbl.appendChild(tbody);
    wrap.appendChild(tbl);
    container.appendChild(wrap);
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

async function loadRMSourceLinks(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = await rpc('admin_get_source_link_status', { p_limit: 80 }) || [];
    container.innerHTML = '';
    function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }
    container.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:14px;line-height:1.6',
      'Approved recipes with a credit URL. Status is updated by the weekly check-dead-links cron (Sundays 03:00 UTC) or Run link check now.'));
    var btnRow = mk('div', 'display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px');
    var runBtn = mk('button', 'padding:8px 14px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-size:12px;cursor:pointer', 'Run link check now');
    runBtn.addEventListener('click', function() {
      runBtn.disabled = true;
      rpc('admin_invoke_edge_function', { p_function: 'check-dead-links' })
        .then(function() { alert('Link check triggered. Refresh in ~15 seconds.'); loadRMSourceLinks(container); })
        .catch(function(e) { alert(e.message); })
        .finally(function() { runBtn.disabled = false; });
    });
    var queueBtn = mk('button', 'padding:8px 14px;background:none;border:1px solid var(--border);border-radius:8px;color:var(--text-mid);font-size:12px;cursor:pointer', 'Queue all for re-check');
    queueBtn.addEventListener('click', function() {
      rpc('admin_queue_all_link_rechecks', {})
        .then(function(n) { alert('Queued ' + (n || 0) + ' recipe(s) for next check.'); loadRMSourceLinks(container); })
        .catch(function(e) { alert(e.message); });
    });
    btnRow.appendChild(runBtn);
    btnRow.appendChild(queueBtn);
    container.appendChild(btnRow);
    if (!rows.length) {
      container.appendChild(mk('div', 'font-size:13px;color:var(--text-mid)', 'No approved recipes with source URLs yet.'));
      return;
    }
    var statusColor = { ok: '#4caf76', dead: '#dc5050', unknown: '#c4973b' };
    var wrap = mk('div', 'overflow-x:auto');
    var tbl = mk('table', 'width:100%;border-collapse:collapse;font-size:12px;min-width:720px');
    tbl.innerHTML = '<thead><tr style="text-align:left;color:var(--text-mid);font-size:10px;text-transform:uppercase;letter-spacing:0.08em"><th style="padding:8px">Recipe</th><th style="padding:8px">URL</th><th style="padding:8px">Status</th><th style="padding:8px">Checked</th><th style="padding:8px"></th></tr></thead>';
    var tbody = mk('tbody');
    rows.forEach(function(r) {
      var tr = mk('tr');
      tr.style.borderTop = '1px solid rgba(255,255,255,0.06)';
      var nameTd = mk('td', 'padding:8px;color:var(--text-high);font-weight:500');
      var link = mk('a', 'color:var(--accent);text-decoration:none');
      link.href = 'recipe-page.html?id=' + encodeURIComponent(r.id);
      link.textContent = r.recipe_name || 'Recipe';
      link.target = '_blank';
      nameTd.appendChild(link);
      tr.appendChild(nameTd);
      var urlTd = mk('td', 'padding:8px;color:var(--text-mid);max-width:280px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap');
      if (r.credit_url) {
        var ext = mk('a', 'color:var(--text-mid)');
        ext.href = r.credit_url;
        ext.target = '_blank';
        ext.rel = 'noopener';
        ext.textContent = r.credit_url;
        urlTd.appendChild(ext);
      } else {
        urlTd.textContent = '\u2014';
      }
      tr.appendChild(urlTd);
      var st = (r.source_link_status || 'pending').toLowerCase();
      var stTd = mk('td', 'padding:8px;font-weight:600;color:' + (statusColor[st] || 'var(--text-mid)'));
      stTd.textContent = st === 'ok' ? 'OK' : st.charAt(0).toUpperCase() + st.slice(1);
      tr.appendChild(stTd);
      var chk = r.source_link_checked_at ? new Date(r.source_link_checked_at).toLocaleString() : 'Never';
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-mid)', chk));
      if (r.credit_url && String(r.credit_url).trim().toLowerCase().indexOf('http') === 0) {
        var actTd = mk('td', 'padding:8px');
        var reBtn = mk('button', 'padding:4px 8px;font-size:10px;border:1px solid var(--border);border-radius:6px;background:none;color:var(--text-mid);cursor:pointer', 'Re-check');
        reBtn.addEventListener('click', function() {
          reBtn.disabled = true;
          rpc('admin_reset_source_link_check', { p_recipe_id: r.id })
            .then(function() { alert('Queued for re-check.'); loadRMSourceLinks(container); })
            .catch(function(e) { alert(e.message); })
            .finally(function() { reBtn.disabled = false; });
        });
        actTd.appendChild(reBtn);
        tr.appendChild(actTd);
      } else {
        tr.appendChild(mk('td', 'padding:8px'));
      }
      tbody.appendChild(tr);
    });
    tbl.appendChild(tbody);
    wrap.appendChild(tbl);
    container.appendChild(wrap);
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

async function loadRMWebsiteSources(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = await rpc('admin_list_website_sources', {}) || [];
    container.innerHTML = '';
    function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
    container.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:14px;line-height:1.6',
      'Turn a website OFF to stop new imports and hide approved recipes from that site on public browse. ' +
      'Chef name is saved on each recipe as credit. Live recipe URL is stored as Source URL on Submit a Recipe.'));
    container.appendChild(mk('div', 'font-size:11px;color:var(--text-mid);margin-bottom:14px',
      'Run database/sql/fix-website-sources.sql in Supabase once if this tab shows an RPC error.'));

    if (!rows.length) {
      container.appendChild(mk('div', 'font-size:13px;color:var(--text-mid)', 'No website sources yet. Run fix-website-sources.sql to seed your list.'));
      return;
    }

    var wrap = mk('div', 'overflow-x:auto');
    var tbl = mk('table', 'width:100%;border-collapse:collapse;font-size:12px;min-width:860px');
    tbl.innerHTML = '<thead><tr style="text-align:left;color:var(--text-mid);font-size:10px;text-transform:uppercase;letter-spacing:0.08em">' +
      '<th style="padding:8px">Site</th><th style="padding:8px">Chef credit</th><th style="padding:8px">Recipes</th>' +
      '<th style="padding:8px">Import</th><th style="padding:8px">Base URL</th></tr></thead>';
    var tbody = mk('tbody');

    rows.forEach(function(r) {
      var tr = mk('tr');
      tr.style.borderTop = '1px solid rgba(255,255,255,0.06)';
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-high);font-weight:500', r.display_name || r.host));
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-mid)', r.chef_name || '\u2014'));
      tr.appendChild(mk('td', 'padding:8px;color:var(--text-mid)', String(r.recipe_count || 0)));

      var toggleTd = mk('td', 'padding:8px');
      var toggle = mk('button', 'padding:6px 12px;border-radius:8px;border:1px solid var(--border);cursor:pointer;font-size:11px;font-family:DM Sans,sans-serif',
        r.is_active ? 'ON \u2014 click to switch off' : 'OFF \u2014 click to switch on');
      toggle.style.background = r.is_active ? 'rgba(76,175,118,0.15)' : 'rgba(220,80,80,0.12)';
      toggle.style.color = r.is_active ? '#4caf76' : '#dc5050';
      toggle.addEventListener('click', function() {
        var next = !r.is_active;
        var msg = next
          ? 'Switch ON ' + (r.display_name || r.host) + '? Approved recipes from this site will become public again.'
          : 'Switch OFF ' + (r.display_name || r.host) + '? New imports stop and approved recipes from this site are hidden from public browse.';
        if (!confirm(msg)) return;
        toggle.disabled = true;
        rpc('admin_set_website_source_active', { p_host: r.host, p_active: next })
          .then(function(res) {
            var hidden = res && res.recipes_hidden != null ? res.recipes_hidden : 0;
            var shown = res && res.recipes_restored != null ? res.recipes_restored : 0;
            alert(next
              ? 'Source enabled. Restored ' + shown + ' recipe(s) to public visibility.'
              : 'Source disabled. Hidden ' + hidden + ' approved recipe(s) from public browse.');
            loadRMWebsiteSources(container);
          })
          .catch(function(e) { alert(e.message); toggle.disabled = false; });
      });
      toggleTd.appendChild(toggle);
      tr.appendChild(toggleTd);

      var urlTd = mk('td', 'padding:8px;max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap');
      if (r.base_url) {
        var link = mk('a', 'color:var(--text-mid);text-decoration:none');
        link.href = r.base_url;
        link.target = '_blank';
        link.rel = 'noopener';
        link.textContent = r.base_url;
        urlTd.appendChild(link);
      } else {
        urlTd.textContent = '\u2014';
      }
      tr.appendChild(urlTd);
      tbody.appendChild(tr);
    });

    tbl.appendChild(tbody);
    wrap.appendChild(tbl);
    container.appendChild(wrap);
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

async function loadRMDuplicates(host) {
  try {
    var dupes = await rpc('admin_find_duplicate_recipes', { p_limit: 30 }) || [];
    if (!Array.isArray(dupes)) dupes = [];
    function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
    var box = mk('div', 'margin-bottom:24px;padding:16px;background:rgba(220,80,80,0.06);border:1px solid rgba(220,80,80,0.25);border-radius:12px');
    box.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#dc5050;margin-bottom:8px', 'Possible duplicate recipes'));
    if (!dupes.length) {
      box.appendChild(mk('div', 'font-size:12px;color:var(--text-mid)', 'No duplicate name groups found.'));
      host.appendChild(box);
      return;
    }
    box.appendChild(mk('div', 'font-size:12px;color:var(--text-mid);margin-bottom:12px', dupes.length + ' group' + (dupes.length === 1 ? '' : 's') + ' — review before approving similar submissions.'));
    dupes.forEach(function(g) {
      var card = mk('div', 'margin-bottom:10px;padding:10px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px');
      card.appendChild(mk('div', 'font-size:12px;font-weight:600;color:var(--text-high);margin-bottom:6px', (g.recipe_names && g.recipe_names[0]) || g.group_key || 'Group'));
      (g.recipe_ids || []).forEach(function(id, i) {
        var row = mk('div', 'display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:11px;color:var(--text-mid);padding:3px 0');
        var nm = (g.recipe_names || [])[i] || 'Recipe';
        var st = (g.statuses || [])[i] || '';
        var cr = (g.credit_names || [])[i] || '';
        row.appendChild(mk('span', '', nm + (cr ? ' · ' + cr : '') + (st ? ' [' + st + ']' : '')));
        var open = mk('button', 'padding:3px 8px;font-size:10px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--accent);cursor:pointer', 'Review');
        open.addEventListener('click', function() { openRecipeModal(id); });
        row.appendChild(open);
        card.appendChild(row);
      });
      box.appendChild(card);
    });
    host.appendChild(box);
  } catch (e) {
    var err = document.createElement('div');
    err.style.cssText = 'font-size:12px;color:var(--text-mid);margin-bottom:16px';
    err.textContent = 'Duplicate scan unavailable — run fix-phase34-batch.sql';
    host.appendChild(err);
  }
}

async function loadRMAudit(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    container.innerHTML = '';
    await loadRMDuplicates(container);
    var rows = [];
    if (typeof TcjAdminAudit !== 'undefined') {
      rows = await TcjAdminAudit.fetchAll({});
    } else {
      rows = await rpc('admin_get_audit_log', {p_limit:200,p_offset:0}) || [];
    }
    var rmRows = rows.filter(function(r){ return (r.tab||'').includes('Recipe Management'); });
    function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
    if (!rmRows.length) { container.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid)",'No recipe management actions logged yet.')); return; }
    var wrap  = mk('div','overflow-x:auto');
    var inner = mk('div','min-width:800px');
    var COLS  = [{l:'Timestamp',w:'160px'},{l:'Admin',w:'140px'},{l:'Action',w:'200px'},{l:'Details',w:'1fr'}];
    var tpl   = COLS.map(function(c){return c.w;}).join(' ');
    var hdr   = mk('div','display:grid;grid-template-columns:'+tpl+';gap:0 8px;padding-bottom:8px;border-bottom:1px solid var(--border)');
    COLS.forEach(function(c){ hdr.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:10px;font-weight:700;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em",c.l)); });
    inner.appendChild(hdr);
    var MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    rmRows.forEach(function(r) {
      var d   = new Date(r.created_at);
      var pad = function(n){ return n<10?'0'+n:String(n); };
      var ts  = d.getDate()+' '+MONTHS[d.getMonth()]+' '+d.getFullYear()+' '+pad(d.getHours())+':'+pad(d.getMinutes());
      var row = mk('div','display:grid;grid-template-columns:'+tpl+';gap:0 8px;padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.04)');
      var cs  = "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)";
      var ch  = "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high)";
      function cell(t,s){ var el=mk('div',s||cs); el.textContent=t||'\u2014'; return el; }
      row.appendChild(cell(ts,cs));
      row.appendChild(cell(r.admin_name,ch));
      row.appendChild(cell(r.action,ch));
      row.appendChild(cell([r.old_value,r.new_value].filter(Boolean).join(' \u2192 '),cs));
      inner.appendChild(row);
    });
    wrap.appendChild(inner); container.appendChild(wrap);
  } catch(e) { container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>'; }
}



// â”€â”€ USER MANAGEMENT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// â”€â”€ USER MANAGEMENT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
var _userPage       = 1;
var _userPageSize   = 50;
var _userTotal      = 0;
var _userSearch     = '';
var _userStatus     = '';
var _currentUserTab = 'members';
var _selectedUsers  = {};
var _userDetailOpen = false;

async function buildSMFeatures(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var res = await apiFetch(SUPABASE_URL+'/rest/v1/site_features?order=sort_order');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var features = await res.json();
    if (!Array.isArray(features)||!features.length){container.dataset.built='';container.innerHTML='<div style="padding:16px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">No features found.</div>';return;}
    container.innerHTML='';
    var tierOpts = [{v:'free',l:'Free'},{v:'daily',l:'Daily'},{v:'weekly',l:'Weekly'},{v:'monthly',l:'Monthly'},{v:'yearly',l:'Yearly'},{v:'premium',l:'Premium'},{v:'event',l:'Event'}];
    features.forEach(function(f){
      var row=document.createElement('div');row.style.cssText='display:flex;align-items:center;justify-content:space-between;padding:12px 16px;background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:9px;margin-bottom:8px;flex-wrap:wrap;gap:10px';
      var info=document.createElement('div');
      info.innerHTML='<div style="font-family:DM Sans,sans-serif;font-size:13px;font-weight:500;color:var(--text-high)">'+(f.name||'')+'</div>'+(f.description?'<div style="font-size:11px;color:var(--text-mid);margin-top:2px">'+(f.description||'')+'</div>':'');
      var right=document.createElement('div');right.style.cssText='display:flex;align-items:center;gap:10px;flex-wrap:wrap';
      if (f.min_tier !== undefined) {
        var tierSel = document.createElement('select');
        tierSel.style.cssText = 'padding:4px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)';
        tierOpts.forEach(function(o) {
          var opt = document.createElement('option');
          opt.value = o.v; opt.textContent = o.l;
          if ((f.min_tier || 'free') === o.v) opt.selected = true;
          tierSel.appendChild(opt);
        });
        tierSel.addEventListener('change', (function(key, sel) { return async function() {
          var prev = sel.value;
          try {
            var r = await apiFetch(SUPABASE_URL + '/rest/v1/site_features?key=eq.' + encodeURIComponent(key), {
              method: 'PATCH', headers: { 'Content-Type': 'application/json', 'Prefer': 'return=minimal' },
              body: JSON.stringify({ min_tier: sel.value })
            });
            if (!r || !r.ok) throw new Error(r ? r.status + ': ' + await r.text() : 'Session expired');
          } catch (e) { sel.value = prev; alert('Tier save failed: ' + e.message); }
        }; })(f.key, tierSel));
        right.appendChild(tierSel);
      }
      var st=document.createElement('span');st.style.cssText='font-size:11px;font-weight:600;color:'+(f.enabled?'#4caf76':'#dc5050');st.textContent=f.enabled?'Enabled':'Disabled';
      var cb=document.createElement('input');cb.type='checkbox';cb.checked=!!f.enabled;cb.style.cssText='width:16px;height:16px;accent-color:var(--accent);cursor:pointer';
      cb.addEventListener('change',(function(key,s){return async function(){
        var prev=this.checked;
        try{var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_features?key=eq.'+encodeURIComponent(key),{method:'PATCH',headers:{'Content-Type':'application/json','Prefer':'return=representation'},body:JSON.stringify({enabled:this.checked})});
        if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');
        s.textContent=this.checked?'Enabled':'Disabled';s.style.color=this.checked?'#4caf76':'#dc5050';}
        catch(e){this.checked=!prev;alert('Toggle failed: '+e.message);}
      };})(f.key,st));
      right.appendChild(st);right.appendChild(cb);row.appendChild(info);row.appendChild(right);container.appendChild(row);
    });
    container.dataset.built='1';
  } catch(e){container.dataset.built='';container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';}
}

function showImportPreview(title, summary, onMerge, onReplace){
  var overlay=document.createElement('div');
  overlay.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:99998;display:flex;align-items:center;justify-content:center';

  var modal=document.createElement('div');
  modal.style.cssText='background:var(--bg);border:1px solid var(--border);border-radius:14px;padding:28px;max-width:480px;width:90%;font-family:DM Sans,sans-serif';

  var h=document.createElement('div');h.style.cssText="font-family:'Cormorant Garamond',serif;font-size:1.2rem;font-weight:700;color:var(--text-high);margin-bottom:12px";h.textContent=title;
  var s=document.createElement('div');s.style.cssText='font-size:13px;color:var(--text-mid);margin-bottom:20px;white-space:pre-line;line-height:1.6';s.textContent=summary;

  var btns=document.createElement('div');btns.style.cssText='display:flex;gap:10px;flex-wrap:wrap';

  function makeBtn(label,fn,color){
    var b=document.createElement('button');
    b.textContent=label;b.style.cssText='padding:9px 20px;background:'+color+';border:none;border-radius:7px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer';
    b.addEventListener('click',function(){fn();overlay.remove();});
    return b;
  }
  btns.appendChild(makeBtn('Merge (keep existing)',onMerge,'#2d5a8e'));
  btns.appendChild(makeBtn('Replace (clear & reload)',onReplace,'#8e2d2d'));
  var cancel=document.createElement('button');
  cancel.textContent='Cancel';cancel.style.cssText='padding:9px 20px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer';
  cancel.addEventListener('click',function(){overlay.remove();});
  btns.appendChild(cancel);

  modal.appendChild(h);modal.appendChild(s);modal.appendChild(btns);
  overlay.appendChild(modal);document.body.appendChild(overlay);
}

// â”€â”€ Categories + Sub Categories Export â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

async function loadRecipeAnalytics() {
  try {
    var owner = await rpc('admin_get_owner_analytics', {}).catch(function() { return null; });
    var ownerHost = document.getElementById('ra-owner-extras');
    if (ownerHost) {
      ownerHost.innerHTML = '';
      if (owner) renderOwnerAnalyticsExtras(ownerHost, owner);
    }
    const stats = (owner && owner.recipes) ? owner.recipes : await rpc('admin_get_stats', {});
    if (stats) {
      const total    = (stats.total    || stats.total_recipes || 0);
      const pending  = (stats.pending  || stats.pending_recipes || 0);
      const approved = (stats.approved || stats.approved_recipes || 0);
      const rejected = (stats.rejected || stats.rejected_recipes || 0);
      const rate     = total > 0 ? Math.round((approved/total)*100) : 0;
      setElT('ra-total',      total);
      setElT('ra-rate',       rate + '%');
      setElT('ra-pending',    pending);
      // Count distinct categories
      const allRecs = await rpc('admin_get_recipes', { p_status: null });
      const cats = new Set((allRecs||[]).map(function(r){ return r.category; }).filter(Boolean));
      setElT('ra-categories', cats.size);
      // Status chart
      renderBarChart('ra-status-chart', [
        {label:'Approved', value: approved},
        {label:'Pending',  value: pending},
        {label:'Rejected', value: rejected}
      ], 'var(--accent)');
      // Category chart
      const catCounts = {};
      (allRecs||[]).forEach(function(r){ if(r.category) catCounts[r.category]=(catCounts[r.category]||0)+1; });
      const catData = Object.entries(catCounts).map(function(e){ return {label:e[0],value:e[1]}; }).sort(function(a,b){return b.value-a.value;});
      renderBarChart('ra-category-chart', catData, 'var(--accent)');
    }
  } catch(e) { console.warn('recipe analytics', e); }
}

function showCsvPreview(data){
  const cols=Object.keys(data[0]),preview=data.slice(0,10);
  document.getElementById('csv-drop-zone').style.display='none';
  document.getElementById('csv-row-count').textContent=data.length+' row'+(data.length===1?'':'s')+' ready';
  document.getElementById('csv-preview-label').textContent=' — showing first '+Math.min(10,data.length);
  document.getElementById('csv-preview-table').innerHTML='<thead><tr>'+cols.map(function(c){return '<th>'+c+'</th>';}).join('')+'</tr></thead><tbody>'+preview.map(function(row){return '<tr>'+cols.map(function(c){return '<td>'+(row[c]||'')+'</td>';}).join('')+'</tr>';}).join('')+'</tbody>';
  document.getElementById('csv-preview-section').style.display='block';
  document.getElementById('csv-import-btn').disabled=false;
  setTimeout(fixDropdownTheme,10);
}

async function bulkApproveRecipes() {
  var ids = Array.from(_selectedRecipes || []);
  if (!ids.length) return;
  if (!confirm('Approve '+ids.length+' recipe'+((ids.length===1)?'':'s')+'?')) return;
  try {
    var n = await rpc('admin_bulk_approve_recipes', {p_ids: ids});
    auditLog('Recipe Management','Bulk Approval',null,null,'approved',n+' recipes');
    _selectedRecipes = new Set();
    loadRecipeMgmt(_currentRecipeTab);
  } catch(e) { alert('Error: '+e.message); }
}

async function approveAllPendingRecipes() {
  var pending = getRmStatNum('rmgmt-pending');
  if (!pending) return;
  if (!confirm('Approve all ' + pending + ' pending recipe' + (pending === 1 ? '' : 's') + '?\n\nThey will go live on the site. One confirmation only.')) return;
  var btn = document.getElementById('rm-bulk-approve-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'Approving\u2026'; }
  try {
    var n = await rpc('admin_approve_all_pending', {});
    auditLog('Recipe Management', 'Bulk Approval', null, null, 'approved', String(n) + ' recipes');
    _rmPage = 1;
    await loadRecipeMgmt('pending');
  } catch (e) {
    var msg = e && e.message ? e.message : String(e);
    if (/admin_approve_all_pending|Could not find|PGRST202/i.test(msg)) {
      alert('Approve All Pending needs one SQL step first.\n\nRun database/sql/fix-admin-approve-all-pending.sql in Supabase SQL Editor, then try again.');
    } else {
      alert('Error: ' + msg);
    }
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = '\u2713 Approve All Pending'; }
  }
}

async function rejectAllPendingRecipes() {
  var pending = getRmStatNum('rmgmt-pending');
  if (!pending) return;
  if (!confirm('Reject all ' + pending + ' pending recipe' + (pending === 1 ? '' : 's') + '?\n\nOne confirmation only — the list will clear without reloading each row.')) return;
  var btn = document.getElementById('rm-bulk-reject-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'Rejecting\u2026'; }
  try {
    var n = await rpc('admin_reject_all_pending', { p_notes: 'Bulk inbox clear' });
    auditLog('Recipe Management', 'Bulk Reject', null, null, 'rejected', String(n) + ' recipes');
    _rmPage = 1;
    await loadRecipeMgmt('pending');
  } catch (e) {
    var msg = e && e.message ? e.message : String(e);
    if (/admin_reject_all_pending|Could not find|PGRST202/i.test(msg)) {
      alert('Reject All Pending needs one SQL step first.\n\nRun database/sql/fix-admin-bulk-reject-recipes.sql in Supabase SQL Editor, then try again.\n\nUntil then, use \u2715 Reject on each row (no popup per row anymore).');
    } else {
      alert('Error: ' + msg);
    }
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = '\u2715 Reject All Pending'; }
  }
}


// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// FM INTERFACE (Finance Management > FM Interface tab)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Recipe of the Week + Cooking Notes Approval
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

async function loadROTW() {
  var panel = document.getElementById('rm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading…</div>';
  try {
    var recipes = [];
    if (typeof TcjAdminRecipes !== 'undefined') {
      recipes = await TcjAdminRecipes.fetchAll({ p_status: 'approved', p_search: null, p_category: null });
    } else {
      console.warn('loadROTW: TcjAdminRecipes missing — capped at 200 rows');
      var rows = await rpc('admin_get_recipes', { p_status: 'approved', p_limit: 200, p_offset: 0 });
      recipes = Array.isArray(rows) ? rows : [];
    }
    function isRotw(r) { return !!(r && (r.recipe_of_week || r.is_recipe_of_week)); }
    var current = recipes.find(isRotw);

    var html = '<div style="font-family:DM Sans,sans-serif">' +
      '<div style="margin-bottom:24px;padding:20px;background:rgba(196,151,59,.06);border:1px solid rgba(196,151,59,.2);border-radius:12px">' +
      '<div style="font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);margin-bottom:8px">Currently Featured</div>';

    if (current) {
      html += '<div style="font-size:15px;font-weight:600;color:var(--text-high);margin-bottom:4px">' + esc(current.recipe_name) + '</div>' +
        '<div style="font-size:12px;color:var(--text-muted)">Set ' + (current.recipe_of_week_at ? new Date(current.recipe_of_week_at).toLocaleDateString() : 'unknown') + '</div>' +
        '<button onclick="setROTW(null)" style="margin-top:12px;font-family:DM Sans,sans-serif;font-size:12px;padding:6px 14px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Clear Recipe of the Week</button>';
    } else {
      html += '<div style="font-size:13px;color:var(--text-muted)">No recipe set as Recipe of the Week.</div>';
    }
    html += '</div>';

    html += '<div style="font-size:12px;color:var(--text-muted);margin-bottom:12px">Select from approved recipes:</div>' +
      '<input type="text" id="rotw-search" placeholder="Search recipes…" oninput="filterROTWList(this.value)" ' +
      'style="width:100%;max-width:400px;background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:8px 12px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high);outline:none;margin-bottom:12px">' +
      '<div id="rotw-list">';

    recipes.forEach(function(r) {
      html += '<div class="rotw-row" data-name="' + esc((r.recipe_name||'').toLowerCase()) + '" ' +
        'style="display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-bottom:1px solid rgba(255,255,255,.04)">' +
        '<div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)">' + esc(r.recipe_name||'') + '</div>' +
        '<div style="font-size:11px;color:var(--text-muted)">' + esc(r.category||'') + '</div>' +
        '</div>' +
        '<button onclick="setROTW(\'' + esc(r.id) + '\')" ' +
        'style="font-family:DM Sans,sans-serif;font-size:11px;font-weight:600;padding:5px 12px;border-radius:6px;border:1px solid ' +
        (isRotw(r)?'var(--accent)':'var(--border)') + ';background:' +
        (isRotw(r)?'var(--accent)':'none') + ';color:' +
        (isRotw(r)?'#0C0702':'var(--text-mid)') + ';cursor:pointer">' +
        (isRotw(r)?'â­ Current':'Set as ROTW') + '</button>' +
        '</div>';
    });

    html += '</div></div>';
    panel.innerHTML = html;
  } catch(e) {
    panel.innerHTML = '<div class="ap-empty">Error: ' + esc(e.message||String(e)) + '</div>';
  }
}

function filterROTWList(query) {
  var q = (query||'').toLowerCase();
  document.querySelectorAll('.rotw-row').forEach(function(row) {
    row.style.display = (!q || row.dataset.name.includes(q)) ? '' : 'none';
  });
}

async function setROTW(id) {
  try {
    await rpc('admin_set_recipe_of_week', { p_id: id || null });
    loadROTW();
  } catch(e) { alert('Error: ' + (e.message||e)); }
}

// â”€â”€ Cooking Tips / Notes Approval â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
async function loadRecipeNotes(container) {
  var panel = container || document.getElementById('rm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading…</div>';
  try {
    var notes = await rpc('admin_get_pending_notes', {});
    buildNotesPanel(panel, Array.isArray(notes) ? notes : []);
    // Update badge
    var badge = document.getElementById('rtab-badge-notes');
    if (badge) badge.textContent = Array.isArray(notes) ? notes.length : 0;
  } catch(e) {
    panel.innerHTML = '<div class="ap-empty">Error: ' + esc(e.message||String(e)) + '</div>';
  }
}

function buildNotesPanel(panel, notes) {
  if (!notes.length) {
    panel.innerHTML = '<div class="ap-empty">No cooking tips pending review.</div>';
    return;
  }
  var html = '<div style="font-family:DM Sans,sans-serif">' +
    '<div style="font-size:12px;color:var(--text-muted);margin-bottom:16px">' + notes.length + ' cooking tip' + (notes.length!==1?'s':'') + ' pending review</div>';

  notes.forEach(function(n) {
    html += '<div style="background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:12px">' +
      '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:10px">' +
      '<div>' +
      '<div style="font-size:13px;font-weight:600;color:var(--text-high);margin-bottom:3px">' + esc(n.recipe_name||'Recipe') + '</div>' +
      '<div style="font-size:11px;color:var(--text-muted)">Submitted by @' + esc(n.submitted_by||'member') + ' · ' + (n.created_at ? new Date(n.created_at).toLocaleDateString() : '') + '</div>' +
      '</div>' +
      '<div style="display:flex;gap:8px">' +
      '<button onclick="reviewNote(' + n.id + ',\'approved\')" style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;padding:6px 14px;border-radius:6px;border:none;background:#6dc86d;color:#0C0702;cursor:pointer">Approve</button>' +
      '<button onclick="reviewNote(' + n.id + ',\'rejected\')" style="font-family:DM Sans,sans-serif;font-size:12px;padding:6px 14px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Reject</button>' +
      '</div></div>' +
      '<div style="font-size:13px;color:var(--text-mid);line-height:1.6;background:var(--bg);padding:12px;border-radius:8px">' + esc(n.note||'') + '</div>' +
      '</div>';
  });

  html += '</div>';
  panel.innerHTML = html;
}

async function reviewNote(id, status) {
  try {
    await rpc('admin_review_note', { p_id: id, p_status: status });
    loadRecipeNotes();
  } catch(e) { alert('Error: ' + (e.message||e)); }
}

window.loadRecipeNotes = loadRecipeNotes;
window.reviewNote = reviewNote;

function rmTaxCollapsed(key, defOpen) {
  try {
    var raw = sessionStorage.getItem('rmTaxCollapsed');
    var map = raw ? JSON.parse(raw) : {};
    if (Object.prototype.hasOwnProperty.call(map, key)) return !map[key];
    return !defOpen;
  } catch (e) { return !defOpen; }
}
function rmTaxSetCollapsed(key, open) {
  try {
    var raw = sessionStorage.getItem('rmTaxCollapsed');
    var map = raw ? JSON.parse(raw) : {};
    map[key] = !!open;
    sessionStorage.setItem('rmTaxCollapsed', JSON.stringify(map));
  } catch (e) { /* ignore */ }
}
function rmTaxMoveBtn(label, title, disabled, onClick) {
  var b = document.createElement('button');
  b.type = 'button';
  b.textContent = label;
  b.title = title || '';
  b.disabled = !!disabled;
  b.style.cssText = 'padding:2px 8px;font-size:11px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--text-mid);cursor:pointer;min-width:28px';
  if (disabled) b.style.opacity = '0.35';
  b.addEventListener('click', onClick);
  return b;
}
function rmTaxLabel(text) {
  var e = document.createElement('div');
  e.style.cssText = 'font-size:10px;font-weight:600;letter-spacing:0.08em;text-transform:uppercase;color:var(--text-mid);margin:10px 0 4px';
  e.textContent = text;
  return e;
}
function rmTaxInput(val, placeholder, flex) {
  var e = document.createElement('input');
  e.type = 'text';
  e.value = val || '';
  e.placeholder = placeholder || '';
  e.style.cssText = 'padding:6px 10px;background:rgba(0,0,0,0.2);border:1px solid var(--border);border-radius:6px;font-size:12px;color:var(--text-high);font-family:DM Sans,sans-serif;box-sizing:border-box' +
    (flex ? ';flex:1;min-width:120px' : '');
  return e;
}
function rmTaxTextarea(val, placeholder, minH) {
  var e = document.createElement('textarea');
  e.value = val || '';
  e.placeholder = placeholder || '';
  e.style.cssText = 'width:100%;min-height:' + (minH || 52) + 'px;padding:8px 10px;background:rgba(0,0,0,0.2);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high);font-family:DM Sans,sans-serif;line-height:1.5;resize:vertical;box-sizing:border-box';
  return e;
}

function rmTaxSnapshotSub(fields) {
  return JSON.stringify({
    emoji: (fields && fields.emoji) || '',
    tagline: (fields && fields.tagline) || '',
    description: (fields && fields.description) || '',
    ingredient_hints: (fields && fields.ingredient_hints) || []
  });
}

function rmTaxAudit(action, target, oldVal, newVal, details) {
  if (typeof auditLog === 'function') {
    auditLog('Recipe Management > Taxonomy', action, target, oldVal, newVal, details);
  }
}

function rmTaxFlashSaved(btn, normalText) {
  if (!btn) return;
  var prevBg = btn.style.background;
  var prevColor = btn.style.color;
  btn.textContent = 'Saved \u2713';
  btn.style.background = '#4caf76';
  btn.style.color = '#fff';
  setTimeout(function() {
    btn.textContent = normalText;
    btn.style.background = prevBg;
    btn.style.color = prevColor;
  }, 1400);
}

function rmTaxNormalizeLabel(value) {
  return String(value || '').replace(/\u00a0/g, ' ').replace(/\s+/g, ' ').trim();
}

async function rmTaxFindSubcategoryId(category, name) {
  category = rmTaxNormalizeLabel(category);
  name = rmTaxNormalizeLabel(name);
  if (!category || !name || typeof apiFetch !== 'function') return null;
  var url = window.SUPA_URL + '/rest/v1/recipe_subcategories?category=eq.' +
    encodeURIComponent(category) + '&name=eq.' + encodeURIComponent(name) + '&select=id&limit=1';
  var res = await apiFetch(url);
  if (!res || !res.ok) return null;
  var rows = await res.json();
  return rows && rows[0] && rows[0].id ? rows[0].id : null;
}

async function rmTaxFindDivisionId(category, subcategory, name) {
  category = rmTaxNormalizeLabel(category);
  subcategory = rmTaxNormalizeLabel(subcategory);
  name = rmTaxNormalizeLabel(name);
  if (!category || !subcategory || !name || typeof apiFetch !== 'function') return null;
  var url = window.SUPA_URL + '/rest/v1/recipe_divisions?category=eq.' +
    encodeURIComponent(category) + '&subcategory=eq.' + encodeURIComponent(subcategory) +
    '&name=eq.' + encodeURIComponent(name) + '&select=id&limit=1';
  var res = await apiFetch(url);
  if (!res || !res.ok) return null;
  var rows = await res.json();
  return rows && rows[0] && rows[0].id ? rows[0].id : null;
}

// After any save, force a single active row per normalized (category, name).
// This is the belt-and-suspenders guard against rename/edit duplicates even if the
// deployed upsert RPC is an older version that inserts instead of overwriting.
async function rmTaxDedupeSubcategory(category, name, keepId) {
  try {
    var nCat = rmTaxNormalizeLabel(category);
    var nName = rmTaxNormalizeLabel(name);
    if (!nCat || !nName || !keepId || typeof apiFetch !== 'function') return;
    var url = window.SUPA_URL + '/rest/v1/recipe_subcategories?select=id,name,category&is_active=eq.true';
    var res = await apiFetch(url);
    if (!res || !res.ok) return;
    var rows = await res.json();
    var dupes = (rows || []).filter(function(r) {
      return r.id !== keepId &&
        rmTaxNormalizeLabel(r.category) === nCat &&
        rmTaxNormalizeLabel(r.name) === nName;
    });
    for (var i = 0; i < dupes.length; i++) {
      try {
        await rpc('admin_delete_recipe_subcategory', { p_id: dupes[i].id });
        rmTaxAudit('Sub-category Duplicate Removed', nCat + ' > ' + nName, dupes[i].id, keepId, 'Auto-deactivated duplicate after save');
      } catch (e) { /* best effort */ }
    }
  } catch (e) { /* best effort */ }
}

async function rmTaxDedupeDivision(category, subcategory, name, keepId) {
  try {
    var nCat = rmTaxNormalizeLabel(category);
    var nSub = rmTaxNormalizeLabel(subcategory);
    var nName = rmTaxNormalizeLabel(name);
    if (!nCat || !nSub || !nName || !keepId || typeof apiFetch !== 'function') return;
    var url = window.SUPA_URL + '/rest/v1/recipe_divisions?select=id,name,category,subcategory&is_active=eq.true';
    var res = await apiFetch(url);
    if (!res || !res.ok) return;
    var rows = await res.json();
    var dupes = (rows || []).filter(function(r) {
      return r.id !== keepId &&
        rmTaxNormalizeLabel(r.category) === nCat &&
        rmTaxNormalizeLabel(r.subcategory) === nSub &&
        rmTaxNormalizeLabel(r.name) === nName;
    });
    for (var i = 0; i < dupes.length; i++) {
      try {
        await rpc('admin_delete_recipe_division', { p_id: dupes[i].id });
        rmTaxAudit('Division Duplicate Removed', nCat + ' > ' + nSub + ' > ' + nName, dupes[i].id, keepId, 'Auto-deactivated duplicate after save');
      } catch (e) { /* best effort */ }
    }
  } catch (e) { /* best effort */ }
}

async function rmTaxUpsertSubcategory(payload, auditCtx) {
  var p = Object.assign({}, payload);
  p.p_category = rmTaxNormalizeLabel(p.p_category);
  p.p_name = rmTaxNormalizeLabel(p.p_name);
  if (!p.p_id && p.p_category && p.p_name) {
    var existingId = await rmTaxFindSubcategoryId(p.p_category, p.p_name);
    if (existingId) p.p_id = existingId;
  }
  function callRpc(body) {
    return rpc('admin_upsert_recipe_subcategory', body);
  }
  try {
    var id = await callRpc(p);
    await rmTaxDedupeSubcategory(p.p_category, p.p_name, id);
    if (auditCtx) {
      rmTaxAudit(
        auditCtx.action || 'Sub-category Saved',
        auditCtx.target || ((p.p_category || '') + ' > ' + (p.p_name || '')),
        auditCtx.oldVal || null,
        auditCtx.newVal || null,
        auditCtx.details || null
      );
    }
    return id;
  } catch (e) {
    var msg = String(e.message || e);
    if (/23505|duplicate key|already exists/i.test(msg) && p.p_category && p.p_name) {
      var retryId = await rmTaxFindSubcategoryId(p.p_category, p.p_name);
      if (!retryId) throw e;
      p.p_id = retryId;
      var id2 = await callRpc(p);
      await rmTaxDedupeSubcategory(p.p_category, p.p_name, id2);
      if (auditCtx) {
        rmTaxAudit(
          auditCtx.action || 'Sub-category Saved',
          auditCtx.target || ((p.p_category || '') + ' > ' + (p.p_name || '')),
          auditCtx.oldVal || null,
          auditCtx.newVal || null,
          (auditCtx.details || '') + (auditCtx.details ? ' | ' : '') + 'Reactivated archived row'
        );
      }
      return id2;
    }
    if (/function|argument|column|tagline|emoji|does not exist/i.test(msg)) {
      var id3 = await callRpc({
        p_id: p.p_id,
        p_category: p.p_category,
        p_name: p.p_name,
        p_sort_order: p.p_sort_order,
        p_ingredient_hints: p.p_ingredient_hints
      });
      await rmTaxDedupeSubcategory(p.p_category, p.p_name, id3);
      if (auditCtx) {
        rmTaxAudit(
          auditCtx.action || 'Sub-category Saved',
          auditCtx.target || ((p.p_category || '') + ' > ' + (p.p_name || '')),
          auditCtx.oldVal || null,
          auditCtx.newVal || null,
          (auditCtx.details || '') + (auditCtx.details ? ' | ' : '') + 'Legacy RPC (no copy fields)'
        );
      }
      return id3;
    }
    throw e;
  }
}

async function rmTaxUpsertDivision(payload, auditCtx) {
  var p = Object.assign({}, payload);
  p.p_category = rmTaxNormalizeLabel(p.p_category);
  p.p_subcategory = rmTaxNormalizeLabel(p.p_subcategory);
  p.p_name = rmTaxNormalizeLabel(p.p_name);
  if (!p.p_id && p.p_category && p.p_subcategory && p.p_name) {
    var existingId = await rmTaxFindDivisionId(p.p_category, p.p_subcategory, p.p_name);
    if (existingId) p.p_id = existingId;
  }
  try {
    var id = await rpc('admin_upsert_recipe_division', p);
    await rmTaxDedupeDivision(p.p_category, p.p_subcategory, p.p_name, id);
    if (auditCtx) {
      rmTaxAudit(
        auditCtx.action || 'Division Saved',
        auditCtx.target || ((p.p_category || '') + ' > ' + (p.p_subcategory || '') + ' > ' + (p.p_name || '')),
        auditCtx.oldVal || null,
        auditCtx.newVal || null,
        auditCtx.details || null
      );
    }
    return id;
  } catch (e) {
    var msg = String(e.message || e);
    if (/23505|duplicate key|already exists/i.test(msg) && p.p_category && p.p_subcategory && p.p_name) {
      var retryId = await rmTaxFindDivisionId(p.p_category, p.p_subcategory, p.p_name);
      if (!retryId) throw e;
      p.p_id = retryId;
      var id2 = await rpc('admin_upsert_recipe_division', p);
      await rmTaxDedupeDivision(p.p_category, p.p_subcategory, p.p_name, id2);
      if (auditCtx) {
        rmTaxAudit(
          auditCtx.action || 'Division Saved',
          auditCtx.target || ((p.p_category || '') + ' > ' + (p.p_subcategory || '') + ' > ' + (p.p_name || '')),
          auditCtx.oldVal || null,
          auditCtx.newVal || null,
          (auditCtx.details || '') + (auditCtx.details ? ' | ' : '') + 'Reactivated archived row'
        );
      }
      return id2;
    }
    throw e;
  }
}

function rmTaxClearTaxonomyCaches() {
  try {
    localStorage.removeItem('tcj_taxonomy_cache');
    sessionStorage.removeItem('tcj_taxonomy_session');
    Object.keys(localStorage).forEach(function(k) {
      if (k.indexOf('tcj_rm_taxonomy_') === 0) localStorage.removeItem(k);
    });
  } catch (e) { /* ignore */ }
}

function rmTaxExportTaxonomyJson(rows, catNames) {
  var byCat = {};
  (rows || []).forEach(function(r) {
    var cat = r.subcategory_category;
    if (!cat) return;
    if (!byCat[cat]) byCat[cat] = { category: cat, subcategories: {} };
    var scName = r.subcategory_name;
    if (!scName) return;
    if (!byCat[cat].subcategories[scName]) {
      byCat[cat].subcategories[scName] = {
        name: scName,
        emoji: r.subcategory_emoji || '',
        tagline: r.subcategory_tagline || '',
        description: r.subcategory_description || '',
        ingredient_hints: r.subcategory_ingredient_hints || [],
        divisions: []
      };
    }
    if (r.division_name) {
      byCat[cat].subcategories[scName].divisions.push({
        name: r.division_name,
        emoji: r.division_emoji || '',
        subtitle: r.division_subtitle || '',
        description: r.division_description || ''
      });
    }
  });
  var out = (catNames || Object.keys(byCat)).map(function(cat) {
    var node = byCat[cat] || { category: cat, subcategories: {} };
    return {
      category: cat,
      subcategories: Object.values(node.subcategories || {})
    };
  });
  var json = JSON.stringify(out, null, 2);
  var blob = new Blob([json], { type: 'application/json' });
  var url = window.URL.createObjectURL(blob);
  var a = document.createElement('a');
  a.href = url;
  a.download = 'taxonomy-' + new Date().toISOString().split('T')[0] + '.json';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  window.URL.revokeObjectURL(url);
}

function rmTaxExportTaxonomyCsv(rows) {
  var headers = ['Category', 'Sub-category', 'Division', 'Sub emoji', 'Sub tagline', 'Division subtitle'];
  var lines = [headers.map(function(h) { return '"' + h + '"'; }).join(',')];
  (rows || []).forEach(function(r) {
    if (!r.subcategory_name) return;
    lines.push([
      r.subcategory_category || '',
      r.subcategory_name || '',
      r.division_name || '',
      r.subcategory_emoji || '',
      r.subcategory_tagline || '',
      r.division_subtitle || ''
    ].map(function(c) { return '"' + String(c).replace(/"/g, '""') + '"'; }).join(','));
  });
  var blob = new Blob([lines.join('\n')], { type: 'text/csv' });
  var url = window.URL.createObjectURL(blob);
  var a = document.createElement('a');
  a.href = url;
  a.download = 'taxonomy-' + new Date().toISOString().split('T')[0] + '.csv';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  window.URL.revokeObjectURL(url);
}

function rmTaxSortSubs(subsMap) {
  return Object.values(subsMap || {}).sort(function(a, b) {
    return (a.sort_order || 0) - (b.sort_order || 0) || String(a.name).localeCompare(String(b.name));
  });
}

function adminTaxonomyRowBelongsToCategory(row, expandedCategoryName) {
  if (!row || !expandedCategoryName || !row.subcategory_name) return false;
  return String(row.subcategory_category || '').trim() === String(expandedCategoryName).trim();
}

async function loadRMTaxonomy(container) {
  rmTaxClearTaxonomyCaches();
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = [];
    var taxonomyRpcError = '';
    try {
      rows = await rpc('get_recipe_taxonomy', { p_category: null }) || [];
    } catch (rpcErr) {
      taxonomyRpcError = String(rpcErr.message || rpcErr);
      console.warn('get_recipe_taxonomy', rpcErr);
    }
    if (!taxonomyRpcError && rows.length) {
      try {
        var activeSubRes = await apiFetch(
          window.SUPA_URL + '/rest/v1/recipe_subcategories?is_active=eq.true&select=id'
        );
        if (activeSubRes && activeSubRes.ok) {
          var activeSubRows = await activeSubRes.json();
          var activeSubIds = {};
          (activeSubRows || []).forEach(function(r) { if (r.id) activeSubIds[r.id] = true; });
          if (Object.keys(activeSubIds).length) {
            var rpcBefore = rows.length;
            rows = rows.filter(function(r) {
              return !r.subcategory_id || activeSubIds[r.subcategory_id];
            });
            if (rpcBefore !== rows.length) {
              console.warn('[TCJ Taxonomy] Dropped', rpcBefore - rows.length,
                'RPC row(s) whose subcategory_id is not is_active=true in table');
            }
          }
        }
      } catch (verifyErr) {
        console.warn('[TCJ Taxonomy] active sub verify skipped', verifyErr);
      }
    }
    var rpcUniqueSubs = {};
    (rows || []).forEach(function(r) { if (r.subcategory_id) rpcUniqueSubs[r.subcategory_id] = true; });
    console.log('[TCJ Taxonomy] get_recipe_taxonomy:',
      (rows || []).length, 'row(s),', Object.keys(rpcUniqueSubs).length, 'unique sub(s)');
    if (taxonomyRpcError) {
      container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.12);border:1px solid #dc5050;border-radius:8px;font-family:DM Sans,sans-serif;font-size:13px;color:#f0a0a0;line-height:1.6">' +
        '<strong>Cannot load taxonomy.</strong> ' + esc(taxonomyRpcError) +
        '<br>Run <code>database/sql/fix-get-recipe-taxonomy-active-only.sql</code> in Supabase, then hard-refresh.</div>';
      return;
    }
    var missing = [];
    try { missing = await rpc('admin_list_recipes_missing_taxonomy', { p_limit: 50 }) || []; } catch(e) { console.warn('missing taxonomy list', e); }
    if (missing.length) { /* backfill lives in Bulk Editor tab */ }
    container.innerHTML = '';
    function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }
    // Action buttons live in the panel heading (outside the scroll area), aligned right —
    // always visible on the "Taxonomy" line without floating over the list.
    var savers = [];
    var saveAllBtn = mk('button', 'padding:7px 16px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-size:12px;font-weight:700;cursor:pointer', 'Save all changes');
    var exportJsonBtn = mk('button', 'padding:7px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-size:12px;cursor:pointer', 'Export JSON');
    var exportCsvBtn = mk('button', 'padding:7px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-size:12px;cursor:pointer', 'Export CSV');
    var toolbar = mk('div', 'display:flex;align-items:center;gap:8px;flex-wrap:wrap');
    toolbar.id = 'rm-tax-head-actions';
    toolbar.appendChild(saveAllBtn);
    toolbar.appendChild(exportJsonBtn);
    toolbar.appendChild(exportCsvBtn);

    var taxMain = (container.closest && container.closest('.admin-if-main')) || null;
    var taxHead = taxMain ? taxMain.querySelector('.admin-if-main-head') : null;
    var existingActions = document.getElementById('rm-tax-head-actions');
    if (existingActions) existingActions.remove();
    if (window._rmTaxHeadObs) { try { window._rmTaxHeadObs.disconnect(); } catch (e) {} window._rmTaxHeadObs = null; }
    if (taxHead) {
      taxHead.style.position = 'relative';
      taxHead.style.minHeight = '52px';
      toolbar.style.position = 'absolute';
      toolbar.style.right = '18px';
      toolbar.style.top = '12px';
      taxHead.appendChild(toolbar);
      var taxTitleEl = taxHead.querySelector('.admin-if-main-title');
      if (taxTitleEl && typeof MutationObserver !== 'undefined') {
        var obs = new MutationObserver(function() {
          if ((taxTitleEl.textContent || '').trim() !== 'Taxonomy') {
            var t = document.getElementById('rm-tax-head-actions');
            if (t) t.remove();
            obs.disconnect();
            if (window._rmTaxHeadObs === obs) window._rmTaxHeadObs = null;
          }
        });
        obs.observe(taxTitleEl, { childList: true, characterData: true, subtree: true });
        window._rmTaxHeadObs = obs;
      }
    } else {
      // Fallback: keep buttons at the top of the panel if the heading isn't found.
      toolbar.style.cssText += ';margin-bottom:14px';
      container.appendChild(toolbar);
    }

    exportJsonBtn.addEventListener('click', function() { rmTaxExportTaxonomyJson(rows, null); });
    exportCsvBtn.addEventListener('click', function() { rmTaxExportTaxonomyCsv(rows); });
    saveAllBtn.addEventListener('click', async function() {
      if (!savers.length) { alert('Nothing to save yet — edit a field first.'); return; }
      saveAllBtn.disabled = true;
      var normalText = 'Save all changes';
      saveAllBtn.textContent = 'Saving ' + savers.length + '\u2026';
      var ok = 0, fail = 0, firstErr = '';
      for (var i = 0; i < savers.length; i++) {
        try { await savers[i](); ok++; }
        catch (e) { fail++; if (!firstErr) firstErr = String(e.message || e); }
      }
      rmTaxAudit('Bulk Save', 'Taxonomy editor', null, null, ok + ' saved, ' + fail + ' failed');
      if (fail && firstErr) alert(fail + ' item(s) failed to save. First error: ' + firstErr);
      saveAllBtn.textContent = 'Saved ' + ok + (fail ? (' \u2022 ' + fail + ' failed') : '');
      setTimeout(function() { saveAllBtn.textContent = normalText; saveAllBtn.disabled = false; }, 1200);
      loadRMTaxonomy(container);
    });

    var note = mk('div', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.6');
    note.innerHTML = 'Browse hierarchy: <strong>Category → Sub-category → Division → Recipes</strong>. ' +
      'All rows load from <code>get_recipe_taxonomy</code> (database only). ' +
      '<br><span style="font-size:11px;color:var(--accent)">Taxonomy editor v20260629g</span> — edit freely across cards, then use <strong>Save all changes</strong> (top-right). Saving one card no longer wipes the others. Renames auto-remove duplicate rows. Every save is logged to Audit Trail.';
    container.appendChild(note);

    var movedNote = mk('div', 'margin-bottom:16px;padding:10px 12px;background:rgba(196,151,59,0.06);border:1px solid var(--border);border-radius:8px;font-size:12px;color:var(--text-mid)');
    movedNote.innerHTML = 'Recipes missing sub-category or division → use <strong>Recipe Management → Bulk Editor</strong> (backfill section at top).';
    container.appendChild(movedNote);

    var catNames = [];
    var catEmojiMap = {};
    var catFetchError = '';
    try {
      var catRows = [];
      if (typeof tcjFetchCategories === 'function') {
        catRows = await tcjFetchCategories();
      } else {
        var catUrl = window.SUPA_URL + '/rest/v1/categories?select=name,emoji,sort_order,is_active&is_active=eq.true&order=sort_order';
        var catRes = (typeof apiFetch === 'function')
          ? await apiFetch(catUrl)
          : await fetch(catUrl, {
            headers: (typeof getAuthHeaders === 'function')
              ? getAuthHeaders()
              : { apikey: window.SUPA_KEY, Accept: 'application/json' }
          });
        if (!catRes) {
          catFetchError = 'categories fetch returned no response (session expired?)';
        } else if (!catRes.ok) {
          catFetchError = 'categories ' + catRes.status + ': ' + (await catRes.text().catch(function() { return ''; }));
        } else {
          catRows = await catRes.json();
        }
      }
      (catRows || []).forEach(function(r) {
        if (!r || !r.name || r.is_active === false) return;
        var n = String(r.name).trim();
        catNames.push(n);
        catEmojiMap[n] = r.emoji || '🍽';
      });
    } catch (e) {
      catFetchError = String(e.message || e);
      console.warn('[TCJ Taxonomy] categories fetch failed', e);
    }
    if (!catNames.length && catFetchError) {
      console.warn('[TCJ Taxonomy] No categories loaded:', catFetchError);
    }
    console.log('[TCJ Taxonomy] Active categories fetched (' + catNames.length + '):', catNames.slice());
    if (catFetchError) {
      console.warn('[TCJ Taxonomy] categories fetch note:', catFetchError);
    }

    var activeCatSet = {};
    catNames.forEach(function(c) { activeCatSet[c] = true; });
    var orphanCats = {};
    (rows || []).forEach(function(r) {
      var c = String(r.subcategory_category || '').trim();
      if (c && !activeCatSet[c]) orphanCats[c] = (orphanCats[c] || 0) + 1;
    });
    if (Object.keys(orphanCats).length) {
      console.warn('[TCJ Taxonomy] Sub-categories on inactive/unknown categories (not shown):', orphanCats);
    }

    catNames.forEach(function(cat, catIdx) {
      var expandedCategoryName = cat;
      var matchedRows = rows.filter(function(r) {
        return adminTaxonomyRowBelongsToCategory(r, expandedCategoryName);
      });
      var matchedSubNames = [];
      var seenSubNames = {};
      matchedRows.forEach(function(r) {
        var sn = r.subcategory_name;
        if (sn && !seenSubNames[sn]) {
          seenSubNames[sn] = true;
          matchedSubNames.push(sn);
        }
      });
      console.log('[TCJ Taxonomy]', expandedCategoryName, '→', matchedRows.length, 'row(s),', matchedSubNames.length, 'sub(s):', matchedSubNames);

      var subs = {};
      matchedRows.forEach(function(r) {
        if (!r.subcategory_id) return;
        if (!subs[r.subcategory_id]) {
          subs[r.subcategory_id] = {
            id: r.subcategory_id,
            name: r.subcategory_name,
            sort_order: r.subcategory_sort_order || 0,
            emoji: r.subcategory_emoji || '',
            tagline: r.subcategory_tagline || '',
            description: r.subcategory_description || '',
            ingredient_hints: r.subcategory_ingredient_hints || [],
            divisions: []
          };
        }
        if (r.subcategory_ingredient_hints && r.subcategory_ingredient_hints.length) {
          subs[r.subcategory_id].ingredient_hints = r.subcategory_ingredient_hints;
        }
        if (r.subcategory_tagline) subs[r.subcategory_id].tagline = r.subcategory_tagline;
        if (r.subcategory_description) subs[r.subcategory_id].description = r.subcategory_description;
        if (r.subcategory_emoji) subs[r.subcategory_id].emoji = r.subcategory_emoji;
        if (r.division_id) {
          subs[r.subcategory_id].divisions.push({
            division_id: r.division_id,
            division_name: r.division_name,
            division_emoji: r.division_emoji,
            division_subtitle: r.division_subtitle,
            division_description: r.division_description,
            division_sort_order: r.division_sort_order || 0
          });
        }
      });
      var subList = rmTaxSortSubs(subs);
      subList.forEach(function(sc) {
        sc.divisions.sort(function(a, b) {
          return (a.division_sort_order || 0) - (b.division_sort_order || 0) ||
            String(a.division_name || '').localeCompare(String(b.division_name || ''));
        });
      });

      var catKey = 'cat:' + cat;
      var catOpen = !rmTaxCollapsed(catKey, true);
      var box = mk('div', 'margin-bottom:16px;border:1px solid var(--border);border-radius:12px;overflow:hidden');
      var catHdr = mk('div', 'display:flex;align-items:center;gap:8px;padding:12px 14px;background:rgba(255,255,255,0.04);cursor:pointer;flex-wrap:wrap');
      var catToggle = mk('span', 'font-size:12px;color:var(--text-mid);width:16px;flex-shrink:0', catOpen ? '▼' : '▶');
      var catEmoji = catEmojiMap[cat] || '🍽';
      catHdr.appendChild(catToggle);
      catHdr.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.06em;text-transform:uppercase;color:var(--accent);flex:1;min-width:160px', catEmoji + ' ' + cat));
      var catMove = mk('span', 'display:flex;gap:4px;flex-shrink:0');
      catMove.appendChild(rmTaxMoveBtn('↑', 'Move category up', catIdx === 0, function(ev) {
        ev.stopPropagation();
        if (catIdx === 0) return;
        var prev = catNames[catIdx - 1];
        Promise.all([
          rpc('admin_update_category_sort_order', { p_name: cat, p_sort_order: catIdx * 10 }),
          rpc('admin_update_category_sort_order', { p_name: prev, p_sort_order: (catIdx + 1) * 10 })
        ]).then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
      }));
      catMove.appendChild(rmTaxMoveBtn('↓', 'Move category down', catIdx === catNames.length - 1, function(ev) {
        ev.stopPropagation();
        if (catIdx >= catNames.length - 1) return;
        var next = catNames[catIdx + 1];
        Promise.all([
          rpc('admin_update_category_sort_order', { p_name: cat, p_sort_order: (catIdx + 2) * 10 }),
          rpc('admin_update_category_sort_order', { p_name: next, p_sort_order: (catIdx + 1) * 10 })
        ]).then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
      }));
      catHdr.appendChild(catMove);
      catHdr.appendChild(mk('span', 'font-size:11px;color:var(--text-mid)', subList.length + ' subs'));
      box.appendChild(catHdr);

      var catBody = mk('div', 'padding:14px;display:' + (catOpen ? 'block' : 'none'));
      catHdr.addEventListener('click', function() {
        catOpen = !catOpen;
        catBody.style.display = catOpen ? 'block' : 'none';
        catToggle.textContent = catOpen ? '▼' : '▶';
        rmTaxSetCollapsed(catKey, catOpen);
      });

      if (!subList.length) {
        catBody.appendChild(mk('div', 'font-size:12px;color:var(--text-mid);margin-bottom:10px', 'No sub-categories yet.'));
      } else {
        subList.forEach(function(sc, subIdx) {
          var subKey = catKey + '|' + sc.id;
          var subOpen = !rmTaxCollapsed(subKey, false);
          var scWrap = mk('div', 'margin-bottom:10px;border:1px solid var(--border);border-radius:8px;overflow:hidden;background:var(--bg)');

          var scHdr = mk('div', 'display:flex;align-items:center;gap:6px;padding:8px 10px;background:rgba(0,0,0,0.15);flex-wrap:wrap');
          var subToggle = mk('span', 'font-size:11px;color:var(--text-mid);cursor:pointer;width:14px', subOpen ? '▼' : '▶');
          var emojiIn = rmTaxInput(sc.emoji || '', '🍽', false);
          emojiIn.style.width = '42px';
          emojiIn.style.flex = 'none';
          emojiIn.style.textAlign = 'center';
          emojiIn.addEventListener('click', function(e) { e.stopPropagation(); });
          var nameIn = rmTaxInput(sc.name, 'Sub-category name', true);
          nameIn.addEventListener('click', function(e) { e.stopPropagation(); });
          scHdr.appendChild(subToggle);
          scHdr.appendChild(emojiIn);
          scHdr.appendChild(nameIn);
          var subMove = mk('span', 'display:flex;gap:4px;margin-left:auto');
          subMove.appendChild(rmTaxMoveBtn('↑', 'Move sub up', subIdx === 0, function(ev) {
            ev.stopPropagation();
            if (subIdx === 0) return;
            var ids = subList.map(function(s) { return s.id; }).filter(Boolean);
            if (ids.length !== subList.length) { alert('Save all subs to the database before reordering.'); return; }
            var t = ids[subIdx]; ids[subIdx] = ids[subIdx - 1]; ids[subIdx - 1] = t;
            rpc('admin_reorder_recipe_subcategories', { p_category: cat, p_ordered_ids: ids })
              .then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
          }));
          subMove.appendChild(rmTaxMoveBtn('↓', 'Move sub down', subIdx === subList.length - 1, function(ev) {
            ev.stopPropagation();
            if (subIdx >= subList.length - 1) return;
            var ids = subList.map(function(s) { return s.id; }).filter(Boolean);
            if (ids.length !== subList.length) { alert('Save all subs to the database before reordering.'); return; }
            var t = ids[subIdx]; ids[subIdx] = ids[subIdx + 1]; ids[subIdx + 1] = t;
            rpc('admin_reorder_recipe_subcategories', { p_category: cat, p_ordered_ids: ids })
              .then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
          }));
          scHdr.appendChild(subMove);
          if (sc.id) {
            var delSubHdr = mk('button', 'padding:4px 10px;font-size:11px;border:1px solid #dc5050;border-radius:6px;background:none;color:#dc5050;cursor:pointer;flex-shrink:0', 'Remove');
            delSubHdr.title = 'Deactivate this sub-category (stays out of browse after refresh)';
            delSubHdr.addEventListener('click', function(ev) {
              ev.stopPropagation();
              if (!confirm('Deactivate sub-category "' + (sc.name || '') + '" and its divisions?')) return;
              delSubHdr.disabled = true;
              rpc('admin_delete_recipe_subcategory', { p_id: sc.id })
                .then(function() {
                  rmTaxAudit('Sub-category Deactivated', cat + ' > ' + sc.name, cat + ' > ' + sc.name, null, 'Deactivated via taxonomy editor');
                  loadRMTaxonomy(container);
                })
                .catch(function(e) { alert(e.message || e); delSubHdr.disabled = false; });
            });
            scHdr.appendChild(delSubHdr);
          }
          scWrap.appendChild(scHdr);

          var scBody = mk('div', 'padding:10px 12px;display:' + (subOpen ? 'block' : 'none'));
          subToggle.addEventListener('click', function(e) {
            e.stopPropagation();
            subOpen = !subOpen;
            scBody.style.display = subOpen ? 'block' : 'none';
            subToggle.textContent = subOpen ? '▼' : '▶';
            rmTaxSetCollapsed(subKey, subOpen);
          });
          scHdr.addEventListener('click', function() {
            subOpen = !subOpen;
            scBody.style.display = subOpen ? 'block' : 'none';
            subToggle.textContent = subOpen ? '▼' : '▶';
            rmTaxSetCollapsed(subKey, subOpen);
          });

          scBody.appendChild(rmTaxLabel('Tagline (short line under the title)'));
          var taglineTa = rmTaxTextarea(sc.tagline || '', 'One-line summary for browse cards', 40);
          scBody.appendChild(taglineTa);

          scBody.appendChild(rmTaxLabel('Description'));
          var descTa = rmTaxTextarea(sc.description || '', 'Longer browse copy', 72);
          scBody.appendChild(descTa);

          scBody.appendChild(rmTaxLabel('Ingredient focus hints'));
          var hints = sc.ingredient_hints && sc.ingredient_hints.length ? sc.ingredient_hints : [];
          var hintTa = rmTaxTextarea(
            typeof formatIngredientHints === 'function' ? formatIngredientHints(hints) : (hints || []).join(', '),
            'Comma-separated — when this ingredient is the main focus, use this sub-category', 52);
          scBody.appendChild(hintTa);

          var hintActs = mk('div', 'display:flex;gap:6px;margin-top:6px;margin-bottom:8px;flex-wrap:wrap');
          var saveSub = mk('button', 'padding:6px 14px;font-size:11px;border:1px solid var(--accent);border-radius:6px;background:var(--accent);color:#fff;cursor:pointer;font-weight:600', 'Save sub-category');
          // Persist this sub-category and update in-memory state WITHOUT reloading the panel,
          // so edits in other cards are never wiped. Returns a promise (used by Save all).
          function saveSubInPlace() {
            var parsed = typeof parseIngredientHintText === 'function'
              ? parseIngredientHintText(hintTa.value)
              : hintTa.value.split(',').map(function(s) { return s.trim(); }).filter(Boolean);
            var newName = nameIn.value.trim();
            if (!newName) { return Promise.reject(new Error('Sub-category name is required.')); }
            var beforeSnap = rmTaxSnapshotSub({
              emoji: sc.emoji, tagline: sc.tagline, description: sc.description, ingredient_hints: sc.ingredient_hints
            });
            var afterSnap = rmTaxSnapshotSub({
              emoji: emojiIn.value.trim(), tagline: taglineTa.value.trim(),
              description: descTa.value.trim(), ingredient_hints: parsed
            });
            var prevName = sc.name;
            return rmTaxUpsertSubcategory({
              p_id: sc.id, p_category: cat, p_name: newName,
              p_sort_order: sc.sort_order,
              p_ingredient_hints: parsed,
              p_tagline: taglineTa.value.trim(),
              p_description: descTa.value.trim(),
              p_emoji: emojiIn.value.trim()
            }, {
              action: prevName !== newName ? 'Sub-category Renamed' : 'Sub-category Saved',
              target: cat + ' > ' + newName,
              oldVal: cat + ' > ' + prevName,
              newVal: cat + ' > ' + newName,
              details: 'Before: ' + beforeSnap + ' | After: ' + afterSnap
            }).then(function(newId) {
              if (newId) sc.id = newId;
              sc.name = newName;
              sc.emoji = emojiIn.value.trim();
              sc.tagline = taglineTa.value.trim();
              sc.description = descTa.value.trim();
              sc.ingredient_hints = parsed;
              return newId;
            });
          }
          savers.push(saveSubInPlace);
          saveSub.addEventListener('click', function() {
            saveSub.disabled = true;
            saveSubInPlace()
              .then(function() { rmTaxFlashSaved(saveSub, 'Save sub-category'); })
              .catch(function(e) { alert(e.message || e); })
              .then(function() { saveSub.disabled = false; });
          });
          hintActs.appendChild(saveSub);
          scBody.appendChild(hintActs);

          scBody.appendChild(rmTaxLabel('Divisions (techniques / styles)'));
          (sc.divisions || []).forEach(function(d, divIdx) {
            var dCard = mk('div', 'margin-bottom:8px;padding:8px 10px;border:1px solid rgba(255,255,255,0.06);border-radius:6px');
            var dTop = mk('div', 'display:flex;align-items:center;gap:6px;margin-bottom:6px;flex-wrap:wrap');
            var dEmoji = rmTaxInput(d.division_emoji || '🍽', '🍽', false);
            dEmoji.style.width = '42px'; dEmoji.style.flex = 'none'; dEmoji.style.textAlign = 'center';
            var dName = rmTaxInput(d.division_name || '', 'Division name', true);
            dTop.appendChild(dEmoji);
            dTop.appendChild(dName);
            var dMove = mk('span', 'display:flex;gap:4px;margin-left:auto');
            dMove.appendChild(rmTaxMoveBtn('↑', 'Move division up', divIdx === 0, function() {
              if (divIdx === 0) return;
              var ids = sc.divisions.map(function(x) { return x.division_id; });
              var tmp = ids[divIdx]; ids[divIdx] = ids[divIdx - 1]; ids[divIdx - 1] = tmp;
              rpc('admin_reorder_recipe_divisions', { p_category: cat, p_subcategory: sc.name, p_ordered_ids: ids })
                .then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
            }));
            dMove.appendChild(rmTaxMoveBtn('↓', 'Move division down', divIdx === sc.divisions.length - 1, function() {
              if (divIdx >= sc.divisions.length - 1) return;
              var ids = sc.divisions.map(function(x) { return x.division_id; });
              var tmp = ids[divIdx]; ids[divIdx] = ids[divIdx + 1]; ids[divIdx + 1] = tmp;
              rpc('admin_reorder_recipe_divisions', { p_category: cat, p_subcategory: sc.name, p_ordered_ids: ids })
                .then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
            }));
            dTop.appendChild(dMove);
            dCard.appendChild(dTop);
            dCard.appendChild(rmTaxLabel('Subtitle'));
            var dSub = rmTaxInput(d.division_subtitle || '', 'Short subtitle', true);
            dCard.appendChild(dSub);
            dCard.appendChild(rmTaxLabel('Description'));
            var dDesc = rmTaxTextarea(d.division_description || '', 'What recipes belong in this division?', 56);
            dCard.appendChild(dDesc);
            var dActs = mk('div', 'display:flex;gap:6px;margin-top:6px');
            var saveDiv = mk('button', 'padding:4px 10px;font-size:11px;border:1px solid var(--accent);border-radius:6px;background:none;color:var(--accent);cursor:pointer', 'Save division');
            function saveDivInPlace() {
              var nm = dName.value.trim();
              if (!nm) { return Promise.reject(new Error('Division name is required.')); }
              var subNm = nameIn.value.trim() || sc.name;
              var beforeDiv = JSON.stringify({
                emoji: d.division_emoji || '',
                subtitle: d.division_subtitle || '',
                description: d.division_description || ''
              });
              var afterDiv = JSON.stringify({
                emoji: dEmoji.value.trim() || '🍽',
                subtitle: dSub.value.trim(),
                description: dDesc.value.trim()
              });
              var prevDivName = d.division_name;
              return rmTaxUpsertDivision({
                p_id: d.division_id, p_category: cat, p_subcategory: subNm,
                p_name: nm, p_emoji: dEmoji.value.trim() || '🍽',
                p_subtitle: dSub.value.trim(), p_description: dDesc.value.trim(),
                p_tags: [], p_sort_order: d.division_sort_order || (divIdx + 1) * 10
              }, {
                action: prevDivName !== nm ? 'Division Renamed' : 'Division Saved',
                target: cat + ' > ' + subNm + ' > ' + nm,
                oldVal: cat + ' > ' + subNm + ' > ' + (prevDivName || ''),
                newVal: cat + ' > ' + subNm + ' > ' + nm,
                details: 'Before: ' + beforeDiv + ' | After: ' + afterDiv
              }).then(function(newId) {
                if (newId) d.division_id = newId;
                d.division_name = nm;
                d.division_emoji = dEmoji.value.trim() || '🍽';
                d.division_subtitle = dSub.value.trim();
                d.division_description = dDesc.value.trim();
                return newId;
              });
            }
            savers.push(saveDivInPlace);
            saveDiv.addEventListener('click', function() {
              saveDiv.disabled = true;
              saveDivInPlace()
                .then(function() { rmTaxFlashSaved(saveDiv, 'Save division'); })
                .catch(function(e) { alert(e.message || e); })
                .then(function() { saveDiv.disabled = false; });
            });
            var delD = mk('button', 'padding:4px 10px;font-size:11px;border:1px solid #dc5050;border-radius:6px;background:none;color:#dc5050;cursor:pointer', 'Remove');
            delD.addEventListener('click', function() {
              if (!confirm('Deactivate division "' + (d.division_name || '') + '"?')) return;
              rpc('admin_delete_recipe_division', { p_id: d.division_id })
                .then(function() {
                  rmTaxAudit('Division Deactivated',
                    cat + ' > ' + (nameIn.value.trim() || sc.name) + ' > ' + (d.division_name || ''),
                    cat + ' > ' + (nameIn.value.trim() || sc.name) + ' > ' + (d.division_name || ''),
                    null, 'Deactivated via taxonomy editor');
                  loadRMTaxonomy(container);
                }).catch(function(e) { alert(e.message); });
            });
            dActs.appendChild(saveDiv);
            dActs.appendChild(delD);
            dCard.appendChild(dActs);
            scBody.appendChild(dCard);
          });

          var addDiv = mk('button', 'margin-top:4px;padding:6px 12px;font-size:11px;border:1px dashed var(--border);border-radius:6px;background:none;color:var(--text-mid);cursor:pointer', '+ Add division');
          addDiv.addEventListener('click', function() {
            var subNm = nameIn.value.trim() || sc.name;
            var divName = window.prompt('Division name:', '');
            if (divName === null) return;
            divName = divName.trim();
            if (!divName) { alert('Division name is required.'); return; }
            rmTaxUpsertDivision({
              p_id: null, p_category: cat, p_subcategory: subNm,
              p_name: divName, p_emoji: '🍽', p_subtitle: '', p_description: '',
              p_tags: [], p_sort_order: ((sc.divisions || []).length + 1) * 10
            }, {
              action: 'Division Created',
              target: cat + ' > ' + subNm + ' > ' + divName,
              oldVal: null,
              newVal: cat + ' > ' + subNm + ' > ' + divName,
              details: 'New division'
            }).then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
          });
          scBody.appendChild(addDiv);
          scWrap.appendChild(scBody);
          catBody.appendChild(scWrap);
        });
      }

      var addRow = mk('div', 'display:flex;gap:8px;flex-wrap:wrap;margin-top:8px');
      var inp = mk('input', 'flex:1;min-width:140px;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-size:12px;color:var(--text-high)');
      inp.placeholder = 'New sub-category name…';
      var btn = mk('button', 'padding:8px 16px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-size:12px;cursor:pointer', 'Add sub-category');
      btn.addEventListener('click', function() {
        var v = inp.value.trim();
        if (!v) return;
        rmTaxUpsertSubcategory({
          p_id: null, p_category: cat, p_name: v,
          p_sort_order: (subList.length + 1) * 10,
          p_ingredient_hints: [], p_tagline: null, p_description: null, p_emoji: null
        }, {
          action: 'Sub-category Created',
          target: cat + ' > ' + v,
          oldVal: null,
          newVal: cat + ' > ' + v,
          details: 'New sub-category'
        }).then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
      });
      addRow.appendChild(inp);
      addRow.appendChild(btn);
      catBody.appendChild(addRow);
      box.appendChild(catBody);
      container.appendChild(box);
    });
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}
