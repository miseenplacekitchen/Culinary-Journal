/**
 * Admin Agent Review — save payload + quality gates for mechanical polish.
 * Used by api/admin-agent-review.js (server) only. No LLM / no Groq.
 */

const TCJ_CATEGORIES = [
  'Rise & Shine', 'The Evening Table', 'Garden & Earth', 'Meat & Fire',
  'Ocean & River', 'Slow & Soulful', 'Grains & Comfort', 'Breads & Bakes',
  'Sweet Serenades', 'Sips & Stories', 'Preserved & Cherished', 'Feast Days',
  'Little Ones', 'Nourish & Heal',
];

const SPICE_LEVELS = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'];
const SWEET_LEVELS = ['Not Applicable', 'Subtly Sweet', 'Lightly Sweet', 'Sweet', 'Very Sweet', 'Extremely Sweet'];

function coerceInt(v, fallback) {
  if (v === null || v === undefined || v === '') return fallback;
  const n = parseInt(String(v).replace(/\D/g, ''), 10);
  return Number.isFinite(n) ? Math.max(0, n) : fallback;
}

function pickChoice(value, allowed, fallback) {
  if (!value) return fallback;
  const t = String(value).trim();
  if (allowed.includes(t)) return t;
  const lower = t.toLowerCase();
  for (const a of allowed) {
    if (a.toLowerCase() === lower) return a;
  }
  return fallback;
}

const BOILERPLATE_INTROS = [
  'Imported from Personal book collection.',
  'Imported from personal book collection.',
];

function parseJsonField(val, fallback) {
  if (val == null) return fallback;
  if (typeof val === 'object') return val;
  try {
    return JSON.parse(val);
  } catch (_) {
    return fallback;
  }
}

function countIngredientRows(ingredients) {
  const sections = parseJsonField(ingredients, []);
  if (!Array.isArray(sections)) return 0;
  let n = 0;
  for (const section of sections) {
    if (Array.isArray(section)) {
      n += section.length;
    } else {
      n += (section.items || []).length;
    }
  }
  return n;
}

function countProcedureSteps(method) {
  const blocks = parseJsonField(method, []);
  if (!Array.isArray(blocks)) return 0;
  let n = 0;
  for (const block of blocks) {
    if (Array.isArray(block)) {
      n += block.length;
    } else {
      n += (block.steps || []).length;
    }
  }
  return n;
}

function isWeakIntro(intro) {
  const t = String(intro || '').trim();
  if (!t) return true;
  if (BOILERPLATE_INTROS.includes(t)) return true;
  if (/^Imported from .+\.$/i.test(t) && t.length < 90) return true;
  return false;
}

/** polished = cleaned, Betty approves | yellow = Betty edits | red = auto-reject junk */
function assessAgentOutcome(structured, row, payload) {
  const reasons = [];
  if (structured.reject_recommended) {
    return {
      outcome: 'reject',
      auto_approve: false,
      needs_manual: false,
      reasons: [structured.reject_reason || 'Not a valid recipe'],
    };
  }

  const ingCount = countIngredientRows(payload.ingredients);
  const stepCount = countProcedureSteps(payload.method);
  const name = String(payload.recipe_name || '').trim();

  if (ingCount < 2 && stepCount < 2) {
    return {
      outcome: 'reject',
      auto_approve: false,
      needs_manual: false,
      reasons: ['Empty ingredients and procedure'],
    };
  }
  if (ingCount < 2) reasons.push(`Only ${ingCount} ingredient(s)`);
  if (stepCount < 2) reasons.push(`Only ${stepCount} step(s)`);
  if (!name || name === 'Untitled Recipe') reasons.push('Missing recipe title');
  if (!payload.category || !TCJ_CATEGORIES.includes(payload.category)) reasons.push('Missing TCJ category');
  if (isWeakIntro(payload.introduction)) reasons.push('Introduction still weak');

  // Unknown ingredients are informational only — flagged in agent_notes, not a review gate.
  const unknown = parseJsonField(structured.unknown_ingredients, []);
  const infoNotes = Array.isArray(unknown) && unknown.length
    ? [`${unknown.length} unknown ingredient(s) flagged`]
    : [];

  if (reasons.length === 0) {
    return {
      outcome: 'polished',
      auto_approve: false,
      needs_manual: false,
      reasons: [],
      info_notes: infoNotes,
    };
  }

  const hardYellow = reasons.some((r) =>
    r.startsWith('Only ') || r.includes('Missing') || r.includes('Introduction'),
  );
  return {
    outcome: 'review',
    auto_approve: false,
    needs_manual: hardYellow,
    reasons,
    info_notes: infoNotes,
  };
}

function buildSavePayload(structured, row) {
  return {
    recipe_name: structured.recipe_name || row.recipe_name,
    native_title: structured.native_title ?? row.native_title ?? '',
    category: structured.category || row.category,
    introduction: structured.introduction ?? row.introduction ?? '',
    prep_time_minutes: coerceInt(structured.prep_time_minutes, row.prep_time_minutes || 0),
    cook_time_minutes: coerceInt(structured.cook_time_minutes, row.cook_time_minutes || 0),
    servings: Math.max(1, coerceInt(structured.servings, row.servings || 1)),
    spice_level: pickChoice(structured.spice_level, SPICE_LEVELS, row.spice_level || 'Not Applicable'),
    sweet_level: pickChoice(structured.sweet_level, SWEET_LEVELS, row.sweet_level || 'Not Applicable'),
    origin_continent: structured.origin_continent || row.origin_continent || '',
    origin_country: structured.origin_country || row.origin_country || '',
    origin_state: structured.origin_state || row.origin_state || '',
    origin_locality: structured.origin_locality || row.origin_locality || '',
    source_type: structured.source_type || row.source_type || 'Original',
    credit_name: structured.credit_name ?? row.credit_name ?? '',
    credit_handle: structured.credit_handle ?? row.credit_handle ?? '',
    credit_url: structured.credit_url || row.credit_url || row.import_source_url || '',
    ingredients: structured.ingredients || row.ingredients,
    method: structured.method || row.method,
    cooking_notes: structured.cooking_notes ?? row.cooking_notes ?? '',
    procedure_rewritten: true,
    import_extractor: 'admin-mechanical-v1',
  };
}

module.exports = {
  TCJ_CATEGORIES,
  buildSavePayload,
  assessAgentOutcome,
};
