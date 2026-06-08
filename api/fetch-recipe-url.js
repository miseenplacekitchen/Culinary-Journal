/**
 * Vercel serverless — fetch recipe page HTML server-side (avoids browser CORS).
 * GET /api/fetch-recipe-url?url=https://...
 */
const MAX_BYTES = 1_500_000;
const TIMEOUT_MS = 12000;

function extractJsonLdRecipe(html) {
  const re = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    try {
      const json = JSON.parse(m[1]);
      const candidates = json['@graph'] ? json['@graph'] : [json];
      for (let i = 0; i < candidates.length; i++) {
        const t = candidates[i]['@type'];
        if (t === 'Recipe' || (Array.isArray(t) && t.includes('Recipe'))) return candidates[i];
      }
    } catch (_) { /* skip invalid JSON-LD */ }
  }
  return null;
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const url = (req.query && req.query.url) ? String(req.query.url).trim() : '';
  if (!url || !/^https?:\/\//i.test(url)) {
    return res.status(400).json({ error: 'Valid http(s) url required' });
  }

  let host;
  try { host = new URL(url).hostname; } catch (_) {
    return res.status(400).json({ error: 'Invalid URL' });
  }

  const blocked = ['localhost', '127.0.0.1', '0.0.0.0'];
  if (blocked.some(b => host === b || host.endsWith('.' + b))) {
    return res.status(403).json({ error: 'URL not allowed' });
  }

  const socialHosts = ['instagram.com', 'tiktok.com', 'www.tiktok.com'];
  if (socialHosts.some(h => host === h || host.endsWith('.' + h))) {
    return res.status(422).json({
      error: 'Social media URLs cannot be imported automatically',
      platform: host.includes('instagram') ? 'Instagram' : 'TikTok',
      hint: 'Copy the recipe from the caption or comments and paste it, or use Photo scan.'
    });
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const upstream = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'TheCulinaryJournalBot/1.0 (+https://theculinaryjournal.site; recipe-import)',
        'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9'
      },
      redirect: 'follow'
    });
    clearTimeout(timer);

    if (!upstream.ok) {
      return res.status(502).json({ error: 'Could not fetch page (' + upstream.status + ')' });
    }

    const buf = await upstream.arrayBuffer();
    if (buf.byteLength > MAX_BYTES) {
      return res.status(413).json({ error: 'Page too large to import' });
    }

    const html = new TextDecoder('utf-8', { fatal: false }).decode(buf);
    const recipe = extractJsonLdRecipe(html);

    return res.status(200).json({
      ok: true,
      url,
      html: html.slice(0, MAX_BYTES),
      recipe: recipe || null,
      hasRecipe: !!recipe
    });
  } catch (e) {
    clearTimeout(timer);
    const msg = e && e.name === 'AbortError' ? 'Request timed out' : 'Fetch failed';
    return res.status(502).json({ error: msg });
  }
};
