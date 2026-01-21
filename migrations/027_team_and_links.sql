-- 027_team_and_links.sql

-- 1. Types ENUM (s'ils n'existent pas déjà, on utilise IF NOT EXISTS ou on gère les erreurs, ici on crée propre)
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('owner', 'manager', 'cashier', 'member');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE request_status AS ENUM ('pending', 'accepted', 'rejected', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE link_type AS ENUM ('supplier', 'reseller', 'partner');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. TABLE: shop_members
CREATE TABLE IF NOT EXISTS shop_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    role user_role DEFAULT 'member',
    permissions JSONB DEFAULT '{}',
    status request_status DEFAULT 'accepted',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shop_id, user_id)
);

-- 3. TABLE: shop_requests (Demandes d'adhésion)
CREATE TABLE IF NOT EXISTS shop_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_shop_id UUID REFERENCES shops(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    status request_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABLE: shop_links (Relations B2B)
CREATE TABLE IF NOT EXISTS shop_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_a_id UUID REFERENCES shops(id) NOT NULL,
    shop_b_id UUID REFERENCES shops(id) NOT NULL,
    type link_type NOT NULL,
    status request_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shop_a_id, shop_b_id)
);

-- Activation RLS
ALTER TABLE shop_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_links ENABLE ROW LEVEL SECURITY;

-- Policies shop_members
DROP POLICY IF EXISTS "Members view own" ON shop_members;
CREATE POLICY "Members view own" ON shop_members FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Owners manage members" ON shop_members;
CREATE POLICY "Owners manage members" ON shop_members FOR ALL USING (
    EXISTS (SELECT 1 FROM shops WHERE id = shop_members.shop_id AND owner_id = auth.uid())
);

-- Policies shop_requests
DROP POLICY IF EXISTS "Users create requests" ON shop_requests;
CREATE POLICY "Users create requests" ON shop_requests FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own requests" ON shop_requests;
CREATE POLICY "Users view own requests" ON shop_requests FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Owners view shop requests" ON shop_requests;
CREATE POLICY "Owners view shop requests" ON shop_requests FOR SELECT USING (
    EXISTS (SELECT 1 FROM shops WHERE id = shop_requests.target_shop_id AND owner_id = auth.uid())
);

DROP POLICY IF EXISTS "Owners manage shop requests" ON shop_requests;
CREATE POLICY "Owners manage shop requests" ON shop_requests FOR UPDATE USING (
    EXISTS (SELECT 1 FROM shops WHERE id = shop_requests.target_shop_id AND owner_id = auth.uid())
);

-- RPC: Rechercher une boutique par son code (shop_code) pour rejoindre
CREATE OR REPLACE FUNCTION search_shop_for_join(shop_code text)
RETURNS TABLE (
    id uuid,
    shop_id text,
    name text,
    category text,
    city text,
    owner_name text
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id, 
        s.shop_code,
        s.name, 
        s.category,
        s.address as city, 
        (u.first_name || ' ' || u.last_name) as owner_name
    FROM shops s
    LEFT JOIN users u ON s.owner_id = u.id
    WHERE s.shop_code = shop_code
    AND s.is_active = true
    LIMIT 1;
    LIMIT 1;
END;
$$;
