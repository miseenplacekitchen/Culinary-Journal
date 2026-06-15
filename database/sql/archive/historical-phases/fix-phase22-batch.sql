-- ══════════════════════════════════════════════════════════════════════
-- fix-phase22-batch.sql — Lane 3: household grocery + library links
-- Safe to re-run. Run after fix-phase21-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

-- ── GL-11: Household sharing (partner login, shared grocery) ─────────
CREATE TABLE IF NOT EXISTS public.households (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name               text NOT NULL DEFAULT 'Our Kitchen',
  owner_id           uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  grocery_list_data  jsonb NOT NULL DEFAULT '{"version":2,"recipes":[],"items":[]}'::jsonb,
  grocery_checked    jsonb NOT NULL DEFAULT '[]'::jsonb,
  grocery_updated_at timestamptz NOT NULL DEFAULT now(),
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.household_members (
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role         text NOT NULL DEFAULT 'member' CHECK (role IN ('owner','member')),
  joined_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (household_id, user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS household_members_one_per_user
  ON public.household_members (user_id);

CREATE TABLE IF NOT EXISTS public.household_invites (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id   uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  invitee_email  text NOT NULL,
  invited_by     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status         text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','accepted','declined','cancelled')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL DEFAULT (now() + interval '14 days')
);

CREATE UNIQUE INDEX IF NOT EXISTS household_invites_one_pending
  ON public.household_invites (household_id, lower(invitee_email))
  WHERE status = 'pending';

ALTER TABLE public.households ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members read own household" ON public.households;
CREATE POLICY "members read own household" ON public.households
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.household_members hm
    WHERE hm.household_id = households.id AND hm.user_id = auth.uid()
  ) OR is_admin());

DROP POLICY IF EXISTS "members read household roster" ON public.household_members;
CREATE POLICY "members read household roster" ON public.household_members
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.household_members hm
    WHERE hm.household_id = household_members.household_id AND hm.user_id = auth.uid()
  ) OR is_admin());

DROP POLICY IF EXISTS "users read own invites" ON public.household_invites;
CREATE POLICY "users read own invites" ON public.household_invites
  FOR SELECT TO authenticated
  USING (
    invited_by = auth.uid()
    OR lower(invitee_email) = lower(COALESCE(
      (SELECT email FROM public.profiles WHERE id = auth.uid()), ''))
    OR is_admin()
  );

-- Internal helper
CREATE OR REPLACE FUNCTION public._my_household_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT household_id FROM public.household_members WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._merge_grocery_lists(a jsonb, b jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  out jsonb := COALESCE(a, '{"version":2,"recipes":[],"items":[]}'::jsonb);
  rec jsonb;
  it jsonb;
BEGIN
  out := jsonb_set(out, '{version}', '2'::jsonb, true);
  IF b IS NULL THEN RETURN out; END IF;
  FOR rec IN SELECT * FROM jsonb_array_elements(COALESCE(b->'recipes', '[]'::jsonb))
  LOOP
    out := jsonb_set(out, '{recipes}', COALESCE(out->'recipes','[]'::jsonb) || rec, true);
  END LOOP;
  FOR it IN SELECT * FROM jsonb_array_elements(COALESCE(b->'items', '[]'::jsonb))
  LOOP
    out := jsonb_set(out, '{items}', COALESCE(out->'items','[]'::jsonb) || it, true);
  END LOOP;
  RETURN out;
END;
$$;

-- ── Grocery RPCs: personal OR shared household list ───────────────────
DROP FUNCTION IF EXISTS public.get_my_grocery_list();
CREATE FUNCTION public.get_my_grocery_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  h_id uuid;
  h_row public.households%ROWTYPE;
  p_row public.grocery_lists%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    SELECT * INTO h_row FROM public.households WHERE id = h_id;
    RETURN jsonb_build_object(
      'list_data', h_row.grocery_list_data,
      'checked', h_row.grocery_checked,
      'updated_at', h_row.grocery_updated_at,
      'shared', true,
      'household_id', h_id,
      'household_name', h_row.name
    );
  END IF;
  SELECT * INTO p_row FROM public.grocery_lists WHERE user_id = auth.uid();
  RETURN jsonb_build_object(
    'list_data', COALESCE(p_row.list_data, '{"version":2,"recipes":[],"items":[]}'::jsonb),
    'checked', COALESCE(p_row.checked, '[]'::jsonb),
    'updated_at', COALESCE(p_row.updated_at, now()),
    'shared', false,
    'household_id', null,
    'household_name', null
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_grocery_list() TO authenticated;

DROP FUNCTION IF EXISTS public.save_my_grocery_list(jsonb, jsonb);
CREATE FUNCTION public.save_my_grocery_list(p_list_data jsonb, p_checked jsonb DEFAULT '[]')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    UPDATE public.households SET
      grocery_list_data = p_list_data,
      grocery_checked = COALESCE(p_checked, '[]'::jsonb),
      grocery_updated_at = now()
    WHERE id = h_id;
    RETURN;
  END IF;
  INSERT INTO public.grocery_lists (user_id, list_data, checked, updated_at)
  VALUES (auth.uid(), p_list_data, COALESCE(p_checked, '[]'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE SET
    list_data = EXCLUDED.list_data,
    checked = EXCLUDED.checked,
    updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_grocery_list(jsonb, jsonb) TO authenticated;

-- ── Household RPCs ───────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_my_household();
CREATE FUNCTION public.get_my_household()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NULL THEN RETURN NULL; END IF;
  RETURN (
    SELECT jsonb_build_object(
      'id', h.id,
      'name', h.name,
      'owner_id', h.owner_id,
      'my_role', hm.role,
      'member_count', (SELECT count(*)::int FROM public.household_members x WHERE x.household_id = h.id),
      'members', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'user_id', m.user_id,
          'username', p.username,
          'full_name', p.full_name,
          'role', m.role,
          'joined_at', m.joined_at
        ) ORDER BY m.joined_at)
        FROM public.household_members m
        JOIN public.profiles p ON p.id = m.user_id
        WHERE m.household_id = h.id
      ), '[]'::jsonb),
      'pending_invites', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'id', i.id,
          'invitee_email', i.invitee_email,
          'created_at', i.created_at,
          'expires_at', i.expires_at
        ) ORDER BY i.created_at DESC)
        FROM public.household_invites i
        WHERE i.household_id = h.id AND i.status = 'pending' AND i.expires_at > now()
      ), '[]'::jsonb)
    )
    FROM public.households h
    JOIN public.household_members hm ON hm.household_id = h.id AND hm.user_id = auth.uid()
    WHERE h.id = h_id
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_household() TO authenticated;

DROP FUNCTION IF EXISTS public.get_pending_household_invites();
CREATE FUNCTION public.get_pending_household_invites()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE my_email text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT lower(email) INTO my_email FROM public.profiles WHERE id = auth.uid();
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', i.id,
      'household_id', i.household_id,
      'household_name', h.name,
      'invited_by_name', p.full_name,
      'invitee_email', i.invitee_email,
      'expires_at', i.expires_at
    ) ORDER BY i.created_at DESC)
    FROM public.household_invites i
    JOIN public.households h ON h.id = i.household_id
    JOIN public.profiles p ON p.id = i.invited_by
    WHERE i.status = 'pending' AND i.expires_at > now()
      AND lower(i.invitee_email) = my_email
  ), '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_pending_household_invites() TO authenticated;

DROP FUNCTION IF EXISTS public.create_household(text);
CREATE FUNCTION public.create_household(p_name text DEFAULT 'Our Kitchen')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
  personal jsonb;
  personal_checked jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF public._my_household_id() IS NOT NULL THEN RAISE EXCEPTION 'Already in a household'; END IF;
  SELECT list_data, checked INTO personal, personal_checked
  FROM public.grocery_lists WHERE user_id = auth.uid();
  INSERT INTO public.households (name, owner_id, grocery_list_data, grocery_checked)
  VALUES (COALESCE(NULLIF(btrim(p_name), ''), 'Our Kitchen'), auth.uid(),
          COALESCE(personal, '{"version":2,"recipes":[],"items":[]}'::jsonb),
          COALESCE(personal_checked, '[]'::jsonb))
  RETURNING id INTO h_id;
  INSERT INTO public.household_members (household_id, user_id, role)
  VALUES (h_id, auth.uid(), 'owner');
  RETURN h_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_household(text) TO authenticated;

DROP FUNCTION IF EXISTS public.invite_household_member(text);
CREATE FUNCTION public.invite_household_member(p_email text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
  invite_id uuid;
  member_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_email IS NULL OR btrim(p_email) = '' THEN RAISE EXCEPTION 'Email required'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NULL THEN RAISE EXCEPTION 'No household'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.household_members
    WHERE household_id = h_id AND user_id = auth.uid() AND role = 'owner'
  ) THEN RAISE EXCEPTION 'Only the household owner can invite'; END IF;
  SELECT count(*)::int INTO member_count FROM public.household_members WHERE household_id = h_id;
  IF member_count >= 2 THEN RAISE EXCEPTION 'Household is full (owner + partner)'; END IF;
  IF lower(btrim(p_email)) = lower((SELECT email FROM public.profiles WHERE id = auth.uid())) THEN
    RAISE EXCEPTION 'Cannot invite yourself';
  END IF;
  UPDATE public.household_invites SET status = 'cancelled'
  WHERE household_id = h_id AND lower(invitee_email) = lower(btrim(p_email)) AND status = 'pending';
  INSERT INTO public.household_invites (household_id, invitee_email, invited_by)
  VALUES (h_id, lower(btrim(p_email)), auth.uid())
  RETURNING id INTO invite_id;
  RETURN invite_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.invite_household_member(text) TO authenticated;

DROP FUNCTION IF EXISTS public.accept_household_invite(uuid);
CREATE FUNCTION public.accept_household_invite(p_invite_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv public.household_invites%ROWTYPE;
  my_email text;
  personal jsonb;
  personal_checked jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF public._my_household_id() IS NOT NULL THEN RAISE EXCEPTION 'Already in a household'; END IF;
  SELECT lower(email) INTO my_email FROM public.profiles WHERE id = auth.uid();
  SELECT * INTO inv FROM public.household_invites
  WHERE id = p_invite_id AND status = 'pending' AND expires_at > now();
  IF NOT FOUND THEN RAISE EXCEPTION 'Invite not found or expired'; END IF;
  IF lower(inv.invitee_email) <> my_email THEN RAISE EXCEPTION 'Invite is for a different email'; END IF;
  SELECT list_data, checked INTO personal, personal_checked
  FROM public.grocery_lists WHERE user_id = auth.uid();
  UPDATE public.households SET
    grocery_list_data = public._merge_grocery_lists(grocery_list_data, personal),
    grocery_checked = grocery_checked || COALESCE(personal_checked, '[]'::jsonb),
    grocery_updated_at = now()
  WHERE id = inv.household_id;
  INSERT INTO public.household_members (household_id, user_id, role)
  VALUES (inv.household_id, auth.uid(), 'member');
  UPDATE public.household_invites SET status = 'accepted' WHERE id = p_invite_id;
  DELETE FROM public.grocery_lists WHERE user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_household_invite(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.decline_household_invite(uuid);
CREATE FUNCTION public.decline_household_invite(p_invite_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE my_email text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT lower(email) INTO my_email FROM public.profiles WHERE id = auth.uid();
  UPDATE public.household_invites SET status = 'declined'
  WHERE id = p_invite_id AND status = 'pending' AND lower(invitee_email) = my_email;
END;
$$;
GRANT EXECUTE ON FUNCTION public.decline_household_invite(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.leave_household();
CREATE FUNCTION public.leave_household()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
  my_role text;
  member_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT household_id, role INTO h_id, my_role
  FROM public.household_members WHERE user_id = auth.uid();
  IF h_id IS NULL THEN RAISE EXCEPTION 'Not in a household'; END IF;
  SELECT count(*)::int INTO member_count FROM public.household_members WHERE household_id = h_id;
  IF my_role = 'owner' AND member_count > 1 THEN
    RAISE EXCEPTION 'Transfer or remove your partner before leaving';
  END IF;
  DELETE FROM public.household_members WHERE household_id = h_id AND user_id = auth.uid();
  IF member_count <= 1 THEN
    DELETE FROM public.households WHERE id = h_id;
  END IF;
  INSERT INTO public.grocery_lists (user_id, list_data, checked)
  VALUES (auth.uid(), '{"version":2,"recipes":[],"items":[]}'::jsonb, '[]'::jsonb)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;
GRANT EXECUTE ON FUNCTION public.leave_household() TO authenticated;

DROP FUNCTION IF EXISTS public.remove_household_member(uuid);
CREATE FUNCTION public.remove_household_member(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NULL THEN RAISE EXCEPTION 'No household'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.household_members
    WHERE household_id = h_id AND user_id = auth.uid() AND role = 'owner'
  ) THEN RAISE EXCEPTION 'Only owner can remove members'; END IF;
  IF p_user_id = auth.uid() THEN RAISE EXCEPTION 'Use leave_household instead'; END IF;
  DELETE FROM public.household_members WHERE household_id = h_id AND user_id = p_user_id;
  INSERT INTO public.grocery_lists (user_id, list_data, checked)
  VALUES (p_user_id, '{"version":2,"recipes":[],"items":[]}'::jsonb, '[]'::jsonb)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;
GRANT EXECUTE ON FUNCTION public.remove_household_member(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.cancel_household_invite(uuid);
CREATE FUNCTION public.cancel_household_invite(p_invite_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
BEGIN
  h_id := public._my_household_id();
  UPDATE public.household_invites SET status = 'cancelled'
  WHERE id = p_invite_id AND household_id = h_id AND status = 'pending'
    AND invited_by = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.cancel_household_invite(uuid) TO authenticated;

-- ── Library: link governed ingredients → ingredient profiles ─────────
ALTER TABLE public.ingredient_profiles
  ADD COLUMN IF NOT EXISTS governed_ingredient_id integer;

CREATE INDEX IF NOT EXISTS ingredient_profiles_gov_id_idx
  ON public.ingredient_profiles (governed_ingredient_id)
  WHERE governed_ingredient_id IS NOT NULL;

DROP FUNCTION IF EXISTS public.get_library_links_for_ingredients(integer[]);
CREATE FUNCTION public.get_library_links_for_ingredients(p_ids integer[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN '{}'::jsonb; END IF;
  RETURN COALESCE((
    SELECT jsonb_object_agg(governed_ingredient_id::text, jsonb_build_object('slug', slug, 'name', name))
    FROM public.ingredient_profiles
    WHERE governed_ingredient_id = ANY(p_ids) AND status = 'published'
  ), '{}'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_library_links_for_ingredients(integer[]) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.admin_link_library_ingredient(uuid, integer);
CREATE FUNCTION public.admin_link_library_ingredient(p_profile_id uuid, p_ingredient_id integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.ingredient_profiles
  SET governed_ingredient_id = p_ingredient_id, updated_at = now()
  WHERE id = p_profile_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_link_library_ingredient(uuid, integer) TO authenticated;

-- ── Stripe scaffolding (manual checkout until keys configured) ────────
INSERT INTO public.site_settings (key, value) VALUES
  ('stripe_enabled', 'false'),
  ('stripe_checkout_mode', 'manual')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Household', 'household.html', 'registered', 15, 'free')
ON CONFLICT (path) DO NOTHING;

SELECT 'fix-phase22-batch.sql complete' AS status;
