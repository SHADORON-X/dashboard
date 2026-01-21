import React, { useState, useEffect } from 'react';
import { Outlet, useLocation, Link, useNavigate } from 'react-router-dom';
import {
    LayoutDashboard, Store, Activity, FileText, BarChart2,
    AlertTriangle, Settings, Search, Bell, LogOut, ChevronDown,
    Menu, X, Users, Package, ShoppingBag, FileWarning,
    Sun, Moon, Monitor, Globe
} from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useCurrency } from '../contexts/CurrencyContext';
import { useTheme } from '../contexts/ThemeContext';
import type { CurrencyCode } from '../contexts/CurrencyContext';
import { CommandPalette } from './CommandPalette';
import { RealtimeMonitor } from './RealtimeMonitor';
import { useToast } from '../contexts/ToastContext';
import { formatDistanceToNow } from 'date-fns';
import { fr } from 'date-fns/locale';

// --- CONFIGURATION NAVIGATION ---
const NAV_ITEMS = [
    { path: '/', label: 'Overview', icon: LayoutDashboard, section: 'Plateforme' },
    { path: '/shops', label: 'Boutiques', icon: Store, section: 'Gestion' },
    { path: '/users', label: 'Utilisateurs', icon: Users, section: 'Gestion' },
    { path: '/products', label: 'Produits Global', icon: Package, section: 'Gestion' },
    { path: '/sales', label: 'Ventes', icon: ShoppingBag, section: 'Finance' },
    { path: '/debts', label: 'Dettes & Crédits', icon: FileWarning, section: 'Finance' },
    { path: '/services', label: 'Services Digitaux', icon: Globe, section: 'Online' },
    { path: '/analytics', label: 'Analytics', icon: BarChart2, section: 'Monitoring' },
    { path: '/activity', label: 'Activité Live', icon: Activity, section: 'Monitoring' },
    { path: '/alerts', label: 'Alertes Stock', icon: AlertTriangle, section: 'Monitoring' },
    { path: '/logs', label: 'Logs & Système', icon: FileText, section: 'Monitoring' },
    { path: '/settings', label: 'Paramètres', icon: Settings, section: 'Configuration' },
];

export default function Layout() {
    const { pathname } = useLocation();
    const navigate = useNavigate();
    const { user, signOut } = useAuth();
    const { currency, setCurrency } = useCurrency();
    const { theme, setTheme } = useTheme();
    const { history, clearHistory } = useToast();

    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const [isProfileOpen, setIsProfileOpen] = useState(false);
    const [isSearchOpen, setIsSearchOpen] = useState(false);
    const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);

    // Keyboard Shortcut for Search (Cmd+K)
    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
                e.preventDefault();
                setIsSearchOpen(true);
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);

    const handleSignOut = async () => {
        await signOut();
        navigate('/login');
    };

    const NavGroup = ({ items, onClose }: { items: typeof NAV_ITEMS, onClose?: () => void }) => {
        let lastSection = '';
        return (
            <>
                {items.map((item) => {
                    const isActive = pathname === item.path;
                    const Icon = item.icon;
                    const showSection = item.section !== lastSection;
                    lastSection = item.section;

                    return (
                        <React.Fragment key={item.path}>
                            {showSection && (
                                <div className="text-xs font-semibold text-zinc-500 uppercase tracking-wider mb-2 mt-6 px-4">
                                    {item.section}
                                </div>
                            )}
                            <Link
                                to={item.path}
                                onClick={onClose}
                                className={`nav-link mx-2 ${isActive ? 'active' : ''}`}
                            >
                                <Icon size={18} className={isActive ? 'text-[var(--primary)]' : 'text-[var(--text-muted)] group-hover:text-[var(--primary)]'} />
                                <span className={isActive ? 'text-[var(--primary)] font-medium' : ''}>{item.label}</span>
                            </Link>
                        </React.Fragment>
                    );
                })}
            </>
        );
    };

    return (
        <div className="flex min-h-screen bg-app font-sans text-zinc-100 selection:bg-indigo-500/30">
            <RealtimeMonitor />

            {/* 1. SIDEBAR DESKTOP (Fixed) */}
            <aside className="hidden lg:flex w-[280px] sidebar-glass flex-col fixed inset-y-0 z-50 transition-all duration-300">

                {/* Logo Area */}
                <div className="h-[80px] flex items-center px-6 border-b border-[var(--border-subtle)] shrink-0">
                    <div className="flex items-center gap-3 group cursor-pointer">
                        <div className="relative w-10 h-10 rounded-xl bg-gradient-to-tr from-[var(--primary)] to-violet-600 flex items-center justify-center font-bold text-white shadow-[0_0_15px_var(--primary-glow)] group-hover:shadow-[0_0_25px_var(--primary-glow)] transition-all duration-500">
                            <span className="text-xl">V</span>
                            <div className="absolute inset-0 rounded-xl bg-white/20 opacity-0 group-hover:opacity-100 transition-opacity" />
                        </div>
                        <span className="text-2xl font-bold tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-[var(--text-primary)] to-[var(--text-muted)] group-hover:to-[var(--text-primary)] transition-all">Velmo</span>
                    </div>
                </div>

                {/* Navigation */}
                <div className="flex-1 overflow-y-auto py-6 px-3 custom-scrollbar">
                    <NavGroup items={NAV_ITEMS} />
                </div>

                {/* User Footer (Sidebar) */}
                <div className="p-4 border-t border-[var(--border-subtle)] shrink-0 bg-[var(--bg-card)]/50 backdrop-blur-sm mt-auto">
                    <Link to="/settings" className="flex items-center gap-3 p-3 rounded-xl hover:bg-[var(--bg-card-hover)] transition-all group border border-transparent hover:border-[var(--border-subtle)]">
                        <div className="w-10 h-10 rounded-full bg-[var(--primary)]/10 flex items-center justify-center text-sm font-bold text-[var(--primary)] group-hover:bg-[var(--primary)] group-hover:text-white transition-all shadow-inner border border-[var(--primary)]/20">
                            {user?.email?.charAt(0).toUpperCase() || 'A'}
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-[var(--text-primary)] truncate group-hover:text-[var(--text-primary)] transition-colors">
                                {user?.email?.split('@')[0]}
                            </p>
                            <div className="flex items-center gap-1.5 mt-0.5">
                                <span className="w-1.5 h-1.5 rounded-full bg-[var(--success)] shadow-[0_0_5px_var(--success)]" />
                                <p className="text-[10px] text-[var(--text-muted)] uppercase tracking-widest font-bold">En ligne</p>
                            </div>
                        </div>
                    </Link>
                </div>
            </aside>

            {/* 2. MAIN CONTENT AREA */}
            <div className="flex-1 flex flex-col lg:ml-[280px] min-h-screen relative w-full overflow-x-hidden">

                {/* Header (Sticky & Glassy) */}
                <header className="h-[80px] sticky top-0 z-40 bg-[var(--bg-app)]/70 backdrop-blur-xl border-b border-[var(--border-subtle)] px-6 flex items-center justify-between shadow-sm">

                    {/* Mobile Menu Trigger */}
                    <button
                        className="lg:hidden p-2 -ml-2 text-zinc-400 hover:text-white hover:bg-white/5 rounded-lg transition-colors"
                        onClick={() => setIsMobileMenuOpen(true)}
                    >
                        <Menu size={24} />
                    </button>

                    {/* Search Bar Global (Click Trigger) */}
                    <div className="hidden md:flex items-center w-full max-w-xl mx-4 group">
                        <div
                            onClick={() => setIsSearchOpen(true)}
                            className="relative w-full transition-all duration-300 transform group-focus-within:scale-[1.02] cursor-pointer"
                        >
                            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                                <Search size={18} className="text-[var(--text-muted)] group-hover:text-[var(--primary)] transition-colors" />
                            </div>
                            <div className="block w-full pl-10 pr-12 py-2.5 border border-[var(--border-subtle)] rounded-xl leading-5 bg-[var(--bg-card)]/50 text-[var(--text-secondary)] font-medium sm:text-sm transition-all shadow-inner hover:border-[var(--border-strong)] hover:bg-[var(--bg-card)] group-hover:shadow-lg">
                                Rechercher partout (Cmd+K)...
                            </div>
                            <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                                <kbd className="hidden sm:inline-block px-2 py-0.5 text-[10px] font-bold text-[var(--text-muted)] bg-[var(--bg-card)] rounded border border-[var(--border-subtle)] shadow-sm">⌘K</kbd>
                            </div>
                        </div>
                    </div>

                    {/* Right Actions */}
                    <div className="flex items-center gap-4 ml-auto">

                        {/* Theme Switcher */}
                        <div className="flex items-center bg-[var(--bg-card)]/80 rounded-lg border border-[var(--border-subtle)] p-1 shadow-inner">
                            <button
                                onClick={() => setTheme('light')}
                                className={`p-1.5 rounded-md transition-all ${theme === 'light' ? 'bg-[var(--primary)] text-white shadow-sm' : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]'}`}
                                title="Mode Clair"
                            >
                                <Sun size={14} />
                            </button>
                            <button
                                onClick={() => setTheme('dark')}
                                className={`p-1.5 rounded-md transition-all ${theme === 'dark' ? 'bg-[var(--primary)] text-white shadow-sm' : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]'}`}
                                title="Mode Sombre"
                            >
                                <Moon size={14} />
                            </button>
                            <button
                                onClick={() => setTheme('system')}
                                className={`p-1.5 rounded-md transition-all ${theme === 'system' ? 'bg-[var(--primary)] text-white shadow-sm' : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]'}`}
                                title="Système"
                            >
                                <Monitor size={14} />
                            </button>
                        </div>

                        {/* Currency Selector */}
                        <div className="hidden sm:flex items-center bg-[var(--bg-card)]/80 rounded-lg border border-[var(--border-subtle)] p-1 shadow-inner">
                            {(['GNF', 'EUR', 'USD'] as CurrencyCode[]).map((code) => (
                                <button
                                    key={code}
                                    onClick={() => setCurrency(code)}
                                    className={`
                    px-3 py-1.5 text-[10px] font-bold rounded-md transition-all uppercase tracking-wider
                    ${currency === code
                                            ? 'bg-[var(--bg-app)] text-[var(--text-primary)] shadow-sm border border-[var(--border-subtle)]'
                                            : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-app)]/50'}
                  `}
                                >
                                    {code}
                                </button>
                            ))}
                        </div>

                        {/* Notifications */}
                        <div className="relative">
                            <button
                                onClick={() => setIsNotificationsOpen(!isNotificationsOpen)}
                                className={`relative p-2.5 rounded-xl text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-card-hover)] transition-all active:scale-95 group ${history.length > 0 ? 'animate-swing' : ''}`}
                            >
                                <Bell size={20} className={history.length > 0 ? 'text-[var(--primary)]' : ''} />
                                {history.length > 0 && (
                                    <span className="absolute top-2.5 right-2.5 w-2.5 h-2.5 bg-[var(--primary)] rounded-full border-2 border-[var(--bg-app)] shadow-[0_0_10px_var(--primary)] animate-pulse"></span>
                                )}
                            </button>

                            {/* Notifications Dropdown */}
                            {isNotificationsOpen && (
                                <>
                                    <div className="fixed inset-0 z-30" onClick={() => setIsNotificationsOpen(false)} />
                                    <div className="absolute right-0 mt-4 w-80 sm:w-96 bg-[#0e0e11] border border-zinc-800 rounded-2xl shadow-2xl shadow-black py-0 z-40 animate-slide-in-up origin-top-right ring-1 ring-white/5 backdrop-blur-2xl overflow-hidden">
                                        <div className="px-4 py-4 border-b border-white/5 bg-white/[0.02] flex items-center justify-between">
                                            <div className="flex items-center gap-2">
                                                <h3 className="text-sm font-bold text-white">Notifications</h3>
                                                {history.length > 0 && (
                                                    <span className="px-1.5 py-0.5 rounded-full bg-indigo-500/10 text-indigo-400 text-[10px] font-black border border-indigo-500/20">
                                                        {history.length}
                                                    </span>
                                                )}
                                            </div>
                                            <button
                                                onClick={() => { clearHistory(); setIsNotificationsOpen(false); }}
                                                className="text-[10px] font-bold text-zinc-500 hover:text-white transition-colors uppercase tracking-widest"
                                            >
                                                Tout effacer
                                            </button>
                                        </div>

                                        <div className="max-h-[400px] overflow-y-auto custom-scrollbar">
                                            {history.length === 0 ? (
                                                <div className="py-12 text-center text-zinc-600 flex flex-col items-center gap-2">
                                                    <Bell size={32} className="opacity-10" />
                                                    <p className="text-sm">Aucune activité récente</p>
                                                </div>
                                            ) : (
                                                <div className="divide-y divide-white/5">
                                                    {history.map((item) => (
                                                        <div key={item.id} className="p-4 hover:bg-[var(--bg-card-hover)] transition-colors group cursor-default">
                                                            <div className="flex gap-3">
                                                                <div className={`mt-0.5 w-2 h-2 rounded-full shrink-0 shadow-[0_0_8px_currentColor] ${item.type === 'success' ? 'text-[var(--success)] bg-[var(--success)]' :
                                                                    item.type === 'error' ? 'text-[var(--error)] bg-[var(--error)]' :
                                                                        item.type === 'warning' ? 'text-[var(--warning)] bg-[var(--warning)]' :
                                                                            'text-[var(--info)] bg-[var(--info)]'
                                                                    }`} />
                                                                <div className="flex-1 min-w-0">
                                                                    <p className="text-sm font-semibold text-zinc-200 group-hover:text-white transition-colors">{item.title}</p>
                                                                    <p className="text-xs text-zinc-500 mt-1 leading-relaxed">{item.message}</p>
                                                                    <p className="text-[10px] text-zinc-600 mt-2 font-medium uppercase tracking-tighter">
                                                                        {item.timestamp ? formatDistanceToNow(item.timestamp, { addSuffix: true, locale: fr }) : ''}
                                                                    </p>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    ))}
                                                </div>
                                            )}
                                        </div>

                                        {history.length > 0 && (
                                            <Link
                                                to="/activity"
                                                onClick={() => setIsNotificationsOpen(false)}
                                                className="block py-3 text-center text-xs font-bold text-[var(--primary)] bg-[var(--primary)]/5 hover:bg-[var(--primary)]/10 transition-all border-t border-[var(--border-subtle)]"
                                            >
                                                Voir tout le journal d'activité
                                            </Link>
                                        )}
                                    </div>
                                </>
                            )}
                        </div>

                        {/* User Dropdown */}
                        <div className="relative pl-4 border-l border-white/5">
                            <button
                                onClick={() => setIsProfileOpen(!isProfileOpen)}
                                className="flex items-center gap-3 group"
                            >
                                <div className="w-9 h-9 rounded-full bg-gradient-to-br from-[var(--primary)] to-violet-600 p-[1px] shadow-lg shadow-[var(--primary-glow)] group-hover:shadow-[var(--primary)]/40 transition-shadow">
                                    <div className="w-full h-full rounded-full bg-[var(--bg-app)] flex items-center justify-center relative">
                                        <span className="text-xs font-bold text-[var(--text-primary)]">{user?.email?.charAt(0).toUpperCase()}</span>
                                    </div>
                                </div>
                                <ChevronDown size={14} className="text-zinc-600 group-hover:text-zinc-400 transition-colors" />
                            </button>

                            {/* Profile Dropdown Menu */}
                            {isProfileOpen && (
                                <>
                                    <div className="fixed inset-0 z-30" onClick={() => setIsProfileOpen(false)} />
                                    <div className="absolute right-0 mt-4 w-60 bg-[#0e0e11] border border-zinc-800 rounded-xl shadow-2xl shadow-black py-2 z-40 animate-fade-in origin-top-right ring-1 ring-white/5 backdrop-blur-xl">
                                        <div className="px-4 py-3 border-b border-white/5 bg-white/[0.02]">
                                            <p className="text-sm font-bold text-white">Super Admin</p>
                                            <p className="text-xs text-zinc-500 truncate mt-0.5">{user?.email}</p>
                                        </div>
                                        <div className='p-2 space-y-1'>
                                            <Link to="/settings" className="flex items-center gap-3 px-3 py-2.5 text-sm text-zinc-400 hover:bg-white/5 hover:text-white transition-colors rounded-lg group">
                                                <Settings size={16} className="group-hover:rotate-90 transition-transform duration-500" /> Paramètres
                                            </Link>
                                            <button
                                                onClick={handleSignOut}
                                                className="w-full flex items-center gap-3 px-3 py-2.5 text-sm text-rose-400 hover:bg-rose-500/10 transition-colors rounded-lg group"
                                            >
                                                <LogOut size={16} className="group-hover:-translate-x-1 transition-transform" /> Déconnexion
                                            </button>
                                        </div>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                </header>

                {/* Content Scrollable Area */}
                <main className="flex-1 p-4 md:p-8 max-w-[1920px] mx-auto w-full animate-fade-in">
                    <Outlet />
                </main>
            </div>

            {/* Command Palette Modal */}
            <CommandPalette isOpen={isSearchOpen} onClose={() => setIsSearchOpen(false)} />

            {/* MOBILE MENU OVERLAY */}
            {isMobileMenuOpen && (
                <div className="fixed inset-0 z-[100] lg:hidden">
                    <div className="fixed inset-0 bg-black/90 backdrop-blur-sm transition-opacity" onClick={() => setIsMobileMenuOpen(false)} />
                    <nav className="fixed inset-y-0 left-0 w-[280px] bg-[#050505] border-r border-zinc-800 flex flex-col animate-slide-in shadow-2xl">
                        <div className="h-[80px] flex items-center justify-between px-6 border-b border-zinc-900 shrink-0 bg-gradient-to-r from-indigo-900/20 to-transparent">
                            <span className="text-xl font-bold text-white tracking-tight">Velmo</span>
                            <button onClick={() => setIsMobileMenuOpen(false)} className="p-2 rounded-lg bg-zinc-900 text-zinc-400 hover:text-white">
                                <X size={20} />
                            </button>
                        </div>
                        <div className="flex-1 overflow-y-auto py-6 px-3">
                            <NavGroup items={NAV_ITEMS} onClose={() => setIsMobileMenuOpen(false)} />
                        </div>
                    </nav>
                </div>
            )}
        </div>
    );
}
