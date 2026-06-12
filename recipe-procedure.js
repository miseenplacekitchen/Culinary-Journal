/**
 * Shared procedure/method parsing for admin review + public recipe page.
 */
window.RecipeProcedure = (function () {
  function stepText(step) {
    if (typeof step === 'string') return step.trim();
    if (!step || typeof step !== 'object') return '';
    if (step.multiple && Array.isArray(step.items)) {
      return step.items.map(function (s) { return String(s || '').trim(); }).filter(Boolean).join('\n');
    }
    var title = (step.title || '').trim();
    var text = (step.text || step.step || '').trim();
    if (title && text) return title + ': ' + text;
    return title || text;
  }

  function parseBlocks(method) {
    if (!method) return [];
    try {
      var blocks = typeof method === 'string' ? JSON.parse(method) : method;
      if (!Array.isArray(blocks)) return [];
      return blocks.map(function (block) {
        if (!block || typeof block !== 'object') return { section: '', steps: [] };
        var steps = block.steps;
        if (!Array.isArray(steps)) steps = [];
        return {
          section: block.section || block.section_name || block.title || '',
          steps: steps
        };
      });
    } catch (_) { TcjErr.warn('recipe-procedure.js:31', _); }
  }

  function stepLines(steps) {
    var out = [];
    (steps || []).forEach(function (step) {
      if (step && typeof step === 'object' && step.multiple && Array.isArray(step.items)) {
        step.items.forEach(function (item) {
          var t = String(item || '').trim();
          if (t) out.push(t);
        });
        return;
      }
      var line = stepText(step);
      if (line) {
        line.split('\n').forEach(function (part) {
          part = part.trim();
          if (part) out.push(part);
        });
      }
    });
    return out;
  }

  return { stepText: stepText, parseBlocks: parseBlocks, stepLines: stepLines };
})();
