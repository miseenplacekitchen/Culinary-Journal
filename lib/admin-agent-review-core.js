/**
 * Admin Agent Review — Groq cleanup matching TCJ review panel sections.
 * Used by api/admin-agent-review.js (server) only.
 */

const TCJ_CATEGORIES = [
  'Rise & Shine', 'The Evening Table', 'Garden & Earth', 'Meat & Fire',
  'Ocean & River', 'Slow & Soulful', 'Grains & Comfort', 'Breads & Bakes',
  'Sweet Serenades', 'Sips & Stories', 'Preserved & Cherished', 'Feast Days',
  'Little Ones', 'Nourish & Heal',
];

const SPICE_LEVELS = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'];
const SWEET_LEVELS = ['Not Applicable', 'Subtly Sweet', 'Lightly Sweet', 'Sweet', 'Very Sweet', 'Extremely Sweet'];

const ADMIN_AGENT_PROMPT = `You are the Admin Recipe Review agent for The Culinary Journal.
You clean pending recipes exactly as Betty (solo admin) would before she clicks Approve.
Return ONLY valid JSON (no markdown fences).

Schema:
{
  "recipe_name": "string — Title Case, no page numbers or PDF junk",
  "native_title": "string or empty",
  "category": "one of: ${TCJ_CATEGORIES.join(', ')}",
  "introduction": "1-2 warm professional sentences",
  "prep_time_minutes": 0,
  "cook_time_minutes": 0,
  "servings": 1,
  "spice_level": "one of: ${SPICE_LEVELS.join(', ')}",
  "sweet_level": "one of: ${SWEET_LEVELS.join(', ')}",
  "origin_continent": "string or empty",
  "origin_country": "string or empty",
  "origin_state": "string or empty",
  "origin_locality": "string or empty",
  "source_type": "Original | From a Book | From a Website | From Social Media | From Somewhere Else",
  "credit_name": "string or empty",
  "credit_handle": "string or empty",
  "credit_url": "string or empty",
  "ingredients": [
    { "section": "string", "items": [{ "qty": "", "unit": "", "ingredient": "", "note": "", "category": "" }] }
  ],
  "method": [
    { "section": "DIRECTIONS or PREP WORK", "steps": [{ "title": "", "text": "string" }] }
  ],
  "cooking_notes": "string or empty",
  "reject_recommended": false,
  "reject_reason": "string or empty — if reject_recommended true",
  "agent_notes": "string — brief checklist of what you fixed (for Betty)"
}

Section rules:
1. Title — strip POUL TRY, page nums, run-on book codes; Title Case dish name.
2. Introduction — never leave only "Imported from Personal book collection."
3. Ingredients — split every line qty/unit/ingredient/note; keep sub-sections; ≥2 items when source allows.
4. Procedure — ≥2 clear steps; formal English; preserve section names.
5. Origin — infer country from cuisine when obvious.
6. Credits — set credit_url from import URL; book name in credit_name when present.
7. Do not invent ingredients or steps not in the source.
8. reject_recommended true only for: not a recipe, empty ingredients+method, spam/off-topic.
9. Do not change visibility or personal_notes.`;

function flattenRecipeForPrompt(row) {
  const parts = [];
  const name = String(row.recipe_name || '').replace(/ﬁ/g, 'fi').replace(/ﬂ/g, 'fl');
  parts.push(`Recipe name: ${name}`);
  if (row.native_title) parts.push(`Also known as: ${row.native_title}`);
  if (row.category) parts.push(`Category: ${row.category}`);
  if (row.credit_name) parts.push(`Book/source: ${row.credit_name}`);
  if (row.import_source_url) parts.push(`Import URL: ${row.import_source_url}`);
  if (row.import_path) parts.push(`Import path: ${row.import_path}`);
  if (row.import_confidence_score != null) parts.push(`Confidence: ${row.import_confidence_score}/100`);
  if (row.servings) parts.push(`Serves: ${row.servings}`);
  if (row.prep_time_minutes) parts.push(`Prep minutes: ${row.prep_time_minutes}`);
  if (row.cook_time_minutes) parts.push(`Cook minutes: ${row.cook_time_minutes}`);
  if (row.introduction) parts.push(`Introduction: ${row.introduction}`);
  if (row.import_paste_snapshot) parts.push(`Raw extract:\n${String(row.import_paste_snapshot).slice(0, 8000)}`);
  if (row.ingredients) {
    parts.push('Ingredients JSON:\n' + JSON.stringify(row.ingredients).slice(0, 6000));
  }
  if (row.method) {
    parts.push('Method JSON:\n' + JSON.stringify(row.method).slice(0, 6000));
  }
  if (row.cooking_notes) parts.push(`Cooking notes: ${row.cooking_notes}`);
  if (row.source_type) parts.push(`Source type: ${row.source_type}`);
  return parts.join('\n\n');
}

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
    import_extractor: 'admin-agent-review-v1',
  };
}

async function callGroqAgent(sourceText, groqApiKey) {
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${groqApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      temperature: 0.15,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: ADMIN_AGENT_PROMPT },
        { role: 'user', content: sourceText },
      ],
    }),
  });
  if (!res.ok) {
    const errText = await res.text().catch(() => String(res.status));
    const err = new Error(errText || `Groq ${res.status}`);
    err.status = res.status;
    throw err;
  }
  const data = await res.json();
  const raw = data.choices?.[0]?.message?.content || '{}';
  return JSON.parse(raw);
}

module.exports = {
  TCJ_CATEGORIES,
  flattenRecipeForPrompt,
  buildSavePayload,
  callGroqAgent,
};
