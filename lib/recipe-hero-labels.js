/* Curved hero labels — dynamic SVG textPath on the inner-circle arc. */
(function (global) {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var BRAND_TEXT = 'The Culinary Journal';

  function deg2rad(d) { return d * Math.PI / 180; }

  function mmToPx(mm, wrapSize) {
    return mm * (96 / 25.4) * (wrapSize / 400);
  }

  /* 2 mm inside the inner edge of the photo circle (inside the accent border). */
  function labelRadius(wrapSize) {
    var photoOuterR = wrapSize * 0.4;
    var borderPx = 3;
    return photoOuterR - borderPx - mmToPx(2, wrapSize);
  }

  function polar(cx, cy, r, deg) {
    var rad = deg2rad(deg);
    return { x: cx + r * Math.cos(rad), y: cy - r * Math.sin(rad) };
  }

  function arcPathD(cx, cy, r, startDeg, endDeg, ccw) {
    var s = polar(cx, cy, r, startDeg);
    var e = polar(cx, cy, r, endDeg);
    var span = Math.abs(startDeg - endDeg);
    var large = span > 180 ? 1 : 0;
    var sweep = ccw ? 0 : 1;
    return 'M ' + s.x.toFixed(2) + ' ' + s.y.toFixed(2) +
      ' A ' + r.toFixed(2) + ' ' + r.toFixed(2) + ' 0 ' + large + ' ' + sweep +
      ' ' + e.x.toFixed(2) + ' ' + e.y.toFixed(2);
  }

  function estimateSpanDeg(text, fontPx, r) {
    var chars = String(text || '').length;
    if (!chars) return 0;
    var arcLen = chars * fontPx * 0.52;
    return (arcLen / r) * (180 / Math.PI);
  }

  function fitFont(text, r, maxSpanDeg, baseFont) {
    var fontPx = baseFont;
    while (fontPx > 7.5) {
      if (estimateSpanDeg(text, fontPx, r) <= maxSpanDeg) break;
      fontPx -= 0.3;
    }
    return fontPx;
  }

  function ensureSvg(layer, size) {
    if (!layer._rhUid) layer._rhUid = 'rh' + Math.random().toString(36).slice(2, 9);
    var uid = layer._rhUid;
    var svg = layer.querySelector('svg.recipe-hero-labels-svg');
    if (!svg) {
      svg = document.createElementNS(NS, 'svg');
      svg.setAttribute('class', 'recipe-hero-labels-svg');
      svg.setAttribute('aria-hidden', 'true');
      var defs = document.createElementNS(NS, 'defs');
      var brandPath = document.createElementNS(NS, 'path');
      brandPath.setAttribute('id', uid + '-brand');
      brandPath.setAttribute('fill', 'none');
      var handlePath = document.createElementNS(NS, 'path');
      handlePath.setAttribute('id', uid + '-handle');
      handlePath.setAttribute('fill', 'none');
      defs.appendChild(brandPath);
      defs.appendChild(handlePath);
      svg.appendChild(defs);
      layer.appendChild(svg);
    }
    svg.setAttribute('viewBox', '0 0 ' + size + ' ' + size);
    svg.setAttribute('width', '100%');
    svg.setAttribute('height', '100%');
    svg._rhUid = uid;
    return svg;
  }

  function upsertText(svg, id, pathId, text, fontPx, show) {
    var el = svg.querySelector('[data-rh-text="' + id + '"]');
    if (!show || !text) {
      if (el) el.style.display = 'none';
      return;
    }
    if (!el) {
      el = document.createElementNS(NS, 'text');
      el.setAttribute('data-rh-text', id);
      el.setAttribute('class', 'recipe-hero-label-text');
      var tp = document.createElementNS(NS, 'textPath');
      tp.setAttribute('href', '#' + pathId);
      tp.setAttribute('startOffset', '0%');
      tp.setAttribute('text-anchor', 'start');
      el.appendChild(tp);
      svg.appendChild(el);
    }
    el.style.display = '';
    el.setAttribute('font-size', fontPx + 'px');
    el.querySelector('textPath').textContent = text;
  }

  function render(wrapEl, opts) {
    opts = opts || {};
    if (!wrapEl) return;
    var layer = wrapEl.querySelector('.sr-img-label-layer, .rp-img-label-layer');
    if (!layer) return;
    var size = wrapEl.getBoundingClientRect().width || wrapEl.offsetWidth;
    if (!size) return;

    var cx = size / 2;
    var cy = size / 2;
    var r = labelRadius(size);
    var baseFont = Math.max(11, Math.round(size * 0.033));
    var svg = ensureSvg(layer, size);

    var brandText = opts.brand != null ? opts.brand : BRAND_TEXT;
    var brandStart = opts.brandStart != null ? opts.brandStart : 180;
    var brandEndLimit = opts.brandEnd != null ? opts.brandEnd : 150;
    var brandMaxSpan = brandStart - brandEndLimit;
    var brandFont = fitFont(brandText, r, brandMaxSpan, baseFont);
    var brandSpan = Math.min(brandMaxSpan, estimateSpanDeg(brandText, brandFont, r));
    var brandEnd = brandStart - brandSpan;

    var uid = svg._rhUid;
    var brandPath = svg.querySelector('#' + uid + '-brand');
    brandPath.setAttribute('d', arcPathD(cx, cy, r, brandStart, brandEnd, true));
    upsertText(svg, 'brand', uid + '-brand', brandText, brandFont, true);

    var handleText = opts.handle || '';
    if (handleText) {
      var handleStart = opts.handleStart != null ? opts.handleStart : 270;
      var handleEndLimit = opts.handleEnd != null ? opts.handleEnd : 300;
      var handleMaxSpan = handleEndLimit - handleStart;
      var handleFont = fitFont(handleText, r, handleMaxSpan, baseFont);
      var handleSpan = Math.min(handleMaxSpan, estimateSpanDeg(handleText, handleFont, r));
      var handleEnd = handleStart + handleSpan;

      var handlePath = svg.querySelector('#' + uid + '-handle');
      handlePath.setAttribute('d', arcPathD(cx, cy, r, handleStart, handleEnd, false));
      upsertText(svg, 'handle', uid + '-handle', handleText, handleFont, true);
    } else {
      upsertText(svg, 'handle', uid + '-handle', '', 0, false);
    }
  }

  global.RecipeHeroLabels = {
    BRAND_TEXT: BRAND_TEXT,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
