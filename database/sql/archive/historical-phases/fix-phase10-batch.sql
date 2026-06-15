-- ══════════════════════════════════════════════════════════════════════
-- fix-phase10-batch.sql — Email template polish + clear bogus link checks.
-- Safe to re-run. Run after fix-phase9-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

-- Remove link-check stamps on recipes without a real URL
UPDATE public.submitted_recipes
   SET source_link_status = NULL,
       source_link_checked_at = NULL
 WHERE credit_url IS NULL OR btrim(credit_url) = '';

INSERT INTO public.email_templates (key, name, subject, body, updated_at) VALUES
('welcome',
 'Welcome',
 'Welcome to The Culinary Journal',
 '<h2 style="font-family:Cormorant Garamond,Georgia,serif;color:#C4973B;margin:0 0 16px">Welcome, {{name}}</h2>
  <p style="line-height:1.7;margin:0 0 16px">Your account is ready. Start exploring community recipes, plan meals, and build your culinary journal.</p>
  <p style="margin:0 0 20px"><a href="{{recipes_url}}" style="color:#C4973B;font-weight:600">Explore Recipes &rarr;</a></p>
  <p style="font-size:12px;color:#888;margin:0">Questions? Reply to this email or visit <a href="{{site_url}}" style="color:#C4973B">{{site_url}}</a></p>',
 NOW()),
('recipe_approved',
 'Recipe Approved',
 'Your recipe has been published',
 '<h2 style="font-family:Cormorant Garamond,Georgia,serif;color:#C4973B;margin:0 0 16px">Your recipe is live</h2>
  <p style="line-height:1.7">Hi {{name}},</p>
  <p style="line-height:1.7"><strong>{{recipe_name}}</strong> has been approved and published on The Culinary Journal.</p>
  <p style="margin:20px 0 0"><a href="{{recipe_url}}" style="color:#C4973B;font-weight:600">View your recipe &rarr;</a></p>',
 NOW()),
('recipe_rejected',
 'Recipe Not Approved',
 'Update on your recipe submission',
 '<h2 style="font-family:Cormorant Garamond,Georgia,serif;color:#e8e0d4;margin:0 0 16px">Recipe needs updates</h2>
  <p style="line-height:1.7">Hi {{name}},</p>
  <p style="line-height:1.7"><strong>{{recipe_name}}</strong> was not approved at this time.</p>
  <p style="line-height:1.7"><strong>Reviewer notes:</strong> {{rejection_reason}}</p>
  <p style="margin:20px 0 0"><a href="https://www.theculinaryjournal.site/draft-recipes.html" style="color:#C4973B;font-weight:600">View your drafts &rarr;</a></p>',
 NOW())
ON CONFLICT (key) DO UPDATE SET
  name       = EXCLUDED.name,
  subject    = EXCLUDED.subject,
  body       = EXCLUDED.body,
  updated_at = NOW();

SELECT 'fix-phase10-batch.sql complete' AS status;
