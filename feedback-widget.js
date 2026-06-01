/**
 * feedback-widget.js — The Culinary Journal
 * Include on all public pages EXCEPT recipe-page.html.
 * Shows a floating "Feedback" button that opens a message modal.
 * Submissions go to the Supabase feedback table.
 * Betty reviews and manages them from Admin Panel → User Management → Feedback.
 */
(function() {
  var SUPA_URL = 'https://kzywmodvfbyexqgipcjt.supabase.co';
  var SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';

  // Don't show on recipe page
  if (window.location.pathname.includes('recipe-page')) return;

  // Read profile for pre-fill
  var profile = null;
  try { profile = JSON.parse(localStorage.getItem('tcj_profile') || 'null'); } catch(_) {}
  var session = null;
  try { session = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch(_) {}

  // ── Inject styles ─────────────────────────────────────────────
  var style = document.createElement('style');
  style.textContent = `
    .tcj-fb-btn {
      position: fixed;
      bottom: 24px;
      right: 24px;
      z-index: 8888;
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 10px 18px;
      background: var(--accent, #C4973B);
      color: #fff;
      border: none;
      border-radius: 50px;
      font-family: 'DM Sans', sans-serif;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
      transition: opacity 0.2s, transform 0.2s;
    }
    .tcj-fb-btn:hover { opacity: 0.88; transform: translateY(-2px); }

    .tcj-fb-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.65);
      z-index: 9990;
      display: flex;
      align-items: center;
      justify-content: center;
      backdrop-filter: blur(3px);
    }
    .tcj-fb-box {
      background: var(--bg, #0f1117);
      border: 1px solid var(--border, rgba(255,255,255,0.1));
      border-radius: 14px;
      padding: 28px 32px;
      width: 90%;
      max-width: 480px;
      font-family: 'DM Sans', sans-serif;
    }
    .tcj-fb-title {
      font-family: 'Cormorant Garamond', serif;
      font-size: 1.3rem;
      font-weight: 700;
      color: var(--text-high, #fff);
      margin: 0 0 6px;
    }
    .tcj-fb-sub {
      font-size: 13px;
      color: var(--text-mid, rgba(255,255,255,0.5));
      margin: 0 0 20px;
      line-height: 1.6;
    }
    .tcj-fb-label {
      display: block;
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--text-mid, rgba(255,255,255,0.5));
      margin-bottom: 4px;
    }
    .tcj-fb-input, .tcj-fb-textarea, .tcj-fb-select {
      width: 100%;
      box-sizing: border-box;
      padding: 9px 12px;
      background: rgba(255,255,255,0.05);
      border: 1px solid var(--border, rgba(255,255,255,0.1));
      border-radius: 8px;
      font-family: 'DM Sans', sans-serif;
      font-size: 13px;
      color: var(--text-high, #fff);
      outline: none;
      transition: border-color 0.2s;
      margin-bottom: 14px;
    }
    .tcj-fb-input:focus, .tcj-fb-textarea:focus, .tcj-fb-select:focus {
      border-color: var(--accent, #C4973B);
    }
    .tcj-fb-textarea { resize: vertical; min-height: 110px; }
    .tcj-fb-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .tcj-fb-btns { display: flex; gap: 10px; margin-top: 4px; }
    .tcj-fb-send {
      flex: 1; padding: 11px;
      background: var(--accent, #C4973B);
      border: none; border-radius: 8px;
      color: #fff;
      font-family: 'DM Sans', sans-serif;
      font-size: 13px; font-weight: 600;
      cursor: pointer;
    }
    .tcj-fb-cancel {
      padding: 11px 20px;
      background: none;
      border: 1px solid var(--border, rgba(255,255,255,0.1));
      border-radius: 8px;
      color: var(--text-mid, rgba(255,255,255,0.5));
      font-family: 'DM Sans', sans-serif;
      font-size: 13px; cursor: pointer;
    }
    .tcj-fb-msg {
      font-size: 12px;
      margin-top: 10px;
      text-align: center;
      min-height: 18px;
    }
  `;
  document.head.appendChild(style);

  // ── Floating button ────────────────────────────────────────────
  var btn = document.createElement('button');
  btn.className = 'tcj-fb-btn';
  btn.innerHTML = '<span>✉</span><span>Feedback</span>';
  btn.setAttribute('aria-label', 'Send feedback to The Culinary Journal');
  document.body.appendChild(btn);

  // ── Modal ──────────────────────────────────────────────────────
  btn.addEventListener('click', function() {
    var overlay = document.createElement('div');
    overlay.className = 'tcj-fb-overlay';

    var box = document.createElement('div');
    box.className = 'tcj-fb-box';
    box.innerHTML = `
      <div class="tcj-fb-title">Feedback to The Culinary Journal</div>
      <p class="tcj-fb-sub">Got a suggestion, spotted something wrong, or just want to say hello? We read everything.</p>

      <label class="tcj-fb-label">Type</label>
      <select class="tcj-fb-select" id="tcj-fb-type">
        <option value="general">General feedback</option>
        <option value="suggestion">Suggestion or idea</option>
        <option value="bug">Something isn't working</option>
        <option value="recipe">Recipe feedback</option>
        <option value="other">Other</option>
      </select>

      <label class="tcj-fb-label">Message <span style="color:#dc5050">*</span></label>
      <textarea class="tcj-fb-textarea" id="tcj-fb-message" placeholder="Tell us anything\u2026"></textarea>

      <div class="tcj-fb-row">
        <div>
          <label class="tcj-fb-label">Your name <span style="color:var(--text-mid,rgba(255,255,255,0.4))">optional</span></label>
          <input class="tcj-fb-input" id="tcj-fb-name" type="text" placeholder="How should we address you?">
        </div>
        <div>
          <label class="tcj-fb-label">Email <span style="color:var(--text-mid,rgba(255,255,255,0.4))">optional — for a reply</span></label>
          <input class="tcj-fb-input" id="tcj-fb-email" type="email" placeholder="your@email.com">
        </div>
      </div>

      <div class="tcj-fb-btns">
        <button class="tcj-fb-cancel" id="tcj-fb-cancel">Cancel</button>
        <button class="tcj-fb-send" id="tcj-fb-send">Send Feedback</button>
      </div>
      <div class="tcj-fb-msg" id="tcj-fb-msg" style="color:var(--text-mid)"></div>
    `;
    overlay.appendChild(box);
    document.body.appendChild(overlay);

    // Pre-fill if logged in
    var nameEl  = box.querySelector('#tcj-fb-name');
    var emailEl = box.querySelector('#tcj-fb-email');
    if (profile) {
      if (nameEl  && profile.full_name)  nameEl.value  = profile.full_name;
      if (emailEl && profile.email)      emailEl.value = profile.email;
    }

    // Cancel
    box.querySelector('#tcj-fb-cancel').addEventListener('click', function() {
      overlay.remove();
    });
    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) overlay.remove();
    });

    // Send
    box.querySelector('#tcj-fb-send').addEventListener('click', async function() {
      var msg  = (box.querySelector('#tcj-fb-message').value || '').trim();
      var type = box.querySelector('#tcj-fb-type').value;
      var name = (nameEl.value || '').trim();
      var email = (emailEl.value || '').trim();
      var msgEl = box.querySelector('#tcj-fb-msg');

      if (!msg) {
        msgEl.style.color = '#dc5050';
        msgEl.textContent = 'Please write a message before sending.';
        box.querySelector('#tcj-fb-message').focus();
        return;
      }

      var sendBtn = box.querySelector('#tcj-fb-send');
      sendBtn.disabled = true;
      sendBtn.textContent = 'Sending\u2026';
      msgEl.textContent = '';

      try {
        var payload = {
          type: type,
          feedback: msg,
          name: name || null,
          email: email || null,
          username: profile ? (profile.username || null) : null,
          user_id: (session && session.user) ? session.user.id : null,
          status: 'new'
        };

        var authHeader = (session && session.access_token)
          ? 'Bearer ' + session.access_token
          : 'Bearer ' + SUPA_KEY;

        var res = await fetch(SUPA_URL + '/rest/v1/feedback', {
          method: 'POST',
          headers: {
            'apikey':       SUPA_KEY,
            'Authorization': authHeader,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
          },
          body: JSON.stringify(payload)
        });

        if (res.ok || res.status === 201) {
          msgEl.style.color = '#4caf76';
          msgEl.textContent = '\u2713 Thank you! We\u2019ll read your message.';
          sendBtn.textContent = '\u2713 Sent';
          setTimeout(function() { overlay.remove(); }, 2000);
        } else {
          throw new Error('Server error ' + res.status);
        }
      } catch(e) {
        msgEl.style.color = '#dc5050';
        msgEl.textContent = 'Couldn\u2019t send right now. Please try again.';
        sendBtn.disabled = false;
        sendBtn.textContent = 'Send Feedback';
      }
    });
  });
})();
