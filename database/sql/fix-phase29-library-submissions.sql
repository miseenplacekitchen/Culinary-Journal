-- ══════════════════════════════════════════════════════════════════════
-- fix-phase29-library-submissions.sql — Member library profile submissions
-- Safe to re-run
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.library_profile_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_type text NOT NULL CHECK (profile_type IN ('ingredient','spice','tool','cut','preservation')),
  slug text,
  payload jsonb NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewer_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_library_submissions_status ON public.library_profile_submissions(status);
CREATE INDEX IF NOT EXISTS idx_library_submissions_user ON public.library_profile_submissions(user_id);

ALTER TABLE public.library_profile_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS library_submissions_own ON public.library_profile_submissions;
CREATE POLICY library_submissions_own ON public.library_profile_submissions
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS library_submissions_insert ON public.library_profile_submissions;
CREATE POLICY library_submissions_insert ON public.library_profile_submissions
  FOR INSERT WITH CHECK (auth.uid() = user_id AND status = 'pending');

DROP FUNCTION IF EXISTS public.submit_library_profile_submission(text, text, jsonb);
CREATE OR REPLACE FUNCTION public.submit_library_profile_submission(
  p_profile_type text,
  p_slug text,
  p_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  INSERT INTO library_profile_submissions (user_id, profile_type, slug, payload, status)
  VALUES (auth.uid(), p_profile_type, NULLIF(trim(p_slug), ''), COALESCE(p_payload, '{}'), 'pending')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_library_profile_submission(text, text, jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_submissions(text, int);
CREATE OR REPLACE FUNCTION public.admin_get_library_submissions(p_status text DEFAULT 'pending', p_limit int DEFAULT 50)
RETURNS SETOF library_profile_submissions
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  RETURN QUERY
  SELECT * FROM library_profile_submissions
  WHERE (p_status IS NULL OR status = p_status)
  ORDER BY created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_library_submissions(text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_review_library_submission(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_review_library_submission(
  p_id uuid,
  p_action text,
  p_notes text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE sub library_profile_submissions%ROWTYPE;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  SELECT * INTO sub FROM library_profile_submissions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  IF p_action = 'reject' THEN
    UPDATE library_profile_submissions SET status = 'rejected', reviewer_notes = p_notes, reviewed_at = now() WHERE id = p_id;
    RETURN true;
  ELSIF p_action = 'approve' THEN
    UPDATE library_profile_submissions SET status = 'approved', reviewer_notes = p_notes, reviewed_at = now() WHERE id = p_id;
    RETURN true;
  END IF;
  RAISE EXCEPTION 'invalid_action';
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_library_submission(uuid, text, text) TO authenticated;

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Submit Library Profile', 'library-submit.html', 'registered', 95, 'free')
ON CONFLICT (path) DO UPDATE SET name = EXCLUDED.name, visibility = EXCLUDED.visibility;

SELECT 'fix-phase29-library-submissions.sql complete' AS status;
