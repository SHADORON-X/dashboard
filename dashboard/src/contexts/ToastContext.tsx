import React, { createContext, useContext, useState, useCallback } from 'react';
import { X, CheckCircle2, AlertTriangle, AlertCircle, Info } from 'lucide-react';

type ToastType = 'success' | 'error' | 'warning' | 'info';

interface Toast {
    id: string;
    type: ToastType;
    title: string;
    message?: string;
    duration?: number;
    timestamp?: Date; // Added timestamp
}

interface ToastContextValue {
    addToast: (toast: Omit<Toast, 'id'>) => void;
    removeToast: (id: string) => void;
    history: Toast[]; // Added history
    clearHistory: () => void; // Added clearHistory
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

export function ToastProvider({ children }: { children: React.ReactNode }) {
    const [toasts, setToasts] = useState<Toast[]>([]);
    const [history, setHistory] = useState<Toast[]>([]); // Added history state

    const addToast = useCallback(({ type, title, message, duration = 5000 }: Omit<Toast, 'id'>) => {
        const id = Math.random().toString(36).substring(2, 9);
        const newToast = { id, type, title, message, duration, timestamp: new Date() }; // Added timestamp to newToast

        setToasts((prev) => [...prev, newToast]);
        setHistory((prev) => [newToast, ...prev].slice(0, 50)); // Keep last 50

        if (duration > 0) {
            setTimeout(() => {
                removeToast(id);
            }, duration);
        }
    }, []);

    const removeToast = useCallback((id: string) => {
        setToasts((prev) => prev.filter((t) => t.id !== id));
    }, []);

    const clearHistory = useCallback(() => { // Added clearHistory method
        setHistory([]);
    }, []);

    const getIcon = (type: ToastType) => {
        switch (type) {
            case 'success': return <CheckCircle2 className="text-emerald-500" size={20} />;
            case 'error': return <AlertCircle className="text-rose-500" size={20} />;
            case 'warning': return <AlertTriangle className="text-amber-500" size={20} />;
            case 'info': return <Info className="text-blue-500" size={20} />;
        }
    };

    return (
        <ToastContext.Provider value={{ addToast, removeToast, history, clearHistory }}> {/* Exposed history and clearHistory */}
            {children}

            {/* Toast Container */}
            <div className="fixed bottom-4 right-4 z-[9999] flex flex-col gap-3 w-full max-w-sm pointer-events-none">
                {toasts.map((toast) => (
                    <div
                        key={toast.id}
                        className="pointer-events-auto bg-[#121215] border border-zinc-800 rounded-xl shadow-2xl p-4 flex items-start gap-4 animate-slide-in-up transform transition-all hover:scale-[1.02] ring-1 ring-white/5 backdrop-blur-xl"
                    >
                        <div className="shrink-0 mt-0.5">{getIcon(toast.type)}</div>
                        <div className="flex-1 min-w-0">
                            <h4 className="text-sm font-bold text-white">{toast.title}</h4>
                            {toast.message && (
                                <p className="text-xs text-zinc-400 mt-1 leading-relaxed">
                                    {toast.message}
                                </p>
                            )}
                        </div>
                        <button
                            onClick={() => removeToast(toast.id)}
                            className="shrink-0 p-1 text-zinc-500 hover:text-white rounded transition-colors"
                        >
                            <X size={16} />
                        </button>
                    </div>
                ))}
            </div>
        </ToastContext.Provider>
    );
}

export function useToast() {
    const context = useContext(ToastContext);
    if (!context) {
        throw new Error('useToast must be used within a ToastProvider');
    }
    return context;
}
