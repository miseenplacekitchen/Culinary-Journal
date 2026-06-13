// dashboard-print-orders.js — Print & Post admin fulfilment inbox

var _poFilterStatus = localStorage.getItem('tcj_po_admin_filter') || 'pending';

function poEsc(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function poStatusLabel(st) {
  return { pending: 'Pending', processing: 'Processing', shipped: 'Shipped', cancelled: 'Cancelled' }[st] || st;
}

function poStatusColor(st) {
  if (st === 'pending') return 'var(--warn,#c97)';
  if (st === 'processing') return '#5B8FD4';
  if (st === 'shipped') return '#4caf76';
  return 'var(--text-mid)';
}

function poFormatDelivery(d) {
  if (!d || typeof d !== 'object') return '—';
  var parts = [d.first, d.last, d.addr1, d.addr2, d.city, d.postcode, d.country].filter(Boolean);
  return parts.join(', ') || '—';
}

function poSetFilter(st) {
  _poFilterStatus = st || '';
  localStorage.setItem('tcj_po_admin_filter', _poFilterStatus);
  var panel = document.getElementById('upanel-fi-print-orders');
  if (panel) {
    panel.dataset.built = '';
    buildFIPrintOrders(panel);
  }
}

async function poUpdateStatus(orderId, selectEl) {
  if (!orderId || !selectEl) return;
  var st = selectEl.value;
  var notesEl = document.getElementById('po-notes-' + orderId);
  var notes = notesEl ? notesEl.value : null;
  selectEl.disabled = true;
  try {
    await rpc('admin_update_print_order_status', {
      p_order_id: orderId,
      p_status: st,
      p_admin_notes: notes || null
    });
    var panel = document.getElementById('upanel-fi-print-orders');
    if (panel) {
      panel.dataset.built = '';
      buildFIPrintOrders(panel);
    }
  } catch (e) {
    alert('Update failed: ' + e.message + '\n\nRun fix-phase53-print-fulfillment.sql on Supabase if the RPC is missing.');
    selectEl.disabled = false;
  }
}

function poExportCsv(rows) {
  if (typeof GardenExport !== 'undefined' && GardenExport.downloadBlob) {
    var head = ['order_id', 'created', 'status', 'member', 'email', 'recipe', 'qty', 'quality', 'size', 'layout', 'address'];
    var lines = [head.join(',')];
    (rows || []).forEach(function (r) {
      var d = r.delivery || {};
      lines.push([
        r.id,
        r.created_at || '',
        r.status || '',
        r.member_name || '',
        r.member_email || '',
        r.recipe_name || '',
        r.card_count || '',
        r.card_quality || '',
        r.card_size || '',
        r.layout_style || '',
        poFormatDelivery(d)
      ].map(function (v) {
        var s = String(v == null ? '' : v);
        return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
      }).join(','));
    });
    GardenExport.downloadBlob(
      'tcj-print-orders-' + new Date().toISOString().slice(0, 10) + '.csv',
      'text/csv;charset=utf-8',
      lines.join('\n')
    );
    return;
  }
  alert('Export helper not loaded.');
}

function poCopyJson(row) {
  try {
    navigator.clipboard.writeText(JSON.stringify(row, null, 2));
    alert('Order JSON copied to clipboard — paste into your print-house workflow.');
  } catch (e) {
    prompt('Copy order JSON:', JSON.stringify(row, null, 2));
  }
}

async function buildFIPrintOrders(container) {
  container.innerHTML = '<div class="ap-loading" style="padding:24px 0">Loading print orders…</div>';
  try {
    var rows = await rpc('admin_get_print_orders', {
      p_status: _poFilterStatus || null,
      p_limit: 150
    });
    if (!Array.isArray(rows)) rows = [];
    container.innerHTML = '';
    function mk(tag, s, t) {
      var e = document.createElement(tag);
      if (s) e.style.cssText = s;
      if (t !== undefined) e.textContent = t;
      return e;
    }

    container.appendChild(mk('div',
      'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.6',
      'Print & Post fulfilment inbox. Update status as you work orders. Shipped triggers a member email (when email cron runs). Payment is not wired yet — use this for manual dispatch.'));

    var filters = mk('div', 'display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px');
    ['pending', 'processing', 'shipped', 'cancelled', ''].forEach(function (st) {
      var label = st ? poStatusLabel(st) : 'All';
      var btn = mk('button',
        'padding:6px 14px;border-radius:20px;border:1px solid var(--border);background:' +
        ((_poFilterStatus || '') === st ? 'var(--accent)' : 'none') + ';color:' +
        ((_poFilterStatus || '') === st ? '#fff' : 'var(--text-mid)') +
        ';font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer',
        label);
      btn.type = 'button';
      btn.addEventListener('click', function () { poSetFilter(st); });
      filters.appendChild(btn);
    });
    var exportBtn = mk('button',
      'padding:6px 14px;border-radius:8px;border:1px solid var(--accent);background:none;color:var(--accent);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer;margin-left:auto',
      '⬇ Export CSV');
    exportBtn.type = 'button';
    exportBtn.addEventListener('click', function () { poExportCsv(rows); });
    filters.appendChild(exportBtn);
    container.appendChild(filters);

    if (!rows.length) {
      container.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:20px 0',
        _poFilterStatus ? 'No ' + poStatusLabel(_poFilterStatus).toLowerCase() + ' orders.' : 'No print orders yet.'));
      container.dataset.built = '1';
      return;
    }

    var wrap = mk('div', 'overflow-x:auto;border:1px solid var(--border);border-radius:12px');
    var tbl = mk('table', 'width:100%;border-collapse:collapse;font-family:DM Sans,sans-serif;font-size:12px;min-width:920px');
    tbl.innerHTML = '<thead><tr style="text-align:left;border-bottom:1px solid var(--border)">' +
      '<th class="ap-th">Date</th><th class="ap-th">Member</th><th class="ap-th">Recipe</th>' +
      '<th class="ap-th">Cards</th><th class="ap-th">Quality</th><th class="ap-th">Status</th>' +
      '<th class="ap-th">Notes</th><th class="ap-th">Actions</th></tr></thead>';
    var tbody = mk('tbody');

    rows.forEach(function (r) {
      var tr = mk('tr', 'border-bottom:1px solid rgba(255,255,255,0.06);vertical-align:top');
      var dt = r.created_at ? new Date(r.created_at).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—';
      tr.appendChild(mk('td', 'padding:10px 12px;color:var(--text-mid);white-space:nowrap', dt));

      var mem = mk('td', 'padding:10px 12px');
      mem.innerHTML = '<div style="color:var(--text-high);font-weight:500">' + poEsc(r.member_name) + '</div>' +
        '<div style="font-size:11px;color:var(--text-mid)">' + poEsc(r.member_email || '—') + '</div>' +
        '<div style="font-size:10px;color:var(--text-mid);margin-top:4px">' + poEsc(poFormatDelivery(r.delivery)) + '</div>';
      tr.appendChild(mem);

      tr.appendChild(mk('td', 'padding:10px 12px;color:var(--text-high)', poEsc(r.recipe_name || '—')));
      tr.appendChild(mk('td', 'padding:10px 12px', String(r.card_count || '—')));
      tr.appendChild(mk('td', 'padding:10px 12px;text-transform:capitalize', poEsc(r.card_quality || '—')));

      var stTd = mk('td', 'padding:10px 12px');
      var sel = mk('select', 'font-family:DM Sans,sans-serif;font-size:12px;padding:4px 8px;border-radius:6px;border:1px solid var(--border);background:var(--input-bg);color:' + poStatusColor(r.status));
      ['pending', 'processing', 'shipped', 'cancelled'].forEach(function (s) {
        var opt = mk('option', '', poStatusLabel(s));
        opt.value = s;
        if (r.status === s) opt.selected = true;
        sel.appendChild(opt);
      });
      sel.addEventListener('change', function () { poUpdateStatus(r.id, sel); });
      stTd.appendChild(sel);
      tr.appendChild(stTd);

      var notesTd = mk('td', 'padding:10px 12px');
      var notes = mk('input', 'width:100%;min-width:120px;box-sizing:border-box;font-size:11px;padding:6px 8px;border-radius:6px;border:1px solid var(--border);background:var(--input-bg);color:var(--text-high)');
      notes.id = 'po-notes-' + r.id;
      notes.placeholder = 'Admin notes…';
      notes.value = r.admin_notes || '';
      notesTd.appendChild(notes);
      tr.appendChild(notesTd);

      var actTd = mk('td', 'padding:10px 12px;white-space:nowrap');
      var copyBtn = mk('button', 'font-size:11px;padding:4px 10px;border:1px solid var(--border);border-radius:6px;background:none;color:var(--accent);cursor:pointer;margin-right:4px', 'Copy JSON');
      copyBtn.type = 'button';
      copyBtn.addEventListener('click', function () { poCopyJson(r); });
      actTd.appendChild(copyBtn);
      if (r.recipe_id) {
        var ps = mk('a', 'font-size:11px;color:var(--text-mid);text-decoration:none', 'Studio ↗');
        ps.href = 'print-studio.html?id=' + encodeURIComponent(r.recipe_id);
        ps.target = '_blank';
        actTd.appendChild(ps);
      }
      tr.appendChild(actTd);
      tbody.appendChild(tr);
    });

    tbl.appendChild(tbody);
    wrap.appendChild(tbl);
    container.appendChild(wrap);
    container.dataset.built = '1';
  } catch (e) {
    container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.35);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050">' +
      '<strong>Print orders error:</strong> ' + poEsc(e.message) + '<br><span style="font-size:12px;color:var(--text-mid)">Run <code>fix-phase53-print-fulfillment.sql</code> on Supabase.</span></div>';
    container.dataset.built = '';
  }
}

window.buildFIPrintOrders = buildFIPrintOrders;
window.poSetFilter = poSetFilter;
