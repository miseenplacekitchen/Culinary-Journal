-- ── User Management SQL ───────────────────────────────────────────
-- Run this entire block in Supabase SQL Editor

-- ── 1. Add columns to profiles table ────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS flagged              BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deactivation_type    TEXT      CHECK (deactivation_type IN ('temporary','permanent')),
  ADD COLUMN IF NOT EXISTS deactivation_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deactivation_reason  TEXT,
  ADD COLUMN IF NOT EXISTS plan                 TEXT      NOT NULL DEFAULT 'free' CHECK (plan IN ('free','premium')),
  ADD COLUMN IF NOT EXISTS last_active_at       TIMESTAMPTZ;

-- ── 2. User badges table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_badges (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge       TEXT NOT NULL,
  awarded_by  TEXT,
  awarded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, badge)
);
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_badges;
CREATE POLICY "Admin full access" ON public.user_badges FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 3. User internal notes table ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_notes (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  note        TEXT NOT NULL,
  created_by  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_notes;
CREATE POLICY "Admin full access" ON public.user_notes FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 4. User invites table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_invites (
  id          BIGSERIAL PRIMARY KEY,
  email       TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'contributor' CHECK (role IN ('contributor','guest_chef')),
  message     TEXT,
  token       TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32),'hex'),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','expired')),
  invited_by  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 days'),
  accepted_at TIMESTAMPTZ
);
ALTER TABLE public.user_invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_invites;
CREATE POLICY "Admin full access" ON public.user_invites FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 5. Reports table ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_reports (
  id              BIGSERIAL PRIMARY KEY,
  reporter_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipe_id       UUID,
  reason          TEXT NOT NULL,
  details         TEXT,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed','actioned')),
  reviewed_by     TEXT,
  reviewed_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_reports;
CREATE POLICY "Admin full access" ON public.user_reports FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 6. Recipe requests table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_requests (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  request_text    TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','fulfilled','declined')),
  notes           TEXT,
  fulfilled_recipe_id UUID,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.recipe_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.recipe_requests;
CREATE POLICY "Admin full access" ON public.recipe_requests FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 7. User feedback table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_feedback (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  feedback    TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'general' CHECK (type IN ('general','recipe','bug','suggestion')),
  status      TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewed','actioned','dismissed')),
  recipe_id   UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_feedback;
CREATE POLICY "Admin full access" ON public.user_feedback FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 8. Get users (paginated, filtered) ───────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_users(text, text, int, int);
CREATE OR REPLACE FUNCTION public.admin_get_users(
  p_search  TEXT    DEFAULT NULL,
  p_status  TEXT    DEFAULT NULL,
  p_limit   INT     DEFAULT 50,
  p_offset  INT     DEFAULT 0
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_agg(row_to_json(t)) FROM (
    SELECT
      p.id, u.email, p.full_name, p.username, p.is_active, p.is_admin,
      p.theme_preference, p.created_at, p.avatar_url, p.flagged,
      p.deactivation_type, p.deactivation_expires_at, p.deactivation_reason, p.plan,
      CASE
        WHEN p.is_active = false AND p.deactivation_type = 'permanent' THEN 'Permanently Deactivated'
        WHEN p.is_active = false AND p.deactivation_type = 'temporary' THEN 'Temporarily Deactivated'
        WHEN p.is_active = false THEN 'Deactivated'
        WHEN p.flagged = true THEN 'Flagged'
        WHEN p.is_admin = true THEN 'Administrator'
        ELSE 'Active'
      END as account_status,
      COALESCE((SELECT COUNT(*) FROM public.submitted_recipes r WHERE r.user_id = p.id),0) as recipe_count,
      COALESCE((SELECT COUNT(*) FROM public.submitted_recipes r WHERE r.user_id = p.id AND r.status = 'approved'),0) as approved_count,
      COALESCE((SELECT json_agg(b.badge) FROM public.user_badges b WHERE b.user_id = p.id),'[]'::json) as badges
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE (
      p_search IS NULL OR p_search = '' OR
      p.full_name ILIKE '%'||p_search||'%' OR
      p.username  ILIKE '%'||p_search||'%' OR
      u.email     ILIKE '%'||p_search||'%'
    )
    AND (
      p_status IS NULL OR p_status = '' OR
      (p_status = 'active'      AND p.is_active = true  AND p.flagged = false AND p.is_admin = false) OR
      (p_status = 'admin'       AND p.is_admin  = true) OR
      (p_status = 'flagged'     AND p.flagged   = true) OR
      (p_status = 'deactivated' AND p.is_active = false)
    )
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;

-- ── 9. Count users ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_count_users(text, text);
CREATE OR REPLACE FUNCTION public.admin_count_users(
  p_search TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_count FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
  WHERE (
    p_search IS NULL OR p_search = '' OR
    p.full_name ILIKE '%'||p_search||'%' OR
    p.username  ILIKE '%'||p_search||'%' OR
    u.email     ILIKE '%'||p_search||'%'
  )
  AND (
    p_status IS NULL OR p_status = '' OR
    (p_status = 'active'      AND p.is_active = true  AND p.flagged = false AND p.is_admin = false) OR
    (p_status = 'admin'       AND p.is_admin  = true) OR
    (p_status = 'flagged'     AND p.flagged   = true) OR
    (p_status = 'deactivated' AND p.is_active = false)
  );
  RETURN v_count;
END;
$$;

-- ── 10. Get full user detail ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_user_detail(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_user_detail(p_user_id UUID)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'profile', (
      SELECT row_to_json(t) FROM (
        SELECT p.*,
          CASE
            WHEN p.is_active = false AND p.deactivation_type = 'permanent' THEN 'Permanently Deactivated'
            WHEN p.is_active = false AND p.deactivation_type = 'temporary' THEN 'Temporarily Deactivated'
            WHEN p.is_active = false THEN 'Deactivated'
            WHEN p.flagged = true THEN 'Flagged'
            WHEN p.is_admin = true THEN 'Administrator'
            ELSE 'Active'
          END as account_status,
          COALESCE((SELECT json_agg(b.badge ORDER BY b.awarded_at) FROM public.user_badges b WHERE b.user_id = p.id), '[]'::json) as badges
        FROM public.profiles p WHERE p.id = p_user_id
      ) t
    ),
    'recipe_count',   (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id),
    'approved_count', (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id AND status = 'approved'),
    'rejected_count', (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id AND status = 'rejected'),
    'pending_count',  (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id AND status = 'pending'),
    'recent_recipes', (SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
      SELECT recipe_name as title, status FROM public.submitted_recipes
      WHERE user_id = p_user_id ORDER BY submitted_at DESC LIMIT 10
    ) t),
    'notes', (SELECT COALESCE(json_agg(row_to_json(n) ORDER BY n.created_at DESC),'[]'::json)
              FROM public.user_notes n WHERE n.user_id = p_user_id)
  ) INTO result;
  RETURN result;
END;
$$;

-- ── 11. Deactivate user ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_deactivate_user(uuid, text, integer, text);
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_user_id UUID, p_type TEXT, p_days INT DEFAULT NULL, p_reason TEXT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active              = false,
    deactivation_type      = p_type,
    deactivation_expires_at = CASE WHEN p_type = 'temporary' AND p_days IS NOT NULL THEN now() + (p_days || ' days')::interval ELSE NULL END,
    deactivation_reason    = p_reason
  WHERE id = p_user_id;
END;
$$;

-- ── 12. Reactivate user ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_reactivate_user(uuid);
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active = true, deactivation_type = NULL,
    deactivation_expires_at = NULL, deactivation_reason = NULL
  WHERE id = p_user_id;
END;
$$;

-- ── 13. Award badge ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_award_badge(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_award_badge(p_user_id UUID, p_badge TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.user_badges (user_id, badge, awarded_by)
  VALUES (p_user_id, p_badge, (SELECT username FROM public.profiles WHERE id = auth.uid()))
  ON CONFLICT (user_id, badge) DO NOTHING;
END;
$$;

-- ── 14. Remove badge ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_remove_badge(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_remove_badge(p_user_id UUID, p_badge TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.user_badges WHERE user_id = p_user_id AND badge = p_badge;
END;
$$;

-- ── 15. Add internal note ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_add_user_note(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_add_user_note(p_user_id UUID, p_note TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.user_notes (user_id, note, created_by)
  VALUES (p_user_id, p_note, (SELECT username FROM public.profiles WHERE id = auth.uid()));
END;
$$;

-- ── 16. Flag/unflag user ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_flag_user(uuid, boolean);
CREATE OR REPLACE FUNCTION public.admin_flag_user(p_user_id UUID, p_flagged BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET flagged = p_flagged WHERE id = p_user_id;
END;
$$;

-- ── 17. Set admin status ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_set_admin_status(uuid, boolean);
CREATE OR REPLACE FUNCTION public.admin_set_admin_status(p_user_id UUID, p_is_admin BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET is_admin = p_is_admin WHERE id = p_user_id;
END;
$$;

-- ── 18. Get invites ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_invites();
CREATE OR REPLACE FUNCTION public.admin_get_invites()
RETURNS SETOF public.user_invites
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  -- Auto-expire old invites
  UPDATE public.user_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at < now();
  RETURN QUERY SELECT * FROM public.user_invites ORDER BY created_at DESC;
END;
$$;

-- ── 19. Create invite ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_create_invite(text, text, text);
CREATE OR REPLACE FUNCTION public.admin_create_invite(
  p_email TEXT, p_role TEXT DEFAULT 'contributor', p_message TEXT DEFAULT NULL
)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_token TEXT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  v_token := encode(gen_random_bytes(32),'hex');
  INSERT INTO public.user_invites (email, role, message, token, invited_by)
  VALUES (p_email, p_role, p_message, v_token,
    (SELECT username FROM public.profiles WHERE id = auth.uid()));
  RETURN v_token;
END;
$$;

-- ── 20. Count pending users (for badge) ──────────────────────────
DROP FUNCTION IF EXISTS public.admin_count_pending_users();
CREATE OR REPLACE FUNCTION public.admin_count_pending_users()
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_count FROM public.profiles WHERE is_active = false;
  RETURN v_count;
END;
$$;

-- ── 21. User analytics ────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_user_analytics();
CREATE OR REPLACE FUNCTION public.admin_get_user_analytics()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'total',         (SELECT COUNT(*) FROM public.profiles),
    'active',        (SELECT COUNT(*) FROM public.profiles WHERE is_active = true AND flagged = false),
    'deactivated',   (SELECT COUNT(*) FROM public.profiles WHERE is_active = false),
    'flagged',       (SELECT COUNT(*) FROM public.profiles WHERE flagged = true),
    'admins',        (SELECT COUNT(*) FROM public.profiles WHERE is_admin = true),
    'new_this_week', (SELECT COUNT(*) FROM public.profiles WHERE created_at > now() - interval '7 days'),
    'new_this_month',(SELECT COUNT(*) FROM public.profiles WHERE created_at > now() - interval '30 days'),
    'top_contributors', (
      SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
        SELECT p.full_name, p.username,
          COUNT(r.id) as recipe_count
        FROM public.profiles p
        JOIN public.submitted_recipes r ON r.user_id = p.id AND r.status = 'approved'
        GROUP BY p.id, p.full_name, p.username
        ORDER BY recipe_count DESC LIMIT 10
      ) t
    ),
    'growth', (
      SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
        SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'Mon YY') as month,
               COUNT(*) as count
        FROM public.profiles
        WHERE created_at > now() - interval '6 months'
        GROUP BY DATE_TRUNC('month', created_at)
        ORDER BY DATE_TRUNC('month', created_at)
      ) t
    )
  ) INTO result;
  RETURN result;
END;
$$;

-- ── 22. Get reports ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_reports(text, int, int);
CREATE OR REPLACE FUNCTION public.admin_get_reports(
  p_status TEXT DEFAULT NULL, p_limit INT DEFAULT 100, p_offset INT DEFAULT 0
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
    SELECT r.*,
      rep.username as reporter_username, rep.full_name as reporter_name,
      rep2.username as reported_username, rep2.full_name as reported_name
    FROM public.user_reports r
    LEFT JOIN public.profiles rep  ON rep.id  = r.reporter_id
    LEFT JOIN public.profiles rep2 ON rep2.id = r.reported_user_id
    WHERE (p_status IS NULL OR r.status = p_status)
    ORDER BY r.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t INTO result;
  RETURN result;
END;
$$;

-- ── 23. Update report status ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_report(bigint, text);
CREATE OR REPLACE FUNCTION public.admin_update_report(
  p_id BIGINT, p_status TEXT
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.user_reports SET
    status = p_status, reviewed_at = now(),
    reviewed_by = (SELECT username FROM public.profiles WHERE id = auth.uid())
  WHERE id = p_id;
END;
$$;

-- ── 24. Get recipe requests ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipe_requests(text);
CREATE OR REPLACE FUNCTION public.admin_get_recipe_requests(
  p_status TEXT DEFAULT NULL
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
    SELECT rr.*, p.username, p.full_name
    FROM public.recipe_requests rr
    LEFT JOIN public.profiles p ON p.id = rr.user_id
    WHERE (p_status IS NULL OR rr.status = p_status)
    ORDER BY rr.created_at DESC
  ) t INTO result;
  RETURN result;
END;
$$;

-- ── 25. Update recipe request ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_recipe_request(bigint, text, text);
CREATE OR REPLACE FUNCTION public.admin_update_recipe_request(
  p_id BIGINT, p_status TEXT, p_notes TEXT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_requests SET status = p_status, notes = p_notes, updated_at = now()
  WHERE id = p_id;
END;
$$;

-- ── 26. Get feedback ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_feedback(text);
CREATE OR REPLACE FUNCTION public.admin_get_feedback(
  p_status TEXT DEFAULT NULL
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
    SELECT f.*, p.username, p.full_name
    FROM public.user_feedback f
    LEFT JOIN public.profiles p ON p.id = f.user_id
    WHERE (p_status IS NULL OR f.status = p_status)
    ORDER BY f.created_at DESC
  ) t INTO result;
  RETURN result;
END;
$$;

-- ── 27. Update feedback ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_feedback(bigint, text);
CREATE OR REPLACE FUNCTION public.admin_update_feedback(
  p_id BIGINT, p_status TEXT
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.user_feedback SET status = p_status WHERE id = p_id;
END;
$$;

-- ── Grant all ─────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_get_users(text,text,integer,integer)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_count_users(text,text)                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_user_detail(uuid)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_user(uuid,text,integer,text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_user(uuid)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_award_badge(uuid,text)                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_badge(uuid,text)                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_user_note(uuid,text)                       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_flag_user(uuid,boolean)                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_admin_status(uuid,boolean)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_invites()                                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_invite(text,text,text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_count_pending_users()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_user_analytics()                           TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_reports(text,integer,integer)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_report(bigint,text)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_recipe_requests(text)                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_recipe_request(bigint,text,text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_feedback(text)                             TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_feedback(bigint,text)                   TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── update_avatar_url — called from profile.html ──────────────────
DROP FUNCTION IF EXISTS public.update_avatar_url(text);
CREATE FUNCTION public.update_avatar_url(p_url text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE profiles SET avatar_url = p_url, last_seen = now() WHERE id = auth.uid();
END; $$;
REVOKE ALL ON FUNCTION public.update_avatar_url(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.update_avatar_url(text) TO authenticated;
SELECT pg_notify('pgrst', 'reload schema'); -- reload after update_avatar_url
