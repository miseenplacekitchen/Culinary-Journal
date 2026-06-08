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

async function loadFestOverview(container) {
  container.innerHTML = '<div class="ap-loading">Loading festivals…</div>';
  try {
    var rows = await rpc('admin_get_festivals') || [];
    container.innerHTML = '';
    var hdr = document.createElement('div');
    hdr.style.cssText = 'font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px';
    hdr.textContent = rows.length + ' festival' + (rows.length === 1 ? '' : 's');
    container.appendChild(hdr);
    if (!rows.length) {
      container.innerHTML += '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">No festivals yet. Run fix-phase36-platform-batch.sql to seed Onam and others.</div>';
      return;
    }
    rows.forEach(function(f) {
      var card = document.createElement('div');
      card.style.cssText = 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:14px 18px;margin-bottom:10px;display:flex;align-items:center;gap:14px;flex-wrap:wrap';
      card.innerHTML =
        '<span style="font-size:24px">' + (f.emoji || '🎉') + '</span>' +
        '<div style="flex:1;min-width:180px"><div style="font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high)">' + esc(f.name) + '</div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">' + esc(f.when_label || '') + ' · ' + (f.dish_count || 0) + ' dishes</div></div>' +
        '<span style="font-size:11px;color:' + (f.is_active ? '#4caf76' : '#dc5050') + '">' + (f.is_active ? 'Active' : 'Inactive') + '</span>' +
        (f.planner_path ? '<a href="' + esc(f.planner_path) + '" target="_blank" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent)">Planner →</a>' : '') +
        '<a href="festival-planner.html" target="_blank" style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent)">Public view →</a>';
      container.appendChild(card);
    });
  } catch (e) {
    container.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: ' + esc(e.message) + '</div>';
  }
}

async function loadFestInterface(container) {
  container.innerHTML =
    '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.7;margin-bottom:16px">' +
    '<strong style="color:var(--text-high)">Festival Management (FM Interface)</strong> — ongoing CRUD for festivals, dish slots, and recipe variants. ' +
    'Onam sadya dishes are seeded from the legacy planner. Link multiple recipe variants per dish (Classic, Kerala-style, etc.) via Supabase for now; full inline editor ships next.</div>' +
    '<div id="fest-detail-host"><div class="ap-loading">Loading…</div></div>';
  try {
    var rows = await rpc('admin_get_festivals') || [];
    var host = document.getElementById('fest-detail-host');
    host.innerHTML = '';
    rows.forEach(function(f) {
      var block = document.createElement('details');
      block.style.cssText = 'background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:10px;padding:12px 16px;margin-bottom:10px';
      block.innerHTML =
        '<summary style="cursor:pointer;font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;color:var(--text-high)">' +
        (f.emoji || '🎉') + ' ' + esc(f.name) + ' <span style="color:var(--text-mid);font-weight:400">(' + (f.dish_count || 0) + ' dishes · slug: ' + esc(f.slug) + ')</span></summary>' +
        '<div class="fest-dish-list" data-slug="' + esc(f.slug) + '" style="margin-top:12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid)">Loading dishes…</div>';
      host.appendChild(block);
      rpc('get_festival_detail', { p_slug: f.slug }).then(function(detail) {
        var list = block.querySelector('.fest-dish-list');
        var dishes = (detail && detail.dishes) || [];
        if (!dishes.length) { list.textContent = 'No dish slots.'; return; }
        list.innerHTML = '<ol style="margin:0;padding-left:20px;line-height:1.8">' + dishes.map(function(d) {
          var vars = (d.recipes || []).length;
          return '<li>' + esc(d.dish_name) + (vars ? ' — ' + vars + ' variant(s)' : ' — <em>no recipes linked</em>') + '</li>';
        }).join('') + '</ol>';
      }).catch(function() {
        block.querySelector('.fest-dish-list').textContent = 'Could not load dish detail.';
      });
    });
  } catch (e) {
    document.getElementById('fest-detail-host').innerHTML = '<div style="color:#dc5050">Error: ' + esc(e.message) + '</div>';
  }
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
