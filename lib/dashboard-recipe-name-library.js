// Dish Index — canonical dish metadata before ingredients + method.
// Requires dashboard-recipes.js/dashboard-shared.js helpers: rpc(), esc().
window.recipeNameLibrary = (function() {
  var _rows = [];
  var _total = 0;
  var _page = 1;
  var _PAGE_SIZE = 50;
  var _sort = { column: 'recipe_name', direction: 'asc' };
  var _selected = new Set();
  var _cats = [];
  var _taxRows = [];
  var _bound = false;
  var _editRow = null;
  var _SHELL_VERSION = '20260702d';
  var _IMPORT_CHUNK = 100;
  var _SCHEMA_VERSION = '20260702';
  var _QUEUE_STORAGE = 'tcj_dish_index_active_queue';

  var _QUEUE_PRESETS = [
    { id: 'all', label: 'All dishes' },
    { id: 'ready-unlinked', label: 'Ready · unlinked' },
    { id: 'needs-research', label: 'Needs research' },
    { id: 'verified-unlinked', label: 'Verified · unlinked' },
    { id: 'linked-drift', label: 'Linked · drift' },
    { id: 'archived', label: 'Archived' }
  ];

  var _RESEARCH = ['idea_only', 'needs_research', 'ready_to_draft', 'verified'];
  var _CONTENT = ['not_started', 'draft_created', 'linked', 'approved', 'duplicate', 'retired'];
  var _SOURCE_TYPES = ['Original', 'Adapted', 'Inspired by', 'Traditional', 'Family recipe'];
  var _DIFFICULTY = ['', 'Easy', 'Medium', 'Hard', 'Expert'];
  var _SPICE = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot'];
  var _SWEET = ['Not Applicable', 'Lightly sweet', 'Medium sweet', 'Very sweet'];

  var _TABLE_COLS = [
    { key: 'select', label: '', fixed: true },
    { key: 'dish_code', label: 'DI#', readonly: true },
    { key: 'recipe_name', label: 'Recipe Name', required: true },
    { key: 'native_name', label: 'Native' },
    { key: 'category', label: 'Category', select: true },
    { key: 'sub_category', label: 'Sub-category', select: true },
    { key: 'division', label: 'Division', select: true },
    { key: 'origin_country', label: 'Country' },
    { key: 'research_status', label: 'Research', select: true },
    { key: 'content_status', label: 'Content', select: true },
    { key: 'linked_recipe_name', label: 'Linked Recipe', readonly: true },
    { key: 'actions', label: 'Actions', fixed: true }
  ];

  var _ARRAY_FIELDS = [
    'alternate_names', 'primary_ingredients', 'dietary_tags', 'meal_type_tags',
    'occasion_tags', 'style_tags', 'health_tags', 'flavor_profile_tags', 'equipment'
  ];

  var _TEXT_FIELDS = [
    'id', 'dish_code', 'recipe_name', 'native_name', 'category', 'sub_category', 'division',
    'origin_continent', 'origin_country', 'origin_state', 'origin_locality',
    'introduction', 'description', 'image_url', 'image_source_url',
    'prep_time_minutes', 'cook_time_minutes', 'additional_time_minutes',
    'servings', 'servings_unit', 'difficulty', 'spice_level', 'sweet_level', 'cooking_style',
    'cooking_notes', 'shelf_life_value', 'shelf_life_unit', 'shelf_life_storage',
    'after_open_value', 'after_open_unit',
    'source_type', 'credit_name', 'credit_handle', 'credit_url', 'source_url', 'source_notes',
    'research_status', 'content_status', 'linked_recipe_id', 'notes'
  ];

  var _CSV_HEADERS = [
    'Schema Version', 'Dish Code', 'ID', 'Recipe Name', 'Native Name', 'Alternate Names', 'Category', 'Sub-category', 'Division',
    'Continent', 'Country', 'State', 'Locality', 'Primary Ingredients',
    'Dietary Tags', 'Health Tags', 'Meal Type Tags', 'Occasion Tags', 'Style Tags', 'Flavor Profile Tags',
    'Introduction', 'Description', 'Image URL', 'Image Source URL',
    'Prep Time Minutes', 'Cook Time Minutes', 'Additional Time Minutes',
    'Servings', 'Servings Unit', 'Difficulty', 'Spice Level', 'Sweet Level', 'Cooking Style',
    'Equipment', 'Cooking Notes',
    'Shelf Life Value', 'Shelf Life Unit', 'Shelf Life Storage', 'After Open Value', 'After Open Unit',
    'Source Type', 'Credit Name', 'Credit Handle', 'Credit URL', 'Source URL', 'Source Notes',
    'Research Status', 'Content Status', 'Linked Recipe ID', 'Linked Recipe', 'Active', 'Notes'
  ];

  var _EDITOR_GROUPS = [
    { title: 'Identity', fields: [
      { key: 'recipe_name', label: 'Recipe Name', required: true },
      { key: 'native_name', label: 'Native Name' },
      { key: 'alternate_names', label: 'Alternate Names', array: true, hint: 'Semicolon-separated' }
    ]},
    { title: 'Taxonomy', fields: [
      { key: 'category', label: 'Category', taxonomy: 'category' },
      { key: 'sub_category', label: 'Sub-category', taxonomy: 'sub' },
      { key: 'division', label: 'Division', taxonomy: 'div' }
    ]},
    { title: 'Origin', fields: [
      { key: 'origin_continent', label: 'Continent' },
      { key: 'origin_country', label: 'Country' },
      { key: 'origin_state', label: 'State / Province' },
      { key: 'origin_locality', label: 'Locality' }
    ]},
    { title: 'Story & Media', fields: [
      { key: 'introduction', label: 'Introduction', textarea: true },
      { key: 'description', label: 'Description', textarea: true },
      { key: 'image_url', label: 'Image URL' },
      { key: 'image_source_url', label: 'Image Source URL', hint: 'Original upload URL for crop reference' }
    ]},
    { title: 'Times & Yield', fields: [
      { key: 'prep_time_minutes', label: 'Prep (minutes)', number: true },
      { key: 'cook_time_minutes', label: 'Cook (minutes)', number: true },
      { key: 'additional_time_minutes', label: 'Additional (minutes)', number: true },
      { key: 'servings', label: 'Servings', number: true },
      { key: 'servings_unit', label: 'Servings Unit' },
      { key: 'difficulty', label: 'Difficulty', select: _DIFFICULTY },
      { key: 'spice_level', label: 'Spice Level', select: _SPICE },
      { key: 'sweet_level', label: 'Sweet Level', select: _SWEET },
      { key: 'cooking_style', label: 'Cooking Style' }
    ]},
    { title: 'Tags & Focus', fields: [
      { key: 'primary_ingredients', label: 'Primary Ingredients', array: true, hint: 'Planning hints only — not full recipe ingredients' },
      { key: 'dietary_tags', label: 'Dietary Tags', array: true },
      { key: 'health_tags', label: 'Health Tags', array: true },
      { key: 'meal_type_tags', label: 'Meal Type Tags', array: true },
      { key: 'occasion_tags', label: 'Occasion Tags', array: true },
      { key: 'style_tags', label: 'Style Tags', array: true },
      { key: 'flavor_profile_tags', label: 'Flavor Profile Tags', array: true }
    ]},
    { title: 'Keeping & Equipment', fields: [
      { key: 'equipment', label: 'Equipment', array: true },
      { key: 'cooking_notes', label: 'Cooking Notes', textarea: true },
      { key: 'shelf_life_value', label: 'Shelf Life Value' },
      { key: 'shelf_life_unit', label: 'Shelf Life Unit' },
      { key: 'shelf_life_storage', label: 'Shelf Life Storage' },
      { key: 'after_open_value', label: 'After Open Value' },
      { key: 'after_open_unit', label: 'After Open Unit' }
    ]},
    { title: 'Source & Credit', fields: [
      { key: 'source_type', label: 'Source Type', select: _SOURCE_TYPES },
      { key: 'credit_name', label: 'Credit Name' },
      { key: 'credit_handle', label: 'Credit Handle' },
      { key: 'credit_url', label: 'Credit URL' },
      { key: 'source_url', label: 'Source URL' },
      { key: 'source_notes', label: 'Source Notes', textarea: true }
    ]},
    { title: 'Workflow', fields: [
      { key: 'research_status', label: 'Research Status', select: _RESEARCH },
      { key: 'content_status', label: 'Content Status', select: _CONTENT },
      { key: 'notes', label: 'Admin Notes', textarea: true }
    ]}
  ];

  function h(s) {
    return (typeof esc === 'function') ? esc(s) : String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
    });
  }
  function arrText(v) { return Array.isArray(v) ? v.join('; ') : (v || ''); }
  function splitList(v) {
    return String(v || '').split(/[;,]/).map(function(s) { return s.trim(); }).filter(Boolean);
  }
  function csvCell(v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; }

  function parseCsv(text) {
    var rows = [], row = [], cell = '', q = false;
    for (var i = 0; i < text.length; i++) {
      var ch = text[i], nx = text[i + 1];
      if (q) {
        if (ch === '"' && nx === '"') { cell += '"'; i++; }
        else if (ch === '"') q = false;
        else cell += ch;
      } else {
        if (ch === '"') q = true;
        else if (ch === ',') { row.push(cell); cell = ''; }
        else if (ch === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; }
        else if (ch !== '\r') cell += ch;
      }
    }
    row.push(cell);
    if (row.length > 1 || row[0]) rows.push(row);
    return rows;
  }

  function rowToPayload(r) {
    var out = {};
    _TEXT_FIELDS.forEach(function(k) { out[k] = r[k] == null ? '' : r[k]; });
    _ARRAY_FIELDS.forEach(function(k) {
      out[k] = Array.isArray(r[k]) ? r[k] : splitList(r[k]);
    });
    return out;
  }

  function listFilters() {
    return {
      p_search: (document.getElementById('rnl-search') || {}).value || null,
      p_research_status: (document.getElementById('rnl-research-filter') || {}).value || null,
      p_content_status: (document.getElementById('rnl-content-filter') || {}).value || null,
      p_linked: (document.getElementById('rnl-linked-filter') || {}).value || null,
      p_category: (document.getElementById('rnl-category-filter') || {}).value || null,
      p_sub_category: (document.getElementById('rnl-sub-filter') || {}).value || null,
      p_division: (document.getElementById('rnl-div-filter') || {}).value || null,
      p_include_archived: (document.getElementById('rnl-archived-filter') || {}).checked || false,
      p_drift: (document.getElementById('rnl-drift-filter') || {}).value || null,
      p_sort_col: _sort.column,
      p_sort_dir: _sort.direction
    };
  }

  function clearQueueFilters() {
    ['rnl-search', 'rnl-research-filter', 'rnl-content-filter', 'rnl-linked-filter', 'rnl-category-filter', 'rnl-sub-filter', 'rnl-div-filter', 'rnl-drift-filter'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.value = '';
    });
    var arch = document.getElementById('rnl-archived-filter');
    if (arch) arch.checked = false;
    _page = 1;
  }

  function applyQueuePreset(id, doLoad) {
    clearQueueFilters();
    if (id === 'ready-unlinked') {
      setSel('rnl-research-filter', 'ready_to_draft');
      setSel('rnl-linked-filter', 'unlinked');
    } else if (id === 'needs-research') {
      setSel('rnl-research-filter', 'needs_research');
    } else if (id === 'verified-unlinked') {
      setSel('rnl-research-filter', 'verified');
      setSel('rnl-linked-filter', 'unlinked');
    } else if (id === 'linked-drift') {
      setSel('rnl-linked-filter', 'linked');
      setSel('rnl-drift-filter', 'yes');
    } else if (id === 'archived') {
      var arch = document.getElementById('rnl-archived-filter');
      if (arch) arch.checked = true;
    }
    try { localStorage.setItem(_QUEUE_STORAGE, id); } catch (_) {}
    document.querySelectorAll('.rnl-queue-pill').forEach(function(btn) {
      btn.classList.toggle('active', btn.dataset.queue === id);
    });
    if (doLoad !== false) loadRows();
  }

  function setSel(id, val) {
    var el = document.getElementById(id);
    if (el) el.value = val;
  }

  function updateBulkToolbar() {
    var bar = document.getElementById('rnl-bulk-bar');
    var countEl = document.getElementById('rnl-bulk-count');
    if (!bar) return;
    var n = _selected.size;
    bar.style.display = n ? 'flex' : 'none';
    if (countEl) countEl.textContent = n + ' selected';
  }

  function selectedIds() {
    return Array.from(_selected);
  }

  async function fetchAllRows() {
    var all = [], offset = 0, limit = 500, total = 0;
    var filters = listFilters();
    do {
      var result = await rpc('admin_list_recipe_name_library', Object.assign({}, filters, {
        p_limit: limit,
        p_offset: offset
      }));
      var rows = (result && result.rows) || [];
      total = parseInt(result && result.total, 10) || rows.length;
      all = all.concat(rows);
      offset += limit;
    } while (all.length < total && offset < 50000);
    return all;
  }

  async function loadCatsAndTaxonomy() {
    try {
      var cats = typeof tcjFetchCategories === 'function' ? await tcjFetchCategories() : [];
      _cats = (cats || []).map(function(c) { return c.name || c; }).filter(Boolean);
    } catch (e) {
      console.warn('Dish Index categories', e);
      _cats = [];
    }
    try {
      _taxRows = await rpc('get_recipe_taxonomy', { p_category: null }) || [];
    } catch (e) {
      console.warn('Dish Index taxonomy', e);
      _taxRows = [];
    }
  }

  function subsFor(cat) {
    var set = {};
    _taxRows.forEach(function(r) {
      if (String(r.subcategory_category || '').trim() === String(cat || '').trim() && r.subcategory_name) set[r.subcategory_name] = true;
    });
    return Object.keys(set).sort();
  }

  function divsFor(cat, sub) {
    var set = {};
    _taxRows.forEach(function(r) {
      if (String(r.subcategory_category || '').trim() === String(cat || '').trim() &&
          String(r.subcategory_name || '').trim() === String(sub || '').trim() &&
          r.division_name) set[r.division_name] = true;
    });
    return Object.keys(set).sort();
  }

  function optHtml(values, active, blank) {
    var html = blank ? '<option value="">' + h(blank) + '</option>' : '';
    values.forEach(function(v) {
      html += '<option value="' + h(v) + '"' + (v === active ? ' selected' : '') + '>' + h(v) + '</option>';
    });
    return html;
  }

  function renderShell(root) {
    root.innerHTML =
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:10px;line-height:1.55">' +
        '<strong>Dish Index v' + _SHELL_VERSION + '</strong> — Canonical dish registry (schema <code>' + _SCHEMA_VERSION + '</code>). Use <strong>queue views</strong> for editorial pipeline, <strong>bulk toolbar</strong> when rows are selected, and <strong>Import CSV</strong> for preview + chunked load. Ingredients and method stay in Submit a Recipe.' +
      '</div>' +
      '<div id="rnl-queue-row" style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px"></div>' +
      '<div class="rm-list-toolbar" style="margin-bottom:10px;flex-wrap:wrap">' +
        '<input type="text" class="ap-search" id="rnl-search" placeholder="Search name, DI#, country..." style="flex:1;min-width:190px;max-width:280px">' +
        '<select id="rnl-category-filter" class="ing-cat-filter" title="Category"><option value="">All categories</option></select>' +
        '<select id="rnl-sub-filter" class="ing-cat-filter" title="Sub-category"><option value="">All sub-categories</option></select>' +
        '<select id="rnl-div-filter" class="ing-cat-filter" title="Division"><option value="">All divisions</option></select>' +
        '<select id="rnl-research-filter" class="ing-cat-filter"><option value="">All research</option>' + optHtml(_RESEARCH, '', null) + '</select>' +
        '<select id="rnl-content-filter" class="ing-cat-filter"><option value="">All content</option>' + optHtml(_CONTENT, '', null) + '</select>' +
        '<select id="rnl-linked-filter" class="ing-cat-filter"><option value="">Linked + unlinked</option><option value="linked">Linked only</option><option value="unlinked">Unlinked only</option></select>' +
        '<select id="rnl-drift-filter" class="ing-cat-filter"><option value="">Any sync state</option><option value="yes">Drift (index ≠ recipe)</option><option value="no">In sync</option></select>' +
        '<label style="display:inline-flex;align-items:center;gap:5px;font-size:11px;color:var(--text-mid);white-space:nowrap"><input type="checkbox" id="rnl-archived-filter"> Show archived</label>' +
      '</div>' +
      '<div class="rm-list-toolbar" style="margin-bottom:12px;flex-wrap:wrap">' +
        '<button type="button" class="ing-add-btn" id="rnl-add-btn">+ Add dish</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-import-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Import CSV</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-export-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Export CSV</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-print-btn" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Print selected linked</button>' +
        '<input type="file" id="rnl-file" accept=".csv,text/csv" style="display:none">' +
      '</div>' +
      '<div id="rnl-bulk-bar" class="bulk-toolbar" style="display:none;flex-wrap:wrap;align-items:center">' +
        '<span class="bulk-count" id="rnl-bulk-count">0 selected</span>' +
        '<select id="rnl-bulk-category" class="ing-cat-filter"><option value="">Category…</option></select>' +
        '<select id="rnl-bulk-sub" class="ing-cat-filter"><option value="">Sub…</option></select>' +
        '<select id="rnl-bulk-div" class="ing-cat-filter"><option value="">Division…</option></select>' +
        '<button type="button" class="bulk-apply-btn" id="rnl-bulk-taxonomy">Apply taxonomy</button>' +
        '<select id="rnl-bulk-research" class="ing-cat-filter"><option value="">Research…</option>' + optHtml(_RESEARCH, '', null) + '</select>' +
        '<select id="rnl-bulk-content" class="ing-cat-filter"><option value="">Content…</option>' + optHtml(_CONTENT, '', null) + '</select>' +
        '<button type="button" class="bulk-apply-btn" id="rnl-bulk-status">Apply status</button>' +
        '<button type="button" class="bulk-apply-btn" id="rnl-bulk-push" title="Push index metadata to linked recipes">Push → recipe</button>' +
        '<button type="button" class="bulk-apply-btn" id="rnl-bulk-pull" title="Pull metadata from linked recipes into index">Pull ← recipe</button>' +
        '<button type="button" class="bulk-clear-btn" id="rnl-bulk-archive">Archive</button>' +
        '<button type="button" class="bulk-clear-btn" id="rnl-bulk-merge">Merge duplicates</button>' +
        '<button type="button" class="bulk-clear-btn" id="rnl-bulk-clear">Clear</button>' +
      '</div>' +
      '<div id="rnl-count" style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:8px"></div>' +
      '<div class="ap-table-wrap" style="overflow:auto">' +
        '<table class="ap-table" id="rnl-table"><thead></thead><tbody id="rnl-tbody"><tr><td class="ap-empty-row">Loading...</td></tr></tbody></table>' +
      '</div>' +
      '<div id="rnl-pagination" style="display:none;align-items:center;justify-content:center;gap:8px;margin-top:14px"></div>' +
      '<div id="rnl-editor-backdrop" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.55);z-index:1200;padding:24px;overflow:auto">' +
        '<div id="rnl-editor-modal" style="max-width:920px;margin:0 auto;background:var(--bg);border:1px solid var(--border);border-radius:14px;padding:20px 22px 18px"></div>' +
      '</div>' +
      '<div id="rnl-import-backdrop" class="csv-modal-overlay" style="z-index:1201">' +
        '<div class="csv-modal" style="max-width:920px">' +
          '<div class="csv-modal-head"><div class="csv-modal-title">Import preview</div><button type="button" class="ing-modal-close" id="rnl-import-close">✕</button></div>' +
          '<div class="csv-modal-body"><div id="rnl-import-summary" style="font-size:13px;color:var(--text-mid);margin-bottom:12px"></div>' +
            '<div class="csv-preview-wrap"><table class="csv-preview-table" id="rnl-import-preview-table"></table></div></div>' +
          '<div class="csv-modal-foot">' +
            '<button type="button" class="csv-import-btn" id="rnl-import-commit">Import approved rows</button>' +
            '<button type="button" class="csv-cancel-btn" id="rnl-import-cancel">Cancel</button>' +
            '<span class="csv-status" id="rnl-import-status"></span>' +
          '</div></div></div>' +
      '<div id="rnl-link-backdrop" class="csv-modal-overlay" style="z-index:1201">' +
        '<div class="csv-modal" style="max-width:640px">' +
          '<div class="csv-modal-head"><div class="csv-modal-title">Link to recipe</div><button type="button" class="ing-modal-close" id="rnl-link-close">✕</button></div>' +
          '<div class="csv-modal-body">' +
            '<input type="text" class="ap-search" id="rnl-link-search" placeholder="Search recipe name or RM#…" style="width:100%;max-width:none;margin-bottom:12px">' +
            '<div id="rnl-link-results" style="max-height:320px;overflow:auto"></div>' +
          '</div></div></div>';
    renderQueuePills();
  }

  function renderQueuePills() {
    var row = document.getElementById('rnl-queue-row');
    if (!row) return;
    row.innerHTML = _QUEUE_PRESETS.map(function(q) {
      return '<button type="button" class="ap-filter-btn rnl-queue-pill" data-queue="' + h(q.id) + '">' + h(q.label) + '</button>';
    }).join('');
    row.querySelectorAll('.rnl-queue-pill').forEach(function(btn) {
      btn.addEventListener('click', function() { applyQueuePreset(btn.dataset.queue); });
    });
    var saved = 'all';
    try { saved = localStorage.getItem(_QUEUE_STORAGE) || 'all'; } catch (_) {}
    applyQueuePreset(saved, false);
  }

  function bindShell() {
    if (_bound) return;
    _bound = true;
    var t;
    var search = document.getElementById('rnl-search');
    if (search) search.addEventListener('input', function() { clearTimeout(t); t = setTimeout(function() { _page = 1; loadRows(); }, 300); });
    ['rnl-category-filter', 'rnl-sub-filter', 'rnl-div-filter', 'rnl-research-filter', 'rnl-content-filter', 'rnl-linked-filter', 'rnl-drift-filter', 'rnl-archived-filter'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.addEventListener('change', function() {
        _page = 1;
        if (id === 'rnl-category-filter') fillSubDivFilters();
        if (id === 'rnl-sub-filter') {
          var cat = (document.getElementById('rnl-category-filter') || {}).value || '';
          var divSel = document.getElementById('rnl-div-filter');
          if (divSel) {
            divSel.innerHTML = '<option value="">All divisions</option>' + divsFor(cat, el.value).map(function(d) {
              return '<option value="' + h(d) + '">' + h(d) + '</option>';
            }).join('');
          }
        }
        loadRows();
      });
    });
    var catBulk = document.getElementById('rnl-bulk-category');
    if (catBulk) catBulk.addEventListener('change', fillBulkSubDiv);
    var bulkSub = document.getElementById('rnl-bulk-sub');
    if (bulkSub) bulkSub.addEventListener('change', function() {
      var cat = (document.getElementById('rnl-bulk-category') || {}).value || '';
      var divSel = document.getElementById('rnl-bulk-div');
      if (divSel) {
        divSel.innerHTML = '<option value="">Division…</option>' + divsFor(cat, bulkSub.value).map(function(d) {
          return '<option value="' + h(d) + '">' + h(d) + '</option>';
        }).join('');
      }
    });
    var add = document.getElementById('rnl-add-btn');
    if (add) add.addEventListener('click', addRow);
    var exp = document.getElementById('rnl-export-btn');
    if (exp) exp.addEventListener('click', exportCsv);
    var imp = document.getElementById('rnl-import-btn');
    var file = document.getElementById('rnl-file');
    if (imp && file) imp.addEventListener('click', function() { file.click(); });
    if (file) file.addEventListener('change', importCsv);
    var print = document.getElementById('rnl-print-btn');
    if (print) print.addEventListener('click', printSelected);
    var backdrop = document.getElementById('rnl-editor-backdrop');
    if (backdrop) backdrop.addEventListener('click', function(e) { if (e.target === backdrop) closeRowEditor(); });
    var impClose = document.getElementById('rnl-import-close');
    var impCancel = document.getElementById('rnl-import-cancel');
    if (impClose) impClose.onclick = closeImportPreview;
    if (impCancel) impCancel.onclick = closeImportPreview;
    var impCommit = document.getElementById('rnl-import-commit');
    if (impCommit) impCommit.onclick = commitImport;
    var linkClose = document.getElementById('rnl-link-close');
    if (linkClose) linkClose.onclick = closeLinkModal;
    var linkSearch = document.getElementById('rnl-link-search');
    if (linkSearch) linkSearch.addEventListener('input', function() { clearTimeout(t); t = setTimeout(runLinkSearch, 300); });
    document.getElementById('rnl-bulk-taxonomy').onclick = bulkApplyTaxonomy;
    document.getElementById('rnl-bulk-status').onclick = bulkApplyStatus;
    document.getElementById('rnl-bulk-push').onclick = bulkPushToRecipe;
    document.getElementById('rnl-bulk-pull').onclick = bulkPullFromRecipe;
    document.getElementById('rnl-bulk-archive').onclick = bulkArchive;
    document.getElementById('rnl-bulk-merge').onclick = bulkMerge;
    document.getElementById('rnl-bulk-clear').onclick = function() { _selected.clear(); updateBulkToolbar(); renderTable(); };
  }

  function fillCategoryFilter() {
    ['rnl-category-filter', 'rnl-bulk-category'].forEach(function(id) {
      var sel = document.getElementById(id);
      if (!sel || sel.options.length > 1) return;
      _cats.forEach(function(c) {
        var o = document.createElement('option');
        o.value = c;
        o.textContent = c;
        sel.appendChild(o);
      });
    });
    fillSubDivFilters();
    fillBulkSubDiv();
  }

  function fillSubDivFilters() {
    var cat = (document.getElementById('rnl-category-filter') || {}).value || '';
    var subSel = document.getElementById('rnl-sub-filter');
    var divSel = document.getElementById('rnl-div-filter');
    if (subSel) {
      subSel.innerHTML = '<option value="">All sub-categories</option>' + subsFor(cat).map(function(s) {
        return '<option value="' + h(s) + '">' + h(s) + '</option>';
      }).join('');
    }
    if (divSel) {
      var sub = (subSel && subSel.value) || '';
      divSel.innerHTML = '<option value="">All divisions</option>' + divsFor(cat, sub).map(function(d) {
        return '<option value="' + h(d) + '">' + h(d) + '</option>';
      }).join('');
    }
  }

  function fillBulkSubDiv() {
    var cat = (document.getElementById('rnl-bulk-category') || {}).value || '';
    var subSel = document.getElementById('rnl-bulk-sub');
    var divSel = document.getElementById('rnl-bulk-div');
    if (subSel) {
      subSel.innerHTML = '<option value="">Sub…</option>' + subsFor(cat).map(function(s) {
        return '<option value="' + h(s) + '">' + h(s) + '</option>';
      }).join('');
    }
    if (divSel) {
      divSel.innerHTML = '<option value="">Division…</option>' + divsFor(cat, (subSel && subSel.value) || '').map(function(d) {
        return '<option value="' + h(d) + '">' + h(d) + '</option>';
      }).join('');
    }
  }

  async function loadRows() {
    var tbody = document.getElementById('rnl-tbody');
    if (tbody) tbody.innerHTML = '<tr><td colspan="' + _TABLE_COLS.length + '" class="ap-empty-row">Loading...</td></tr>';
    try {
      var result = await rpc('admin_list_recipe_name_library', Object.assign({ p_limit: _PAGE_SIZE, p_offset: (_page - 1) * _PAGE_SIZE }, listFilters()));
      _rows = (result && result.rows) || [];
      _total = parseInt(result && result.total, 10) || 0;
      renderTable();
      renderPagination();
    } catch (e) {
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="' + _TABLE_COLS.length + '" class="ap-empty-row">Error: ' + h(e.message || e) +
          '<br>Run <code>database/sql/fix-recipe-name-library.sql</code>, <code>fix-dish-index-columns.sql</code>, then <code>fix-dish-index-ops.sql</code> in Supabase, then refresh.</td></tr>';
      }
    }
  }

  function renderTable() {
    var table = document.getElementById('rnl-table');
    var tbody = document.getElementById('rnl-tbody');
    var count = document.getElementById('rnl-count');
    if (!table || !tbody) return;
    if (count) {
      var start = _total ? ((_page - 1) * _PAGE_SIZE) + 1 : 0;
      var end = Math.min(_page * _PAGE_SIZE, _total);
      count.textContent = _total + ' dish' + (_total === 1 ? '' : 'es') + (_total ? ' (showing ' + start + '-' + end + ')' : '');
    }
    table.querySelector('thead').innerHTML = '<tr>' + _TABLE_COLS.map(function(c) {
      if (c.key === 'select') return '<th style="width:28px"><input type="checkbox" id="rnl-select-all"></th>';
      if (c.fixed || c.readonly) return '<th>' + h(c.label) + '</th>';
      var arrow = _sort.column === c.key ? (_sort.direction === 'asc' ? ' ▲' : ' ▼') : '';
      return '<th class="rnl-sort" data-col="' + h(c.key) + '" style="cursor:pointer;white-space:nowrap">' + h(c.label) + arrow + '</th>';
    }).join('') + '</tr>';
    tbody.innerHTML = '';
    if (!_rows.length) {
      tbody.innerHTML = '<tr><td colspan="' + _TABLE_COLS.length + '" class="ap-empty-row">No dishes yet. Add one or import a CSV.</td></tr>';
      return;
    }
    _rows.forEach(function(r) {
      var tr = document.createElement('tr');
      tr.dataset.id = r.id;
      tr.innerHTML = _TABLE_COLS.map(function(c) { return renderCell(r, c); }).join('');
      tbody.appendChild(tr);
    });
    bindTableEvents();
  }

  function renderCell(r, c) {
    if (c.key === 'select') {
      var archived = r.is_active === false;
      return '<td><input type="checkbox" class="rnl-row-cb" value="' + h(r.id) + '"' + (_selected.has(r.id) ? ' checked' : '') + (archived ? ' disabled' : '') + '></td>';
    }
    if (c.key === 'actions') {
      var driftBtn = r.has_drift ? '<button class="ap-mini-btn rnl-drift" style="color:#d4a017" title="Index differs from linked recipe">Drift</button>' : '';
      var syncPush = r.linked_recipe_id ? '<button class="ap-mini-btn rnl-sync-push" title="Push index → recipe">Push</button>' : '';
      var syncPull = r.linked_recipe_id ? '<button class="ap-mini-btn rnl-sync-pull" title="Pull recipe → index">Pull</button>' : '';
      var print = r.linked_recipe_id ? '<button class="ap-mini-btn rnl-print-one" data-id="' + h(r.linked_recipe_id) + '">Print</button>' : '';
      return '<td style="white-space:nowrap">' +
        '<button class="ap-mini-btn rnl-edit-btn" style="border-color:var(--accent);color:var(--accent);font-weight:600">Edit</button>' +
        driftBtn + syncPush + syncPull +
        (r.linked_recipe_id ? '<button class="ap-mini-btn rnl-unlink">Unlink</button>' : '<button class="ap-mini-btn rnl-create">Create recipe</button>') +
        print +
        '<button class="ap-mini-btn rnl-link">Link</button>' +
        '<button class="ap-mini-btn rnl-delete" style="color:#dc5050">Archive</button>' +
      '</td>';
    }
    if (c.key === 'dish_code') {
      var code = r.dish_code || '—';
      var driftMark = r.has_drift ? ' <span title="Drift from linked recipe" style="color:#d4a017">⚠</span>' : '';
      return '<td style="font-family:ui-monospace,monospace;font-size:11px;white-space:nowrap">' + h(code) + driftMark + '</td>';
    }
    if (c.key === 'linked_recipe_name') {
      var txt = r.linked_recipe_id ? ((r.linked_recipe_code ? r.linked_recipe_code + ' · ' : '') + (r.linked_recipe_name || r.linked_recipe_id) + (r.linked_recipe_status ? ' (' + r.linked_recipe_status + ')' : '')) : 'Unlinked';
      return '<td style="min-width:180px;color:' + (r.linked_recipe_id ? 'var(--text-high)' : 'var(--text-mid)') + '">' + h(txt) + '</td>';
    }
    if (c.key === 'category') return '<td>' + selectCell(c.key, _cats, r[c.key], 'Category...') + '</td>';
    if (c.key === 'sub_category') return '<td>' + selectCell(c.key, subsFor(r.category), r[c.key], 'Sub...') + '</td>';
    if (c.key === 'division') return '<td>' + selectCell(c.key, divsFor(r.category, r.sub_category), r[c.key], 'Division...') + '</td>';
    if (c.key === 'research_status') return '<td>' + selectCell(c.key, _RESEARCH, r[c.key] || 'idea_only', '') + '</td>';
    if (c.key === 'content_status') return '<td>' + selectCell(c.key, _CONTENT, r[c.key] || 'not_started', '') + '</td>';
    var val = r[c.key] || '';
    return '<td><input class="rnl-edit" data-field="' + h(c.key) + '" value="' + h(val) + '" style="min-width:130px;width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px"></td>';
  }

  function selectCell(field, options, active, blank) {
    return '<select class="rnl-edit" data-field="' + h(field) + '" style="min-width:130px;width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px">' +
      optHtml(options, active || '', blank) + '</select>';
  }

  function bindTableEvents() {
    document.querySelectorAll('#rnl-table .rnl-sort').forEach(function(th) {
      th.addEventListener('click', function() {
        var col = th.dataset.col;
        if (_sort.column === col) _sort.direction = _sort.direction === 'asc' ? 'desc' : 'asc';
        else _sort = { column: col, direction: 'asc' };
        loadRows();
      });
    });
    var all = document.getElementById('rnl-select-all');
    if (all) all.addEventListener('change', function() {
      document.querySelectorAll('.rnl-row-cb:not(:disabled)').forEach(function(cb) {
        cb.checked = all.checked;
        if (cb.checked) _selected.add(cb.value); else _selected.delete(cb.value);
      });
      updateBulkToolbar();
    });
    document.querySelectorAll('.rnl-row-cb').forEach(function(cb) {
      cb.addEventListener('change', function() {
        if (cb.checked) _selected.add(cb.value); else _selected.delete(cb.value);
        updateBulkToolbar();
      });
    });
    document.querySelectorAll('#rnl-tbody .rnl-edit').forEach(function(el) {
      el.addEventListener('change', function() { saveCell(el); });
    });
    document.querySelectorAll('.rnl-edit-btn').forEach(function(btn) { btn.addEventListener('click', openRowEditorFromBtn); });
    document.querySelectorAll('.rnl-create').forEach(function(btn) { btn.addEventListener('click', createRecipe); });
    document.querySelectorAll('.rnl-delete').forEach(function(btn) { btn.addEventListener('click', deleteRow); });
    document.querySelectorAll('.rnl-link').forEach(function(btn) { btn.addEventListener('click', openLinkModal); });
    document.querySelectorAll('.rnl-unlink').forEach(function(btn) { btn.addEventListener('click', unlinkRow); });
    document.querySelectorAll('.rnl-sync-push').forEach(function(btn) { btn.addEventListener('click', syncPushOne); });
    document.querySelectorAll('.rnl-sync-pull').forEach(function(btn) { btn.addEventListener('click', syncPullOne); });
    document.querySelectorAll('.rnl-drift').forEach(function(btn) { btn.addEventListener('click', showDrift); });
    document.querySelectorAll('.rnl-print-one').forEach(function(btn) {
      btn.addEventListener('click', function() { window.open('print-studio.html?id=' + encodeURIComponent(btn.dataset.id), '_blank'); });
    });
    updateBulkToolbar();
  }

  function openRowEditorFromBtn(e) {
    var tr = e.target.closest('tr');
    var id = tr && tr.dataset.id;
    var r = _rows.find(function(x) { return x.id === id; });
    if (r) openRowEditor(Object.assign({}, r));
  }

  function editorFieldHtml(f, r) {
    var val = f.array ? arrText(r[f.key]) : (r[f.key] == null ? '' : r[f.key]);
    var common = 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;color:var(--text-high);font-size:13px;font-family:DM Sans,sans-serif';
    var hint = f.hint ? '<div style="font-size:11px;color:var(--text-mid);margin-top:4px">' + h(f.hint) + '</div>' : '';
    if (f.taxonomy === 'category') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(_cats, val, 'Category...') + '</select>' + hint;
    }
    if (f.taxonomy === 'sub') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(subsFor(r.category), val, 'Sub-category...') + '</select>' + hint;
    }
    if (f.taxonomy === 'div') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(divsFor(r.category, r.sub_category), val, 'Division...') + '</select>' + hint;
    }
    if (f.select) {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(f.select, val, '') + '</select>' + hint;
    }
    if (f.textarea) {
      return '<textarea data-field="' + h(f.key) + '" rows="3" style="' + common + '">' + h(val) + '</textarea>' + hint;
    }
    return '<input data-field="' + h(f.key) + '" value="' + h(val) + '" style="' + common + '">' + hint;
  }

  function openRowEditor(row) {
    _editRow = Object.assign({}, row);
    var modal = document.getElementById('rnl-editor-modal');
    var backdrop = document.getElementById('rnl-editor-backdrop');
    if (!modal || !backdrop) return;
    modal.innerHTML =
      '<div style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:14px">' +
        '<div><div style="font-family:Cormorant Garamond,serif;font-size:1.5rem;font-weight:700;color:var(--text-high)">' + h(_editRow.recipe_name || 'New dish') + '</div>' +
        '<div style="font-size:12px;color:var(--text-mid);margin-top:4px">' +
          (_editRow.dish_code ? 'DI# ' + h(_editRow.dish_code) + ' · ' : '') +
          'Full Dish Index record — ingredients and method are added later in Submit a Recipe.</div></div>' +
        '<button type="button" class="ap-mini-btn" id="rnl-editor-close">Close</button>' +
      '</div>' +
      _EDITOR_GROUPS.map(function(g) {
        return '<div style="margin-bottom:16px;padding-top:8px;border-top:1px solid var(--border)">' +
          '<div style="font-size:11px;font-weight:600;letter-spacing:0.08em;text-transform:uppercase;color:var(--accent);margin-bottom:10px">' + h(g.title) + '</div>' +
          '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:12px">' +
            g.fields.map(function(f) {
              return '<label style="display:block"><div style="font-size:12px;color:var(--text-mid);margin-bottom:5px">' + h(f.label) + (f.required ? ' *' : '') + '</div>' +
                editorFieldHtml(f, _editRow) + '</label>';
            }).join('') +
          '</div></div>';
      }).join('') +
      '<div style="display:flex;justify-content:flex-end;gap:8px;margin-top:8px">' +
        '<button type="button" class="ing-add-btn" id="rnl-editor-cancel" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Cancel</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-editor-save">Save dish</button>' +
      '</div>';
    backdrop.style.display = 'block';
    document.getElementById('rnl-editor-close').onclick = closeRowEditor;
    document.getElementById('rnl-editor-cancel').onclick = closeRowEditor;
    document.getElementById('rnl-editor-save').onclick = saveRowEditor;
    modal.querySelectorAll('[data-field="category"]').forEach(function(el) {
      el.addEventListener('change', function() {
        _editRow.category = el.value;
        _editRow.sub_category = '';
        _editRow.division = '';
        openRowEditor(_editRow);
      });
    });
    modal.querySelectorAll('[data-field="sub_category"]').forEach(function(el) {
      el.addEventListener('change', function() {
        _editRow.sub_category = el.value;
        _editRow.division = '';
        openRowEditor(_editRow);
      });
    });
  }

  function closeRowEditor() {
    _editRow = null;
    var backdrop = document.getElementById('rnl-editor-backdrop');
    if (backdrop) backdrop.style.display = 'none';
  }

  function collectEditorValues() {
    var modal = document.getElementById('rnl-editor-modal');
    if (!modal || !_editRow) return null;
    var out = Object.assign({}, _editRow);
    modal.querySelectorAll('[data-field]').forEach(function(el) {
      var key = el.dataset.field;
      var fMeta = null;
      _EDITOR_GROUPS.forEach(function(g) {
        g.fields.forEach(function(f) { if (f.key === key) fMeta = f; });
      });
      var raw = el.value || '';
      out[key] = (fMeta && fMeta.array) ? splitList(raw) : raw;
    });
    return out;
  }

  async function saveRowEditor() {
    var payload = collectEditorValues();
    if (!payload || !String(payload.recipe_name || '').trim()) {
      alert('Recipe name is required.');
      return;
    }
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: rowToPayload(payload) });
      if (typeof auditLog === 'function') auditLog('Dish Index', 'Row Saved', null, null, null, payload.recipe_name);
      closeRowEditor();
      await loadRows();
    } catch (e) {
      alert(e.message || e);
    }
  }

  async function saveCell(el) {
    var tr = el.closest('tr');
    var id = tr && tr.dataset.id;
    var r = _rows.find(function(x) { return x.id === id; });
    if (!r) return;
    var field = el.dataset.field;
    r[field] = el.value;
    if (field === 'category') { r.sub_category = ''; r.division = ''; }
    if (field === 'sub_category') { r.division = ''; }
    el.style.borderColor = 'var(--accent)';
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: rowToPayload(r) });
      el.style.borderColor = 'var(--border)';
      if (field === 'category' || field === 'sub_category') renderTable();
      if (typeof auditLog === 'function') auditLog('Dish Index', 'Row Updated', null, null, null, r.recipe_name + ' - ' + field);
    } catch (e) {
      el.style.borderColor = '#dc5050';
      alert(e.message || e);
    }
  }

  async function addRow() {
    var name = prompt('Recipe name');
    if (!name || !name.trim()) return;
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: { recipe_name: name.trim(), research_status: 'idea_only', content_status: 'not_started' } });
      await loadRows();
    } catch (e) {
      alert(e.message || e);
    }
  }

  async function createRecipe(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Create a pending draft recipe from this Dish Index row?')) return;
    try {
      var recipeId = await rpc('admin_create_recipe_from_name_library', { p_id: id });
      await loadRows();
      if (recipeId && confirm('Draft created. Open it in Submit a Recipe now?')) {
        window.open('submit-recipe.html?adminReview=' + encodeURIComponent(recipeId) + '&embedded=1', '_blank');
      }
    } catch (err) {
      alert(err.message || err);
    }
  }

  var _importRows = [];
  var _linkTargetId = null;

  async function syncPushOne(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Push Dish Index metadata to the linked recipe? Ingredients and method are not changed.')) return;
    try {
      await rpc('admin_sync_recipe_from_name_library', { p_id: id, p_overwrite: true });
      if (typeof auditLog === 'function') auditLog('Dish Index', 'Pushed to Recipe', null, null, null, id);
      await loadRows();
    } catch (err) { alert(err.message || err); }
  }

  async function syncPullOne(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Pull metadata from the linked recipe into this Dish Index row?')) return;
    try {
      await rpc('admin_sync_name_library_from_recipe', { p_id: id });
      if (typeof auditLog === 'function') auditLog('Dish Index', 'Pulled from Recipe', null, null, null, id);
      await loadRows();
    } catch (err) { alert(err.message || err); }
  }

  async function showDrift(e) {
    var id = e.target.closest('tr').dataset.id;
    try {
      var d = await rpc('admin_name_library_drift', { p_id: id });
      var fields = (d && d.fields) || [];
      if (!fields.length) { alert('No drift detected (or not linked).'); return; }
      alert('Fields that differ:\n\n' + fields.map(function(f) {
        return f.field + ':\n  Index: ' + (f.index || '—') + '\n  Recipe: ' + (f.recipe || '—');
      }).join('\n\n'));
    } catch (err) { alert(err.message || err); }
  }

  function openLinkModal(e) {
    _linkTargetId = e.target.closest('tr').dataset.id;
    var backdrop = document.getElementById('rnl-link-backdrop');
    var search = document.getElementById('rnl-link-search');
    if (search) search.value = '';
    document.getElementById('rnl-link-results').innerHTML = '<div style="padding:12px;color:var(--text-mid);font-size:13px">Type to search recipes…</div>';
    if (backdrop) backdrop.classList.add('open');
  }

  function closeLinkModal() {
    _linkTargetId = null;
    var backdrop = document.getElementById('rnl-link-backdrop');
    if (backdrop) backdrop.classList.remove('open');
  }

  async function runLinkSearch() {
    var q = (document.getElementById('rnl-link-search') || {}).value || '';
    var host = document.getElementById('rnl-link-results');
    if (!host || !q.trim()) return;
    host.innerHTML = '<div style="padding:12px;color:var(--text-mid)">Searching…</div>';
    try {
      var rows = await rpc('admin_search_recipes_for_link', { p_search: q.trim(), p_limit: 20 }) || [];
      if (!rows.length) {
        host.innerHTML = '<div style="padding:12px;color:var(--text-mid)">No recipes found.</div>';
        return;
      }
      host.innerHTML = rows.map(function(r) {
        return '<button type="button" class="rnl-link-pick" data-rid="' + h(r.id) + '" style="display:block;width:100%;text-align:left;padding:10px 12px;margin-bottom:6px;border:1px solid var(--border);border-radius:8px;background:var(--card-bg);color:var(--text-high);cursor:pointer;font-family:DM Sans,sans-serif;font-size:13px">' +
          '<strong>' + h(r.recipe_code || 'No RM#') + '</strong> — ' + h(r.recipe_name) +
          (r.native_title ? ' <span style="color:var(--text-mid)">(' + h(r.native_title) + ')</span>' : '') +
          '<div style="font-size:11px;color:var(--text-mid);margin-top:4px">' + h(r.category || '') + ' · ' + h(r.status || '') + '</div></button>';
      }).join('');
      host.querySelectorAll('.rnl-link-pick').forEach(function(btn) {
        btn.addEventListener('click', async function() {
          try {
            await rpc('admin_link_recipe_name_library', { p_id: _linkTargetId, p_recipe_id: btn.dataset.rid });
            closeLinkModal();
            await loadRows();
          } catch (err) { alert(err.message || err); }
        });
      });
    } catch (err) {
      host.innerHTML = '<div style="padding:12px;color:var(--danger)">' + h(err.message || err) + '</div>';
    }
  }

  async function bulkApplyTaxonomy() {
    var ids = selectedIds();
    if (!ids.length) return alert('Select rows first.');
    var fields = {};
    var cat = (document.getElementById('rnl-bulk-category') || {}).value;
    var sub = (document.getElementById('rnl-bulk-sub') || {}).value;
    var div = (document.getElementById('rnl-bulk-div') || {}).value;
    if (cat) fields.category = cat;
    if (sub) fields.sub_category = sub;
    if (div) fields.division = div;
    if (!Object.keys(fields).length) return alert('Choose category, sub-category, or division.');
    try {
      var res = await rpc('admin_bulk_update_recipe_name_library', { p_ids: ids, p_fields: fields });
      alert('Updated ' + (res.updated || 0) + ' row(s).');
      await loadRows();
    } catch (e) { alert(e.message || e); }
  }

  async function bulkApplyStatus() {
    var ids = selectedIds();
    if (!ids.length) return alert('Select rows first.');
    var fields = {};
    var rs = (document.getElementById('rnl-bulk-research') || {}).value;
    var cs = (document.getElementById('rnl-bulk-content') || {}).value;
    if (rs) fields.research_status = rs;
    if (cs) fields.content_status = cs;
    if (!Object.keys(fields).length) return alert('Choose research or content status.');
    try {
      var res = await rpc('admin_bulk_update_recipe_name_library', { p_ids: ids, p_fields: fields });
      alert('Updated ' + (res.updated || 0) + ' row(s).');
      await loadRows();
    } catch (e) { alert(e.message || e); }
  }

  async function bulkPushToRecipe() {
    var ids = selectedIds();
    var linked = _rows.filter(function(r) { return ids.indexOf(r.id) >= 0 && r.linked_recipe_id; });
    if (!linked.length) return alert('Select linked rows only.');
    if (!confirm('Push index metadata to ' + linked.length + ' linked recipe(s)?')) return;
    var ok = 0;
    for (var i = 0; i < linked.length; i++) {
      try {
        await rpc('admin_sync_recipe_from_name_library', { p_id: linked[i].id, p_overwrite: true });
        ok++;
      } catch (_) {}
    }
    alert('Pushed to ' + ok + ' recipe(s).');
    await loadRows();
  }

  async function bulkPullFromRecipe() {
    var ids = selectedIds();
    var linked = _rows.filter(function(r) { return ids.indexOf(r.id) >= 0 && r.linked_recipe_id; });
    if (!linked.length) return alert('Select linked rows only.');
    if (!confirm('Pull metadata from recipe into ' + linked.length + ' index row(s)?')) return;
    var ok = 0;
    for (var i = 0; i < linked.length; i++) {
      try {
        await rpc('admin_sync_name_library_from_recipe', { p_id: linked[i].id });
        ok++;
      } catch (_) {}
    }
    alert('Pulled ' + ok + ' row(s).');
    await loadRows();
  }

  async function bulkArchive() {
    var ids = selectedIds();
    if (!ids.length) return alert('Select rows first.');
    if (!confirm('Archive ' + ids.length + ' dish row(s)? They can be shown again with Show archived.')) return;
    try {
      await rpc('admin_bulk_update_recipe_name_library', { p_ids: ids, p_fields: { is_active: false, content_status: 'retired' } });
      ids.forEach(function(id) { _selected.delete(id); });
      await loadRows();
    } catch (e) { alert(e.message || e); }
  }

  async function bulkMerge() {
    var ids = selectedIds();
    if (ids.length < 2) return alert('Select at least 2 rows to merge. The first selected row is kept.');
    var keep = ids[0];
    if (!confirm('Merge ' + (ids.length - 1) + ' row(s) into the first selected row? Merged rows are archived.')) return;
    var merged = 0;
    for (var i = 1; i < ids.length; i++) {
      try {
        await rpc('admin_merge_recipe_name_library', { p_keep_id: keep, p_merge_id: ids[i] });
        _selected.delete(ids[i]);
        merged++;
      } catch (e) { alert(e.message || e); break; }
    }
    alert('Merged ' + merged + ' row(s).');
    await loadRows();
  }

  function closeImportPreview() {
    _importRows = [];
    var backdrop = document.getElementById('rnl-import-backdrop');
    if (backdrop) backdrop.classList.remove('open');
  }

  async function commitImport() {
    if (!_importRows.length) return;
    var btn = document.getElementById('rnl-import-commit');
    var status = document.getElementById('rnl-import-status');
    if (btn) btn.disabled = true;
    var inserted = 0, updated = 0, skipped = 0;
    try {
      for (var i = 0; i < _importRows.length; i += _IMPORT_CHUNK) {
        var chunk = _importRows.slice(i, i + _IMPORT_CHUNK);
        if (status) status.textContent = 'Importing ' + Math.min(i + _IMPORT_CHUNK, _importRows.length) + ' / ' + _importRows.length + '…';
        var result = await rpc('admin_import_recipe_name_library', { p_rows: chunk });
        inserted += result.inserted || 0;
        updated += result.updated || 0;
        skipped += result.skipped || 0;
      }
      alert('Import complete: ' + inserted + ' inserted, ' + updated + ' updated, ' + skipped + ' skipped.');
      closeImportPreview();
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    } finally {
      if (btn) btn.disabled = false;
      if (status) status.textContent = '';
    }
  }

  async function unlinkRow(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Unlink this dish from its recipe?')) return;
    try {
      await rpc('admin_link_recipe_name_library', { p_id: id, p_recipe_id: null });
      _selected.delete(id);
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  async function deleteRow(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Archive this Dish Index row? Use Show archived to view it later. Linked recipes are not deleted.')) return;
    try {
      await rpc('admin_bulk_update_recipe_name_library', { p_ids: [id], p_fields: { is_active: false, content_status: 'retired' } });
      _selected.delete(id);
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  function rowToCsvLine(r) {
    return [
      r.schema_version || _SCHEMA_VERSION, r.dish_code, r.id, r.recipe_name, r.native_name, arrText(r.alternate_names),
      r.category, r.sub_category, r.division,
      r.origin_continent, r.origin_country, r.origin_state, r.origin_locality,
      arrText(r.primary_ingredients),
      arrText(r.dietary_tags), arrText(r.health_tags), arrText(r.meal_type_tags), arrText(r.occasion_tags), arrText(r.style_tags), arrText(r.flavor_profile_tags),
      r.introduction, r.description, r.image_url, r.image_source_url,
      r.prep_time_minutes, r.cook_time_minutes, r.additional_time_minutes,
      r.servings, r.servings_unit, r.difficulty, r.spice_level, r.sweet_level, r.cooking_style,
      arrText(r.equipment), r.cooking_notes,
      r.shelf_life_value, r.shelf_life_unit, r.shelf_life_storage, r.after_open_value, r.after_open_unit,
      r.source_type, r.credit_name, r.credit_handle, r.credit_url, r.source_url, r.source_notes,
      r.research_status, r.content_status, r.linked_recipe_id,
      r.linked_recipe_name || '', r.is_active === false ? 'false' : 'true', r.notes
    ].map(csvCell).join(',');
  }

  async function exportCsv() {
    var btn = document.getElementById('rnl-export-btn');
    if (btn) { btn.textContent = 'Exporting...'; btn.disabled = true; }
    try {
      var all = await fetchAllRows();
      var lines = [_CSV_HEADERS.map(csvCell).join(',')];
      all.forEach(function(r) { lines.push(rowToCsvLine(r)); });
      var blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'dish-index-' + new Date().toISOString().slice(0, 10) + '.csv';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      alert(e.message || e);
    } finally {
      if (btn) { btn.textContent = 'Export CSV'; btn.disabled = false; }
    }
  }

  async function importCsv(e) {
    var file = e.target.files && e.target.files[0];
    e.target.value = '';
    if (!file) return;
    var text = await file.text();
    var parsed = parseCsv(text.replace(/^\ufeff/, ''));
    if (parsed.length < 2) { alert('CSV has no rows.'); return; }
    var headers = parsed.shift().map(function(hd) { return hd.trim(); });
    var rows = parsed.map(function(cols) {
      var o = { schema_version: _SCHEMA_VERSION };
      headers.forEach(function(hd, i) { o[hd] = cols[i] || ''; });
      return o;
    });
    var backdrop = document.getElementById('rnl-import-backdrop');
    var table = document.getElementById('rnl-import-preview-table');
    var summary = document.getElementById('rnl-import-summary');
    if (summary) summary.textContent = 'Analysing ' + rows.length + ' rows…';
    if (backdrop) backdrop.classList.add('open');
    try {
      var preview = await rpc('admin_preview_import_recipe_name_library', { p_rows: rows });
      _importRows = rows;
      var sum = preview.summary || {};
      if (summary) {
        summary.textContent = (sum.insert || 0) + ' new · ' + (sum.update || 0) + ' update · ' +
          (sum.skip || 0) + ' skip · ' + (sum.error || 0) + ' with warnings — import runs in chunks of ' + _IMPORT_CHUNK + '.';
      }
      var prevRows = preview.rows || [];
      if (table) {
        table.innerHTML = '<thead><tr><th>#</th><th>Action</th><th>Dish</th><th>DI#</th><th>Warnings</th></tr></thead><tbody>' +
          prevRows.map(function(pr) {
            var warns = (pr.warnings || []).join('; ');
            return '<tr><td>' + h(pr.row_num) + '</td><td>' + h(pr.action) + '</td><td>' + h(pr.recipe_name) + '</td><td>' + h(pr.dish_code || '') + '</td><td style="color:' + (warns ? '#d4a017' : 'var(--text-mid)') + '">' + h(warns || '—') + '</td></tr>';
          }).join('') + '</tbody>';
      }
    } catch (err) {
      closeImportPreview();
      alert(err.message || err);
    }
  }

  function printSelected() {
    var ids = _rows.filter(function(r) { return _selected.has(r.id) && r.linked_recipe_id; }).map(function(r) { return r.linked_recipe_id; });
    if (!ids.length) { alert('Select one or more linked dishes first.'); return; }
    if (ids.length === 1) window.open('print-studio.html?id=' + encodeURIComponent(ids[0]), '_blank');
    else window.open('print-studio.html?ids=' + encodeURIComponent(ids.join(',')) + '&collection=' + encodeURIComponent('Dish Index Batch'), '_blank');
  }

  function renderPagination() {
    var el = document.getElementById('rnl-pagination');
    if (!el) return;
    var pages = Math.max(1, Math.ceil(_total / _PAGE_SIZE));
    if (_total <= _PAGE_SIZE) { el.style.display = 'none'; return; }
    el.style.display = 'flex';
    el.innerHTML = '<button type="button" class="ap-pg-btn" id="rnl-prev" ' + (_page <= 1 ? 'disabled' : '') + '>Prev</button>' +
      '<span style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);padding:0 12px">Page ' + _page + ' of ' + pages + '</span>' +
      '<button type="button" class="ap-pg-btn" id="rnl-next" ' + (_page >= pages ? 'disabled' : '') + '>Next</button>';
    document.getElementById('rnl-prev').onclick = function() { if (_page > 1) { _page--; loadRows(); } };
    document.getElementById('rnl-next').onclick = function() { if (_page < pages) { _page++; loadRows(); } };
  }

  async function loadRecipeNameLibraryTab() {
    var root = document.getElementById('recipe-name-library-root');
    if (!root) return;
    if (root.dataset.shellVersion !== _SHELL_VERSION) {
      root.dataset.shellVersion = _SHELL_VERSION;
      root.dataset.built = '';
      _bound = false;
      root.innerHTML = '';
    }
    if (!root.dataset.built) {
      await loadCatsAndTaxonomy();
      renderShell(root);
      fillCategoryFilter();
      bindShell();
      root.dataset.built = '1';
    }
    await loadRows();
  }

  return { loadRecipeNameLibraryTab: loadRecipeNameLibraryTab };
})();
