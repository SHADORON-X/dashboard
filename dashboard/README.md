# 🎛️ Velmo Admin Dashboard

> **Dashboard d'administration privé pour la plateforme Velmo**

Un centre de contrôle puissant, rapide et sécurisé pour surveiller et analyser l'ensemble de la plateforme Velmo.

## 📋 Sommaire

- [Stack Technique](#-stack-technique)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Pages du Dashboard](#-pages-du-dashboard)
- [Sécurité](#-sécurité)
- [Sources de Données](#-sources-de-données)
- [Performance](#-performance)

---

## 🛠️ Stack Technique

| Technologie | Version | Rôle |
|-------------|---------|------|
| **React** | 19.x | Framework UI |
| **TypeScript** | 5.x | Type safety |
| **Vite** | 7.x | Build tool |
| **Tailwind CSS** | 3.x | Styling |
| **Supabase JS** | 2.x | Backend (Auth, DB, Realtime) |
| **React Query** | 5.x | Data fetching & caching |
| **React Router** | 6.x | Navigation |
| **Recharts** | 2.x | Graphiques |
| **Lucide React** | 0.x | Icônes |
| **date-fns** | 3.x | Manipulation dates |

---

## 🏗️ Architecture

```
dashboard/
├── public/
│   └── velmo-icon.svg          # Favicon
├── src/
│   ├── components/
│   │   ├── Layout.tsx          # Layout principal (sidebar + header)
│   │   └── ui/
│   │       └── index.tsx       # Composants UI réutilisables
│   ├── contexts/
│   │   └── AuthContext.tsx     # Authentification & vérification admin
│   ├── hooks/
│   │   └── useData.ts          # Hooks React Query pour data fetching
│   ├── lib/
│   │   └── supabase.ts         # Client Supabase configuré
│   ├── pages/
│   │   ├── OverviewPage.tsx    # Vue d'ensemble
│   │   ├── ShopsPage.tsx       # Liste des boutiques
│   │   ├── ShopDetailPage.tsx  # Détail boutique
│   │   ├── ActivityPage.tsx    # Activité temps réel
│   │   ├── LogsPage.tsx        # Logs & erreurs
│   │   ├── AnalyticsPage.tsx   # Analytics
│   │   ├── AlertsPage.tsx      # Alertes stock
│   │   └── LoginPage.tsx       # Connexion
│   ├── types/
│   │   └── database.ts         # Types TypeScript (from SQL)
│   ├── App.tsx                 # Routes & providers
│   ├── main.tsx                # Entry point
│   └── index.css               # Styles globaux + Tailwind
├── .env.example                # Template variables d'environnement
├── package.json
├── tailwind.config.js
├── postcss.config.js
├── tsconfig.json
└── vite.config.ts
```

---

## 🚀 Installation

### 1. Prérequis

- Node.js 18+
- npm ou yarn
- Projet Supabase configuré

### 2. Installation des dépendances

```bash
cd dashboard
npm install
```

### 3. Configuration

Copier le fichier `.env.example` en `.env` :

```bash
cp .env.example .env
```

Remplir les variables :

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

### 4. Migration SQL

Exécuter la migration pour créer l'infrastructure admin :

```sql
-- Dans Supabase SQL Editor, exécuter:
-- migrations/080_admin_dashboard_infrastructure.sql
```

### 5. Créer le premier Super Admin

```sql
-- Remplacer par l'UUID de votre utilisateur Supabase Auth
INSERT INTO velmo_admins (user_id, role, is_active)
VALUES ('YOUR_AUTH_USER_UUID', 'super_admin', true);
```

### 6. Lancer le développement

```bash
npm run dev
```

Accéder à `http://localhost:5173`

---

## 📄 Pages du Dashboard

### 1️⃣ Overview (`/`)

**Objectif**: Vue instantanée de Velmo

| Données | Source |
|---------|--------|
| Boutiques actives | `shops` table (count) |
| Utilisateurs actifs | `users` table (count) |
| Ventes 24h | `sales` table (filtered) |
| Volume total (GMV) | `sales` table (sum) |
| Profit total | `sales` table (sum) |
| Dettes actives | `debts` table (sum) |
| Graphique tendances | `useDailySales()` hook |
| Activité temps réel | `useRealtimeActivity()` hook |

### 2️⃣ Boutiques (`/shops`)

**Objectif**: Liste et recherche de toutes les boutiques

| Données | Source |
|---------|--------|
| Liste boutiques | `useShopsOverview()` |
| Stats par boutique | Calculées via sous-requêtes |
| Recherche | `useSearchShops()` |

### 3️⃣ Détail Boutique (`/shops/:shopId`)

**Objectif**: Analyse complète d'une boutique

| Données | Source |
|---------|--------|
| Infos boutique | `shops` table |
| Propriétaire | `users` table |
| Ventes du jour/semaine/mois | `sales` table (filtered) |
| Produits stock critique | `products` table |
| Dettes actives | `debts` table |
| Équipe | `shop_members` table |

### 4️⃣ Activité (`/activity`)

**Objectif**: Feed live des événements

| Données | Source |
|---------|--------|
| Ventes récentes | `sales` + Supabase Realtime |
| Nouvelles dettes | `debts` + Supabase Realtime |
| Inscriptions | `users` + Supabase Realtime |

### 5️⃣ Logs & Erreurs (`/logs`)

**Objectif**: Diagnostic rapide

| Données | Source |
|---------|--------|
| Événements critiques | `audit_logs` table |
| Erreurs sync | `audit_logs` (type filter) |
| Activités suspectes | `audit_logs` (severity filter) |

### 6️⃣ Analytics (`/analytics`)

**Objectif**: Tendances légères

| Données | Source |
|---------|--------|
| Évolution revenue | `useDailySales()` |
| Répartition catégories | `shops` (group by category) |
| Top boutiques | `useShopsOverview()` (sorted) |
| Volume ventes quotidien | `useDailySales()` |

### 7️⃣ Alertes Stock (`/alerts`)

**Objectif**: Produits en rupture

| Données | Source |
|---------|--------|
| Produits sous seuil | `products` (quantity <= stock_alert) |
| Boutique associée | JOIN `shops` |
| Contact propriétaire | JOIN `users` |

---

## 🔐 Sécurité

### Architecture d'accès

```
┌─────────────────────────────────────────┐
│             SUPABASE AUTH               │
│         (Email/Password login)          │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│          velmo_admins TABLE             │
│  ┌─────────────────────────────────┐   │
│  │ user_id  │ role        │ active │   │
│  ├──────────┼─────────────┼────────┤   │
│  │ uuid-1   │ super_admin │ true   │   │
│  │ uuid-2   │ admin       │ true   │   │
│  └─────────────────────────────────┘   │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│       is_velmo_super_admin()            │
│       is_velmo_admin()                  │
│           (RPC Checks)                  │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│          DASHBOARD ACCESS               │
│    (Read-only, no write actions)        │
└─────────────────────────────────────────┘
```

### Rôles Admin

| Rôle | Permissions |
|------|-------------|
| `super_admin` | Accès total, gestion des admins |
| `admin` | Accès total en lecture |
| `support` | Accès boutiques, logs, alertes |
| `viewer` | Accès lecture seule limité |

### Vérification dans le code

```typescript
// AuthContext.tsx
const adminStatus = await checkIsVelmoAdmin(userId);

// Dans les RPC SQL
IF NOT is_velmo_admin(p_admin_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
END IF;
```

---

## 📊 Sources de Données

### Tables Utilisées (Read-Only)

| Table | Données extraites |
|-------|-------------------|
| `users` | Comptes, profils, stats |
| `shops` | Boutiques, propriétaires |
| `products` | Inventaire, stocks |
| `sales` | Transactions, revenue |
| `sale_items` | Détails ventes |
| `debts` | Créances actives |
| `debt_payments` | Historique paiements |
| `shop_members` | Équipes boutiques |
| `audit_logs` | Logs sécurité |
| `velmo_admins` | Contrôle accès admin |

### Vues SQL Admin

| Vue | Objectif |
|-----|----------|
| `v_admin_platform_stats` | KPIs globaux |
| `v_admin_daily_sales` | Ventes quotidiennes |
| `v_admin_shops_overview` | Aperçu boutiques |
| `v_admin_stock_alerts` | Alertes rupture |
| `v_admin_realtime_activity` | Feed temps réel |
| `critical_audit_events` | Événements critiques |

### RPC Sécurisées

| Fonction | Objectif |
|----------|----------|
| `is_velmo_super_admin()` | Vérifier super admin |
| `is_velmo_admin()` | Vérifier admin (any role) |
| `admin_get_shop_details()` | Détails complets boutique |
| `admin_search_shops()` | Recherche boutiques |

---

## ⚡ Performance

### Stratégies Implémentées

1. **React Query Caching**
   - `staleTime: 30000` (30s avant refetch)
   - `refetchInterval` pour données live

2. **Pagination**
   - Toutes les listes paginées (20-50 items/page)
   - Offset-based avec `range()`

3. **Lazy Loading**
   - Chargement conditionnel des détails
   - Hooks avec `enabled` flag

4. **Optimistic Updates**
   - Affichage immédiat des filtres locaux

5. **Supabase Realtime**
   - Abonnements aux changements
   - Invalidation cache automatique

### Recommandations

```typescript
// Pagination standard
const { data } = useShopsOverview(page, 20);

// Debounce recherche
const debouncedSearch = useMemo(
  () => debounce((q) => setSearchQuery(q), 300),
  []
);

// Skeleton loading
{isLoading ? <Skeleton /> : <Data />}
```

---

## 📱 Responsive Design

Le dashboard est **mobile-first** avec:

- Sidebar collapsible sur mobile
- Tables horizontalement scrollables
- Grilles adaptatives (1 → 2 → 4 colonnes)
- Touch-friendly (min 44px tap targets)

Breakpoints Tailwind:
- `sm`: 640px
- `md`: 768px 
- `lg`: 1024px
- `xl`: 1280px

---

## 🚫 Limitations (By Design)

1. **Lecture seule** : Aucune action d'écriture
2. **Pas de backend custom** : 100% Supabase
3. **Pas de cron** : Tout est query-based ou realtime
4. **Pas de BI complexe** : Analytics légers uniquement

---

## 📝 License

Proprietary - Velmo © 2026
