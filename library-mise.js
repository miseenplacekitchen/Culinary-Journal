/* Library mise circles — circular crop + brand-only ring captions */
(function (global) {
  'use strict';

  var RING_SVG =
    '<svg class="sr-img-hero-ring lib-mise-ring" viewBox="0 0 420 420" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
    '<circle class="sr-img-hero-ring-stroke" cx="210" cy="210" r="168"/>' +
    '<defs><path id="sr-ring-arc-brand" fill="none"/><path id="sr-ring-arc-handle" fill="none"/></defs>' +
    '<text class="rh-ring-text rh-ring-brand"><textPath href="#sr-ring-arc-brand">THE CULINARY JOURNAL</textPath></text>' +
    '<text class="rh-ring-text rh-ring-handle" style="display:none"><textPath href="#sr-ring-arc-handle"></textPath></text>' +
    '</svg>';

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
      return '<img class="sr-img-hero-img lib-protected-img" src="' + esc(url) + '" alt="" draggable="false" loading="lazy" crossorigin="anonymous" oncontextmenu="return false">';
    }
    return '<span class="lib-mise-emoji" aria-hidden="true">' + esc(fallbackEmoji || '·') + '</span>';
  }

  function circleFrame(profile, fallbackEmoji, extraClass) {
    var url = approvedMiseUrl(profile);
    var wrapCls = 'lib-mise-ring-wrap sr-img-hero-ring-wrap' + (extraClass ? ' ' + extraClass : '');
    if (!url) {
      var phCls = 'lib-mise-circle lib-mise-placeholder' + (extraClass ? ' ' + extraClass : '');
      return '<div class="' + phCls + '">' + circleInner(profile, fallbackEmoji) + '</div>';
    }
    return (
      '<div class="' + wrapCls + '">' +
      RING_SVG +
      '<div class="sr-img-hero-circle lib-mise-circle">' +
      circleInner(profile, fallbackEmoji) +
      '</div></div>'
    );
  }

  function bindProtection(root) {
    if (!root) return;
    root.querySelectorAll('.lib-mise-circle, .lib-mise-ring-wrap').forEach(function (el) {
      el.addEventListener('contextmenu', function (e) { e.preventDefault(); });
      el.addEventListener('dragstart', function (e) { e.preventDefault(); });
    });
  }

  function mountRings(root) {
    if (!root || !global.RecipeHeroLabels) return;
    root.querySelectorAll('.lib-mise-ring-wrap').forEach(function (wrap) {
      global.RecipeHeroLabels.render(wrap, {});
    });
    bindProtection(root);
  }

  global.LibraryMise = {
    esc: esc,
    approvedMiseUrl: approvedMiseUrl,
    circleFrame: circleFrame,
    bindProtection: bindProtection,
    mountRings: mountRings,
    ringSvg: RING_SVG
  };
})(typeof window !== 'undefined' ? window : global);
