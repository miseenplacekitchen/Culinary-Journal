/**
 * Owner spec — recipe hero ring labels:
 *   Brand: 180° → 150° along inner photo circle (CCW).
 *   Handle: 270° → 300° along inner photo circle (CW).
 *   Inset: 2 mm inside inner photo circle edge (measured from DOM).
 *   Type: Cormorant Garamond italic 400, ~15px scaled to wrap.
 * Canvas renderer — does not depend on SVG textPath browser support.
 */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'The Culinary Journal';
  var FONT_FAMILY = '"Cormorant Garamond", Georgia, "Times New Roman", serif';

  function mmPx(mm) {
    return mm * (96 / 25.4);
  }

  function getGeometry(wrapEl) {
    var wrapRect = wrapEl.getBoundingClientRect();
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!wrapRect.width || !circle) return null;
    var circleRect = circle.getBoundingClientRect();
    var border = parseFloat(getComputedStyle(circle).borderTopWidth) || 3;
    var photoR = circleRect.width / 2;
    var labelR = photoR - border - mmPx(2);
    return {
      cx: (circleRect.left - wrapRect.left) + circleRect.width / 2,
      cy: (circleRect.top - wrapRect.top) + circleRect.height / 2,
      labelR: labelR,
      w: wrapRect.width,
      h: wrapRect.height
    };
  }

  function ensureCanvas(wrapEl) {
    var canvas = wrapEl.querySelector('.rh-label-canvas');
    if (!canvas) {
      canvas = document.createElement('canvas');
      canvas.className = 'rh-label-canvas';
      canvas.setAttribute('aria-hidden', 'true');
      wrapEl.appendChild(canvas);
    }
    return canvas;
  }

  function drawTextOnArc(ctx, text, geom, startDeg, endDeg, fontPx) {
    var chars = String(text || '').split('');
    if (!chars.length || geom.labelR <= 0) return;

    ctx.font = 'italic 400 ' + fontPx + 'px ' + FONT_FAMILY;
    ctx.fillStyle = '#2a1e14';
    ctx.shadowColor = 'rgba(255,255,255,0.95)';
    ctx.shadowBlur = 3;

    var widths = chars.map(function(ch) {
      return Math.max(ctx.measureText(ch === ' ' ? ' ' : ch).width, fontPx * 0.35);
    });
    var textLen = 0;
    widths.forEach(function(w) { textLen += w; });

    var spanRad = Math.abs(endDeg - startDeg) * Math.PI / 180;
    var arcLen = geom.labelR * spanRad;
    var spacing = textLen > arcLen ? arcLen / textLen : 1;
    var ccw = endDeg < startDeg;
    var traveled = 0;

    chars.forEach(function(ch, i) {
      traveled += (widths[i] / 2) * spacing;
      var angleDeg = ccw
        ? startDeg - (traveled / geom.labelR) * (180 / Math.PI)
        : startDeg + (traveled / geom.labelR) * (180 / Math.PI);
      var rad = angleDeg * Math.PI / 180;
      var x = geom.cx + geom.labelR * Math.cos(rad);
      var y = geom.cy - geom.labelR * Math.sin(rad);
      var rot = (angleDeg + 90) * Math.PI / 180;

      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(rot);
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(ch === ' ' ? '\u00a0' : ch, 0, 0);
      ctx.restore();

      traveled += (widths[i] / 2) * spacing;
    });
  }

  function paint(wrapEl, opts) {
    opts = opts || {};
    var geom = getGeometry(wrapEl);
    if (!geom) return;

    var canvas = ensureCanvas(wrapEl);
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(geom.w * dpr);
    canvas.height = Math.round(geom.h * dpr);
    canvas.style.width = geom.w + 'px';
    canvas.style.height = geom.h + 'px';

    var ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, geom.w, geom.h);

    var fontPx = Math.max(14, Math.round(geom.w * 0.038));
    drawTextOnArc(ctx, opts.brand != null ? opts.brand : BRAND_TEXT, geom, 180, 150, fontPx);
    if (opts.handle) {
      drawTextOnArc(ctx, opts.handle, geom, 270, 300, fontPx);
    }
  }

  function render(wrapEl, opts) {
    if (!wrapEl) return;
    wrapEl._rhOpts = opts || wrapEl._rhOpts || {};
    var run = function() { paint(wrapEl, wrapEl._rhOpts); };
    if (document.fonts && document.fonts.load) {
      document.fonts.load('italic 400 15px ' + FONT_FAMILY).then(run).catch(run);
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
