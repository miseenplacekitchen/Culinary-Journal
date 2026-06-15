/**
 * Admin dashboard — Agent Review buttons + full-field editor popup.
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

  /** Center popup — full Submit a Recipe form for one pending recipe. */
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
      (opts.subtitle || 'Same form as Submit a Recipe — save, then approve in the review panel.') +
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

  function updateProgressOverlay(message) {
    var el = document.getElementById('rm-agent-progress-msg');
    if (el) el.textContent = message;
  }

  function closeProgressOverlay() {
    var el = document.getElementById('rm-agent-progress-overlay');
    if (el) el.remove();
  }

  /** Single recipe — Groq agent clean, then open full editor popup. */
  async function runAgentReviewRecipe(recipeId, recipeName) {
    if (!recipeId) return;
    showProgressOverlay(
      'Agent Review',
      'Cleaning “' + (recipeName || 'recipe') + '” — title, ingredients, procedure, credits…',
    );
    try {
      var result = await callAgentReview({ recipe_id: recipeId });
      closeProgressOverlay();
      var notes = result.agent_notes || 'Agent review complete.';
      if (result.reject_recommended) {
        notes += ' ⚠ Agent suggests reject: ' + (result.reject_reason || 'see review panel');
      }
      openAdminFullEditorPopup(recipeId, {
        title: 'Agent Review — edit & save',
        subtitle: 'Review agent changes, adjust any field, then Save recipe changes.',
        agentNotes: notes,
      });
      if (typeof openRecipeModal === 'function' && document.getElementById('rm-detail-panel')) {
        setTimeout(function () { openRecipeModal(recipeId); }, 500);
      }
    } catch (e) {
      closeProgressOverlay();
      alert(e.message || String(e));
    }
  }

  /** Bulk — up to 25 pending; then open first success in full editor. */
  async function runBulkAgentReview(limit) {
    limit = limit || 10;
    if (!confirm(
      'Run Agent Review on up to ' + limit + ' oldest pending recipes?\n\n' +
      'This uses Groq (daily limit applies). You will still Approve each recipe yourself.',
    )) {
      return;
    }
    showProgressOverlay('Bulk Agent Review', 'Processing up to ' + limit + ' pending recipes…');
    try {
      var result = await callAgentReview({ bulk: true, limit: limit });
      closeProgressOverlay();
      var lines = (result.results || []).map(function (r) {
        if (r.ok) {
          return '✓ ' + (r.recipe_name || r.id) + (r.reject_recommended ? ' (flag reject)' : '');
        }
        return '✗ ' + (r.recipe_name || r.id) + ': ' + (r.error || 'failed');
      });
      alert(
        'Bulk Agent Review done\n\n' +
        'Succeeded: ' + (result.succeeded || 0) + '\n' +
        'Failed: ' + (result.failed || 0) + '\n\n' +
        lines.join('\n'),
      );
      if (typeof loadRecipeMgmt === 'function') {
        loadRecipeMgmt(typeof _currentRecipeTab !== 'undefined' ? _currentRecipeTab : 'pending');
      }
      var firstOk = (result.results || []).find(function (r) { return r.ok && !r.reject_recommended; });
      if (firstOk && firstOk.id) {
        openAdminFullEditorPopup(firstOk.id, {
          title: 'First cleaned recipe — edit & save',
          agentNotes: firstOk.agent_notes || '',
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
      if (typeof loadRecipeMgmt === 'function') {
        loadRecipeMgmt(typeof _currentRecipeTab !== 'undefined' ? _currentRecipeTab : 'pending');
      }
    });
  }
})(typeof window !== 'undefined' ? window : global);
