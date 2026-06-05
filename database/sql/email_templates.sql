-- ── email_templates table ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_templates (
  key        text PRIMARY KEY,
  name       text,
  subject    text,
  body       text,
  updated_at timestamptz DEFAULT NOW()
);
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin manages email templates" ON public.email_templates;
CREATE POLICY "Admin manages email templates" ON public.email_templates
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "Anon cannot read email templates" ON public.email_templates;
CREATE POLICY "Anon cannot read email templates" ON public.email_templates
  FOR SELECT TO anon USING (false);

-- ══════════════════════════════════════════════════════════════════════
-- Email Templates — written against actual schema:
--   key (text, PK), name (text), subject (text), body (text), updated_at
-- Does NOT drop or alter the table — only inserts/updates templates
-- and creates the email_queue table + queue_email RPC
-- ══════════════════════════════════════════════════════════════════════

-- RLS on existing table
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages email templates" ON email_templates;
CREATE POLICY "admin manages email templates"
  ON email_templates FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Insert/update templates using actual columns: key, name, subject, body
INSERT INTO email_templates (key, name, subject, body, updated_at) VALUES

('welcome',
 'Welcome',
 'Welcome to The Culinary Journal',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Welcome, {{name}} 🍳</h2><p>Your account is ready. <a href="https://www.theculinaryjournal.site/recipes.html">Explore Recipes →</a></p>',
 NOW()),

('recipe_approved',
 'Recipe Approved',
 'Your recipe has been published ✓',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Your recipe is live 🎉</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> has been published. <a href="{{recipe_url}}">View it →</a></p>',
 NOW()),

('recipe_rejected',
 'Recipe Not Approved',
 'Update on your recipe submission',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#e8e0d4">Recipe not approved</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> was not approved at this time.</p><p><strong>Reason:</strong> {{rejection_reason}}</p><p><a href="https://www.theculinaryjournal.site/draft-recipes.html">View your drafts →</a></p>',
 NOW()),

('account_deactivated',
 'Account Deactivated',
 'Your account has been deactivated',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#dc5050">Account Deactivated</h2><p>Hi {{name}}, your account has been deactivated.</p><p><strong>Reason:</strong> {{reason}}</p><p>To appeal, reply to this email.</p>',
 NOW()),

('request_fulfilled',
 'Recipe Request Fulfilled',
 'Your recipe request has been fulfilled ✓',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Request fulfilled 🍽</h2><p>Hi {{name}}, the recipe you requested — <strong>{{recipe_name}}</strong> — is now live. <a href="{{recipe_url}}">View it →</a></p>',
 NOW())

ON CONFLICT (key) DO UPDATE SET
  name       = EXCLUDED.name,
  subject    = EXCLUDED.subject,
  body       = EXCLUDED.body,
  updated_at = NOW();

-- ── Email queue (no FK — avoids schema mismatch) ──────────────────────
-- Handle existing email_queue with old column name template_id
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_id')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_key') THEN
    ALTER TABLE email_queue RENAME COLUMN template_id TO template_key;
    RAISE NOTICE 'Renamed email_queue.template_id to template_key';
  END IF;
  -- Edge case: email_queue exists but has neither column (broken half-created table)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'email_queue')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_key')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_id') THEN
    ALTER TABLE email_queue ADD COLUMN template_key text NOT NULL DEFAULT '';
    RAISE NOTICE 'Added missing template_key column to existing email_queue table';
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS email_queue (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key text NOT NULL,
  to_email     text NOT NULL,
  to_name      text,
  variables    jsonb NOT NULL DEFAULT '{}',
  status       text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','sending','sent','failed')),
  attempts     integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT NOW(),
  sent_at      timestamptz
);

ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages email queue" ON email_queue;
CREATE POLICY "admin manages email queue"
  ON email_queue FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ── queue_email RPC — admin only ──────────────────────────────────────
DROP FUNCTION IF EXISTS queue_email(text, text, text, jsonb);
CREATE FUNCTION queue_email(
  p_template_key text,
  p_to_email     text,
  p_to_name      text DEFAULT NULL,
  p_variables    jsonb DEFAULT '{}'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  INSERT INTO email_queue (template_key, to_email, to_name, variables)
  VALUES (p_template_key, p_to_email, p_to_name, p_variables)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.queue_email(text, text, text, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.queue_email(text, text, text, jsonb) TO authenticated;

SELECT 'Email system ready — ' || COUNT(*) || ' templates' AS status
FROM email_templates;

-- ── Add missing columns to email_queue ────────────────────────────────
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS status     text        NOT NULL DEFAULT 'pending';
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS sent_at    timestamptz;
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS error_msg  text;
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT NOW();
-- Enforce correct status constraint immediately — not deferred to end of file
ALTER TABLE public.email_queue DROP CONSTRAINT IF EXISTS email_queue_status_check;
ALTER TABLE public.email_queue ADD CONSTRAINT email_queue_status_check
  CHECK (status IN ('pending','sending','sent','failed'));

-- Index for efficient queue polling
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON public.email_queue(status, created_at);

-- ── Email templates for all key events ────────────────────────────────
INSERT INTO email_templates (key, name, subject, body) VALUES

('recipe_approved',
 'Recipe Approved',
 'Your recipe has been published! 🎉',
 '<h2>Your recipe is live!</h2><p>Hi {{name}},</p><p><strong>{{recipe_name}}</strong> has been approved and is now published on The Culinary Journal.</p><p><a href="{{site_url}}/recipe-page.html?id={{recipe_id}}">View your recipe →</a></p>')

ON CONFLICT (key) DO NOTHING;

INSERT INTO email_templates (key, name, subject, body) VALUES

('recipe_rejected',
 'Recipe Not Approved',
 'Update on your recipe submission',
 '<h2>Recipe update</h2><p>Hi {{name}},</p><p>Your recipe <strong>{{recipe_name}}</strong> was not approved at this time.</p><p><em>{{reviewer_notes}}</em></p><p>You can edit and resubmit from your <a href="{{site_url}}/my-dashboard.html">dashboard</a>.</p>')

ON CONFLICT (key) DO NOTHING;

INSERT INTO email_templates (key, name, subject, body) VALUES

('note_approved',
 'Cooking Tip Approved',
 'Your cooking tip has been published',
 '<h2>Your tip is live!</h2><p>Hi {{name}},</p><p>Your cooking tip for <strong>{{recipe_name}}</strong> has been approved and is now visible to other members.</p>')

ON CONFLICT (key) DO NOTHING;

SELECT 'Email templates updated' AS status;

-- Status constraint enforced above, immediately after ADD COLUMN.

-- ── Add retry tracking columns ─────────────────────────────────────────
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS attempts        integer     NOT NULL DEFAULT 0;
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS last_attempt_at timestamptz;


SELECT pg_notify('pgrst', 'reload schema');
