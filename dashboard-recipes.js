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
  var hint = document.getElementById('rm-panel-hint');
  if (hint) hint.style.display = (tab === 'rmsettings') ? 'none' : 'block';
  var listPanel = document.getElementById('rmgmt-list-panel');
  var anaPanel  = document.getElementById('rmgmt-analytics-panel');
  var opsPanel  = document.getElementById('rmgmt-ops-panel');
  var setPanel  = document.getElementById('rmgmt-rmsettings-panel');
  var extPanel  = document.getElementById('rmgmt-extra-panel');
  if (listPanel) listPanel.style.display = _RM_LIST_TABS.indexOf(tab) !== -1 ? 'block' : 'none';
  if (anaPanel)  anaPanel.style.display  = tab === 'analytics' ? 'block' : 'none';
  if (opsPanel)  opsPanel.style.display  = 'none';
  if (setPanel)  setPanel.style.display  = tab === 'rmsettings' ? 'block' : 'none';
  if (extPanel)  extPanel.style.display  = _RM_SPOTLIGHT_TABS.indexOf(tab) !== -1 ? 'block' : 'none';
  if (tab === 'analytics')  { loadRecipeAnalytics(); return; }
  if (tab === 'rmsettings') { loadRMInterfaceSettings(); return; }
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

async function loadRecipeMgmt(tab) {
  var status = (tab === 'all') ? null : tab;
  var tbody  = document.getElementById('rmgmt-tbody');
  if (!tbody) return;
  _currentRecipeTab = tab;
  tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Loading\u2026</td></tr>';
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
      tr.style.cssText = 'cursor:pointer;border-bottom:1px solid rgba(255,255,255,0.04)';
      tr.addEventListener('click', (function(id){ return function(){ openRecipeModal(id); }; })(r.id));
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
        '<td class="ap-td"></td>';
      tbody.appendChild(tr);
      // Feature toggle button in last cell (DOM to avoid quote nesting)
      var lastTd = tr.lastElementChild;
      var featBtn = document.createElement('button');
      featBtn.textContent = r.featured ? '\u2b50' : '\u2606';
      featBtn.title = r.featured ? 'Unfeature' : 'Feature';
      featBtn.style.cssText = 'padding:3px 8px;background:none;border:1px solid var(--border);border-radius:5px;font-size:11px;color:var(--text-mid);cursor:pointer';
      featBtn.addEventListener('click', (function(id, featured){ return function(e){ e.stopPropagation(); toggleFeature(id, featured); }; })(r.id, r.featured));
      lastTd.appendChild(featBtn);
    });
    // Ensure thead has 8 columns
    var thead = tbody.closest('table').querySelector('thead tr');
    if (thead && thead.children.length < 8) {
      var th = document.createElement('th');
      thead.appendChild(th);
    }
    renderRmPagination();
  } catch(e) {
    tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Error: ' + esc(e.message) + '</td></tr>';
  }
}

async function openRecipeModal(id) {
  var existing = document.getElementById('rm-detail-panel');
  if (existing) existing.remove();
  var panel = document.createElement('div');
  panel.id = 'rm-detail-panel';
  panel.style.cssText = 'position:fixed;top:0;right:0;width:620px;max-width:100vw;height:100vh;background:var(--bg);border-left:1px solid var(--border);z-index:9999;overflow-y:auto;box-shadow:-8px 0 32px rgba(0,0,0,0.5)';
  panel.innerHTML = '<div style="padding:24px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  document.body.appendChild(panel);
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
    panel.appendChild(titleBlock);

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
    panel.appendChild(imgBlock);

    // Ingredients
    if (r.ingredients) {
      var ingBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
      ingBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:10px",'Ingredients'));
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
      panel.appendChild(ingBlock);
    }

    // Method — section blocks with steps (not raw JSON per section)
    if (r.method) {
      var methBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
      methBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:10px",'Procedure'));
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
      panel.appendChild(methBlock);
    }

    // Source
    if (r.source_type || r.credit_name) {
      var srcBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border)');
      srcBlock.appendChild(mk('div',"font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:8px",'Source & Credits'));
      srcBlock.innerHTML += field('Type', r.source_type);
      if (r.credit_name)   srcBlock.innerHTML += field('Credit', r.credit_name);
      if (r.credit_handle) srcBlock.innerHTML += field('Handle', '@'+r.credit_handle);
      panel.appendChild(srcBlock);
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
      panel.appendChild(iaBlock);
    }

    // Unknown ingredients — ingredients submitted that aren't in the database yet
    var unknowns = [];
    try {
      unknowns = Array.isArray(r.unknown_ingredients) ? r.unknown_ingredients
                 : (r.unknown_ingredients ? JSON.parse(r.unknown_ingredients) : []);
    } catch(e) { console.warn('unknown ingredients parse', e); }
    if (unknowns.length) {
      var uBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(212,160,23,0.05);border-left:3px solid #d4a017');
      uBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#d4a017;margin-bottom:10px",'⚠ New Ingredients Not Yet in Database'));
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
      panel.appendChild(uBlock);
    }

    // Unknown utensils — tools not yet in the Tools & Appliances library
    var unknownTools = [];
    try {
      unknownTools = Array.isArray(r.unknown_utensils) ? r.unknown_utensils
        : (r.unknown_utensils ? JSON.parse(r.unknown_utensils) : []);
    } catch(e) { console.warn('unknown utensils parse', e); }
    if (unknownTools.length) {
      var tBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(212,160,23,0.05);border-left:3px solid #d4a017');
      tBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#d4a017;margin-bottom:10px",'⚠ New Tools Not Yet in Library'));
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
      panel.appendChild(tBlock);
    }

    // Suggested taxonomy — sub-categories / divisions not yet in the database
    var taxSug = [];
    try {
      taxSug = Array.isArray(r.taxonomy_suggestions) ? r.taxonomy_suggestions
        : (r.taxonomy_suggestions ? JSON.parse(r.taxonomy_suggestions) : []);
    } catch(e) { console.warn('taxonomy suggestions parse', e); }
    if (taxSug.length) {
      var tBlock = mk('div','padding:16px 20px;border-bottom:1px solid var(--border);background:rgba(212,160,23,0.05);border-left:3px solid #d4a017');
      tBlock.appendChild(mk('div',"font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;color:#d4a017;margin-bottom:10px",'⚠ Suggested Taxonomy Not Yet in Database'));
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
            p = rpc('admin_upsert_recipe_subcategory', { p_id: null, p_category: s.category, p_name: s.value, p_sort_order: 99 });
          } else if (s.field === 'division') {
            if (!s.sub_category) {
              alert('Add the sub-category first (or use Sub-cats & Divisions tab), then add this division.');
              btn.disabled = false;
              btn.textContent = '+ Add to Taxonomy';
              return;
            }
            p = rpc('admin_upsert_recipe_division', {
              p_id: null, p_category: s.category, p_subcategory: s.sub_category, p_name: s.value,
              p_emoji: '🍽', p_subtitle: '', p_description: null, p_tags: [], p_sort_order: 99
            });
          } else {
            btn.disabled = false;
            btn.textContent = '+ Add to Taxonomy';
            return;
          }
          p.then(function() {
            btn.textContent = '✓ Added';
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
      panel.appendChild(tBlock);
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
    getCats().forEach(function(c) { var o = document.createElement('option'); o.value = c; o.textContent = c; catSel.appendChild(o); });
    catWrap.appendChild(catSel);
    if (r.category) {
      catSel.value = String(r.category).trim();
      if (!catSel.value && getCats().indexOf(r.category) < 0) {
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
    var locWrap = editField('Origin locality (village/area)', 'rm-edit-locality', r.origin_locality, 'text');
    var stateWrap = editField('Origin state/region', 'rm-edit-state', r.origin_state, 'text');
    var countryWrap = editField('Origin country', 'rm-edit-country', r.origin_country, 'text');
    editGrid.appendChild(nameWrap); editGrid.appendChild(nativeWrap);
    editGrid.appendChild(catWrap);  editGrid.appendChild(spiceWrap);
    editGrid.appendChild(locWrap); editGrid.appendChild(stateWrap);
    editGrid.appendChild(countryWrap);
    editBlock.appendChild(editGrid);
    var saveEditBtn = mk('button','margin-top:10px;padding:6px 16px;background:none;border:1px solid var(--accent);border-radius:7px;color:var(--accent);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer','Save Edits');
    saveEditBtn.addEventListener('click', function(){ saveRecipeEdits(r.id); });
    var editMsg = mk('span','margin-left:10px;font-family:DM Sans,sans-serif;font-size:11px;color:#4caf76','');
    editMsg.id = 'rm-edit-msg';
    editBlock.appendChild(saveEditBtn); editBlock.appendChild(editMsg);
    panel.appendChild(editBlock);

    // Review actions
    var reviewBlock = mk('div','padding:16px 20px');
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

async function toggleFeature(id, currentFeatured) {
  try {
    await rpc('admin_feature_recipe', {p_id: id, p_featured: !currentFeatured});
    auditLog('Recipe Management', currentFeatured ? 'Recipe Unfeatured' : 'Recipe Featured', null, id, String(!currentFeatured), null);
    loadRecipeMgmt(_currentRecipeTab);
  } catch(e) { alert('Error: ' + e.message); }
}

function closeRecipeModal() {
  var el = document.getElementById('rm-detail-panel');
  if (el) el.remove();
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
    await rpc('admin_review_recipe', {p_id: id, p_status: status, p_notes: combined || null});
    auditLog('Recipe Management', 'Recipe ' + status.charAt(0).toUpperCase() + status.slice(1), null, id, status, combined || null);
    if (msg) {
      msg.style.color = status === 'approved' ? '#4caf76' : status === 'rejected' ? '#dc5050' : 'var(--text-mid)';
      msg.textContent = status === 'approved' ? '\u2713 Approved!' : status === 'rejected' ? '\u2715 Rejected' : '\u21ba Reset to Pending';
    }
    setTimeout(function(){
      closeRecipeModal();
      loadRecipeMgmt(_currentRecipeTab);
    }, 1000);
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
  var locality = (document.getElementById('rm-edit-locality') || {}).value || '';
  var state   = (document.getElementById('rm-edit-state')   || {}).value || '';
  var country = (document.getElementById('rm-edit-country') || {}).value || '';
  var msg    = document.getElementById('rm-edit-msg');
  try {
    await rpc('admin_edit_recipe', {
      p_id: id, p_recipe_name: name || null, p_category: cat || null,
      p_spice_level: spice || null, p_native_title: native || null,
      p_introduction: null, p_cooking_notes: null, p_servings: null,
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
  if (!el) return;
  if (el.dataset.shellBuilt === '1') {
    var stored = localStorage.getItem('tcj_rm_interface_tab') || 'settings';
    var btn = el.querySelector('[data-admin-if-tab="' + stored + '"]');
    if (btn) btn.click();
    return;
  }
  el.innerHTML = '';
  el.dataset.shellBuilt = '1';
  if (typeof AdminTabNav === 'undefined') {
    el.textContent = 'Admin tab navigation failed to load.';
    return;
  }
  el.appendChild(AdminTabNav.interfaceBanner('Configuration and reference data — work queues stay in the tabs above. Slugs and rejection reasons are admin-only.'));
  el.appendChild(AdminTabNav.interfaceIntro('Taxonomy, collections, nutrition queue, print queue, and audit trail live here — same pattern as IM Interface reference data.'));

  function mk(tag, style, text) { var e = document.createElement(tag); if (style) e.style.cssText = style; if (text !== undefined) e.textContent = text; return e; }
  function card(title) {
    var d = mk('div', 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
    d.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px", title));
    return d;
  }

  var shell = AdminTabNav.buildInnerTabBar(el, [
    { key: 'settings', label: 'Settings' },
    { key: 'taxonomy', label: 'Taxonomy' },
    { key: 'sourcelinks', label: 'Source Links' },
    { key: 'nutrition', label: 'Nutrition' },
    { key: 'printqueue', label: 'Print Queue' },
    { key: 'collections', label: 'Collections' },
    { key: 'audit', label: 'Audit Trail' }
  ], 'tcj_rm_interface_tab', 'settings', function (key, panel) {
    if (key === 'settings') return;
    loadRMTab(key, panel);
  });

  var settingsPanel = shell.panels.settings;
  var rejCard = card('Rejection Reasons');
  rejCard.appendChild(mk('p', 'font-size:11px;color:var(--text-mid);margin-bottom:10px', 'One reason per line. Used in the recipe review panel when rejecting submissions.'));
  var rejTa = mk('textarea', 'width:100%;box-sizing:border-box;min-height:140px;padding:10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);resize:vertical');
  rejTa.value = getRejectReasons().join('\n');
  rejCard.appendChild(rejTa);
  var rejBtn = mk('button', "margin-top:10px;padding:8px 18px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:'DM Sans',sans-serif;font-size:12px;cursor:pointer", 'Save Reasons');
  rejBtn.addEventListener('click', function() {
    var lines = rejTa.value.split('\n').map(function(s){ return s.trim(); }).filter(Boolean);
    if (!lines.length) { alert('Add at least one reason.'); return; }
    localStorage.setItem('tcj_rm_reject_reasons', JSON.stringify(lines));
    rejBtn.textContent = '\u2713 Saved';
    setTimeout(function(){ rejBtn.textContent = 'Save Reasons'; }, 2000);
    auditLog('RM Interface', 'Rejection Reasons Updated', null, null, null, lines.length + ' reasons');
  });
  rejCard.appendChild(rejBtn);
  settingsPanel.appendChild(rejCard);

  var smCard = card('Site Management Shortcuts');
  var smGrid = mk('div', 'display:flex;flex-wrap:wrap;gap:10px');
  [
    { label: 'Pages & visibility', tab: 'sm-pages' },
    { label: 'Feature toggles', tab: 'sm-features' },
    { label: 'Billing & refund copy', smTab: 'sm-interface', sub: 'settings' }
  ].forEach(function(link) {
    var b = mk('button', "padding:8px 16px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--accent);font-family:'DM Sans',sans-serif;font-size:12px;cursor:pointer", link.label + ' \u2192');
    b.addEventListener('click', function() {
      if (link.smTab) {
        localStorage.setItem('tcj_sm_interface_tab', link.sub || 'settings');
        switchView('site-mgmt');
        switchSMTab('sm-interface');
      } else {
        switchView('site-mgmt');
        switchSMTab(link.tab);
      }
    });
    smGrid.appendChild(b);
  });
  smCard.appendChild(smGrid);
  settingsPanel.appendChild(smCard);

  shell.activate(shell.activeKey);
}

function loadRMTab(key, container) {
  if (!container) return;
  if (key === 'analytics')   loadRMAnalytics(container);
  else if (key === 'taxonomy')    loadRMTaxonomy(container);
  else if (key === 'collections') loadRMCollections(container);
  else if (key === 'featured')    loadRMFeatured(container);
  else if (key === 'sourcelinks') loadRMSourceLinks(container);
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



// ── USER MANAGEMENT ───────────────────────────────────────────────
// ── USER MANAGEMENT ──────────────────────────────────────────────
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

// ── Categories + Sub Categories Export ───────────────────────────

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


// ═══════════════════════════════════════════════════════════════
// FM INTERFACE (Finance Management > FM Interface tab)
// ═══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════
// Recipe of the Week + Cooking Notes Approval
// ══════════════════════════════════════════════════════════════════════

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
        (isRotw(r)?'⭐ Current':'Set as ROTW') + '</button>' +
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

// ── Cooking Tips / Notes Approval ─────────────────────────────────────
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

async function loadRMTaxonomy(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  var CATS = ['Rise & Shine','The Evening Table','Garden & Earth','Meat & Fire','Ocean & River',
    'Slow & Soulful','Grains & Comfort','Breads & Bakes','Sweet Serenades','Sips & Stories',
    'Preserved & Cherished','Feast Days','Little Ones','Nourish & Heal'];
  try {
    var rows = await rpc('get_recipe_taxonomy', { p_category: null }) || [];
    var missing = [];
    try { missing = await rpc('admin_list_recipes_missing_taxonomy', { p_limit: 50 }) || []; } catch(e) { console.warn('missing taxonomy list', e); }
    container.innerHTML = '';
    function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }
    var note = mk('div', 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.6');
    note.textContent = 'Manage sub-categories and divisions for recipe browse and submit. Divisions support emoji, subtitle, description and tags.';
    container.appendChild(note);

    if (missing.length) {
      var bulk = mk('div', 'margin-bottom:24px;padding:16px;background:rgba(196,151,59,0.08);border:1px solid var(--accent);border-radius:12px');
      bulk.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:var(--accent);margin-bottom:8px', 'Bulk backfill — missing taxonomy'));
      bulk.appendChild(mk('div', 'font-size:12px;color:var(--text-mid);margin-bottom:12px;line-height:1.5', missing.length + ' approved recipe(s) lack sub-category or division. Select rows, pick taxonomy, then apply.'));
      var tbl = mk('table', 'width:100%;border-collapse:collapse;font-size:12px;margin-bottom:12px');
      tbl.innerHTML = '<thead><tr style="text-align:left;color:var(--text-mid)"><th style="padding:6px 8px;width:28px"></th><th style="padding:6px 8px">Recipe</th><th style="padding:6px 8px">Category</th><th style="padding:6px 8px">Current</th></tr></thead>';
      var tbody = mk('tbody');
      missing.forEach(function(m) {
        var tr = mk('tr');
        tr.style.borderTop = '1px solid rgba(255,255,255,0.06)';
        var td0 = mk('td'); td0.style.padding = '6px 8px';
        var cb = mk('input'); cb.type = 'checkbox'; cb.className = 'rm-tax-bulk-cb'; cb.value = m.id; cb.dataset.category = m.category || '';
        td0.appendChild(cb);
        tr.appendChild(td0);
        tr.appendChild(mk('td', 'padding:6px 8px;color:var(--text-high)', m.recipe_name || ''));
        tr.appendChild(mk('td', 'padding:6px 8px;color:var(--text-mid)', m.category || ''));
        var cur = (m.sub_category || '—') + ' · ' + (m.division || '—');
        tr.appendChild(mk('td', 'padding:6px 8px;color:var(--text-mid)', cur));
        tbody.appendChild(tr);
      });
      tbl.appendChild(tbody);
      bulk.appendChild(tbl);
      var bulkRow = mk('div', 'display:flex;flex-wrap:wrap;gap:8px;align-items:center');
      var catSel = mk('select', 'padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-size:12px;color:var(--text-high)');
      catSel.innerHTML = '<option value="">Category filter…</option>' + CATS.map(function(c){ return '<option value="'+esc(c)+'">'+esc(c)+'</option>'; }).join('');
      var subSel = mk('select', 'padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-size:12px;color:var(--text-high);min-width:140px');
      subSel.innerHTML = '<option value="">Sub-category…</option>';
      var divSel = mk('select', 'padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-size:12px;color:var(--text-high);min-width:140px');
      divSel.innerHTML = '<option value="">Division…</option>';
      function fillSubs(cat) {
        subSel.innerHTML = '<option value="">Sub-category…</option>';
        divSel.innerHTML = '<option value="">Division…</option>';
        var subs = {};
        rows.filter(function(r) { return !cat || r.subcategory_category === cat; }).forEach(function(r) {
          if (!r.subcategory_id || !r.subcategory_name) return;
          if (!subs[r.subcategory_name]) subs[r.subcategory_name] = [];
          if (r.division_name) subs[r.subcategory_name].push(r.division_name);
        });
        Object.keys(subs).sort().forEach(function(name) {
          var o = document.createElement('option');
          o.value = name; o.textContent = name;
          subSel.appendChild(o);
        });
      }
      function fillDivs(sub) {
        divSel.innerHTML = '<option value="">Division…</option>';
        var cat = catSel.value;
        rows.filter(function(r) {
          return r.subcategory_name === sub && (!cat || r.subcategory_category === cat);
        }).forEach(function(r) {
          if (!r.division_name) return;
          var o = document.createElement('option');
          o.value = r.division_name;
          o.textContent = (r.division_emoji || '') + ' ' + r.division_name;
          divSel.appendChild(o);
        });
      }
      catSel.addEventListener('change', function() { fillSubs(catSel.value); });
      subSel.addEventListener('change', function() { fillDivs(subSel.value); });
      fillSubs('');
      var applyBtn = mk('button', 'padding:8px 16px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-size:12px;cursor:pointer', 'Apply to selected');
      applyBtn.addEventListener('click', function() {
        var ids = [].map.call(container.querySelectorAll('.rm-tax-bulk-cb:checked'), function(cb) { return cb.value; });
        if (!ids.length) { alert('Select at least one recipe.'); return; }
        var sub = subSel.value.trim();
        var div = divSel.value.trim();
        if (!sub && !div) { alert('Choose a sub-category and/or division.'); return; }
        rpc('admin_bulk_set_recipe_taxonomy', { p_recipe_ids: ids, p_sub_category: sub || null, p_division: div || null })
          .then(function(n) { alert('Updated ' + (n || 0) + ' recipe(s).'); loadRMTaxonomy(container); })
          .catch(function(e) { alert(e.message); });
      });
      bulkRow.appendChild(catSel);
      bulkRow.appendChild(subSel);
      bulkRow.appendChild(divSel);
      bulkRow.appendChild(applyBtn);
      bulk.appendChild(bulkRow);
      container.appendChild(bulk);
    }

    CATS.forEach(function(cat) {
      var subs = {};
      rows.filter(function(r) { return r.subcategory_category === cat; }).forEach(function(r) {
        if (!r.subcategory_id) return;
        if (!subs[r.subcategory_id]) subs[r.subcategory_id] = { id: r.subcategory_id, name: r.subcategory_name, divisions: [] };
        if (r.division_id) subs[r.subcategory_id].divisions.push(r);
      });
      var subList = Object.values(subs);
      var box = mk('div', 'margin-bottom:20px;padding:16px;background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:12px');
      box.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:var(--accent);margin-bottom:10px', cat));

      if (!subList.length) {
        box.appendChild(mk('div', 'font-size:12px;color:var(--text-mid);margin-bottom:10px', 'No sub-categories yet.'));
      } else {
        subList.forEach(function(sc) {
          var scRow = mk('div', 'margin-bottom:12px;padding:10px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px');
          scRow.appendChild(mk('div', 'font-size:13px;font-weight:600;color:var(--text-high);margin-bottom:6px', sc.name));
          (sc.divisions || []).forEach(function(d) {
            var dRow = mk('div', 'display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:12px;color:var(--text-mid);padding:6px 0;border-top:1px solid rgba(255,255,255,0.04)');
            var dLabel = mk('span', '', (d.division_emoji || '') + ' ' + (d.division_name || '') + (d.division_subtitle ? ' — ' + d.division_subtitle : ''));
            dRow.appendChild(dLabel);
            var dActs = mk('span', 'display:flex;gap:4px;flex-shrink:0');
            var editD = mk('button', 'padding:2px 8px;font-size:10px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--text-mid);cursor:pointer', 'Edit');
            editD.addEventListener('click', function() {
              var name = prompt('Division name:', d.division_name || '');
              if (!name || !name.trim()) return;
              var emoji = prompt('Emoji:', d.division_emoji || '🍽') || '🍽';
              var subtitle = prompt('Subtitle:', d.division_subtitle || '') || '';
              rpc('admin_upsert_recipe_division', {
                p_id: d.division_id, p_category: cat, p_subcategory: sc.name, p_name: name.trim(),
                p_emoji: emoji, p_subtitle: subtitle, p_description: d.division_description || null,
                p_tags: d.division_tags || [], p_sort_order: d.division_sort_order || 0
              }).then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
            });
            var delD = mk('button', 'padding:2px 8px;font-size:10px;border:1px solid #dc5050;border-radius:5px;background:none;color:#dc5050;cursor:pointer', 'Remove');
            delD.addEventListener('click', function() {
              if (!confirm('Deactivate division "' + (d.division_name || '') + '"?')) return;
              rpc('admin_delete_recipe_division', { p_id: d.division_id })
                .then(function() { loadRMTaxonomy(container); })
                .catch(function(e) { alert(e.message); });
            });
            dActs.appendChild(editD);
            dActs.appendChild(delD);
            dRow.appendChild(dActs);
            scRow.appendChild(dRow);
          });
          var addDiv = mk('button', 'margin-top:6px;padding:4px 10px;font-size:11px;border:1px solid var(--border);border-radius:6px;background:none;color:var(--text-mid);cursor:pointer');
          addDiv.textContent = '+ Division';
          addDiv.addEventListener('click', function() {
            var name = prompt('Division name for ' + sc.name + ':');
            if (!name || !name.trim()) return;
            var emoji = prompt('Emoji (optional):', '🍽') || '🍽';
            var subtitle = prompt('Subtitle (optional):', '') || '';
            rpc('admin_upsert_recipe_division', {
              p_id: null, p_category: cat, p_subcategory: sc.name, p_name: name.trim(),
              p_emoji: emoji, p_subtitle: subtitle, p_description: null, p_tags: [], p_sort_order: (sc.divisions || []).length + 1
            }).then(function() { loadRMTaxonomy(container); }).catch(function(e) { alert(e.message); });
          });
          scRow.appendChild(addDiv);
          box.appendChild(scRow);
        });
      }

      var addRow = mk('div', 'display:flex;gap:8px;flex-wrap:wrap;margin-top:8px');
      var inp = mk('input', 'flex:1;min-width:140px;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-size:12px;color:var(--text-high)');
      inp.placeholder = 'New sub-category…';
      var btn = mk('button', 'padding:8px 16px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-size:12px;cursor:pointer', 'Add');
      btn.addEventListener('click', function() {
        var v = inp.value.trim();
        if (!v) return;
        rpc('admin_upsert_recipe_subcategory', { p_id: null, p_category: cat, p_name: v, p_sort_order: subList.length + 1 })
          .then(function() { loadRMTaxonomy(container); })
          .catch(function(e) { alert(e.message); });
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
