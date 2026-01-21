-- ================================================================
-- TEMP FIX: Disable RLS on shops to prevent recursion errors
-- Date: 2025-01-02
-- Status: TEMPORARY - Re-enable after debugging
-- ================================================================

BEGIN;

-- Disable RLS on shops table to prevent infinite recursion
ALTER TABLE shops DISABLE ROW LEVEL SECURITY;

COMMIT;

-- ================================================================
-- When ready to re-enable:
-- ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
-- ================================================================
