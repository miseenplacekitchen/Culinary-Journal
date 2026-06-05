"""SEO pass: canonical tags, meta descriptions, H1 fixes, tab-nav cleanup."""
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), '..')
BASE = 'https://theculinaryjournal.site'

SEO = {
    'index.html': {'canonical': f'{BASE}/', 'description': 'The Culinary Journal is your complete culinary life in one place. Browse recipes, plan meals, host events, print cookbooks, and keep your culinary diary.'},
    'recipes.html': {'canonical': f'{BASE}/recipes.html', 'description': 'Browse hand-curated recipes from around the world — searchable by category, origin, spice level, and dietary needs.'},
    'recipe-page.html': {'canonical': f'{BASE}/recipe-page.html', 'description': 'Full recipe with ingredients, method, notes, and nutritional guidance from The Culinary Journal.'},
    'chefs.html': {'canonical': f'{BASE}/chefs.html', 'description': 'Discover recipes credited to named chefs, cooks, and authors in The Culinary Journal chef directory.'},
    'search.html': {'canonical': f'{BASE}/search.html', 'description': 'Search recipes, ingredients, and cuisines across The Culinary Journal collection.'},
    'submit-recipe.html': {'canonical': f'{BASE}/submit-recipe.html', 'description': 'Submit your recipe to The Culinary Journal community — share family favourites and regional dishes.'},
    'draft-recipes.html': {'canonical': f'{BASE}/draft-recipes.html', 'description': 'View and manage your saved recipe drafts and submission status on The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'meal-planner.html': {'canonical': f'{BASE}/meal-planner.html', 'description': 'Plan weekly meals, assign recipes to days, and coordinate cooking for your household.'},
    'grocery.html': {'canonical': f'{BASE}/grocery.html', 'description': 'Build and manage your grocery list from recipes and pantry needs on The Culinary Journal.'},
    'pantry.html': {'canonical': f'{BASE}/pantry.html', 'description': 'Track pantry and fridge inventory, expiry dates, and low-stock items in your kitchen.'},
    'print-studio.html': {'canonical': f'{BASE}/print-studio.html', 'description': 'Design and print recipe cards, index cards, and cookbook pages from your saved recipes.'},
    'family-profiles.html': {'canonical': f'{BASE}/family-profiles.html', 'description': 'Store dietary requirements for family and guests — used by meal planner and table planner.'},
    'table-planner.html': {'canonical': f'{BASE}/table-planner.html', 'description': 'Plan events, seating arrangements, place cards, and guest dietary requirements.'},
    'dietary-card.html': {'canonical': f'{BASE}/dietary-card.html', 'description': 'Guest dietary requirements form for events hosted through The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'library-directory.html': {'canonical': f'{BASE}/library-directory.html', 'description': 'Explore The Library — ingredients, spices, tools, cuts, and preservation reference guides.', 'title': 'Library Directory — The Culinary Journal'},
    'library-profile.html': {'canonical': f'{BASE}/library-profile.html', 'description': 'Detailed library profile for an ingredient, spice, tool, cut, or preservation technique.', 'title': 'Library Profile — The Culinary Journal'},
    'library-submit.html': {'canonical': f'{BASE}/library-submit.html', 'description': 'Submit a library profile for ingredients, spices, tools, or techniques to The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'library.html': {'canonical': f'{BASE}/library-directory.html?type=preservation', 'description': 'Legacy preservation library — browse fermentation, canning, and preserved recipe guides.', 'title': 'Preservation Library — The Culinary Journal', 'robots': 'noindex, follow'},
    'preservation.html': {'canonical': f'{BASE}/preservation.html', 'description': 'Complete guide to food preservation — canning, freezing, pickling, fermenting, curing, and more.'},
    'conversions.html': {'canonical': f'{BASE}/conversions.html', 'description': 'Kitchen conversion tools — weights, volumes, temperatures, and ingredient substitutions.'},
    'baby.html': {'canonical': f'{BASE}/baby.html', 'description': 'Baby and toddler food guidance with age-appropriate recipes and allergen warnings.'},
    'culinary-life.html': {'canonical': f'{BASE}/culinary-life.html', 'description': 'Your personal culinary life hub — collections, diary, submissions, and kitchen activity.', 'robots': 'noindex, nofollow'},
    'collections.html': {'canonical': f'{BASE}/collections.html', 'description': 'Organise and save your favourite recipes into personal collections.', 'robots': 'noindex, nofollow'},
    'diary.html': {'canonical': f'{BASE}/diary.html', 'description': 'Private culinary diary for cooking notes, memories, and reflections.', 'robots': 'noindex, nofollow'},
    'my-dashboard.html': {'canonical': f'{BASE}/my-dashboard.html', 'description': 'Personal analytics dashboard for your recipe submissions and kitchen activity.', 'robots': 'noindex, nofollow'},
    'profile.html': {'canonical': f'{BASE}/profile.html', 'description': 'Manage your Culinary Journal profile, preferences, and account settings.', 'robots': 'noindex, nofollow'},
    'user.html': {'canonical': f'{BASE}/user.html', 'description': 'Public member profile showing recipes and collections shared on The Culinary Journal.'},
    'login.html': {'canonical': f'{BASE}/login.html', 'description': 'Sign in or create a free account on The Culinary Journal.'},
    'reset-password.html': {'canonical': f'{BASE}/reset-password.html', 'description': 'Reset your Culinary Journal account password securely.', 'robots': 'noindex, nofollow'},
    'members-only.html': {'canonical': f'{BASE}/members-only.html', 'description': 'Sign in to access member features on The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'paid-members-only.html': {'canonical': f'{BASE}/paid-members-only.html', 'description': 'Upgrade to Premium to access this feature on The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'coming-soon.html': {'canonical': f'{BASE}/coming-soon.html', 'description': 'This feature is coming soon to The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'dashboard.html': {'canonical': f'{BASE}/dashboard.html', 'description': 'Administrator panel for The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'site-settings.html': {'canonical': f'{BASE}/site-settings.html', 'description': 'Site-wide settings for The Culinary Journal administrators.', 'robots': 'noindex, nofollow'},
    'site-management.html': {'canonical': f'{BASE}/site-management.html', 'description': 'Site management console for The Culinary Journal administrators.', 'robots': 'noindex, nofollow'},
    'terms.html': {'canonical': f'{BASE}/terms.html', 'description': 'Terms of Use for The Culinary Journal — account rules, recipe submissions, and site policies.'},
    'privacy.html': {'canonical': f'{BASE}/privacy.html', 'description': 'Privacy Policy for The Culinary Journal — what we collect, how we use it, and your rights.'},
    'ai-disclaimer.html': {'canonical': f'{BASE}/ai-disclaimer.html', 'description': 'AI and automation disclaimer for The Culinary Journal — what is automated and its limitations.'},
    'email-reset.html': {'canonical': f'{BASE}/email-reset.html', 'description': 'Password reset email template for The Culinary Journal.', 'robots': 'noindex, nofollow'},
    'email-confirm.html': {'canonical': f'{BASE}/email-confirm.html', 'description': 'Email confirmation template for new Culinary Journal accounts.', 'robots': 'noindex, nofollow'},
}

H1_REPLACEMENTS = [
    ('<div class="lib-title">🫙 The Library</div>', '<h1 class="lib-title">🫙 The Library</h1>'),
    ("<div style=\"font-family:'Cormorant Garamond',serif;font-size:1.6rem;font-weight:700;color:var(--text-high);margin-bottom:16px\">Search The Culinary Journal</div>",
     "<h1 style=\"font-family:'Cormorant Garamond',serif;font-size:1.6rem;font-weight:700;color:var(--text-high);margin-bottom:16px\">Search The Culinary Journal</h1>"),
    ('<div class="ch-title">👨‍🍳 Chef Directory</div>', '<h1 class="ch-title">👨‍🍳 Chef Directory</h1>'),
    ('<div class="tp-title">🪑 Table Planner</div>', '<h1 class="tp-title">🪑 Table Planner</h1>'),
    ('<div class="mp-title">🗓 Meal Planner</div>', '<h1 class="mp-title">🗓 Meal Planner</h1>'),
    ('<div class="gl-title">🛒 Grocery List</div>', '<h1 class="gl-title">🛒 Grocery List</h1>'),
    ('<div class="pt-title">🫙 Pantry &amp; Fridge</div>', '<h1 class="pt-title">🫙 Pantry &amp; Fridge</h1>'),
    ('<div class="cv-title">⚖️ Conversion Tools</div>', '<h1 class="cv-title">⚖️ Conversion Tools</h1>'),
    ('<div class="cl-title">📁 My Collections</div>', '<h1 class="cl-title">📁 My Collections</h1>'),
    ('<div class="bt-title">👶 Baby &amp; Toddler</div>', '<h1 class="bt-title">👶 Baby &amp; Toddler</h1>'),
    ('<div class="fp-title">👨‍👩‍👧‍👦 Family &amp; Guest Profiles</div>', '<h1 class="fp-title">👨‍👩‍👧‍👦 Family &amp; Guest Profiles</h1>'),
    ('<div class="dj-heading">My <span>Diary</span></div>', '<h1 class="dj-heading">My <span>Diary</span></h1>'),
    ('<div class="ud-greeting">Analytics — <span id="ud-name">Chef</span></div>', '<h1 class="ud-greeting">Analytics — <span id="ud-name">Chef</span></h1>'),
    ('<div class="bp-title">✨ Site Settings</div>', '<h1 class="bp-title">✨ Site Settings</h1>'),
    ('<div class="sm-logo-title">Site Management</div>', '<h1 class="sm-logo-title">Site Management</h1>'),
    ("<div style=\"font-family:'Cormorant Garamond',serif;font-size:1.6rem;font-weight:600;color:var(--text-high);margin-bottom:20px\">🖨 Print Studio</div>",
     "<h1 style=\"font-family:'Cormorant Garamond',serif;font-size:1.6rem;font-weight:600;color:var(--text-high);margin-bottom:20px\">🖨 Print Studio</h1>"),
    ('<h1 style="font-size:clamp(1.5rem,4vw,2rem)">My Submissions</h1>', '<h2 style="font-size:clamp(1.5rem,4vw,2rem)">My Submissions</h2>'),
    ('<div class="greeting">Reset your password</div>', '<h1 class="greeting">Reset your password</h1>'),
    ('<div class="greeting">Confirm your email address</div>', '<h1 class="greeting">Confirm your email address</h1>'),
    ('<h1 class="auth-heading">Link Invalid or Expired</h1>', '<h2 class="auth-heading">Link Invalid or Expired</h2>'),
]

TAB_NAV_RE = re.compile(r'<div class="tab-nav"><div class="tab-nav-inner">[\s\S]*?</div></div>')


def inject_seo_head(html, meta):
    if 'rel="canonical"' in html:
        return html
    block_lines = []
    if meta.get('description') and 'name="description"' not in html:
        block_lines.append(f'  <meta name="description" content="{meta["description"]}">')
    block_lines.append(f'  <link rel="canonical" href="{meta["canonical"]}">')
    if meta.get('robots'):
        block_lines.append(f'  <meta name="robots" content="{meta["robots"]}">')
    block = '\n'.join(block_lines)
    if meta.get('title'):
        html = re.sub(r'<title>[^<]*</title>', f'<title>{meta["title"]}</title>', html)
    if re.search(r'<meta name="viewport"[^>]*>', html, re.I):
        return re.sub(r'(<meta name="viewport"[^>]*>)', r'\1\n' + block, html, count=1, flags=re.I)
    if re.search(r'<meta charset="UTF-8">', html, re.I):
        return re.sub(r'(<meta charset="UTF-8">)', r'\1\n' + block, html, count=1, flags=re.I)
    return re.sub(r'(<head>)', r'\1\n' + block, html, count=1, flags=re.I)


def process_file(filename, meta):
    path = os.path.join(ROOT, filename)
    html = open(path, encoding='utf-8').read()
    original = html

    if filename == 'index.html':
        if 'rel="canonical"' not in html:
            html = re.sub(
                r'(<meta name="description"[^>]*>)',
                r'\1\n  <link rel="canonical" href="' + BASE + '/">',
                html, count=1
            )
    else:
        html = inject_seo_head(html, meta)

    html = TAB_NAV_RE.sub('<div class="tab-nav"></div>', html)

    for old, new in H1_REPLACEMENTS:
        html = html.replace(old, new)

    if filename == 'recipes.html' and 'class="recipes-page-h1"' not in html:
        html = html.replace(
            '<div class="recipes-top">',
            '<h1 class="recipes-page-h1" style="font-family:\'Cormorant Garamond\',serif;font-size:1.8rem;font-weight:700;color:var(--text-high);margin:0 0 16px;padding:24px 24px 0">📖 Recipes</h1>\n  <div class="recipes-top">'
        )

    if filename == 'login.html' and 'class="auth-page-h1"' not in html:
        html = html.replace(
            '<div class="auth-tabs">',
            '<h1 class="auth-page-h1 auth-heading" style="text-align:center;margin-bottom:20px">Sign In</h1>\n      <div class="auth-tabs">'
        )

    if filename == 'dashboard.html' and 'class="ap-page-h1"' not in html:
        html = html.replace(
            '<div id="v-dashboard">',
            '<h1 class="ap-page-h1" style="position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0">Admin Panel</h1>\n    <div id="v-dashboard">'
        )

    if filename == 'dietary-card.html' and '<h1 class="dc-event"' not in html:
        html = html.replace(
            '<div class="dc-event" id="dc-event-name">Event</div>',
            '<h1 class="dc-event" id="dc-event-name">Event</h1>'
        )

    if filename == 'user.html':
        html = html.replace('<div class="up-username" id="up-username"></div>', '<h1 class="up-username" id="up-username"></h1>')

    if html != original:
        open(path, 'w', encoding='utf-8').write(html)
        return True
    return False


updated = 0
for f in sorted(os.listdir(ROOT)):
    if not f.endswith('.html'):
        continue
    if f not in SEO:
        print('No SEO config for', f)
        continue
    if process_file(f, SEO[f]):
        updated += 1
        print('Updated', f)

print(f'Done. {updated} files updated.')
