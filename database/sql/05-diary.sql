-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 05-diary.sql
-- Diary entries table + RPCs
-- Run in Supabase SQL Editor after 04-auth-triggers.sql
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.diary_entries (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_date  date        NOT NULL,
  title       text        DEFAULT '',
  content     text        DEFAULT '',
  entry_type  text        DEFAULT 'general',
  mood        text        DEFAULT '',
  tags        text[]      DEFAULT '{}',
  is_private  boolean     DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

ALTER TABLE public.diary_entries ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.diary_entries TO authenticated;

DROP POLICY IF EXISTS "Users manage own diary" ON public.diary_entries;
CREATE POLICY "Users manage own diary"
  ON public.diary_entries FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Get entries for a specific month
DROP FUNCTION IF EXISTS public.get_my_diary_entries(int, int);
CREATE FUNCTION public.get_my_diary_entries(p_year int, p_month int)
RETURNS SETOF public.diary_entries
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT * FROM public.diary_entries
    WHERE user_id = auth.uid()
      AND EXTRACT(YEAR  FROM entry_date) = p_year
      AND EXTRACT(MONTH FROM entry_date) = p_month
    ORDER BY entry_date DESC, created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_diary_entries(int,int) TO authenticated;

-- Get all entries for search
DROP FUNCTION IF EXISTS public.search_my_diary(text);
CREATE FUNCTION public.search_my_diary(p_query text)
RETURNS SETOF public.diary_entries
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT * FROM public.diary_entries
    WHERE user_id = auth.uid()
      AND (title ILIKE '%'||p_query||'%' OR content ILIKE '%'||p_query||'%'
           OR p_query = ANY(tags))
    ORDER BY entry_date DESC LIMIT 50;
END;
$$;
GRANT EXECUTE ON FUNCTION public.search_my_diary(text) TO authenticated;

-- Upsert a diary entry
DROP FUNCTION IF EXISTS public.upsert_diary_entry(uuid,date,text,text,text,text,text[],boolean);
CREATE FUNCTION public.upsert_diary_entry(
  p_id         uuid    DEFAULT NULL,
  p_date       date    DEFAULT CURRENT_DATE,
  p_title      text    DEFAULT '',
  p_content    text    DEFAULT '',
  p_type       text    DEFAULT 'general',
  p_mood       text    DEFAULT '',
  p_tags       text[]  DEFAULT '{}',
  p_is_private boolean DEFAULT true
)
RETURNS public.diary_entries
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result public.diary_entries;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.diary_entries
      (user_id, entry_date, title, content, entry_type, mood, tags, is_private)
    VALUES (auth.uid(), p_date, p_title, p_content, p_type, p_mood,
            COALESCE(p_tags,'{}'), p_is_private)
    RETURNING * INTO result;
  ELSE
    UPDATE public.diary_entries SET
      entry_date = p_date, title = p_title, content = p_content,
      entry_type = p_type, mood = p_mood, tags = COALESCE(p_tags,'{}'),
      is_private = p_is_private, updated_at = now()
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_diary_entry(uuid,date,text,text,text,text,text[],boolean) TO authenticated;

-- Delete a diary entry
DROP FUNCTION IF EXISTS public.delete_diary_entry(uuid);
CREATE FUNCTION public.delete_diary_entry(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.diary_entries WHERE id = p_id AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_diary_entry(uuid) TO authenticated;

-- Diary stats (streak + count)
DROP FUNCTION IF EXISTS public.get_diary_stats();
CREATE FUNCTION public.get_diary_stats()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  total_count  bigint;
  this_month   bigint;
  streak       int := 0;
  check_date   date := CURRENT_DATE;
BEGIN
  IF auth.uid() IS NULL THEN RETURN '{}'; END IF;
  SELECT COUNT(*) INTO total_count FROM public.diary_entries WHERE user_id = auth.uid();
  SELECT COUNT(*) INTO this_month  FROM public.diary_entries
    WHERE user_id = auth.uid()
      AND EXTRACT(YEAR FROM entry_date)  = EXTRACT(YEAR FROM CURRENT_DATE)
      AND EXTRACT(MONTH FROM entry_date) = EXTRACT(MONTH FROM CURRENT_DATE);
  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.diary_entries
      WHERE user_id = auth.uid() AND entry_date = check_date
    );
    streak     := streak + 1;
    check_date := check_date - 1;
  END LOOP;
  RETURN json_build_object('total', total_count, 'this_month', this_month, 'streak', streak);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_diary_stats() TO authenticated;
