// dashboard-garden.js — Garden Management work tabs (species list + preview)
// GM Interface lives in dashboard-gm-interface.js

function escGm(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function switchGardenTab(tab) {
  localStorage.setItem('tcj_active_garden_tab', tab);
  ['gtab-all', 'gtab-draft', 'gtab-preview', 'gtab-gminterface'].forEach(function (id) {
    var btn = document.getElementById(id);
    if (btn) btn.classList.toggle('active', id === 'gtab-' + tab);
  });
  var panels = { all: 'gpanel-all', draft: 'gpanel-draft', preview: 'gpanel-preview', gminterface: 'gpanel-gminterface' };
  Object.keys(panels).forEach(function (k) {
    var el = document.getElementById(panels[k]);
    if (el) el.style.display = (k === tab) ? 'block' : 'none';
  });
  if (tab === 'all') loadGardenSpeciesTable(false);
  if (tab === 'draft') loadGardenSpeciesTable(true);
  if (tab === 'gminterface' && typeof loadGmInterface === 'function') loadGmInterface();
  if (tab === 'preview') loadGardenPreviewFrame();
}

function loadGardenPreviewFrame() {
  var wrap = document.getElementById('gpanel-preview');
  if (!wrap) return;
  if (wrap.dataset.built !== '1') {
    wrap.innerHTML = '<p style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);margin-bottom:12px">Member-facing preview (names only — no internal ids).</p>' +
      '<iframe id="frame-garden-preview" title="Garden preview" style="width:100%;min-height:calc(100vh - 220px);border:1px solid var(--border);border-radius:12px;background:transparent"></iframe>';
    if (typeof loadAdminEmbedFrame === 'function') {
      loadAdminEmbedFrame('frame-garden-preview', 'garden-directory.html?embed=1');
    }
    wrap.dataset.built = '1';
  }
}

function gmFilterSpeciesTable(draftsOnly) {
  var q = (document.getElementById(draftsOnly ? 'gm-draft-search' : 'gm-species-search') || {}).value || '';
  q = q.trim().toLowerCase();
  var tbody = document.getElementById(draftsOnly ? 'gm-draft-tbody' : 'gm-species-tbody');
  if (!tbody) return;
  tbody.querySelectorAll('tr[data-slug]').forEach(function (tr) {
    var text = (tr.dataset.slug + ' ' + (tr.dataset.name || '')).toLowerCase();
    tr.style.display = !q || text.indexOf(q) !== -1 ? '' : 'none';
  });
}

async function loadGardenSpeciesTable(draftsOnly) {
  var tbody = document.getElementById(draftsOnly ? 'gm-draft-tbody' : 'gm-species-tbody');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Loading…</td></tr>';
  try {
    var q = '/rest/v1/plants?select=id,slug,common_name,botanical_name,is_published,updated_at&order=common_name';
    if (draftsOnly) q += '&is_published=eq.false';
    var res = await supaFetch(q);
    if (!res.ok) throw new Error(String(res.status));
    var rows = await res.json();
    if (!Array.isArray(rows) || !rows.length) {
      tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">' +
        (draftsOnly ? 'No draft species.' : 'No species yet — run Garden v3 SQL or import via GM Interface.') + '</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(function (p) {
      var updated = p.updated_at ? new Date(p.updated_at).toLocaleDateString() : '—';
      var slugAttr = escGm(p.slug);
      return '<tr data-slug="' + slugAttr + '" data-name="' + escGm(p.common_name) + '">' +
        '<td style="font-family:monospace;font-size:11px;color:var(--text-muted)">' + escGm(String(p.id).slice(0, 8)) + '…</td>' +
        '<td style="font-family:monospace;font-size:11px">' + escGm(p.slug) + '</td>' +
        '<td><strong>' + escGm(p.common_name) + '</strong></td>' +
        '<td style="font-style:italic;color:var(--text-mid)">' + escGm(p.botanical_name) + '</td>' +
        '<td>' + (p.is_published ? '<span style="color:#6dc86d">Published</span>' : '<span style="color:var(--warn,#c97)">Draft</span>') + '</td>' +
        '<td>' + escGm(updated) + '</td>' +
        '<td style="white-space:nowrap">' +
        '<button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px;margin-right:4px" onclick="gmFocusSpecies(' + JSON.stringify(p.slug) + ')">GM Detail</button>' +
        '<button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px" onclick="gmTogglePublish(' + JSON.stringify(p.slug) + ',' + (p.is_published ? 'true' : 'false') + ',this)">' + (p.is_published ? 'Unpublish' : 'Publish') + '</button>' +
        '</td>' +
        '<td><a href="garden-plant.html?slug=' + encodeURIComponent(p.slug || '') + '" target="_blank" rel="noopener" style="color:var(--accent);font-size:12px">Preview ↗</a></td>' +
        '</tr>';
    }).join('');
    var stat = document.getElementById(draftsOnly ? 'gm-draft-count' : 'gm-species-count');
    if (stat) stat.textContent = rows.length + ' species';
    gmFilterSpeciesTable(draftsOnly);
  } catch (e) {
    console.warn('loadGardenSpeciesTable', e);
    tbody.innerHTML = '<tr><td colspan="8" class="ap-empty-row">Could not load plants — run Garden v3 SQL on Supabase (admin session required).</td></tr>';
  }
}

async function loadGardenMgmtStats() {
  try {
    var pub = await supaFetch('/rest/v1/plants?select=id&is_published=eq.true');
    var all = await supaFetch('/rest/v1/plants?select=id,is_published');
    var cz = await supaFetch('/rest/v1/climate_zones?select=id');
    var vr = await supaFetch('/rest/v1/plant_varieties?select=id&is_published=eq.true');
    var set = function (id, n) { var el = document.getElementById(id); if (el) el.textContent = n; };
    if (pub.ok) set('gm-stat-published', (await pub.json()).length);
    if (all.ok) {
      var a = await all.json();
      set('gm-stat-total', a.length);
      set('gm-stat-draft', a.filter(function (p) { return !p.is_published; }).length);
    }
    if (cz.ok) set('gm-stat-climates', (await cz.json()).length);
    if (vr.ok) set('gm-stat-varieties', (await vr.json()).length);
  } catch (e) { console.warn('loadGardenMgmtStats', e); }
}

function initGardenMgmt() {
  loadGardenMgmtStats();
  var tab = localStorage.getItem('tcj_active_garden_tab') || 'gminterface';
  switchGardenTab(tab);
}
