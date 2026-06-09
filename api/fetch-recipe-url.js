/**
 * Vercel serverless — fetch recipe page HTML server-side (avoids browser CORS).
 * GET /api/fetch-recipe-url?url=https://...
 */
const RecipeImportCore = require('../lib/recipe-import-core.js');
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

function htmlFragmentToText(fragment) {
  if (!fragment) return '';
  return fragment
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|h[1-6]|li|tr|section|article)>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&#8211;|&ndash;/gi, '–')
    .replace(/&#8212;|&mdash;/gi, '—')
    .replace(/&#8220;|&ldquo;/gi, '"')
    .replace(/&#8221;|&rdquo;/gi, '"')
    .replace(/&#8216;|&lsquo;/gi, "'")
    .replace(/&#8217;|&rsquo;/gi, "'")
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
}

function extractArticleHtml(html) {
  if (!html) return '';
  const markers = [
    /<div[^>]*class="[^"]*\bentry-content\b[^"]*"[^>]*>([\s\S]*)/i,
    /<div[^>]*class="[^"]*\bwp-block-post-content\b[^"]*"[^>]*>([\s\S]*)/i,
    /<div[^>]*class="[^"]*\bpost-content\b[^"]*"[^>]*>([\s\S]*)/i,
    /<article[^>]*>([\s\S]*?)<\/article>/i,
    /<div[^>]*itemprop=["']articleBody["'][^>]*>([\s\S]*)/i,
    /<main[^>]*>([\s\S]*?)<\/main>/i
  ];
  for (let i = 0; i < markers.length; i++) {
    const m = html.match(markers[i]);
    if (!m || !m[1] || m[1].length < 200) continue;
    let chunk = m[1];
    const stops = [
      /<footer\b/i, /class="[^"]*\bcomments-area\b/i, /id=["']comments["']/i,
      /class="[^"]*\bsharedaddy\b/i, /class="[^"]*\bjp-relatedposts\b/i,
      /class="[^"]*\bpost-navigation\b/i, /Share this:/i, /Leave a Reply/i,
      /Recent Posts/i, /Loading Comments/i
    ];
    let cut = chunk.length;
    stops.forEach(re => {
      const idx = chunk.search(re);
      if (idx > 150 && idx < cut) cut = idx;
    });
    chunk = chunk.slice(0, cut);
    if (chunk.length > 200) return chunk;
  }
  return '';
}

function extractPageTitle(html) {
  const og = html.match(/property=["']og:title["'][^>]*content=["']([^"']+)["']/i)
    || html.match(/content=["']([^"']+)["'][^>]*property=["']og:title["']/i);
  if (og && og[1]) {
    return decodeHtmlEntities(og[1]).replace(/\s*[-|–—]\s*[^-|–—]+$/, '').trim();
  }
  const h1 = html.match(/<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1 && h1[1]) return htmlFragmentToText(h1[1]).trim();
  return '';
}

const BLOG_STOP_LINES = [
  /^share this:/i, /^print\s*\(/i, /^email a link/i, /^like this:/i, /^loading\.?\.?\.?$/i,
  /^one response to/i, /^leave a reply/i, /^cancel reply/i, /^recent posts/i, /^categories$/i,
  /^trending$/i, /^subscribe to our newsletters/i, /^discover more from/i,
  /^loading comments/i, /^write a comment/i, /^type your email/i, /^continue reading/i,
  /^author$/i, /^written by$/i, /^facebook$/i, /^instagram$/i, /^youtube$/i, /^search$/i,
  /^skip to content/i, /^about me$/i, /^recipe request$/i, /^copyright$/i, /^subscribe$/i,
  /^happy cooking/i, /^with love$/i,
  /food advertisements by/i, /^\(?\s*\d+\s*reviews?\s*\)?\.?$/i,
  /^check here for more/i, /^sharing is caring/i, /^bon appetit/i,
  /^related posts?/i, /^\d+\s+comments?$/i
];

const BLOG_NAV_LINES = /^(beef|chicken|mutton|egg|rice|bread|breakfast|cakes|snacks|soups|drinks|sea food|pickles|sweets|useful tips|my cooking|post delivery|healthy salads|indian vegetable|kerala sadya|spice mixes|chutneys|curryworld menu|biriyani|chinese dishes)/i;

function trimBlogRecipeText(text) {
  if (!text) return '';
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  let start = 0;
  let ingIdx = lines.findIndex(l => /^ingredients?\s*:?\s*$/i.test(l.replace(/[\u00A0\u200B]/g, ' ').trim()));
  if (ingIdx >= 0) {
    start = ingIdx;
  } else {
    start = lines.findIndex(l => l.length > 10 && l.length < 90 && !BLOG_NAV_LINES.test(l) && !BLOG_STOP_LINES.some(re => re.test(l)));
    if (start < 0) start = 0;
  }
  let end = lines.length;
  for (let i = start; i < lines.length; i++) {
    if (BLOG_STOP_LINES.some(re => re.test(lines[i]))) { end = i; break; }
    if (/^share on /i.test(lines[i])) { end = i; break; }
  }
  return lines.slice(start, end).join('\n');
}

function extractArticleText(html) {
  const fragment = extractArticleHtml(html);
  const text = fragment ? htmlFragmentToText(fragment) : '';
  const trimmed = text.length > 150 ? trimBlogRecipeText(text) : trimBlogRecipeText(htmlFragmentToText(html.slice(0, 120000)));
  const seg = RecipeImportCore.segmentRecipeImportText(trimmed);
  return seg.normalizedText || RecipeImportCore.normalizeRecipeImportText(trimmed);
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

    const articleText = extractArticleText(html);
    const pageTitle = extractPageTitle(html);
    return res.status(200).json({
      ok: true,
      url,
      html: html.slice(0, MAX_BYTES),
      recipe: recipe || null,
      hasRecipe: !!recipe,
      articleText: articleText || '',
      parserVersion: RecipeImportCore.PARSER_VERSION,
      pageTitle: pageTitle || '',
      hasArticleText: articleText.length > 80
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
