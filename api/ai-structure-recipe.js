/**
 * Vercel serverless — structure social/video recipe text with Claude.
 * POST /api/ai-structure-recipe
 * Body: { caption, transcript?, url?, platform?, pageTitle?, creditName?, extraText? }
 *
 * Requires ANTHROPIC_API_KEY in Vercel environment variables.
 */
const AiRecipeStructure = require('../lib/ai-recipe-structure.js');

const MODEL = process.env.ANTHROPIC_RECIPE_MODEL || 'claude-sonnet-4-20250514';
const MAX_MS = 55000;

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'POST required' });
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(503).json({
      ok: false,
      error: 'AI recipe structuring is not configured (missing ANTHROPIC_API_KEY).',
      fetchStatus: 'ai-not-configured'
    });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  body = body || {};

  const caption = String(body.caption || '').trim();
  const transcript = String(body.transcript || '').trim();
  const extraText = String(body.extraText || '').trim();
  if (!caption && !transcript && !extraText) {
    return res.status(400).json({
      ok: false,
      error: 'Provide caption, transcript, or extraText to structure.',
      fetchStatus: 'empty-input'
    });
  }

  const input = {
    url: body.url || '',
    platform: body.platform || 'Social',
    pageTitle: body.pageTitle || '',
    creditName: body.creditName || '',
    caption: caption,
    transcript: transcript,
    extraText: extraText
  };

  const messages = AiRecipeStructure.buildStructureMessages(input);
  const controller = new AbortController();
  const timer = setTimeout(function () { controller.abort(); }, MAX_MS);

  try {
    const upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 8192,
        temperature: 0.2,
        system: messages.system,
        messages: [{ role: 'user', content: messages.user }]
      })
    });
    clearTimeout(timer);

    if (!upstream.ok) {
      const errText = await upstream.text();
      return res.status(502).json({
        ok: false,
        error: 'AI structuring failed (' + upstream.status + ')',
        fetchStatus: 'ai-error',
        detail: errText.slice(0, 500)
      });
    }

    const data = await upstream.json();
    const textBlock = (data.content || []).find(function (b) { return b.type === 'text'; });
    const rawJson = AiRecipeStructure.parseJsonFromModelText(textBlock && textBlock.text);
    if (!rawJson) {
      return res.status(502).json({
        ok: false,
        error: 'AI returned invalid JSON. Try again or paste the recipe manually.',
        fetchStatus: 'ai-parse-error'
      });
    }

    const normalized = AiRecipeStructure.normalizeAiRecipe(rawJson, input);
    if (!normalized.ok) {
      return res.status(422).json({
        ok: false,
        error: 'AI could not produce enough ingredients and steps. Add more source text or edit manually.',
        fetchStatus: 'ai-incomplete',
        partial: normalized
      });
    }

    return res.status(200).json({
      ok: true,
      fetchStatus: 'ok',
      extractor: 'ai-social',
      structure_version: AiRecipeStructure.STRUCTURE_VERSION,
      model: MODEL,
      platform: input.platform,
      warnings: (normalized.recipe.warnings || []).concat(
        normalized.recipe.inferred_fields.length
          ? ['AI filled in missing details — verify every quantity and step against the original video.']
          : []
      ),
      inferred_fields: normalized.recipe.inferred_fields,
      importQuality: {
        confidence_score: normalized.confidence,
        review_required: true,
        enrich_allowed: normalized.enrich_allowed
      },
      structured: normalized.recipe,
      ingCount: normalized.ingCount,
      stepCount: normalized.stepCount
    });
  } catch (e) {
    clearTimeout(timer);
    const timedOut = e && e.name === 'AbortError';
    return res.status(502).json({
      ok: false,
      error: timedOut ? 'AI structuring timed out — try again.' : 'AI structuring failed.',
      fetchStatus: timedOut ? 'ai-timeout' : 'ai-failed'
    });
  }
};
