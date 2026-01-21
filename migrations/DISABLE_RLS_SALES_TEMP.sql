-- ================================================================
-- TEMPORARY FIX: Disable RLS on sales tables for deployment
-- Date: 2025-12-30
-- Status: TEMPORARY - Re-enable after testing
-- ================================================================

-- Disable RLS on sales table to allow sync to pull data
ALTER TABLE sales DISABLE ROW LEVEL SECURITY;

-- Disable RLS on sale_items table to allow sync to pull data
ALTER TABLE sale_items DISABLE ROW LEVEL SECURITY;

-- Verify RLS status
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('sales', 'sale_items') 
AND schemaname = 'public';

-- ================================================================
-- IMPORTANT: Re-enable after deployment with:
-- ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
-- ================================================================
