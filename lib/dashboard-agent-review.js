/**
 * Admin dashboard — Agent Review (autopilot: approve/reject/edit-only-exceptions).
 */
(function (global) {
  'use strict';

  function getSessionToken() {
    try {
      var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
      return sess && sess.access_token ? sess.access_token : null;
    } catch (_) {
      return null;
    }
  }

  function agentApiUrl() {
    return '/api/admin-agent-review';
  }

  async function callAgentReview(body) {
    var token = getSessionToken();
    if (!token) throw new Error('Sign in again — session expired');
    var res = await fetch(agentApiUrl(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + token,
      },
      body: JSON.stringify(body),
    });
    var data = {};
    try {
      data = await res.json();
    } catch (_) {
      data = { ok: false, error: 'Invalid response' };
    }
    if (!res.ok || data.ok === false) {
      throw new Error(data.error || 'Agent review failed (' + res.status + ')');
    }
    return data;
  }

  function closeFullEditorPopup() {
    var el = document.getElementById('rm-agent-editor-overlay');
    if (el) el.remove();
    document.body.style.overflow = document.body.dataset.rmPrevOverflow || '';
    delete document.body.dataset.rmPrevOverflow;
  }

  function openAdminFullEditorPopup(recipeId, opts) {
    opts = opts || {};
    closeFullEditorPopup();
    var overlay = document.createElement('div');
    overlay.id = 'rm-agent-editor-overlay';
    overlay.className = 'rm-review-overlay';
    overlay.style.zIndex = '10001';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Edit all recipe fields');
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) closeFullEditorPopup();
    });

    var panel = document.createElement('div');
    panel.className = 'rm-agent-editor-modal';
    panel.addEventListener('click', function (e) { e.stopPropagation(); });

    var head = document.createElement('div');
    head.className = 'rm-agent-editor-head';
    head.innerHTML =
      '<div><strong style="font-family:Cormorant Garamond,serif;font-size:1.2rem;color:var(--text-high)">' +
      (opts.title || 'Edit all fields') +
      '</strong><div style="font-size:11px;color:var(--text-mid);margin-top:4px">' +
      (opts.subtitle || 'Fix what the agent flagged, save, then approve below.') +
      '</div></div>';

    var closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'ap-modal-close';
    closeBtn.textContent = '✕';
    closeBtn.addEventListener('click', closeFullEditorPopup);
    head.appendChild(closeBtn);
    panel.appendChild(head);

    if (opts.agentNotes) {
      var note = document.createElement('div');
      note.className = 'rm-agent-notes-banner';
      note.textContent = opts.agentNotes;
      panel.appendChild(note);
    }

    var frame = document.createElement('iframe');
    frame.className = 'rm-agent-editor-frame';
    frame.title = 'Recipe editor';
    frame.src = 'submit-recipe.html?adminReview=' + encodeURIComponent(recipeId) + '&embedded=1';
    panel.appendChild(frame);

    overlay.appendChild(panel);
    document.body.dataset.rmPrevOverflow = document.body.style.overflow || '';
    document.body.style.overflow = 'hidden';
    document.body.appendChild(overlay);
  }

  function showProgressOverlay(title, message) {
    closeProgressOverlay();
    var overlay = document.createElement('div');
    overlay.id = 'rm-agent-progress-overlay';
    overlay.className = 'rm-review-overlay';
    var box = document.createElement('div');
    box.className = 'rm-agent-progress-box';
    box.innerHTML =
      '<div style="font-family:Cormorant Garamond,serif;font-size:1.3rem;color:var(--text-high);margin-bottom:8px">' +
      title +
      '</div><div id="rm-agent-progress-msg" style="font-size:13px;color:var(--text-mid);line-height:1.6">' +
      message +
      '</div><div class="rm-agent-spinner" aria-hidden="true"></div>';
    overlay.appendChild(box);
    document.body.appendChild(overlay);
  }

  function closeProgressOverlay() {
    var el = document.getElementById('rm-agent-progress-overlay');
    if (el) el.remove();
  }

  function refreshRecipeList() {
    if (typeof loadRecipeMgmt === 'function') {
      loadRecipeMgmt(typeof _currentRecipeTab !== 'undefined' ? _currentRecipeTab : 'pending');
    }
  }

  function outcomeLabel(r) {
    if (!r.ok) return 'failed';
    if (r.outcome === 'auto_approve') return 'approved';
    if (r.outcome === 'reject') return 'rejected';
    return 'needs you';
  }

  /** Auto-approve greens, auto-reject reds — Betty only sees yellows. */
  async function applyAutopilotActions(results) {
    var greens = (results || []).filter(function (r) { return r.ok && r.outcome === 'auto_approve'; });
    var reds = (results || []).filter(function (r) { return r.ok && r.outcome === 'reject'; });
    var yellows = (results || []).filter(function (r) { return r.ok && r.outcome === 'review'; });
    var approved = 0;
    var rejected = 0;

    if (greens.length && typeof rpc === 'function') {
      try {
        approved = await rpc('admin_bulk_approve_recipes', { p_ids: greens.map(function (r) { return r.id; }) });
      } catch (e) {
        console.warn('autopilot approve', e);
      }
    }

    if (typeof rpc === 'function') {
      for (var i = 0; i < reds.length; i++) {
        var red = reds[i];
        try {
          await rpc('admin_review_recipe', {
            p_id: red.id,
            p_status: 'rejected',
            p_notes: red.reject_reason ||
              (red.assessment_reasons && red.assessment_reasons[0]) ||
              'Agent: not a valid recipe',
          });
          rejected += 1;
        } catch (e) {
          console.warn('autopilot reject', red.id, e);
        }
      }
    }

    return { approved: approved || greens.length, rejected: rejected, yellows: yellows, greens: greens, reds: reds };
  }

  function formatAutopilotSummary(ap) {
    var lines = [];
    if (ap.greens.length) {
      lines.push('✓ Auto-approved (' + ap.greens.length + '):');
      ap.greens.forEach(function (r) { lines.push('   ' + (r.recipe_name || r.id)); });
    }
    if (ap.reds.length) {
      lines.push('✗ Auto-rejected (' + ap.reds.length + '):');
      ap.reds.forEach(function (r) {
        var why = r.reject_reason || (r.assessment_reasons && r.assessment_reasons[0]) || 'junk';
        lines.push('   ' + (r.recipe_name || r.id) + ' — ' + why);
      });
    }
    if (ap.yellows.length) {
      lines.push('⚠ Needs you (' + ap.yellows.length + ') — editor opens for fixes:');
      ap.yellows.forEach(function (r) {
        lines.push('   ' + (r.recipe_name || r.id) + ' — ' + ((r.assessment_reasons || []).join('; ') || 'review'));
      });
    }
    return lines.join('\n');
  }

  async function runAgentReviewRecipe(recipeId, recipeName) {
    if (!recipeId) return;
    showProgressOverlay('Agent Review', 'Cleaning “' + (recipeName || 'recipe') + '”…');
    try {
      var result = await callAgentReview({ recipe_id: recipeId });
      closeProgressOverlay();
      var ap = await applyAutopilotActions([result]);

      if (result.outcome === 'auto_approve') {
        alert('✓ Auto-approved: ' + (result.recipe_name || recipeName) + '\n\n' + (result.agent_notes || 'Passed all quality gates.'));
        closeFullEditorPopup();
        if (typeof closeRecipeModal === 'function') closeRecipeModal();
        refreshRecipeList();
        return;
      }

      if (result.outcome === 'reject') {
        alert('✗ Auto-rejected: ' + (result.recipe_name || recipeName) + '\n\n' +
          (result.reject_reason || (result.assessment_reasons || []).join('; ') || 'Not a valid recipe'));
        if (typeof closeRecipeModal === 'function') closeRecipeModal();
        refreshRecipeList();
        return;
      }

      var notes = (result.agent_notes || '') +
        ((result.assessment_reasons && result.assessment_reasons.length)
          ? ' Fix: ' + result.assessment_reasons.join('; ')
          : '');
      openAdminFullEditorPopup(recipeId, {
        title: 'Needs your edit — then approve',
        subtitle: 'Agent cleaned what it could; fix flagged fields, Save, then Approve.',
        agentNotes: notes.trim(),
      });
      if (typeof openRecipeModal === 'function') {
        setTimeout(function () { openRecipeModal(recipeId); }, 400);
      }
    } catch (e) {
      closeProgressOverlay();
      alert(e.message || String(e));
    }
  }

  async function runBulkAgentReview(limit) {
    limit = limit || 10;
    if (!confirm(
      'Autopilot: clean up to ' + limit + ' oldest pending recipes?\n\n' +
      '• Green → auto-approved (no popup)\n' +
      '• Red → auto-rejected (junk / empty)\n' +
      '• Yellow → opens editor only for those\n\n' +
      'Uses Groq daily limit.',
    )) {
      return;
    }
    showProgressOverlay('Bulk Autopilot', 'Cleaning up to ' + limit + ' recipes…');
    try {
      var result = await callAgentReview({ bulk: true, limit: limit });
      closeProgressOverlay();
      var ap = await applyAutopilotActions(result.results || []);

      alert(
        'Autopilot done\n\n' +
        'Auto-approved: ' + ap.approved + '\n' +
        'Auto-rejected: ' + ap.rejected + '\n' +
        'Needs you: ' + ap.yellows.length + '\n' +
        'Failed: ' + (result.failed || 0) + '\n\n' +
        formatAutopilotSummary(ap),
      );

      refreshRecipeList();

      if (ap.yellows.length === 1) {
        var y = ap.yellows[0];
        openAdminFullEditorPopup(y.id, {
          title: 'One recipe needs you',
          agentNotes: ((y.assessment_reasons || []).join('; ') || y.agent_notes || ''),
        });
      } else if (ap.yellows.length > 1 && confirm(
        'Open full editor for the first of ' + ap.yellows.length + ' recipes that need you?',
      )) {
        var first = ap.yellows[0];
        openAdminFullEditorPopup(first.id, {
          title: 'First exception — ' + ap.yellows.length + ' total need you',
          agentNotes: ((first.assessment_reasons || []).join('; ') || first.agent_notes || ''),
        });
      }
    } catch (e) {
      closeProgressOverlay();
      alert(e.message || String(e));
    }
  }

  global.openAdminFullEditorPopup = openAdminFullEditorPopup;
  global.runAgentReviewRecipe = runAgentReviewRecipe;
  global.runBulkAgentReview = runBulkAgentReview;
  global.closeAdminFullEditorPopup = closeFullEditorPopup;

  if (typeof window !== 'undefined') {
    window.addEventListener('message', function (ev) {
      if (!ev.data || ev.data.type !== 'tcj-admin-recipe-saved') return;
      var id = ev.data.recipeId;
      if (id && typeof openRecipeModal === 'function' && document.getElementById('rm-detail-panel')) {
        openRecipeModal(id);
      }
      refreshRecipeList();
    });
  }
})(typeof window !== 'undefined' ? window : global);
