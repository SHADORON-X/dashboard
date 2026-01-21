import { useState } from 'react';
import {
    TrendingUp, ArrowUpRight, DollarSign, Activity,
    Target, Share2, Layers, Zap, ArrowRight, MousePointer2
} from 'lucide-react';
import {
    ResponsiveContainer, AreaChart, Area, BarChart, Bar,
    XAxis, YAxis, Tooltip, CartesianGrid, PieChart, Pie, Cell, Legend
} from 'recharts';
import { useNavigate } from 'react-router-dom';
import { format } from 'date-fns';
import { useDailySales, usePlatformStats, useShopsOverview } from '../hooks/useData';
import { useCurrency } from '../contexts/CurrencyContext';
import { PageHeader, StatCard, LoadingSpinner } from '../components/ui';

// --- COLORS PALETTE ---
const CHART_COLORS = ['var(--primary)', '#06b6d4', '#ec4899', '#f59e0b', 'var(--success)', '#8b5cf6'];

// --- MAIN PAGE ---

export default function AnalyticsPage() {
    const navigate = useNavigate();
    const [period, setPeriod] = useState<7 | 14 | 30>(30);
    const { data: dailySales, isLoading: salesLoading } = useDailySales(period);
    const { data: stats, isLoading: statsLoading } = usePlatformStats();
    const { data: shopsData, isLoading: shopsLoading } = useShopsOverview(1, 100);
    const { formatAmount } = useCurrency();

    // Data Processing
    const categoryDistribution = shopsData?.data?.reduce((acc, shop) => {
        const category = shop.category || 'Non classé';
        acc[category] = (acc[category] || 0) + 1;
        return acc;
    }, {} as Record<string, number>) || {};

    const categoryData = Object.entries(categoryDistribution)
        .map(([name, value]) => ({ name, value }))
        .sort((a, b) => b.value - a.value)
        .slice(0, 5);

    const topShops = shopsData?.data?.sort((a, b) => b.total_revenue - a.total_revenue).slice(0, 5) || [];

    // Growth Calculation
    const firstHalf = dailySales?.slice(0, Math.floor(dailySales.length / 2)) || [];
    const secondHalf = dailySales?.slice(Math.floor(dailySales.length / 2)) || [];
    const firstHalfRev = firstHalf.reduce((sum, d) => sum + d.total_amount, 0);
    const secondHalfRev = secondHalf.reduce((sum, d) => sum + d.total_amount, 0);
    const revenueGrowth = firstHalfRev > 0 ? ((secondHalfRev - firstHalfRev) / firstHalfRev * 100).toFixed(1) : '0';

    const isLoading = salesLoading || statsLoading || shopsLoading;

    if (isLoading) {
        return (
            <div className="min-h-[60vh] flex flex-col items-center justify-center gap-4">
                <LoadingSpinner />
                <p className="text-[10px] font-black text-[var(--text-muted)] uppercase tracking-widest animate-pulse">Compilation des données stratégiques...</p>
            </div>
        );
    }

    return (
        <div className="space-y-10 pb-20 animate-fade-in">

            {/* HEADER */}
            <PageHeader
                title="Intelligence D'Affaires"
                description="Visualisez les trajectoires de croissance, la performance des nœuds et la distribution du marché."
                actions={
                    <div className="flex items-center gap-2 bg-[var(--bg-card)] p-1 rounded-2xl border border-[var(--border-subtle)] shadow-inner">
                        {[7, 14, 30].map((days) => (
                            <button
                                key={days}
                                onClick={() => setPeriod(days as any)}
                                className={`px-4 py-2 text-[10px] font-black uppercase tracking-widest rounded-xl transition-all ${period === days
                                    ? 'bg-[var(--primary)] text-white shadow-lg shadow-[var(--primary-glow)]'
                                    : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]'
                                    }`}
                            >
                                {days}J
                            </button>
                        ))}
                    </div>
                }
            />

            {/* KPI ROW */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    label="Volume GMV"
                    value={formatAmount(stats?.total_gmv || 0)}
                    icon={DollarSign}
                    variant="info"
                    change={Number(revenueGrowth)}
                    changeLabel="vs période précédente"
                />
                <StatCard
                    label="Marge Opérationnelle"
                    value={formatAmount(stats?.total_profit || 0)}
                    icon={TrendingUp}
                    variant="success"
                    changeLabel="Profit net consolidé"
                />
                <StatCard
                    label="Panier Moyen"
                    value={formatAmount(stats?.total_sales ? (stats.total_gmv / stats.total_sales) : 0)}
                    icon={Zap}
                    variant="info"
                    changeLabel="Valeur par transaction"
                />
                <StatCard
                    label="Taux d'Engagement"
                    value={`${((stats?.total_active_shops || 0) / (shopsData?.total || 1) * 100).toFixed(1)}%`}
                    icon={Target}
                    variant="warning"
                    changeLabel="Boutiques actives en ligne"
                />
            </div>

            {/* MAIN CHART SECTION */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">

                {/* Evolution Revenue Chart (Wide) */}
                <div className="lg:col-span-2 card-dashboard flex flex-col p-8 group relative overflow-hidden">
                    <div className="absolute top-0 right-0 p-8 opacity-[0.02] pointer-events-none group-hover:scale-110 transition-transform duration-1000">
                        <Activity size={120} />
                    </div>

                    <div className="flex justify-between items-center mb-10 relative z-10">
                        <div>
                            <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Trajectoire Financière</h2>
                            <p className="text-[var(--text-muted)] text-[11px] font-bold uppercase tracking-widest mt-1">Comparatif Revenu vs Profit Net</p>
                        </div>
                        <div className="flex gap-4">
                            <div className="flex items-center gap-2">
                                <span className="w-2 h-2 rounded-full bg-[var(--primary)] shadow-[0_0_8px_var(--primary-glow)]" />
                                <span className="text-[10px] font-black text-[var(--text-secondary)] uppercase">Input</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <span className="w-2 h-2 rounded-full bg-[var(--success)] shadow-[0_0_8px_var(--success)]/40" />
                                <span className="text-[10px] font-black text-[var(--text-secondary)] uppercase">Margin</span>
                            </div>
                        </div>
                    </div>

                    <div className="h-[350px] w-full mt-4">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={dailySales || []}>
                                <defs>
                                    <linearGradient id="colorRev" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="var(--primary)" stopOpacity={0.2} />
                                        <stop offset="95%" stopColor="var(--primary)" stopOpacity={0} />
                                    </linearGradient>
                                    <linearGradient id="colorProf" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="var(--success)" stopOpacity={0.2} />
                                        <stop offset="95%" stopColor="var(--success)" stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" stroke="var(--border-subtle)" vertical={false} />
                                <XAxis
                                    dataKey="sale_date"
                                    stroke="var(--text-muted)"
                                    tick={{ fontSize: 9, fontWeight: 900, fill: 'var(--text-muted)' }}
                                    tickFormatter={(val) => format(new Date(val), 'dd MMM')}
                                    axisLine={false}
                                    tickLine={false}
                                    dy={10}
                                />
                                <YAxis
                                    stroke="var(--text-muted)"
                                    tick={{ fontSize: 9, fontWeight: 900, fill: 'var(--text-muted)' }}
                                    tickFormatter={(val) => val >= 1000 ? `${(val / 1000).toFixed(0)}k` : val}
                                    axisLine={false}
                                    tickLine={false}
                                />
                                <Tooltip
                                    contentStyle={{
                                        backgroundColor: 'var(--bg-card)',
                                        backdropFilter: 'blur(10px)',
                                        border: '1px solid var(--border-strong)',
                                        borderRadius: '16px',
                                        boxShadow: '0 25px 50px -12px rgba(0,0,0,0.5)'
                                    }}
                                    itemStyle={{ fontSize: '11px', fontWeight: 900, textTransform: 'uppercase' }}
                                    labelStyle={{ color: 'var(--text-primary)', marginBottom: '8px' }}
                                    formatter={(value: any) => [formatAmount(value), '']}
                                />
                                <Area type="monotone" dataKey="total_amount" stroke="var(--primary)" strokeWidth={4} fill="url(#colorRev)" name="Revenu" animationDuration={1500} />
                                <Area type="monotone" dataKey="total_profit" stroke="var(--success)" strokeWidth={4} fill="url(#colorProf)" name="Profit" animationDuration={2000} />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* Categories Pie Chart */}
                <div className="card-dashboard flex flex-col p-8 group overflow-hidden">
                    <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Répartition Marché</h2>
                    <p className="text-[var(--text-muted)] text-[11px] font-bold uppercase tracking-widest mt-1 mb-10">Analyse par secteur d'activité</p>

                    <div className="flex-1 min-h-[300px] relative">
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie
                                    data={categoryData}
                                    cx="50%"
                                    cy="45%"
                                    innerRadius={70}
                                    outerRadius={100}
                                    paddingAngle={8}
                                    dataKey="value"
                                    stroke="rgba(0,0,0,0)"
                                >
                                    {categoryData.map((_, index) => (
                                        <Cell key={`cell-${index}`} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                                    ))}
                                </Pie>
                                <Tooltip
                                    contentStyle={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-strong)', borderRadius: '12px' }}
                                    formatter={(val: number | undefined) => [`${val || 0} boutiques`, 'UNILOC']}
                                    itemStyle={{ color: 'var(--text-primary)', fontSize: '10px', fontWeight: 900, textTransform: 'uppercase' }}
                                />
                                <Legend
                                    layout="horizontal"
                                    verticalAlign="bottom"
                                    align="center"
                                    wrapperStyle={{ fontSize: '9px', fontWeight: 900, textTransform: 'uppercase', color: 'var(--text-muted)', paddingTop: '20px' }}
                                />
                            </PieChart>
                        </ResponsiveContainer>

                        {/* Center Text Overlay */}
                        <div className="absolute top-[45%] left-1/2 -translate-x-1/2 -translate-y-[45%] text-center pointer-events-none">
                            <span className="text-3xl font-black text-[var(--text-primary)] block tracking-tighter">{shopsData?.total}</span>
                            <span className="text-[9px] text-[var(--text-muted)] uppercase font-black tracking-widest">Unités</span>
                        </div>
                    </div>
                </div>
            </div>

            {/* Performance Details Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">

                {/* Top Performers Table */}
                <div className="card-dashboard p-8">
                    <div className="flex justify-between items-center mb-8">
                        <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Élite du Réseau</h2>
                        <button className="p-2 text-[var(--text-muted)] hover:text-[var(--text-primary)] transition-colors">
                            <Share2 size={18} />
                        </button>
                    </div>

                    <div className="space-y-3">
                        {topShops.map((shop, idx) => (
                            <div
                                key={shop.shop_id}
                                onClick={() => navigate(`/shops/${shop.shop_id}`)}
                                className="flex items-center gap-5 p-4 rounded-2xl hover:bg-[var(--primary)]/5 border border-transparent hover:border-[var(--border-subtle)] transition-all group cursor-pointer active:scale-[0.98]"
                            >
                                <div className={`
                                    w-12 h-12 rounded-2xl flex items-center justify-center font-black text-lg shadow-xl shrink-0
                                    ${idx === 0 ? 'bg-amber-500/10 text-amber-500 border border-amber-500/20' :
                                        idx === 1 ? 'bg-[var(--text-secondary)]/5 text-[var(--text-secondary)] border border-[var(--border-subtle)]' :
                                            idx === 2 ? 'bg-orange-500/10 text-orange-500 border border-orange-500/20' : 'bg-[var(--bg-app)] border border-[var(--border-subtle)] text-[var(--text-muted)]'}
                                `}>
                                    {idx + 1}
                                </div>

                                <div className="flex-1 min-w-0">
                                    <p className="text-sm font-black text-[var(--text-secondary)] group-hover:text-[var(--primary)] transition-colors truncate uppercase tracking-tight">{shop.shop_name}</p>
                                    <div className="flex items-center gap-3 mt-1">
                                        <span className="text-[10px] text-[var(--text-muted)] font-bold uppercase tracking-widest flex items-center gap-1"><Layers size={10} /> {shop.total_sales} Trx</span>
                                        <div className="w-1 h-1 rounded-full bg-[var(--border-subtle)]" />
                                        <span className="text-[10px] text-[var(--text-muted)] font-bold uppercase tracking-widest">{shop.category}</span>
                                    </div>
                                </div>

                                <div className="text-right">
                                    <p className="text-base font-black text-[var(--text-primary)] font-mono tracking-tighter">{formatAmount(shop.total_revenue)}</p>
                                    <div className="flex items-center justify-end gap-1 mt-1">
                                        <span className="text-[9px] font-black text-[var(--success)] uppercase">Premium</span>
                                        <ArrowUpRight size={12} className="text-[var(--success)]" />
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Sales Volume Bar Chart */}
                <div className="card-dashboard flex flex-col p-8">
                    <div className="flex justify-between items-center mb-8">
                        <h2 className="text-xl font-black text-[var(--text-primary)] uppercase tracking-tighter">Densité Logistique</h2>
                        <div className="px-3 py-1 bg-[var(--bg-app)]/50 rounded-lg text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Volume (Commandes)</div>
                    </div>

                    <div className="flex-1 min-h-[300px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={dailySales || []}>
                                <defs>
                                    <linearGradient id="colorBar" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="0%" stopColor="var(--primary)" stopOpacity={1} />
                                        <stop offset="100%" stopColor="var(--primary)" stopOpacity={0.6} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" stroke="var(--border-subtle)" vertical={false} />
                                <XAxis
                                    dataKey="sale_date"
                                    stroke="var(--text-muted)"
                                    tick={{ fontSize: 9, fontWeight: 900, fill: 'var(--text-muted)' }}
                                    tickFormatter={(val) => format(new Date(val), 'dd')}
                                    axisLine={false}
                                    tickLine={false}
                                    dy={10}
                                />
                                <Tooltip
                                    cursor={{ fill: 'var(--primary)', opacity: 0.05, radius: 8 }}
                                    contentStyle={{ backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-strong)', borderRadius: '12px' }}
                                    itemStyle={{ fontSize: '11px', fontWeight: 900, color: 'var(--text-primary)' }}
                                    labelStyle={{ color: 'var(--text-primary)', marginBottom: '4px' }}
                                />
                                <Bar dataKey="sales_count" name="UNITÉS" fill="url(#colorBar)" radius={[6, 6, 0, 0]} barSize={24} />
                            </BarChart>
                        </ResponsiveContainer>
                    </div>

                    <div className="mt-8 pt-6 border-t border-[var(--border-subtle)] flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <MousePointer2 size={14} className="text-[var(--text-muted)]" />
                            <span className="text-[9px] font-black text-[var(--text-muted)] uppercase tracking-widest">Survolez pour les détails précis</span>
                        </div>
                        <button className="flex items-center gap-2 text-[10px] font-black text-[var(--primary)] uppercase tracking-widest hover:text-[var(--text-primary)] transition-colors">
                            Rapport Complet <ArrowRight size={14} />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
