import {
    Settings, User, LogOut, Shield, Bell,
    Globe, Lock, Database, Layout, Smartphone,
    ChevronRight, CreditCard, HelpCircle
} from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { PageHeader } from '../components/ui';

export default function SettingsPage() {
    const { user, signOut } = useAuth();

    const sections = [
        {
            title: 'Compte & Sécurité',
            icon: Shield,
            items: [
                { label: 'Profil de l\'administrateur', desc: 'Gérez vos informations personnelles et votre avatar.', icon: User },
                { label: 'Mot de passe & Authentification', desc: 'Sécurisez votre accès avec la double-facturation.', icon: Lock },
                { label: 'Sessions Actives', desc: 'Contrôlez les terminaux connectés à votre compte.', icon: Smartphone },
            ]
        },
        {
            title: 'Préférences Système',
            icon: Layout,
            items: [
                { label: 'Interface & Thème', desc: 'Personnalisez l\'apparence de votre centre de commandement.', icon: Layout },
                { label: 'Notifications Live', desc: 'Configurez les alertes sonores et visuelles.', icon: Bell },
                { label: 'Langue & Région', desc: 'Ajustez les formats de date et la monnaie locale.', icon: Globe },
            ]
        },
        {
            title: 'Infrastructure & Data',
            icon: Database,
            items: [
                { label: 'Connexions Supabase', desc: 'Vérifiez l\'état des flux de données et de l\'API.', icon: Database },
                { label: 'Plans & Facturation', desc: 'Consultez votre abonnement Velmo Enterprise.', icon: CreditCard },
                { label: 'Centre d\'aide', desc: 'Documentations techniques et support prioritaires.', icon: HelpCircle },
            ]
        }
    ];

    return (
        <div className="space-y-10 pb-20 animate-fade-in">
            <PageHeader
                title="Configuration Système"
                description="Ajustez les paramètres de votre centre de commandement et gérez vos préférences de sécurité."
            />

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

                {/* Profile Overview Sidebar */}
                <div className="lg:col-span-1 space-y-6">
                    <div className="card-dashboard p-8 flex flex-col items-center text-center relative overflow-hidden group">
                        <div className="absolute inset-0 bg-gradient-to-b from-[var(--primary)]/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

                        <div className="relative w-24 h-24 mb-6">
                            <div className="absolute inset-0 bg-[var(--primary)] blur-2xl opacity-20 animate-pulse" />
                            <div className="relative w-full h-full bg-gradient-to-br from-[var(--primary)] to-violet-700 rounded-[2.5rem] flex items-center justify-center text-3xl font-black text-white shadow-2xl shadow-[var(--primary-glow)] border-2 border-white/10">
                                {user?.email?.[0].toUpperCase() || 'A'}
                            </div>
                            <div className="absolute -bottom-1 -right-1 w-8 h-8 bg-[var(--bg-card)] border-4 border-[var(--bg-card)] rounded-full flex items-center justify-center">
                                <div className="w-full h-full bg-[var(--success)] rounded-full animate-pulse" />
                            </div>
                        </div>

                        <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tight mb-1">{user?.email?.split('@')[0]}</h2>
                        <p className="text-[var(--text-muted)] font-bold text-[10px] uppercase tracking-widest mb-6">Super Administrateur • Velmo HQ</p>

                        <div className="w-full space-y-3">
                            <div className="flex items-center justify-between p-3 rounded-xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] text-xs">
                                <span className="text-[var(--text-muted)] font-bold uppercase">ID Badge</span>
                                <span className="text-[var(--text-secondary)] font-mono">#{user?.id?.slice(0, 8).toUpperCase()}</span>
                            </div>
                            <div className="flex items-center justify-between p-3 rounded-xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] text-xs">
                                <span className="text-[var(--text-muted)] font-bold uppercase">Accès</span>
                                <span className="text-[var(--primary)] font-black uppercase tracking-widest text-[9px]">Root Privilege</span>
                            </div>
                        </div>

                        <button
                            onClick={() => signOut()}
                            className="w-full mt-8 py-4 bg-[var(--error)]/10 hover:bg-[var(--error)] text-[var(--error)] hover:text-white rounded-2xl border border-[var(--error)]/20 transition-all font-black text-[10px] uppercase tracking-widest flex items-center justify-center gap-2 active:scale-95 shadow-lg hover:shadow-[var(--error)]/20"
                        >
                            <LogOut size={14} /> Terminer la Session
                        </button>
                    </div>

                    <div className="card-dashboard bg-gradient-to-br from-[var(--bg-card)] to-[var(--bg-app)] border-[var(--primary)]/10">
                        <h3 className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-4">Statut Infrastructure</h3>
                        <div className="space-y-3">
                            <div className="flex items-center gap-3">
                                <div className="w-2 h-2 rounded-full bg-[var(--success)] shadow-[0_0_8px_var(--success)]" />
                                <span className="text-xs font-bold text-[var(--text-secondary)]">Database Core</span>
                                <span className="ml-auto text-[10px] font-mono text-[var(--text-muted)]">v2.4.0</span>
                            </div>
                            <div className="flex items-center gap-3">
                                <div className="w-2 h-2 rounded-full bg-[var(--success)] shadow-[0_0_8px_var(--success)]" />
                                <span className="text-xs font-bold text-[var(--text-secondary)]">Realtime Engine</span>
                                <span className="ml-auto text-[10px] font-mono text-[var(--text-muted)]">Stable</span>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Settings Matrix */}
                <div className="lg:col-span-2 space-y-8">
                    {sections.map((section, idx) => (
                        <div key={idx} className="space-y-4">
                            <h3 className="text-[11px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] ml-2 flex items-center gap-2">
                                <section.icon size={14} className="text-[var(--primary)]" /> {section.title}
                            </h3>
                            <div className="grid grid-cols-1 gap-3">
                                {section.items.map((item, i) => (
                                    <button
                                        key={i}
                                        className="card-dashboard p-5 flex items-center gap-5 hover:bg-[var(--primary)]/5 transition-all group text-left border-[var(--border-subtle)] active:scale-[0.99]"
                                    >
                                        <div className="w-12 h-12 rounded-2xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)] group-hover:bg-[var(--primary)] group-hover:text-white group-hover:border-[var(--primary)]/50 transition-all duration-300">
                                            <item.icon size={20} />
                                        </div>
                                        <div className="flex-1">
                                            <h4 className="text-sm font-bold text-[var(--text-primary)] mb-0.5">{item.label}</h4>
                                            <p className="text-xs text-[var(--text-muted)] font-medium">{item.desc}</p>
                                        </div>
                                        <ChevronRight size={16} className="text-[var(--text-muted)] group-hover:text-[var(--text-primary)] group-hover:translate-x-1 transition-all" />
                                    </button>
                                ))}
                            </div>
                        </div>
                    ))}

                    <div className="pt-10 flex flex-col items-center justify-center text-center opacity-30">
                        <Settings size={40} className="text-[var(--text-muted)] mb-4 animate-spin-slow" />
                        <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.3em]">Velmo Cloud OS v4.2.0 • Build 2024.01</p>
                    </div>
                </div>

            </div>
        </div>
    );
}
