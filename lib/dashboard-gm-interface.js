// dashboard-gm-interface.js — Garden Management sacred ground (GM Interface)
// Pattern: Ingredient Management → IM Interface. Admin sees ids/slugs; public site shows names only.

var _gmLineage = [
  { v: 'heirloom', l: 'Heirloom', emoji: '🏆' },
  { v: 'open_pollinated', l: 'Open-pollinated', emoji: '🌱' },
  { v: 'hybrid', l: 'Hybrid (F1)', emoji: '🧬' },
  { v: 'indigenous', l: 'Indigenous / regional', emoji: '🌏' }
];

var _gmLookupDefs = [
  { table: 'cat_high_level', label: 'A.1 High-level categories', cols: 'slug,name,definition', order: 'name' },
  { table: 'cat_main', label: 'A.2 Main categories', cols: 'slug,name,definition', order: 'name' },
  { table: 'garden_layers', label: 'A.13 Garden layers', cols: 'slug,name,description', order: 'name' },
  { table: 'growth_habits', label: 'A.12 Growth habits', cols: 'slug,name,description', order: 'name' },
  { table: 'lifecycles', label: 'Lifecycles', cols: 'slug,name,traits', order: 'name' },
  { table: 'soil_types', label: 'C.2 Soil types', cols: 'slug,name,ph_low,ph_high', order: 'name' },
  { table: 'sunlight_levels', label: 'C.4 Sunlight levels', cols: 'slug,name,hours', order: 'name' },
  { table: 'seed_saving_groups', label: 'F.6 Seed-saving groups', cols: 'grp,name,notes', order: 'grp' },
  { table: 'ease_ratings', label: 'B.2 Ease ratings', cols: 'score,name,definition', order: 'score' },
  { table: 'tags', label: 'Tags', cols: 'slug,name', order: 'name' }
];

var _gmCache = {};
var _gmSelectedSlug = localStorage.getItem('tcj_gm_selected_species') || '';

function gmEsc(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function gmShortId(id) {
  return id ? String(id).slice(0, 8) + '…' : '—';
}

function gmTableWrap(headHtml, bodyHtml) {
  return '<div class="ap-table-wrap" style="margin-top:8px"><table class="ap-table"><thead>' + headHtml + '</thead><tbody>' +
    bodyHtml + '</tbody></table></div>';
}

function gmAccordion(title, bodyHtml, open) {
  var openAttr = open !== false ? '' : ' style="display:none"';
  var arrow = open !== false ? '▲' : '▼';
  return '<div class="gm-acc" style="margin-bottom:12px;border:1px solid var(--border);border-radius:10px;overflow:hidden">' +
    '<div class="gm-acc-hdr" onclick="var b=this.nextElementSibling;var a=this.querySelector(\'.gm-arr\');var o=b.style.display!==\'none\';b.style.display=o?\'none\':\'block\';a.textContent=o?\'▼\':\'▲\'" ' +
    'style="display:flex;justify-content:space-between;padding:10px 14px;background:rgba(255,255,255,0.03);cursor:pointer">' +
    '<div style="font-family:Cormorant Garamond,serif;font-size:1.05rem;font-weight:700">' + gmEsc(title) + '</div>' +
    '<span class="gm-arr" style="color:var(--text-mid)">' + arrow + '</span></div>' +
    '<div class="gm-acc-body" style="padding:14px"' + openAttr + '>' + bodyHtml + '</div></div>';
}

async function gmFetch(path) {
  var res = await supaFetch(path);
  if (!res.ok) throw new Error(path + ' → ' + res.status);
  return res.json();
}

async function gmFetchSafe(path) {
  try { return await gmFetch(path); } catch (e) { console.warn('gmFetchSafe', path, e); return null; }
}

function reloadGmInterface() {
  var root = document.getElementById('gm-interface-content');
  if (root) {
    delete root.dataset.built;
    root.innerHTML = '';
  }
  _gmCache = {};
  loadGmInterface(true);
}

async function gmLoadCoreData() {
  if (_gmCache.core) return _gmCache.core;
  var core = {
    climates: await gmFetchSafe('/rest/v1/climate_zones?select=id,slug,name&order=name') || [],
    regions: await gmFetchSafe('/rest/v1/regions?select=id,slug,name,climate_zone_id,is_active&order=name') || [],
    zones: await gmFetchSafe('/rest/v1/zone_definitions?select=zone,name,description&order=zone') || [],
    plants: await gmFetchSafe('/rest/v1/plants?select=id,slug,common_name,botanical_name,is_published,genetic_lineage_type,updated_at&order=common_name') || [],
    hinges: await gmFetchSafe('/rest/v1/plant_ingredients?select=plant_id,ingredient_id,part,is_primary') || [],
    pages: await gmFetchSafe('/rest/v1/site_pages?or=(path.eq.garden-directory.html,path.eq.garden-plant.html,path.eq.my-garden.html)&select=path,name,visibility') || [],
    lessons: await gmFetchSafe('/rest/v1/lessons?select=id,slug,title,is_published') || [],
    topics: await gmFetchSafe('/rest/v1/topics?select=id,slug,name') || []
  };
  _gmCache.core = core;
  return core;
}

function gmClimateName(core, id) {
  var c = (core.climates || []).find(function (x) { return x.id === id; });
  return c ? c.name : '—';
}

async function gmLoadSpeciesDetail(slug) {
  if (!slug) return null;
  var key = 'species:' + slug;
  if (_gmCache[key]) return _gmCache[key];
  var plant = await gmFetchSafe('/rest/v1/plants?slug=eq.' + encodeURIComponent(slug) + '&select=*');
  if (!plant || !plant.length) return null;
  var p = plant[0];
  var detail = {
    plant: p,
    parts: await gmFetchSafe('/rest/v1/plant_parts?plant_id=eq.' + p.id + '&select=part,role,notes&order=part') || [],
    care: await gmFetchSafe('/rest/v1/plant_climate_care?plant_id=eq.' + p.id + '&select=climate_zone_id,field_key,core,risk,fix&order=field_key') || [],
    calendar: await gmFetchSafe('/rest/v1/plant_calendar?plant_id=eq.' + p.id + '&select=activity,month_start,month_end,climate_zone_id,notes&order=activity') || [],
    companions: await gmFetchSafe('/rest/v1/plant_companions?plant_id=eq.' + p.id + '&select=other_plant_id,relationship,reason') || [],
    hinges: await gmFetchSafe('/rest/v1/plant_ingredients?plant_id=eq.' + p.id + '&select=ingredient_id,part,is_primary') || [],
    culture: await gmFetchSafe('/rest/v1/plant_culture?plant_id=eq.' + p.id + '&select=region_id,local_name,placement_status') || []
  };
  var ingIds = detail.hinges.map(function (h) { return h.ingredient_id; }).filter(Boolean);
  if (ingIds.length) {
    detail.ingredients = await gmFetchSafe('/rest/v1/ingredients?ID=in.(' + ingIds.join(',') + ')&select=ID,Name,Category') || [];
  } else {
    detail.ingredients = [];
  }
  _gmCache[key] = detail;
  return detail;
}

function gmMonthLabel(n) {
  return ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][n] || String(n);
}

async function gmTogglePublish(slug, currentlyPublished, btn) {
  if (!slug || !confirm((currentlyPublished ? 'Unpublish' : 'Publish') + ' "' + slug + '" on the public site?')) return;
  if (btn) { btn.disabled = true; btn.textContent = '…'; }
  try {
    var res = await supaFetch('/rest/v1/plants?slug=eq.' + encodeURIComponent(slug), {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ is_published: !currentlyPublished })
    });
    if (!res.ok) throw new Error(String(res.status));
    delete _gmCache.core;
    Object.keys(_gmCache).forEach(function (k) { if (k.indexOf('species:') === 0) delete _gmCache[k]; });
    if (typeof loadGardenMgmtStats === 'function') loadGardenMgmtStats();
    if (typeof loadGardenSpeciesTable === 'function') {
      var tab = localStorage.getItem('tcj_active_garden_tab');
      if (tab === 'all') loadGardenSpeciesTable(false);
      if (tab === 'draft') loadGardenSpeciesTable(true);
    }
    reloadGmInterface();
  } catch (e) {
    alert('Publish toggle failed: ' + e.message);
    if (btn) { btn.disabled = false; btn.textContent = currentlyPublished ? 'Unpublish' : 'Publish'; }
  }
}

function gmFocusSpecies(slug) {
  _gmSelectedSlug = slug || '';
  localStorage.setItem('tcj_gm_selected_species', _gmSelectedSlug);
  localStorage.setItem('tcj_active_gm_tab', 'species');
  if (typeof switchGardenTab === 'function') switchGardenTab('gminterface');
  reloadGmInterface();
}

async function loadGmInterface(force) {
  var root = document.getElementById('gm-interface-content');
  if (!root) return;
  if (root.dataset.built === '1' && !force) return;

  root.innerHTML = '<div class="ap-loading" style="padding:24px">Loading GM Interface…</div>';

  var core;
  try {
    core = await gmLoadCoreData();
    if (!core.plants && !core.climates) throw new Error('no_tables');
  } catch (e) {
    root.innerHTML = '<p style="color:var(--warn,#c97);font-family:DM Sans,sans-serif;padding:12px 0">' +
      'GM Interface could not reach Garden tables. Run <code>RUN-GARDEN-V3.sql</code> on Supabase, then hard-refresh.</p>';
    return;
  }

  var TAB_DEFS = [
    { key: 'refdata', label: 'Lookup vocabularies' },
    { key: 'location', label: 'Climates & regions' },
    { key: 'species', label: 'Species registry' },
    { key: 'care', label: 'Care & calendar' },
    { key: 'kitchen', label: 'Kitchen links' },
    { key: 'health', label: 'Health & pipeline' }
  ];

  var activeTab = localStorage.getItem('tcj_active_gm_tab') || 'refdata';
  var html = '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-bottom:16px">' +
    '<span style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);flex:1;min-width:200px">' +
    'Sacred ground — slugs, UUIDs, and internal keys live here only. Public garden pages show names.</span>' +
    '<button type="button" class="ing-add-btn" onclick="reloadGmInterface()" style="font-size:11px;padding:6px 12px">↻ Refresh</button>' +
    '<a href="garden-directory.html" target="_blank" rel="noopener" class="ing-add-btn" style="font-size:11px;padding:6px 12px;text-decoration:none;display:inline-block">Member directory ↗</a>' +
    '</div>';

  html += '<div class="ap-inner-tabs" style="margin-bottom:16px" id="gm-subtabs">';
  TAB_DEFS.forEach(function (td) {
    html += '<button type="button" class="ap-inner-tab' + (td.key === activeTab ? ' active' : '') + '" data-gmtab="' + td.key + '" onclick="gmSwitchTab(\'' + td.key + '\')">' + gmEsc(td.label) + '</button>';
  });
  html += '</div>';

  TAB_DEFS.forEach(function (td) {
    html += '<div id="gmpanel-' + td.key + '" style="display:' + (td.key === activeTab ? 'block' : 'none') + '"></div>';
  });

  root.innerHTML = html;
  root.dataset.built = '1';

  await gmRenderTab(activeTab, core);
}

function gmSwitchTab(tab) {
  localStorage.setItem('tcj_active_gm_tab', tab);
  document.querySelectorAll('#gm-subtabs .ap-inner-tab').forEach(function (b) {
    b.classList.toggle('active', b.dataset.gmtab === tab);
  });
  ['refdata', 'location', 'species', 'care', 'kitchen', 'health'].forEach(function (k) {
    var el = document.getElementById('gmpanel-' + k);
    if (el) el.style.display = k === tab ? 'block' : 'none';
  });
  gmRenderTab(tab);
}

async function gmRenderTab(tab, core) {
  var panel = document.getElementById('gmpanel-' + tab);
  if (!panel || panel.dataset.rendered === '1') return;
  panel.innerHTML = '<div class="ap-loading" style="padding:16px 0">Loading…</div>';
  if (!core) core = await gmLoadCoreData();

  try {
    if (tab === 'refdata') panel.innerHTML = await gmBuildRefDataTab(core);
    else if (tab === 'location') panel.innerHTML = gmBuildLocationTab(core);
    else if (tab === 'species') panel.innerHTML = await gmBuildSpeciesTab(core);
    else if (tab === 'care') panel.innerHTML = await gmBuildCareTab(core);
    else if (tab === 'kitchen') panel.innerHTML = await gmBuildKitchenTab(core);
    else if (tab === 'health') panel.innerHTML = gmBuildHealthTab(core);
    panel.dataset.rendered = '1';
  } catch (e) {
    panel.innerHTML = '<p style="color:#dc5050;font-size:13px">Tab error: ' + gmEsc(e.message) + '</p>';
  }
}

async function gmBuildRefDataTab(core) {
  var blocks = gmAccordion('Display policy',
    '<p style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.7;margin:0">' +
    '<strong>Public rule:</strong> members see climate name, plant name, variety name, lineage labels — never slugs or UUIDs. ' +
    'Excel export (completed records) and care-card PPT download ship once species profiles are stable.</p>', true);

  blocks += gmAccordion('Variety lineage labels (public display)',
    '<ul style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.8;margin:0;padding-left:18px">' +
    _gmLineage.map(function (l) {
      return '<li>' + l.emoji + ' <code>' + l.v + '</code> → <strong>' + gmEsc(l.l) + '</strong></li>';
    }).join('') + '</ul>', true);

  for (var i = 0; i < _gmLookupDefs.length; i++) {
    var def = _gmLookupDefs[i];
    var rows = await gmFetchSafe('/rest/v1/' + def.table + '?select=' + def.cols + '&order=' + def.order);
    var count = Array.isArray(rows) ? rows.length : 0;
    var body;
    if (!rows || !count) {
      body = '<p style="font-size:12px;color:var(--text-muted)">No rows — seed via <code>garden-v3-07-seed-slice1.sql</code> or inbox lookup bundle.</p>';
    } else {
      var cols = def.cols.split(',');
      var head = '<tr>' + cols.map(function (c) { return '<th>' + gmEsc(c) + '</th>'; }).join('') + '</tr>';
      var tbody = rows.map(function (r) {
        return '<tr>' + cols.map(function (c) {
          return '<td' + (c === 'slug' ? ' style="font-family:monospace;font-size:11px"' : '') + '>' + gmEsc(r[c]) + '</td>';
        }).join('') + '</tr>';
      }).join('');
      body = '<p style="font-size:12px;color:var(--text-mid);margin:0 0 8px"><strong>' + count + '</strong> rows</p>' + gmTableWrap(head, tbody);
    }
    blocks += gmAccordion(def.label + ' (' + count + ')', body, i < 3);
  }
  return blocks;
}

function gmBuildLocationTab(core) {
  var climateRows = (core.climates || []).map(function (c) {
    return '<tr><td style="font-family:monospace;font-size:11px">' + gmEsc(c.slug) + '</td>' +
      '<td style="font-family:monospace;font-size:10px;color:var(--text-muted)">' + gmShortId(c.id) + '</td>' +
      '<td><strong>' + gmEsc(c.name) + '</strong></td></tr>';
  }).join('') || '<tr><td colspan="3" class="ap-empty-row">No climates — seed warm-temperate, humid-subtropical, tropical-monsoon.</td></tr>';

  var regionRows = (core.regions || []).map(function (r) {
    return '<tr><td style="font-family:monospace;font-size:11px">' + gmEsc(r.slug) + '</td>' +
      '<td>' + gmEsc(r.name) + '</td>' +
      '<td>' + gmEsc(gmClimateName(core, r.climate_zone_id)) + '</td>' +
      '<td>' + (r.is_active ? 'Yes' : 'No') + '</td></tr>';
  }).join('') || '<tr><td colspan="4" class="ap-empty-row">No regions (optional — culture only).</td></tr>';

  var zoneRows = (core.zones || []).map(function (z) {
    return '<tr><td>' + z.zone + '</td><td>' + gmEsc(z.name) + '</td><td style="color:var(--text-mid)">' + gmEsc(z.description) + '</td></tr>';
  }).join('') || '<tr><td colspan="3" class="ap-empty-row">No permaculture zones defined.</td></tr>';

  return gmAccordion('Growing climates (primary location key)', 
    '<p style="font-size:13px;color:var(--text-mid);margin:0 0 12px">Climate-first growing — not city-first. Inbox “Brisbane” maps to <code>humid-subtropical</code>; “Kerala” to <code>tropical-monsoon</code>.</p>' +
    gmTableWrap('<tr><th>Slug (admin)</th><th>ID</th><th>Display name (public)</th></tr>', climateRows), true) +
    gmAccordion('Regions (culture & optional display)', 
    '<p style="font-size:12px;color:var(--text-muted);margin:0 0 10px">Regions are demoted — used for cultural context, not primary growing logic.</p>' +
    gmTableWrap('<tr><th>Slug</th><th>Name</th><th>Climate</th><th>Active</th></tr>', regionRows), false) +
    gmAccordion('Permaculture zones (A.13 map)', gmTableWrap('<tr><th>Zone</th><th>Name</th><th>Description</th></tr>', zoneRows), false);
}

async function gmBuildSpeciesTab(core) {
  var options = (core.plants || []).map(function (p) {
    return '<option value="' + gmEsc(p.slug) + '"' + (p.slug === _gmSelectedSlug ? ' selected' : '') + '>' +
      gmEsc(p.common_name) + ' (' + gmEsc(p.slug) + ')' + (p.is_published ? '' : ' — draft') + '</option>';
  }).join('');

  var registryRows = (core.plants || []).map(function (p) {
    var h = (core.hinges || []).filter(function (x) { return x.plant_id === p.id; }).length;
    return '<tr>' +
      '<td style="font-family:monospace;font-size:10px;color:var(--text-muted)">' + gmShortId(p.id) + '</td>' +
      '<td style="font-family:monospace;font-size:11px">' + gmEsc(p.slug) + '</td>' +
      '<td><strong>' + gmEsc(p.common_name) + '</strong><br><span style="font-size:11px;font-style:italic;color:var(--text-mid)">' + gmEsc(p.botanical_name) + '</span></td>' +
      '<td>' + (p.is_published ? '<span style="color:#6dc86d">Published</span>' : '<span style="color:var(--warn,#c97)">Draft</span>') + '</td>' +
      '<td>' + h + '</td>' +
      '<td style="white-space:nowrap">' +
      '<button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px;margin-right:4px" onclick="gmFocusSpecies(' + JSON.stringify(p.slug) + ')">Detail</button>' +
      '<button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px;margin-right:4px" onclick="gmTogglePublish(' + JSON.stringify(p.slug) + ',' + (p.is_published ? 'true' : 'false') + ',this)">' + (p.is_published ? 'Unpublish' : 'Publish') + '</button>' +
      '<a href="garden-plant.html?slug=' + encodeURIComponent(p.slug) + '" target="_blank" rel="noopener" style="font-size:10px;color:var(--accent)">Preview ↗</a>' +
      '</td></tr>';
  }).join('') || '<tr><td colspan="6" class="ap-empty-row">No species — run Garden v3 seed.</td></tr>';

  var detailHtml = '';
  if (_gmSelectedSlug) {
    var detail = await gmLoadSpeciesDetail(_gmSelectedSlug);
    if (detail && detail.plant) {
      var p = detail.plant;
      var adminFields = [
        ['ID', gmShortId(p.id)], ['Slug', p.slug], ['Common name', p.common_name], ['Botanical', p.botanical_name],
        ['Family', p.plant_family], ['Type', p.plant_type], ['Lineage', p.genetic_lineage_type || '—'],
        ['Published', p.is_published ? 'Yes' : 'No'], ['Care summary', p.care_summary]
      ];
      detailHtml = '<div style="margin-top:16px;padding:14px;border:1px solid var(--border);border-radius:10px;background:rgba(255,255,255,0.02)">' +
        '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;margin-bottom:10px">Species detail — ' + gmEsc(p.common_name) + '</div>' +
        '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:8px;font-family:DM Sans,sans-serif;font-size:12px;margin-bottom:12px">' +
        adminFields.map(function (pair) {
          return '<div><span style="color:var(--text-muted);text-transform:uppercase;font-size:10px;letter-spacing:.06em">' + gmEsc(pair[0]) + '</span><br>' + gmEsc(pair[1]) + '</div>';
        }).join('') + '</div>';

      if (detail.parts.length) {
        detailHtml += '<p style="font-size:11px;color:var(--text-muted);margin:12px 0 6px">Plant parts</p>' +
          gmTableWrap('<tr><th>Part</th><th>Role</th><th>Notes</th></tr>',
            detail.parts.map(function (x) {
              return '<tr><td>' + gmEsc(x.part) + '</td><td>' + gmEsc(x.role) + '</td><td>' + gmEsc(x.notes) + '</td></tr>';
            }).join(''));
      }
      detailHtml += '<p style="font-size:11px;color:var(--text-muted);margin:12px 0 6px">Full 83-field profile editing + variety layer (<code>plant_varieties</code>) — Garden v4.</p></div>';
    }
  }

  return gmAccordion('Species registry (' + (core.plants || []).length + ')',
    gmTableWrap('<tr><th>ID</th><th>Slug</th><th>Names</th><th>Status</th><th>Kitchen</th><th></th></tr>', registryRows) +
    '<div style="margin-top:14px"><label style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid)">Inspect species detail</label>' +
    '<select class="ap-search" style="margin-top:6px;max-width:360px" onchange="gmFocusSpecies(this.value)">' +
    '<option value="">— Select —</option>' + options + '</select></div>' + detailHtml, true);
}

async function gmBuildCareTab(core) {
  var slug = _gmSelectedSlug || ((core.plants || [])[0] && core.plants[0].slug) || '';
  if (!slug) return '<p class="ap-empty-row">No species to show care data.</p>';

  var detail = await gmLoadSpeciesDetail(slug);
  if (!detail) return '<p class="ap-empty-row">Could not load care for ' + gmEsc(slug) + '.</p>';

  var careRows = detail.care.map(function (c) {
    return '<tr><td>' + gmEsc(gmClimateName(core, c.climate_zone_id)) + '</td>' +
      '<td><code>' + gmEsc(c.field_key) + '</code></td>' +
      '<td>' + gmEsc(c.core) + '</td><td style="color:var(--warn,#c97)">' + gmEsc(c.risk) + '</td><td>' + gmEsc(c.fix) + '</td></tr>';
  }).join('') || '<tr><td colspan="5" class="ap-empty-row">No climate care rows for this species.</td></tr>';

  var calRows = detail.calendar.map(function (c) {
    var range = gmMonthLabel(c.month_start) + (c.month_end && c.month_end !== c.month_start ? '–' + gmMonthLabel(c.month_end) : '');
    return '<tr><td>' + gmEsc(c.activity) + '</td><td>' + gmEsc(range) + '</td>' +
      '<td>' + gmEsc(gmClimateName(core, c.climate_zone_id)) + '</td><td>' + gmEsc(c.notes) + '</td></tr>';
  }).join('') || '<tr><td colspan="4" class="ap-empty-row">No calendar rows.</td></tr>';

  var selector = '<select class="ap-search" style="max-width:320px;margin-bottom:12px" onchange="gmFocusSpecies(this.value);gmSwitchTab(\'care\');var p=document.getElementById(\'gmpanel-care\');if(p){delete p.dataset.rendered;p.innerHTML=\'\';}gmRenderTab(\'care\')">' +
    (core.plants || []).map(function (p) {
      return '<option value="' + gmEsc(p.slug) + '"' + (p.slug === slug ? ' selected' : '') + '>' + gmEsc(p.common_name) + '</option>';
    }).join('') + '</select>';

  return '<p style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);margin:0 0 8px">Care card fields per climate (PPT export matches inbox Artichoke layout — later).</p>' +
    selector +
    gmAccordion('Climate care (' + detail.care.length + ')', gmTableWrap('<tr><th>Climate</th><th>Field</th><th>Core</th><th>Risk</th><th>Fix</th></tr>', careRows), true) +
    gmAccordion('Growing calendar (' + detail.calendar.length + ')', gmTableWrap('<tr><th>Activity</th><th>Months</th><th>Climate</th><th>Notes</th></tr>', calRows), true);
}

async function gmBuildKitchenTab(core) {
  var slug = _gmSelectedSlug || ((core.plants || [])[0] && core.plants[0].slug) || '';
  if (!slug) return '<p class="ap-empty-row">No species.</p>';

  var detail = await gmLoadSpeciesDetail(slug);
  var ingMap = {};
  (detail.ingredients || []).forEach(function (i) { ingMap[i.ID] = i; });

  var hingeRows = (detail.hinges || []).map(function (h) {
    var ing = ingMap[h.ingredient_id];
    return '<tr><td>' + (ing ? gmEsc(ing.Name) : 'ID ' + h.ingredient_id) + '</td>' +
      '<td style="font-family:monospace;font-size:10px">' + (ing ? h.ingredient_id : '—') + '</td>' +
      '<td>' + gmEsc(h.part) + '</td><td>' + (h.is_primary ? 'Primary' : '—') + '</td>' +
      '<td>' + (ing && ing.Category ? gmEsc(ing.Category) : '—') + '</td></tr>';
  }).join('') || '<tr><td colspan="5" class="ap-empty-row">No kitchen hinges — link to governed ingredient.</td></tr>';

  var missing = (core.plants || []).filter(function (p) {
    return !(core.hinges || []).some(function (h) { return h.plant_id === p.id; });
  });

  return gmAccordion('Kitchen hinges — ' + gmEsc((detail.plant && detail.plant.common_name) || slug),
    gmTableWrap('<tr><th>Ingredient (public)</th><th>ID (admin)</th><th>Part</th><th>Role</th><th>Category</th></tr>', hingeRows) +
    (missing.length ? '<p style="margin-top:10px;font-size:12px;color:var(--warn,#c97)">Species missing hinges: ' + missing.map(function (p) { return gmEsc(p.common_name); }).join(', ') + '</p>' : ''), true) +
    gmAccordion('All species hinge status',
    gmTableWrap('<tr><th>Species</th><th>Slug</th><th>Hinges</th></tr>',
      (core.plants || []).map(function (p) {
        var n = (core.hinges || []).filter(function (h) { return h.plant_id === p.id; }).length;
        return '<tr><td>' + gmEsc(p.common_name) + '</td><td style="font-family:monospace;font-size:11px">' + gmEsc(p.slug) + '</td>' +
          '<td style="color:' + (n ? '#6dc86d' : 'var(--warn,#c97)') + '">' + n + '</td></tr>';
      }).join('')), false);
}

function gmBuildHealthTab(core) {
  var health = [];
  if (!(core.climates || []).length) health.push('No climate zones seeded.');
  if ((core.climates || []).length < 2) health.push('Only ' + (core.climates || []).length + ' climate — add humid-subtropical + tropical-monsoon for inbox coverage.');
  if (!(core.plants || []).length) health.push('No species rows.');
  (core.plants || []).forEach(function (p) {
    if (!(core.hinges || []).some(function (h) { return h.plant_id === p.id; })) {
      health.push('Missing kitchen hinge: ' + p.common_name);
    }
  });
  if ((core.plants || []).length === 1) health.push('Only 1 species — 208 Variety Assessments in brainstorm-inbox await import.');
  var draft = (core.plants || []).filter(function (p) { return !p.is_published; });
  if (draft.length) health.push(draft.length + ' draft species not visible on public site.');

  var healthHtml = health.length
    ? '<ul style="color:var(--warn,#c97);font-size:13px;line-height:1.7;margin:0;padding-left:18px">' + health.map(function (h) { return '<li>' + gmEsc(h) + '</li>'; }).join('') + '</ul>'
    : '<p style="color:#6dc86d;font-size:13px;margin:0">No blocking issues detected for current v3 slice.</p>';

  var pageRows = (core.pages || []).map(function (pg) {
    return '<tr><td>' + gmEsc(pg.path) + '</td><td>' + gmEsc(pg.name) + '</td><td>' + gmEsc(pg.visibility) + '</td>' +
      '<td><button type="button" class="ing-add-btn" style="font-size:11px;padding:4px 10px" onclick="switchView(\'site-mgmt\');switchSMTab(\'sm-pages\')">Site Mgmt →</button></td></tr>';
  }).join('') || '<tr><td colspan="4" class="ap-empty-row">Garden pages not in site_pages — run fix-garden-v3-visible.sql</td></tr>';

  return gmAccordion('Health checks', healthHtml, true) +
    gmAccordion('Garden site pages', '<p style="font-size:12px;color:var(--text-mid)">Visibility owned by Site Management → Pages.</p>' +
      gmTableWrap('<tr><th>Path</th><th>Name</th><th>Visibility</th><th></th></tr>', pageRows), true) +
    gmAccordion('Content counts',
      '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:10px;font-family:DM Sans,sans-serif;font-size:13px">' +
      '<div><strong>' + (core.plants || []).length + '</strong> species</div>' +
      '<div><strong>' + (core.climates || []).length + '</strong> climates</div>' +
      '<div><strong>' + (core.regions || []).length + '</strong> regions</div>' +
      '<div><strong>' + (core.lessons || []).length + '</strong> lessons</div>' +
      '<div><strong>' + (core.topics || []).length + '</strong> topics</div>' +
      '</div>', false) +
    gmAccordion('Import & export pipeline (v4+)',
      '<p style="font-size:13px;color:var(--text-mid);line-height:1.7;margin:0 0 10px">' +
      '<strong>Import:</strong> <code>brainstorm-inbox/Variety Assessments/*.docx</code> → parse → staging → approve → <code>plants</code> + <code>plant_varieties</code> per climate.<br>' +
      '<strong>Export:</strong> completed online records → Excel (your TCJ column format).<br>' +
      '<strong>Care cards:</strong> per-species download → PPT (Artichoke template).</p>' +
      '<p style="font-size:12px;color:var(--text-muted);margin:0">208 assessments on disk. Tomato docx: 56+ Brisbane cultivars.</p>', false);
}
