import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/database';

// ============================================
// SUPABASE CLIENT CONFIGURATION
// ============================================

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error('Missing Supabase environment variables. Please check .env file.');
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
    auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
    },
    realtime: {
        params: {
            eventsPerSecond: 10,
        },
    },
});

// ============================================
// ADMIN VERIFICATION
// ============================================

/**
 * Vérifie si l'utilisateur courant est un super_admin Velmo
 * En l'absence de table velmo_admins, on vérifie via une RPC custom
 */
export async function checkIsVelmoAdmin(userId: string): Promise<boolean> {
    try {
        // Option 1: Via RPC (recommandé - à créer dans les migrations)
        // @ts-ignore
        const { data, error } = await supabase.rpc('is_velmo_super_admin', {
            p_user_id: userId,
        });

        if (error) {
            console.error('Admin check error:', error);
            // Fallback: vérifier dans la table velmo_admins directement
            // @ts-ignore
            const { data: adminData } = await supabase
                .from('velmo_admins')
                .select('id, role')
                .eq('user_id', userId)
                .eq('is_active', true)
                .single();

            // @ts-ignore
            return (adminData as any)?.role === 'super_admin';
        }

        return data === true;
    } catch (err) {
        console.error('Failed to verify admin status:', err);
        return false;
    }
}

// ============================================
// DATA FETCHING HELPERS
// ============================================

export interface QueryOptions {
    page?: number;
    limit?: number;
    orderBy?: string;
    orderDirection?: 'asc' | 'desc';
}

/**
 * Calcule l'offset pour la pagination
 */
export function calculateOffset(page: number, limit: number): number {
    return (page - 1) * limit;
}

/**
 * Wrapper pour les requêtes avec gestion d'erreur unifiée
 */
export async function safeQuery<T>(
    queryFn: () => Promise<{ data: T | null; error: Error | null }>
): Promise<{ data: T | null; error: string | null }> {
    try {
        const { data, error } = await queryFn();
        if (error) {
            return { data: null, error: error.message };
        }
        return { data, error: null };
    } catch (err) {
        return { data: null, error: err instanceof Error ? err.message : 'Unknown error' };
    }
}

// ============================================
// REALTIME SUBSCRIPTIONS
// ============================================

export type RealtimeCallback<T> = (payload: T) => void;

/**
 * S'abonne aux événements en temps réel sur une table
 */
export function subscribeToTable<T>(
    tableName: string,
    callback: RealtimeCallback<T>,
    eventTypes: ('INSERT' | 'UPDATE' | 'DELETE')[] = ['INSERT', 'UPDATE', 'DELETE']
) {
    const channel = supabase
        .channel(`public:${tableName}`)
        .on(
            'postgres_changes',
            {
                event: '*',
                schema: 'public',
                table: tableName,
            },
            (payload) => {
                if (eventTypes.includes(payload.eventType as 'INSERT' | 'UPDATE' | 'DELETE')) {
                    callback(payload as T);
                }
            }
        )
        .subscribe();

    return () => {
        supabase.removeChannel(channel);
    };
}

export default supabase;
