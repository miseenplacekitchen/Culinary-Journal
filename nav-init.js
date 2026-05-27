/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — nav-init.js
   Shared top-right nav buttons. Reads the saved session from
   localStorage and populates any element with id="nav-btns".

   Include on every page that has the main top nav:
     <div id="nav-btns"></div>
     <script src="nav-init.js"></script>

   Shows on every page:
     [+ Submit a Recipe] always visible
     [Sign in] [Get started]  when logged out
     [@username] [My Profile] [Sign Out]  when logged in
═══════════════════════════════════════════════════════════════ */
(function () {
  function init() {
    var btns = document.getElementById('nav-btns');
    if (!btns) return;

    var session = null;
    try { session = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
    var loggedIn = !!(session && session.access_token);
    var username = (session && session.username) || '';

    var html = '<a href="submit-recipe.html" class="btn btn-ghost">+ Submit a Recipe</a>';

    if (loggedIn) {
      html +=
        '<span style="font-family:\'DM Sans\',sans-serif;font-size:12px;color:var(--text-mid);padding:6px 12px;background:rgba(255,255,255,0.04);border-radius:20px;border:0.5px solid var(--border);margin-right:4px">@<span style="color:var(--accent)">' + escapeHtml(username) + '</span></span>' +
        '<a href="profile.html" class="btn btn-ghost">My Profile</a>' +
        '<button class="btn btn-ghost" id="signout-btn" type="button">Sign Out</button>';
    } else {
      html +=
        '<a href="login.html" class="btn btn-ghost">Sign in</a>' +
        '<a href="login.html" class="btn btn-gold">Get started</a>';
    }

    btns.innerHTML = html;

    var signoutBtn = document.getElementById('signout-btn');
    if (signoutBtn) {
      signoutBtn.onclick = function () {
        try { localStorage.removeItem('tcj_session'); } catch (_) {}
        try { localStorage.removeItem('tcj_profile'); } catch (_) {}
        window.location.reload();
      };
    }
  }

  function escapeHtml(s) {
    return String(s || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
