-- ================================================================
-- MIGRATION 070: DEPRECATED - Use 071 instead
-- ================================================================
-- This migration is replaced by 071_fix_function_overload.sql
-- which fixes the function parameter order issue
-- ================================================================

-- No-op migration
DO $$
BEGIN
    RAISE NOTICE '⏭️ Migration 070: Skipped (see 071_fix_function_overload.sql)';
END $$;

