/* Shared Library mise (circular prep-board) image helpers */
(function (global) {
  'use strict';

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function approvedMiseUrl(profile) {
    if (!profile) return '';
    var url = profile.mise_image_url || '';
    if (!url || !String(url).trim()) return '';
    if (profile.image_status === 'approved') return url;
    return '';
  }

  function circleInner(profile, fallbackEmoji) {
    var url = approvedMiseUrl(profile);
    if (url) {
      return '<img class="lib-protected-img" src="' + esc(url) + '" alt="" draggable="false" loading="lazy" oncontextmenu="return false">';
    }
    return '<span class="lib-mise-emoji" aria-hidden="true">' + esc(fallbackEmoji || '·') + '</span>';
  }

  function circleFrame(profile, fallbackEmoji, extraClass) {
    var cls = 'lib-mise-circle' + (extraClass ? ' ' + extraClass : '');
    if (!approvedMiseUrl(profile)) cls += ' lib-mise-placeholder';
    return '<div class="' + cls + '">' + circleInner(profile, fallbackEmoji) + '</div>';
  }

  function bindProtection(root) {
    if (!root) return;
    root.querySelectorAll('.lib-mise-circle').forEach(function (el) {
      el.addEventListener('contextmenu', function (e) { e.preventDefault(); });
      el.addEventListener('dragstart', function (e) { e.preventDefault(); });
    });
  }

  global.LibraryMise = {
    esc: esc,
    approvedMiseUrl: approvedMiseUrl,
    circleFrame: circleFrame,
    bindProtection: bindProtection
  };
})(typeof window !== 'undefined' ? window : global);
