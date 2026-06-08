/**
 * Vercel serverless — fetch recipe page HTML server-side (avoids browser CORS).
 * GET /api/fetch-recipe-url?url=https://...
 */
const MAX_BYTES = 1_500_000;
const TIMEOUT_MS = 14000;

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

function decodeHtmlEntities(s) {
  return String(s || '')
    .replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/\\n/g, '\n')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&#39;/g, "'").replace(/&quot;/g, '"');
}

function looksLikeStructuredRecipe(text) {
  if (!text || text.length < 40) return false;
  const t = text.toLowerCase();
  if (/\b(ingredients?|method|instructions?|directions?|serves|prep|cook)\b/.test(t)) return true;
  const lines = text.split('\n').filter(l => l.trim());
  const withQty = lines.filter(l => /^\s*[\d\u00BC-\u00BE\/]/.test(l) || /\b(tsp|tbsp|cup|g|ml|oz|lb)\b/i.test(l)).length;
  const numbered = lines.filter(l => /^\s*\d+[\.\)]\s/.test(l)).length;
  return withQty >= 3 || numbered >= 3;
}

function extractSocialCaption(html, host) {
  const candidates = [];
  const ogRe = [
    /property=["']og:description["'][^>]*content=["']([^"']+)["']/i,
    /content=["']([^"']+)["'][^>]*property=["']og:description["']/i,
    /name=["']description["'][^>]*content=["']([^"']+)["']/i
  ];
  ogRe.forEach(re => {
    const m = html.match(re);
    if (m && m[1]) candidates.push(decodeHtmlEntities(m[1]));
  });

  const jsonPatterns = [
    /"accessibility_caption"\s*:\s*"((?:\\.|[^"\\])*)"/,
    /"edge_media_to_caption"\s*:\s*\{\s*"edges"\s*:\s*\[\s*\{\s*"node"\s*:\s*\{\s*"text"\s*:\s*"((?:\\.|[^"\\])*)"/,
    /"caption"\s*:\s*"((?:\\.|[^"\\]){20,3000})"/
  ];
  jsonPatterns.forEach(re => {
    const m = html.match(re);
    if (m && m[1]) candidates.push(decodeHtmlEntities(m[1]));
  });

  const unique = [...new Set(candidates.map(c => c.trim()).filter(c => c.length > 15))];
  unique.sort((a, b) => b.length - a.length);
  const caption = unique[0] || '';
  const platform = host.includes('instagram') ? 'Instagram'
    : host.includes('tiktok') ? 'TikTok'
    : host.includes('facebook') ? 'Facebook' : 'Social';
  return {
    caption: caption.slice(0, 8000),
    platform,
    hasRecipeStructure: looksLikeStructuredRecipe(caption)
  };
}

async function tryInstagramOembed(url) {
  try {
    const oembedUrl = 'https://api.instagram.com/oembed?url=' + encodeURIComponent(url);
    const res = await fetch(oembedUrl, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return null;
    const data = await res.json();
    const title = (data.title || '').trim();
    const author = (data.author_name || '').trim();
    if (title && title.length > 20) {
      return { caption: title, platform: 'Instagram', hasRecipeStructure: looksLikeStructuredRecipe(title) };
    }
    if (author) return { caption: 'Post by ' + author, platform: 'Instagram', hasRecipeStructure: false };
  } catch (_) { /* oembed optional */ }
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

  const isSocial = /instagram\.com|tiktok\.com|facebook\.com/i.test(host);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const upstream = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; TheCulinaryJournalBot/1.0; +https://theculinaryjournal.site)',
        'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9'
      },
      redirect: 'follow'
    });
    clearTimeout(timer);

    if (!upstream.ok) {
      if (isSocial && host.includes('instagram')) {
        const oembed = await tryInstagramOembed(url);
        if (oembed && oembed.caption) {
          return res.status(200).json({ ok: true, url, social: true, ...oembed, html: '', recipe: null });
        }
      }
      return res.status(502).json({ error: 'Could not fetch page (' + upstream.status + ')' });
    }

    const buf = await upstream.arrayBuffer();
    if (buf.byteLength > MAX_BYTES) {
      return res.status(413).json({ error: 'Page too large to import' });
    }

    const html = new TextDecoder('utf-8', { fatal: false }).decode(buf);
    const recipe = extractJsonLdRecipe(html);

    if (isSocial) {
      let social = extractSocialCaption(html, host);
      if ((!social.caption || social.caption.length < 30) && host.includes('instagram')) {
        const oembed = await tryInstagramOembed(url);
        if (oembed && oembed.caption && oembed.caption.length > (social.caption || '').length) social = oembed;
      }
      return res.status(200).json({
        ok: true,
        url,
        social: true,
        html: html.slice(0, 50000),
        recipe: recipe || null,
        caption: social.caption || '',
        platform: social.platform,
        hasRecipeStructure: social.hasRecipeStructure || !!recipe
      });
    }

    return res.status(200).json({
      ok: true,
      url,
      html: html.slice(0, MAX_BYTES),
      recipe: recipe || null,
      hasRecipe: !!recipe
    });
  } catch (e) {
    clearTimeout(timer);
    if (isSocial && host.includes('instagram')) {
      const oembed = await tryInstagramOembed(url);
      if (oembed && oembed.caption) {
        return res.status(200).json({ ok: true, url, social: true, ...oembed, html: '', recipe: null });
      }
    }
    const msg = e && e.name === 'AbortError' ? 'Request timed out' : 'Fetch failed';
    return res.status(502).json({ error: msg });
  }
};
