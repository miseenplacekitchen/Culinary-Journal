/**
 * One-time SEO pass: canonical tags, meta descriptions, H1 fixes,
 * duplicate title resolution, and empty tab-nav shells (nav-init.js fills them).
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const BASE = 'https://theculinaryjournal.site';

const SEO = {
  'index.html': {
    canonical: `${BASE}/`,
    description: 'The Culinary Journal is your complete culinary life in one place. Browse recipes, plan meals, host events, print cookbooks, and keep your culinary diary.',
  },
  'recipes.html': {
    canonical: `${BASE}/recipes.html`,
    description: 'Browse hand-curated recipes from around the world — searchable by category, origin, spice level, and dietary needs.',
  },
  'recipe-page.html': {
    canonical: `${BASE}/recipe-page.html`,
    description: 'Full recipe with ingredients, method, notes, and nutritional guidance from The Culinary Journal.',
  },
  'chefs.html': {
    canonical: `${BASE}/chefs.html`,
    description: 'Discover recipes credited to named chefs, cooks, and authors in The Culinary Journal chef directory.',
  },
  'search.html': {
    canonical: `${BASE}/search.html`,
    description: 'Search recipes, ingredients, and cuisines across The Culinary Journal collection.',
  },
  'submit-recipe.html': {
    canonical: `${BASE}/submit-recipe.html`,
    description: 'Submit your recipe to The Culinary Journal community — share family favourites and regional dishes.',
  },
  'draft-recipes.html': {
    canonical: `${BASE}/draft-recipes.html`,
    description: 'View and manage your saved recipe drafts and submission status on The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'meal-planner.html': {
    canonical: `${BASE}/meal-planner.html`,
    description: 'Plan weekly meals, assign recipes to days, and coordinate cooking for your household.',
  },
  'grocery.html': {
    canonical: `${BASE}/grocery.html`,
    description: 'Build and manage your grocery list from recipes and pantry needs on The Culinary Journal.',
  },
  'pantry.html': {
    canonical: `${BASE}/pantry.html`,
    description: 'Track pantry and fridge inventory, expiry dates, and low-stock items in your kitchen.',
  },
  'print-studio.html': {
    canonical: `${BASE}/print-studio.html`,
    description: 'Design and print recipe cards, index cards, and cookbook pages from your saved recipes.',
  },
  'family-profiles.html': {
    canonical: `${BASE}/family-profiles.html`,
    description: 'Store dietary requirements for family and guests — used by meal planner and table planner.',
  },
  'household.html': {
    canonical: `${BASE}/household.html`,
    description: 'Link your partner and share one grocery list on The Culinary Journal.',
  },
  'table-planner.html': {
    canonical: `${BASE}/table-planner.html`,
    description: 'Plan events, seating arrangements, place cards, and guest dietary requirements.',
  },
  'dietary-card.html': {
    canonical: `${BASE}/dietary-card.html`,
    description: 'Guest dietary requirements form for events hosted through The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'library-directory.html': {
    canonical: `${BASE}/library-directory.html`,
    description: 'Explore The Library — ingredients, spices, tools, cuts, and preservation reference guides.',
    title: 'Library Directory — The Culinary Journal',
  },
  'library-profile.html': {
    canonical: `${BASE}/library-profile.html`,
    description: 'Detailed library profile for an ingredient, spice, tool, cut, or preservation technique.',
    title: 'Library Profile — The Culinary Journal',
  },
  'library-submit.html': {
    canonical: `${BASE}/library-submit.html`,
    description: 'Submit a library profile for ingredients, spices, tools, or techniques to The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'library.html': {
    canonical: `${BASE}/library-directory.html?type=preservation`,
    description: 'Legacy preservation library — browse fermentation, canning, and preserved recipe guides.',
    title: 'Preservation Library — The Culinary Journal',
    robots: 'noindex, follow',
  },
  'preservation.html': {
    canonical: `${BASE}/preservation.html`,
    description: 'Complete guide to food preservation — canning, freezing, pickling, fermenting, curing, and more.',
  },
  'conversions.html': {
    canonical: `${BASE}/conversions.html`,
    description: 'Kitchen conversion tools — weights, volumes, temperatures, and ingredient substitutions.',
  },
  'baby.html': {
    canonical: `${BASE}/baby.html`,
    description: 'Baby and toddler food guidance with age-appropriate recipes and allergen warnings.',
  },
  'culinary-life.html': {
    canonical: `${BASE}/culinary-life.html`,
    description: 'Your personal culinary life hub — collections, diary, submissions, and kitchen activity.',
    robots: 'noindex, nofollow',
  },
  'collections.html': {
    canonical: `${BASE}/collections.html`,
    description: 'Organise and save your favourite recipes into personal collections.',
    robots: 'noindex, nofollow',
  },
  'diary.html': {
    canonical: `${BASE}/diary.html`,
    description: 'Private culinary diary for cooking notes, memories, and reflections.',
    robots: 'noindex, nofollow',
  },
  'my-dashboard.html': {
    canonical: `${BASE}/my-dashboard.html`,
    description: 'Personal analytics dashboard for your recipe submissions and kitchen activity.',
    robots: 'noindex, nofollow',
  },
  'profile.html': {
    canonical: `${BASE}/profile.html`,
    description: 'Manage your Culinary Journal profile, preferences, and account settings.',
    robots: 'noindex, nofollow',
  },
  'user.html': {
    canonical: `${BASE}/user.html`,
    description: 'Public member profile showing recipes and collections shared on The Culinary Journal.',
  },
  'login.html': {
    canonical: `${BASE}/login.html`,
    description: 'Sign in or create a free account on The Culinary Journal.',
  },
  'reset-password.html': {
    canonical: `${BASE}/reset-password.html`,
    description: 'Reset your Culinary Journal account password securely.',
    robots: 'noindex, nofollow',
  },
  'members-only.html': {
    canonical: `${BASE}/members-only.html`,
    description: 'Sign in to access member features on The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'paid-members-only.html': {
    canonical: `${BASE}/paid-members-only.html`,
    description: 'Upgrade to Premium to access this feature on The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'coming-soon.html': {
    canonical: `${BASE}/coming-soon.html`,
    description: 'This feature is coming soon to The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'dashboard.html': {
    canonical: `${BASE}/dashboard.html`,
    description: 'Administrator panel for The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'site-settings.html': {
    canonical: `${BASE}/site-settings.html`,
    description: 'Site-wide settings for The Culinary Journal administrators.',
    robots: 'noindex, nofollow',
  },
  'site-management.html': {
    canonical: `${BASE}/site-management.html`,
    description: 'Site management console for The Culinary Journal administrators.',
    robots: 'noindex, nofollow',
  },
  'terms.html': {
    canonical: `${BASE}/terms.html`,
    description: 'Terms of Use for The Culinary Journal — account rules, recipe submissions, and site policies.',
  },
  'privacy.html': {
    canonical: `${BASE}/privacy.html`,
    description: 'Privacy Policy for The Culinary Journal — what we collect, how we use it, and your rights.',
  },
  'ai-disclaimer.html': {
    canonical: `${BASE}/ai-disclaimer.html`,
    description: 'AI and automation disclaimer for The Culinary Journal — what is automated and its limitations.',
  },
  'email-reset.html': {
    canonical: `${BASE}/email-reset.html`,
    description: 'Password reset email template for The Culinary Journal.',
    robots: 'noindex, nofollow',
  },
  'email-confirm.html': {
    canonical: `${BASE}/email-confirm.html`,
    description: 'Email confirmation template for new Culinary Journal accounts.',
    robots: 'noindex, nofollow',
  },
};

const H1_REPLACEMENTS = [
  ['<div class="lib-title">🫙 The Library</div>', '<h1 class="lib-title">🫙 The Library</h1>'],
  ['<div style="font-family:\'Cormorant Garamond\',serif;font-size:1.6rem;font-weight:700;color:var(--text-high);margin-bottom:16px">Search The Culinary Journal</div>',
   '<h1 style="font-family:\'Cormorant Garamond\',serif;font-size:1.6rem;font-weight:700;color:var(--text-high);margin-bottom:16px">Search The Culinary Journal</h1>'],
  ['<div class="ch-title">👨‍🍳 Chef Directory</div>', '<h1 class="ch-title">👨‍🍳 Chef Directory</h1>'],
  ['<div class="tp-title">🪑 Table Planner</div>', '<h1 class="tp-title">🪑 Table Planner</h1>'],
  ['<div class="mp-title">🗓 Meal Planner</div>', '<h1 class="mp-title">🗓 Meal Planner</h1>'],
  ['<div class="gl-title">🛒 Grocery List</div>', '<h1 class="gl-title">🛒 Grocery List</h1>'],
  ['<div class="pt-title">🫙 Pantry &amp; Fridge</div>', '<h1 class="pt-title">🫙 Pantry &amp; Fridge</h1>'],
  ['<div class="cv-title">⚖️ Conversion Tools</div>', '<h1 class="cv-title">⚖️ Conversion Tools</h1>'],
  ['<div class="cl-title">📁 My Collections</div>', '<h1 class="cl-title">📁 My Collections</h1>'],
  ['<div class="bt-title">👶 Baby &amp; Toddler</div>', '<h1 class="bt-title">👶 Baby &amp; Toddler</h1>'],
  ['<div class="fp-title">👨‍👩‍👧‍👦 Family &amp; Guest Profiles</div>', '<h1 class="fp-title">👨‍👩‍👧‍👦 Family &amp; Guest Profiles</h1>'],
  ['<div class="dj-heading">My <span>Diary</span></div>', '<h1 class="dj-heading">My <span>Diary</span></h1>'],
  ['<div class="ud-greeting">Analytics — <span id="ud-name">Chef</span></div>', '<h1 class="ud-greeting">Analytics — <span id="ud-name">Chef</span></h1>'],
  ['<div class="bp-title">✨ Site Settings</div>', '<h1 class="bp-title">✨ Site Settings</h1>'],
  ['<div class="sm-logo-title">Site Management</div>', '<h1 class="sm-logo-title">Site Management</h1>'],
  ['<div style="font-family:\'Cormorant Garamond\',serif;font-size:1.6rem;font-weight:600;color:var(--text-high);margin-bottom:20px">🖨 Print Studio</div>',
   '<h1 style="font-family:\'Cormorant Garamond\',serif;font-size:1.6rem;font-weight:600;color:var(--text-high);margin-bottom:20px">🖨 Print Studio</h1>'],
  ['<h1 style="font-size:clamp(1.5rem,4vw,2rem)">My Submissions</h1>', '<h2 style="font-size:clamp(1.5rem,4vw,2rem)">My Submissions</h2>'],
  ['<div class="greeting">Reset your password</div>', '<h1 class="greeting">Reset your password</h1>'],
];

function injectSeoHead(html, file, meta) {
  if (html.includes('rel="canonical"')) return html;

  const block = [
    meta.description ? `  <meta name="description" content="${meta.description}">` : '',
    `  <link rel="canonical" href="${meta.canonical}">`,
    meta.robots ? `  <meta name="robots" content="${meta.robots}">` : '',
  ].filter(Boolean).join('\n');

  if (meta.title) {
    html = html.replace(/<title>[^<]*<\/title>/, `<title>${meta.title}</title>`);
  }

  // Insert after viewport meta when present
  if (/<meta name="viewport"[^>]*>/i.test(html)) {
    return html.replace(/(<meta name="viewport"[^>]*>)/i, `$1\n${block}`);
  }
  // Fallback: after charset
  if (/<meta charset="UTF-8">/i.test(html)) {
    return html.replace(/(<meta charset="UTF-8">)/i, `$1\n${block}`);
  }
  return html.replace(/(<head>)/i, `$1\n${block}`);
}

function simplifyTabNav(html) {
  // nav-init.js rebuilds .tab-nav entirely — remove duplicated hardcoded links
  return html.replace(
    /<div class="tab-nav"><div class="tab-nav-inner">[\s\S]*?<\/div><\/div>/g,
    '<div class="tab-nav"></div>'
  );
}

function addRecipesH1(html) {
  if (html.includes('class="recipes-page-h1"')) return html;
  return html.replace(
    '<div class="recipes-top">',
    '<h1 class="recipes-page-h1" style="font-family:\'Cormorant Garamond\',serif;font-size:1.8rem;font-weight:700;color:var(--text-high);margin:0 0 16px;padding:24px 24px 0">📖 Recipes</h1>\n  <div class="recipes-top">'
  );
}

function addLoginH1(html) {
  if (html.includes('class="auth-page-h1"')) return html;
  return html.replace(
    '<div class="auth-tabs">',
    '<h1 class="auth-page-h1 auth-heading" style="text-align:center;margin-bottom:20px">Sign In</h1>\n      <div class="auth-tabs">'
  );
}

function addDashboardH1(html) {
  if (html.includes('class="ap-page-h1"')) return html;
  return html.replace(
    '<div id="v-dashboard">',
    '<h1 class="ap-page-h1" style="position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0">Admin Panel</h1>\n    <div id="v-dashboard">'
  );
}

function addDietaryCardH1(html) {
  if (/<h1[^>]*dc-event/.test(html)) return html;
  return html.replace(
    '<div class="dc-event" id="dc-event-name">',
    '<h1 class="dc-event" id="dc-event-name">'
  ).replace(
    '</div>\n    <div class="dc-date" id="dc-event-date">',
    '</h1>\n      <div class="dc-date" id="dc-event-date">'
  );
}

function addUserH1(html) {
  if (html.includes('id="up-page-h1"')) return html;
  return html.replace(
    '<div class="up-username" id="up-username"></div>',
    '<h1 class="up-username" id="up-username"></h1>'
  );
}

function addIndexCanonical(html) {
  // index already has description — only add canonical if missing
  if (!html.includes('rel="canonical"')) {
    html = html.replace(
      /(<meta name="description"[^>]*>)/,
      `$1\n  <link rel="canonical" href="${BASE}/">`
    );
  }
  return html;
}

const files = fs.readdirSync(ROOT).filter((f) => f.endsWith('.html'));
let updated = 0;

for (const file of files) {
  const meta = SEO[file];
  if (!meta) {
    console.warn('No SEO config for', file);
    continue;
  }

  const filePath = path.join(ROOT, file);
  let html = fs.readFileSync(filePath, 'utf8');
  const original = html;

  if (file === 'index.html') {
    html = addIndexCanonical(html);
  } else {
    html = injectSeoHead(html, file, meta);
  }

  html = simplifyTabNav(html);

  for (const [from, to] of H1_REPLACEMENTS) {
    html = html.split(from).join(to);
  }

  if (file === 'recipes.html') html = addRecipesH1(html);
  if (file === 'login.html') html = addLoginH1(html);
  if (file === 'dashboard.html') html = addDashboardH1(html);
  if (file === 'dietary-card.html') html = addDietaryCardH1(html);
  if (file === 'user.html') html = addUserH1(html);

  if (html !== original) {
    fs.writeFileSync(filePath, html, 'utf8');
    updated++;
    console.log('Updated', file);
  }
}

console.log(`Done. ${updated} files updated.`);
