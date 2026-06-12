/**
 * Shared circular hero editor — zoom, pan, backdrop sample, high-res bake.
 * Used by library mise uploads (brand-only ring via RecipeHeroLabels).
 */
(function (global) {
  'use strict';

  function clampZoom(z) {
    return Math.min(3, Math.max(1, z || 1));
  }

  function create(opts) {
    opts = opts || {};
    var img = opts.imgEl;
    var circle = opts.circleEl;
    var overlay = opts.overlayEl;
    var zoomValEl = opts.zoomValEl;
    var ringWrap = opts.ringWrapEl;

    var state = {
      panX: 0,
      panY: 0,
      zoom: 1,
      nativeFile: null,
      blobUrl: null,
      sourceUrl: '',
      hasImage: false
    };

    function syncCropGlobal() {
      global._imgCrop = { panX: state.panX, panY: state.panY, zoom: state.zoom };
    }

    function getMetrics() {
      if (!img || !circle || !img.naturalWidth) return null;
      var cw = circle.clientWidth;
      var ch = circle.clientHeight;
      if (!cw || !ch) return null;
      var baseScale = Math.max(cw / img.naturalWidth, ch / img.naturalHeight);
      var zoom = clampZoom(state.zoom);
      return {
        img: img,
        circle: circle,
        cw: cw,
        ch: ch,
        baseScale: baseScale,
        scale: baseScale * zoom,
        panX: state.panX,
        panY: state.panY
      };
    }

    function sampleBackdrop() {
      if (!img || !circle || !img.naturalWidth) return;
      try {
        var canvas = document.createElement('canvas');
        var size = 24;
        canvas.width = size;
        canvas.height = size;
        var ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, size, size);
        var pts = [
          [0, 0], [size - 1, 0], [0, size - 1], [size - 1, size - 1],
          [size / 2, 0], [size / 2, size - 1], [0, size / 2], [size - 1, size / 2]
        ];
        var r = 0;
        var g = 0;
        var b = 0;
        var n = 0;
        pts.forEach(function (p) {
          var d = ctx.getImageData(Math.floor(p[0]), Math.floor(p[1]), 1, 1).data;
          r += d[0];
          g += d[1];
          b += d[2];
          n++;
        });
        circle.style.background = 'rgb(' + Math.round(r / n) + ',' + Math.round(g / n) + ',' + Math.round(b / n) + ')';
      } catch (_) { TcjErr.warn('lib/circular-hero-editor.js:78', _); }
    }

    function renderLabels() {
      syncCropGlobal();
      if (ringWrap && global.RecipeHeroLabels) {
        global.RecipeHeroLabels.render(ringWrap, {});
      }
    }

    function layout() {
      var m = getMetrics();
      if (!m) return;
      var w = Math.max(1, m.img.naturalWidth * m.scale);
      var h = Math.max(1, m.img.naturalHeight * m.scale);
      img.style.width = w + 'px';
      img.style.height = h + 'px';
      img.style.transform = 'translate(calc(-50% + ' + m.panX + 'px), calc(-50% + ' + m.panY + 'px))';
      sampleBackdrop();
      renderLabels();
    }

    function resetCrop() {
      state.panX = 0;
      state.panY = 0;
      state.zoom = 1;
      if (zoomValEl) zoomValEl.textContent = '100%';
      layout();
    }

    function adjustZoom(direction) {
      state.zoom = clampZoom(state.zoom + direction * 0.1);
      if (zoomValEl) zoomValEl.textContent = Math.round(state.zoom * 100) + '%';
      layout();
    }

    function bindDrag() {
      if (!overlay || overlay._cheBound) return;
      overlay._cheBound = true;
      var dragging = false;
      var startX = 0;
      var startY = 0;
      var startPanX = 0;
      var startPanY = 0;

      function pointer(e) {
        return e.touches && e.touches.length ? e.touches[0] : e;
      }

      function onStart(e) {
        if (!state.hasImage) return;
        dragging = true;
        overlay.classList.add('dragging');
        var pt = pointer(e);
        startX = pt.clientX;
        startY = pt.clientY;
        startPanX = state.panX;
        startPanY = state.panY;
        e.preventDefault();
      }

      function onMove(e) {
        if (!dragging) return;
        var pt = pointer(e);
        state.panX = startPanX + (pt.clientX - startX);
        state.panY = startPanY + (pt.clientY - startY);
        layout();
        e.preventDefault();
      }

      function onEnd() {
        dragging = false;
        overlay.classList.remove('dragging');
      }

      overlay.addEventListener('mousedown', onStart);
      overlay.addEventListener('touchstart', onStart, { passive: false });
      global.addEventListener('mousemove', onMove);
      global.addEventListener('touchmove', onMove, { passive: false });
      global.addEventListener('mouseup', onEnd);
      global.addEventListener('touchend', onEnd);
    }

    function setSrc(src) {
      if (!img || !src) return;
      if (/^https?:\/\//i.test(src)) img.crossOrigin = 'anonymous';
      else img.removeAttribute('crossOrigin');
      img.onload = function () {
        state.hasImage = true;
        layout();
      };
      img.src = src;
      if (img.complete && img.naturalWidth) {
        state.hasImage = true;
        layout();
      }
    }

    function loadFromFile(file) {
      if (!file) return;
      if (state.blobUrl) {
        try { URL.revokeObjectURL(state.blobUrl); } catch(_) { TcjErr.ignore(_); }
      }
      state.nativeFile = file;
      state.blobUrl = URL.createObjectURL(file);
      var reader = new FileReader();
      reader.onload = function (e) {
        state.sourceUrl = e.target.result;
        setSrc(state.blobUrl);
      };
      reader.readAsDataURL(file);
    }

    function loadFromUrl(url, loadOpts) {
      loadOpts = loadOpts || {};
      if (!url) return;
      state.sourceUrl = url;
      if (!loadOpts.keepCrop) resetCrop();
      setSrc(url);
    }

    function bake() {
      return new Promise(function (resolve) {
        if (!state.hasImage) {
          resolve('');
          return;
        }
        syncCropGlobal();

        function bakeDrawable(drawable, nw, nh) {
          var m = getMetrics();
          if (!m || !nw || !nh) {
            resolve(state.sourceUrl || '');
            return;
          }
          var maxSrc = Math.max(nw, nh);
          var outSize = Math.min(2400, Math.max(1200, maxSrc));
          var dpr = Math.min(3, global.devicePixelRatio || 1);
          var canvas = document.createElement('canvas');
          canvas.width = Math.round(outSize * dpr);
          canvas.height = Math.round(outSize * dpr);
          var ctx = canvas.getContext('2d');
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          if (ctx.imageSmoothingEnabled !== undefined) {
            ctx.imageSmoothingEnabled = true;
            ctx.imageSmoothingQuality = 'high';
          }
          ctx.beginPath();
          ctx.arc(outSize / 2, outSize / 2, outSize / 2, 0, Math.PI * 2);
          ctx.closePath();
          ctx.clip();
          ctx.fillStyle = (circle && circle.style.background) ? circle.style.background : '#fff';
          ctx.fillRect(0, 0, outSize, outSize);
          var ratio = outSize / m.cw;
          var drawW = nw * m.scale * ratio;
          var drawH = nh * m.scale * ratio;
          var drawX = (outSize / 2) + (m.panX * ratio) - (drawW / 2);
          var drawY = (outSize / 2) + (m.panY * ratio) - (drawH / 2);
          try {
            ctx.drawImage(drawable, drawX, drawY, drawW, drawH);
            resolve(canvas.toDataURL('image/jpeg', 0.97));
          } catch (_) { TcjErr.warn('lib/circular-hero-editor.js:241', _); }
        }

        function bakeFromImg() {
          if (!img || !img.src) {
            resolve('');
            return;
          }
          function run() { bakeDrawable(img, img.naturalWidth, img.naturalHeight); }
          if (img.complete && img.naturalWidth) run();
          else img.onload = run;
        }

        if (state.nativeFile && typeof createImageBitmap === 'function') {
          createImageBitmap(state.nativeFile).then(function (bitmap) {
            bakeDrawable(bitmap, bitmap.width, bitmap.height);
          }).catch(bakeFromImg);
          return;
        }
        bakeFromImg();
      });
    }

    bindDrag();
    if (ringWrap && typeof ResizeObserver !== 'undefined') {
      var ro = new ResizeObserver(function () { layout(); });
      ro.observe(ringWrap);
    }

    return {
      state: state,
      layout: layout,
      resetCrop: resetCrop,
      adjustZoom: adjustZoom,
      loadFromFile: loadFromFile,
      loadFromUrl: loadFromUrl,
      bake: bake,
      hasImage: function () { return state.hasImage; }
    };
  }

  global.CircularHeroEditor = { create: create };
})(typeof window !== 'undefined' ? window : global);
