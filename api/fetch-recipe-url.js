/**
 * Vercel serverless — fetch recipe page HTML server-side (avoids browser CORS).
 * GET /api/fetch-recipe-url?url=https://...
 */
const RecipeImportCore = require('../lib/recipe-import-core.js');
const RecipeImportExtract = require('../lib/recipe-import-extract.js');
const MAX_BYTES = 1_500_000;
const TIMEOUT_MS = 14000;

function looksLikeStructuredRecipe(text) {
  if (RecipeImportCore && RecipeImportCore.looksLikeStructuredRecipe) {
    return RecipeImportCore.looksLikeStructuredRecipe(text);
  }
  return false;
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
    if (m && m[1]) candidates.push(RecipeImportExtract.decodeHtmlEntities(m[1]));
  });

  const jsonPatterns = [
    /"accessibility_caption"\s*:\s*"((?:\\.|[^"\\])*)"/,
    /"edge_media_to_caption"\s*:\s*\{\s*"edges"\s*:\s*\[\s*\{\s*"node"\s*:\s*\{\s*"text"\s*:\s*"((?:\\.|[^"\\])*)"/,
    /"caption"\s*:\s*"((?:\\.|[^"\\]){20,3000})"/
  ];
  jsonPatterns.forEach(re => {
    const m = html.match(re);
    if (m && m[1]) candidates.push(RecipeImportExtract.decodeHtmlEntities(m[1]));
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

function extractPageTitle(html) {
  const og = html.match(/property=["']og:title["'][^>]*content=["']([^"']+)["']/i)
    || html.match(/content=["']([^"']+)["'][^>]*property=["']og:title["']/i);
  if (og && og[1]) {
    return RecipeImportExtract.decodeHtmlEntities(og[1]).replace(/\s*[-|–—]\s*[^-|–—]+$/, '').trim();
  }
  const h1 = html.match(/<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1 && h1[1]) return RecipeImportExtract.htmlFragmentToText(h1[1]).trim();
  return '';
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
  } catch (_) { TcjErr.ignore(_); }
  return null;
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const url = (req.query && req.query.url) ? String(req.query.url).trim() : '';
  if (!url || !/^https?:\/\//i.test(url)) {
    return res.status(400).json({ ok: false, error: 'Valid http(s) url required', fetchStatus: 'invalid-url' });
  }

  let host;
  try { host = new URL(url).hostname; } catch (_) {
    return res.status(400).json({ ok: false, error: 'Invalid URL', fetchStatus: 'invalid-url' });
  }

  if (RecipeImportExtract.isLikelyNonRecipeUrl(url)) {
    return res.status(400).json({
      ok: false,
      error: 'That URL looks like a homepage or category page, not a single recipe. Paste a direct recipe link.',
      fetchStatus: 'non-recipe-url',
      host: RecipeImportExtract.resolveHostStrategy(host).host
    });
  }

  const blocked = ['localhost', '127.0.0.1', '0.0.0.0'];
  if (blocked.some(b => host === b || host.endsWith('.' + b))) {
    return res.status(403).json({ ok: false, error: 'URL not allowed', fetchStatus: 'blocked' });
  }

  const hostInfo = RecipeImportExtract.resolveHostStrategy(host);
  const isSocial = hostInfo.strategy === 'social';

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
          return res.status(200).json({ ok: true, url, social: true, ...oembed, html: '', recipe: null, fetchStatus: 'ok' });
        }
      }
      return res.status(502).json({
        ok: false,
        error: RecipeImportExtract.getFetchErrorMessage(upstream.status, host),
        fetchStatus: upstream.status === 403 || upstream.status === 402 ? 'bot-blocked' : 'http-error',
        httpStatus: upstream.status,
        host: hostInfo.host,
        strategy: hostInfo.strategy
      });
    }

    const buf = await upstream.arrayBuffer();
    if (buf.byteLength > MAX_BYTES) {
      return res.status(413).json({ ok: false, error: 'Page too large to import', fetchStatus: 'too-large' });
    }

    const html = new TextDecoder('utf-8', { fatal: false }).decode(buf);
    if (!html || html.length < 200) {
      return res.status(502).json({
        ok: false,
        error: 'Empty response from recipe site. Paste the recipe text manually.',
        fetchStatus: 'empty-body',
        host: hostInfo.host
      });
    }

    const recipe = RecipeImportExtract.extractJsonLdRecipe(html);

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
        hasRecipeStructure: social.hasRecipeStructure || !!recipe,
        fetchStatus: 'ok',
        host: hostInfo.host,
        strategy: hostInfo.strategy,
        parserVersion: RecipeImportCore.PARSER_VERSION,
        extractorVersion: RecipeImportExtract.EXTRACTOR_VERSION
      });
    }

    const pageTitle = extractPageTitle(html);
    const payload = RecipeImportExtract.buildImportPayload({
      html: html,
      host: host,
      url: url,
      recipe: recipe,
      pageTitle: pageTitle,
      fetchStatus: 'ok'
    });

    return res.status(200).json({
      ...payload,
      html: html.slice(0, MAX_BYTES),
      hasRecipe: !!recipe,
      strategy: hostInfo.strategy,
      family: hostInfo.family
    });
  } catch (e) {
    clearTimeout(timer);
    if (isSocial && host.includes('instagram')) {
      const oembed = await tryInstagramOembed(url);
      if (oembed && oembed.caption) {
        return res.status(200).json({ ok: true, url, social: true, ...oembed, html: '', recipe: null, fetchStatus: 'ok' });
      }
    }
    const timedOut = e && e.name === 'AbortError';
    return res.status(502).json({
      ok: false,
      error: timedOut ? 'Request timed out — try again or paste the recipe manually.' : 'Fetch failed — paste the recipe text manually.',
      fetchStatus: timedOut ? 'timeout' : 'fetch-failed',
      host: hostInfo.host,
      strategy: hostInfo.strategy
    });
  }
};
