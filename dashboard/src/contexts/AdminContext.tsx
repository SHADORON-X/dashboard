import React, { createContext, useContext, useState } from 'react';

interface AdminContextType {
    isSimulationMode: boolean;
    simulatedUserId: string | null;
    simulatedShopId: string | null;
    startSimulation: (userId: string | null, shopId: string | null) => void;
    stopSimulation: () => void;
}

const AdminContext = createContext<AdminContextType | undefined>(undefined);

export function AdminProvider({ children }: { children: React.ReactNode }) {
    const [simulatedUserId, setSimulatedUserId] = useState<string | null>(() => localStorage.getItem('velmo_sim_user'));
    const [simulatedShopId, setSimulatedShopId] = useState<string | null>(() => localStorage.getItem('velmo_sim_shop'));

    const isSimulationMode = !!(simulatedUserId || simulatedShopId);

    const startSimulation = (userId: string | null, shopId: string | null) => {
        setSimulatedUserId(userId);
        setSimulatedShopId(shopId);
        if (userId) localStorage.setItem('velmo_sim_user', userId);
        else localStorage.removeItem('velmo_sim_user');

        if (shopId) localStorage.setItem('velmo_sim_shop', shopId);
        else localStorage.removeItem('velmo_sim_shop');
    };

    const stopSimulation = () => {
        setSimulatedUserId(null);
        setSimulatedShopId(null);
        localStorage.removeItem('velmo_sim_user');
        localStorage.removeItem('velmo_sim_shop');
    };

    return (
        <AdminContext.Provider value={{
            isSimulationMode,
            simulatedUserId,
            simulatedShopId,
            startSimulation,
            stopSimulation
        }}>
            {children}
            {isSimulationMode && (
                <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-[9999] animate-bounce">
                    <div className="bg-amber-500 text-black px-6 py-3 rounded-2xl shadow-2xl flex items-center gap-4 border-2 border-amber-400">
                        <div className="flex flex-col">
                            <span className="text-[10px] font-black uppercase tracking-widest leading-none">Simulation Active</span>
                            <span className="text-xs font-bold whitespace-nowrap">Lecture seule : {simulatedUserId ? 'Utilisateur' : 'Boutique'}</span>
                        </div>
                        <button
                            onClick={stopSimulation}
                            className="bg-black/10 hover:bg-black/20 px-3 py-1 rounded-lg text-[10px] font-black uppercase transition-all"
                        >
                            Quitter
                        </button>
                    </div>
                </div>
            )}
        </AdminContext.Provider>
    );
}

export function useAdmin() {
    const context = useContext(AdminContext);
    if (context === undefined) {
        throw new Error('useAdmin must be used within an AdminProvider');
    }
    return context;
}
