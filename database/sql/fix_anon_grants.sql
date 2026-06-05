-- ══════════════════════════════════════════════════════════════════════
-- Remove anon grants from admin functions
-- Uses to_regprocedure() to match exact signatures safely
-- Returns NULL (not an error) if the signature does not exist
-- ══════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF to_regprocedure('public.admin_rename_extra_field(text, text)') IS NOT NULL THEN
    REVOKE ALL   ON FUNCTION public.admin_rename_extra_field(text, text) FROM anon;
    GRANT EXECUTE ON FUNCTION public.admin_rename_extra_field(text, text) TO authenticated;
  END IF;
END; $$;

DO $$ BEGIN
  IF to_regprocedure('public.admin_get_deleted_extra_fields()') IS NOT NULL THEN
    REVOKE ALL   ON FUNCTION public.admin_get_deleted_extra_fields() FROM anon;
    GRANT EXECUTE ON FUNCTION public.admin_get_deleted_extra_fields() TO authenticated;
  END IF;
END; $$;

DO $$ BEGIN
  IF to_regprocedure('public.admin_delete_extra_field(text)') IS NOT NULL THEN
    REVOKE ALL   ON FUNCTION public.admin_delete_extra_field(text) FROM anon;
    GRANT EXECUTE ON FUNCTION public.admin_delete_extra_field(text) TO authenticated;
  END IF;
END; $$;

SELECT 'Anon grants fixed' AS status;
