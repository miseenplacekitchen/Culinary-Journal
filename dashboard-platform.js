// Festival Management + Voice of the Customer — dashboard-platform.js

var VOC_CATEGORIES = [
  { id:'actionable', label:'Actionable', color:'#dc5050' },
  { id:'signals',    label:'Signals',    color:'#4caf76' },
  { id:'noise',      label:'Noise',      color:'#5B8FD4' }
];

var VOC_TYPE_MAP = {
  system_bug:'actionable', process_friction:'actionable', content_issue:'actionable', bug:'actionable',
  kudos:'signals', value_story:'signals', feature_wish:'signals', suggestion:'signals',
  user_error:'noise', vague_vent:'noise', known_repeat:'noise', general:'noise', recipe:'signals', other:'noise'
};

function switchFestTab(tab) {
  localStorage.setItem('tcj_active_fest_tab', tab);
  document.querySelectorAll('#v-festival-mgmt .ap-inner-tab').forEach(function(el) {
    el.classList.toggle('active', el.dataset.tab === tab);
  });
  var panel = document.getElementById('fest-panel');
  if (!panel) return;
  if (tab === 'fm-overview') loadFestOverview(panel);
  if (tab === 'fm-interface') loadFestInterface(panel);
}

function switchVocTab(tab) {
  localStorage.setItem('tcj_active_voc_tab', tab);
  document.querySelectorAll('#v-voc-mgmt .ap-inner-tab').forEach(function(el) {
    el.classList.toggle('active', el.dataset.tab === tab);
  });
  var panel = document.getElementById('voc-panel');
  if (!panel) return;
  if (tab === 'voc-inbox') loadVocInbox(panel);
  if (tab === 'voc-taxonomy') loadVocTaxonomy(panel);
}

function fmInput(label, id, val, ph) {
  return '<label style="display:block;font-family:DM Sans,sans-serif;font-size:10px;color:var(--text-mid);margin-bottom:4px">' + esc(label) +
    '</label><input id="' + id + '" value="' + esc(val || '') + '" placeholder="' + esc(ph || '') + '" style="width:100%;box-sizing:border-box;padding:8px 10px;border:1px solid var(--border);border-radius:8px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px;margin-bottom:10px">';
}

function fmBtn(label, onclick, accent) {
  return '<button type="button" onclick="' + onclick + '" style="padding:7px 14px;border-radius:8px;border:1px solid ' +
    (accent ? 'var(--accent)' : 'var(--border)') + ';background:' + (accent ? 'var(--accent)' : 'none') +
    ';color:' + (accent ? '#fff' : 'var(--text-mid)') + ';font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer">' + esc(label) + '</button>';
}

async function loadFestOverview(container) {
  container.innerHTML = '<div class="ap-loading">Loading festivals…</div>';
  try {
    var rows = await rpc('admin_get_festivals') || [];
    container.innerHTML =
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;flex-wrap:wrap;gap:10px">' +
        '<div style="font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high)">' + rows.length + ' festival' + (rows.length === 1 ? '' : 's') + '</div>' +
        fmBtn('+ Add festival', 'fmShowNewFest()', true) +
      '</div>' +
      '<div id="fm-new-fest" style="display:none;background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:16px"></div>' +
      '<div id="fm-overview-list"></div>';
    var list = document.getElementById('fm-overview-list');
    if (!rows.length) {
      list.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">No festivals yet — click Add festival.</div>';
      return;
    }
    rows.forEach(function(f) {
      var card = document.createElement('div');
      card.style.cssText = 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:14px 18px;margin-bottom:10px;display:flex;align-items:center;gap:14px;flex-wrap:wrap';
      card.innerHTML =
        '<span style="font-size:24px">' + (f.emoji || '🎉') + '</span>' +
        '<div style="flex:1;min-width:180px"><div style="font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high)">' + esc(f.name) + '</div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">' + esc(f.when_label || '') + ' · ' + (f.dish_count || 0) + ' dishes</div></div>' +
        '<label style="display:flex;align-items:center;gap:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);cursor:pointer">' +
          '<input type="checkbox" ' + (f.is_active ? 'checked' : '') + ' onchange="fmToggleActive(\'' + f.id + '\', this.checked)"> Show on Festival Planner</label>' +
        (f.planner_path ? '<a href="' + esc(f.planner_path) + '" target="_blank" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent)">Planner →</a>' : '') +
        '<a href="festival-planner.html" target="_blank" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent)">Public view →</a>' +
        fmBtn('Edit', 'switchFestTab(\'fm-interface\');fmEditFest(\'' + f.slug + '\')', false);
      list.appendChild(card);
    });
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

function fmShowNewFest() {
  var box = document.getElementById('fm-new-fest');
  if (!box) return;
  box.style.display = 'block';
  box.innerHTML =
    '<div style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;color:var(--text-high);margin-bottom:10px">New festival</div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">' +
      fmInput('Name', 'fm-nf-name', '', 'Diwali Feast') +
      fmInput('Slug (URL key)', 'fm-nf-slug', '', 'diwali-feast') +
      fmInput('Emoji', 'fm-nf-emoji', '🎉', '🪔') +
      fmInput('When', 'fm-nf-when', '', 'Oct–Nov') +
      fmInput('Planner page path', 'fm-nf-planner', '', 'diwali-planner.html') +
    '</div>' +
    fmInput('Description', 'fm-nf-desc', '', 'Short intro for the public planner') +
    '<div style="display:flex;gap:8px">' + fmBtn('Create', 'fmSaveNewFest()', true) + fmBtn('Cancel', 'document.getElementById(\'fm-new-fest\').style.display=\'none\'', false) + '</div>';
}

async function fmSaveNewFest() {
  try {
    await rpc('admin_upsert_festival', {
      p_slug: document.getElementById('fm-nf-slug').value.trim(),
      p_name: document.getElementById('fm-nf-name').value.trim(),
      p_emoji: document.getElementById('fm-nf-emoji').value.trim() || '🎉',
      p_when_label: document.getElementById('fm-nf-when').value.trim() || null,
      p_description: document.getElementById('fm-nf-desc').value.trim() || null,
      p_planner_path: document.getElementById('fm-nf-planner').value.trim() || null,
      p_is_active: true
    });
    auditLog('Festival Management', 'Created festival', null, null, null, null);
    loadFestOverview(document.getElementById('fest-panel'));
  } catch (e) { alert('Error: ' + e.message); }
}

async function fmToggleActive(id, on) {
  try {
    await rpc('admin_toggle_festival', { p_id: id, p_is_active: !!on });
    auditLog('Festival Management', on ? 'Activated festival' : 'Deactivated festival', null, id, null, null);
  } catch (e) { alert('Error: ' + e.message); loadFestOverview(document.getElementById('fest-panel')); }
}

var _fmEditSlug = '';

async function loadFestInterface(container) {
  container.innerHTML = '<div class="ap-loading">Loading FM Interface…</div>';
  try {
    var rows = await rpc('admin_get_festivals') || [];
    container.innerHTML =
      '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.7;margin-bottom:14px">' +
      'Edit festivals, define <strong style="color:var(--text-high)">sections</strong> (Main, Sides, Desserts…), add dish slots, and link approved recipe variants.</div>' +
      '<div style="display:flex;gap:10px;align-items:center;margin-bottom:16px;flex-wrap:wrap">' +
        '<label style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">Festival</label>' +
        '<select id="fm-pick-fest" style="padding:8px 12px;border-radius:8px;border:1px solid var(--border);background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px;min-width:220px"></select>' +
        fmBtn('Load', 'fmEditFest(document.getElementById(\'fm-pick-fest\').value)', true) +
      '</div>' +
      '<div id="fm-editor"></div>';
    var sel = document.getElementById('fm-pick-fest');
    rows.forEach(function(f) {
      var o = document.createElement('option');
      o.value = f.slug; o.textContent = (f.emoji || '') + ' ' + f.name;
      sel.appendChild(o);
    });
    if (_fmEditSlug) sel.value = _fmEditSlug;
    fmEditFest(sel.value || (rows[0] && rows[0].slug));
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050">Error: ' + esc(e.message) + '</div>';
  }
}

async function fmEditFest(slug) {
  if (!slug) return;
  _fmEditSlug = slug;
  var editor = document.getElementById('fm-editor');
  if (!editor) return;
  editor.innerHTML = '<div class="ap-loading">Loading ' + esc(slug) + '…</div>';
  var all = await rpc('admin_get_festivals') || [];
  var fest = all.find(function(f) { return f.slug === slug; });
  if (!fest) { editor.textContent = 'Festival not found.'; return; }
  var detail = await rpc('admin_get_festival_detail', { p_slug: slug }).catch(function() { return { dishes: [] }; });
  if (!detail) detail = fest;
  detail.dishes = detail.dishes || [];
  editor.innerHTML =
    '<div style="background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:16px">' +
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;color:var(--text-high);margin-bottom:10px">Festival details</div>' +
      '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px">' +
        fmInput('Name', 'fm-ef-name', fest.name) +
        fmInput('Slug', 'fm-ef-slug', fest.slug) +
        fmInput('Emoji', 'fm-ef-emoji', fest.emoji) +
        fmInput('When', 'fm-ef-when', fest.when_label) +
        fmInput('Planner path', 'fm-ef-planner', fest.planner_path) +
        fmInput('Sort order', 'fm-ef-sort', String(fest.sort_order || 0)) +
      '</div>' +
      fmInput('Description', 'fm-ef-desc', fest.description) +
      '<label style="display:flex;align-items:center;gap:8px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:12px">' +
        '<input type="checkbox" id="fm-ef-active" ' + (fest.is_active ? 'checked' : '') + '> Visible on Festival Planner</label>' +
      fmBtn('Save festival', 'fmSaveFest(\'' + fest.id + '\')', true) +
    '</div>' +
    '<div style="background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:16px">' +
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;color:var(--text-high);margin-bottom:10px">Dish structure &amp; recipes</div>' +
      '<div style="display:grid;grid-template-columns:2fr 1.2fr 80px 80px;gap:8px;margin-bottom:8px;font-size:10px;color:var(--text-mid);text-transform:uppercase">Dish · Section · Order · </div>' +
      '<div id="fm-dish-rows"></div>' +
      '<div style="margin-top:14px;padding-top:14px;border-top:1px solid var(--border)">' +
        '<div style="font-size:11px;font-weight:600;color:var(--text-high);margin-bottom:8px">Add dish slot</div>' +
        '<div style="display:grid;grid-template-columns:2fr 1.2fr 80px;gap:8px">' +
          fmInput('Dish name', 'fm-ad-name', '', 'Sambar') +
          fmInput('Section', 'fm-ad-sec', '', 'Main Curries') +
          fmInput('Order', 'fm-ad-ord', '99', '10') +
        '</div>' +
        fmBtn('Add dish', 'fmAddDish(\'' + fest.id + '\')', true) +
      '</div></div>';
  fmRenderDishes(fest.id, detail.dishes);
}

function fmRenderDishes(festivalId, dishes) {
  var host = document.getElementById('fm-dish-rows');
  if (!host) return;
  if (!dishes.length) { host.innerHTML = '<div style="font-size:12px;color:var(--text-mid);padding:8px 0">No dishes yet — add slots below.</div>'; return; }
  host.innerHTML = dishes.map(function(d) {
    var recipes = (d.recipes || []).map(function(r) {
      return '<div style="display:flex;align-items:center;gap:6px;margin-top:4px;flex-wrap:wrap">' +
        '<a href="recipe-page.html?id=' + r.recipe_id + '" target="_blank" style="font-size:11px;color:var(--accent)">' + esc(r.variant_label || r.recipe_name) + '</a>' +
        fmBtn('Unlink', 'fmUnlinkRecipe(\'' + r.id + '\',\'' + _fmEditSlug + '\')', false) +
      '</div>';
    }).join('');
    return '<div style="border:1px solid var(--border);border-radius:8px;padding:10px 12px;margin-bottom:8px">' +
      '<div style="display:grid;grid-template-columns:2fr 1.2fr 80px auto;gap:8px;align-items:center">' +
        '<input value="' + esc(d.dish_name) + '" id="fm-dn-' + d.id + '" style="padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);font-size:12px">' +
        '<input value="' + esc(d.section_label || '') + '" id="fm-ds-' + d.id + '" placeholder="Section" style="padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);font-size:12px">' +
        '<input value="' + (d.sort_order || 0) + '" id="fm-do-' + d.id + '" style="padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);font-size:12px">' +
        '<div style="display:flex;gap:4px">' + fmBtn('Save', 'fmSaveDish(\'' + d.id + '\')', false) + fmBtn('Del', 'fmDelDish(\'' + d.id + '\')', false) + '</div>' +
      '</div>' +
      (recipes || '<div style="font-size:11px;color:var(--text-mid);margin-top:6px">No recipes linked</div>') +
      '<div style="margin-top:8px;display:flex;gap:6px;flex-wrap:wrap;align-items:center">' +
        '<input id="fm-rq-' + d.id + '" placeholder="Search approved recipes…" style="flex:1;min-width:140px;padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);font-size:11px">' +
        '<input id="fm-rv-' + d.id + '" placeholder="Variant label" value="Classic" style="width:100px;padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);font-size:11px">' +
        fmBtn('Search', 'fmSearchRecipes(\'' + d.id + '\')', false) +
      '</div>' +
      '<div id="fm-rs-' + d.id + '"></div></div>';
  }).join('');
}

async function fmSaveFest(id) {
  try {
    await rpc('admin_upsert_festival', {
      p_id: id,
      p_slug: document.getElementById('fm-ef-slug').value.trim(),
      p_name: document.getElementById('fm-ef-name').value.trim(),
      p_emoji: document.getElementById('fm-ef-emoji').value.trim(),
      p_when_label: document.getElementById('fm-ef-when').value.trim() || null,
      p_description: document.getElementById('fm-ef-desc').value.trim() || null,
      p_planner_path: document.getElementById('fm-ef-planner').value.trim() || null,
      p_sort_order: parseInt(document.getElementById('fm-ef-sort').value, 10) || 0,
      p_is_active: document.getElementById('fm-ef-active').checked
    });
    auditLog('Festival Management', 'Updated festival', null, id, null, null);
    fmEditFest(document.getElementById('fm-ef-slug').value.trim());
  } catch (e) { alert('Error: ' + e.message); }
}

async function fmAddDish(festivalId) {
  try {
    await rpc('admin_upsert_festival_dish', {
      p_festival_id: festivalId,
      p_dish_name: document.getElementById('fm-ad-name').value.trim(),
      p_section_label: document.getElementById('fm-ad-sec').value.trim() || null,
      p_sort_order: parseInt(document.getElementById('fm-ad-ord').value, 10) || 0
    });
    fmEditFest(_fmEditSlug);
  } catch (e) { alert('Error: ' + e.message); }
}

async function fmSaveDish(id) {
  try {
    await rpc('admin_upsert_festival_dish', {
      p_id: id,
      p_dish_name: document.getElementById('fm-dn-' + id).value.trim(),
      p_section_label: document.getElementById('fm-ds-' + id).value.trim() || null,
      p_sort_order: parseInt(document.getElementById('fm-do-' + id).value, 10) || 0
    });
    fmEditFest(_fmEditSlug);
  } catch (e) { alert('Error: ' + e.message); }
}

async function fmDelDish(id) {
  if (!confirm('Delete this dish slot and all linked recipes?')) return;
  try {
    await rpc('admin_delete_festival_dish', { p_id: id });
    fmEditFest(_fmEditSlug);
  } catch (e) { alert('Error: ' + e.message); }
}

async function fmSearchRecipes(dishId) {
  var q = document.getElementById('fm-rq-' + dishId).value.trim();
  var box = document.getElementById('fm-rs-' + dishId);
  box.innerHTML = 'Searching…';
  try {
    var rows = await rpc('admin_search_recipes', { p_query: q, p_limit: 48, p_offset: 0 }) || [];
    if (!rows.length) { box.innerHTML = '<div style="font-size:11px;color:var(--text-mid);margin-top:6px">No approved recipes found.</div>'; return; }
    var html = rows.map(function(r) {
      return '<button type="button" onclick="fmLinkRecipe(\'' + dishId + '\',\'' + r.id + '\')" style="display:block;width:100%;text-align:left;margin-top:4px;padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:none;color:var(--text-high);font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer">' +
        esc(r.recipe_name) + ' <span style="color:var(--text-mid)">· ' + esc(r.category || '') + '</span></button>';
    }).join('');
    if (rows.length >= 48) {
      html += '<div style="font-size:10px;color:var(--text-mid);margin-top:6px">Showing first 48 — narrow your search for more.</div>';
    }
    box.innerHTML = html;
  } catch (e) { box.innerHTML = '<div style="color:#dc5050;font-size:11px">' + esc(e.message) + '</div>'; }
}

async function fmLinkRecipe(dishId, recipeId) {
  try {
    await rpc('admin_link_festival_recipe', {
      p_dish_id: dishId,
      p_recipe_id: recipeId,
      p_variant_label: document.getElementById('fm-rv-' + dishId).value.trim() || 'Classic',
      p_is_featured: false
    });
    fmEditFest(_fmEditSlug);
  } catch (e) { alert('Error: ' + e.message); }
}

async function fmUnlinkRecipe(linkId, slug) {
  try {
    await rpc('admin_unlink_festival_recipe', { p_id: linkId });
    fmEditFest(slug || _fmEditSlug);
  } catch (e) { alert('Error: ' + e.message); }
}

async function loadVocInbox(container, filters) {
  filters = filters || {};
  container.innerHTML = '<div class="ap-loading">Loading Voice of the Customer…</div>';
  try {
    var rows = await rpc('admin_get_feedback', {
      p_status: filters.status || null,
      p_voc_category: filters.voc_category || null,
      p_action_required: filters.action_required != null ? filters.action_required : null
    }) || [];
    container.innerHTML = '';

    var toolbar = document.createElement('div');
    toolbar.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;align-items:center';
    toolbar.innerHTML =
      '<span style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">Filter:</span>';
    [
      { label:'All', f:{} },
      { label:'New', f:{ status:'new' } },
      { label:'Action required', f:{ action_required:true } },
      { label:'Actionable', f:{ voc_category:'actionable' } },
      { label:'Signals', f:{ voc_category:'signals' } },
      { label:'Noise', f:{ voc_category:'noise' } }
    ].forEach(function(opt) {
      var b = document.createElement('button');
      b.textContent = opt.label;
      b.style.cssText = 'padding:5px 12px;border:1px solid var(--border);border-radius:6px;background:none;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer';
      b.addEventListener('click', function() { loadVocInbox(container, opt.f); });
      toolbar.appendChild(b);
    });
    container.appendChild(toolbar);

    var countLbl = document.createElement('div');
    countLbl.style.cssText = 'font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px';
    countLbl.textContent = rows.length + ' entr' + (rows.length === 1 ? 'y' : 'ies');
    container.appendChild(countLbl);

    if (!rows.length) {
      var empty = document.createElement('div');
      empty.style.cssText = 'font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)';
      empty.textContent = 'No entries match this filter.';
      container.appendChild(empty);
      return;
    }

    rows.forEach(function(r) {
      var cat = r.voc_category || VOC_TYPE_MAP[r.type] || 'noise';
      var catMeta = VOC_CATEGORIES.find(function(c) { return c.id === cat; }) || VOC_CATEGORIES[2];
      var sc = { new:'#d4a017', reviewed:'#5B8FD4', actioned:'#4caf76', dismissed:'#dc5050' }[r.status] || 'var(--text-mid)';
      var dt = r.created_at ? new Date(r.created_at).toLocaleDateString('en-GB', { day:'numeric', month:'short', year:'numeric' }) : '—';
      var card = document.createElement('div');
      card.style.cssText = 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:14px 18px;margin-bottom:10px';

      var header = document.createElement('div');
      header.style.cssText = 'display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:8px';
      header.innerHTML =
        '<span style="font-size:10px;font-weight:700;padding:2px 8px;border-radius:10px;background:rgba(0,0,0,0.2);color:' + catMeta.color + '">' + esc(catMeta.label) + '</span>' +
        '<span style="font-size:10px;padding:2px 8px;border-radius:10px;border:1px solid var(--border);color:var(--text-mid)">' + esc(r.type) + '</span>' +
        (r.action_required ? '<span style="font-size:10px;color:#dc5050">⚑ Action required</span>' : '') +
        '<span style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">' + esc(r.name || r.profile_name || 'Anonymous') +
        (r.email ? ' · ' + esc(r.email) : '') + ' — ' + dt + '</span>' +
        '<span style="margin-left:auto;font-size:11px;font-weight:600;color:' + sc + '">' + esc(r.status) + '</span>';
      card.appendChild(header);

      var body = document.createElement('div');
      body.style.cssText = 'font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high);margin-bottom:10px;white-space:pre-wrap';
      body.textContent = r.feedback || '';
      card.appendChild(body);

      if (r.admin_notes) {
        var notes = document.createElement('div');
        notes.style.cssText = 'font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:10px;font-style:italic';
        notes.textContent = 'Admin notes: ' + r.admin_notes;
        card.appendChild(notes);
      }

      var row = document.createElement('div');
      row.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;align-items:center';
      var catSel = document.createElement('select');
      catSel.style.cssText = 'padding:4px 8px;border-radius:6px;border:1px solid var(--border);background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:11px';
      VOC_CATEGORIES.forEach(function(c) {
        var o = document.createElement('option');
        o.value = c.id; o.textContent = c.label;
        if (c.id === cat) o.selected = true;
        catSel.appendChild(o);
      });
      row.appendChild(catSel);

      [{ s:'actioned', l:'Mark Actioned', c:'#4caf76' }, { s:'reviewed', l:'Reviewed', c:'#5B8FD4' }, { s:'dismissed', l:'Dismiss', c:'#dc5050' }].forEach(function(b) {
        if (r.status === b.s) return;
        var btn = document.createElement('button');
        btn.textContent = b.l;
        btn.style.cssText = 'padding:4px 10px;background:none;border:1px solid ' + b.c + ';border-radius:6px;color:' + b.c + ';font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer';
        btn.addEventListener('click', async function() {
          btn.disabled = true;
          try {
            await rpc('admin_update_feedback', {
              p_id: r.id,
              p_status: b.s,
              p_voc_category: catSel.value,
              p_action_required: b.s === 'new'
            });
            auditLog('Voice of Customer', 'Feedback ' + b.s, null, String(r.id), b.s, null);
            loadVocInbox(container, filters);
          } catch (e) { btn.disabled = false; alert('Error: ' + e.message); }
        });
        row.appendChild(btn);
      });
      card.appendChild(row);
      container.appendChild(card);
    });
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

function loadVocTaxonomy(container) {
  container.innerHTML =
    '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.8;max-width:640px">' +
    '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;color:var(--text-high);margin-bottom:12px">VoC taxonomy</div>' +
    '<p><strong style="color:#dc5050">Actionable</strong> — system bugs, process friction, content issues. Default action_required.</p>' +
    '<p><strong style="color:#4caf76">Signals</strong> — kudos, value stories, feature wishes, recipe praise.</p>' +
    '<p><strong style="color:#5B8FD4">Noise</strong> — vague vents, user errors, repeats. Review and dismiss.</p>' +
    '<p style="margin-top:16px;font-size:12px">Widget types map automatically. Re-categorise in the inbox; admin_notes persist per entry.</p></div>';
}
