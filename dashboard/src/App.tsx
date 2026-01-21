import { BrowserRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider, useAuth, ProtectedRoute } from './contexts/AuthContext';
import { CurrencyProvider } from './contexts/CurrencyContext';
import { ToastProvider } from './contexts/ToastContext';
import Layout from './components/Layout';

// Pages
import LoginPage from './pages/LoginPage';
import SignupPage from './pages/SignupPage';
import AuthCallback from './pages/AuthCallback';
import OverviewPage from './pages/OverviewPage';
import ShopsPage from './pages/ShopsPage';
import ShopDetailPage from './pages/ShopDetailPage';
import ActivityPage from './pages/ActivityPage';
import LogsPage from './pages/LogsPage';
import AnalyticsPage from './pages/AnalyticsPage';
import AlertsPage from './pages/AlertsPage';
import UsersPage from './pages/UsersPage';
import UserDetailPage from './pages/UserDetailPage';
import ProductsPage from './pages/ProductsPage';
import ProductDetailPage from './pages/ProductDetailPage';
import SalesPage from './pages/SalesPage';
import SaleDetailPage from './pages/SaleDetailPage';
import DebtsPage from './pages/DebtsPage';
import DebtDetailPage from './pages/DebtDetailPage';
import SettingsPage from './pages/SettingsPage';

// ============================================
// QUERY CLIENT CONFIG
// ============================================

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 30000,
      refetchOnWindowFocus: false,
    },
  },
});

// ============================================
// AUTH GUARD
// ============================================

function AuthGuard() {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#09090b] flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin" />
          <p className="text-zinc-500 text-sm">Chargement...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return (
    <ProtectedRoute>
      <Layout />
    </ProtectedRoute>
  );
}

// ============================================
// PUBLIC GUARD
// ============================================

function PublicGuard() {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#09090b] flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (user) {
    return <Navigate to="/" replace />;
  }

  return <Outlet />;
}

// ============================================
// APP ROUTES
// ============================================

function AppRoutes() {
  return (
    <Routes>
      {/* Public routes */}
      <Route element={<PublicGuard />}>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignupPage />} />
        <Route path="/auth/callback" element={<AuthCallback />} />
      </Route>

      {/* Protected routes */}
      <Route element={<AuthGuard />}>
        <Route path="/" element={<OverviewPage />} />
        <Route path="/shops" element={<ShopsPage />} />
        <Route path="/shops/:shopId" element={<ShopDetailPage />} />
        <Route path="/activity" element={<ActivityPage />} />
        <Route path="/logs" element={<LogsPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
        <Route path="/alerts" element={<AlertsPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/users/:userId" element={<UserDetailPage />} />
        <Route path="/products" element={<ProductsPage />} />
        <Route path="/products/:productId" element={<ProductDetailPage />} />
        <Route path="/sales" element={<SalesPage />} />
        <Route path="/sales/:saleId" element={<SaleDetailPage />} />
        <Route path="/debts" element={<DebtsPage />} />
        <Route path="/debts/:debtId" element={<DebtDetailPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>

      {/* Fallback */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

// ============================================
// MAIN APP
// ============================================

import { AdminProvider } from './contexts/AdminContext';
import { ThemeProvider } from './contexts/ThemeContext';

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
          <CurrencyProvider>
            <ToastProvider>
              <AdminProvider>
                <AuthProvider>
                  <AppRoutes />
                </AuthProvider>
              </AdminProvider>
            </ToastProvider>
          </CurrencyProvider>
        </BrowserRouter>
      </ThemeProvider>
    </QueryClientProvider>
  );
}
