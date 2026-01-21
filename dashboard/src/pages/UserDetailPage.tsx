import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, Mail, Phone, Shield, Crown, Briefcase,
    MapPin, Activity, History, CreditCard,
    MoreVertical, User as UserIcon, Store
} from 'lucide-react';

import { useUserDetails } from '../hooks/useData';

import { StatCard, LoadingSpinner, EmptyState, StatusBadge } from '../components/ui';

export default function UserDetailPage() {
    const { userId } = useParams();
    const navigate = useNavigate();
    const { data: user, isLoading } = useUserDetails(userId || null);

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
                    className="p-3 rounded-2xl bg-[var(--bg-card)] border border-[var(--border-subtle)] text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all hover:bg-[var(--primary)]/10"
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
                <div className="lg:col-span-1 space-y-6">
                    <div className="card-dashboard p-8 flex flex-col items-center text-center relative overflow-hidden group">
                        <div className="absolute inset-0 bg-gradient-to-b from-[var(--primary)]/10 to-transparent opacity-50" />

                        <div className="relative w-32 h-32 mb-6">
                            <div className="absolute inset-0 bg-[var(--primary)] blur-3xl opacity-20 animate-pulse" />
                            <div className={`relative w-full h-full rounded-[3rem] flex items-center justify-center text-4xl font-black text-white shadow-2xl border-2 border-white/10 italic ${user.role === 'admin' ? 'bg-gradient-to-br from-[var(--primary)] to-violet-700' : 'bg-gradient-to-br from-[var(--text-muted)] to-[var(--bg-app)]'}`}>
                                {user.first_name?.[0]}{user.last_name?.[0]}
                            </div>
                            <div className="absolute -bottom-1 -right-1 w-10 h-10 bg-[var(--bg-app)] border-4 border-[var(--bg-app)] rounded-full flex items-center justify-center shadow-xl">
                                <div className="w-full h-full bg-[var(--success)] rounded-full animate-pulse shadow-[0_0_15px_var(--success)]" />
                            </div>
                        </div>

                        <h2 className="text-2xl font-black text-[var(--text-primary)] uppercase tracking-tight mb-1">{user.first_name} {user.last_name}</h2>
                        <div className="flex items-center gap-2 mb-8">
                            <StatusBadge
                                status={user.role === 'admin' ? 'active' : user.role === 'manager' ? 'pending' : 'inactive'}
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
                        <div className="card-dashboard p-6 group cursor-pointer hover:border-[var(--primary)]/30 transition-all border-[var(--border-subtle)] bg-[var(--bg-card)]">
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
                </div>

                {/* Performance Matrix */}
                <div className="lg:col-span-2 space-y-8">

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                        <StatCard
                            label="Opérations Clé"
                            value={user.sales?.[0]?.count || 0}
                            icon={Briefcase}
                            variant="indigo"
                            changeLabel="Ventes enregistrées"
                        />
                        <StatCard
                            label="Flux Financier"
                            value={user.debts?.[0]?.count || 0}
                            icon={CreditCard}
                            variant="warning"
                            changeLabel="Dossiers de crédit"
                        />
                    </div>

                    {/* Timeline / Recent Activity Placeholders */}
                    <div className="card-dashboard p-8">
                        <div className="flex items-center justify-between mb-8">
                            <h3 className="text-lg font-black text-[var(--text-primary)] uppercase tracking-tighter">Historique des Flux</h3>
                            <div className="flex items-center gap-2 bg-[var(--bg-app)]/50 px-3 py-1.5 rounded-xl border border-[var(--border-subtle)] text-[9px] font-black text-[var(--text-muted)] uppercase">
                                <Activity size={12} className="text-[var(--primary)]" /> Live Data
                            </div>
                        </div>

                        <div className="space-y-6">
                            {[1, 2, 3].map((i) => (
                                <div key={i} className="flex gap-4 group">
                                    <div className="flex flex-col items-center">
                                        <div className="w-2 h-2 rounded-full bg-[var(--bg-app)] border-2 border-[var(--border-subtle)] z-10 group-hover:bg-[var(--primary)] transition-colors" />
                                        <div className="w-0.5 flex-1 bg-[var(--border-subtle)] my-1 group-last:hidden" />
                                    </div>
                                    <div className="flex-1 pb-6">
                                        <div className="flex justify-between items-start">
                                            <div>
                                                <p className="text-sm font-bold text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] transition-colors">Connexion au terminal {user.shops?.name || 'Central'}</p>
                                                <p className="text-xs text-[var(--text-muted)] mt-0.5">Autorisation validée via SSL Node</p>
                                            </div>
                                            <span className="text-[9px] font-black text-[var(--text-muted)] uppercase">Il y a {i * 2}h</span>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="card-dashboard p-8 border-[var(--error)]/10 bg-[var(--error)]/[0.01]">
                        <h3 className="text-[10px] font-black text-[var(--error)] uppercase tracking-widest mb-4 flex items-center gap-2">
                            <Shield size={14} /> Zone de Révocation
                        </h3>
                        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
                            <div className="flex-1 text-center sm:text-left">
                                <p className="text-xs font-bold text-[var(--text-muted)]">Suspendre ou révoquer les accès de cet agent immédiatement.</p>
                                <p className="text-[9px] text-[var(--text-muted)]/60 mt-1 uppercase tracking-tighter">Action irréversible sans validation Super-Admin.</p>
                            </div>
                            <button className="px-6 py-3 bg-[var(--error)]/10 hover:bg-[var(--error)] text-[var(--error)] hover:text-white rounded-xl border border-[var(--error)]/20 font-black text-[10px] uppercase tracking-widest transition-all active:scale-95 shadow-lg hover:shadow-[var(--error)]/20">
                                Révoquer Accès
                            </button>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    );
}
