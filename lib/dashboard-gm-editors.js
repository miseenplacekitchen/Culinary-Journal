// dashboard-gm-editors.js — GM species, cultivar, care/calendar editors
(function (global) {
  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function optList(items, valField, labelField, selected) {
    return (items || []).map(function (x) {
      var v = x[valField];
      return '<option value="' + esc(v) + '"' + (v === selected ? ' selected' : '') + '>' + esc(x[labelField]) + '</option>';
    }).join('');
  }

  async function loadLookups() {
    if (global._gmLookups) return global._gmLookups;
    var tables = {};
    var out = {};
    var fetches = [
      ['cat_high_level', '/rest/v1/cat_high_level?select=id,slug,name&order=name'],
      ['cat_main', '/rest/v1/cat_main?select=id,slug,name&order=name'],
      ['growth_habits', '/rest/v1/growth_habits?select=id,slug,name&order=name'],
      ['garden_layers', '/rest/v1/garden_layers?select=id,slug,name&order=name'],
      ['lifecycles', '/rest/v1/lifecycles?select=id,slug,name&order=name'],
      ['ease_ratings', '/rest/v1/ease_ratings?select=id,score,name&order=score'],
      ['seed_saving_groups', '/rest/v1/seed_saving_groups?select=id,grp,name&order=grp']
    ];
    for (var i = 0; i < fetches.length; i++) {
      out[fetches[i][0]] = await global.gmFetchSafe(fetches[i][1]) || [];
    }
    global._gmLookups = out;
    return out;
  }

  function fieldInput(id, label, value, wide) {
    return '<label style="' + (wide ? 'grid-column:1/-1;' : '') + 'font-family:DM Sans,sans-serif;font-size:12px">' +
      '<span style="color:var(--text-muted);font-size:10px;text-transform:uppercase">' + esc(label) + '</span>' +
      '<input id="' + id + '" class="ap-search" style="margin-top:4px;width:100%" value="' + esc(value || '') + '"></label>';
  }

  function fieldText(id, label, value) {
    return '<label style="grid-column:1/-1;font-family:DM Sans,sans-serif;font-size:12px">' +
      '<span style="color:var(--text-muted);font-size:10px;text-transform:uppercase">' + esc(label) + '</span>' +
      '<textarea id="' + id + '" class="ap-search" rows="2" style="margin-top:4px;width:100%">' + esc(value || '') + '</textarea></label>';
  }

  function fieldSelect(id, label, optionsHtml) {
    return '<label style="font-family:DM Sans,sans-serif;font-size:12px">' +
      '<span style="color:var(--text-muted);font-size:10px;text-transform:uppercase">' + esc(label) + '</span>' +
      '<select id="' + id + '" class="ap-search" style="margin-top:4px;width:100%">' +
      '<option value="">—</option>' + optionsHtml + '</select></label>';
  }

  async function renderSpeciesTab(core, selectedSlug) {
    var slug = selectedSlug || '';
    var lookups = await loadLookups();
    var options = (core.plants || []).map(function (p) {
      return '<option value="' + esc(p.slug) + '"' + (p.slug === slug ? ' selected' : '') + '>' +
        esc(p.common_name) + ' (' + esc(p.slug) + ')' + (p.is_published ? '' : ' — draft') + '</option>';
    }).join('');

    var registryRows = (core.plants || []).map(function (p) {
      return '<tr><td style="font-family:monospace;font-size:11px">' + esc(p.slug) + '</td>' +
        '<td><strong>' + esc(p.common_name) + '</strong></td>' +
        '<td>' + (p.is_published ? 'Published' : 'Draft') + '</td>' +
        '<td><button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px" onclick="gmFocusSpecies(' + JSON.stringify(p.slug) + ')">Edit</button></td></tr>';
    }).join('') || '<tr><td colspan="4" class="ap-empty-row">No species yet.</td></tr>';

    var detail = '';
    if (slug) {
      var d = await global.gmLoadSpeciesDetail(slug);
      if (d && d.plant) {
        var p = d.plant;
        var mediaBlock = await renderMediaBlock(p.id, slug);
        detail = '<div style="margin-top:16px;padding:14px;border:1px solid var(--border);border-radius:10px">' +
          '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;margin-bottom:12px">Edit — ' + esc(p.common_name) + '</div>' +
          '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px">' +
          fieldInput('gm-edit-common_name', 'Common name (public)', p.common_name) +
          fieldInput('gm-edit-botanical_name', 'Botanical name', p.botanical_name) +
          fieldInput('gm-edit-plant_family', 'Family', p.plant_family) +
          fieldInput('gm-edit-plant_type', 'Plant type', p.plant_type) +
          fieldInput('gm-edit-origin', 'Origin', p.origin) +
          fieldInput('gm-edit-size_height', 'Height', p.size_height) +
          fieldInput('gm-edit-size_spread', 'Spread', p.size_spread) +
          fieldInput('gm-edit-growth_rate', 'Growth rate', p.growth_rate) +
          fieldInput('gm-edit-time_to_harvest', 'Time to harvest', p.time_to_harvest) +
          fieldSelect('gm-edit-high_level_category_id', 'High-level category',
            optList(lookups.cat_high_level, 'id', 'name', p.high_level_category_id)) +
          fieldSelect('gm-edit-main_category_id', 'Main category',
            optList(lookups.cat_main, 'id', 'name', p.main_category_id)) +
          fieldSelect('gm-edit-growth_habit_id', 'Growth habit',
            optList(lookups.growth_habits, 'id', 'name', p.growth_habit_id)) +
          fieldSelect('gm-edit-garden_layer_id', 'Garden layer',
            optList(lookups.garden_layers, 'id', 'name', p.garden_layer_id)) +
          fieldSelect('gm-edit-lifecycle_id', 'Lifecycle',
            optList(lookups.lifecycles, 'id', 'name', p.lifecycle_id)) +
          fieldSelect('gm-edit-ease_rating_id', 'Ease rating',
            optList(lookups.ease_ratings, 'id', 'name', p.ease_rating_id)) +
          fieldSelect('gm-edit-seed_saving_group_id', 'Seed-saving group',
            optList(lookups.seed_saving_groups, 'id', 'name', p.seed_saving_group_id)) +
          fieldText('gm-edit-care_summary', 'Care summary (public)', p.care_summary) +
          fieldText('gm-edit-edible_parts', 'Edible parts', p.edible_parts) +
          fieldText('gm-edit-culinary_applications', 'Culinary applications', p.culinary_applications) +
          fieldText('gm-edit-toxic_parts', 'Toxic parts', p.toxic_parts) +
          fieldText('gm-edit-propagation_methods', 'Propagation', p.propagation_methods) +
          fieldText('gm-edit-harvest_season', 'Harvest season', p.harvest_season) +
          '</div>' +
          mediaBlock +
          '<div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap">' +
          '<button type="button" class="ing-add-btn" onclick="GmEditors.saveSpecies(' + JSON.stringify(slug) + ',this)">Save species</button>' +
          '<button type="button" class="ing-add-btn" onclick="gmTogglePublish(' + JSON.stringify(slug) + ',' + (p.is_published ? 'true' : 'false') + ',this)">' + (p.is_published ? 'Unpublish' : 'Publish') + '</button>' +
          '<a href="garden-plant.html?slug=' + encodeURIComponent(slug) + '" target="_blank" rel="noopener" style="font-size:11px;color:var(--accent);align-self:center">Preview ↗</a>' +
          '</div></div>';
      }
    }

    return '<div style="display:flex;gap:8px;margin-bottom:14px;flex-wrap:wrap">' +
      '<button type="button" class="ing-add-btn" onclick="GmEditors.promptNewSpecies()">+ New species</button>' +
      '</div>' +
      global.gmTableWrap('<tr><th>Slug</th><th>Name</th><th>Status</th><th></th></tr>', registryRows) +
      '<div style="margin-top:14px"><label style="font-size:12px;color:var(--text-mid)">Edit species</label>' +
      '<select class="ap-search" style="margin-top:6px;max-width:400px" onchange="gmFocusSpecies(this.value)">' +
      '<option value="">— Select —</option>' + options + '</select></div>' + detail;
  }

  async function saveSpecies(slug, btn) {
    if (!slug) return;
    var fields = {};
    [
      'common_name', 'botanical_name', 'plant_family', 'plant_type', 'origin', 'size_height', 'size_spread',
      'growth_rate', 'time_to_harvest', 'care_summary', 'edible_parts', 'culinary_applications', 'toxic_parts',
      'propagation_methods', 'harvest_season',
      'high_level_category_id', 'main_category_id', 'growth_habit_id', 'garden_layer_id',
      'lifecycle_id', 'ease_rating_id', 'seed_saving_group_id'
    ].forEach(function (k) {
      var el = document.getElementById('gm-edit-' + k);
      if (el) fields[k] = el.value || null;
    });
    if (btn) { btn.disabled = true; btn.textContent = 'Saving…'; }
    try {
      await global.rpc('admin_patch_garden_species', { p_slug: slug, p_fields: fields });
      delete global._gmCache['species:' + slug];
      if (btn) btn.textContent = 'Saved';
      setTimeout(function () { if (btn) { btn.disabled = false; btn.textContent = 'Save species'; } }, 1000);
    } catch (e) {
      alert('Save failed: ' + e.message);
      if (btn) { btn.disabled = false; btn.textContent = 'Save species'; }
    }
  }

  async function promptNewSpecies() {
    var name = prompt('Common name for new species:');
    if (!name) return;
    var botanical = prompt('Botanical name (optional):', '') || '';
    try {
      var res = await global.rpc('admin_create_garden_species', {
        p_row: { common_name: name, botanical_name: botanical, is_published: false }
      });
      if (res && res.slug) global.gmFocusSpecies(res.slug);
      global.reloadGmInterface();
    } catch (e) {
      alert('Create failed: ' + e.message);
    }
  }

  async function renderVarietiesTab(core) {
    var vars = await global.gmFetchSafe('/rest/v1/plant_varieties?select=id,slug,name,lineage_type,is_published,plant_id,origin,traits,growing_notes&order=name') || [];
    var plantMap = {};
    (core.plants || []).forEach(function (p) { plantMap[p.id] = p; });

    var rows = vars.map(function (v) {
      var sp = plantMap[v.plant_id] || {};
      return '<tr data-vid="' + esc(v.id) + '">' +
        '<td>' + esc(sp.common_name || '—') + '</td>' +
        '<td style="font-family:monospace;font-size:11px">' + esc(v.slug) + '</td>' +
        '<td><input class="ap-search gm-v-name" value="' + esc(v.name) + '" style="font-size:12px"></td>' +
        '<td><select class="ap-search gm-v-lineage" style="font-size:12px">' +
        ['heirloom', 'open_pollinated', 'hybrid', 'indigenous'].map(function (l) {
          return '<option value="' + l + '"' + (v.lineage_type === l ? ' selected' : '') + '>' + l + '</option>';
        }).join('') + '</select></td>' +
        '<td><button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px" onclick="GmEditors.saveCultivarRow(this)">Save</button></td></tr>';
    }).join('') || '<tr><td colspan="5" class="ap-empty-row">No cultivars.</td></tr>';

    return '<p style="font-size:13px;color:var(--text-mid);margin:0 0 10px">Edit cultivar names and lineage. Import queue <strong>Apply</strong> bulk-loads; refine here.</p>' +
      '<button type="button" class="ing-add-btn" style="margin-bottom:12px;font-size:11px" onclick="GmEditors.promptNewCultivar()">+ Add cultivar</button>' +
      '<button type="button" class="ing-add-btn" style="margin-bottom:12px;margin-left:8px;font-size:11px" onclick="gmExportCultivarsCsv()">Export CSV</button>' +
      global.gmTableWrap('<tr><th>Species</th><th>Slug</th><th>Name</th><th>Lineage</th><th></th></tr>', rows);
  }

  async function saveCultivarRow(btn) {
    var tr = btn.closest('tr');
    if (!tr) return;
    var id = tr.dataset.vid;
    var name = tr.querySelector('.gm-v-name').value;
    var lineage = tr.querySelector('.gm-v-lineage').value;
    btn.disabled = true;
    try {
      await global.rpc('admin_upsert_garden_cultivar', { p_row: { id: id, name: name, lineage_type: lineage } });
      btn.textContent = 'OK';
      setTimeout(function () { btn.disabled = false; btn.textContent = 'Save'; }, 800);
    } catch (e) {
      alert(e.message);
      btn.disabled = false;
    }
  }

  async function promptNewCultivar() {
    var slug = prompt('Species slug (e.g. tomato):');
    if (!slug) return;
    var name = prompt('Cultivar name:');
    if (!name) return;
    var climate = prompt('Climate slug (humid-subtropical or tropical-monsoon):', 'humid-subtropical');
    try {
      await global.rpc('admin_upsert_garden_cultivar', {
        p_row: { plant_slug: slug, name: name, climate_slug: climate, lineage_type: 'open_pollinated' }
      });
      global.reloadGmInterface();
    } catch (e) {
      alert(e.message);
    }
  }

  async function renderCareTab(core, selectedSlug) {
    var slug = selectedSlug || ((core.plants || [])[0] && core.plants[0].slug) || '';
    if (!slug) return '<p class="ap-empty-row">No species.</p>';

    var detail = await global.gmLoadSpeciesDetail(slug);
    if (!detail) return '<p class="ap-empty-row">Could not load ' + esc(slug) + '</p>';

    var climates = core.climates || [];
    var climateOpts = climates.map(function (c) {
      return '<option value="' + esc(c.slug) + '">' + esc(c.name) + '</option>';
    }).join('');

    var careRows = detail.care.map(function (c, i) {
      var cz = climates.find(function (x) { return x.id === c.climate_zone_id; });
      return '<tr data-ci="' + i + '">' +
        '<td>' + esc(cz ? cz.name : '—') + '</td>' +
        '<td><input class="ap-search gm-c-field" value="' + esc(c.field_key) + '" style="font-size:11px;width:90px"></td>' +
        '<td><input class="ap-search gm-c-core" value="' + esc(c.core) + '" style="font-size:12px"></td>' +
        '<td><input class="ap-search gm-c-risk" value="' + esc(c.risk) + '" style="font-size:12px"></td>' +
        '<td><input class="ap-search gm-c-fix" value="' + esc(c.fix) + '" style="font-size:12px"></td>' +
        '<td><button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 6px" onclick="GmEditors.saveCareRow(' + JSON.stringify(slug) + ',' + JSON.stringify(cz ? cz.slug : '') + ',this)">Save</button></td></tr>';
    }).join('') || '<tr><td colspan="6" class="ap-empty-row">No care rows — add below.</td></tr>';

    var calRows = detail.calendar.map(function (c) {
      var cz = climates.find(function (x) { return x.id === c.climate_zone_id; });
      var range = (c.month_start || '') + '-' + (c.month_end || '');
      return '<tr><td>' + esc(c.activity) + '</td><td>' + esc(range) + '</td><td>' + esc(cz ? cz.name : '—') + '</td><td>' + esc(c.notes) + '</td></tr>';
    }).join('') || '<tr><td colspan="4" class="ap-empty-row">No calendar rows.</td></tr>';

    var selector = '<select class="ap-search" style="max-width:280px;margin-bottom:10px" onchange="gmFocusSpecies(this.value);gmSwitchTab(\'care\');gmRefreshGmTab(\'care\')">' +
      (core.plants || []).map(function (p) {
        return '<option value="' + esc(p.slug) + '"' + (p.slug === slug ? ' selected' : '') + '>' + esc(p.common_name) + '</option>';
      }).join('') + '</select>';

    return selector +
      '<div style="margin-bottom:16px;padding:12px;border:1px dashed var(--border);border-radius:8px">' +
      '<p style="font-size:11px;color:var(--text-muted);margin:0 0 8px">Add care field</p>' +
      '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end">' +
      '<label style="font-size:12px">Climate<select id="gm-new-care-climate" class="ap-search" style="margin-left:6px">' + climateOpts + '</select></label>' +
      '<label style="font-size:12px">Field<input id="gm-new-care-field" class="ap-search" placeholder="sunlight" style="margin-left:6px;width:100px"></label>' +
      '<label style="font-size:12px">Core<input id="gm-new-care-core" class="ap-search" style="margin-left:6px;min-width:160px"></label>' +
      '<button type="button" class="ing-add-btn" style="font-size:11px" onclick="GmEditors.addCareRow(' + JSON.stringify(slug) + ')">Add care row</button>' +
      '</div></div>' +
      global.gmAccordion('Climate care (' + detail.care.length + ')',
        global.gmTableWrap('<tr><th>Climate</th><th>Field</th><th>Core</th><th>Risk</th><th>Fix</th><th></th></tr>', careRows), true) +
      '<div style="margin-bottom:16px;padding:12px;border:1px dashed var(--border);border-radius:8px;margin-top:12px">' +
      '<p style="font-size:11px;color:var(--text-muted);margin:0 0 8px">Add calendar row</p>' +
      '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end">' +
      '<label style="font-size:12px">Climate<select id="gm-new-cal-climate" class="ap-search" style="margin-left:6px">' + climateOpts + '</select></label>' +
      '<label style="font-size:12px">Activity<select id="gm-new-cal-act" class="ap-search" style="margin-left:6px">' +
      ['sow', 'transplant', 'plant', 'harvest', 'prune'].map(function (a) { return '<option value="' + a + '">' + a + '</option>'; }).join('') +
      '</select></label>' +
      '<label style="font-size:12px">Month start<input id="gm-new-cal-ms" type="number" min="1" max="12" class="ap-search" style="margin-left:6px;width:50px" value="3"></label>' +
      '<label style="font-size:12px">Month end<input id="gm-new-cal-me" type="number" min="1" max="12" class="ap-search" style="margin-left:6px;width:50px" value="4"></label>' +
      '<button type="button" class="ing-add-btn" style="font-size:11px" onclick="GmEditors.addCalendarRow(' + JSON.stringify(slug) + ')">Add calendar row</button>' +
      '</div></div>' +
      global.gmAccordion('Growing calendar (' + detail.calendar.length + ')',
        global.gmTableWrap('<tr><th>Activity</th><th>Months</th><th>Climate</th><th>Notes</th></tr>', calRows), true) +
      '<button type="button" class="ing-add-btn" style="font-size:11px;margin-top:8px;margin-right:8px" onclick="gmExportCareCard(' + JSON.stringify(slug) + ')">Download care-card JSON</button>' +
      '<button type="button" class="ing-add-btn" style="font-size:11px;margin-top:8px" onclick="gmExportCareCardPptx(' + JSON.stringify(slug) + ')">Download care-card PPT</button>';
  }

  function gmSessionToken() {
    try {
      var raw = localStorage.getItem('tcj_session');
      var s = raw ? JSON.parse(raw) : null;
      return s && s.access_token ? s.access_token : '';
    } catch (_) {
      return '';
    }
  }

  function gmMediaPublicUrl(path) {
    return window.SUPA_URL + '/storage/v1/object/public/garden-media/' + path;
  }

  async function gmUploadGardenBlob(file, relativePath) {
    var token = gmSessionToken();
    if (!token || !window.SUPA_URL) throw new Error('Missing Supabase session');
    var res = await fetch(window.SUPA_URL + '/storage/v1/object/garden-media/' + relativePath, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': file.type || 'image/jpeg',
        'x-upsert': 'true'
      },
      body: file
    });
    if (!res.ok) throw new Error('Upload failed (' + res.status + ')');
    return relativePath;
  }

  async function renderMediaBlock(plantId, slug) {
    var media = await global.gmFetchSafe(
      '/rest/v1/media?entity_type=eq.plant&entity_id=eq.' + plantId + '&select=id,bucket_path,alt_text,is_primary&order=created_at.desc'
    ) || [];
    var rows = media.map(function (m) {
      var url = gmMediaPublicUrl(m.bucket_path);
      return '<tr><td>' + (m.is_primary ? '★' : '') + '</td>' +
        '<td><a href="' + esc(url) + '" target="_blank" rel="noopener" style="font-size:11px">View</a></td>' +
        '<td style="font-size:11px">' + esc(m.alt_text || '—') + '</td>' +
        '<td style="font-family:monospace;font-size:10px">' + esc(m.bucket_path) + '</td>' +
        '<td><button type="button" class="ing-del-btn" style="font-size:10px;padding:3px 8px" onclick="GmEditors.removeMedia(' +
        JSON.stringify(m.id) + ',' + JSON.stringify(slug) + ',this)">Remove</button></td></tr>';
    }).join('') || '<tr><td colspan="5" class="ap-empty-row">No media — upload hero or reference photo.</td></tr>';

    return '<div style="margin-top:14px;padding-top:12px;border-top:1px dashed var(--border)">' +
      '<div style="font-weight:600;margin-bottom:8px;font-size:13px">Plant media (garden-media bucket)</div>' +
      global.gmTableWrap('<tr><th>Primary</th><th></th><th>Alt text</th><th>Path</th><th></th></tr>', rows) +
      '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end;margin-top:10px">' +
      '<label style="font-size:12px">Image file<br><input type="file" accept="image/*" id="gm-media-file"></label>' +
      '<label style="font-size:12px">Alt text<br><input id="gm-media-alt" class="ap-search" placeholder="Purple Romagna bud"></label>' +
      '<label style="font-size:12px;display:flex;align-items:center;gap:6px;margin-top:18px">' +
      '<input type="checkbox" id="gm-media-primary"> Primary</label>' +
      '<button type="button" class="ing-add-btn" style="font-size:11px;padding:6px 12px" onclick="GmEditors.uploadMedia(' +
      JSON.stringify(slug) + ',this)">Upload</button></div></div>';
  }

  async function uploadMedia(slug, btn) {
    var input = document.getElementById('gm-media-file');
    if (!input || !input.files || !input.files[0]) { alert('Choose an image file'); return; }
    var file = input.files[0];
    var alt = (document.getElementById('gm-media-alt') || {}).value || '';
    var primary = !!(document.getElementById('gm-media-primary') || {}).checked;
    var ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
    var path = 'plants/' + slug + '/' + Date.now() + '.' + ext;
    if (btn) { btn.disabled = true; btn.textContent = 'Uploading…'; }
    try {
      await gmUploadGardenBlob(file, path);
      await global.rpc('admin_register_plant_media', {
        p_plant_slug: slug,
        p_bucket_path: path,
        p_alt_text: alt,
        p_is_primary: primary
      });
      delete global._gmCache['species:' + slug];
      global.reloadGmInterface();
    } catch (e) {
      alert('Upload failed: ' + e.message);
      if (btn) { btn.disabled = false; btn.textContent = 'Upload'; }
    }
  }

  async function removeMedia(mediaId, slug, btn) {
    if (!mediaId || !confirm('Remove this media row?')) return;
    if (btn) btn.disabled = true;
    try {
      await global.rpc('admin_remove_plant_media', { p_media_id: mediaId });
      delete global._gmCache['species:' + slug];
      global.reloadGmInterface();
    } catch (e) {
      alert(e.message);
      if (btn) btn.disabled = false;
    }
  }

  async function saveCareRow(plantSlug, climateSlug, btn) {
    var tr = btn.closest('tr');
    if (!tr) return;
    btn.disabled = true;
    try {
      await global.rpc('admin_upsert_plant_care', {
        p_row: {
          plant_slug: plantSlug,
          climate_slug: climateSlug || document.getElementById('gm-new-care-climate').value,
          field_key: tr.querySelector('.gm-c-field').value,
          core: tr.querySelector('.gm-c-core').value,
          risk: tr.querySelector('.gm-c-risk').value,
          fix: tr.querySelector('.gm-c-fix').value
        }
      });
      delete global._gmCache['species:' + plantSlug];
      btn.textContent = 'OK';
      setTimeout(function () { btn.disabled = false; btn.textContent = 'Save'; }, 700);
    } catch (e) {
      alert(e.message);
      btn.disabled = false;
    }
  }

  async function addCareRow(slug) {
    try {
      await global.rpc('admin_upsert_plant_care', {
        p_row: {
          plant_slug: slug,
          climate_slug: document.getElementById('gm-new-care-climate').value,
          field_key: document.getElementById('gm-new-care-field').value || 'custom',
          core: document.getElementById('gm-new-care-core').value
        }
      });
      delete global._gmCache['species:' + slug];
      global.gmSwitchTab('care');
      global.gmRefreshGmTab('care');
    } catch (e) { alert(e.message); }
  }

  async function addCalendarRow(slug) {
    try {
      await global.rpc('admin_upsert_plant_calendar', {
        p_row: {
          plant_slug: slug,
          climate_slug: document.getElementById('gm-new-cal-climate').value,
          activity: document.getElementById('gm-new-cal-act').value,
          month_start: document.getElementById('gm-new-cal-ms').value,
          month_end: document.getElementById('gm-new-cal-me').value,
          notes: ''
        }
      });
      delete global._gmCache['species:' + slug];
      global.gmSwitchTab('care');
      global.gmRefreshGmTab('care');
    } catch (e) { alert(e.message); }
  }

  global.GmEditors = {
    renderSpeciesTab: renderSpeciesTab,
    renderVarietiesTab: renderVarietiesTab,
    renderCareTab: renderCareTab,
    saveSpecies: saveSpecies,
    saveCultivarRow: saveCultivarRow,
    promptNewSpecies: promptNewSpecies,
    promptNewCultivar: promptNewCultivar,
    saveCareRow: saveCareRow,
    addCareRow: addCareRow,
    addCalendarRow: addCalendarRow,
    uploadMedia: uploadMedia,
    removeMedia: removeMedia
  };
})(window);
