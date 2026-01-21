-- Fix RLS policies for sales and sale_items
-- Enable RLS
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any to avoid conflicts (optional, but good for idempotency)
DROP POLICY IF EXISTS "Users can insert sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users can update sales for their shops" ON sales;
DROP POLICY IF EXISTS "Users can insert sale_items for their shops" ON sale_items;

-- Policy for INSERT on sales
CREATE POLICY "Users can insert sales for their shops"
ON sales FOR INSERT
WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
  OR
  shop_id IN (
    SELECT id FROM shops WHERE owner_id = auth.uid()
  )
);

-- Policy for UPDATE on sales
CREATE POLICY "Users can update sales for their shops"
ON sales FOR UPDATE
USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
  OR
  shop_id IN (
    SELECT id FROM shops WHERE owner_id = auth.uid()
  )
);

-- Policy for INSERT on sale_items
CREATE POLICY "Users can insert sale_items for their shops"
ON sale_items FOR INSERT
WITH CHECK (
  sale_id IN (
    SELECT id FROM sales WHERE shop_id IN (
        SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
    ) OR shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  )
);

-- Policy for SELECT on sale_items (if not already present)
CREATE POLICY "Users can view sale_items for their shops"
ON sale_items FOR SELECT
USING (
  sale_id IN (
    SELECT id FROM sales WHERE shop_id IN (
        SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
    ) OR shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  )
);
