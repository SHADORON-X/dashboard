import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import supabase from '../lib/supabase';
import type {
    PlatformStats,
    ShopOverview,
    DailySales,
    RealtimeActivity,
    StockAlert,
    CriticalAuditEvent,
    Shop,
    Sale,
    User,
    UserStatus,
    ShopStatus,
    CustomerOrder,
    Shop as DatabaseShop
} from '../types/database';

// ============================================
// QUERY KEYS
// ============================================

export const queryKeys = {
    platformStats: ['platformStats'] as const,
    shopsOverview: (page: number, limit: number) => ['shopsOverview', page, limit] as const,
    shopDetails: (shopId: string) => ['shopDetails', shopId] as const,
    dailySales: (days: number) => ['dailySales', days] as const,
    realtimeActivity: ['realtimeActivity'] as const,
    stockAlerts: (page: number, limit: number) => ['stockAlerts', page, limit] as const,
    criticalEvents: (page: number, limit: number) => ['criticalEvents', page, limit] as const,
    searchShops: (query: string) => ['searchShops', query] as const,
    topShops: (limit: number) => ['topShops', limit] as const,
    allUsers: (page: number, limit: number, search?: string) => ['allUsers', page, limit, search] as const,
    allProducts: (page: number, limit: number, search?: string) => ['allProducts', page, limit, search] as const,
    allSales: (page: number, limit: number) => ['allSales', page, limit] as const,
    allDebts: (page: number, limit: number) => ['allDebts', page, limit] as const,
    userDetails: (userId: string) => ['userDetails', userId] as const,
    productDetails: (productId: string) => ['productDetails', productId] as const,
    saleDetails: (saleId: string) => ['saleDetails', saleId] as const,
    debtDetails: (debtId: string) => ['debtDetails', debtId] as const,
    customerOrders: (page: number, limit: number, shopId?: string) => ['customerOrders', page, limit, shopId] as const,
    shopOnlineSettings: (shopId: string) => ['shopOnlineSettings', shopId] as const,
};

// ============================================
// IMAGE RESOLVER UTILITY
// ============================================

/**
 * Résout une URL d'image à partir d'un chemin stocké en base.
 * Gère les URL complètes, les chemins relatifs Supabase et les chemins mobiles.
 */
export function resolveImageUrl(path: string | null, bucket: 'products' | 'avatars' = 'products'): string | null {
    if (!path) return null;

    // 1. Déjà une URL complète
    if (path.startsWith('http')) return path;

    // 2. Chemin local mobile (Legacy / Bug App) -> Essayer de trouver une version cloud
    if (path.startsWith('file:///')) {
        const filename = path.split('/').pop();
        if (filename) {
            return supabase.storage.from(bucket).getPublicUrl(filename).data.publicUrl;
        }
        return null;
    }

    // 3. Chemin relatif Supabase
    return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

// ============================================
// PLATFORM STATS (Via Vue SQL)
// ============================================

export function usePlatformStats() {
    return useQuery({
        queryKey: queryKeys.platformStats,
        queryFn: async (): Promise<PlatformStats> => {
            const { data, error } = await supabase
                .from('v_admin_platform_stats')
                .select('*')
                .single();

            if (error) {
                console.error("❌ Erreur Fetch Platform Stats (Vue SQL manquante ?):", error);
                throw error;
            }
            return data as PlatformStats;
        },
        staleTime: 30000,
    });
}

// ============================================
// SHOPS OVERVIEW
// ============================================

export function useShopsOverview(page = 1, limit = 20) {
    return useQuery({
        queryKey: queryKeys.shopsOverview(page, limit),
        queryFn: async () => {
            const offset = (page - 1) * limit;

            const { data, error, count } = await supabase
                .from('v_admin_shops_overview')
                .select('*', { count: 'exact' })
                .range(offset, offset + limit - 1);

            if (error) {
                console.error("❌ Erreur Fetch Shops Overview (Vue SQL manquante ?):", error);
                throw error;
            }

            return {
                data: (data || []) as ShopOverview[],
                total: count || 0,
                page,
                limit,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
        staleTime: 30000,
    });
}

export function useSearchShops(query: string) {
    return useQuery({
        queryKey: queryKeys.searchShops(query),
        queryFn: async () => {
            if (!query || query.length < 2) return [];
            const { data, error } = await supabase
                .from('v_admin_shops_overview')
                .select('*')
                .or(`shop_name.ilike.%${query}%,shop_velmo_id.ilike.%${query}%,owner_name.ilike.%${query}%`)
                .limit(20);

            if (error) throw error;
            return (data || []) as ShopOverview[];
        },
        enabled: query.length >= 2,
    });
}

// ============================================
// SHOP DETAILS
// ============================================

export function useShopDetails(shopId: string | null) {
    return useQuery({
        queryKey: queryKeys.shopDetails(shopId || ''),
        queryFn: async () => {
            if (!shopId) return null;

            try {
                // 1. Récupérer la boutique
                const { data: shopResult, error: shopError } = await supabase
                    .from('shops')
                    .select('*')
                    .eq('id', shopId)
                    .maybeSingle();

                if (shopError) throw shopError;
                const shop = (shopResult as unknown) as Shop;
                if (!shop) throw new Error("Boutique introuvable");

                // 2. Paralléliser les requêtes de données
                const [ownerResult, salesResult, productsResult, debtsResult, membersResult] = await Promise.all([
                    supabase.from('users').select('*').eq('id', shop.owner_id).maybeSingle(),
                    supabase.from('sales').select('*').eq('shop_id', shopId).order('created_at', { ascending: false }).limit(20),
                    supabase.from('products').select('*').eq('shop_id', shopId).eq('is_active', true),
                    supabase.from('debts').select('*').eq('shop_id', shopId).neq('status', 'paid'),
                    supabase.from('shop_members').select('*, users:user_id(first_name, last_name, phone, role)').eq('shop_id', shopId),
                ]);

                // 3. Calculer les stats de base
                const now = new Date();
                const startOfDay = new Date(now.setHours(0, 0, 0, 0)).toISOString();

                const sales = (salesResult.data || []) as Sale[];
                const products = (productsResult.data || []) as any[];

                const salesToday = sales.filter(s => s.created_at >= startOfDay);
                const revenueToday = salesToday.reduce((acc, s) => acc + (Number(s.total_amount) || 0), 0);
                const profitToday = salesToday.reduce((acc, s) => acc + (Number(s.total_profit) || 0), 0);

                const activeDebts = (debtsResult.data || []) as any[];
                const lowStockProducts = products.filter(p => p.quantity <= (p.stock_alert || 0));

                return {
                    shop,
                    owner: (ownerResult.data as unknown) as User || null,
                    stats: {
                        revenue_today: revenueToday,
                        profit_today: profitToday,
                        sales_today: salesToday.length,
                        low_stock_count: lowStockProducts.length,
                        active_debts: activeDebts.length,
                        total_debt_amount: activeDebts.reduce((acc, d) => acc + (Number(d.remaining_amount) || 0), 0)
                    },
                    recent_sales: sales,
                    low_stock_products: lowStockProducts,
                    active_debts: activeDebts,
                    team: (membersResult.data || []) as any[]
                };
            } catch (err) {
                console.error("Error in useShopDetails:", err);
                throw err;
            }
        },
        enabled: !!shopId,
        staleTime: 30000,
    });
}

// ============================================
// ANALYTICS & ACTIVITY
// ============================================

export function useDailySales(days = 30) {
    return useQuery({
        queryKey: queryKeys.dailySales(days),
        queryFn: async () => {
            const { data, error } = await supabase
                .from('v_admin_daily_sales')
                .select('*')
                .limit(days);

            if (error) throw error;
            return (data || []) as DailySales[];
        },
        staleTime: 300000, // 5 min
    });
}

export function useRealtimeActivity(limit = 10) {
    return useQuery({
        queryKey: queryKeys.realtimeActivity,
        queryFn: async () => {
            const { data, error } = await supabase
                .from('v_admin_realtime_activity')
                .select('*')
                .order('activity_at', { ascending: false })
                .limit(limit);

            if (error) throw error;
            return (data || []) as RealtimeActivity[];
        },
        refetchInterval: 10000, // 10s auto refresh
    });
}

// ============================================
// ALERTS
// ============================================

export function useStockAlerts(page = 1, limit = 20) {
    return useQuery({
        queryKey: queryKeys.stockAlerts(page, limit),
        queryFn: async () => {
            const offset = (page - 1) * limit;
            const { data, error, count } = await supabase
                .from('v_admin_stock_alerts')
                .select('*', { count: 'exact' })
                .range(offset, offset + limit - 1);

            if (error) throw error;
            return {
                data: (data || []) as StockAlert[],
                total: count || 0,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
    });
}

// ============================================
// AUDIT LOGS
// ============================================

export function useCriticalEvents(page = 1, limit = 20) {
    return useQuery({
        queryKey: queryKeys.criticalEvents(page, limit),
        queryFn: async () => {
            const offset = (page - 1) * limit;
            const { data, error, count } = await supabase
                .from('critical_audit_events')
                .select('*', { count: 'exact' })
                .range(offset, offset + limit - 1);

            if (error) throw error;
            return {
                data: (data || []) as CriticalAuditEvent[],
                total: count || 0,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
    });
}

// ============================================
// CACHE MANAGEMENT
// ============================================

export function useCache() {
    const queryClient = useQueryClient();

    const invalidateQueries = (keys: string[]) => {
        keys.forEach(key => queryClient.invalidateQueries({ queryKey: [key] }));
    };

    return { invalidateQueries };
}

// ============================================
// GLOBAL USERS (God Mode)
// ============================================

export function useAllUsers(page = 1, limit = 20, search = '') {
    return useQuery({
        queryKey: queryKeys.allUsers(page, limit, search),
        queryFn: async () => {
            const offset = (page - 1) * limit;

            let query = supabase
                .from('users')
                .select(`
                    *,
                    shops (name, velmo_id)
                `, { count: 'exact' });

            if (search && search.length > 2) {
                query = query.or(`first_name.ilike.%${search}%,last_name.ilike.%${search}%,email.ilike.%${search}%,phone.ilike.%${search}%`);
            }

            const { data, error, count } = await query
                .order('created_at', { ascending: false })
                .range(offset, offset + limit - 1);

            if (error) throw error;

            return {
                data: data || [],
                total: count || 0,
                page,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
        staleTime: 30000,
    });
}

// ============================================
// GLOBAL PRODUCTS
// ============================================

export function useAllProducts(page = 1, limit = 20, search = '') {
    return useQuery({
        queryKey: queryKeys.allProducts(page, limit, search),
        queryFn: async () => {
            const offset = (page - 1) * limit;

            let query = supabase
                .from('products')
                .select(`
                    *,
                    shops!products_shop_id_fkey (name, velmo_id)
                `, { count: 'exact' });

            if (search && search.length > 2) {
                query = query.ilike('name', `%${search}%`);
            }

            const { data, error, count } = await query
                .order('created_at', { ascending: false })
                .range(offset, offset + limit - 1);

            if (error) {
                console.error("❌ Erreur useAllProducts:", error);
                throw error;
            }

            return {
                data: (data || []).map((p: any) => ({
                    ...p,
                    photo_url: resolveImageUrl(p.photo_url || p.photo, 'products')
                })),
                total: count || 0,
                page,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
        staleTime: 30000,
    });
}

// ============================================
// GLOBAL SALES HISTORY
// ============================================

export function useAllSales(page = 1, limit = 20) {
    return useQuery({
        queryKey: queryKeys.allSales(page, limit),
        queryFn: async () => {
            const offset = (page - 1) * limit;

            const { data, error, count } = await supabase
                .from('sales')
                .select(`
                    *,
                    shops (name, velmo_id),
                    users!user_id (first_name, last_name)
                `, { count: 'exact' })
                .order('created_at', { ascending: false })
                .range(offset, offset + limit - 1);

            if (error) throw error;

            return {
                data: (data || []) as any,
                total: count || 0,
                page,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
        staleTime: 30000,
    });
}

// ============================================
// GLOBAL DEBTS
// ============================================

export function useAllDebts(page = 1, limit = 20) {
    return useQuery({
        queryKey: queryKeys.allDebts(page, limit),
        queryFn: async () => {
            const offset = (page - 1) * limit;

            const { data, error, count } = await supabase
                .from('debts')
                .select(`
                    *,
                    shops (name, velmo_id),
                    users!user_id (first_name, last_name)
                `, { count: 'exact' })
                .order('created_at', { ascending: false })
                .range(offset, offset + limit - 1);

            if (error) throw error;

            return {
                data: (data || []) as any,
                total: count || 0,
                page,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
        staleTime: 30000,
    });
}

// ============================================
// SINGLE USER DETAILS
// ============================================

export function useUserDetails(userId: string | null) {
    return useQuery({
        queryKey: queryKeys.userDetails(userId || ''),
        queryFn: async () => {
            if (!userId) return null;

            try {
                // 1. Fetch user core data
                const { data: user, error: userError } = await supabase
                    .from('users')
                    .select('*, shops (name, velmo_id)')
                    .eq('id', userId)
                    .maybeSingle();

                if (userError) throw userError;
                if (!user) return null;

                // 2. Fetch counts in parallel to avoid heavy joins
                const [salesResult, debtsResult] = await Promise.all([
                    supabase.from('sales').select('id', { count: 'exact', head: true }).eq('user_id', userId),
                    supabase.from('debts').select('id', { count: 'exact', head: true }).eq('user_id', userId),
                ]);

                // Map to the structure expected by UserDetailPage.tsx
                // The UI expects user.sales?.[0]?.count and user.debts?.[0]?.count
                return {
                    ...(user as any),
                    avatar_url: resolveImageUrl((user as any).avatar_url, 'avatars'),
                    sales: [{ count: salesResult.count || 0 }],
                    debts: [{ count: debtsResult.count || 0 }]
                };
            } catch (err) {
                console.error("❌ Error in useUserDetails:", err);
                throw err;
            }
        },
        enabled: !!userId,
        staleTime: 30000,
    });
}

// ============================================
// SINGLE PRODUCT DETAILS
// ============================================

export function useProductDetails(productId: string | null) {
    return useQuery({
        queryKey: queryKeys.productDetails(productId || ''),
        queryFn: async () => {
            if (!productId) return null;

            const { data, error } = await supabase
                .from('products')
                .select(`
                    *,
                    shops (name, velmo_id)
                `)
                .eq('id', productId)
                .single();

            if (error) throw error;
            const p = data as any;
            return {
                ...p,
                photo_url: resolveImageUrl(p.photo_url || p.photo, 'products')
            };
        },
        enabled: !!productId,
        staleTime: 30000,
    });
}

// ============================================
// SINGLE SALE DETAILS
// ============================================

export function useSaleDetails(saleId: string | null) {
    return useQuery({
        queryKey: queryKeys.saleDetails(saleId || ''),
        queryFn: async () => {
            if (!saleId) return null;

            const { data, error } = await supabase
                .from('sales')
                .select(`
                    *,
                    shops (name, velmo_id),
                    users!user_id (first_name, last_name),
                    sale_items (*)
                `)
                .eq('id', saleId)
                .single();

            if (error) throw error;
            return data as any;
        },
        enabled: !!saleId,
        staleTime: 30000,
    });
}

// ============================================
// SINGLE DEBT DETAILS
// ============================================

export function useDebtDetails(debtId: string | null) {
    return useQuery({
        queryKey: queryKeys.debtDetails(debtId || ''),
        queryFn: async () => {
            if (!debtId) return null;

            const { data, error } = await supabase
                .from('debts')
                .select(`
                    *,
                    shops (name, velmo_id, address),
                    users!user_id (first_name, last_name, phone),
                    debt_payments (*)
                `)
                .eq('id', debtId)
                .single();

            if (error) throw error;
            return data as any;
        },
        enabled: !!debtId,
        staleTime: 30000,
    });
}

// ============================================
// ADMIN ACTIONS (CONTROL CENTER)
// ============================================

export function useAdminActions() {
    const queryClient = useQueryClient();

    const updateUserStatus = useMutation({
        mutationFn: async ({ userId, status }: { userId: string; status: UserStatus }) => {
            const { data, error } = await (supabase
                .from('users') as any)
                .update({
                    status,
                    is_active: status === 'active'
                })
                .eq('id', userId)
                .select()
                .single();

            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['allUsers'] });
            queryClient.invalidateQueries({ queryKey: ['userDetails'] });
            queryClient.invalidateQueries({ queryKey: ['platformStats'] });
        }
    });

    const updateShopStatus = useMutation({
        mutationFn: async ({ shopId, status }: { shopId: string; status: ShopStatus }) => {
            const { data, error } = await (supabase
                .from('shops') as any)
                .update({
                    status,
                    is_active: status === 'active'
                })
                .eq('id', shopId)
                .select()
                .single();

            if (error) throw error;
            return data;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['shopsOverview'] });
            queryClient.invalidateQueries({ queryKey: ['shopDetails'] });
            queryClient.invalidateQueries({ queryKey: ['platformStats'] });
        }
    });

    return {
        updateUserStatus,
        updateShopStatus
    };
}

export function useSilentShops() {
    return useQuery({
        queryKey: ['silentShops'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('v_admin_silent_shops')
                .select('*');

            if (error) throw error;
            return (data || []) as any[];
        },
        staleTime: 60000,
    });
}

// ============================================
// ONLINE SHOP FEATURES
// ============================================

export function useCustomerOrders(page = 1, limit = 20, shopId?: string) {
    return useQuery({
        queryKey: queryKeys.customerOrders(page, limit, shopId),
        queryFn: async () => {
            const offset = (page - 1) * limit;
            let query = supabase
                .from('customer_orders')
                .select('*, shops!inner(name)', { count: 'exact' });

            if (shopId) {
                query = query.eq('shop_id', shopId);
            }

            const { data, error, count } = await query
                .order('created_at', { ascending: false })
                .range(offset, offset + limit - 1);

            if (error) throw error;

            // Flatten shop name
            const orders = (data || []).map((order: any) => ({
                ...order,
                shop_name: order.shops?.name
            }));

            return {
                data: orders as CustomerOrder[],
                total: count || 0,
                totalPages: Math.ceil((count || 0) / limit),
            };
        },
        staleTime: 30000,
    });
}

export function useUpdateOnlineSettings() {
    const queryClient = useQueryClient();

    return useMutation({
        mutationFn: async ({ shopId, updates }: { shopId: string; updates: Partial<DatabaseShop> }) => {
            const { data, error } = await (supabase
                .from('shops') as any)
                .update(updates)
                .eq('id', shopId)
                .select()
                .single();

            if (error) throw error;
            return data as DatabaseShop;
        },
        onSuccess: (_, variables) => {
            queryClient.invalidateQueries({ queryKey: ['shopsOverview'] });
            queryClient.invalidateQueries({ queryKey: ['shopDetails', variables.shopId] });
            queryClient.invalidateQueries({ queryKey: ['customerOrders'] });
        }
    });
}

