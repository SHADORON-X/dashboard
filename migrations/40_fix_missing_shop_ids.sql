-- ================================================================
-- 🔧 MIGRATION 40: FIX MISSING SHOP_IDs
-- ================================================================
-- Date: 30 Décembre 2025
-- Objectif: Réparer tous les shop_id manquants/NULL pour permettre
--           la synchronisation locale avec WatermelonDB
-- ================================================================

-- **IMPORTANT**: Remplacer '667fad42-e96a-48a7-990d-59a15d4d3a93' par le vrai shop_id si différent

BEGIN;

-- 1. PRODUCTS - Corriger tous les shop_id NULL
UPDATE products
SET shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
WHERE shop_id IS NULL;

-- 2. SALES - Corriger tous les shop_id NULL
UPDATE sales
SET shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
WHERE shop_id IS NULL;

-- 3. DEBTS - Corriger tous les shop_id NULL
UPDATE debts
SET shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
WHERE shop_id IS NULL;

-- 4. ORDERS - Corriger tous les shop_id NULL
UPDATE orders
SET shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
WHERE shop_id IS NULL;

-- 7. VERIFY - Afficher les résultats
SELECT 
  'products' AS table_name,
  COUNT(*) AS fixed_count
FROM products
WHERE shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
UNION ALL
SELECT 
  'sales' AS table_name,
  COUNT(*) AS fixed_count
FROM sales
WHERE shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
UNION ALL
SELECT 
  'debts' AS table_name,
  COUNT(*) AS fixed_count
FROM debts
WHERE shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93'
UNION ALL
SELECT 
  'orders' AS table_name,
  COUNT(*) AS fixed_count
FROM orders
WHERE shop_id = '667fad42-e96a-48a7-990d-59a15d4d3a93';

COMMIT;
