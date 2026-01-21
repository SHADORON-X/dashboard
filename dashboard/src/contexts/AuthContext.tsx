import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import type { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

// ============================================
// TYPES
// ============================================

interface AuthContextType {
    user: User | null;
    session: Session | null;
    isAdmin: boolean;
    role: string | null;
    isLoading: boolean;
    error: string | null;
    signInWithPassword: (email: string, password: string) => Promise<void>;
    signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

// ============================================
// PROVIDER
// ============================================

export function AuthProvider({ children }: { children: React.ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [session, setSession] = useState<Session | null>(null);
    const [isAdmin, setIsAdmin] = useState(false);
    const [role, setRole] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // Fonction centrale de vérification des droits
    const verifyAccess = useCallback(async (currentSession: Session | null) => {
        if (!currentSession?.user) {
            setUser(null);
            setSession(null);
            setIsAdmin(false);
            setRole(null);
            setIsLoading(false);
            return;
        }

        try {
            // 1. Vérifier la table admin_users via RPC sécurisée
            // @ts-ignore
            const { data: accessData, error: accessError } = await (supabase.rpc('check_admin_access') as any);

            let isAuthorized = false;
            let userRole = 'viewer';

            if (!accessError && accessData) {
                isAuthorized = accessData.authorized;
                userRole = accessData.role;
            } else {
                // Fallback: Tentative de lecture directe (si RLS le permet)
                // @ts-ignore
                const { data: adminUser } = await supabase
                    .from('admin_users')
                    .select('role')
                    .eq('id', currentSession.user.id)
                    .single();

                if (adminUser) {
                    isAuthorized = true;
                    // @ts-ignore
                    userRole = adminUser.role;
                }
            }

            if (!isAuthorized) {
                console.warn('⛔ Accès refusé: Utilisateur non trouvé dans admin_users');
                await supabase.auth.signOut();
                setError("Accès refusé. Contactez un administrateur.");
                setUser(null);
                setSession(null);
            } else {
                console.log('✅ Accès autorisé:', { email: currentSession.user.email, role: userRole });
                setUser(currentSession.user);
                setSession(currentSession);
                setRole(userRole);
                setIsAdmin(userRole === 'super_admin' || userRole === 'admin');
                setError(null);
            }
        } catch (err) {
            console.error('Erreur vérification accès:', err);
            setError("Erreur lors de la vérification des droits.");
            await supabase.auth.signOut();
        } finally {
            setIsLoading(false);
        }
    }, []);

    // Initialisation
    useEffect(() => {
        supabase.auth.getSession().then(({ data: { session } }) => {
            verifyAccess(session);
        });

        const {
            data: { subscription },
        } = supabase.auth.onAuthStateChange((_event, session) => {
            verifyAccess(session);
        });

        return () => subscription.unsubscribe();
    }, [verifyAccess]);

    const signInWithPassword = async (email: string, password: string) => {
        setIsLoading(true);
        setError(null);
        try {
            const { data, error } = await supabase.auth.signInWithPassword({
                email,
                password,
            });

            if (error) {
                if (error.message.includes('Email not confirmed')) {
                    throw new Error("Veuillez confirmer votre email avant de vous connecter.");
                }
                throw error;
            }

            if (!data.session) throw new Error("Erreur de session");

            // La vérification des droits se fera via onAuthStateChange
        } catch (err: any) {
            setError(err.message);
            setIsLoading(false);
            throw err;
        }
    };

    const signOut = async () => {
        setIsLoading(true);
        await supabase.auth.signOut();
        setUser(null);
        setSession(null);
        setIsAdmin(false);
        setIsLoading(false);
    };

    return (
        <AuthContext.Provider value={{
            user,
            session,
            isAdmin,
            role,
            isLoading,
            error,
            signInWithPassword,
            signOut
        }}>
            {children}
        </AuthContext.Provider>
    );
}

export function useAuth() {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
}

// Composant Helper pour protéger les routes
import { Navigate } from 'react-router-dom';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
    const { user, isLoading } = useAuth();

    if (isLoading) {
        return (
            <div className="min-h-screen bg-dark-950 flex items-center justify-center">
                <div className="flex flex-col items-center gap-4">
                    <div className="w-10 h-10 border-4 border-velmo-600 border-t-transparent rounded-full animate-spin" />
                    <p className="text-dark-400 text-sm">Vérification des accès...</p>
                </div>
            </div>
        );
    }

    if (!user) {
        return <Navigate to="/login" replace />;
    }

    return <>{children}</>;
}
