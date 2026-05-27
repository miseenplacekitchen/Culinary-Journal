/* ═══════════════════════════════════════════════════════════════
   THE CULINARY JOURNAL — theme-init.js
   Reads the saved theme from localStorage and applies it to the body
   so style.css's body.theme-* rules take effect.
   Include this on every page:
     <script src="theme-init.js"><\/script>
═══════════════════════════════════════════════════════════════ */
(function () {
  try {
    var t = localStorage.getItem('tcj_theme');
    if (!t || t === 'midnight-slate') return;

    function apply() {
      if (document.body && !document.body.classList.contains('theme-' + t)) {
        document.body.classList.add('theme-' + t);
      }
    }

    if (document.body) {
      apply();
    } else {
      document.addEventListener('DOMContentLoaded', apply);
    }
  } catch (_) {}
})();
