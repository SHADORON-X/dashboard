import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, Store, Package, ShoppingCart, DollarSign,
    TrendingUp, Phone, MapPin,
    CreditCard, Share2, MoreVertical, LayoutGrid,
    Search, Activity as ActivityIcon, ShieldCheck,
    AlertCircle, Receipt
} from 'lucide-react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';

import { useShopDetails } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { StatCard, StatusBadge, DataTable, LoadingSpinner, EmptyState } from '../components/ui';

// --- COMPONENTS ---

const TabButton = ({ active, onClick, icon: Icon, label }: { active: boolean, onClick: () => void, icon: any, label: string }) => (
    <button
        onClick={onClick}
        className={`flex items-center gap-2.5 px-6 py-4 text-xs font-black uppercase tracking-widest transition-all relative
            ${active
                ? 'text-[var(--text-primary)]'
                : 'text-[var(--text-muted)] hover:text-[var(--text-secondary)]'
            }`}
    >
        <Icon size={14} className={active ? 'text-[var(--primary)]' : ''} />
        {label}
        {active && (
            <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[var(--primary)] shadow-[var(--primary-glow)]" />
        )}
    </button>
);

// --- MAIN PAGE ---

export default function ShopDetailPage() {
    const { shopId } = useParams<{ shopId: string }>();
    const navigate = useNavigate();
    const { data: details, isLoading } = useShopDetails(shopId || null);
    const { formatAmount } = useCurrency();
    const [activeTab, setActiveTab] = useState<'overview' | 'sales' | 'stock' | 'debts'>('overview');

    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Chargement de l'unité opérationnelle...</p>
            </div>
        );
    }

    if (!details) {
        return (
            <EmptyState
                icon={Store}
                title="Boutique introuvable"
                description="Le terminal spécifié n'existe pas ou n'est plus enregistré dans le réseau."
                action={
                    <button onClick={() => navigate('/shops')} className="px-6 py-2.5 bg-[var(--bg-app)] border border-[var(--border-subtle)] text-[var(--text-primary)] rounded-xl font-bold transition-all text-xs uppercase tracking-widest hover:bg-[var(--bg-card)]">
                        Retour au réseau
                    </button>
                }
            />
        );
    }

    const { shop, owner, stats, recent_sales, low_stock_products, active_debts, team } = details;

    // Mock chart data (we'll use recent_sales dates)
    const chartData = recent_sales.map(s => ({
        date: format(new Date(s.created_at), 'dd MMM'),
        amount: s.total_amount
    })).reverse();

    return (
        <div className="space-y-8 pb-20 animate-fade-in">

            {/* HEADER AREA */}
            <div className="flex flex-col gap-8">
                {/* Top Bar Actions */}
                <div className="flex items-center justify-between">
                    <button
                        onClick={() => navigate('/shops')}
                        className="flex items-center gap-2 text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all group px-4 py-2 rounded-xl bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] active:scale-95"
                    >
                        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
                        <span className="text-[10px] font-black uppercase tracking-widest">Retour au réseau</span>
                    </button>

                    <div className="flex items-center gap-2">
                        <button className="p-2.5 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/5 rounded-xl border border-[var(--border-subtle)] transition-all">
                            <Share2 size={18} />
                        </button>
                        <button className="p-2.5 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/5 rounded-xl border border-[var(--border-subtle)] transition-all">
                            <MoreVertical size={18} />
                        </button>
                    </div>
                </div>

                {/* Identity Profile (Glassmorphism) */}
                <div className="card-dashboard p-0 overflow-hidden relative group">
                    <div className="absolute inset-0 bg-gradient-to-br from-indigo-500/10 via-transparent to-transparent pointer-events-none" />

                    <div className="h-40 bg-[url('https://images.unsplash.com/photo-1534489503337-33f749007c91?q=80&w=2000&auto=format&fit=crop')] bg-cover bg-center brightness-[0.2]" />

                    <div className="px-8 pb-10 mt-[-60px] flex flex-col lg:flex-row items-end justify-between gap-8 relative z-10">
                        <div className="flex flex-col sm:flex-row items-end gap-6 w-full lg:w-auto">
                            <div className="w-32 h-32 rounded-[2.5rem] bg-[var(--bg-card)] border-[6px] border-[var(--bg-app)] flex items-center justify-center shadow-2xl overflow-hidden relative group-hover:scale-105 transition-transform duration-700">
                                <div className="absolute inset-0 bg-[var(--primary)]/10 animate-pulse-slow" />
                                <Store size={48} className="text-[var(--primary)] relative z-10" />
                            </div>

                            <div className="flex-1 pb-2">
                                <div className="flex flex-wrap items-center gap-3 mb-2">
                                    <h1 className="text-4xl font-black text-[var(--text-primary)] tracking-tighter uppercase">{shop.name}</h1>
                                    <StatusBadge
                                        status={shop.is_active ? 'success' : 'inactive'}
                                        label={shop.is_active ? 'OPÉRATIONNELLE' : 'INACTIF'}
                                    />
                                </div>
                                <div className="flex flex-wrap items-center gap-4 text-[var(--text-muted)] text-[10px] font-black uppercase tracking-[0.2em]">
                                    <span className="flex items-center gap-1.5"><MapPin size={12} className="text-[var(--primary)]" /> {shop.address || 'Héliopolis Centre'}</span>
                                    <span className="w-1.5 h-1.5 rounded-full bg-[var(--border-subtle)]" />
                                    <span className="flex items-center gap-1.5"><LayoutGrid size={12} /> {shop.category || 'Retail'}</span>
                                    <span className="w-1.5 h-1.5 rounded-full bg-[var(--border-subtle)]" />
                                    <span className="flex items-center gap-1.5 font-mono text-[var(--primary)]">{shop.velmo_id}</span>
                                </div>
                            </div>
                        </div>

                        {/* Owner Section */}
                        <div className="flex items-center gap-5 bg-[var(--bg-app)]/50 backdrop-blur-2xl p-4 rounded-3xl border border-[var(--border-subtle)] shadow-2xl min-w-[280px]">
                            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[var(--primary)] to-indigo-600 text-white flex items-center justify-center font-black text-lg shadow-lg shadow-[var(--primary)]/20">
                                {owner?.first_name?.[0]}{owner?.last_name?.[0]}
                            </div>
                            <div className="flex-1">
                                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest mb-1">Responsable Nœud</p>
                                <p className="text-base font-bold text-[var(--text-primary)]">{owner?.first_name} {owner?.last_name}</p>
                                <div className="flex items-center gap-2 mt-1">
                                    <Phone size={10} className="text-[var(--text-muted)]/50" />
                                    <span className="text-[10px] font-mono text-[var(--text-muted)]">{owner?.phone || 'Non renseigné'}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* TABS NAVIGATION */}
                <div className="flex items-center justify-between border-b border-[var(--border-subtle)] bg-[var(--bg-card)] rounded-t-3xl px-2">
                    <div className="flex overflow-x-auto no-scrollbar">
                        <TabButton
                            label="Centre Analytique"
                            icon={TrendingUp}
                            active={activeTab === 'overview'}
                            onClick={() => setActiveTab('overview')}
                        />
                        <TabButton
                            label="Transactions"
                            icon={ShoppingCart}
                            active={activeTab === 'sales'}
                            onClick={() => setActiveTab('sales')}
                        />
                        <TabButton
                            label="Inventaire Local"
                            icon={Package}
                            active={activeTab === 'stock'}
                            onClick={() => setActiveTab('stock')}
                        />
                        <TabButton
                            label="Flux Financiers"
                            icon={DollarSign}
                            active={activeTab === 'debts'}
                            onClick={() => setActiveTab('debts')}
                        />
                    </div>
                    <div className="hidden md:flex items-center gap-2 pr-6">
                        <span className="flex items-center gap-1.5 text-[9px] font-black text-[var(--success)] bg-[var(--success)]/10 px-2 py-0.5 rounded-full border border-[var(--success)]/20">
                            <span className="w-1.5 h-1.5 bg-[var(--success)] rounded-full animate-pulse" />
                            FLUX LIVE
                        </span>
                    </div>
                </div>
            </div>

            {/* TAB CONTENT: OVERVIEW */}
            {activeTab === 'overview' && (
                <div className="space-y-8 animate-fade-in">
                    {/* Key Stats Row */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                        <StatCard
                            label="Volume (24h)"
                            value={formatAmount(stats.revenue_today)}
                            icon={DollarSign}
                            variant="info"
                            changeLabel={`${stats.sales_today} ventes aujourd'hui`}
                        />
                        <StatCard
                            label="Marge Brute"
                            value={formatAmount(stats.profit_today)}
                            icon={TrendingUp}
                            variant="success"
                            changeLabel="Sur volume réalisé"
                        />
                        <StatCard
                            label="Alerte Logistique"
                            value={stats.low_stock_count}
                            icon={Package}
                            variant={stats.low_stock_count > 0 ? 'warning' : 'default'}
                            changeLabel="Unités critiques"
                        />
                        <StatCard
                            label="Risque Client"
                            value={formatAmount(stats.total_debt_amount)}
                            icon={CreditCard}
                            variant="error"
                            changeLabel={`${stats.active_debts} dossiers ouverts`}
                        />
                    </div>

                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                        {/* PERFORMANCE CHART (Centerpiece) */}
                        <div className="lg:col-span-2 card-dashboard flex flex-col group p-8">
                            <div className="flex justify-between items-center mb-8">
                                <div>
                                    <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Dynamique Commerciale</h2>
                                    <p className="text-[var(--text-muted)] text-[11px] font-bold uppercase tracking-widest mt-1">Évolution des volumes récents</p>
                                </div>
                                <div className="flex gap-2">
                                    <div className="p-2 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] text-[var(--text-muted)]">
                                        <ActivityIcon size={16} />
                                    </div>
                                </div>
                            </div>

                            <div className="h-[300px] w-full mt-4">
                                <ResponsiveContainer width="100%" height="100%">
                                    <AreaChart data={chartData}>
                                        <defs>
                                            <linearGradient id="colorShop" x1="0" y1="0" x2="0" y2="1">
                                                <stop offset="5%" stopColor="var(--primary)" stopOpacity={0.3} />
                                                <stop offset="95%" stopColor="var(--primary)" stopOpacity={0} />
                                            </linearGradient>
                                        </defs>
                                        <CartesianGrid strokeDasharray="3 3" stroke="var(--border-subtle)" strokeOpacity={0.3} vertical={false} />
                                        <XAxis
                                            dataKey="date"
                                            stroke="var(--text-muted)"
                                            tick={{ fontSize: 9, fontWeight: 900, fill: 'var(--text-muted)' }}
                                            axisLine={false}
                                            tickLine={false}
                                            dy={10}
                                        />
                                        <YAxis
                                            hide
                                        />
                                        <Tooltip
                                            contentStyle={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: '12px' }}
                                            itemStyle={{ color: 'var(--primary)', fontSize: '12px', fontWeight: 900 }}
                                            formatter={(value: any) => [formatAmount(value), 'REVENU']}
                                        />
                                        <Area
                                            type="monotone"
                                            dataKey="amount"
                                            stroke="var(--primary)"
                                            strokeWidth={4}
                                            fillOpacity={1}
                                            fill="url(#colorShop)"
                                            animationDuration={2000}
                                        />
                                    </AreaChart>
                                </ResponsiveContainer>
                            </div>
                        </div>

                        {/* TEAM & OPERATIONAL INFO */}
                        <div className="flex flex-col gap-8">
                            <div className="card-dashboard">
                                <h3 className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] mb-6 flex items-center justify-between">
                                    Effectif Affecté
                                    <span className="text-[var(--text-muted)] bg-[var(--bg-app)]/50 px-2 py-0.5 rounded-lg">{team.length}</span>
                                </h3>
                                <div className="space-y-5">
                                    {team.map((member: any) => (
                                        <div key={member.id} className="flex items-center gap-4 group/member">
                                            <div className="w-10 h-10 rounded-xl bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-xs font-black text-[var(--text-muted)] group-hover/member:border-[var(--primary)]/30 group-hover/member:text-[var(--primary)] transition-all">
                                                {member.users?.first_name?.[0]}
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-sm font-bold text-[var(--text-secondary)] group-hover/member:text-[var(--text-primary)] transition-colors truncate">
                                                    {member.users?.first_name} {member.users?.last_name}
                                                </p>
                                                <p className="text-[10px] text-[var(--text-muted)] font-black uppercase tracking-widest mt-0.5">{member.role}</p>
                                            </div>
                                            <div className="w-2 h-2 rounded-full bg-[var(--success)] animate-pulse" title="En ligne" />
                                        </div>
                                    ))}
                                </div>
                                <button className="w-full mt-8 py-3 bg-[var(--bg-app)]/50 border border-[var(--border-subtle)] rounded-xl text-[10px] font-black uppercase tracking-widest text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--primary)]/5 transition-all">
                                    Modifier l'équipe
                                </button>
                            </div>

                            <div className="card-dashboard bg-[var(--bg-app)] border-[var(--primary)]/20">
                                <h3 className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-[0.2em] mb-4">Statut Système</h3>
                                <div className="space-y-3">
                                    <div className="flex items-center justify-between p-3 rounded-xl bg-[var(--bg-card)]/50">
                                        <span className="text-xs font-bold text-[var(--text-muted)]">Dernière Sync</span>
                                        <span className="text-xs font-mono text-[var(--text-primary)]">Il y a 2m</span>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-xl bg-[var(--bg-card)]/50">
                                        <span className="text-xs font-bold text-[var(--text-muted)]">Terminal ID</span>
                                        <span className="text-xs font-mono text-[var(--primary)]">VLM-X-092</span>
                                    </div>
                                    <div className="flex items-center justify-between p-3 rounded-xl bg-[var(--success)]/5 border border-[var(--success)]/10">
                                        <span className="text-xs font-bold text-[var(--success)]">Service Cloud</span>
                                        <ShieldCheck size={14} className="text-[var(--success)]" />
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* TAB CONTENT: STOCK */}
            {activeTab === 'stock' && (
                <div className="space-y-6 animate-fade-in">
                    <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-[var(--bg-card)] p-3 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                        <div className="relative flex-1">
                            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
                            <input
                                type="text"
                                placeholder="Filtrer l'inventaire local..."
                                className="w-full bg-transparent border-none rounded-xl pl-12 pr-4 py-3 text-sm text-[var(--text-primary)] focus:ring-0 placeholder-[var(--text-muted)]/50 font-bold"
                            />
                        </div>
                        <button className="px-5 py-2.5 bg-[var(--primary)] text-white rounded-xl font-black text-[10px] uppercase tracking-widest shadow-lg shadow-[var(--primary-glow)]">
                            Réapprovisionner
                        </button>
                    </div>

                    <div className="card-dashboard p-0 overflow-hidden">
                        <DataTable
                            columns={[
                                {
                                    key: 'name', header: 'Référence', className: 'w-[40%]',
                                    render: (p: any) => (
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] flex items-center justify-center text-[var(--text-muted)]">
                                                <Package size={14} />
                                            </div>
                                            <span className="font-bold text-[var(--text-secondary)]">{p.name}</span>
                                        </div>
                                    )
                                },
                                {
                                    key: 'quantity', header: 'Stock', className: 'w-[20%]',
                                    render: (p: any) => (
                                        <span className={`text-base font-black ${p.quantity <= p.stock_alert ? 'text-[var(--warning)]' : 'text-[var(--text-primary)]'}`}>
                                            {p.quantity}
                                        </span>
                                    )
                                },
                                {
                                    key: 'alert', header: 'Seuil', className: 'w-[20%]',
                                    render: (p: any) => <span className="text-xs font-mono text-[var(--text-muted)]">{p.stock_alert} Unités</span>
                                },
                                {
                                    key: 'price', header: 'Prix Unitaire', className: 'w-[20%] text-right',
                                    render: (p: any) => <span className="font-mono font-bold text-[var(--text-primary)] pr-4">{formatAmount(p.price_sale)}</span>
                                }
                            ]}
                            data={low_stock_products}
                            emptyMessage="Inventaire opérationnel. Aucune rupture détectée."
                            keyExtractor={(p) => p.id}
                        />
                    </div>
                </div>
            )}

            {/* TAB CONTENT: DEBTS */}
            {activeTab === 'debts' && (
                <div className="space-y-6 animate-fade-in">
                    <div className="card-dashboard p-8 bg-[var(--error)]/5 border-[var(--error)]/20">
                        <div className="flex items-center gap-4 mb-2">
                            <AlertCircle className="text-[var(--error)]" size={24} />
                            <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Gestion du Risque Client</h2>
                        </div>
                        <p className="text-[var(--text-muted)] text-sm max-w-2xl font-medium">Auditez les créances en suspens spécifiquement pour ce terminal. Tout retard peut impacter la liquidité de la boutique.</p>
                    </div>

                    <div className="card-dashboard p-0 overflow-hidden">
                        <DataTable
                            columns={[
                                {
                                    key: 'customer', header: 'Débiteur', className: 'w-[40%]',
                                    render: (d: any) => (
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-full bg-[var(--error)]/10 text-[var(--error)] flex items-center justify-center text-[10px] font-black">
                                                {d.customer_name[0]}
                                            </div>
                                            <span className="font-bold text-[var(--text-secondary)]">{d.customer_name}</span>
                                        </div>
                                    )
                                },
                                {
                                    key: 'amount', header: 'Reliquat', className: 'w-[30%]',
                                    render: (d: any) => <span className="text-lg font-black text-[var(--error)] font-mono">{formatAmount(d.remaining_amount)}</span>
                                },
                                {
                                    key: 'date', header: 'Ouvert le', className: 'w-[30%] text-right',
                                    render: (d: any) => <span className="text-xs font-black text-[var(--text-muted)] uppercase pr-4">{format(new Date(d.created_at), 'dd MMM yyyy', { locale: fr })}</span>
                                }
                            ]}
                            data={active_debts}
                            emptyMessage="Aucune créance enregistrée pour cette boutique."
                            keyExtractor={(d) => d.id}
                        />
                    </div>
                </div>
            )}

            {/* TAB CONTENT: SALES */}
            {activeTab === 'sales' && (
                <div className="space-y-6 animate-fade-in">
                    <div className="card-dashboard p-0 overflow-hidden">
                        <DataTable
                            columns={[
                                {
                                    key: 'date', header: 'Date / Heure', className: 'w-[30%]',
                                    render: (s: any) => (
                                        <div className="flex flex-col">
                                            <span className="text-[var(--text-secondary)] font-bold">{format(new Date(s.created_at), 'dd MMM yyyy', { locale: fr })}</span>
                                            <span className="text-[10px] text-[var(--text-muted)] font-black">{format(new Date(s.created_at), 'HH:mm')}</span>
                                        </div>
                                    )
                                },
                                {
                                    key: 'items', header: 'Poids Panier', className: 'w-[20%]',
                                    render: (s: any) => <span className="text-sm font-bold text-[var(--text-muted)]">{s.items_count} articles</span>
                                },
                                {
                                    key: 'total', header: 'Volume', className: 'w-[30%]',
                                    render: (s: any) => <span className="text-base font-black text-[var(--text-primary)] font-mono">{formatAmount(s.total_amount)}</span>
                                },
                                {
                                    key: 'action', header: '', className: 'w-[20%] text-right',
                                    render: () => (
                                        <button className="p-2 text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-all pr-4">
                                            <Receipt size={16} />
                                        </button>
                                    )
                                }
                            ]}
                            data={recent_sales}
                            emptyMessage="Aucune transaction récente identifiée."
                            keyExtractor={(s) => s.id}
                        />
                    </div>
                </div>
            )}

        </div>
    );
}
