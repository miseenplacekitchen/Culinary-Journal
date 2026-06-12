/* Admin data integrity panel — surfaces issues and one-click fixes */
(function (global) {
  function mk(tag, style, text) {
    var el = document.createElement(tag);
    if (style) el.style.cssText = style;
    if (text !== undefined) el.textContent = text;
    return el;
  }

  async function loadDataIntegrityPanel(container) {
    if (!container) return;
    container.innerHTML = '';

    var hdr = mk('div', 'margin-bottom:16px');
    hdr.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1.15rem;font-weight:700;color:var(--text-high)", 'System Health'));
    hdr.appendChild(mk('p', "font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid);margin:8px 0 0;line-height:1.6",
      'Checks that recipes, library profiles, and the governed ingredient database stay aligned. ' +
      'Not email, backups, or site uptime — use Lane 2 spot-check for those. ' +
      'Run Normalise Recipes only for large libraries with spelling drift.'));
    container.appendChild(hdr);

    var reportEl = mk('div', 'margin-bottom:20px');
    var actionsEl = mk('div', 'display:flex;flex-wrap:wrap;gap:10px;margin-bottom:20px');
    var logEl = mk('div', "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);line-height:1.6;white-space:pre-wrap");
    container.appendChild(reportEl);
    container.appendChild(actionsEl);
    container.appendChild(logEl);

    var scanBtn = mk('button', "padding:9px 18px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;cursor:pointer", 'Run Health Check');
    var normBtn = mk('button', "padding:9px 18px;background:#2e7d4f;border:none;border-radius:8px;color:#fff;font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;cursor:pointer", 'Normalise Recipes (batch)');
    var normAllBtn = mk('button', "padding:9px 18px;background:none;border:1px solid #2e7d4f;border-radius:8px;color:#2e7d4f;font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;cursor:pointer", 'Normalise ALL Recipes');
    actionsEl.appendChild(scanBtn);
    actionsEl.appendChild(normBtn);
    actionsEl.appendChild(normAllBtn);

    function renderReport(data) {
      if (!data) {
        reportEl.innerHTML = '<div style="color:var(--text-mid);font-size:13px">No report yet.</div>';
        return;
      }
      var issues = data.issues || {};
      var totals = data.totals || {};
      var healthy = !!data.healthy;
      var needsPhase43 = issues.starter_library_wrong_links === undefined
        && totals.approved_recipes === undefined;
      var color = healthy ? '#4caf76' : '#d4a017';
      reportEl.innerHTML =
        '<div style="padding:16px 18px;border-radius:10px;border:1px solid ' + (healthy ? 'rgba(76,175,118,0.35)' : 'rgba(212,160,23,0.35)') + ';background:rgba(0,0,0,0.15)">' +
        '<div style="font-family:DM Sans,sans-serif;font-size:15px;font-weight:600;color:' + color + ';margin-bottom:10px">' +
        (healthy ? '✓ No critical integrity issues detected' : '⚠ Issues found — review below') + '</div>' +
        '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)">' +
        '<div><strong>' + (totals.recipes || 0) + '</strong> total recipes</div>' +
        '<div><strong>' + (totals.approved_recipes || 0) + '</strong> approved recipes</div>' +
        '<div><strong>' + (totals.ingredients || 0) + '</strong> ingredients</div>' +
        '<div>Invalid library links: <strong>' + (issues.invalid_governed_links || 0) + '</strong></div>' +
        '<div>Library name mismatches: <strong>' + (issues.library_name_mismatches || 0) + '</strong></div>' +
        '<div>Starter wrong links: <strong>' + (issues.starter_library_wrong_links || 0) + '</strong></div>' +
        '<div>Duplicate ingredient names: <strong>' + (issues.duplicate_ingredient_names || 0) + '</strong></div>' +
        '<div>Orphan recipe ingredient names: <strong>' + (issues.orphan_recipe_ingredient_names || 0) + '</strong></div>' +
        '</div>' +
        (needsPhase43
          ? '<div style="margin-top:10px;font-size:12px;color:#d4a017">Run <code>fix-phase43-starter-library-health.sql</code> or <code>RUN-LIVE-CLEANUP.sql</code> in Supabase to refresh health RPCs.</div>'
          : '') +
        ((issues.orphan_recipe_ingredient_names || 0) > 0
          ? '<div style="margin-top:10px;font-size:12px;color:#d4a017">Orphan names: run <code>fix-phase48-recipe-ingredient-orphans.sql</code> in Supabase SQL Editor.</div>'
          : '') +
        '</div>';
    }

    scanBtn.addEventListener('click', async function () {
      scanBtn.disabled = true;
      scanBtn.textContent = 'Checking…';
      try {
        var data = await rpc('admin_data_integrity_report', {});
        renderReport(data);
        if (global.TcjIngredientLookup) TcjIngredientLookup.clearCache();
      } catch (e) {
        reportEl.innerHTML = '<div style="color:#dc5050;font-size:13px">Error: ' + esc(e.message) + '</div>';
      }
      scanBtn.disabled = false;
      scanBtn.textContent = 'Run Health Check';
    });

    async function runNormalizeBatch(offset, autoContinue) {
      var res = await rpc('admin_bulk_normalize_recipe_ingredients', { p_limit: 200, p_offset: offset });
      var line = 'Batch @' + offset + ': ' + (res.recipes_updated || 0) + ' recipes, ' +
        (res.ingredient_lines_fixed || 0) + ' lines fixed.\n';
      logEl.textContent += line;
      if (autoContinue && (res.recipes_updated > 0 || res.ingredient_lines_fixed > 0)) {
        return runNormalizeBatch(offset + 200, true);
      }
      return res;
    }

    normBtn.addEventListener('click', async function () {
      normBtn.disabled = true;
      logEl.textContent = '';
      try {
        var offset = parseInt(logEl.dataset.offset || '0', 10) || 0;
        await runNormalizeBatch(offset, false);
        logEl.dataset.offset = String(offset + 200);
        logEl.textContent += '\nNext batch starts at offset ' + (offset + 200) + '. Click again to continue.';
        if (global.TcjIngredientLookup) TcjIngredientLookup.clearCache();
      } catch (e) {
        logEl.textContent += 'Error: ' + e.message;
      }
      normBtn.disabled = false;
    });

    normAllBtn.addEventListener('click', async function () {
      if (!confirm('Normalise ALL recipes in 200-recipe batches? This may take several minutes for large libraries.')) return;
      normAllBtn.disabled = true;
      normBtn.disabled = true;
      logEl.textContent = 'Starting full normalisation…\n';
      logEl.dataset.offset = '0';
      try {
        var offset = 0;
        var rounds = 0;
        while (rounds < 200) {
          var res = await rpc('admin_bulk_normalize_recipe_ingredients', { p_limit: 200, p_offset: offset });
          logEl.textContent += 'Batch @' + offset + ': ' + (res.recipes_updated || 0) + ' recipes, ' +
            (res.ingredient_lines_fixed || 0) + ' lines fixed.\n';
          if ((res.recipes_updated || 0) === 0 && (res.ingredient_lines_fixed || 0) === 0) break;
          offset += 200;
          rounds++;
        }
        logEl.textContent += '\nDone. Run health check to verify.';
        if (global.TcjIngredientLookup) TcjIngredientLookup.clearCache();
        var data = await rpc('admin_data_integrity_report', {});
        renderReport(data);
      } catch (e) {
        logEl.textContent += 'Error: ' + e.message;
      }
      normAllBtn.disabled = false;
      normBtn.disabled = false;
    });

    scanBtn.click();
  }

  global.loadDataIntegrityPanel = loadDataIntegrityPanel;
})(typeof window !== 'undefined' ? window : globalThis);
