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
  var DIVISION_PLACEHOLDER = '(none)';
  var TEMPLATE_URL = 'assets/dish-index-export-template.xlsx';
  var DATA_TABLE_NAME = 'T_DishIndex';

  /* DD sheet: row 2 = list key, row 3+ = values; matches Betty's formatted template */
  var DD_LIST = {
    categories: { col: 'B', table: 'T_Categories' },
    subCategories: { col: 'D', table: 'T_SubCategories' },
    divisions: { col: 'F', table: 'T_Divisions' },
    continents: { col: 'H', table: 'T_Continents' },
    countries: { col: 'J', table: 'T_Countries' },
    states: { col: 'L', table: 'T_States' },
    difficulty: { col: 'N', table: 'T_Difficulty' },
    spice: { col: 'P', table: 'T_SpiceLevel' },
    sweet: { col: 'R', table: 'T_SweetLevel' },
    cookingStyles: { col: 'T', table: 'T_CookingStyles' },
    sourceTypes: { col: 'V', table: 'T_SourceTypes' },
    research: { col: 'X', table: 'T_Research' },
    content: { col: 'Z', table: 'T_Content' },
    visibility: { col: 'AB', table: 'T_Visibility' },
    active: { col: 'AD', table: 'T_Active' },
    servingsUnits: { col: 'AF', table: 'T_ServingUnits' },
    dietary_tags: { col: 'AH', table: 'T_TagDietary' },
    health_tags: { col: 'AJ', table: 'T_TagHealth' },
    meal_type_tags: { col: 'AL', table: 'T_TagMeal' },
    occasion_tags: { col: 'AN', table: 'T_TagOccasion' },
    style_tags: { col: 'AP', table: 'T_TagStyles' },
    flavor_profile_tags: { col: 'AR', table: 'T_TagFlavourProfile' }
  };

  var EMOJI_PREFIX_RE = /^(\s*(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[\u2600-\u27BF]|[\u200D\uFE0F])+\s*)+/;

  var LEGACY_COOKING_SLUGS = {
    'Stir-fry & Sauté': 'stir-fry',
    'Slow Cooking & Braising': 'slow-cook',
    'Grilling & BBQ': 'bbq',
    'Steaming & Poaching': 'steam-poach',
    'Deep Frying': 'deep-fry'
  };

  function colLetter(n) {
    var s = '';
    while (n > 0) {
      var m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = Math.floor((n - 1) / 26);
    }
    return s;
  }

  function colNumber(letters) {
    var n = 0;
    for (var i = 0; i < letters.length; i++) {
      n = n * 26 + (letters.charCodeAt(i) - 64);
    }
    return n;
  }

  function stripLeadingEmoji(value) {
    var s = String(value == null ? '' : value).trim();
    while (EMOJI_PREFIX_RE.test(s)) {
      s = s.replace(EMOJI_PREFIX_RE, '').trim();
    }
    return s;
  }

  function writeDdListColumn(ws, listKey, items) {
    var spec = DD_LIST[listKey];
    if (!spec || !ws) return;
    items = items && items.length ? items : [''];
    var colNum = colNumber(spec.col);
    ws.getCell(2, colNum).value = listKey;
    var clearTo = Math.max(items.length + 5, 20);
    var i;
    for (i = 0; i < clearTo; i++) {
      ws.getCell(3 + i, colNum).value = i < items.length ? items[i] : '';
    }
  }

  function refreshDdSheet(wb, lists) {
    var ws = wb.getWorksheet('DD');
    if (!ws) throw new Error('Export template missing DD sheet.');
    Object.keys(DD_LIST).forEach(function(listKey) {
      writeDdListColumn(ws, listKey, lists[listKey] || []);
    });
  }

  function clearDishIndexData(ws, headers, fromRow, toRow) {
    var lastCol = START_COL + headers.length - 1;
    var r;
    for (r = fromRow; r <= toRow; r++) {
      var c;
      for (c = START_COL; c <= lastCol; c++) {
        ws.getCell(r, c).value = '';
      }
    }
  }

  function writeDishIndexData(ws, headers, rows, rowValues) {
    rows.forEach(function(row, ri) {
      var vals = rowValues(row);
      vals.forEach(function(v, ci) {
        ws.getCell(START_ROW + 1 + ri, START_COL + ci).value = v == null ? '' : v;
      });
    });
  }

  function mergeSheetPreserveFooter(templateXml, dirtyXml) {
    var closeTag = '</sheetData>';
    var tplSdStart = templateXml.indexOf('<sheetData');
    var tplSdEnd = templateXml.indexOf(closeTag);
    var dirtySdStart = dirtyXml.indexOf('<sheetData');
    var dirtySdEnd = dirtyXml.indexOf(closeTag);
    if (tplSdStart < 0 || tplSdEnd < 0 || dirtySdStart < 0 || dirtySdEnd < 0) {
      return templateXml;
    }
    var tplHead = templateXml.substring(0, tplSdStart);
    var sheetData = dirtyXml.substring(dirtySdStart, dirtySdEnd + closeTag.length);
    var tplFooter = templateXml.substring(tplSdEnd + closeTag.length);
    var dimMatch = dirtyXml.match(/<dimension ref="([^"]+)"/);
    if (dimMatch) {
      if (tplHead.indexOf('<dimension') >= 0) {
        tplHead = tplHead.replace(/<dimension ref="[^"]+"/, '<dimension ref="' + dimMatch[1] + '"');
      } else {
        tplHead = tplHead.replace('<sheetData', '<dimension ref="' + dimMatch[1] + '"/><sheetData');
      }
    }
    return tplHead + sheetData + tplFooter;
  }

  function resolveSheetPaths(wbXml, relsXml) {
    var relMap = {};
    relsXml.replace(/<Relationship\b[^>]*\/>/g, function(tag) {
      var id = (tag.match(/\bId="([^"]+)"/) || [])[1];
      var target = (tag.match(/\bTarget="([^"]+)"/) || [])[1];
      if (id && target) relMap[id] = target;
      return tag;
    });
    var out = {};
    wbXml.replace(/<sheet\b[^>]*\/>|<sheet\b[^>]*>[\s\S]*?<\/sheet>/g, function(tag) {
      var name = (tag.match(/\bname="([^"]+)"/) || [])[1];
      var rid = (tag.match(/\br:id="([^"]+)"/) || tag.match(/\bId="([^"]+)"/) || [])[1];
      if (!name || !rid || !relMap[rid]) return tag;
      var target = relMap[rid].replace(/^\/?xl\//, '');
      out[name] = target.indexOf('worksheets/') === 0 ? 'xl/' + target : 'xl/worksheets/' + target.replace(/^worksheets\//, '');
      return tag;
    });
    return out;
  }

  async function mergeWorkbookPreservingTemplate(templateBuf, dirtyBuf, sheetNames) {
    if (!window.JSZip) {
      throw new Error('JSZip not loaded — hard refresh the dashboard.');
    }
    var tplZip = await window.JSZip.loadAsync(templateBuf);
    var dirtyZip = await window.JSZip.loadAsync(dirtyBuf);
    var tplWb = await tplZip.file('xl/workbook.xml').async('string');
    var tplRels = await tplZip.file('xl/_rels/workbook.xml.rels').async('string');
    var dirtyWb = await dirtyZip.file('xl/workbook.xml').async('string');
    var dirtyRels = await dirtyZip.file('xl/_rels/workbook.xml.rels').async('string');
    var tplPaths = resolveSheetPaths(tplWb, tplRels);
    var dirtyPaths = resolveSheetPaths(dirtyWb, dirtyRels);
    var i;
    for (i = 0; i < sheetNames.length; i++) {
      var name = sheetNames[i];
      var tplPath = tplPaths[name];
      var dirtyPath = dirtyPaths[name];
      if (!tplPath || !dirtyPath) continue;
      var tplXml = await tplZip.file(tplPath).async('string');
      var dirtyXml = await dirtyZip.file(dirtyPath).async('string');
      tplZip.file(tplPath, mergeSheetPreserveFooter(tplXml, dirtyXml));
    }
    var dirtySst = dirtyZip.file('xl/sharedStrings.xml');
    if (dirtySst) {
      tplZip.file('xl/sharedStrings.xml', await dirtySst.async('string'));
    }
    if (tplZip.file('xl/calcChain.xml')) {
      tplZip.remove('xl/calcChain.xml');
    }
    return tplZip.generateAsync({ type: 'arraybuffer', compression: 'DEFLATE' });
  }

  async function loadExportTemplate() {
    var res = await fetch(TEMPLATE_URL, { cache: 'no-store' });
    if (!res.ok) {
      throw new Error('Export template not found (' + TEMPLATE_URL + ') — redeploy or hard refresh.');
    }
    return res.arrayBuffer();
  }

  async function buildWorkbookFromTemplate(opts) {
    var headers = opts.headers || [];
    var rows = opts.rows || [];
    var rowValues = opts.rowValues;
    var schemaVersion = opts.schemaVersion || '';
    var lists = buildLists(opts.context || {}, headers, rows, rowValues);
    var buf = await loadExportTemplate();
    var wb = new window.ExcelJS.Workbook();
    await wb.xlsx.load(buf);
    wb.creator = 'The Culinary Journal';
    wb.created = new Date();
    refreshDdSheet(wb, lists);
    var ws = wb.getWorksheet('Dish Index');
    if (!ws) throw new Error('Export template missing Dish Index sheet.');
    ws.getCell(1, 1).value = 'TCJ Dish Index — Schema ' + schemaVersion + ' (table from B2; tag cells: semicolon-separated)';
    clearDishIndexData(ws, headers, START_ROW + 1, START_ROW + Math.max(rows.length, 10) + 5);
    writeDishIndexData(ws, headers, rows, rowValues);
    var dirty = await wb.xlsx.writeBuffer();
    var out = await mergeWorkbookPreservingTemplate(buf, dirty, ['DD', 'Dish Index']);
    return new Blob([out], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
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

  function exportDivision(value) {
    if (value == null || String(value).trim() === '') return DIVISION_PLACEHOLDER;
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
      division: exportDivision(r.division),
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
    if (!lists.divisions.length) {
      lists.divisions = [DIVISION_PLACEHOLDER];
    } else if (lists.divisions.indexOf(DIVISION_PLACEHOLDER) < 0) {
      lists.divisions.unshift(DIVISION_PLACEHOLDER);
    }
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

  async function buildWorkbookLegacy(opts) {
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

  async function buildWorkbook(opts) {
    if (!window.ExcelJS) throw new Error('ExcelJS not loaded — refresh the dashboard.');
    try {
      return await buildWorkbookFromTemplate(opts);
    } catch (err) {
      console.warn('Dish Index template export failed, using legacy layout:', err);
      return buildWorkbookLegacy(opts);
    }
  }

  function cellToText(val) {
    if (val == null) return '';
    if (typeof val === 'object') {
      if (val.richText) {
        return val.richText.map(function(rt) { return rt.text || ''; }).join('');
      }
      if (val.text != null) return String(val.text);
      if (val.result != null) return String(val.result);
      if (val.hyperlink) return val.text || String(val.hyperlink);
    }
    return String(val);
  }

  function importCookingStyleSlug(value) {
    var v = String(value == null ? '' : value).trim();
    if (!v || v === 'General cooking') return '';
    var styles = (window.tcjRecipeFields || {}).COOKING_STYLES || [];
    var i;
    for (i = 0; i < styles.length; i++) {
      if (styles[i].label === v || styles[i].value === v) return styles[i].value || '';
    }
    if (LEGACY_COOKING_SLUGS[v]) return LEGACY_COOKING_SLUGS[v];
    var legacy = LEGACY_COOKING_LABELS[v.toLowerCase()];
    if (legacy && LEGACY_COOKING_SLUGS[legacy]) return LEGACY_COOKING_SLUGS[legacy];
    return v;
  }

  function importDifficulty(value) {
    var v = String(value == null ? '' : value).trim();
    if (!v || v === 'Not set' || v === '—') return '';
    return v;
  }

  function importDivision(value) {
    var v = String(value == null ? '' : value).trim();
    if (!v || v === DIVISION_PLACEHOLDER) return '';
    return v;
  }

  function importActive(value) {
    var v = String(value == null ? '' : value).trim().toLowerCase();
    if (v === 'false' || v === '0' || v === 'no') return 'false';
    return 'true';
  }

  function importTaxonomyText(value) {
    return stripLeadingEmoji(String(value == null ? '' : value));
  }

  function normalizeImportRow(row) {
    if (!row) return row;
    var out = Object.assign({}, row);
    var pairs = [
      ['Cooking Style', importCookingStyleSlug],
      ['cooking_style', importCookingStyleSlug],
      ['Difficulty', importDifficulty],
      ['difficulty', importDifficulty],
      ['Division', importDivision],
      ['division', importDivision],
      ['Active', importActive],
      ['is_active', importActive]
    ];
    pairs.forEach(function(pair) {
      var key = pair[0];
      if (out[key] != null && String(out[key]).trim() !== '') {
        out[key] = pair[1](out[key]);
      }
    });
    ['Category', 'category', 'Sub-category', 'sub_category', 'Sub Category', 'Division', 'division'].forEach(function(key) {
      if (out[key] != null && String(out[key]).trim() !== '') {
        out[key] = key === 'Division' || key === 'division' ? importDivision(out[key]) : importTaxonomyText(out[key]);
      }
    });
    return out;
  }

  async function parseExcelFile(file, schemaVersion) {
    if (!window.ExcelJS) throw new Error('ExcelJS not loaded — hard refresh the dashboard.');
    var wb = new window.ExcelJS.Workbook();
    await wb.xlsx.load(await file.arrayBuffer());
    var ws = wb.getWorksheet('Dish Index');
    if (!ws && wb.worksheets.length > 1) ws = wb.worksheets[1];
    if (!ws) throw new Error('No Dish Index sheet found in workbook.');
    var headers = [];
    var col = START_COL;
    while (col < START_COL + 80) {
      var hv = cellToText(ws.getCell(START_ROW, col).value).trim();
      if (!hv) break;
      headers.push(hv);
      col++;
    }
    if (!headers.length) throw new Error('No headers found at B2 — use a TCJ Dish Index export.');
    var rows = [];
    var ri = START_ROW + 1;
    while (ri < START_ROW + 50000) {
      var empty = true;
      var o = { schema_version: schemaVersion || '' };
      headers.forEach(function(h, i) {
        var txt = cellToText(ws.getCell(ri, START_COL + i).value);
        if (txt.trim() !== '') empty = false;
        o[h] = txt;
      });
      if (empty) break;
      rows.push(normalizeImportRow(o));
      ri++;
    }
    if (!rows.length) throw new Error('No data rows found below the header row.');
    return rows;
  }

  window.dishIndexExport = {
    buildWorkbook: buildWorkbook,
    buildWorkbookFromTemplate: buildWorkbookFromTemplate,
    normalizeExportRow: normalizeExportRow,
    normalizeImportRow: normalizeImportRow,
    parseExcelFile: parseExcelFile,
    exportActive: exportActive,
    exportCookingStyle: exportCookingStyle,
    exportDifficulty: exportDifficulty,
    exportDivision: exportDivision,
    exportTagText: exportTagText,
    stripLeadingEmoji: stripLeadingEmoji
  };
})();
