-- ================================================================
-- MIGRATION 063: FIX STRUCTURE (COLONNES MANQUANTES)
-- À EXÉCUTER DANS SUPABASE SQL EDITOR
-- ================================================================

BEGIN;

-- 1️⃣ TABLE SALES : Ajout colonnes manquantes
ALTER TABLE sales ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE sales ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS items_count INTEGER DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'paid';

-- Créer index pour accélérer la sync
CREATE INDEX IF NOT EXISTS idx_sales_user_id ON sales(user_id);
CREATE INDEX IF NOT EXISTS idx_sales_updated_at ON sales(updated_at);

-- 2️⃣ TABLE SALE_ITEMS : Ajout colonnes manquantes (C'est celle qui bloquait !)
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id);

-- Créer index
CREATE INDEX IF NOT EXISTS idx_sale_items_user_id ON sale_items(user_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_updated_at ON sale_items(updated_at);

-- 3️⃣ TRIGGERS : Mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_sales_updated_at ON sales;
CREATE TRIGGER update_sales_updated_at
    BEFORE UPDATE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sale_items_updated_at ON sale_items;
CREATE TRIGGER update_sale_items_updated_at
    BEFORE UPDATE ON sale_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;

-- ✅ VÉRIFICATION FINALE (Optionnel)
-- Vous devriez voir "updated_at" dans la liste des colonnes de sale_items après ça.
