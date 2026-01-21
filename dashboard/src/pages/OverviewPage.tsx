import {
    Users,
    ShoppingBag,
    CreditCard,
    TrendingUp,
    ArrowRight,
    Package,
    Store,
    AlertTriangle,
    Activity as ActivityIcon,
    Layers
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { motion, AnimatePresence } from 'framer-motion';
import { usePlatformStats, useDailySales, useRealtimeActivity } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { StatCard, PageHeader, LoadingSpinner, ExpandableValue } from '../components/ui';
import { useState, useEffect } from 'react';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';


export default function OverviewPage() {
    const navigate = useNavigate();
    const { data: stats, isLoading } = usePlatformStats();
    const { data: salesData } = useDailySales(14);
    const { data: activities } = useRealtimeActivity(10);
    const { formatAmount, formatNumber } = useCurrency();
    const [currentTime, setCurrentTime] = useState(new Date());

    useEffect(() => {
        const timer = setInterval(() => setCurrentTime(new Date()), 1000);
        return () => clearInterval(timer);
    }, []);


    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[var(--text-muted)] font-medium animate-pulse uppercase tracking-widest text-xs">Initialisation du Centre de Commandement...</p>
            </div>
        );
    }

    return (
        <div className="space-y-8 pb-20 animate-fade-in">

            {/* PAGE HEADER */}
            <PageHeader
                title="Tableau de bord"
                description={
                    <div className="flex items-center gap-2">
                        <span>Système opérationnel • {format(currentTime, 'EEEE dd MMMM yyyy', { locale: fr })}</span>
                        <span className="w-1.5 h-1.5 rounded-full bg-[var(--success)] animate-pulse" />
                        <span className="text-[var(--primary)] font-mono font-black tracking-widest bg-[var(--primary)]/10 px-2 py-0.5 rounded-md border border-[var(--primary)]/20 shadow-[0_0_10px_var(--primary-glow)]">
                            {format(currentTime, 'HH:mm:ss')}
                        </span>
                    </div>
                }
                actions={
                    <div className="hidden sm:flex items-center gap-3">
                        <div className="px-5 py-2.5 bg-[var(--primary)]/5 border border-[var(--primary)]/20 rounded-2xl flex flex-col items-end shadow-lg shadow-[var(--primary)]/5 min-w-0">
                            <span className="text-[10px] uppercase text-[var(--primary)] font-black tracking-tighter opacity-70 whitespace-nowrap">Volume Total (GMV)</span>
                            <ExpandableValue
                                value={formatAmount(stats?.total_gmv || 0)}
                                className="text-lg font-bold text-[var(--text-primary)] tracking-tight text-right w-full"
                            />
                        </div>
                    </div>
                }
            />

            {/* 1. KPIS GRID - Using Unified StatCard */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6">
                <StatCard
                    label="Revenu Total"
                    value={formatAmount(stats?.total_gmv || 0)}
                    icon={CreditCard}
                    change={12.5}
                    changeLabel="vs mois dernier"
                    variant="info"
                    index={0}
                />
                <StatCard
                    label="Ventes (24h)"
                    value={formatNumber(stats?.sales_last_24h || 0)}
                    icon={ShoppingBag}
                    change={8.2}
                    changeLabel="Commandes aujourd'hui"
                    variant="success"
                    index={1}
                />
                <StatCard
                    label="Boutiques Actives"
                    value={formatNumber(stats?.total_active_shops || 0)}
                    icon={Store}
                    change={5.0}
                    changeLabel="Nouveaux lancements"
                    variant="default"
                    index={2}
                />
                <StatCard
                    label="Dettes en Cours"
                    value={formatAmount(stats?.total_outstanding_debt || 0)}
                    icon={AlertTriangle}
                    change={-2.4}
                    changeLabel="Recouvrement actif"
                    variant="warning"
                    index={3}
                />
            </div>

            {/* 2. MAIN CHARTS & ACTIVITY AREA */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 md:gap-8">

                {/* CHART SECTION (2/3 width) */}
                <motion.div
                    initial={{ opacity: 0, scale: 0.98 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.5, delay: 0.2 }}
                    className="lg:col-span-2 card-dashboard flex flex-col group"
                >
                    <div className="flex justify-between items-center mb-10">
                        <div>
                            <h2 className="text-xl font-bold text-[var(--text-primary)] flex items-center gap-2">
                                <TrendingUp size={20} className="text-[var(--primary)]" />
                                Performance Analytique
                            </h2>
                            <p className="text-[var(--text-muted)] text-sm mt-1">Flux monétaire des 14 derniers jours</p>
                        </div>
                        <div className="flex gap-2">
                            <span className="px-2 py-1 rounded-md bg-[var(--bg-app)] text-[10px] font-bold text-[var(--text-muted)] uppercase">Live</span>
                        </div>
                    </div>

                    <div className="flex-1 min-h-[350px] w-full">
                        <ResponsiveContainer width="100%" height="100%" debounce={100}>
                            <AreaChart data={salesData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                                <defs>
                                    <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="var(--primary)" stopOpacity={0.3} />
                                        <stop offset="95%" stopColor="var(--primary)" stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
                                <XAxis
                                    dataKey="sale_date"
                                    stroke="var(--text-muted)"
                                    tick={{ fontSize: 10, fontWeight: 700, fill: 'var(--text-muted)' }}
                                    tickLine={false}
                                    axisLine={false}
                                    dy={10}
                                    tickFormatter={(value) => new Date(value).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' }).toUpperCase()}
                                />
                                <YAxis
                                    stroke="var(--text-muted)"
                                    tick={{ fontSize: 10, fontWeight: 700, fill: 'var(--text-muted)' }}
                                    tickLine={false}
                                    axisLine={false}
                                    dx={-10}
                                    tickFormatter={(value) => value >= 1000 ? `${(value / 1000).toFixed(0)}k` : value}
                                />
                                <Tooltip
                                    cursor={{ stroke: 'var(--primary)', strokeWidth: 1 }}
                                    contentStyle={{
                                        backgroundColor: 'var(--bg-card)',
                                        backdropFilter: 'blur(10px)',
                                        border: '1px solid var(--border-strong)',
                                        borderRadius: '12px',
                                        boxShadow: '0 10px 30px rgba(0,0,0,0.5)'
                                    }}
                                    itemStyle={{ color: 'var(--primary)', fontSize: '12px', fontWeight: 700 }}
                                    labelStyle={{ color: 'var(--text-primary)', fontSize: '10px', marginBottom: '8px', fontWeight: 900, textTransform: 'uppercase' }}
                                    formatter={(value: any) => [formatAmount(value || 0), 'VOLUME']}
                                />
                                <Area
                                    type="monotone"
                                    dataKey="total_amount"
                                    stroke="var(--primary)"
                                    strokeWidth={4}
                                    fillOpacity={1}
                                    fill="url(#colorRevenue)"
                                    activeDot={{ r: 6, fill: "var(--text-primary)", stroke: "var(--primary)", strokeWidth: 3 }}
                                    animationDuration={2000}
                                />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </motion.div>

                {/* RECENT ACTIVITY & SMALL STATS */}
                <div className="flex flex-col gap-8">

                    {/* Activity Feed (Command Center Style) */}
                    <motion.div
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ duration: 0.5, delay: 0.3 }}
                        className="card-dashboard flex-1"
                    >
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-base font-bold text-[var(--text-primary)] flex items-center gap-2 uppercase tracking-widest">
                                <ActivityIcon size={16} className="text-[var(--success)]" />
                                Monitor Live
                            </h2>
                            <span className="flex items-center gap-1.5 text-[9px] font-black text-[var(--success)] bg-[var(--success)]/10 px-2 py-0.5 rounded-full border border-[var(--success)]/20">
                                <span className="w-1.5 h-1.5 bg-[var(--success)] rounded-full animate-pulse shadow-[0_0_5px_var(--success)]" />
                                CONNECTÉ
                            </span>
                        </div>

                        <div className="space-y-4">
                            {activities?.length === 0 ? (
                                <div className="text-center py-12 text-[var(--text-muted)] flex flex-col items-center gap-3">
                                    <Layers size={32} className="opacity-10" />
                                    <p className="text-xs uppercase font-bold tracking-widest">En attente de données...</p>
                                </div>
                            ) : (
                                <div className="space-y-1">
                                    {activities?.map((activity, idx) => (
                                        <motion.div
                                            key={idx}
                                            initial={{ opacity: 0, x: 10 }}
                                            animate={{ opacity: 1, x: 0 }}
                                            transition={{ duration: 0.3, delay: 0.4 + (idx * 0.05) }}
                                            onClick={() => {
                                                const path = activity.activity_type === 'sale'
                                                    ? `/sales/${activity.entity_id}`
                                                    : `/debts/${activity.entity_id}`;
                                                // @ts-ignore - we assume the entity exists if it shows up in activity
                                                navigate(path);
                                            }}
                                            className="flex items-start gap-4 p-3 rounded-xl hover:bg-[var(--primary)]/10 transition-all group cursor-pointer border border-transparent hover:border-[var(--border-subtle)] active:scale-[0.98]"
                                        >
                                            <div className={`
                                                w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5 border shadow-lg transition-transform group-hover:scale-110
                                                ${activity.activity_type === 'sale' ? 'bg-[var(--primary)]/10 text-[var(--primary)] border-[var(--primary)]/20 shadow-[var(--primary)]/5' : 'bg-[var(--warning)]/10 text-[var(--warning)] border-[var(--warning)]/20 shadow-[var(--warning)]/5'}
                                            `}>
                                                {activity.activity_type === 'sale' ? <ShoppingBag size={14} /> : <AlertTriangle size={14} />}
                                            </div>

                                            <div className="flex-1 min-w-0">
                                                <div className="flex justify-between items-start">
                                                    <p className="text-sm font-bold text-[var(--text-primary)] group-hover:text-[var(--primary)] transition-colors truncate">
                                                        {activity.activity_type === 'sale' ? 'Vente Détectée' : 'Nouvelle Dette'}
                                                    </p>
                                                    <span className="text-[10px] font-black text-[var(--text-muted)] group-hover:text-[var(--text-secondary)] transition-colors bg-[var(--bg-app)] px-1.5 py-0.5 rounded">
                                                        {new Date(activity.activity_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                    </span>
                                                </div>
                                                <p className="text-[11px] text-[var(--text-muted)] mt-0.5 font-medium truncate uppercase tracking-tighter">
                                                    Boutique: <span className="text-[var(--text-secondary)] font-bold">{activity.shop_name}</span>
                                                </p>
                                            </div>
                                        </motion.div>
                                    ))}
                                </div>
                            )}
                        </div>

                        <button
                            onClick={() => navigate('/activity')}
                            className="w-full mt-6 py-3 text-[10px] font-black text-[var(--text-muted)] hover:text-[var(--primary)] hover:bg-[var(--primary)]/5 border border-[var(--border-subtle)] rounded-xl transition-all flex items-center justify-center gap-2 uppercase tracking-widest group shadow-sm active:scale-95"
                        >
                            Consulter l'historique complet <ArrowRight size={14} className="group-hover:translate-x-1 transition-transform" />
                        </button>
                    </motion.div>

                    {/* Infrastructure Overview Mini Grid */}
                    <div className="grid grid-cols-2 gap-4">
                        <motion.div
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ duration: 0.4, delay: 0.5 }}
                            whileHover={{ y: -5, scale: 1.02 }}
                            className="card-dashboard group hover:border-[var(--primary)]/30 transition-all cursor-default"
                        >
                            <div className="flex items-center justify-between mb-2">
                                <Users size={20} className="text-[var(--primary)] group-hover:scale-110 transition-transform" />
                                <span className="text-[9px] font-black text-[var(--primary)] uppercase tracking-widest">+2 today</span>
                            </div>
                            <h4 className="text-2xl font-black text-[var(--text-primary)]">{formatNumber(stats?.total_active_users || 0)}</h4>
                            <p className="text-[10px] text-[var(--text-muted)] font-bold uppercase tracking-widest mt-1">Agents</p>
                        </motion.div>

                        <motion.div
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ duration: 0.4, delay: 0.6 }}
                            whileHover={{ y: -5, scale: 1.02 }}
                            className="card-dashboard group hover:border-[var(--info)]/30 transition-all cursor-default"
                        >
                            <div className="flex items-center justify-between mb-2">
                                <Package size={20} className="text-[var(--info)] group-hover:scale-110 transition-transform" />
                                <span className="text-[9px] font-black text-[var(--info)] uppercase tracking-widest">Global</span>
                            </div>
                            <h4 className="text-2xl font-black text-[var(--text-primary)]">{formatNumber(stats?.total_products || 0)}</h4>
                            <p className="text-[10px] text-[var(--text-muted)] font-bold uppercase tracking-widest mt-1">Articles</p>
                        </motion.div>
                    </div>

                </div>
            </div>
        </div>
    );
}
