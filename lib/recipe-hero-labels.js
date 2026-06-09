/* Curved hero labels — SVG textPath in 420 viewBox (matches ring SVG scale). */
(function (global) {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var XLINK = 'http://www.w3.org/1999/xlink';
  var BRAND_TEXT = 'The Culinary Journal';
  var VB = 420;
  var CX = 210;
  var CY = 210;

  function deg2rad(d) { return d * Math.PI / 180; }

  function mmToPx(mm, refSize) {
    return mm * (96 / 25.4) * (refSize / 400);
  }

  /* 2 mm inside photo inner edge; photo outer r=168 in 420 viewBox. */
  function labelRadius() {
    return 168 - 3 - mmToPx(2, VB);
  }

  function polar(r, deg) {
    var rad = deg2rad(deg);
    return {
      x: CX + r * Math.cos(rad),
      y: CY - r * Math.sin(rad)
    };
  }

  function arcPath(r, startDeg, endDeg, sweep) {
    var s = polar(r, startDeg);
    var e = polar(r, endDeg);
    var span = Math.abs(startDeg - endDeg);
    var large = span > 180 ? 1 : 0;
    return 'M ' + s.x.toFixed(2) + ' ' + s.y.toFixed(2) +
      ' A ' + r.toFixed(2) + ' ' + r.toFixed(2) + ' 0 ' + large + ' ' + sweep +
      ' ' + e.x.toFixed(2) + ' ' + e.y.toFixed(2);
  }

  function pathLength(d) {
    var svg = document.createElementNS(NS, 'svg');
    var path = document.createElementNS(NS, 'path');
    path.setAttribute('d', d);
    svg.appendChild(path);
    document.body.appendChild(svg);
    var len = path.getTotalLength();
    document.body.removeChild(svg);
    return len;
  }

  function ensureLabelSvg(layer, uid) {
    var svg = layer.querySelector('svg.recipe-hero-labels-svg');
    if (!svg) {
      svg = document.createElementNS(NS, 'svg');
      svg.setAttribute('class', 'recipe-hero-labels-svg');
      svg.setAttribute('viewBox', '0 0 ' + VB + ' ' + VB);
      svg.setAttribute('aria-hidden', 'true');
      svg.setAttribute('xmlns', NS);
      svg.setAttribute('xmlns:xlink', XLINK);

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
    return svg;
  }

  function setTextPath(svg, uid, key, pathD, text, fontSize, show) {
    var textId = uid + '-text-' + key;
    var pathId = uid + '-' + key;
    var pathEl = svg.querySelector('#' + pathId);
    if (pathEl) pathEl.setAttribute('d', pathD);

    var textEl = svg.querySelector('#' + textId);
    if (!show || !text) {
      if (textEl) textEl.style.display = 'none';
      return;
    }

    if (!textEl) {
      textEl = document.createElementNS(NS, 'text');
      textEl.setAttribute('id', textId);
      textEl.setAttribute('class', 'recipe-hero-label-text');
      var tp = document.createElementNS(NS, 'textPath');
      tp.setAttribute('href', '#' + pathId);
      tp.setAttributeNS(XLINK, 'href', '#' + pathId);
      tp.setAttribute('startOffset', '0%');
      tp.setAttribute('text-anchor', 'start');
      textEl.appendChild(tp);
      svg.appendChild(textEl);
    }

    textEl.style.display = '';
    textEl.setAttribute('font-size', fontSize);
    var arcLen = pathLength(pathD);
    var tp = textEl.querySelector('textPath');
    tp.textContent = text;
    tp.setAttribute('textLength', String(arcLen.toFixed(2)));
    tp.setAttribute('lengthAdjust', 'spacing');
  }

  function draw(wrapEl, opts) {
    opts = opts || {};
    if (!wrapEl) return;
    var layer = wrapEl.querySelector('.sr-img-label-layer, .rp-img-label-layer');
    if (!layer) return;

    if (!wrapEl._rhUid) wrapEl._rhUid = 'rh' + Math.random().toString(36).slice(2, 9);
    var uid = wrapEl._rhUid;
    var r = labelRadius();
    var fontSize = 14;

    var brandStart = opts.brandStart != null ? opts.brandStart : 180;
    var brandEnd = opts.brandEnd != null ? opts.brandEnd : 150;
    var handleStart = opts.handleStart != null ? opts.handleStart : 270;
    var handleEnd = opts.handleEnd != null ? opts.handleEnd : 300;

    var brandPath = arcPath(r, brandStart, brandEnd, 0);
    var handlePath = arcPath(r, handleStart, handleEnd, 1);

    var svg = ensureLabelSvg(layer, uid);
    setTextPath(svg, uid, 'brand', brandPath, opts.brand != null ? opts.brand : BRAND_TEXT, fontSize, true);
    setTextPath(svg, uid, 'handle', handlePath, opts.handle || '', fontSize, !!opts.handle);
  }

  function render(wrapEl, opts) {
    if (!wrapEl) return;
    wrapEl._rhOpts = opts || wrapEl._rhOpts || {};
    var w = wrapEl.getBoundingClientRect().width;
    if (!w) {
      requestAnimationFrame(function() { render(wrapEl, wrapEl._rhOpts); });
      return;
    }
    function run() { draw(wrapEl, wrapEl._rhOpts); }
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(run);
    } else {
      run();
    }
    if (!wrapEl._rhRO && typeof ResizeObserver !== 'undefined') {
      wrapEl._rhRO = new ResizeObserver(run);
      wrapEl._rhRO.observe(wrapEl);
    }
  }

  global.RecipeHeroLabels = {
    BRAND_TEXT: BRAND_TEXT,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
