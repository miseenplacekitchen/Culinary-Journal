/**
 * POST /api/admin-agent-review
 * Body: { recipe_id: "uuid" } OR { bulk: true, limit: 10 }
 * Auth: Bearer session token (admin only)
 * Env: GROQ_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 */
const {
  flattenRecipeForPrompt,
  buildSavePayload,
  assessAgentOutcome,
  callGroqAgent,
} = require('../lib/admin-agent-review-core.js');

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://kzywmodvfbyexqgipcjt.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const GROQ_KEY = process.env.GROQ_API_KEY;
// Public anon key (same as supabase-config.js) — fallback if Vercel env name typo
const ANON_KEY_FALLBACK = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eXdtb2R2ZmJ5ZXhxZ2lwY2p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2Mzc0NjcsImV4cCI6MjA5NTIxMzQ2N30.hkGIGx-IYrVtyTQRg6eduUAVQKnkxJHUd9KM_us6_ZM';
const ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ANON_KEY_FALLBACK;

async function sbFetch(path, options, key, userJwt) {
  const bearer = userJwt || key;
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...options,
    headers: {
      apikey: key,
      Authorization: `Bearer ${bearer}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  return res;
}

async function assertAdmin(userToken) {
  const anonKey = ANON_KEY;
  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${userToken}` },
  });
  if (!userRes.ok) throw new Error('Not signed in — refresh the page and log in again');
  const user = await userRes.json();
  if (!user?.id) throw new Error('Not signed in');

  // Same check the dashboard uses: is_admin() RPC with your session token
  const adminRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/is_admin`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${userToken}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
  });
  if (!adminRes.ok) {
    const detail = await adminRes.text().catch(() => '');
    throw new Error('Could not verify admin' + (detail ? ' — try logging out and back in' : ''));
  }
  const isAdmin = await adminRes.json();
  if (!isAdmin) throw new Error('Admin access required for this account');
  return user.id;
}

async function fetchRecipe(recipeId) {
  const res = await sbFetch(
    `/rest/v1/submitted_recipes?id=eq.${encodeURIComponent(recipeId)}&select=*`,
    { method: 'GET' },
    SERVICE_KEY,
  );
  if (!res.ok) throw new Error('Recipe fetch failed');
  const rows = await res.json();
  return rows?.[0] || null;
}

async function saveRecipeReview(recipeId, payload) {
  const res = await sbFetch(
    '/rest/v1/rpc/admin_save_recipe_review',
    {
      method: 'POST',
      body: JSON.stringify({ p_id: recipeId, p_data: payload }),
    },
    SERVICE_KEY,
  );
  if (!res.ok) {
    const t = await res.text();
    throw new Error(t || 'Save failed');
  }
}

async function updateProcedureFlags(recipeId) {
  await sbFetch(
    `/rest/v1/submitted_recipes?id=eq.${encodeURIComponent(recipeId)}`,
    {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({
        procedure_rewritten: true,
        import_extractor: 'admin-agent-review-v1',
      }),
    },
    SERVICE_KEY,
  );
}

async function reviewOneRecipe(recipeId) {
  const row = await fetchRecipe(recipeId);
  if (!row) throw new Error('Recipe not found');
  if (row.status !== 'pending') throw new Error('Only pending recipes can be agent-reviewed');

  const sourceText = flattenRecipeForPrompt(row);
  const structured = await callGroqAgent(sourceText, GROQ_KEY);
  const payload = buildSavePayload(structured, row);

  await saveRecipeReview(recipeId, payload);
  await updateProcedureFlags(recipeId);

  const assessment = assessAgentOutcome(structured, row, payload);

  return {
    id: recipeId,
    recipe_name: payload.recipe_name,
    reject_recommended: !!structured.reject_recommended,
    reject_reason: structured.reject_reason || '',
    agent_notes: structured.agent_notes || '',
    outcome: assessment.outcome,
    auto_approve: assessment.auto_approve,
    needs_manual: assessment.needs_manual,
    assessment_reasons: assessment.reasons,
    ok: true,
  };
}

async function listPending(limit) {
  const res = await sbFetch(
    `/rest/v1/submitted_recipes?status=eq.pending&order=submitted_at.asc&limit=${limit}&select=id,recipe_name`,
    { method: 'GET' },
    SERVICE_KEY,
  );
  if (!res.ok) throw new Error('Could not list pending');
  return res.json();
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'POST only' });
  }
  if (!SERVICE_KEY || !GROQ_KEY) {
    return res.status(503).json({
      ok: false,
      error: 'Server missing GROQ_API_KEY or SUPABASE_SERVICE_ROLE_KEY in hosting env',
    });
  }

  const auth = req.headers.authorization || '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ ok: false, error: 'Sign in required' });

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  body = body || {};

  try {
    await assertAdmin(token);
  } catch (e) {
    return res.status(403).json({ ok: false, error: e.message });
  }

  try {
    if (body.bulk) {
      const limit = Math.min(Math.max(parseInt(body.limit, 10) || 10, 1), 25);
      const pending = await listPending(limit);
      const results = [];
      let ok = 0;
      let failed = 0;
      for (const row of pending) {
        try {
          const r = await reviewOneRecipe(row.id);
          results.push(r);
          ok += 1;
        } catch (e) {
          failed += 1;
          results.push({
            id: row.id,
            recipe_name: row.recipe_name,
            ok: false,
            error: e.message,
          });
          if (String(e.message).includes('429') || String(e.status) === '429') break;
        }
      }
      return res.status(200).json({ ok: true, bulk: true, processed: results.length, succeeded: ok, failed, results });
    }

    const recipeId = body.recipe_id;
    if (!recipeId) {
      return res.status(400).json({ ok: false, error: 'recipe_id required' });
    }
    const result = await reviewOneRecipe(recipeId);
    return res.status(200).json(result);
  } catch (e) {
    const status = e.status === 429 ? 429 : 500;
    return res.status(status).json({ ok: false, error: e.message || String(e) });
  }
};
