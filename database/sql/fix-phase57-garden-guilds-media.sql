-- fix-phase57-garden-guilds-media.sql
-- Guild admin RPCs, plant media register RPC, sample guild seeds.
-- Safe to re-run.

CREATE OR REPLACE FUNCTION public.admin_upsert_guild(p_row jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_slug text := lower(regexp_replace(COALESCE(p_row->>'slug', p_row->>'name', ''), '[^a-z0-9]+', '-', 'g'));
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF v_slug IS NULL OR v_slug = '' THEN RAISE EXCEPTION 'slug required'; END IF;
  v_slug := trim(both '-' from v_slug);

  INSERT INTO public.guilds (slug, name, description, is_published)
  VALUES (
    v_slug,
    COALESCE(NULLIF(btrim(p_row->>'name'), ''), initcap(replace(v_slug, '-', ' '))),
    NULLIF(btrim(p_row->>'description'), ''),
    COALESCE((p_row->>'is_published')::boolean, false)
  )
  ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_published = COALESCE((p_row->>'is_published')::boolean, guilds.is_published);

  SELECT id INTO v_id FROM public.guilds WHERE slug = v_slug LIMIT 1;
  RETURN jsonb_build_object('id', v_id, 'slug', v_slug);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_guild_member(
  p_guild_slug text,
  p_plant_slug text,
  p_role text DEFAULT NULL,
  p_remove boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_guild uuid;
  v_plant uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;

  SELECT id INTO v_guild FROM public.guilds WHERE slug = p_guild_slug LIMIT 1;
  IF v_guild IS NULL THEN RAISE EXCEPTION 'guild not found: %', p_guild_slug; END IF;

  SELECT id INTO v_plant FROM public.plants WHERE slug = p_plant_slug LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found: %', p_plant_slug; END IF;

  IF COALESCE(p_remove, false) THEN
    DELETE FROM public.guild_members WHERE guild_id = v_guild AND plant_id = v_plant;
    RETURN jsonb_build_object('guild_slug', p_guild_slug, 'plant_slug', p_plant_slug, 'removed', true);
  END IF;

  DELETE FROM public.guild_members WHERE guild_id = v_guild AND plant_id = v_plant;
  INSERT INTO public.guild_members (guild_id, plant_id, role)
  VALUES (v_guild, v_plant, NULLIF(btrim(p_role), ''));

  RETURN jsonb_build_object('guild_slug', p_guild_slug, 'plant_slug', p_plant_slug, 'role', p_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_register_plant_media(
  p_plant_slug text,
  p_bucket_path text,
  p_alt_text text DEFAULT NULL,
  p_is_primary boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plant uuid;
  v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;

  SELECT id INTO v_plant FROM public.plants WHERE slug = p_plant_slug LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found: %', p_plant_slug; END IF;
  IF p_bucket_path IS NULL OR btrim(p_bucket_path) = '' THEN RAISE EXCEPTION 'bucket_path required'; END IF;

  IF COALESCE(p_is_primary, false) THEN
    UPDATE public.media SET is_primary = false
    WHERE entity_type = 'plant' AND entity_id = v_plant;
  END IF;

  INSERT INTO public.media (bucket_path, alt_text, entity_type, entity_id, is_primary)
  VALUES (btrim(p_bucket_path), NULLIF(btrim(p_alt_text), ''), 'plant', v_plant, COALESCE(p_is_primary, false))
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'plant_slug', p_plant_slug, 'bucket_path', btrim(p_bucket_path));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_remove_plant_media(p_media_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  DELETE FROM public.media WHERE id = p_media_id AND entity_type = 'plant';
  RETURN jsonb_build_object('deleted', p_media_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_guild(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_guild_member(text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_register_plant_media(text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_plant_media(uuid) TO authenticated;

-- Sample guilds (draft until published in GM)
DO $$
DECLARE v_guild uuid;
BEGIN
  INSERT INTO public.guilds (slug, name, description, is_published)
  VALUES (
    'mediterranean-kitchen',
    'Mediterranean kitchen guild',
    'Tomato, basil, and artichoke polyculture — shared pollinators and kitchen harvest rhythm.',
    false
  )
  ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

  SELECT id INTO v_guild FROM public.guilds WHERE slug = 'mediterranean-kitchen' LIMIT 1;
  IF v_guild IS NOT NULL THEN
    DELETE FROM public.guild_members gm
    USING public.plants p
    WHERE gm.guild_id = v_guild AND gm.plant_id = p.id AND p.slug IN ('tomato', 'basil', 'artichoke');
    INSERT INTO public.guild_members (guild_id, plant_id, role)
    SELECT v_guild, p.id, m.role FROM (VALUES
      ('tomato', 'fruiting crop'),
      ('basil', 'companion / herb'),
      ('artichoke', 'structural perennial')
    ) AS m(slug, role)
    JOIN public.plants p ON p.slug = m.slug;
  END IF;

  INSERT INTO public.guilds (slug, name, description, is_published)
  VALUES (
    'cool-season-brassica',
    'Cool-season brassica guild',
    'Broccoli and peas — nitrogen support and staggered cool-season harvest.',
    false
  )
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

  SELECT id INTO v_guild FROM public.guilds WHERE slug = 'cool-season-brassica' LIMIT 1;
  IF v_guild IS NOT NULL THEN
    DELETE FROM public.guild_members gm
    USING public.plants p
    WHERE gm.guild_id = v_guild AND gm.plant_id = p.id AND p.slug IN ('broccoli', 'peas');
    INSERT INTO public.guild_members (guild_id, plant_id, role)
    SELECT v_guild, p.id, m.role FROM (VALUES
      ('broccoli', 'brassica crop'),
      ('peas', 'nitrogen fixer')
    ) AS m(slug, role)
    JOIN public.plants p ON p.slug = m.slug;
  END IF;
END $$;

SELECT 'fix-phase57-garden-guilds-media ready — guild RPCs + 2 sample guilds' AS status;
