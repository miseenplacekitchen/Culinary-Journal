-- fix-email-system.sql — Wire lifecycle emails, clean templates, helper queue function
-- Safe to re-run. Run in Supabase SQL Editor after email_templates.sql / fix-phase6.

-- ── RLS cleanup (duplicate policies) ─────────────────────────────────
DROP POLICY IF EXISTS "admin manages email templates" ON public.email_templates;
DROP POLICY IF EXISTS "Admin manages email templates" ON public.email_templates;
CREATE POLICY "Admin manages email templates" ON public.email_templates
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "Anon cannot read email templates" ON public.email_templates;
CREATE POLICY "Anon cannot read email templates" ON public.email_templates
  FOR SELECT TO anon USING (false);

-- ── Canonical templates (single source; ON CONFLICT updates) ───────
-- Placeholders: name, site_url, recipe_name, recipe_id, recipe_url, rejection_reason,
--   reason, message, subject, author, product_name, tier_label, amount_line, recipes_url

INSERT INTO public.email_templates (key, name, subject, body, updated_at) VALUES
('welcome',
 'Welcome',
 'Welcome to The Culinary Journal',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Welcome, {{name}} 🍳</h2><p>Your account is ready. <a href="{{recipes_url}}">Explore recipes →</a></p>',
 NOW()),
('recipe_approved',
 'Recipe Approved',
 'Your recipe has been published ✓',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Your recipe is live 🎉</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> has been published. <a href="{{recipe_url}}">View it →</a></p>',
 NOW()),
('recipe_rejected',
 'Recipe Not Approved',
 'Update on your recipe submission',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#e8e0d4">Recipe not approved</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> was not approved at this time.</p><p><strong>Reason:</strong> {{rejection_reason}}</p><p><a href="{{site_url}}/draft-recipes.html">View your drafts →</a></p>',
 NOW()),
('account_deactivated',
 'Account Deactivated',
 'Your account has been deactivated',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#dc5050">Account deactivated</h2><p>Hi {{name}}, your account has been deactivated.</p><p><strong>Reason:</strong> {{reason}}</p><p>Reply to this email to appeal.</p>',
 NOW()),
('request_fulfilled',
 'Recipe Request Fulfilled',
 'Your recipe request has been fulfilled ✓',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Request fulfilled 🍽</h2><p>Hi {{name}}, the recipe you requested — <strong>{{recipe_name}}</strong> — is now live. <a href="{{recipe_url}}">View it →</a></p>',
 NOW()),
('note_approved',
 'Cooking Tip Approved',
 'Your cooking tip has been published',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Your tip is live</h2><p>Hi {{name}}, your cooking tip for <strong>{{recipe_name}}</strong> has been approved and is visible to other members.</p>',
 NOW()),
('follow_new_recipe',
 'Follow — New Recipe',
 '{{author}} published a new recipe',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">New from {{author}}</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> is now live. <a href="{{recipe_url}}">View recipe →</a></p>',
 NOW()),
('custom',
 'Admin Custom Message',
 '{{subject}}',
 '<p>Hi {{name}},</p><div style="white-space:pre-wrap">{{message}}</div>',
 NOW())
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  updated_at = NOW();

-- ── Internal queue helper (called from other SECURITY DEFINER RPCs) ───
CREATE OR REPLACE FUNCTION public.tcj_queue_member_email(
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
  IF p_to_email IS NULL OR btrim(p_to_email) = '' THEN RETURN NULL; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'email_queue'
  ) THEN RETURN NULL; END IF;
  INSERT INTO public.email_queue (template_key, to_email, to_name, variables, status)
  VALUES (p_template_key, btrim(p_to_email), COALESCE(NULLIF(btrim(p_to_name), ''), 'Member'), COALESCE(p_variables, '{}'::jsonb), 'pending')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.tcj_queue_member_email(text, text, text, jsonb) FROM PUBLIC;

-- ── Recipe approve / reject + follower notify ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid;
  v_name text;
  v_msg text;
  v_email text;
  v_username text;
  v_author text;
  v_vis text;
  v_site text := 'https://www.theculinaryjournal.site';
  v_follower record;
  v_has_approved_at boolean;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT user_id, recipe_name, visibility INTO v_user_id, v_name, v_vis
  FROM public.submitted_recipes WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'submitted_recipes' AND column_name = 'approved_at'
  ) INTO v_has_approved_at;

  IF v_has_approved_at THEN
    UPDATE public.submitted_recipes
    SET status = p_status, reviewer_notes = p_notes, reviewed_at = now(),
        approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END
    WHERE id = p_id;
  ELSE
    UPDATE public.submitted_recipes
    SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
    WHERE id = p_id;
  END IF;

  IF v_user_id IS NOT NULL AND p_status IN ('approved', 'rejected') THEN
    v_msg := CASE p_status
      WHEN 'approved' THEN 'Your recipe "' || COALESCE(v_name, 'submission') || '" was approved and is now live!'
      ELSE 'Your recipe "' || COALESCE(v_name, 'submission') || '" needs updates.'
           || CASE WHEN COALESCE(p_notes, '') <> '' THEN ' ' || p_notes ELSE '' END
    END;
    INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (
      v_user_id,
      CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id, v_name, v_msg
    );

    SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
    INTO v_email, v_username
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_user_id;

    IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
      PERFORM public.tcj_queue_member_email(
        CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
        v_email,
        v_username,
        jsonb_build_object(
          'name', v_username,
          'recipe_name', COALESCE(v_name, 'your recipe'),
          'recipe_id', p_id::text,
          'recipe_url', v_site || '/recipe-page.html?id=' || p_id::text,
          'site_url', v_site,
          'rejection_reason', COALESCE(p_notes, '')
        )
      );
    END IF;

    IF p_status = 'approved' AND COALESCE(v_vis, 'Public') IN ('Public', 'Friends') THEN
      SELECT COALESCE(username, full_name, 'A contributor') INTO v_author
      FROM public.profiles WHERE id = v_user_id;
      FOR v_follower IN
        SELECT cf.follower_id AS uid
        FROM public.contributor_follows cf
        WHERE cf.following_id = v_user_id
      LOOP
        SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
        INTO v_email, v_username
        FROM public.profiles p
        LEFT JOIN auth.users u ON u.id = p.id
        WHERE p.id = v_follower.uid;
        IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
          INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
          VALUES (
            v_follower.uid, 'follow_new_recipe', p_id, v_name,
            COALESCE(v_author, 'A contributor you follow') || ' published: ' || COALESCE(v_name, 'a new recipe')
          );
          PERFORM public.tcj_queue_member_email(
            'follow_new_recipe',
            v_email,
            v_username,
            jsonb_build_object(
              'name', v_username,
              'author', COALESCE(v_author, 'A contributor'),
              'recipe_name', COALESCE(v_name, 'a new recipe'),
              'recipe_url', v_site || '/recipe-page.html?id=' || p_id::text,
              'site_url', v_site
            )
          );
        END IF;
      END LOOP;
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;

-- ── Welcome email on onboarding complete ─────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_my_onboarding(
  p_dietary_preferences text[] DEFAULT '{}',
  p_allergies           text[] DEFAULT '{}',
  p_health_conditions   text[] DEFAULT '{}',
  p_cooking_style       text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_email text;
  v_name text;
  v_site text := 'https://www.theculinaryjournal.site';
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.profiles SET
    dietary_preferences   = COALESCE(p_dietary_preferences, '{}'),
    allergies             = COALESCE(p_allergies, '{}'),
    health_conditions     = COALESCE(p_health_conditions, '{}'),
    cooking_style         = COALESCE(NULLIF(trim(p_cooking_style), ''), cooking_style, ''),
    onboarding_completed  = true
  WHERE id = auth.uid();

  SELECT u.email, COALESCE(p.full_name, p.username, 'Member')
  INTO v_email, v_name
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE p.id = auth.uid();

  IF v_email IS NOT NULL AND btrim(v_email) <> '' AND NOT EXISTS (
    SELECT 1 FROM public.email_queue
    WHERE to_email = v_email AND template_key = 'welcome'
      AND status IN ('pending', 'sending', 'sent')
  ) THEN
    PERFORM public.tcj_queue_member_email(
      'welcome', v_email, v_name,
      jsonb_build_object('name', v_name, 'site_url', v_site, 'recipes_url', v_site || '/recipes.html')
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.complete_my_onboarding(text[],text[],text[],text) TO authenticated;

-- ── Account deactivation email ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_user_id uuid, p_type text, p_days int DEFAULT NULL, p_reason text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_email text; v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active = false,
    deactivation_type = p_type,
    deactivation_expires_at = CASE WHEN p_type = 'temporary' AND p_days IS NOT NULL
      THEN now() + (p_days || ' days')::interval ELSE NULL END,
    deactivation_reason = p_reason
  WHERE id = p_user_id;

  SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
  INTO v_email, v_name
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE p.id = p_user_id;

  IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
    PERFORM public.tcj_queue_member_email(
      'account_deactivated', v_email, v_name,
      jsonb_build_object('name', v_name, 'reason', COALESCE(p_reason, 'No reason provided'))
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_user(uuid, text, integer, text) TO authenticated;

-- ── Cooking note approved email ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_review_note(p_id bigint, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid;
  v_recipe_name text;
  v_email text;
  v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE public.recipe_public_notes
  SET status = p_status, reviewed_at = NOW(), reviewer_id = auth.uid()
  WHERE id = p_id;

  IF p_status = 'approved' THEN
    SELECT n.user_id, COALESCE(r.recipe_name, 'a recipe')
    INTO v_user_id, v_recipe_name
    FROM public.recipe_public_notes n
    LEFT JOIN public.submitted_recipes r ON r.id = n.recipe_id
    WHERE n.id = p_id;

    IF v_user_id IS NOT NULL THEN
      SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
      INTO v_email, v_name
      FROM public.profiles p
      LEFT JOIN auth.users u ON u.id = p.id
      WHERE p.id = v_user_id;

      IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
        PERFORM public.tcj_queue_member_email(
          'note_approved', v_email, v_name,
          jsonb_build_object('name', v_name, 'recipe_name', v_recipe_name)
        );
      END IF;
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_note(bigint, text) TO authenticated;

-- ── Recipe request fulfilled email ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_update_recipe_request(
  p_id bigint, p_status text, p_notes text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row public.recipe_requests%ROWTYPE;
  v_email text;
  v_name text;
  v_recipe_name text;
  v_site text := 'https://www.theculinaryjournal.site';
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_requests
  SET status = p_status, notes = p_notes, updated_at = now()
  WHERE id = p_id
  RETURNING * INTO v_row;

  IF p_status = 'fulfilled' AND v_row.user_id IS NOT NULL THEN
    SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
    INTO v_email, v_name
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_row.user_id;

    v_recipe_name := COALESCE(v_row.request_text, 'your requested recipe');
    IF v_row.fulfilled_recipe_id IS NOT NULL THEN
      SELECT recipe_name INTO v_recipe_name
      FROM public.submitted_recipes WHERE id = v_row.fulfilled_recipe_id;
      v_recipe_name := COALESCE(v_recipe_name, 'your requested recipe');
    END IF;

    IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
      PERFORM public.tcj_queue_member_email(
        'request_fulfilled', v_email, v_name,
        jsonb_build_object(
          'name', v_name,
          'recipe_name', v_recipe_name,
          'recipe_url', CASE WHEN v_row.fulfilled_recipe_id IS NOT NULL
            THEN v_site || '/recipe-page.html?id=' || v_row.fulfilled_recipe_id::text
            ELSE v_site || '/recipes.html' END,
          'site_url', v_site
        )
      );
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_recipe_request(bigint, text, text) TO authenticated;

-- ── Delete single queue row (admin) ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_delete_email_queue(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.email_queue WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_email_queue(uuid) TO authenticated;

SELECT 'fix-email-system.sql complete — ' || COUNT(*) || ' templates' AS status
FROM public.email_templates;

SELECT pg_notify('pgrst', 'reload schema');
