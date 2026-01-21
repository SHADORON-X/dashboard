-- 1. FIX: Update existing sales with missing velmo_id (Server Side)
-- This fixes any sales that might have slipped in without a velmo_id
UPDATE sales
SET velmo_id = 'S-' || id
WHERE velmo_id IS NULL;

-- 2. PROTECTION: Enforce velmo_id presence
-- This ensures no future sales can be inserted without a velmo_id
ALTER TABLE sales
ALTER COLUMN velmo_id SET NOT NULL;

-- 3. INDEX: Ensure uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_velmo_id ON sales (velmo_id);
