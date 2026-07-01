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
  var _SHELL_VERSION = '20260705b';
  var _catRows = [];
  var _allCountries = [];
  var _dupClusters = [];
  var _covGaps = null;
  var _IMPORT_CHUNK = 100;
  var _SCHEMA_VERSION = '20260703';
  var _QUEUE_STORAGE = 'tcj_dish_index_active_queue';
  var _COL_VIS_KEY = 'tcj_dish_index_hidden_cols';
  var _activeFilter = 'active';
  var _queueCounts = {};
  var _hiddenCols = new Set();

  var _RESEARCH_LABELS = {
    idea_only: 'Idea only',
    needs_research: 'Needs research',
    ready_to_draft: 'Ready to draft',
    verified: 'Verified'
  };
  var _CONTENT_LABELS = {
    not_started: 'Not started',
    draft_created: 'Draft created',
    linked: 'Linked',
    approved: 'Approved',
    duplicate: 'Duplicate',
    retired: 'Retired'
  };
  var _QUEUE_COUNT_KEYS = {
    all: 'all',
    'idea-only': 'idea_only',
    'ready-unlinked': 'ready_unlinked',
    'ready-linked': 'ready_linked',
    'needs-research': 'needs_research',
    'verified-unlinked': 'verified_unlinked',
    'verified-linked': 'verified_linked',
    'linked-drift': 'linked_drift',
    archived: 'archived'
  };

  var _QUEUE_PRESETS = [
    { id: 'all', label: 'All dishes' },
    { id: 'idea-only', label: 'Idea only' },
    { id: 'needs-research', label: 'Needs research' },
    { id: 'ready-unlinked', label: 'Ready · unlinked' },
    { id: 'ready-linked', label: 'Ready · linked' },
    { id: 'verified-unlinked', label: 'Verified · unlinked' },
    { id: 'verified-linked', label: 'Verified · linked' },
    { id: 'linked-drift', label: 'Linked · drift' },
    { id: 'archived', label: 'Archived' }
  ];

  var _RESEARCH = ['idea_only', 'needs_research', 'ready_to_draft', 'verified'];
  var _CONTENT = ['not_started', 'draft_created', 'linked', 'approved', 'duplicate', 'retired'];
  var _SOURCE_TYPES = ['Original', 'From Somewhere Else', 'Scanned'];
  var _SOURCE_LABELS = {
    'Original': '⭐ My Original Recipe',
    'From Somewhere Else': '🔗 From Somewhere Else',
    'Scanned': '📸 Scanned / Photographed'
  };
  var _VISIBILITY = ['Public', 'Private', 'Friends', 'Archived'];

  var _DEFAULT_HIDDEN_COLS = [
    'occasion_tags', 'style_tags', 'flavor_profile_tags', 'dietary_tags', 'health_tags',
    'prep_time_minutes', 'cook_time_minutes', 'additional_time_minutes', 'servings', 'cooking_style'
  ];

  var _TABLE_COLS = [
    { key: 'select', label: '', fixed: true },
    { key: 'dish_code', label: 'DI#', sortable: true, w: 88 },
    { key: 'recipe_name', label: 'Recipe Name', required: true, w: 140, sortable: true },
    { key: 'native_name', label: 'Native Title', w: 110, sortable: true },
    { key: 'category', label: 'Category', combo: true },
    { key: 'sub_category', label: 'Sub-category', combo: true },
    { key: 'division', label: 'Division', combo: true },
    { key: 'origin_country', label: 'Country', combo: true, w: 130 },
    { key: 'origin_state', label: 'State', combo: true, w: 130 },
    { key: 'primary_ingredients', label: 'Hero Ingredient', array: true, w: 140 },
    { key: 'meal_type_tags', label: 'Meal Type', tags: true, w: 120 },
    { key: 'occasion_tags', label: 'Occasion', tags: true, w: 120 },
    { key: 'style_tags', label: 'Style', tags: true, w: 120 },
    { key: 'flavor_profile_tags', label: 'Flavour', tags: true, w: 120 },
    { key: 'dietary_tags', label: 'Dietary', tags: true, w: 120 },
    { key: 'health_tags', label: 'Health', tags: true, w: 120 },
    { key: 'cooking_style', label: 'Cooking Style', combo: true, w: 140 },
    { key: 'prep_time_minutes', label: 'Prep (min)', number: true, w: 72 },
    { key: 'cook_time_minutes', label: 'Cook (min)', number: true, w: 72 },
    { key: 'additional_time_minutes', label: 'Extra (min)', number: true, w: 72 },
    { key: 'servings', label: 'Servings', number: true, w: 72 },
    { key: 'difficulty', label: 'Difficulty', level: 'diff', w: 168 },
    { key: 'spice_level', label: 'Spice', level: 'spice', w: 168 },
    { key: 'sweet_level', label: 'Sweet', level: 'sweet', w: 168 },
    { key: 'source_type', label: 'Source', combo: true, w: 120 },
    { key: 'visibility', label: 'Visibility', combo: true, w: 100 },
    { key: 'research_status', label: 'Research', combo: true },
    { key: 'content_status', label: 'Content', combo: true },
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
    'research_status', 'content_status', 'linked_recipe_id', 'visibility', 'notes'
  ];

  var _CSV_HEADERS = [
    'Schema Version', 'Dish Code', 'ID', 'Recipe Name', 'Native Name', 'Alternate Names', 'Category', 'Sub-category', 'Division',
    'Continent', 'Country', 'State', 'Locality', 'Hero Ingredient',
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
      { key: 'dish_code', label: 'DI#', hint: 'Unique code e.g. DI000042. Auto-assigned if left blank on new dishes.' },
      { key: 'recipe_name', label: 'Recipe Name', required: true },
      { key: 'native_name', label: 'Native Title' },
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
      { key: 'image_url', label: 'Recipe Photo', photo: true }
    ]},
    { title: 'Times & Yield', fields: [
      { key: 'prep_time_minutes', label: 'Prep (minutes)', number: true },
      { key: 'cook_time_minutes', label: 'Cook (minutes)', number: true },
      { key: 'additional_time_minutes', label: 'Additional (minutes)', number: true },
      { key: 'servings', label: 'Servings', number: true },
      { key: 'servings_unit', label: 'Servings Unit' },
      { key: 'difficulty', label: 'Difficulty', selectKey: 'DIFFICULTY' },
      { key: 'spice_level', label: 'Spice Level', selectKey: 'SPICE' },
      { key: 'sweet_level', label: 'Sweet Level', selectKey: 'SWEET' },
      { key: 'cooking_style', label: 'Cooking Style', selectKey: 'COOKING_STYLES' }
    ]},
    { title: 'Tags & Focus', fields: [
      { key: 'primary_ingredients', label: 'Hero Ingredient', array: true, hint: 'Planning focus — semicolon-separated; not the full recipe ingredient list' },
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
      { key: 'visibility', label: 'Recipe Visibility', select: _VISIBILITY },
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
      p_active_filter: _activeFilter,
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
    _activeFilter = 'active';
    _page = 1;
  }

  function applyQueuePreset(id, doLoad) {
    clearQueueFilters();
    if (id === 'idea-only') {
      setSel('rnl-research-filter', 'idea_only');
    } else if (id === 'ready-unlinked') {
      setSel('rnl-research-filter', 'ready_to_draft');
      setSel('rnl-linked-filter', 'unlinked');
    } else if (id === 'ready-linked') {
      setSel('rnl-research-filter', 'ready_to_draft');
      setSel('rnl-linked-filter', 'linked');
      setSel('rnl-drift-filter', 'no');
    } else if (id === 'needs-research') {
      setSel('rnl-research-filter', 'needs_research');
    } else if (id === 'verified-unlinked') {
      setSel('rnl-research-filter', 'verified');
      setSel('rnl-linked-filter', 'unlinked');
    } else if (id === 'verified-linked') {
      setSel('rnl-research-filter', 'verified');
      setSel('rnl-linked-filter', 'linked');
      setSel('rnl-drift-filter', 'no');
    } else if (id === 'linked-drift') {
      setSel('rnl-linked-filter', 'linked');
      setSel('rnl-drift-filter', 'yes');
    } else if (id === 'archived') {
      _activeFilter = 'archived';
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
    var restoreBtn = document.getElementById('rnl-bulk-restore');
    var archiveBtn = document.getElementById('rnl-bulk-archive');
    if (!bar) return;
    var n = _selected.size;
    bar.classList.toggle('visible', n > 0);
    if (countEl) countEl.textContent = n + ' selected';
    var archivedSel = _rows.some(function(r) { return _selected.has(r.id) && r.is_active === false; });
    var activeSel = _rows.some(function(r) { return _selected.has(r.id) && r.is_active !== false; });
    if (restoreBtn) restoreBtn.style.display = archivedSel ? '' : 'none';
    if (archiveBtn) archiveBtn.style.display = activeSel ? '' : 'none';
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
      _catRows = cats || [];
      _cats = _catRows.map(function(c) { return c.name || c; }).filter(Boolean);
    } catch (e) {
      console.warn('Dish Index categories', e);
      _catRows = [];
      _cats = [];
    }
    try {
      _taxRows = await rpc('get_recipe_taxonomy', { p_category: null }) || [];
    } catch (e) {
      console.warn('Dish Index taxonomy', e);
      _taxRows = [];
    }
    if (window.tcjOrigin && typeof window.tcjOrigin.allCountries === 'function') {
      _allCountries = window.tcjOrigin.allCountries();
    }
  }

  function catEmoji(name) {
    if (!name) return '';
    return (typeof window.TCJ_CAT_EMOJI !== 'undefined' && window.TCJ_CAT_EMOJI[name]) ? window.TCJ_CAT_EMOJI[name] : '';
  }

  function catsWithEmoji() {
    return _cats.map(function(name) {
      var em = catEmoji(name);
      return { value: name, label: (em ? em + ' ' : '') + name };
    });
  }

  function subsFor(cat) {
    var map = {};
    _taxRows.forEach(function(r) {
      if (String(r.subcategory_category || '').trim() === String(cat || '').trim() && r.subcategory_name) {
        if (!map[r.subcategory_name] && r.subcategory_emoji) map[r.subcategory_name] = r.subcategory_emoji;
        else if (!map[r.subcategory_name]) map[r.subcategory_name] = '';
      }
    });
    return Object.keys(map).sort().map(function(name) {
      var em = map[name];
      return { value: name, label: (em ? em + ' ' : '') + name };
    });
  }

  function divsFor(cat, sub) {
    var map = {};
    _taxRows.forEach(function(r) {
      if (String(r.subcategory_category || '').trim() === String(cat || '').trim() &&
          String(r.subcategory_name || '').trim() === String(sub || '').trim() &&
          r.division_name) {
        if (!map[r.division_name] && r.division_emoji) map[r.division_name] = r.division_emoji;
        else if (!map[r.division_name]) map[r.division_name] = '';
      }
    });
    return Object.keys(map).sort().map(function(name) {
      var em = map[name];
      return { value: name, label: (em ? em + ' ' : '') + name };
    });
  }

  function statesForRow(country) {
    if (!window.tcjOrigin || typeof window.tcjOrigin.statesForCountry !== 'function') return [];
    return window.tcjOrigin.statesForCountry(country).map(function(s) { return { value: s, label: s }; });
  }

  function countriesForSelect() {
    return (_allCountries || []).map(function(n) { return { value: n, label: n }; });
  }

  function labelEnum(map, v) { return map[v] || (v || '').replace(/_/g, ' '); }

  function diEd() { return window.diInlineEditors || {}; }
  function rf() { return window.tcjRecipeFields || {}; }

  function labeledItems(values, labels) {
    return (values || []).map(function(v) {
      return { value: v, label: (labels && labels[v]) ? labels[v] : v };
    });
  }

  function tagValues(r, key) {
    var v = r[key];
    return Array.isArray(v) ? v : (v ? splitList(String(v)) : []);
  }

  function loadColVis() {
    _hiddenCols = new Set();
    try {
      var raw = localStorage.getItem(_COL_VIS_KEY);
      if (raw == null) {
        _DEFAULT_HIDDEN_COLS.forEach(function(k) { _hiddenCols.add(k); });
        return;
      }
      var saved = JSON.parse(raw || '[]');
      if (Array.isArray(saved)) saved.forEach(function(k) { _hiddenCols.add(k); });
    } catch (_) {}
  }

  function saveColVis() {
    try { localStorage.setItem(_COL_VIS_KEY, JSON.stringify(Array.from(_hiddenCols))); } catch (_) {}
  }

  function visibleTableCols() {
    return _TABLE_COLS.filter(function(c) {
      if (c.key === 'select' || c.key === 'dish_code' || c.key === 'recipe_name' || c.key === 'actions') return true;
      return !_hiddenCols.has(c.key);
    });
  }

  function completenessPct(r) {
    var checks = [
      r.recipe_name, r.category, r.sub_category, r.origin_country,
      arrText(r.primary_ingredients), r.introduction, r.difficulty,
      r.prep_time_minutes, r.image_url
    ];
    var filled = 0;
    checks.forEach(function(v) {
      if (v != null && String(v).trim() !== '' && String(v) !== '0') filled++;
    });
    return Math.round(filled / checks.length * 100);
  }

  function completenessChip(r) {
    var pct = completenessPct(r);
    var tone = pct >= 75 ? '#4caf76' : (pct >= 40 ? '#d4a017' : 'var(--text-mid)');
    return '<span class="di-complete-chip" style="color:' + tone + '" title="Metadata completeness (9 key fields)">' + pct + '%</span>';
  }

  function stickyClass(key) {
    if (key === 'select') return ' di-sticky-0';
    if (key === 'dish_code') return ' di-sticky-1';
    if (key === 'recipe_name') return ' di-sticky-2';
    return '';
  }

  function optHtml(values, active, blank) {
    var html = blank ? '<option value="">' + h(blank) + '</option>' : '';
    values.forEach(function(v) {
      var val = (v && typeof v === 'object') ? v.value : v;
      var lbl = (v && typeof v === 'object') ? (v.label || v.value) : v;
      html += '<option value="' + h(val) + '"' + (val === active ? ' selected' : '') + '>' + h(lbl) + '</option>';
    });
    return html;
  }

  function optHtmlLabeled(values, labels, active, blank) {
    var html = blank ? '<option value="">' + h(blank) + '</option>' : '';
    values.forEach(function(v) {
      html += '<option value="' + h(v) + '"' + (v === active ? ' selected' : '') + '>' + h(labels[v] || v) + '</option>';
    });
    return html;
  }

  async function loadQueueCounts() {
    try {
      _queueCounts = await rpc('admin_dish_index_queue_counts', {}) || {};
    } catch (_) {
      _queueCounts = {};
    }
    renderQueuePills();
  }

  function renderColVisPanel() {
    var panel = document.getElementById('rnl-col-vis-panel');
    if (!panel) return;
    panel.innerHTML = '<div class="col-vis-title">Table columns</div>' +
      _TABLE_COLS.filter(function(c) { return c.key !== 'select' && c.key !== 'actions'; }).map(function(c) {
        var checked = !_hiddenCols.has(c.key);
        return '<label class="col-vis-row"><input type="checkbox" data-col="' + h(c.key) + '"' + (checked ? ' checked' : '') + '> ' + h(c.label || c.key) + '</label>';
      }).join('') +
      '<div style="margin-top:10px;display:flex;gap:8px">' +
        '<button type="button" class="bulk-clear-btn" id="rnl-col-vis-reset" style="flex:1">Show all</button>' +
        '<button type="button" class="bulk-apply-btn" id="rnl-col-vis-close" style="flex:1">Done</button>' +
      '</div>';
    panel.querySelectorAll('input[data-col]').forEach(function(cb) {
      cb.addEventListener('change', function() {
        if (cb.checked) _hiddenCols.delete(cb.dataset.col);
        else _hiddenCols.add(cb.dataset.col);
        saveColVis();
        renderTable();
      });
    });
    var reset = document.getElementById('rnl-col-vis-reset');
    if (reset) reset.onclick = function() {
      _hiddenCols.clear();
      saveColVis();
      renderColVisPanel();
      renderTable();
    };
    var close = document.getElementById('rnl-col-vis-close');
    if (close) close.onclick = function() { panel.classList.remove('open'); };
  }

  function renderShell(root) {
    root.innerHTML =
      '<div class="di-panel">' +
        '<div class="di-panel-head">' +
          '<p class="di-intro"><strong>Dish Index v' + _SHELL_VERSION + '</strong> — Canonical dish registry (schema <code>' + _SCHEMA_VERSION + '</code>). Queue pills partition active dishes (counts add up to All); Archived is separate. Dropdowns are searchable — click × to clear. Cooking style sets metadata only; edit prep/cook/extra minutes per row. Ingredients and method stay in Submit a Recipe.</p>' +
          '<div class="di-actions">' +
            '<button type="button" class="ing-add-btn" id="rnl-add-btn">+ Add dish</button>' +
            '<button type="button" class="ing-add-btn" id="rnl-import-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Import CSV</button>' +
            '<button type="button" class="ing-add-btn" id="rnl-export-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Export CSV</button>' +
            '<button type="button" class="ing-add-btn" id="rnl-print-btn" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Print selected linked</button>' +
            '<button type="button" class="ing-add-btn" id="rnl-dup-btn" style="background:none;border:1px solid rgba(220,80,80,0.45);color:#dc5050">Duplicates</button>' +
            '<button type="button" class="ing-add-btn" id="rnl-cov-btn" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Coverage gaps</button>' +
            '<button type="button" class="ing-add-btn" id="rnl-col-vis-btn" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Columns</button>' +
            '<input type="file" id="rnl-file" accept=".csv,text/csv" style="display:none">' +
          '</div>' +
        '</div>' +
        '<div class="di-section-label">Queue</div>' +
        '<div id="rnl-queue-row" class="di-queue-row"></div>' +
        '<div class="di-section-label">Filters</div>' +
        '<div class="di-filters">' +
          '<input type="text" class="ap-search" id="rnl-search" placeholder="Search name, DI#, country…">' +
          '<select id="rnl-category-filter" class="ing-cat-filter" title="Category"><option value="">All categories</option></select>' +
          '<select id="rnl-sub-filter" class="ing-cat-filter" title="Sub-category"><option value="">All sub-categories</option></select>' +
          '<select id="rnl-div-filter" class="ing-cat-filter" title="Division"><option value="">All divisions</option></select>' +
          '<select id="rnl-research-filter" class="ing-cat-filter"><option value="">All research</option>' + optHtmlLabeled(_RESEARCH, _RESEARCH_LABELS, '', null) + '</select>' +
          '<select id="rnl-content-filter" class="ing-cat-filter"><option value="">All content</option>' + optHtmlLabeled(_CONTENT, _CONTENT_LABELS, '', null) + '</select>' +
          '<select id="rnl-linked-filter" class="ing-cat-filter"><option value="">Linked + unlinked</option><option value="linked">Linked only</option><option value="unlinked">Unlinked only</option></select>' +
          '<select id="rnl-drift-filter" class="ing-cat-filter"><option value="">Any sync state</option><option value="yes">Drift (index ≠ recipe)</option><option value="no">In sync</option></select>' +
          '<label class="di-archived-toggle"><input type="checkbox" id="rnl-archived-filter"> Include archived</label>' +
        '</div>' +
        '<div id="rnl-bulk-bar" class="bulk-toolbar">' +
          '<span class="bulk-count" id="rnl-bulk-count">0 selected</span>' +
          '<select id="rnl-bulk-category" class="ing-cat-filter"><option value="">Category…</option></select>' +
          '<select id="rnl-bulk-sub" class="ing-cat-filter"><option value="">Sub…</option></select>' +
          '<select id="rnl-bulk-div" class="ing-cat-filter"><option value="">Division…</option></select>' +
          '<button type="button" class="bulk-apply-btn" id="rnl-bulk-taxonomy">Apply taxonomy</button>' +
          '<select id="rnl-bulk-research" class="ing-cat-filter"><option value="">Research…</option>' + optHtmlLabeled(_RESEARCH, _RESEARCH_LABELS, '', null) + '</select>' +
          '<select id="rnl-bulk-content" class="ing-cat-filter"><option value="">Content…</option>' + optHtmlLabeled(_CONTENT, _CONTENT_LABELS, '', null) + '</select>' +
          '<button type="button" class="bulk-apply-btn" id="rnl-bulk-status">Apply status</button>' +
          '<button type="button" class="bulk-apply-btn" id="rnl-bulk-push" title="Push index metadata to linked recipes">Push → recipe</button>' +
          '<button type="button" class="bulk-apply-btn" id="rnl-bulk-pull" title="Pull metadata from linked recipes into index">Pull ← recipe</button>' +
          '<button type="button" class="bulk-clear-btn" id="rnl-bulk-archive">Archive</button>' +
          '<button type="button" class="bulk-clear-btn" id="rnl-bulk-restore" style="display:none">Restore</button>' +
          '<button type="button" class="bulk-clear-btn" id="rnl-bulk-merge">Merge duplicates</button>' +
          '<button type="button" class="bulk-clear-btn" id="rnl-bulk-clear">Clear</button>' +
        '</div>' +
        '<div id="rnl-count" class="di-count"></div>' +
        '<div class="ap-table-wrap di-table-wrap">' +
          '<table class="ap-table" id="rnl-table"><thead></thead><tbody id="rnl-tbody"><tr><td class="ap-empty-row">Loading...</td></tr></tbody></table>' +
        '</div>' +
        '<div id="rnl-pagination" style="display:none;align-items:center;justify-content:center;gap:8px;margin-top:14px"></div>' +
      '</div>' +
      '<div id="rnl-col-vis-panel" class="col-vis-panel"></div>' +
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
          '</div></div></div>' +
      '<div id="rnl-dup-backdrop" class="csv-modal-overlay" style="z-index:1201">' +
        '<div class="csv-modal" style="max-width:960px">' +
          '<div class="csv-modal-head"><div class="csv-modal-title">Duplicate clusters</div><button type="button" class="ing-modal-close" id="rnl-dup-close">✕</button></div>' +
          '<div class="csv-modal-body">' +
            '<p id="rnl-dup-summary" style="font-size:13px;color:var(--text-mid);margin:0 0 12px">Scanning…</p>' +
            '<input type="text" class="ap-search" id="rnl-dup-filter" placeholder="Filter clusters by name, DI#, country…" style="width:100%;max-width:none;margin-bottom:12px">' +
            '<div id="rnl-dup-list" style="max-height:420px;overflow:auto"></div>' +
          '</div></div></div>' +
      '<div id="rnl-cov-backdrop" class="csv-modal-overlay" style="z-index:1201">' +
        '<div class="csv-modal" style="max-width:920px">' +
          '<div class="csv-modal-head"><div class="csv-modal-title">Coverage gaps</div><button type="button" class="ing-modal-close" id="rnl-cov-close">✕</button></div>' +
          '<div class="csv-modal-body" id="rnl-cov-content" style="max-height:480px;overflow:auto"><p style="font-size:13px;color:var(--text-mid)">Loading…</p></div>' +
        '</div></div>';
    renderQueuePills();
  }

  function renderQueuePills() {
    var row = document.getElementById('rnl-queue-row');
    if (!row) return;
    row.innerHTML = _QUEUE_PRESETS.map(function(q) {
      var ck = _QUEUE_COUNT_KEYS[q.id];
      var n = ck && _queueCounts[ck] != null ? _queueCounts[ck] : null;
      var suffix = n != null ? ' (' + n + ')' : '';
      return '<button type="button" class="ap-filter-btn rnl-queue-pill" data-queue="' + h(q.id) + '">' + h(q.label) + suffix + '</button>';
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
    var table = document.getElementById('rnl-table');
    if (table && !table.dataset.sortBound) {
      table.dataset.sortBound = '1';
      table.addEventListener('click', function(e) {
        var th = e.target.closest('th.rnl-sort');
        if (!th || !th.dataset.col) return;
        var col = th.dataset.col;
        if (_sort.column === col) _sort.direction = _sort.direction === 'asc' ? 'desc' : 'asc';
        else _sort = { column: col, direction: 'asc' };
        _page = 1;
        loadRows();
      });
    }
    ['rnl-category-filter', 'rnl-sub-filter', 'rnl-div-filter', 'rnl-research-filter', 'rnl-content-filter', 'rnl-linked-filter', 'rnl-drift-filter', 'rnl-archived-filter'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.addEventListener('change', function() {
        _page = 1;
        if (id === 'rnl-archived-filter') {
          _activeFilter = el.checked ? 'all' : 'active';
          document.querySelectorAll('.rnl-queue-pill').forEach(function(btn) {
            if (btn.dataset.queue === 'archived') btn.classList.remove('active');
          });
        }
        if (id === 'rnl-category-filter') fillSubDivFilters();
        if (id === 'rnl-sub-filter') {
          var cat = (document.getElementById('rnl-category-filter') || {}).value || '';
          var divSel = document.getElementById('rnl-div-filter');
          if (divSel) {
            divSel.innerHTML = '<option value="">All divisions</option>' + divsFor(cat, el.value).map(function(d) {
              return '<option value="' + h(d.value) + '">' + h(d.label) + '</option>';
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
    var dupBtn = document.getElementById('rnl-dup-btn');
    if (dupBtn) dupBtn.addEventListener('click', function() { loadDupClusters(false); });
    var covBtn = document.getElementById('rnl-cov-btn');
    if (covBtn) covBtn.addEventListener('click', loadCoverageGaps);
    var dupClose = document.getElementById('rnl-dup-close');
    if (dupClose) dupClose.onclick = closeDupModal;
    var covClose = document.getElementById('rnl-cov-close');
    if (covClose) covClose.onclick = closeCovModal;
    var dupFilter = document.getElementById('rnl-dup-filter');
    if (dupFilter) dupFilter.addEventListener('input', function() { clearTimeout(t); t = setTimeout(renderDupClusters, 200); });
    var colVisBtn = document.getElementById('rnl-col-vis-btn');
    if (colVisBtn) colVisBtn.addEventListener('click', function() {
      var panel = document.getElementById('rnl-col-vis-panel');
      if (!panel) return;
      renderColVisPanel();
      panel.classList.toggle('open');
    });
    document.addEventListener('click', function(e) {
      var panel = document.getElementById('rnl-col-vis-panel');
      var btn = document.getElementById('rnl-col-vis-btn');
      if (!panel || !panel.classList.contains('open')) return;
      if (panel.contains(e.target) || (btn && btn.contains(e.target))) return;
      panel.classList.remove('open');
    });
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
    document.getElementById('rnl-bulk-restore').onclick = bulkRestore;
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
        var em = catEmoji(c);
        o.textContent = (em ? em + ' ' : '') + c;
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
        return '<option value="' + h(s.value) + '">' + h(s.label) + '</option>';
      }).join('');
    }
    if (divSel) {
      var sub = (subSel && subSel.value) || '';
      divSel.innerHTML = '<option value="">All divisions</option>' + divsFor(cat, sub).map(function(d) {
        return '<option value="' + h(d.value) + '">' + h(d.label) + '</option>';
      }).join('');
    }
  }

  function fillBulkSubDiv() {
    var cat = (document.getElementById('rnl-bulk-category') || {}).value || '';
    var subSel = document.getElementById('rnl-bulk-sub');
    var divSel = document.getElementById('rnl-bulk-div');
    if (subSel) {
      subSel.innerHTML = '<option value="">Sub…</option>' + subsFor(cat).map(function(s) {
        return '<option value="' + h(s.value) + '">' + h(s.label) + '</option>';
      }).join('');
    }
    if (divSel) {
      divSel.innerHTML = '<option value="">Division…</option>' + divsFor(cat, (subSel && subSel.value) || '').map(function(d) {
        return '<option value="' + h(d.value) + '">' + h(d.label) + '</option>';
      }).join('');
    }
  }

  async function loadRows() {
    var cols = visibleTableCols();
    var tbody = document.getElementById('rnl-tbody');
    if (tbody) tbody.innerHTML = '<tr><td colspan="' + cols.length + '" class="ap-empty-row">Loading...</td></tr>';
    try {
      var result = await rpc('admin_list_recipe_name_library', Object.assign({ p_limit: _PAGE_SIZE, p_offset: (_page - 1) * _PAGE_SIZE }, listFilters()));
      _rows = (result && result.rows) || [];
      _total = parseInt(result && result.total, 10) || 0;
      renderTable();
      renderPagination();
      loadQueueCounts();
    } catch (e) {
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="' + cols.length + '" class="ap-empty-row">Error: ' + h(e.message || e) +
          '<br>Run Dish Index SQL in order (steps 1–6) — see <code>database/sql/run-dish-index-migrations.ps1</code> or run each file in Supabase SQL Editor.</td></tr>';
      }
    }
  }

  function renderTable() {
    var cols = visibleTableCols();
    var table = document.getElementById('rnl-table');
    var tbody = document.getElementById('rnl-tbody');
    var count = document.getElementById('rnl-count');
    if (!table || !tbody) return;
    if (count) {
      var start = _total ? ((_page - 1) * _PAGE_SIZE) + 1 : 0;
      var end = Math.min(_page * _PAGE_SIZE, _total);
      count.textContent = _total + ' dish' + (_total === 1 ? '' : 'es') + (_total ? ' (showing ' + start + '-' + end + ')' : '');
    }
    table.querySelector('thead').innerHTML = '<tr>' + cols.map(function(c) {
      var sc = stickyClass(c.key);
      if (c.key === 'select') return '<th class="' + sc.trim() + '" style="width:36px;min-width:36px;max-width:36px"><input type="checkbox" id="rnl-select-all"></th>';
      if (c.key === 'actions' || c.key === 'linked_recipe_name') return '<th class="' + sc.trim() + '">' + h(c.label) + '</th>';
      if (c.fixed && !c.sortable) return '<th class="' + sc.trim() + '">' + h(c.label) + '</th>';
      var arrow = _sort.column === c.key ? (_sort.direction === 'asc' ? ' ▲' : ' ▼') : '';
      var w = c.w ? 'min-width:' + c.w + 'px;' : '';
      return '<th class="rnl-sort' + sc + '" data-col="' + h(c.key) + '" style="cursor:pointer;white-space:nowrap;' + w + '">' + h(c.label) + arrow + '</th>';
    }).join('') + '</tr>';
    tbody.innerHTML = '';
    if (!_rows.length) {
      tbody.innerHTML = '<tr><td colspan="' + cols.length + '" class="ap-empty-row">No dishes yet. Add one or import a CSV.</td></tr>';
      return;
    }
    _rows.forEach(function(r) {
      var tr = document.createElement('tr');
      tr.dataset.id = r.id;
      if (r.is_active === false) tr.classList.add('rnl-archived');
      tr.innerHTML = cols.map(function(c) { return renderCell(r, c); }).join('');
      tbody.appendChild(tr);
    });
    bindTableEvents();
    syncDiStickyOffsets();
  }

  function syncDiStickyOffsets() {
    var wrap = document.querySelector('.di-table-wrap');
    var table = document.getElementById('rnl-table');
    if (!wrap || !table) return;
    var head = table.querySelector('thead tr');
    if (!head) return;
    var s0 = head.querySelector('th.di-sticky-0');
    var s1 = head.querySelector('th.di-sticky-1');
    var s2 = head.querySelector('th.di-sticky-2');
    if (!s0 || !s1 || !s2) return;
    var w0 = s0.offsetWidth;
    var w1 = s1.offsetWidth;
    var w2 = s2.offsetWidth;
    wrap.style.setProperty('--di-sticky-w0', w0 + 'px');
    wrap.style.setProperty('--di-sticky-w1', w1 + 'px');
    wrap.style.setProperty('--di-sticky-w2', w2 + 'px');
    wrap.style.setProperty('--di-sticky-left1', w0 + 'px');
    wrap.style.setProperty('--di-sticky-left2', (w0 + w1) + 'px');
  }

  function renderCell(r, c) {
    var sc = stickyClass(c.key);
    var archived = r.is_active === false;
    if (c.key === 'select') {
      return '<td class="' + sc.trim() + '"><input type="checkbox" class="rnl-row-cb" value="' + h(r.id) + '"' + (_selected.has(r.id) ? ' checked' : '') + '></td>';
    }
    if (c.key === 'actions') {
      var menu = '';
      if (r.has_drift) menu += '<button type="button" class="di-act-item rnl-drift" role="menuitem">⚠ View drift</button>';
      if (r.linked_recipe_id) {
        menu += '<button type="button" class="di-act-item rnl-sync-push" role="menuitem">Push index → recipe</button>';
        menu += '<button type="button" class="di-act-item rnl-sync-pull" role="menuitem">Pull recipe → index</button>';
        menu += '<button type="button" class="di-act-item rnl-unlink" role="menuitem">Unlink recipe</button>';
        menu += '<button type="button" class="di-act-item rnl-print-one" data-id="' + h(r.linked_recipe_id) + '" role="menuitem">Print linked recipe</button>';
      } else if (!archived) {
        menu += '<button type="button" class="di-act-item rnl-create" role="menuitem">Create recipe draft</button>';
        menu += '<button type="button" class="di-act-item rnl-link" role="menuitem">Link existing recipe</button>';
      }
      if (archived) {
        menu += '<button type="button" class="di-act-item di-act-good rnl-restore" role="menuitem">Restore dish</button>';
      } else {
        menu += '<button type="button" class="di-act-item di-act-danger rnl-delete" role="menuitem">Archive dish</button>';
      }
      return '<td class="di-actions-cell"><div class="di-row-actions">' +
        '<button type="button" class="rm-quick-btn di-act-primary rnl-edit-btn">Edit</button>' +
        '<div class="di-act-menu-wrap">' +
          '<button type="button" class="rm-quick-btn di-act-more" aria-haspopup="true" aria-expanded="false">More ▾</button>' +
          '<div class="di-act-menu" role="menu">' + menu + '</div>' +
        '</div>' +
      '</div></td>';
    }
    if (c.key === 'dish_code') {
      var driftMark = r.has_drift ? '<span title="Drift from linked recipe" style="color:#d4a017;margin-left:4px">⚠</span>' : '';
      return '<td class="' + sc.trim() + '"><div style="display:flex;align-items:center;gap:2px;min-width:0">' +
        '<input class="rnl-edit" data-field="dish_code" value="' + h(r.dish_code || '') + '" title="Unique dish code — e.g. DI000042"' +
        ' style="width:100%;min-width:72px;padding:5px 6px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:11px;font-family:ui-monospace,monospace">' +
        driftMark + '</div></td>';
    }
    if (c.key === 'recipe_name') {
      return '<td class="' + sc.trim() + '"><div style="display:flex;align-items:center;gap:6px;min-width:0">' +
        completenessChip(r) +
        '<input class="rnl-edit" data-field="recipe_name" value="' + h(r.recipe_name || '') + '" style="flex:1;min-width:0;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px">' +
      '</div></td>';
    }
    if (c.key === 'linked_recipe_name') {
      var txt = r.linked_recipe_id ? ((r.linked_recipe_code ? r.linked_recipe_code + ' · ' : '') + (r.linked_recipe_name || r.linked_recipe_id) + (r.linked_recipe_status ? ' (' + r.linked_recipe_status + ')' : '')) : 'Unlinked';
      return '<td style="min-width:180px;color:' + (r.linked_recipe_id ? 'var(--text-high)' : 'var(--text-mid)') + '">' + h(txt) + '</td>';
    }
    if (c.key === 'category') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, catsWithEmoji(), r[c.key], 'Search category…') : '') + '</td>';
    if (c.key === 'sub_category') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, subsFor(r.category), r[c.key], 'Search sub…') : '') + '</td>';
    if (c.key === 'division') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, divsFor(r.category, r.sub_category), r[c.key], 'Search division…') : '') + '</td>';
    if (c.key === 'origin_country') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, countriesForSelect(), r[c.key], 'Search country…') : '') + '</td>';
    if (c.key === 'origin_state') {
      var stOpts = statesForRow(r.origin_country);
      var stDis = !r.origin_country;
      return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, stOpts, r[c.key], stDis ? 'Pick country first' : 'Search state…', stDis) : '') + '</td>';
    }
    if (c.key === 'source_type') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, labeledItems(_SOURCE_TYPES, _SOURCE_LABELS), r[c.key] || 'Original', 'Search source…') : '') + '</td>';
    if (c.key === 'visibility') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, _VISIBILITY.map(function(v) { return { value: v, label: v }; }), r[c.key] || 'Private', 'Search…') : '') + '</td>';
    if (c.key === 'research_status') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, labeledItems(_RESEARCH, _RESEARCH_LABELS), r[c.key] || 'idea_only', 'Research…') : '') + '</td>';
    if (c.key === 'content_status') return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, labeledItems(_CONTENT, _CONTENT_LABELS), r[c.key] || 'not_started', 'Content…') : '') + '</td>';
    if (c.key === 'cooking_style') {
      var styles = (rf().COOKING_STYLES || []).slice();
      return '<td>' + (diEd().comboCell ? diEd().comboCell(c.key, styles, r[c.key] || '', 'Cooking style…') : '') + '</td>';
    }
    if (c.level) return '<td class="di-level-td">' + (diEd().levelCell ? diEd().levelCell(c.key, c.level, r[c.key] || '') : '') + '</td>';
    if (c.tags) {
      var opts = rf().tagOptions ? rf().tagOptions(c.key) : [];
      return '<td>' + (diEd().tagCell ? diEd().tagCell(c.key, opts, tagValues(r, c.key)) : '') + '</td>';
    }
    if (c.number) {
      var num = r[c.key] == null ? '' : r[c.key];
      var nw = c.w ? 'min-width:' + c.w + 'px;' : 'min-width:64px;';
      return '<td><input type="number" min="0" class="rnl-edit" data-field="' + h(c.key) + '" value="' + h(num) + '" style="' + nw + 'width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px"></td>';
    }
    var val = c.array ? arrText(r[c.key]) : (r[c.key] == null ? '' : r[c.key]);
    var w2 = c.w ? 'min-width:' + c.w + 'px;' : 'min-width:80px;';
    var title = c.array ? ' title="Semicolon-separated"' : '';
    return '<td><input class="rnl-edit" data-field="' + h(c.key) + '" value="' + h(val) + '"' + title + ' style="' + w2 + 'width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px"></td>';
  }

  function selectCell(field, options, active, blank) {
    return '<select class="rnl-edit" data-field="' + h(field) + '" style="min-width:130px;width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px">' +
      optHtml(options, active || '', blank) + '</select>';
  }

  function selectCellLabeled(field, options, labels, active, blank) {
    return '<select class="rnl-edit" data-field="' + h(field) + '" style="min-width:130px;width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px">' +
      optHtmlLabeled(options, labels, active || '', blank) + '</select>';
  }

  function bindTableEvents() {
    var tbody = document.getElementById('rnl-tbody');
    if (diEd().bindAll) diEd().bindAll(tbody);
    var all = document.getElementById('rnl-select-all');
    if (all) all.addEventListener('change', function() {
      document.querySelectorAll('.rnl-row-cb').forEach(function(cb) {
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
    document.querySelectorAll('.rnl-restore').forEach(function(btn) { btn.addEventListener('click', restoreRow); });
    document.querySelectorAll('.rnl-link').forEach(function(btn) { btn.addEventListener('click', openLinkModal); });
    document.querySelectorAll('.rnl-unlink').forEach(function(btn) { btn.addEventListener('click', unlinkRow); });
    document.querySelectorAll('.rnl-sync-push').forEach(function(btn) { btn.addEventListener('click', syncPushOne); });
    document.querySelectorAll('.rnl-sync-pull').forEach(function(btn) { btn.addEventListener('click', syncPullOne); });
    document.querySelectorAll('.rnl-drift').forEach(function(btn) { btn.addEventListener('click', showDrift); });
    document.querySelectorAll('.rnl-print-one').forEach(function(btn) {
      btn.addEventListener('click', function() { window.open('print-studio.html?id=' + encodeURIComponent(btn.dataset.id), '_blank'); });
    });
    document.querySelectorAll('.di-act-more').forEach(function(btn) {
      btn.addEventListener('click', function(e) {
        e.stopPropagation();
        var wrap = btn.closest('.di-act-menu-wrap');
        var open = wrap && wrap.classList.contains('open');
        document.querySelectorAll('.di-act-menu-wrap.open').forEach(function(w) { w.classList.remove('open'); });
        if (wrap && !open) {
          wrap.classList.add('open');
          btn.setAttribute('aria-expanded', 'true');
        } else if (btn) {
          btn.setAttribute('aria-expanded', 'false');
        }
      });
    });
    document.querySelectorAll('.di-act-menu-wrap').forEach(function(wrap) {
      wrap.addEventListener('click', function(e) { e.stopPropagation(); });
    });
    document.querySelectorAll('.di-act-item').forEach(function(item) {
      item.addEventListener('click', function() {
        var w = item.closest('.di-act-menu-wrap');
        if (w) w.classList.remove('open');
      });
    });
    if (!window._diActMenuCloseBound) {
      window._diActMenuCloseBound = true;
      document.addEventListener('click', function() {
        document.querySelectorAll('.di-act-menu-wrap.open').forEach(function(w) {
          w.classList.remove('open');
          var b = w.querySelector('.di-act-more');
          if (b) b.setAttribute('aria-expanded', 'false');
        });
      });
    }
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
    if (f.photo) {
      var preview = val ? '<img src="' + h(val) + '" alt="" class="di-photo-preview" style="display:block;max-width:200px;max-height:160px;border-radius:10px;margin-top:10px;border:1px solid var(--border)">' : '';
      return '<div class="di-photo-field">' +
        '<input type="file" accept="image/jpeg,image/png,image/webp" class="di-photo-file" style="display:none">' +
        '<div style="display:flex;gap:8px;flex-wrap:wrap">' +
          '<button type="button" class="ing-add-btn di-photo-pick" style="background:none;border:1px solid var(--accent);color:var(--accent)">Upload photo</button>' +
          '<button type="button" class="ing-add-btn di-photo-clear" style="background:none;border:1px solid var(--border);color:var(--text-mid);' + (val ? '' : 'display:none') + '">Remove</button>' +
        '</div>' +
        preview +
        '<input type="hidden" data-field="' + h(f.key) + '" value="' + h(val) + '">' +
      '</div>' + hint;
    }
    if (f.taxonomy === 'category') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(catsWithEmoji(), val, 'Category...') + '</select>' + hint;
    }
    if (f.taxonomy === 'sub') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(subsFor(r.category), val, 'Sub-category...') + '</select>' + hint;
    }
    if (f.taxonomy === 'div') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(divsFor(r.category, r.sub_category), val, 'Division...') + '</select>' + hint;
    }
    if (f.key === 'origin_country') {
      return '<select data-field="origin_country" style="' + common + '">' + optHtml(countriesForSelect(), val, 'Country...') + '</select>' + hint;
    }
    if (f.key === 'origin_state') {
      return '<select data-field="origin_state" style="' + common + '">' + optHtml(statesForRow(r.origin_country), val, 'State / Province...') + '</select>' + hint;
    }
    if (f.key === 'origin_continent') {
      return '<input data-field="origin_continent" value="' + h(val) + '" readonly style="' + common + ';opacity:0.75;cursor:default" title="Auto-filled from country or state">' + hint;
    }
    if (f.select || f.selectKey) {
      if (f.key === 'research_status') {
        return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtmlLabeled(_RESEARCH, _RESEARCH_LABELS, val, '') + '</select>' + hint;
      }
      if (f.key === 'content_status') {
        return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtmlLabeled(_CONTENT, _CONTENT_LABELS, val, '') + '</select>' + hint;
      }
      if (f.key === 'source_type') {
        return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtmlLabeled(_SOURCE_TYPES, _SOURCE_LABELS, val, '') + '</select>' + hint;
      }
      var opts = f.selectKey ? (rf()[f.selectKey] || []) : f.select;
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(opts, val, '') + '</select>' + hint;
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
        '<button type="button" class="rm-quick-btn" id="rnl-editor-close">Close</button>' +
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
    modal.querySelectorAll('[data-field="origin_country"]').forEach(function(el) {
      el.addEventListener('change', function() {
        if (window.tcjOrigin) window.tcjOrigin.applyOriginPick(_editRow, 'origin_country', el.value);
        openRowEditor(_editRow);
      });
    });
    modal.querySelectorAll('[data-field="origin_state"]').forEach(function(el) {
      el.addEventListener('change', function() {
        if (window.tcjOrigin) window.tcjOrigin.applyOriginPick(_editRow, 'origin_state', el.value);
        openRowEditor(_editRow);
      });
    });
    modal.querySelectorAll('.di-photo-field').forEach(function(wrap) {
      var fileInput = wrap.querySelector('.di-photo-file');
      var pickBtn = wrap.querySelector('.di-photo-pick');
      var clearBtn = wrap.querySelector('.di-photo-clear');
      var hidden = wrap.querySelector('[data-field="image_url"]');
      var preview = wrap.querySelector('.di-photo-preview');
      if (pickBtn && fileInput) {
        pickBtn.onclick = function() { fileInput.click(); };
        fileInput.onchange = async function() {
          var file = fileInput.files && fileInput.files[0];
          if (!file) return;
          if (!/^image\/(jpeg|png|webp)$/i.test(file.type)) {
            alert('Please choose a JPEG, PNG, or WebP photo.');
            return;
          }
          pickBtn.disabled = true;
          pickBtn.textContent = 'Uploading…';
          try {
            var url = typeof window.tcjUploadRecipeImage === 'function'
              ? await window.tcjUploadRecipeImage(file)
              : null;
            if (!url) throw new Error('Photo upload is not available.');
            _editRow.image_url = url;
            if (hidden) hidden.value = url;
            if (preview) {
              preview.src = url;
              preview.style.display = 'block';
            } else {
              var img = document.createElement('img');
              img.src = url;
              img.alt = '';
              img.className = 'di-photo-preview';
              img.style.cssText = 'display:block;max-width:200px;max-height:160px;border-radius:10px;margin-top:10px;border:1px solid var(--border)';
              wrap.appendChild(img);
            }
            if (clearBtn) clearBtn.style.display = '';
          } catch (err) {
            alert(err.message || err);
          } finally {
            pickBtn.disabled = false;
            pickBtn.textContent = 'Upload photo';
            fileInput.value = '';
          }
        };
      }
      if (clearBtn) {
        clearBtn.onclick = function() {
          _editRow.image_url = '';
          if (hidden) hidden.value = '';
          if (preview) preview.remove();
          clearBtn.style.display = 'none';
        };
      }
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
    if (_ARRAY_FIELDS.indexOf(field) >= 0) {
      r[field] = splitList(el.value);
    } else if (field === 'dish_code') {
      r[field] = String(el.value || '').trim().toUpperCase();
      el.value = r[field];
    } else if (field === 'prep_time_minutes' || field === 'cook_time_minutes' || field === 'additional_time_minutes' || field === 'servings') {
      r[field] = el.value === '' ? '' : String(parseInt(el.value, 10) || 0);
    } else {
      r[field] = el.value;
    }
    if (field === 'category') { r.sub_category = ''; r.division = ''; }
    if (field === 'sub_category') { r.division = ''; }
    if (field === 'origin_country') {
      if (!el.value) r.origin_state = '';
      if (window.tcjOrigin) window.tcjOrigin.applyOriginPick(r, field, el.value);
    } else if (field === 'origin_state' && window.tcjOrigin) {
      window.tcjOrigin.applyOriginPick(r, field, el.value);
    }
    el.style.borderColor = 'var(--accent)';
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: rowToPayload(r) });
      el.style.borderColor = 'var(--border)';
      if (field === 'category' || field === 'sub_category' || field === 'origin_country') renderTable();
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
    if (!confirm('Archive ' + ids.length + ' dish row(s)? Use Archived queue or Include archived to view them later.')) return;
    try {
      await rpc('admin_bulk_update_recipe_name_library', { p_ids: ids, p_fields: { is_active: false, content_status: 'retired' } });
      ids.forEach(function(id) { _selected.delete(id); });
      await loadRows();
    } catch (e) { alert(e.message || e); }
  }

  async function bulkRestore() {
    var ids = selectedIds().filter(function(id) {
      var r = _rows.find(function(x) { return x.id === id; });
      return r && r.is_active === false;
    });
    if (!ids.length) return alert('Select archived rows to restore.');
    if (!confirm('Restore ' + ids.length + ' archived dish row(s)?')) return;
    try {
      var res = await rpc('admin_restore_recipe_name_library', { p_ids: ids });
      alert('Restored ' + (res.restored || 0) + ' row(s).');
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
    if (!confirm('Archive this Dish Index row? Use the Archived queue to view or restore it. Linked recipes are not deleted.')) return;
    try {
      await rpc('admin_bulk_update_recipe_name_library', { p_ids: [id], p_fields: { is_active: false, content_status: 'retired' } });
      _selected.delete(id);
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  async function restoreRow(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Restore this dish to the active index?')) return;
    try {
      await rpc('admin_restore_recipe_name_library', { p_ids: [id] });
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

  function closeDupModal() {
    var backdrop = document.getElementById('rnl-dup-backdrop');
    if (backdrop) backdrop.classList.remove('open');
  }

  function closeCovModal() {
    var backdrop = document.getElementById('rnl-cov-backdrop');
    if (backdrop) backdrop.classList.remove('open');
  }

  function dupClusterMatchesFilter(cluster, q) {
    if (!q) return true;
    q = q.toLowerCase();
    if ((cluster.group_key || '').toLowerCase().indexOf(q) >= 0) return true;
    return (cluster.rows || []).some(function(r) {
      return [r.recipe_name, r.dish_code, r.native_name, r.origin_country, r.category].some(function(v) {
        return String(v || '').toLowerCase().indexOf(q) >= 0;
      });
    });
  }

  function renderDupClusters() {
    var list = document.getElementById('rnl-dup-list');
    var summary = document.getElementById('rnl-dup-summary');
    var filterEl = document.getElementById('rnl-dup-filter');
    if (!list) return;
    var q = filterEl ? filterEl.value.trim() : '';
    var clusters = (_dupClusters || []).filter(function(c) { return dupClusterMatchesFilter(c, q); });
    if (summary) {
      summary.textContent = clusters.length + ' cluster' + (clusters.length === 1 ? '' : 's') +
        ' shown' + (_dupClusters.length !== clusters.length ? ' (filtered from ' + _dupClusters.length + ')' : '') +
        ' — pick the row to keep, then merge extras into it.';
    }
    if (!clusters.length) {
      list.innerHTML = '<p style="font-size:13px;color:var(--text-mid);padding:8px 0">No duplicate name clusters found.</p>';
      return;
    }
    list.innerHTML = clusters.map(function(cluster, ci) {
      var rows = cluster.rows || [];
      var title = (rows[0] && rows[0].recipe_name) || cluster.group_key || 'Cluster';
      var body = rows.map(function(r, ri) {
        var meta = [r.dish_code, r.origin_country, r.category].filter(Boolean).join(' · ');
        var linked = r.linked_recipe_id ? ' · linked' : '';
        return '<label style="display:flex;align-items:flex-start;gap:8px;padding:6px 0;font-size:12px;color:var(--text-mid);cursor:pointer">' +
          '<input type="radio" name="rnl-dup-keep-' + ci + '" value="' + h(r.id) + '"' + (ri === 0 ? ' checked' : '') + ' style="margin-top:2px">' +
          '<span><strong style="color:var(--text-high)">' + h(r.recipe_name || '—') + '</strong>' +
          (meta ? '<span style="display:block;font-size:11px;margin-top:2px">' + h(meta) + linked + '</span>' : '') +
          '</span></label>';
      }).join('');
      return '<div class="di-dup-cluster" data-cluster="' + ci + '" style="margin-bottom:12px;padding:12px 14px;background:rgba(220,80,80,0.04);border:1px solid rgba(220,80,80,0.2);border-radius:10px">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:8px">' +
          '<div style="font-size:13px;font-weight:600;color:var(--text-high)">' + h(title) + ' <span style="font-weight:400;color:var(--text-mid)">(' + (cluster.count || rows.length) + ' rows)</span></div>' +
          '<button type="button" class="bulk-apply-btn rnl-dup-merge-btn" data-cluster="' + ci + '">Merge cluster</button>' +
        '</div>' + body + '</div>';
    }).join('');
    list.querySelectorAll('.rnl-dup-merge-btn').forEach(function(btn) {
      btn.addEventListener('click', function() { mergeDupCluster(parseInt(btn.dataset.cluster, 10)); });
    });
  }

  async function mergeDupCluster(clusterIndex) {
    var cluster = (_dupClusters || [])[clusterIndex];
    if (!cluster || !(cluster.rows || []).length) return;
    var card = document.querySelector('.di-dup-cluster[data-cluster="' + clusterIndex + '"]');
    var keepInput = card && card.querySelector('input[type="radio"]:checked');
    var keep = keepInput && keepInput.value;
    if (!keep) return alert('Pick the row to keep.');
    var mergeIds = (cluster.rows || []).map(function(r) { return r.id; }).filter(function(id) { return id !== keep; });
    if (!mergeIds.length) return;
    if (!confirm('Merge ' + mergeIds.length + ' duplicate row(s) into the selected keeper? Merged rows are archived.')) return;
    var merged = 0;
    for (var i = 0; i < mergeIds.length; i++) {
      try {
        await rpc('admin_merge_recipe_name_library', { p_keep_id: keep, p_merge_id: mergeIds[i] });
        merged++;
      } catch (e) { alert(e.message || e); break; }
    }
    alert('Merged ' + merged + ' row(s).');
    await loadDupClusters(true);
    await loadRows();
    loadQueueCounts();
  }

  async function loadDupClusters(refreshOnly) {
    var backdrop = document.getElementById('rnl-dup-backdrop');
    var summary = document.getElementById('rnl-dup-summary');
    if (!refreshOnly && backdrop) backdrop.classList.add('open');
    if (summary) summary.textContent = 'Scanning for normalized name duplicates…';
    try {
      var result = await rpc('admin_dish_index_duplicate_clusters', { p_limit: 80 });
      if (typeof result === 'string') { try { result = JSON.parse(result); } catch (e) {} }
      _dupClusters = (result && result.clusters) || [];
      renderDupClusters();
    } catch (e) {
      if (summary) summary.textContent = 'Duplicate scan unavailable — run fix-dish-index-intelligence.sql in Supabase.';
      var list = document.getElementById('rnl-dup-list');
      if (list) list.innerHTML = '<p style="font-size:12px;color:#dc5050">' + h(e.message || e) + '</p>';
    }
  }

  function renderCoverageGaps() {
    var host = document.getElementById('rnl-cov-content');
    if (!host || !_covGaps) return;
    var s = _covGaps.summary || {};
    function gapSection(title, count, rows, filterKind) {
      var items = rows || [];
      var head = '<div style="margin-bottom:18px">' +
        '<div style="font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:var(--accent);margin-bottom:8px">' +
          h(title) + ' <span style="font-weight:400;color:var(--text-mid)">(' + count + ')</span></div>';
      if (!items.length) return head + '<p style="font-size:12px;color:var(--text-mid);margin:0">None — looking good.</p></div>';
      var list = items.slice(0, 40).map(function(r) {
        var meta = [r.dish_code, r.category, r.origin_country].filter(Boolean).join(' · ');
        return '<div style="display:flex;align-items:center;justify-content:space-between;gap:8px;padding:5px 0;border-bottom:1px solid var(--border);font-size:12px">' +
          '<span>' + h(r.recipe_name || '—') + (meta ? ' <span style="color:var(--text-mid)">· ' + h(meta) + '</span>' : '') + '</span>' +
          (filterKind ? '<button type="button" class="bulk-clear-btn rnl-cov-focus" data-focus="' + filterKind + '" data-id="' + h(r.id) + '" data-name="' + h(r.recipe_name || '') + '">Show</button>' : '') +
        '</div>';
      }).join('');
      var more = items.length > 40 ? '<p style="font-size:11px;color:var(--text-mid);margin:8px 0 0">+' + (items.length - 40) + ' more not shown</p>' : '';
      return head + list + more + '</div>';
    }
    var emptyCats = (_covGaps.empty_categories || []).map(function(c) { return c.category; }).filter(Boolean);
    host.innerHTML =
      '<p style="font-size:13px;color:var(--text-mid);margin:0 0 16px;line-height:1.55">' +
        (s.active_dish_count || 0) + ' active dishes · ' + (s.missing_category_count || 0) + ' missing category · ' +
        (s.missing_country_count || 0) + ' missing country · ' + (s.empty_category_count || 0) + ' taxonomy categories with zero dishes' +
      '</p>' +
      gapSection('Missing category', s.missing_category_count || 0, _covGaps.missing_category, 'missing_category') +
      gapSection('Missing country', s.missing_country_count || 0, _covGaps.missing_country, 'missing_country') +
      gapSection('Missing sub-category (category set)', s.missing_sub_category_count || 0, _covGaps.missing_sub_category, 'missing_sub') +
      '<div style="margin-bottom:18px">' +
        '<div style="font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:var(--accent);margin-bottom:8px">Empty taxonomy categories (' + (s.empty_category_count || 0) + ')</div>' +
        (emptyCats.length
          ? '<div style="display:flex;flex-wrap:wrap;gap:6px">' + emptyCats.map(function(c) {
              return '<span style="font-size:11px;padding:4px 8px;border:1px solid var(--border);border-radius:999px;color:var(--text-mid)">' + h(c) + '</span>';
            }).join('') + '</div>'
          : '<p style="font-size:12px;color:var(--text-mid);margin:0">Every active taxonomy category has at least one dish.</p>') +
      '</div>' +
      '<div style="margin-bottom:8px">' +
        '<div style="font-family:DM Sans,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:var(--text-mid);margin-bottom:8px">Dishes by category</div>' +
        '<div style="display:flex;flex-wrap:wrap;gap:6px">' +
          ((_covGaps.category_counts || []).slice(0, 24).map(function(c) {
            return '<span style="font-size:11px;padding:4px 8px;background:rgba(196,151,59,0.08);border-radius:999px;color:var(--text-mid)">' + h(c.category) + ' · ' + c.count + '</span>';
          }).join('') || '<span style="font-size:12px;color:var(--text-mid)">No categorized dishes yet.</span>') +
        '</div></div>';
    host.querySelectorAll('.rnl-cov-focus').forEach(function(btn) {
      btn.addEventListener('click', function() {
        closeCovModal();
        var kind = btn.dataset.focus;
        var search = document.getElementById('rnl-search');
        if (kind === 'missing_category') {
          _page = 1;
          _activeFilter = 'active';
          var arch = document.getElementById('rnl-archived-filter');
          if (arch) arch.checked = false;
          ['rnl-category-filter', 'rnl-sub-filter', 'rnl-div-filter'].forEach(function(id) {
            var el = document.getElementById(id);
            if (el) el.value = '';
          });
          if (search) search.value = btn.dataset.name || '';
          loadRows();
          return;
        }
        if (kind === 'missing_country' || kind === 'missing_sub') {
          _page = 1;
          if (search) search.value = btn.dataset.name || '';
          loadRows();
        }
      });
    });
  }

  async function loadCoverageGaps() {
    var backdrop = document.getElementById('rnl-cov-backdrop');
    var host = document.getElementById('rnl-cov-content');
    if (backdrop) backdrop.classList.add('open');
    if (host) host.innerHTML = '<p style="font-size:13px;color:var(--text-mid)">Loading coverage report…</p>';
    try {
      var result = await rpc('admin_dish_index_coverage_gaps', { p_row_limit: 200 });
      if (typeof result === 'string') { try { result = JSON.parse(result); } catch (e) {} }
      _covGaps = result || {};
      renderCoverageGaps();
    } catch (e) {
      if (host) host.innerHTML = '<p style="font-size:12px;color:#dc5050">Coverage report unavailable — run fix-dish-index-intelligence.sql.<br>' + h(e.message || e) + '</p>';
    }
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
      loadColVis();
      await loadCatsAndTaxonomy();
      renderShell(root);
      fillCategoryFilter();
      bindShell();
      root.dataset.built = '1';
    }
    await loadRows();
    loadQueueCounts();
  }

  return { loadRecipeNameLibraryTab: loadRecipeNameLibraryTab };
})();
