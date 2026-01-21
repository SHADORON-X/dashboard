-- Migration: Cleanup malformed records in sync_queue
-- Date: 26 December 2025
-- Purpose: Remove orphaned sync_queue records without valid id/velmo_id

-- ============================================================
-- 1. DELETE MALFORMED RECORDS
-- ============================================================

-- Delete records where id is NULL or empty
DELETE FROM sync_queue 
WHERE 
    (data->>'id' IS NULL OR data->>'id' = '')
    AND (data->>'velmo_id' IS NULL OR data->>'velmo_id' = '');

-- Log the cleanup
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    SELECT count(*) INTO deleted_count FROM sync_queue 
    WHERE (data->>'id' IS NULL OR data->>'id' = '')
    AND (data->>'velmo_id' IS NULL OR data->>'velmo_id' = '');
    
    RAISE NOTICE '[Cleanup] Deleted % malformed records from sync_queue', deleted_count;
END $$;

-- ============================================================
-- 2. ADD VALIDATION TRIGGER
-- ============================================================

-- Create trigger to prevent future malformed records
CREATE OR REPLACE FUNCTION validate_sync_queue_record()
RETURNS TRIGGER AS $$
BEGIN
    -- Check that either id or velmo_id exists and is not NULL
    IF (
        (NEW.data->>'id' IS NULL OR NEW.data->>'id' = '')
        AND (NEW.data->>'velmo_id' IS NULL OR NEW.data->>'velmo_id' = '')
    ) THEN
        RAISE EXCEPTION 'Malformed sync_queue record: either id or velmo_id must be provided';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_queue_validation_trigger ON sync_queue;

-- Create trigger
CREATE TRIGGER sync_queue_validation_trigger
BEFORE INSERT OR UPDATE ON sync_queue
FOR EACH ROW
EXECUTE FUNCTION validate_sync_queue_record();

-- ============================================================
-- 3. VERIFY CLEANUP
-- ============================================================

-- Check remaining records
SELECT 
    table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN data->>'id' IS NOT NULL THEN 1 END) as with_id,
    COUNT(CASE WHEN data->>'velmo_id' IS NOT NULL THEN 1 END) as with_velmo_id
FROM sync_queue
GROUP BY table_name;
