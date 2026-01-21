import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, Mail, Phone, Shield, Crown, Briefcase,
    MapPin, Activity, History, CreditCard,
    MoreVertical, User as UserIcon, Store, ShoppingBag, AlertTriangle, UserPlus
} from 'lucide-react';
import { motion } from 'framer-motion';

import { useUserDetails, useUserActivity, useAdminActions } from '../hooks/useData';
import { useToast } from '../contexts/ToastContext';

import { StatCard, LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

export default function UserDetailPage() {
    const { userId } = useParams();
    const navigate = useNavigate();
    const { addToast } = useToast();
    const { data: user, isLoading } = useUserDetails(userId || null);
    const { data: activities, isLoading: activitiesLoading } = useUserActivity(userId || null);
    const { updateUserStatus } = useAdminActions();

    const handleRevokeAccess = async () => {
        if (!userId || !user) return;

        const confirmRevoke = window.confirm(`Êtes-vous sûr de vouloir révoquer l'accès de ${user.first_name} ${user.last_name} ?`);
        if (!confirmRevoke) return;

        try {
            await updateUserStatus.mutateAsync({ userId, status: 'blocked' });
            addToast({
                title: 'Accès Révoqué',
                message: "L'agent a été suspendu du système avec succès.",
                type: 'success'
            });
        } catch (err) {
            addToast({
                title: 'Erreur',
                message: "Échec de la révocation de l'accès.",
                type: 'error'
            });
        }
    };

    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Extraction du profil agent...</p>
            </div>
        );
    }

    if (!user) {
        return (
            <EmptyState
                icon={UserIcon}
                title="Agent Introuvable"
                description="Le profil spécifié n'existe pas ou a été révoqué du système."
            />
        );
    }

    return (
        <div className="space-y-10 pb-20 animate-fade-in">
            {/* Header with Back Button */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/users')}
                    className="p-3 rounded-2xl bg-[var(--bg-card)] border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all hover:bg-[var(--primary)]/10 active:scale-90"
                >
                    <ArrowLeft size={20} />
                </button>
                <div className="h-10 w-px bg-[var(--border-subtle)] mx-2" />
                <div>
                    <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Registre du Commandement</p>
                    <h1 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Profil Identité</h1>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

                {/* Profile Identity Card */}
                <motion.div
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="lg:col-span-1 space-y-6"
                >
                    <div className="card-dashboard p-8 flex flex-col items-center text-center relative overflow-hidden group">
                        <div className="absolute inset-0 bg-gradient-to-b from-[var(--primary)]/10 to-transparent opacity-50" />

                        <div className="relative w-32 h-32 mb-6">
                            <div className="absolute inset-0 bg-[var(--primary)] blur-3xl opacity-20 animate-pulse" />
                            <div className={`relative w-full h-full rounded-[3rem] flex items-center justify-center text-4xl font-black text-white shadow-2xl border-2 border-white/10 italic ${user.role === 'admin' ? 'bg-gradient-to-br from-[var(--primary)] to-violet-700' : 'bg-gradient-to-br from-[var(--text-muted)] to-[var(--bg-app)]'}`}>
                                {user.first_name?.[0]}{user.last_name?.[0]}
                            </div>
                            <div className="absolute -bottom-1 -right-1 w-10 h-10 bg-[var(--bg-app)] border-4 border-[var(--bg-app)] rounded-full flex items-center justify-center shadow-xl">
                                <div className={`w-full h-full rounded-full animate-pulse shadow-[0_0_15px_var(--success)] ${user.is_active ? 'bg-[var(--success)]' : 'bg-[var(--error)]'}`} />
                            </div>
                        </div>

                        <h2 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tight mb-1">{user.first_name} {user.last_name}</h2>
                        <div className="flex items-center gap-2 mb-8">
                            <StatusBadge
                                status={user.status === 'active' ? 'active' : 'inactive'}
                                label={user.role.toUpperCase()}
                            />
                            {user.role === 'admin' && <Crown size={14} className="text-[var(--warning)]" />}
                        </div>

                        <div className="w-full space-y-3">
                            <div className="flex items-center justify-between p-4 rounded-2xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] group/info">
                                <div className="flex items-center gap-3">
                                    <Mail size={16} className="text-[var(--text-muted)] group-hover/info:text-[var(--primary)] transition-colors" />
                                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase">Email</span>
                                </div>
                                <span className="text-xs font-bold text-[var(--text-secondary)]">{user.email || 'N/A'}</span>
                            </div>
                            <div className="flex items-center justify-between p-4 rounded-2xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] group/info">
                                <div className="flex items-center gap-3">
                                    <Phone size={16} className="text-[var(--text-muted)] group-hover/info:text-[var(--primary)] transition-colors" />
                                    <span className="text-[10px] font-black text-[var(--text-muted)] uppercase">Contact</span>
                                </div>
                                <span className="text-xs font-mono text-[var(--text-secondary)]">{user.phone || 'N/A'}</span>
                            </div>
                        </div>

                        <div className="w-full mt-8 pt-8 border-t border-[var(--border-subtle)]">
                            <div className="flex justify-around items-center opacity-40">
                                <Activity size={18} className="text-[var(--text-muted)]" />
                                <History size={18} className="text-[var(--text-muted)]" />
                                <MoreVertical size={18} className="text-[var(--text-muted)]" />
                            </div>
                        </div>
                    </div>

                    {/* Shop Assignment */}
                    {user.shops ? (
                        <div
                            onClick={() => navigate(`/shops/${user.shop_id}`)}
                            className="card-dashboard p-6 group cursor-pointer hover:border-[var(--primary)]/30 transition-all border-[var(--border-subtle)] bg-[var(--bg-card)]"
                        >
                            <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] mb-4">Affectation Tactique</p>
                            <div className="flex items-center gap-4">
                                <div className="w-12 h-12 rounded-2xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center group-hover:bg-[var(--primary)] group-hover:text-white transition-all duration-500">
                                    <Store size={20} />
                                </div>
                                <div className="flex-1">
                                    <h4 className="text-sm font-black text-[var(--text-primary)] uppercase tracking-tight">{user.shops.name}</h4>
                                    <p className="text-[9px] font-bold text-[var(--text-muted)] uppercase tracking-widest mt-0.5">{user.shops.category || 'Commerce'}</p>
                                </div>
                                <ArrowLeft size={16} className="text-[var(--text-muted)] rotate-180 group-hover:text-[var(--primary)] transition-colors" />
                            </div>
                        </div>
                    ) : (
                        <div className="card-dashboard p-6 border-dashed border-[var(--border-subtle)] bg-transparent flex flex-col items-center justify-center text-center opacity-50">
                            <MapPin size={24} className="text-[var(--text-muted)] mb-2" />
                            <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest">Aucune Affectation</p>
                        </div>
                    )}
                </motion.div>

                {/* Performance Matrix */}
                <div className="lg:col-span-2 space-y-8">

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                        <StatCard
                            label="Opérations Clé"
                            value={user.sales?.[0]?.count || 0}
                            icon={Briefcase}
                            variant="indigo"
                            index={0}
                            changeLabel="Ventes enregistrées"
                        />
                        <StatCard
                            label="Flux Financier"
                            value={user.debts?.[0]?.count || 0}
                            icon={CreditCard}
                            variant="warning"
                            index={1}
                            changeLabel="Dossiers de crédit"
                        />
                    </div>

                    {/* Timeline / Recent Activity */}
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="card-dashboard p-8"
                    >
                        <div className="flex items-center justify-between mb-8">
                            <h3 className="text-lg font-black text-[var(--text-primary)] uppercase tracking-tighter">Historique des Flux</h3>
                            <div className="flex items-center gap-2 bg-[var(--bg-app)]/50 px-3 py-1.5 rounded-xl border border-[var(--border-subtle)] text-[9px] font-black text-[var(--text-muted)] uppercase">
                                <Activity size={12} className="text-[var(--primary)]" /> Live Data
                            </div>
                        </div>

                        <div className="space-y-6">
                            {activitiesLoading ? (
                                <div className="flex justify-center py-10">
                                    <LoadingSpinner />
                                </div>
                            ) : activities && activities.length > 0 ? (
                                activities.map((activity, i) => (
                                    <div key={i} className="flex gap-4 group cursor-pointer" onClick={() => navigate(activity.activity_type === 'sale' ? `/sales/${activity.entity_id}` : `/debts/${activity.entity_id}`)}>
                                        <div className="flex flex-col items-center">
                                            <div className={`w-10 h-10 rounded-xl flex items-center justify-center border shadow-lg transition-transform group-hover:scale-110
                                                ${activity.activity_type === 'sale' ? 'bg-[var(--success)]/10 text-[var(--success)] border-[var(--success)]/20' : activity.activity_type === 'debt' ? 'bg-[var(--error)]/10 text-[var(--error)] border-[var(--error)]/20' : 'bg-[var(--primary)]/10 text-[var(--primary)] border-[var(--primary)]/20'}
                                            `}>
                                                {activity.activity_type === 'sale' ? <ShoppingBag size={14} /> : activity.activity_type === 'debt' ? <AlertTriangle size={14} /> : <UserPlus size={14} />}
                                            </div>
                                            <div className="w-0.5 flex-1 bg-[var(--border-subtle)] my-2 group-last:hidden" />
                                        </div>
                                        <div className="flex-1 pb-6">
                                            <div className="flex justify-between items-start">
                                                <div>
                                                    <p className="text-sm font-bold text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors">
                                                        {activity.activity_type === 'sale' ? 'Vente enregistrée' : activity.activity_type === 'debt' ? 'Nouvelle Dette' : 'Création Profil'}
                                                    </p>
                                                    <p className="text-xs text-[var(--text-muted)] mt-0.5">Terminal: {activity.shop_name}</p>
                                                </div>
                                                <span className="text-[9px] font-black text-[var(--text-muted)] uppercase">
                                                    {new Date(activity.activity_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                ))
                            ) : (
                                <div className="text-center py-10 opacity-50">
                                    <p className="text-xs uppercase font-bold tracking-widest text-[var(--text-muted)]">Aucune activité récente détectée</p>
                                </div>
                            )}
                        </div>
                    </motion.div>

                    <div className="card-dashboard p-8 border-[var(--error)]/10 bg-[var(--error)]/[0.01]">
                        <h3 className="text-[10px] font-black text-[var(--error)] uppercase tracking-widest mb-4 flex items-center gap-2">
                            <Shield size={14} /> Zone de Révocation
                        </h3>
                        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
                            <div className="flex-1 text-center sm:text-left">
                                <p className="text-xs font-bold text-[var(--text-muted)]">Suspendre ou révoquer les accès de cet agent immédiatement.</p>
                                <p className="text-[9px] text-[var(--text-muted)]/60 mt-1 uppercase tracking-tighter">Action irréversible sans validation Super-Admin.</p>
                            </div>
                            <button
                                onClick={handleRevokeAccess}
                                className={`px-6 py-3 rounded-xl border font-black text-[10px] uppercase tracking-widest transition-all active:scale-95 shadow-lg
                                    ${user.status === 'blocked'
                                        ? 'bg-zinc-800 text-zinc-500 border-zinc-700 cursor-not-allowed'
                                        : 'bg-[var(--error)]/10 hover:bg-[var(--error)] text-[var(--error)] hover:text-white border-[var(--error)]/20 hover:shadow-[var(--error)]/20'}
                                `}
                                disabled={user.status === 'blocked'}
                            >
                                {user.status === 'blocked' ? 'Accès Déjà Révoqué' : 'Révoquer Accès'}
                            </button>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    );
}
