import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Users, Search, Crown, Store,
    MoreHorizontal, Download, Briefcase, UserPlus
} from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

import { useAllUsers, useAdminActions } from '../hooks/useData';
import { useAdmin } from '../contexts/AdminContext';
import { useToast } from '../contexts/ToastContext';
import { PageHeader, DataTable, Pagination, StatCard } from '../components/ui';
import type { UserStatus } from '../types/database';

export default function UsersPage() {
    const navigate = useNavigate();
    const { startSimulation } = useAdmin();
    const { addToast } = useToast();
    const { updateUserStatus } = useAdminActions();
    const [page, setPage] = useState(1);
    const [search, setSearch] = useState('');
    const [roleFilter, setRoleFilter] = useState<'all' | 'admin' | 'owner' | 'manager' | 'staff'>('all');

    // Fetch data
    const { data: usersData, isLoading, isFetching } = useAllUsers(page, 20, search);

    const handleUpdateStatus = async (userId: string, status: UserStatus) => {
        try {
            await updateUserStatus.mutateAsync({ userId, status });
            addToast({
                title: 'Statut mis à jour',
                message: `L'utilisateur est maintenant ${status}.`,
                type: 'success'
            });
        } catch (err) {
            addToast({
                title: 'Erreur',
                message: `Impossible de mettre à jour le statut.`,
                type: 'error'
            });
        }
    };

    // Filtering client-side for role (since the hook might only do search)
    const filteredUsers = (usersData?.data as any[])?.filter((user: any) => {
        if (roleFilter === 'all') return true;
        if (roleFilter === 'staff') {
            return user.role === 'staff' || user.role === 'seller' || user.role === 'cashier';
        }
        if (roleFilter === 'owner') return user.role === 'owner';
        if (roleFilter === 'manager') return user.role === 'manager';
        if (roleFilter === 'admin') return user.role === 'admin';
        return user.role === roleFilter;
    }) || [];

    // Columns Configuration
    const columns = [
        {
            key: 'user',
            header: 'Utilisateur',
            className: 'w-[25%] min-w-[200px]',
            render: (user: any) => (
                <div className="flex items-center gap-3">
                    <div className={`
                        w-10 h-10 rounded-xl flex items-center justify-center text-xs font-black shadow-lg shrink-0 border
                        ${user.role === 'admin' ? 'bg-[var(--primary)]/10 text-[var(--primary)] border-[var(--primary)]/20 shadow-[var(--primary-glow)]' :
                            user.role === 'manager' ? 'bg-[var(--info)]/10 text-[var(--info)] border-[var(--info)]/20 shadow-[var(--info)]/5' :
                                'bg-[var(--bg-app)] text-[var(--text-muted)] border-[var(--border-subtle)]'}
                    `}>
                        {user.first_name?.[0]?.toUpperCase() || 'U'}{user.last_name?.[0]?.toUpperCase()}
                    </div>
                    <div className="flex flex-col min-w-0">
                        <span className="text-[var(--text-primary)] font-bold text-sm truncate group-hover:text-[var(--primary)] transition-colors">
                            {user.first_name} {user.last_name}
                        </span>
                        <span className="text-[10px] text-[var(--text-muted)] font-medium truncate uppercase tracking-tighter">
                            ID: {user.id.split('-')[0]}
                        </span>
                    </div>
                </div>
            ),
        },
        {
            key: 'contact',
            header: 'Coordonnées',
            className: 'w-[20%] min-w-[180px]',
            render: (user: any) => (
                <div className="flex flex-col">
                    <span className="text-[var(--text-secondary)] text-xs font-medium truncate" title={user.email}>
                        {user.email || 'Pas d\'email'}
                    </span>
                    <span className="text-[10px] font-mono text-[var(--text-muted)] mt-0.5">{user.phone || '-'}</span>
                </div>
            ),
        },
        {
            key: 'role',
            header: 'Niveau d\'accès',
            className: 'w-[15%] min-w-[120px]',
            render: (user: any) => (
                <span className={`
                    inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider border
                    ${user.role === 'admin' ? 'bg-[var(--primary)]/10 text-[var(--primary)] border-[var(--primary)]/20' :
                        user.role === 'manager' ? 'bg-[var(--info)]/10 text-[var(--info)] border-[var(--info)]/20' :
                            'bg-[var(--bg-app)] text-[var(--text-muted)] border-[var(--border-subtle)]'}
                `}>
                    {user.role === 'admin' && <Crown size={10} />}
                    {user.role || 'Staff'}
                </span>
            ),
        },
        {
            key: 'shop',
            header: 'Affectation',
            className: 'w-[20%] min-w-[150px]',
            render: (user: any) => (
                user.shops ? (
                    <div className="flex items-center gap-2 text-xs text-[var(--text-secondary)]">
                        <div className="w-6 h-6 rounded bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center shrink-0">
                            <Store size={12} className="text-[var(--text-muted)]" />
                        </div>
                        <span className="font-bold truncate" title={user.shops.name}>{user.shops.name}</span>
                    </div>
                ) : <span className="text-[var(--text-muted)] text-[10px] font-black uppercase tracking-widest italic opacity-30">Non assigné</span>
            ),
        },
        {
            key: 'created_at',
            header: 'Membre depuis',
            className: 'w-[15%] min-w-[100px]',
            render: (user: any) => (
                <span className="text-[var(--text-muted)] text-[11px] font-black uppercase">
                    {format(new Date(user.created_at), 'MMM yyyy', { locale: fr })}
                </span>
            )
        },
        {
            key: 'status',
            header: 'Statut',
            className: 'w-[10%] min-w-[100px]',
            render: (user: any) => (
                <span className={`
                    px-2 py-0.5 rounded-full text-[9px] font-black uppercase tracking-widest border
                    ${user.status === 'active' ? 'bg-[var(--success)]/10 text-[var(--success)] border-[var(--success)]/20' :
                        user.status === 'suspended' ? 'bg-[var(--warning)]/10 text-[var(--warning)] border-[var(--warning)]/20' :
                            'bg-[var(--error)]/10 text-[var(--error)] border-[var(--error)]/20'}
                `}>
                    {user.status || 'active'}
                </span>
            ),
        },
        {
            key: 'actions',
            header: '',
            className: 'w-[10%] min-w-[100px] text-right',
            render: (user: any) => (
                <div className="flex items-center justify-end gap-2 px-2">
                    <button
                        onClick={(e) => { e.stopPropagation(); startSimulation(user.id, null); }}
                        className="p-2 text-[var(--text-muted)] hover:text-[var(--warning)] hover:bg-[var(--warning)]/10 rounded-xl transition-all"
                        title="Simuler ce profil"
                    >
                        <Search size={16} />
                    </button>
                    {(user.status === 'suspended' || user.status === 'blocked') ? (
                        <button
                            onClick={(e) => { e.stopPropagation(); handleUpdateStatus(user.id, 'active'); }}
                            className="p-2 text-[var(--text-muted)] hover:text-[var(--success)] hover:bg-[var(--success)]/10 rounded-xl transition-all"
                            title="Réactiver"
                        >
                            <Crown size={16} />
                        </button>
                    ) : (
                        <button
                            onClick={(e) => { e.stopPropagation(); handleUpdateStatus(user.id, 'suspended'); }}
                            className="p-2 text-[var(--text-muted)] hover:text-[var(--error)] hover:bg-[var(--error)]/10 rounded-xl transition-all"
                            title="Suspendre"
                        >
                            <MoreHorizontal size={16} />
                        </button>
                    )}
                </div>
            ),
        }
    ];

    return (
        <div className="space-y-10 animate-fade-in pb-20">

            <PageHeader
                title="Équipe & Utilisateurs"
                description={`Gérez les privilèges et les accès des ${usersData?.total || '...'} collaborateurs de la plateforme.`}
                actions={
                    <div className="flex items-center gap-3">
                        <button className="px-4 py-2.5 text-xs font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors flex items-center gap-2">
                            <Download size={14} /> Exporter CSV
                        </button>
                        <button className="px-5 py-2.5 bg-[var(--primary)] hover:opacity-90 text-white rounded-2xl font-bold transition-all shadow-xl shadow-[var(--primary-glow)] flex items-center gap-2 active:scale-95 text-xs uppercase tracking-widest">
                            <UserPlus size={16} /> Ajouter un Membre
                        </button>
                    </div>
                }
            />

            {/* STATS OVERVIEW */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
                <StatCard
                    label="Commandement"
                    value={(usersData?.data as any[])?.filter((u: any) => u.role === 'admin' || u.role === 'owner').length || 0}
                    icon={Crown}
                    variant="info"
                    changeLabel="Administrateurs et Propriétaires"
                />
                <StatCard
                    label="Opérations"
                    value={(usersData?.data as any[])?.filter((u: any) => u.role === 'manager').length || 0}
                    icon={Briefcase}
                    variant="default"
                    changeLabel="Gérants de boutique"
                />
                <StatCard
                    label="Support"
                    value={(usersData?.data as any[])?.filter((u: any) => u.role === 'staff' || u.role === 'seller' || u.role === 'cashier').length || 0}
                    icon={Users}
                    variant="info"
                    changeLabel="Équipe terrain / Vendeurs"
                />
            </div>

            {/* TABLE CONTROLS */}
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                <div className="relative flex-1">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
                    <input
                        type="text"
                        placeholder="Rechercher par identité, email ou terminal..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="w-full bg-transparent border-none rounded-xl pl-12 pr-4 py-3 text-sm text-[var(--text-primary)] focus:ring-1 focus:ring-[var(--primary)]/50 placeholder:text-[var(--text-secondary)] transition-all font-bold"
                    />
                </div>
                <div className="hidden lg:block h-8 w-px bg-[var(--border-subtle)] mx-2" />
                <div className="flex items-center gap-2">
                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest ml-2 hidden sm:block">Filtrer par Rôle:</span>
                    <div className="flex bg-[var(--bg-app)]/50 p-1 rounded-xl border border-[var(--border-subtle)]">
                        {['all', 'admin', 'owner', 'manager', 'staff'].map((role) => (
                            <button
                                key={role}
                                onClick={() => setRoleFilter(role as any)}
                                className={`
                                    px-3 py-1.5 text-[10px] font-black uppercase tracking-tighter rounded-lg transition-all
                                    ${roleFilter === role ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)]' : 'text-[var(--text-muted)] hover:text-[var(--text-primary)]'}
                                `}
                            >
                                {role === 'all' ? 'Tous' : role}
                            </button>
                        ))}
                    </div>
                </div>
            </div>

            {/* MAIN TABLE AREA */}
            <div className="relative">
                {isFetching && (
                    <div className="absolute top-0 inset-x-0 h-[2px] bg-gradient-to-r from-transparent via-[var(--primary)] to-transparent z-10 animate-pulse" />
                )}

                <DataTable
                    columns={columns}
                    data={filteredUsers}
                    loading={isLoading}
                    emptyMessage="Aucun membre trouvé dans le registre."
                    keyExtractor={(user) => user.id}
                    onRowClick={(user) => navigate(`/users/${user.id}`)}
                />

                <Pagination
                    page={page}
                    totalPages={usersData?.totalPages || 1}
                    onPageChange={setPage}
                />
            </div>
        </div>
    );
}
