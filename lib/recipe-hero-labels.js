/**
 * Recipe hero ring labels — spec (do not change without owner approval):
 *   Brand "The Culinary Journal": starts 180°, curves to 150° (CCW), 2 mm inside photo inner edge.
 *   Handle @username: starts 270°, curves to 300° (CW), same inset.
 *   Font: Cormorant Garamond italic, weight 400, 15px in 420 viewBox.
 *   Paths live inside the ring <svg viewBox="0 0 420 420"> — same element as the accent ring.
 */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'The Culinary Journal';

  function fitTextToPath(textPathEl, pathEl) {
    if (!textPathEl || !pathEl) return;
    var len = pathEl.getTotalLength();
    if (!len) return;
    textPathEl.setAttribute('textLength', len.toFixed(2));
    textPathEl.setAttribute('lengthAdjust', 'spacing');
  }

  function render(wrapEl, opts) {
    opts = opts || {};
    if (!wrapEl) return;
    var svg = wrapEl.querySelector('svg');
    if (!svg) return;

    var brandPath = svg.querySelector('#rh-arc-brand');
    var handlePath = svg.querySelector('#rh-arc-handle');
    var brandText = svg.querySelector('#rh-text-brand');
    var handleText = svg.querySelector('#rh-text-handle');
    var brandTP = brandText && brandText.querySelector('textPath');
    var handleTP = handleText && handleText.querySelector('textPath');

    if (brandTP && brandPath) {
      if (opts.brand != null) brandTP.textContent = opts.brand;
      else if (!brandTP.textContent) brandTP.textContent = BRAND_TEXT;
      fitTextToPath(brandTP, brandPath);
    }

    var handle = opts.handle || '';
    if (handleTP && handleText && handlePath) {
      if (handle) {
        handleTP.textContent = handle;
        fitTextToPath(handleTP, handlePath);
        handleText.style.display = '';
      } else {
        handleText.style.display = 'none';
      }
    }
  }

  global.RecipeHeroLabels = {
    BRAND_TEXT: BRAND_TEXT,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
