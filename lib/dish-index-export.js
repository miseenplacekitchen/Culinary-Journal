// dish-index-export.js — Dish Index Excel export (table from B2, dropdown validation)
(function() {
  var START_ROW = 2;
  var START_COL = 2;

  var HEADER_LIST_KEY = {
    'Category': 'categories',
    'Sub-category': 'subCategories',
    'Division': 'divisions',
    'Continent': 'continents',
    'Country': 'countries',
    'State': 'states',
    'Dietary Tags': 'dietary_tags',
    'Health Tags': 'health_tags',
    'Meal Type Tags': 'meal_type_tags',
    'Occasion Tags': 'occasion_tags',
    'Style Tags': 'style_tags',
    'Flavor Profile Tags': 'flavor_profile_tags',
    'Servings Unit': 'servingsUnits',
    'Difficulty': 'difficulty',
    'Spice Level': 'spice',
    'Sweet Level': 'sweet',
    'Cooking Style': 'cookingStyles',
    'Source Type': 'sourceTypes',
    'Research Status': 'research',
    'Content Status': 'content',
    'Visibility': 'visibility',
    'Active': 'active'
  };

  var TAG_HEADERS = {
    'Dietary Tags': 'dietary_tags',
    'Health Tags': 'health_tags',
    'Meal Type Tags': 'meal_type_tags',
    'Occasion Tags': 'occasion_tags',
    'Style Tags': 'style_tags',
    'Flavor Profile Tags': 'flavor_profile_tags'
  };

  var LEGACY_COOKING_LABELS = {
    'pan-fried': 'Stir-fry & Sauté',
    'pan fried': 'Stir-fry & Sauté',
    'slow-cooked': 'Slow Cooking & Braising',
    'slow cooked': 'Slow Cooking & Braising',
    'grilled': 'Grilling & BBQ',
    'steamed': 'Steaming & Poaching'
  };

  var DEFAULT_SERVINGS_UNITS = ['people', 'servings', 'portions', 'cups', 'litres', 'liters', 'slices', 'pieces'];

  function colLetter(n) {
    var s = '';
    while (n > 0) {
      var m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = Math.floor((n - 1) / 26);
    }
    return s;
  }

  function uniqueSorted(arr) {
    var m = {};
    (arr || []).forEach(function(v) {
      if (v != null && String(v).trim() !== '') m[String(v).trim()] = true;
    });
    return Object.keys(m).sort(function(a, b) { return a.localeCompare(b); });
  }

  function flattenStates() {
    var out = [];
    if (window.tcjOrigin && typeof window.tcjOrigin.statesForCountry === 'function' && window.CD) {
      Object.keys(window.CD).forEach(function(cont) {
        (window.CD[cont] || []).forEach(function(c) {
          (window.tcjOrigin.statesForCountry(c.name) || []).forEach(function(s) { out.push(s); });
        });
      });
    }
    return uniqueSorted(out);
  }

  function cookingStyleLabel(value) {
    if (value == null || String(value).trim() === '') return '';
    var v = String(value).trim();
    var styles = (window.tcjRecipeFields || {}).COOKING_STYLES || [];
    var i;
    for (i = 0; i < styles.length; i++) {
      if (styles[i].value === v) return styles[i].label || v;
      if (styles[i].label === v) return styles[i].label;
    }
    var legacy = LEGACY_COOKING_LABELS[v.toLowerCase()];
    return legacy || v;
  }

  function exportCookingStyle(value) {
    var label = cookingStyleLabel(value);
    return label || 'General cooking';
  }

  function exportDifficulty(value) {
    if (value == null || String(value).trim() === '') return 'Not set';
    return String(value).trim();
  }

  function exportActive(row) {
    var v = row && row.is_active;
    if (v === false || v === 'false' || v === 0 || v === '0') return 'false';
    if (v === true || v === 'true' || v === 1 || v === '1') return 'true';
    if (row && row.content_status === 'retired') return 'false';
    return 'true';
  }

  function normalizeTagToken(tag, groupKey) {
    var t = String(tag || '').trim();
    if (!t) return '';
    if (groupKey === 'dietary_tags') {
      var low = t.toLowerCase().replace(/-/g, ' ');
      if (low === 'gluten free') return 'Gluten Free';
    }
    var opts = (window.tcjRecipeFields || {}).tagOptions
      ? window.tcjRecipeFields.tagOptions(groupKey)
      : [];
    var i;
    for (i = 0; i < opts.length; i++) {
      if (opts[i].value === t) return opts[i].value;
      if (opts[i].value.toLowerCase() === t.toLowerCase()) return opts[i].value;
    }
    return t;
  }

  function exportTagText(value, groupKey) {
    if (!value) return '';
    var parts = Array.isArray(value)
      ? value
      : String(value).split(';').map(function(s) { return s.trim(); }).filter(Boolean);
    return parts.map(function(p) { return normalizeTagToken(p, groupKey); }).filter(Boolean).join('; ');
  }

  function normalizeExportRow(r) {
    if (!r) return r;
    return Object.assign({}, r, {
      cooking_style: exportCookingStyle(r.cooking_style),
      difficulty: exportDifficulty(r.difficulty),
      dietary_tags: exportTagText(r.dietary_tags, 'dietary_tags'),
      health_tags: exportTagText(r.health_tags, 'health_tags'),
      meal_type_tags: exportTagText(r.meal_type_tags, 'meal_type_tags'),
      occasion_tags: exportTagText(r.occasion_tags, 'occasion_tags'),
      style_tags: exportTagText(r.style_tags, 'style_tags'),
      flavor_profile_tags: exportTagText(r.flavor_profile_tags, 'flavor_profile_tags'),
      visibility: r.visibility || 'Private',
      is_active_export: exportActive(r)
    });
  }

  function buildLists(context, headers, rows, rowValues) {
    var rf = window.tcjRecipeFields || {};
    var lists = {
      categories: uniqueSorted(context.categories || []),
      subCategories: uniqueSorted(context.subCategories || []),
      divisions: uniqueSorted(context.divisions || []),
      continents: uniqueSorted(context.continents || []),
      countries: uniqueSorted(context.countries || []),
      states: uniqueSorted(context.states || []).length ? uniqueSorted(context.states) : flattenStates(),
      difficulty: ['Not set', 'Easy', 'Intermediate', 'Advanced'],
      spice: (rf.SPICE || []).slice(),
      sweet: (rf.SWEET || []).slice(),
      cookingStyles: (rf.COOKING_STYLES || []).map(function(x) {
        return x.label || x.value || '';
      }).filter(Boolean),
      sourceTypes: (context.sourceTypes || ['Original', 'From Somewhere Else', 'Scanned']).slice(),
      research: (context.research || ['idea_only', 'needs_research', 'ready_to_draft', 'verified']).slice(),
      content: (context.content || ['not_started', 'draft_created', 'linked', 'approved', 'duplicate', 'retired']).slice(),
      visibility: (context.visibility || ['Public', 'Private', 'Friends', 'Archived']).slice(),
      active: ['true', 'false'],
      servingsUnits: uniqueSorted((context.servingsUnits || []).concat(DEFAULT_SERVINGS_UNITS))
    };
    if (rf.tagOptions) {
      Object.keys(TAG_HEADERS).forEach(function(h) {
        var k = TAG_HEADERS[h];
        lists[k] = rf.tagOptions(k).map(function(o) { return o.value; });
      });
    }
    if (lists.cookingStyles.indexOf('General cooking') < 0) {
      lists.cookingStyles.unshift('General cooking');
    }
    mergeExportedValues(lists, headers, rows, rowValues);
    return lists;
  }

  function mergeExportedValues(lists, headers, rows, rowValues) {
    if (!headers || !rows || !rowValues) return;
    rows.forEach(function(r) {
      var vals = rowValues(r);
      headers.forEach(function(h, i) {
        var raw = vals[i];
        if (raw == null || String(raw).trim() === '') return;
        var listKey = HEADER_LIST_KEY[h];
        if (!listKey || !lists[listKey]) return;
        if (TAG_HEADERS[h]) {
          String(raw).split(';').forEach(function(token) {
            token = token.trim();
            if (token && lists[listKey].indexOf(token) < 0) lists[listKey].push(token);
          });
        } else if (lists[listKey].indexOf(String(raw).trim()) < 0) {
          lists[listKey].push(String(raw).trim());
        }
      });
    });
    Object.keys(lists).forEach(function(k) {
      lists[k] = uniqueSorted(lists[k]);
    });
  }

  function writeOptionsSheet(wb, lists) {
    var ws = wb.addWorksheet('Dropdown options');
    ws.state = 'hidden';
    var refs = {};
    var col = 1;
    Object.keys(lists).forEach(function(key) {
      var items = lists[key] || [];
      ws.getCell(1, col).value = key;
      items.forEach(function(v, i) {
        ws.getCell(i + 2, col).value = v;
      });
      refs[key] = {
        letter: colLetter(col),
        start: 2,
        end: items.length ? items.length + 1 : 1,
        count: items.length
      };
      col++;
    });
    return refs;
  }

  function listFormula(ref) {
    if (!ref || ref.count < 1) return null;
    return "'Dropdown options'!$" + ref.letter + "$" + ref.start + ":$" + ref.letter + "$" + ref.end;
  }

  async function buildWorkbook(opts) {
    if (!window.ExcelJS) throw new Error('ExcelJS not loaded — refresh the dashboard.');
    var headers = opts.headers || [];
    var rows = opts.rows || [];
    var rowValues = opts.rowValues;
    var schemaVersion = opts.schemaVersion || '';
    var lists = buildLists(opts.context || {}, headers, rows, rowValues);
    var wb = new window.ExcelJS.Workbook();
    wb.creator = 'The Culinary Journal';
    wb.created = new Date();
    var listRefs = writeOptionsSheet(wb, lists);
    var ws = wb.addWorksheet('Dish Index', { views: [{ state: 'frozen', xSplit: 1, ySplit: 2, topLeftCell: 'B3', activeCell: 'B3' }] });

    ws.getCell(1, 1).value = 'TCJ Dish Index — Schema ' + schemaVersion + ' (table from B2; tag cells: semicolon-separated)';

    headers.forEach(function(h, i) {
      var cell = ws.getCell(START_ROW, START_COL + i);
      cell.value = h;
      cell.font = { bold: true };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8ECF0' } };
      if (TAG_HEADERS[h]) {
        cell.note = 'Semicolon-separated tags. Each token should match the ' + h + ' list on the Dropdown options sheet.';
      }
    });

    rows.forEach(function(r, ri) {
      var vals = rowValues(r);
      vals.forEach(function(v, ci) {
        ws.getCell(START_ROW + 1 + ri, START_COL + ci).value = v == null ? '' : v;
      });
    });

    var dataStart = START_ROW + 1;
    var dataEnd = Math.max(dataStart + rows.length + 200, dataStart + 50);

    headers.forEach(function(h, i) {
      var listKey = HEADER_LIST_KEY[h];
      if (!listKey || !listRefs[listKey]) return;
      var formula = listFormula(listRefs[listKey]);
      if (!formula) return;
      var letter = colLetter(START_COL + i);
      var isTag = !!TAG_HEADERS[h];
      ws.dataValidations.add(letter + dataStart + ':' + letter + dataEnd, {
        type: 'list',
        allowBlank: true,
        formulae: [formula],
        errorStyle: isTag ? 'warning' : 'stop',
        showErrorMessage: true,
        errorTitle: isTag ? 'Tag hint' : 'Invalid value',
        error: isTag
          ? 'Pick one tag from the list, or type several separated by semicolons (each token must match the list).'
          : 'Choose a value from the dropdown list.'
      });
    });

    ws.columns.forEach(function(col, idx) {
      if (idx < START_COL - 1) return;
      var max = 12;
      col.eachCell({ includeEmpty: false }, function(cell) {
        var n = String(cell.value == null ? '' : cell.value).length;
        if (n + 2 > max) max = Math.min(n + 2, 48);
      });
      col.width = max;
    });

    var buf = await wb.xlsx.writeBuffer();
    return new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  }

  window.dishIndexExport = {
    buildWorkbook: buildWorkbook,
    normalizeExportRow: normalizeExportRow,
    exportActive: exportActive,
    exportCookingStyle: exportCookingStyle,
    exportDifficulty: exportDifficulty,
    exportTagText: exportTagText
  };
})();
