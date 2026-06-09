/* Curved hero labels — characters placed along measured SVG arc paths. */
(function (global) {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var BRAND_TEXT = 'The Culinary Journal';

  function deg2rad(d) { return d * Math.PI / 180; }

  function mmToPx(mm, wrapSize) {
    return mm * (96 / 25.4) * (wrapSize / 400);
  }

  /* 2 mm inside the photo circle outer edge. */
  function labelRadius(wrapSize) {
    return wrapSize * 0.4 - mmToPx(2, wrapSize);
  }

  function polar(cx, cy, r, deg) {
    var rad = deg2rad(deg);
    return { x: cx + r * Math.cos(rad), y: cy - r * Math.sin(rad) };
  }

  function arcPathD(cx, cy, r, startDeg, endDeg, sweep) {
    var s = polar(cx, cy, r, startDeg);
    var e = polar(cx, cy, r, endDeg);
    var span = Math.abs(startDeg - endDeg);
    var large = span > 180 ? 1 : 0;
    return 'M ' + s.x.toFixed(2) + ' ' + s.y.toFixed(2) +
      ' A ' + r.toFixed(2) + ' ' + r.toFixed(2) + ' 0 ' + large + ' ' + sweep +
      ' ' + e.x.toFixed(2) + ' ' + e.y.toFixed(2);
  }

  function pathLength(d) {
    var svg = document.createElementNS(NS, 'svg');
    svg.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden;visibility:hidden';
    var path = document.createElementNS(NS, 'path');
    path.setAttribute('d', d);
    svg.appendChild(path);
    document.body.appendChild(svg);
    var len = path.getTotalLength();
    document.body.removeChild(svg);
    return len;
  }

  function bestArcD(cx, cy, r, startDeg, endDeg) {
    var span = Math.abs(startDeg - endDeg);
    var want = r * deg2rad(span);
    var d0 = arcPathD(cx, cy, r, startDeg, endDeg, 0);
    var d1 = arcPathD(cx, cy, r, startDeg, endDeg, 1);
    return Math.abs(pathLength(d0) - want) <= Math.abs(pathLength(d1) - want) ? d0 : d1;
  }

  var _measureCanvas = null;
  function charWidths(text, fontPx) {
    if (!_measureCanvas) _measureCanvas = document.createElement('canvas');
    var ctx = _measureCanvas.getContext('2d');
    ctx.font = '400 italic ' + fontPx + 'px "Cormorant Garamond", Georgia, serif';
    return String(text || '').split('').map(function(ch) {
      var w = ctx.measureText(ch === ' ' ? ' ' : ch).width;
      return Math.max(w, fontPx * (ch === ' ' ? 0.3 : 0.42));
    });
  }

  function appendChar(layer, ch, x, y, angleDeg, className, fontPx) {
    var span = document.createElement('span');
    span.className = className || 'recipe-hero-char';
    span.textContent = ch === ' ' ? '\u00a0' : ch;
    span.style.fontSize = fontPx + 'px';
    span.style.left = x + 'px';
    span.style.top = y + 'px';
    span.style.transform =
      'translate(-50%, -50%) rotate(' + angleDeg + 'deg)';
    layer.appendChild(span);
  }

  function renderAlongPath(layer, text, pathD, className, fontPx, anchorStart) {
    var chars = String(text || '').split('');
    if (!chars.length) return;

    var svg = document.createElementNS(NS, 'svg');
    svg.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden;visibility:hidden';
    var path = document.createElementNS(NS, 'path');
    path.setAttribute('d', pathD);
    svg.appendChild(path);
    document.body.appendChild(svg);

    var pathLen = path.getTotalLength();
    var widths = charWidths(chars.join(''), fontPx);
    var textLen = 0;
    widths.forEach(function(w) { textLen += w; });

    var scale = textLen > pathLen ? pathLen / textLen : 1;
    var fontUsed = fontPx;
    if (scale < 0.82 && fontPx > 10) {
      fontUsed = Math.max(10, fontPx * 0.9);
      widths = charWidths(chars.join(''), fontUsed);
      textLen = 0;
      widths.forEach(function(w) { textLen += w; });
      scale = textLen > pathLen ? pathLen / textLen : 1;
    }

    var offset = anchorStart ? 0 : (pathLen - textLen * scale) / 2;
    var traveled = offset;

    chars.forEach(function(ch, i) {
      traveled += (widths[i] / 2) * scale;
      var t = Math.max(0, Math.min(pathLen, traveled));
      var pt = path.getPointAtLength(t);
      var pt2 = path.getPointAtLength(Math.min(pathLen, t + 1.5));
      var angle = Math.atan2(pt2.y - pt.y, pt2.x - pt.x) * (180 / Math.PI);
      appendChar(layer, ch, pt.x, pt.y, angle, className, fontUsed);
      traveled += (widths[i] / 2) * scale;
    });

    document.body.removeChild(svg);
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
    var fontPx = Math.max(13, Math.round(size * 0.04));
    var charClass = opts.charClass || 'recipe-hero-char';

    layer.innerHTML = '';

    var brandStart = opts.brandStart != null ? opts.brandStart : 180;
    var brandEnd = opts.brandEnd != null ? opts.brandEnd : 150;
    var brandPath = bestArcD(cx, cy, r, brandStart, brandEnd);
    renderAlongPath(
      layer,
      opts.brand != null ? opts.brand : BRAND_TEXT,
      brandPath,
      charClass,
      fontPx,
      true
    );

    if (opts.handle) {
      var handleStart = opts.handleStart != null ? opts.handleStart : 270;
      var handleEnd = opts.handleEnd != null ? opts.handleEnd : 300;
      var handlePath = bestArcD(cx, cy, r, handleStart, handleEnd);
      renderAlongPath(layer, opts.handle, handlePath, charClass, fontPx, true);
    }
  }

  global.RecipeHeroLabels = {
    BRAND_TEXT: BRAND_TEXT,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
