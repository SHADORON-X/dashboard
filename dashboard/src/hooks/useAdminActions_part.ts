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

if (error) {
    console.error("❌ Error fetching Debt Detail:", error.message);
    throw error;
}
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
            const { data, error } = await supabase
                .from('users')
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
            const { data, error } = await supabase
                .from('shops')
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
