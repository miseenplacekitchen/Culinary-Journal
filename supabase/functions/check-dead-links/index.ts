// Deploy: supabase functions deploy check-dead-links
// Auth: same CRON_SECRET as send-queued-emails
// Cron: database/sql/schedule-dead-link-cron.sql
// Prerequisites: fix-phase9-batch.sql (service_role grants)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const UA = 'TCJ-LinkChecker/1.0 (+https://www.theculinaryjournal.site)';
const RECHECK_DAYS = 7;
const BATCH_SIZE = 15;

function formatError(e: unknown): string {
  if (e && typeof e === 'object') {
    const o = e as Record<string, unknown>;
    const parts = [o.message, o.details, o.code, o.hint].filter(Boolean).map(String);
    if (parts.length) return parts.join(' | ');
  }
  return String(e);
}

async function probeUrl(url: string): Promise<'ok' | 'dead' | 'unknown'> {
  const opts = {
    redirect: 'follow' as const,
    signal: AbortSignal.timeout(8000),
    headers: { 'User-Agent': UA },
  };
  for (const method of ['HEAD', 'GET'] as const) {
    try {
      const res = await fetch(url, { ...opts, method });
      if (res.status === 404 || res.status === 410) return 'dead';
      if (res.ok || res.status < 400) return 'ok';
      if (res.status === 401 || res.status === 403) return 'ok';
      if (res.status >= 400) return 'unknown';
      return 'ok';
    } catch (_) {
      /* try GET if HEAD failed */
    }
  }
  return 'unknown';
}

Deno.serve(async (req) => {
  const CRON_SECRET = Deno.env.get('CRON_SECRET');
  if (!CRON_SECRET) {
    return new Response('CRON_SECRET not configured', { status: 500 });
  }
  const authHeader = req.headers.get('Authorization') || '';
  const provided   = authHeader.replace('Bearer ', '').trim();
  const encoder    = new TextEncoder();
  const a = encoder.encode(provided);
  const b = encoder.encode(CRON_SECRET);
  let mismatch = a.length !== b.length ? 1 : 0;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    mismatch |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  if (mismatch !== 0) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
                     ?? Deno.env.get('TCJ_SERVICE_ROLE_KEY')
                     ?? '';
    if (!supabaseUrl || !serviceKey) {
      return new Response(JSON.stringify({
        error: 'Missing database credentials (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY).'
      }), { status: 500, headers: { 'Content-Type': 'application/json' } });
    }
    const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

    const cutoffMs = Date.now() - RECHECK_DAYS * 24 * 60 * 60 * 1000;
    const { data: rows, error } = await supabase
      .from('submitted_recipes')
      .select('id, credit_url, source_link_checked_at')
      .eq('status', 'approved')
      .not('credit_url', 'is', null)
      .order('source_link_checked_at', { ascending: true, nullsFirst: true })
      .limit(60);

    if (error) throw error;
    const recipes = (rows || []).filter((row) => {
      if (!row.source_link_checked_at) return true;
      return new Date(row.source_link_checked_at).getTime() < cutoffMs;
    }).slice(0, BATCH_SIZE);

    if (!recipes.length) {
      return new Response(JSON.stringify({ checked: 0 }), { headers: { 'Content-Type': 'application/json' } });
    }

    let ok = 0, dead = 0, unknown = 0;

    for (const row of recipes) {
      const url = String(row.credit_url || '').trim();
      if (!url.startsWith('http')) {
        await supabase.from('submitted_recipes').update({
          source_link_status: 'unknown',
          source_link_checked_at: new Date().toISOString(),
        }).eq('id', row.id);
        unknown++;
        continue;
      }
      const status = await probeUrl(url);
      await supabase.from('submitted_recipes').update({
        source_link_status: status,
        source_link_checked_at: new Date().toISOString(),
      }).eq('id', row.id);
      if (status === 'ok') ok++;
      else if (status === 'dead') dead++;
      else unknown++;
    }

    return new Response(JSON.stringify({ checked: recipes.length, ok, dead, unknown }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: formatError(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
