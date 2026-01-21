import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Search, Package, User, Store, ShoppingBag,
    ArrowRight, Command, Loader2, FileWarning
} from 'lucide-react';
import supabase from '../lib/supabase';

// Types pour les résultats
type SearchResult = {
    type: 'product' | 'user' | 'shop' | 'sale' | 'debt';
    id: string;
    title: string;
    subtitle: string;
    url: string;
    meta: any;
};

interface CommandPaletteProps {
    isOpen: boolean;
    onClose: () => void;
}

export function CommandPalette({ isOpen, onClose }: CommandPaletteProps) {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState<SearchResult[]>([]);
    const [loading, setLoading] = useState(false);
    const inputRef = useRef<HTMLInputElement>(null);
    const navigate = useNavigate();

    // Effet pour le Focus automatique
    useEffect(() => {
        if (isOpen) {
            setTimeout(() => inputRef.current?.focus(), 50);
        }
    }, [isOpen]);

    // Recherche via Supabase RPC + Fallback manuel si besoin
    useEffect(() => {
        const search = async () => {
            if (query.trim().length < 2) {
                setResults([]);
                return;
            }

            setLoading(true);
            try {
                // 1. Tenter la recherche RPC (optimisée côté serveur)
                const { data, error } = await (supabase.rpc as any)('search_all', { search_query: query });

                if (!error && data && data.length > 0) {
                    setResults(data);
                    setLoading(false);
                    return;
                }

                // 2. Si RPC échoue ou ne renvoie rien, tenter une recherche manuelle sur les tables critiques
                // Cela compense les cas où la migration SQL RPC n'a pas encore été appliquée.
                const [productsRes, shopsRes, usersRes] = await Promise.all([
                    supabase.from('products').select('id, name, quantity, category').ilike('name', `%${query}%`).limit(8),
                    supabase.from('shops').select('id, name, address, location').ilike('name', `%${query}%`).limit(5),
                    supabase.from('users').select('id, first_name, last_name, role, email').or(`first_name.ilike.%${query}%,last_name.ilike.%${query}%`).limit(5)
                ]);

                const combined: SearchResult[] = [];

                if (productsRes.data) {
                    productsRes.data.forEach(p => combined.push({
                        type: 'product',
                        id: p.id,
                        title: p.name,
                        subtitle: `Stock: ${p.quantity} | ${p.category || 'Général'}`,
                        url: '/products',
                        meta: p
                    }));
                }

                if (shopsRes.data) {
                    shopsRes.data.forEach(s => combined.push({
                        type: 'shop',
                        id: s.id,
                        title: s.name,
                        subtitle: s.address || s.location || 'Sans adresse',
                        url: '/shops',
                        meta: s
                    }));
                }

                if (usersRes.data) {
                    usersRes.data.forEach(u => combined.push({
                        type: 'user',
                        id: u.id,
                        title: `${u.first_name || ''} ${u.last_name || ''}`.trim() || u.email,
                        subtitle: `${u.role || 'Utilisateur'} | ${u.email}`,
                        url: '/users',
                        meta: u
                    }));
                }

                setResults(combined);
            } catch (err) {
                console.error("Search Error (All Methods):", err);
                setResults([]);
            } finally {
                setLoading(false);
            }
        };

        const timer = setTimeout(search, 300); // Debounce manuel 300ms
        return () => clearTimeout(timer);
    }, [query]);

    // Raccourci Clavier pour fermer (Echap)
    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === 'Escape') onClose();
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [onClose]);

    if (!isOpen) return null;

    const handleSelect = (result: SearchResult) => {
        let finalUrl = result.url;

        // Si l'URL est juste la racine, on construit l'URL de détail
        if (finalUrl === '/products') finalUrl = `/products/${result.id}`;
        if (finalUrl === '/users') finalUrl = `/users/${result.id}`;
        if (finalUrl === '/shops') finalUrl = `/shops/${result.id}`;
        if (finalUrl === '/sales') finalUrl = `/sales/${result.id}`;
        if (finalUrl === '/debts') finalUrl = `/debts/${result.id}`;

        navigate(finalUrl);
        onClose();
        setQuery('');
    };

    const getIcon = (type: string) => {
        switch (type) {
            case 'product': return <Package size={18} className="text-[var(--warning)]" />;
            case 'user': return <User size={18} className="text-violet-500" />;
            case 'shop': return <Store size={18} className="text-[var(--primary)]" />;
            case 'sale': return <ShoppingBag size={18} className="text-[var(--success)]" />;
            case 'debt': return <FileWarning size={18} className="text-[var(--error)]" />;
            default: return <Search size={18} className="text-[var(--text-muted)]" />;
        }
    };

    return (
        <div className="fixed inset-0 z-[100] flex items-start justify-center pt-[15vh] px-4 animate-fade-in">
            {/* Backdrop Blur */}
            <div
                className="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity"
                onClick={onClose}
            />

            {/* Modal Window */}
            <div className="relative w-full max-w-2xl bg-[var(--bg-card)] border border-[var(--border-subtle)] rounded-2xl shadow-2xl shadow-black overflow-hidden flex flex-col max-h-[60vh] transform transition-all animate-slide-in-up ring-1 ring-white/10">

                {/* Search Header */}
                <div className="flex items-center gap-3 px-4 py-4 border-b border-[var(--border-subtle)] bg-white/[0.02]">
                    <Search className="text-[var(--text-muted)]" size={20} />
                    <input
                        ref={inputRef}
                        type="text"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        placeholder="Rechercher (ex: 'Iphone', 'Mamadou', '#1234')..."
                        className="flex-1 bg-transparent border-none outline-none text-lg text-[var(--text-primary)] placeholder-[var(--text-muted)] font-medium"
                    />
                    <div className="flex items-center gap-2">
                        {loading && <Loader2 className="animate-spin text-[var(--primary)]" size={18} />}
                        <button
                            onClick={onClose}
                            className="p-1 px-2 text-xs font-bold text-[var(--text-secondary)] bg-[var(--bg-app)] rounded border border-[var(--border-subtle)] hover:text-[var(--text-primary)] transition-colors"
                        >
                            ESC
                        </button>
                    </div>
                </div>

                {/* Results List */}
                <div className="flex-1 overflow-y-auto p-2 scrollbar-hide">
                    {query.length < 2 && (
                        <div className="py-12 text-center text-[var(--text-muted)]">
                            <Command size={48} className="mx-auto mb-4 opacity-20" />
                            <p className="text-sm">Tapez au moins 2 caractères pour lancer l'Œil de Dieu...</p>
                        </div>
                    )}

                    {query.length >= 2 && results.length === 0 && !loading && (
                        <div className="py-8 text-center text-[var(--text-muted)]">
                            <p>Aucun résultat trouvé pour "{query}".</p>
                        </div>
                    )}

                    {results.length > 0 && (
                        <div className="space-y-1">
                            {/* Group by type logic could be added here, currently flat list */}
                            {results.map((result) => (
                                <button
                                    key={`${result.type}-${result.id}`}
                                    onClick={() => handleSelect(result)}
                                    className="w-full flex items-center gap-4 p-3 rounded-xl hover:bg-[var(--primary)]/10 hover:border-[var(--primary)]/20 border border-transparent transition-all group text-left"
                                >
                                    <div className="p-2 rounded-lg bg-[var(--bg-app)] border border-[var(--border-subtle)] group-hover:bg-[var(--primary)]/20 group-hover:border-[var(--primary)]/30 transition-colors">
                                        {getIcon(result.type)}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center justify-between">
                                            <p className="font-medium text-[var(--text-primary)] group-hover:text-[var(--primary)] truncate">
                                                {result.title}
                                            </p>
                                            <span className="text-[10px] uppercase font-bold text-[var(--text-muted)] group-hover:text-[var(--primary)] bg-[var(--bg-app)] px-1.5 py-0.5 rounded border border-[var(--border-subtle)] group-hover:border-[var(--primary)]/30 transition-colors">
                                                {result.type}
                                            </span>
                                        </div>
                                        <p className="text-sm text-[var(--text-secondary)] group-hover:text-[var(--text-primary)] truncate">
                                            {result.subtitle}
                                        </p>
                                    </div>
                                    <ArrowRight size={16} className="text-[var(--text-muted)] group-hover:text-[var(--primary)] -translate-x-2 opacity-0 group-hover:translate-x-0 group-hover:opacity-100 transition-all" />
                                </button>
                            ))}
                        </div>
                    )}
                </div>

                {/* Footer */}
                <div className="px-4 py-2 bg-[var(--bg-app)]/50 border-t border-[var(--border-subtle)] text-[10px] text-[var(--text-muted)] flex justify-between items-center">
                    <span>Pro tip: Utilisez les flèches pour naviguer</span>
                    <div className="flex gap-2">
                        <span className="flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-[var(--primary)]"></span>
                            Supabase Search
                        </span>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default CommandPalette;
