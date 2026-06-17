/**
 * SSRF guards for server-side URL fetch (Vercel / Node).
 * Resolve DNS, reject private/link-local/loopback, follow redirects manually with re-check.
 */
const dns = require('dns').promises;
const net = require('net');

const BLOCKED_HOSTNAMES = new Set([
  'localhost',
  'metadata.google.internal',
  'metadata.goog'
]);

function isPrivateOrReservedIp(ip) {
  if (net.isIPv4(ip)) {
    const o = ip.split('.').map(Number);
    if (o[0] === 0) return true;
    if (o[0] === 10) return true;
    if (o[0] === 127) return true;
    if (o[0] === 169 && o[1] === 254) return true;
    if (o[0] === 192 && o[1] === 168) return true;
    if (o[0] === 172 && o[1] >= 16 && o[1] <= 31) return true;
    if (o[0] === 100 && o[1] >= 64 && o[1] <= 127) return true;
    if (o[0] === 198 && (o[1] === 18 || o[1] === 19)) return true;
    if (o[0] >= 224) return true;
    return false;
  }
  if (net.isIPv6(ip)) {
    const n = ip.toLowerCase();
    if (n === '::1' || n === '::') return true;
    if (n.startsWith('fc') || n.startsWith('fd')) return true;
    if (n.startsWith('fe80')) return true;
    if (n.startsWith('::ffff:')) {
      const v4 = n.slice(7);
      if (net.isIPv4(v4)) return isPrivateOrReservedIp(v4);
    }
    return false;
  }
  return true;
}

function normalizeHostname(host) {
  let h = String(host || '').toLowerCase().replace(/\.$/, '');
  if (h.startsWith('[') && h.endsWith(']')) h = h.slice(1, -1);
  return h;
}

function hostnameBlocked(host) {
  const h = normalizeHostname(host);
  if (!h) return true;
  if (BLOCKED_HOSTNAMES.has(h)) return true;
  if (h.endsWith('.localhost') || h.endsWith('.local')) return true;
  if (net.isIP(h)) return isPrivateOrReservedIp(h);
  return false;
}

async function assertPublicHttpUrl(urlStr) {
  let u;
  try {
    u = new URL(urlStr);
  } catch (_) {
    throw new Error('Invalid URL');
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') {
    throw new Error('URL must be http or https');
  }
  if (u.username || u.password) throw new Error('URL credentials not allowed');
  const host = u.hostname;
  if (hostnameBlocked(host)) throw new Error('URL not allowed');

  if (net.isIP(host)) {
    if (isPrivateOrReservedIp(host)) throw new Error('URL not allowed');
    return u.href;
  }

  let records;
  try {
    records = await dns.lookup(host, { all: true, verbatim: true });
  } catch (_) {
    throw new Error('Could not resolve host');
  }
  if (!records || !records.length) throw new Error('Could not resolve host');
  for (const rec of records) {
    if (isPrivateOrReservedIp(rec.address)) throw new Error('URL not allowed');
  }
  return u.href;
}

async function safeFetch(urlStr, options, maxRedirects) {
  const limit = maxRedirects == null ? 5 : maxRedirects;
  let current = urlStr;
  for (let hop = 0; hop <= limit; hop++) {
    current = await assertPublicHttpUrl(current);
    const res = await fetch(current, Object.assign({}, options || {}, { redirect: 'manual' }));
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      if (!loc || hop >= limit) throw new Error('Too many redirects');
      current = new URL(loc, current).href;
      continue;
    }
    return res;
  }
  throw new Error('Too many redirects');
}

async function verifySupabaseSession(req) {
  const auth = req.headers && req.headers.authorization;
  const token = auth && String(auth).startsWith('Bearer ') ? String(auth).slice(7) : '';
  if (!token) return { ok: false, status: 401, error: 'Sign in required' };

  const supaUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '';
  const supaKey = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';
  if (!supaUrl || !supaKey) {
    return { ok: false, status: 503, error: 'Auth verification not configured' };
  }

  const res = await fetch(supaUrl.replace(/\/$/, '') + '/auth/v1/user', {
    headers: { apikey: supaKey, Authorization: 'Bearer ' + token }
  });
  if (!res.ok) return { ok: false, status: 401, error: 'Invalid or expired session' };
  return { ok: true, token };
}

module.exports = {
  assertPublicHttpUrl,
  safeFetch,
  verifySupabaseSession,
  isPrivateOrReservedIp
};
