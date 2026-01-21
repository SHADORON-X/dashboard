import { useEffect } from 'react';
import supabase from '../lib/supabase';
import { useToast } from '../contexts/ToastContext';
import { useQueryClient } from '@tanstack/react-query';

export function RealtimeMonitor() {
    const { addToast } = useToast();
    const queryClient = useQueryClient();

    useEffect(() => {
        console.log("🟢 LIVE MONITOR: Initializing secure realtime connection...");

        // Channel unique pour éviter les conflits
        const channel = supabase.channel('dashboard-live-events');

        channel
            // 1. Écouter les NOUVELLES VENTES
            .on(
                'postgres_changes',
                { event: 'INSERT', schema: 'public', table: 'sales' },
                (payload) => {
                    console.log('💰 NEW SALE:', payload);

                    // Invalider les queries pour rafraîchir les stats auto
                    queryClient.invalidateQueries({ queryKey: ['platformStats'] });
                    queryClient.invalidateQueries({ queryKey: ['dailySales'] });
                    queryClient.invalidateQueries({ queryKey: ['recentActivity'] });

                    addToast({
                        type: 'success',
                        title: 'Nouvelle Vente ! 💰',
                        message: `Commande de ${payload.new.total_amount?.toLocaleString()} FCFA enregistrée.`,
                        duration: 6000
                    });
                }
            )
            // 2. Écouter les ALERTES CRITIQUES (Stock Faible)
            .on(
                'postgres_changes',
                { event: 'UPDATE', schema: 'public', table: 'products', filter: 'quantity=lt.5' },
                (payload) => {
                    // Check if status changed to critical
                    if (payload.new.quantity <= 3) {
                        addToast({
                            type: 'warning',
                            title: 'Stock Critique ⚠️',
                            message: `Le produit "${payload.new.name}" est presque en rupture (${payload.new.quantity} restants).`,
                            duration: 10000
                        });
                    }
                }
            )
            // 3. Écouter les UTILISATEURS connectés/créés
            .on(
                'postgres_changes',
                { event: 'INSERT', schema: 'public', table: 'users' },
                (payload) => {
                    addToast({
                        type: 'info',
                        title: 'Nouveau Membre 👋',
                        message: `${payload.new.first_name || 'Un utilisateur'} vient de rejoindre l'équipe.`,
                    });
                }
            )
            .subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    console.log('🟢 LIVE MONITOR: Connected and listening.');
                }
            });

        return () => {
            console.log('🔴 LIVE MONITOR: Disconnecting...');
            supabase.removeChannel(channel);
        };
    }, [addToast, queryClient]);

    return null; // Ce composant ne rend rien visuellement
}
