-- Migration 23: Add status field to sales table
-- This migration aligns with WatermelonDB schema version 23

-- Add status column to sales table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sales' AND column_name = 'status'
    ) THEN
        ALTER TABLE sales ADD COLUMN status TEXT DEFAULT 'paid';
    END IF;
END $$;

-- Create index on status for better query performance
CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status);

-- Update existing sales to have 'paid' status if null
UPDATE sales SET status = 'paid' WHERE status IS NULL;

-- Add comment
COMMENT ON COLUMN sales.status IS 'Sale status: paid, debt, cancelled';
