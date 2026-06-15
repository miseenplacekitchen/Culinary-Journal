/**
 * POST /api/admin-agent-review
 * Body: { recipe_id: "uuid" } OR { bulk: true, limit: 10 }
 * Auth: Bearer session token (admin only)
 * Env: SUPABASE_SERVICE_ROLE_KEY (Groq NOT used — reels/video only)
 */
const {
  buildSavePayload,
  assessAgentOutcome,
} = require('../lib/admin-agent-review-core.js');
const { polishMechanically, loadIngredientIndex } = require('../lib/admin-mechanical-polish.js');

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://kzywmodvfbyexqgipcjt.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
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
  const patch = {
    recipe_name: payload.recipe_name,
    native_title: payload.native_title || '',
    category: payload.category,
    introduction: payload.introduction || '',
    prep_time_minutes: payload.prep_time_minutes ?? 0,
    cook_time_minutes: payload.cook_time_minutes ?? 0,
    servings: payload.servings ?? 1,
    spice_level: payload.spice_level,
    sweet_level: payload.sweet_level,
    origin_continent: payload.origin_continent || '',
    origin_country: payload.origin_country || '',
    origin_state: payload.origin_state || '',
    origin_locality: payload.origin_locality || '',
    source_type: payload.source_type,
    credit_name: payload.credit_name || '',
    credit_handle: payload.credit_handle || '',
    credit_url: payload.credit_url || '',
    ingredients: payload.ingredients,
    method: payload.method,
    cooking_notes: payload.cooking_notes || '',
    procedure_rewritten: true,
    import_extractor: 'admin-mechanical-v1',
  };
  if (payload.unknown_ingredients?.length) {
    patch.unknown_ingredients = payload.unknown_ingredients;
  }
  const res = await sbFetch(
    `/rest/v1/submitted_recipes?id=eq.${encodeURIComponent(recipeId)}`,
    {
      method: 'PATCH',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(patch),
    },
    SERVICE_KEY,
  );
  if (!res.ok) {
    const t = await res.text();
    let msg = t || 'Save failed';
    try {
      const j = JSON.parse(t);
      if (j.message) msg = j.message;
    } catch (_) {}
    throw new Error(msg);
  }
}

let cachedIngredientIndex = null;

async function getIngredientIndex() {
  if (!cachedIngredientIndex) {
    cachedIngredientIndex = await loadIngredientIndex(sbFetch, SERVICE_KEY);
  }
  return cachedIngredientIndex;
}

async function reviewOneRecipe(recipeId, userToken) {
  const row = await fetchRecipe(recipeId);
  if (!row) throw new Error('Recipe not found');
  if (row.status !== 'pending') throw new Error('Only pending recipes can be agent-reviewed');

  const { canonicalMap, knownLower } = await getIngredientIndex();
  const structured = polishMechanically(row, canonicalMap, knownLower);
  const payload = buildSavePayload(structured, row);
  if (structured.unknown_ingredients?.length) {
    payload.unknown_ingredients = structured.unknown_ingredients;
  }

  await saveRecipeReview(recipeId, payload);

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
    info_notes: assessment.info_notes || [],
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
  if (!SERVICE_KEY) {
    return res.status(503).json({
      ok: false,
      error: 'Server missing SUPABASE_SERVICE_ROLE_KEY in hosting env',
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
          const r = await reviewOneRecipe(row.id, token);
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
          if (String(e.message).includes('429')) break;
        }
      }
      return res.status(200).json({ ok: true, bulk: true, processed: results.length, succeeded: ok, failed, results });
    }

    const recipeId = body.recipe_id;
    if (!recipeId) {
      return res.status(400).json({ ok: false, error: 'recipe_id required' });
    }
    const result = await reviewOneRecipe(recipeId, token);
    return res.status(200).json(result);
  } catch (e) {
    const status = e.status === 429 ? 429 : 500;
    return res.status(status).json({ ok: false, error: e.message || String(e) });
  }
};
