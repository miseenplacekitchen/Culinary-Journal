// Bulk Recipe Editor — full recipe management tab (requires dashboard-recipes.js rpc/esc)
window.bulkRecipeEditor = (function() {
  var _bulkRecipes = [];
  var _bulkRecipesFiltered = [];
  var _bulkRecipesTotal = 0;
  var _bulkPage = 1;
  var _BULK_PAGE_SIZE = 50;
  var _bulkSort = { column: 'recipe_name', direction: 'asc' };
  var _bulkSelected = new Set();
  var _bulkEditorReady = false;
  var _bulkTaxonomyRows = [];
  var _bulkColFilters = {};
  var _RM_BULK_CATS = ['Garden & Earth','Feather & Flock','Pasture & Hoof','Ocean & River',
    'The Grain Field','Wrapped & Stuffed','Curds, Creams & Eggs','Breads & Bakery',
    'Sweet Serenades','Sips & Stories','Preserved & Pantry'];
  var _BULK_COLS = [
    { key: 'recipe_code', label: 'RM#', sort: true, filter: true },
    { key: 'recipe_name', label: 'Recipe', sort: true, filter: true },
    { key: 'category', label: 'Category', sort: true, filter: true },
    { key: 'sub_category', label: 'Sub-category', sort: true, filter: true },
    { key: 'division', label: 'Division', sort: true, filter: true },
    { key: 'cooking_style', label: 'Cooking', sort: true, filter: true },
    { key: 'spice_level', label: 'Spice', sort: true, filter: true },
    { key: 'sweet_level', label: 'Sweet', sort: true, filter: true },
    { key: 'difficulty', label: 'Difficulty', sort: true, filter: true },
    { key: 'dietary_tags', label: 'Dietary', sort: false, filter: true, tags: true },
    { key: 'style_tags', label: 'Style', sort: false, filter: true, tags: true },
    { key: 'health_tags', label: 'Health', sort: false, filter: true, tags: true },
    { key: 'occasion_tags', label: 'Occasion', sort: false, filter: true, tags: true },
    { key: 'visibility', label: 'Visibility', sort: true, filter: true },
    { key: 'status', label: 'Status', sort: true, filter: true }
  ];
  var _SPICE_OPTS = ['Not Applicable','Mild','Medium','Hot','Very Hot','Extremely Hot'];
  var _SWEET_OPTS = ['Not Applicable','Subtly Sweet','Lightly Sweet','Sweet','Very Sweet','Extremely Sweet'];
  var _DIFF_OPTS = ['Easy','Intermediate','Advanced'];
  var _VIS_OPTS = ['Public','Private','Friends','Archived'];
  var _STATUS_OPTS = ['pending','approved','rejected'];

  function bulkEsc(s) { return (typeof esc === 'function') ? esc(s) : String(s == null ? '' : s); }
  function bulkRpc(fn, params) { return rpc(fn, params); }

  function bulkTagsStr(arr) {
    if (!arr || !arr.length) return '—';
    return arr.join(', ');
  }

  function bulkCatMatch(rowCat, cat) {
    if (typeof taxonomyCategoryMatches === 'function') return taxonomyCategoryMatches(rowCat, cat);
    return rowCat === cat;
  }

  function bulkTaxSubs(cat) {
    var names = {};
    _bulkTaxonomyRows.forEach(function(r) {
      if (bulkCatMatch(r.subcategory_category, cat) && r.subcategory_name) names[r.subcategory_name] = true;
    });
    return Object.keys(names).sort();
  }

  function bulkTaxDivs(cat, sub) {
    var names = [];
    _bulkTaxonomyRows.forEach(function(r) {
      if (bulkCatMatch(r.subcategory_category, cat) && r.subcategory_name === sub && r.division_name) {
        names.push(r.division_name);
      }
    });
    return names.sort();
  }

  async function bulkLoadTaxonomy() {
    try {
      _bulkTaxonomyRows = await bulkRpc('get_recipe_taxonomy', { p_category: null }) || [];
    } catch (e) {
      console.warn('bulk taxonomy', e);
      _bulkTaxonomyRows = [];
    }
  }

  function bulkFillAssignDropdowns() {
    var catSel = document.getElementById('bulk-assign-category');
    var subSel = document.getElementById('bulk-assign-sub');
    var divSel = document.getElementById('bulk-assign-division');
    if (!catSel) return;
    if (catSel.dataset.init !== '1') {
      catSel.dataset.init = '1';
      var cats = (typeof getRecipeCats === 'function') ? getRecipeCats() : _RM_BULK_CATS;
      cats.forEach(function(c) {
        var o = document.createElement('option');
        o.value = c; o.textContent = c;
        catSel.appendChild(o);
      });
      catSel.addEventListener('change', function() {
        subSel.innerHTML = '<option value="">Sub-category…</option>';
        divSel.innerHTML = '<option value="">Division…</option>';
        bulkTaxSubs(catSel.value).forEach(function(n) {
          var o = document.createElement('option');
          o.value = n; o.textContent = n;
          subSel.appendChild(o);
        });
      });
      subSel.addEventListener('change', function() {
        divSel.innerHTML = '<option value="">Division…</option>';
        bulkTaxDivs(catSel.value, subSel.value).forEach(function(n) {
          var o = document.createElement('option');
          o.value = n; o.textContent = n;
          divSel.appendChild(o);
        });
      });
    }
  }

  function initBulkEditorFilters() {
    var catSel = document.getElementById('bulk-category-filter');
    if (catSel && catSel.dataset.init !== '1') {
      catSel.dataset.init = '1';
      var cats = (typeof getRecipeCats === 'function') ? getRecipeCats() : _RM_BULK_CATS;
      cats.forEach(function(c) {
        var o = document.createElement('option');
        o.value = c; o.textContent = c;
        catSel.appendChild(o);
      });
    }
    if (!_bulkEditorReady) {
      _bulkEditorReady = true;
      var search = document.getElementById('bulk-recipe-search');
      if (search) {
        var t;
        search.addEventListener('input', function() {
          clearTimeout(t);
          t = setTimeout(function() { _bulkPage = 1; loadBulkRecipes(); }, 300);
        });
      }
      ['bulk-category-filter', 'bulk-status-filter'].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) el.addEventListener('change', function() { _bulkPage = 1; loadBulkRecipes(); });
      });
      document.querySelectorAll('.bulk-sort-th').forEach(function(th) {
        th.addEventListener('click', function() {
          var col = th.dataset.sort;
          if (!col) return;
          if (_bulkSort.column === col) {
            _bulkSort.direction = _bulkSort.direction === 'asc' ? 'desc' : 'asc';
          } else {
            _bulkSort.column = col;
            _bulkSort.direction = 'asc';
          }
          bulkApplyColFilters();
          sortBulkRecipesClient();
          renderBulkRecipesTable();
        });
      });
      document.querySelectorAll('.bulk-col-filter').forEach(function(inp) {
        inp.addEventListener('input', function() {
          _bulkColFilters[inp.dataset.col] = inp.value.trim().toLowerCase();
          bulkApplyColFilters();
          sortBulkRecipesClient();
          renderBulkRecipesTable();
        });
      });
    }
    bulkFillAssignDropdowns();
  }

  function bulkCellVal(r, col) {
    if (col.tags) return bulkTagsStr(r[col.key]);
    return r[col.key] == null || r[col.key] === '' ? '—' : String(r[col.key]);
  }

  function bulkApplyColFilters() {
    _bulkRecipesFiltered = _bulkRecipes.filter(function(r) {
      for (var k in _bulkColFilters) {
        if (!_bulkColFilters[k]) continue;
        var col = null;
        for (var i = 0; i < _BULK_COLS.length; i++) {
          if (_BULK_COLS[i].key === k) { col = _BULK_COLS[i]; break; }
        }
        var val = col && col.tags ? bulkTagsStr(r[k]).toLowerCase() : bulkCellVal(r, { key: k, tags: false }).toLowerCase();
        if (val.indexOf(_bulkColFilters[k]) < 0) return false;
      }
      return true;
    });
  }

  async function loadBulkRecipesTab() {
    initBulkEditorFilters();
    await bulkLoadTaxonomy();
    bulkFillAssignDropdowns();
    await renderBulkTaxonomyBackfill();
    loadBulkRecipes();
  }

  async function renderBulkTaxonomyBackfill() {
    var host = document.getElementById('bulk-taxonomy-backfill');
    if (!host) return;
    host.innerHTML = '<div style="font-size:12px;color:var(--text-mid)">Loading missing taxonomy…</div>';
    try {
      var missing = await bulkRpc('admin_list_recipes_missing_taxonomy', { p_limit: 50 }) || [];
      if (!missing.length) {
        host.innerHTML = '<div style="font-size:12px;color:var(--text-mid)">All approved recipes have sub-category and division.</div>';
        return;
      }
      var html = '<div style="font-size:11px;font-weight:700;letter-spacing:0.1em;text-transform:uppercase;color:var(--accent);margin-bottom:8px">Backfill missing taxonomy (' + missing.length + ')</div>';
      html += '<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:10px"><thead><tr style="color:var(--text-mid);text-align:left">';
      html += '<th style="padding:4px 6px;width:24px"></th><th style="padding:4px 6px">Recipe</th><th style="padding:4px 6px">Category</th><th style="padding:4px 6px">Current</th></tr></thead><tbody>';
      missing.forEach(function(m) {
        html += '<tr style="border-top:1px solid rgba(255,255,255,0.06)"><td style="padding:4px 6px"><input type="checkbox" class="bulk-backfill-cb" value="' + bulkEsc(m.id) + '"></td>';
        html += '<td style="padding:4px 6px">' + bulkEsc(m.recipe_name) + '</td>';
        html += '<td style="padding:4px 6px">' + bulkEsc(m.category) + '</td>';
        html += '<td style="padding:4px 6px">' + bulkEsc((m.sub_category || '—') + ' · ' + (m.division || '—')) + '</td></tr>';
      });
      html += '</tbody></table>';
      html += '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center">';
      html += '<select id="bulk-backfill-sub" class="ing-cat-filter" style="min-width:140px"><option value="">Sub-category…</option></select>';
      html += '<select id="bulk-backfill-div" class="ing-cat-filter" style="min-width:140px"><option value="">Division…</option></select>';
      html += '<button type="button" class="rm-bulk-approve-btn" id="bulk-backfill-apply">Apply to checked</button></div>';
      host.innerHTML = html;

      var subSel = document.getElementById('bulk-backfill-sub');
      var divSel = document.getElementById('bulk-backfill-div');
      var cats = {};
      _bulkTaxonomyRows.forEach(function(r) {
        if (!r.subcategory_name) return;
        var canon = (typeof normalizeRecipeCategory === 'function')
          ? (normalizeRecipeCategory(r.subcategory_category) || r.subcategory_category)
          : r.subcategory_category;
        if (!cats[canon]) cats[canon] = {};
        cats[canon][r.subcategory_name] = true;
      });
      Object.keys(cats).sort().forEach(function(cat) {
        Object.keys(cats[cat]).sort().forEach(function(sub) {
          var o = document.createElement('option');
          o.value = sub; o.textContent = cat + ' → ' + sub;
          o.dataset.cat = cat;
          subSel.appendChild(o);
        });
      });
      subSel.addEventListener('change', function() {
        divSel.innerHTML = '<option value="">Division…</option>';
        var opt = subSel.options[subSel.selectedIndex];
        var cat = opt && opt.dataset.cat;
        bulkTaxDivs(cat, subSel.value).forEach(function(d) {
          var o = document.createElement('option');
          o.value = d; o.textContent = d;
          divSel.appendChild(o);
        });
      });
      document.getElementById('bulk-backfill-apply').addEventListener('click', function() {
        var ids = [].map.call(host.querySelectorAll('.bulk-backfill-cb:checked'), function(cb) { return cb.value; });
        if (!ids.length) { alert('Check at least one recipe.'); return; }
        var sub = subSel.value.trim();
        var div = divSel.value.trim();
        if (!sub || !div) { alert('Pick sub-category and division.'); return; }
        bulkRpc('admin_bulk_set_recipe_taxonomy', { p_recipe_ids: ids, p_sub_category: sub, p_division: div })
          .then(function(n) { alert('Updated ' + (n || 0) + ' recipe(s).'); renderBulkTaxonomyBackfill(); loadBulkRecipes(); })
          .catch(function(e) { alert(e.message); });
      });
    } catch (e) {
      host.innerHTML = '<div style="color:#dc5050;font-size:12px">' + bulkEsc(e.message) + '</div>';
    }
  }

  window.loadBulkRecipes = async function() {
    var tbody = document.getElementById('bulk-recipes-tbody');
    if (!tbody) return;
    var colCount = _BULK_COLS.length + 1;
    tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="ap-empty-row">Loading…</td></tr>';
    try {
      var search = (document.getElementById('bulk-recipe-search') || {}).value || '';
      var cat = (document.getElementById('bulk-category-filter') || {}).value || '';
      var status = (document.getElementById('bulk-status-filter') || {}).value || '';
      var result = await bulkRpc('admin_get_recipes_bulk', {
        p_limit: _BULK_PAGE_SIZE,
        p_offset: (_bulkPage - 1) * _BULK_PAGE_SIZE,
        p_search: search.trim() || null,
        p_category: cat || null,
        p_status: status || null
      });
      if (!result || typeof result === 'string') {
        try { result = JSON.parse(result); } catch (e) { /* keep */ }
      }
      _bulkRecipes = (result && result.rows) ? result.rows : [];
      if (typeof _bulkRecipes === 'string') {
        try { _bulkRecipes = JSON.parse(_bulkRecipes); } catch (e) { _bulkRecipes = []; }
      }
      if (!Array.isArray(_bulkRecipes)) _bulkRecipes = [];
      _bulkRecipesTotal = (result && result.total) ? parseInt(result.total, 10) : _bulkRecipes.length;
      bulkApplyColFilters();
      sortBulkRecipesClient();
      renderBulkRecipesTable();
      renderBulkRecipePagination();
    } catch (err) {
      tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="ap-empty-row" style="color:#dc5050">Run database/sql/fix-admin-bulk-recipes.sql and fix-admin-bulk-recipes-v2.sql — ' + bulkEsc(err.message || err) + '</td></tr>';
    }
  };

  function sortBulkRecipesClient() {
    var col = _bulkSort.column;
    var dir = _bulkSort.direction === 'asc' ? 1 : -1;
    _bulkRecipesFiltered.sort(function(a, b) {
      var av, bv;
      var colDef = null;
      for (var i = 0; i < _BULK_COLS.length; i++) {
        if (_BULK_COLS[i].key === col) { colDef = _BULK_COLS[i]; break; }
      }
      if (colDef && colDef.tags) {
        av = bulkTagsStr(a[col]).toLowerCase();
        bv = bulkTagsStr(b[col]).toLowerCase();
      } else {
        av = (a[col] == null ? '' : String(a[col])).toLowerCase();
        bv = (b[col] == null ? '' : String(b[col])).toLowerCase();
      }
      if (av < bv) return -1 * dir;
      if (av > bv) return 1 * dir;
      return 0;
    });
  }

  function renderBulkRecipesTable() {
    var tbody = document.getElementById('bulk-recipes-tbody');
    if (!tbody) return;
    var colCount = _BULK_COLS.length + 1;
    tbody.innerHTML = '';
    if (!_bulkRecipesFiltered.length) {
      tbody.innerHTML = '<tr><td colspan="' + colCount + '" class="ap-empty-row">No recipes match filters.</td></tr>';
      return;
    }
    _bulkRecipesFiltered.forEach(function(r) {
      var tr = document.createElement('tr');
      tr.dataset.recipeId = r.id;
      tr.style.borderBottom = '1px solid rgba(255,255,255,0.04)';

      var tdChk = document.createElement('td');
      tdChk.className = 'ap-td';
      var cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = _bulkSelected.has(r.id);
      cb.addEventListener('change', function() {
        if (cb.checked) _bulkSelected.add(r.id); else _bulkSelected.delete(r.id);
        updateBulkActionBar();
      });
      tdChk.appendChild(cb);
      tr.appendChild(tdChk);

      _BULK_COLS.forEach(function(col) {
        tr.appendChild(bulkMakeCell(r, col));
      });
      tbody.appendChild(tr);
    });
    updateBulkActionBar();
  }

  function bulkMakeCell(recipe, col) {
    var field = col.key;
    var display = bulkCellVal(recipe, col);
    var td = document.createElement('td');
    td.className = 'ap-td';
    td.style.fontSize = '11px';
    td.style.cursor = 'pointer';
    td.style.maxWidth = col.tags ? '120px' : '140px';
    td.style.overflow = 'hidden';
    td.style.textOverflow = 'ellipsis';
    td.style.whiteSpace = 'nowrap';
    td.title = display;
    if (field === 'recipe_code' && !recipe.recipe_code) td.style.color = '#dc5050';
    td.textContent = display;
    td.addEventListener('click', function(e) {
      e.stopPropagation();
      bulkStartEdit(td, recipe, col);
    });
    if (field === 'recipe_name') {
      td.addEventListener('dblclick', function(e) {
        e.stopPropagation();
        if (typeof openRecipeModal === 'function') openRecipeModal(recipe.id);
      });
    }
    return td;
  }

  function bulkStartEdit(td, recipe, col) {
    var field = col.key;
    var original = td.textContent;
    var origVal = col.tags ? bulkTagsStr(recipe[field]) : (recipe[field] || '');
    if (origVal === '—') origVal = '';

    function save(val) {
      if (val === origVal || (val === '' && origVal === '')) { td.textContent = original; return; }
      bulkRpc('admin_update_recipe_field', { p_id: recipe.id, p_field: field, p_value: val })
        .then(function() {
          if (col.tags) {
            recipe[field] = val ? val.split(',').map(function(s) { return s.trim(); }).filter(Boolean) : [];
          } else {
            recipe[field] = val;
          }
          td.textContent = bulkCellVal(recipe, col);
          td.style.color = '';
        })
        .catch(function(e) { alert(e.message); td.textContent = original; });
    }

    if (field === 'category') {
      bulkSelectEdit(td, origVal, _RM_BULK_CATS, save);
    } else if (field === 'sub_category') {
      bulkSelectEdit(td, origVal, bulkTaxSubs(recipe.category || ''), save);
    } else if (field === 'division') {
      bulkSelectEdit(td, origVal, bulkTaxDivs(recipe.category || '', recipe.sub_category || ''), save);
    } else if (field === 'spice_level') {
      bulkSelectEdit(td, origVal, _SPICE_OPTS, save);
    } else if (field === 'sweet_level') {
      bulkSelectEdit(td, origVal, _SWEET_OPTS, save);
    } else if (field === 'difficulty') {
      bulkSelectEdit(td, origVal, _DIFF_OPTS, save);
    } else if (field === 'visibility') {
      bulkSelectEdit(td, origVal || 'Public', _VIS_OPTS, save);
    } else if (field === 'status') {
      bulkSelectEdit(td, origVal || 'pending', _STATUS_OPTS, save);
    } else {
      bulkTextEdit(td, origVal, save);
    }
  }

  function bulkSelectEdit(td, origVal, options, save) {
    var sel = document.createElement('select');
    sel.style.cssText = 'width:100%;padding:4px;background:var(--bg);border:1px solid var(--accent);border-radius:4px;font-size:11px';
    (options || []).forEach(function(opt) {
      var o = document.createElement('option');
      o.value = opt; o.textContent = opt;
      o.selected = opt === origVal;
      sel.appendChild(o);
    });
    if (!options || !options.length) {
      var o = document.createElement('option');
      o.value = origVal; o.textContent = origVal || '(none in taxonomy)';
      sel.appendChild(o);
    }
    sel.addEventListener('blur', function() { save(sel.value); });
    sel.addEventListener('change', function() { sel.blur(); });
    td.textContent = '';
    td.appendChild(sel);
    sel.focus();
  }

  function bulkTextEdit(td, origVal, save) {
    var inp = document.createElement('input');
    inp.type = 'text';
    inp.value = origVal;
    inp.style.cssText = 'width:100%;padding:4px;background:var(--bg);border:1px solid var(--accent);border-radius:4px;font-size:11px';
    inp.addEventListener('blur', function() { save(inp.value.trim()); });
    inp.addEventListener('keydown', function(ev) {
      if (ev.key === 'Enter') inp.blur();
      if (ev.key === 'Escape') td.textContent = origVal || '—';
    });
    td.textContent = '';
    td.appendChild(inp);
    inp.focus();
    inp.select();
  }

  window.updateBulkActionBar = function() {
    var bar = document.getElementById('bulk-actions-bar');
    var count = document.getElementById('bulk-selected-count');
    if (!bar) return;
    bar.style.display = _bulkSelected.size > 0 ? 'flex' : 'none';
    if (count) count.textContent = _bulkSelected.size + ' selected';
  };

  window.toggleBulkSelectAll = function(checkbox) {
    var tbody = document.getElementById('bulk-recipes-tbody');
    if (!tbody) return;
    tbody.querySelectorAll('input[type="checkbox"]').forEach(function(cb) {
      if (cb.id === 'bulk-select-all') return;
      cb.checked = checkbox.checked;
      var id = cb.closest('tr') && cb.closest('tr').dataset.recipeId;
      if (id) { if (checkbox.checked) _bulkSelected.add(id); else _bulkSelected.delete(id); }
    });
    updateBulkActionBar();
  };

  window.clearBulkRecipeSelection = function() {
    _bulkSelected.clear();
    var all = document.getElementById('bulk-select-all');
    if (all) all.checked = false;
    var tbody = document.getElementById('bulk-recipes-tbody');
    if (tbody) tbody.querySelectorAll('input[type="checkbox"]').forEach(function(cb) { cb.checked = false; });
    updateBulkActionBar();
  };

  window.executeBulkRecipeAction = async function() {
    var action = (document.getElementById('bulk-action-select') || {}).value;
    if (!action || !_bulkSelected.size) return;
    var ids = Array.from(_bulkSelected);
    try {
      if (action === 'show') {
        await bulkRpc('admin_bulk_update_recipe_visibility', { p_recipe_ids: ids, p_visibility: 'Public' });
      } else if (action === 'hide') {
        await bulkRpc('admin_bulk_update_recipe_visibility', { p_recipe_ids: ids, p_visibility: 'Private' });
      } else if (action === 'assign-tax') {
        await bulkAssignSelectedTaxonomy(ids);
      } else if (_STATUS_OPTS.indexOf(action) >= 0) {
        var chain = Promise.resolve();
        ids.forEach(function(id) {
          chain = chain.then(function() {
            return bulkRpc('admin_update_recipe_field', { p_id: id, p_field: 'status', p_value: action });
          });
        });
        await chain;
      } else {
        alert('Unknown action.');
        return;
      }
      alert('Updated ' + ids.length + ' recipe(s).');
      clearBulkRecipeSelection();
      loadBulkRecipes();
    } catch (e) {
      alert(e.message || e);
    }
  };

  window.bulkAssignSelectedTaxonomy = async function(ids) {
    ids = ids || Array.from(_bulkSelected);
    if (!ids.length) return;
    var cat = (document.getElementById('bulk-assign-category') || {}).value || null;
    var sub = (document.getElementById('bulk-assign-sub') || {}).value || null;
    var div = (document.getElementById('bulk-assign-division') || {}).value || null;
    if (!cat && !sub && !div) { alert('Pick at least one of category, sub-category, or division.'); return; }
    await bulkRpc('admin_bulk_assign_recipe_taxonomy', {
      p_recipe_ids: ids, p_category: cat, p_sub_category: sub, p_division: div
    });
  };

  document.addEventListener('click', function(e) {
    if (e.target && e.target.id === 'bulk-assign-taxonomy-btn') {
      if (!_bulkSelected.size) { alert('Select recipes first.'); return; }
      bulkAssignSelectedTaxonomy(Array.from(_bulkSelected))
        .then(function() { alert('Taxonomy updated.'); loadBulkRecipes(); })
        .catch(function(err) { alert(err.message); });
    }
  });

  window.generateRecipeCodes = async function() {
    if (!confirm('Generate RM# codes for recipes missing them?')) return;
    try {
      var result = await bulkRpc('admin_generate_recipe_codes', { p_batch_size: 500 });
      if (typeof result === 'string') { try { result = JSON.parse(result); } catch (e) {} }
      alert('Generated ' + ((result && result.generated_count) || 0) + ' code(s).');
      loadBulkRecipes();
    } catch (e) { alert(e.message || e); }
  };

  window.exportBulkRecipes = function(format) {
    if (format !== 'csv') return;
    var headers = ['RM#','Recipe','Category','Sub-category','Division','Cooking','Spice','Sweet','Difficulty',
      'Dietary','Style','Health','Occasion','Visibility','Status'];
    var lines = [headers.map(function(h) { return '"' + h + '"'; }).join(',')];
    _bulkRecipesFiltered.forEach(function(r) {
      lines.push([
        r.recipe_code || '', r.recipe_name || '', r.category || '', r.sub_category || '', r.division || '',
        r.cooking_style || '', r.spice_level || '', r.sweet_level || '', r.difficulty || '',
        bulkTagsStr(r.dietary_tags), bulkTagsStr(r.style_tags), bulkTagsStr(r.health_tags), bulkTagsStr(r.occasion_tags),
        r.visibility || '', r.status || ''
      ].map(function(c) { return '"' + String(c === '—' ? '' : c).replace(/"/g, '""') + '"'; }).join(','));
    });
    var blob = new Blob([lines.join('\n')], { type: 'text/csv' });
    var url = window.URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'recipes-bulk-' + new Date().toISOString().split('T')[0] + '.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  };

  window.renderBulkRecipePagination = function() {
    var el = document.getElementById('bulk-pagination');
    if (!el) return;
    var totalPages = Math.max(1, Math.ceil(_bulkRecipesTotal / _BULK_PAGE_SIZE));
    if (_bulkRecipesTotal <= _BULK_PAGE_SIZE) { el.style.display = 'none'; return; }
    el.style.display = 'flex';
    el.innerHTML =
      '<button type="button" class="ap-pg-btn" ' + (_bulkPage <= 1 ? 'disabled' : '') + ' data-bulk-pg="prev">Prev</button>' +
      '<span style="font-size:12px;color:var(--text-mid);padding:0 12px">Page ' + _bulkPage + ' of ' + totalPages + '</span>' +
      '<button type="button" class="ap-pg-btn" ' + (_bulkPage >= totalPages ? 'disabled' : '') + ' data-bulk-pg="next">Next</button>';
    el.querySelectorAll('[data-bulk-pg]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        if (btn.dataset.bulkPg === 'prev' && _bulkPage > 1) { _bulkPage--; loadBulkRecipes(); }
        if (btn.dataset.bulkPg === 'next' && _bulkPage < totalPages) { _bulkPage++; loadBulkRecipes(); }
      });
    });
  };

  return {
    loadBulkRecipesTab: loadBulkRecipesTab,
    bulkRpc: bulkRpc,
    bulkFillAssignDropdowns: bulkFillAssignDropdowns
  };
})();
