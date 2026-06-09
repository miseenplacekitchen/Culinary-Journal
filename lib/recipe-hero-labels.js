/* Curved hero labels — each character placed on the inner-circle arc. */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'The Culinary Journal';
  var _measureCanvas = null;

  function deg2rad(d) { return d * Math.PI / 180; }

  /* Just inside the photo circle edge (~2 mm inset). Photo disc = 40% of wrap radius. */
  function labelRadius(wrapSize) {
    var photoR = wrapSize * 0.4;
    var inset = Math.max(5, wrapSize * 0.014);
    return photoR - inset;
  }

  /* Baseline tangent to circle; readable from outside. */
  function charRotationDeg(angleDeg) {
    return angleDeg + 90;
  }

  function measureChar(ch, fontPx, fontFamily) {
    if (!_measureCanvas) {
      _measureCanvas = document.createElement('canvas');
    }
    var ctx = _measureCanvas.getContext('2d');
    ctx.font = '400 italic ' + fontPx + 'px ' + (fontFamily || '"Cormorant Garamond", Georgia, serif');
    return ctx.measureText(ch === ' ' ? ' ' : ch).width;
  }

  function charWidths(text, fontPx, fontFamily) {
    return String(text || '').split('').map(function(ch) {
      var w = measureChar(ch, fontPx, fontFamily);
      return Math.max(w, fontPx * (ch === ' ' ? 0.28 : 0.38));
    });
  }

  function totalArcDeg(widths, r) {
    var sum = 0;
    widths.forEach(function(w) { sum += w; });
    return (sum / r) * (180 / Math.PI);
  }

  function appendChar(layer, ch, cx, cy, r, angleDeg, className, fontPx) {
    var span = document.createElement('span');
    span.className = className || 'recipe-hero-char';
    span.textContent = ch === ' ' ? '\u00a0' : ch;
    span.style.fontSize = fontPx + 'px';
    var theta = deg2rad(angleDeg);
    var x = cx + r * Math.cos(theta);
    var y = cy - r * Math.sin(theta);
    span.style.left = x + 'px';
    span.style.top = y + 'px';
    span.style.transform =
      'translate(-50%, -50%) rotate(' + charRotationDeg(angleDeg) + 'deg)';
    layer.appendChild(span);
  }

  /**
   * Place characters along a circular arc using real glyph widths.
   * anchorDeg = centre of the text on the circle.
   * direction: 'ccw' (brand, upper-left rim), 'cw' (handle, lower-right rim).
   */
  function renderArc(layer, text, cx, cy, r, anchorDeg, direction, className, maxSpanDeg) {
    var chars = String(text || '').split('');
    if (!chars.length) return;

    var baseFont = parseFloat(layer.style.fontSize) || 13;
    var fontFamily = layer.style.fontFamily || '"Cormorant Garamond", Georgia, serif';
    var fontPx = baseFont;
    var widths = charWidths(chars.join(''), fontPx, fontFamily);
    var spanDeg = totalArcDeg(widths, r);

    while (spanDeg > maxSpanDeg && fontPx > 8) {
      fontPx -= 0.35;
      widths = charWidths(chars.join(''), fontPx, fontFamily);
      spanDeg = totalArcDeg(widths, r);
    }

    var halfSpan = spanDeg / 2;
    var traveled = 0;

    chars.forEach(function(ch, i) {
      traveled += widths[i] / 2;
      var deltaDeg = (traveled / r) * (180 / Math.PI);
      var angleDeg = direction === 'ccw'
        ? (anchorDeg + halfSpan) - deltaDeg
        : (anchorDeg - halfSpan) + deltaDeg;
      appendChar(layer, ch, cx, cy, r, angleDeg, className, fontPx);
      traveled += widths[i] / 2;
    });
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
    layer.innerHTML = '';
    layer.style.fontSize = Math.max(11, Math.round(size * 0.033)) + 'px';
    layer.style.fontFamily = '"Cormorant Garamond", Georgia, "Times New Roman", serif';

    /* Brand centred on upper-left inner rim (180°–150° zone). */
    renderArc(
      layer,
      opts.brand != null ? opts.brand : BRAND_TEXT,
      cx, cy, r,
      opts.brandAnchor != null ? opts.brandAnchor : 165,
      'ccw',
      opts.charClass,
      opts.brandMaxSpan != null ? opts.brandMaxSpan : 55
    );

    if (opts.handle) {
      /* Handle centred on lower-right inner rim (270°–300° zone). */
      renderArc(
        layer,
        opts.handle,
        cx, cy, r,
        opts.handleAnchor != null ? opts.handleAnchor : 285,
        'cw',
        opts.charClass,
        opts.handleMaxSpan != null ? opts.handleMaxSpan : 44
      );
    }
  }

  global.RecipeHeroLabels = {
    BRAND_TEXT: BRAND_TEXT,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
