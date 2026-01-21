import { createContext, useContext, useState, type ReactNode } from 'react';

// Types de devises supportées
export type CurrencyCode = 'GNF' | 'EUR' | 'USD';

interface CurrencyContextType {
    currency: CurrencyCode;
    setCurrency: (code: CurrencyCode) => void;
    formatAmount: (amount: number) => string;
    formatNumber: (amount: number) => string;
    exchangeRates: Record<CurrencyCode, number>;
}

const CurrencyContext = createContext<CurrencyContextType | undefined>(undefined);

// Taux de change fixes (à titre indicatif, pourraient être dynamiques plus tard)
const EXCHANGE_RATES: Record<CurrencyCode, number> = {
    GNF: 1,
    EUR: 0.00011, // 1 GNF = 0.00011 EUR (approx ~9000 GNF/EUR inversé)
    USD: 0.00012, // 1 GNF = 0.00012 USD
};

export function CurrencyProvider({ children }: { children: ReactNode }) {
    const [currency, setCurrency] = useState<CurrencyCode>('GNF');

    const formatAmount = (amount: number) => {
        // Conversion
        const convertedAmount = amount * EXCHANGE_RATES[currency];

        // Formatage
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: currency,
            minimumFractionDigits: currency === 'GNF' ? 0 : 2,
            maximumFractionDigits: currency === 'GNF' ? 0 : 2,
        }).format(convertedAmount);
    };

    const formatNumber = (amount: number) => {
        return new Intl.NumberFormat('en-US').format(amount);
    };

    return (
        <CurrencyContext.Provider value={{
            currency,
            setCurrency,
            formatAmount,
            formatNumber,
            exchangeRates: EXCHANGE_RATES
        }}>
            {children}
        </CurrencyContext.Provider>
    );
}

export function useCurrency() {
    const context = useContext(CurrencyContext);
    if (context === undefined) {
        throw new Error('useCurrency must be used within a CurrencyProvider');
    }
    return context;
}
