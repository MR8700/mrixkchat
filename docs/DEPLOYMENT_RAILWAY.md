# Guide de Déploiement MRixk sur Railway (Backend & PWA Client)

Ce guide décrit la mise en production de l'infrastructure complète **MRixk** sur **Railway** :
1. **mrixk-backend** : API Go haute performance, WebSockets E2EE, persistance.
2. **mrixk-pwa** : Application web / PWA Flutter servie par Nginx avec support hors-ligne, compression gzip et cache optimisé.
3. **Services managés** : PostgreSQL 16 et Redis 7 reliés par le réseau privé WireGuard.

---

## 1. Architecture sur Railway

Railway orchestre l'ensemble des services dans un canevas de projet unifié :

```
[ Navigateur / Appareils ]
     │               │
     │ HTTPS         │ HTTPS / WSS
     ▼               ▼
┌──────────────┐   ┌────────────────────────────────────────────────────────┐
│  mrixk-pwa   │   │  mrixk-backend (Go Alpine Container)                   │
│  (Nginx SPA) │   │  Port: 8080 | Healthcheck: /api/v1/health               │
└──────────────┘   └───┬───────────────────────────────┬────────────────────┘
                       │ Private Network (WireGuard)   │ Private Net (WireGuard)
                       ▼                               ▼
                ┌──────────────────────┐      ┌────────────────────┐
                │  PostgreSQL 16       │      │  Redis 7           │
                │  postgres.internal   │      │  redis.internal    │
                └──────────────────────┘      └────────────────────┘
```

---

## 2. Déploiement en 5 étapes via la console Railway

### Étape 1 : Créer le projet et importer le Backend
1. Rendez-vous sur [railway.com](https://railway.com) et connectez-vous.
2. Cliquez sur **+ New Project** $\rightarrow$ **Deploy from GitHub repo**.
3. Sélectionnez votre dépôt `mrixk`.
4. Railway détecte automatiquement le fichier [railway.json](file:///home/richard/mrixk/railway.json) et le [Dockerfile](file:///home/richard/mrixk/Dockerfile) du backend.

### Étape 2 : Ajouter PostgreSQL et Redis
1. Sur le tableau de bord de votre projet, cliquez sur **+ New** (en haut à droite).
2. Choisissez **Database** $\rightarrow$ **Add PostgreSQL**.
3. Cliquez à nouveau sur **+ New** $\rightarrow$ **Database** $\rightarrow$ **Add Redis**.

### Étape 3 : Configurer les Variables du Backend
Sur le service `mrixk-backend`, rendez-vous dans l'onglet **Variables** :

| Variable | Valeur recommandée sur Railway | Description |
| :--- | :--- | :--- |
| `APP_ENV` | `production` | Active le mode sécurité strict |
| `PORT` | `8080` | Port d'écoute interne |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Référence dynamique injectée par Railway |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Référence dynamique injectée par Railway |
| `MAX_DEVICES_PER_USER` | `3` | Plafond strict de 3 appareils |
| `JWT_SIGNING_KEY` | *(Générer une clé secrète aléatoire de 64 car.)* | Signature des jetons de session |

Dans **Settings** $\rightarrow$ **Networking**, cliquez sur **Generate Domain** pour obtenir l'URL publique de l'API (ex: `https://mrixk-backend-production.up.railway.app`).

---

### Étape 4 : Déployer le Client PWA (`mrixk-pwa`)

Pour déployer le client Web PWA dans le même projet Railway :

1. Cliquez sur **+ New** $\rightarrow$ **GitHub Repo** $\rightarrow$ Sélectionnez à nouveau votre dépôt `mrixk`.
2. Renommez ce nouveau service en `mrixk-pwa`.
3. Allez dans **Settings** $\rightarrow$ **Build** :
   - **Dockerfile Path** : indiquez `infrastructure/docker/Dockerfile.pwa` (pour compiler Flutter Web à partir des sources) OU `infrastructure/docker/Dockerfile.pwa.prebuilt` (si vous avez poussé le build existant).
4. Dans l'onglet **Variables** de `mrixk-pwa`, configurez :
   - `API_URL` : l'URL publique de votre backend (ex: `https://mrixk-backend-production.up.railway.app/api/v1`).
5. Dans **Settings** $\rightarrow$ **Networking**, cliquez sur **Generate Domain** (ex: `https://mrixk-app-production.up.railway.app`).

> [!TIP]
> **Résolution d'API automatique** : Si le client PWA est servi sur le même domaine ou si aucune variable `API_URL` n'est définie, [api_client.dart](file:///home/richard/mrixk/apps/client_flutter/lib/core/network/api_client.dart) détecte automatiquement l'hôte courant dans le navigateur (`Uri.base.origin + '/api/v1'`).

---

### Étape 5 : Option Tout-en-Un (Alternative Économique / Monolithe)

Si vous préférez **ne payer qu'un seul service** pour héberger à la fois l'API et le client PWA :
- Le serveur Go intègre un serveur de fichiers statiques avec gestion SPA et en-têtes PWA (`no-cache` sur le Service Worker, cache immuable sur les assets).
- Définissez simplement la variable d'environnement `STATIC_WEB_DIR=/app/web` sur le service backend et placez vos fichiers compilés dans ce répertoire.
- Dans ce mode, `https://votre-projet.up.railway.app/` sert la PWA et `https://votre-projet.up.railway.app/api/v1/` sert l'API sans aucun souci de CORS.

---

## 3. Déploiement via la CLI Railway

```bash
# 1. Se connecter à Railway
railway login

# 2. Lier au projet
railway link

# 3. Déployer le service backend
railway up --service mrixk-backend

# 4. Appliquer les migrations de schéma SQL (si souhaité)
railway run ./infrastructure/postgres/run-migrations.sh
```
| `STORAGE_ENDPOINT` | *(Optionnel : ex. https://<id>.r2.cloudflarestorage.com)* | Stockage média objet S3 |
| `STORAGE_BUCKET` | `mrixk-media` | Bucket média |
| `STORAGE_ACCESS_KEY` | *(Clé S3 / R2)* | Identifiant S3 |
| `STORAGE_SECRET_KEY` | *(Secret S3 / R2)* | Clé secrète S3 |

> [!NOTE]
> La notation `${{Postgres.DATABASE_URL}}` permet à Railway de synchroniser automatiquement l'URL de connexion même si le mot de passe de la base de données change.

### Étape 5 : Générer le Domaine Public
1. Toujours sur `mrixk-backend`, allez dans **Settings** $\rightarrow$ **Networking**.
2. Cliquez sur **Generate Domain** (ex: `mrixk-production.up.railway.app`) ou configurez un domaine personnalisé (ex: `api.mrixk.io`).
3. Le certificat SSL/TLS Let's Encrypt est provisionné et renouvelé automatiquement.

---

## 3. Alternative : Déploiement via la CLI Railway

Pour les développeurs préférant la ligne de commande :

```bash
# 1. Installer la CLI
curl -fsSL https://railway.com/install.sh | sh

# 2. Se connecter
railway login

# 3. Lier au projet
railway link

# 4. Déployer
railway up
```

---

## 4. Migrations PostgreSQL (Optionnel)

L'API MRixk initialise et gère automatiquement sa persistance JSONB haute fidélité (`mrixk_state`). Si vous souhaitez exécuter le schéma complet des 24 entités relationnelles :

```bash
# Avec la CLI Railway :
railway run ./bin/run-migrations.sh
```

---

## 5. Connexion de l'application cliente Flutter

Pour pointer l'application Flutter vers votre nouvelle instance Railway :

```bash
cd apps/client_flutter
flutter run --dart-define=API_URL=https://<votre-domaine-railway>.up.railway.app/api/v1
```

Vous pouvez également mettre à jour la constante `prodRemoteUrl` dans [api_client.dart](file:///home/richard/mrixk/apps/client_flutter/lib/core/network/api_client.dart).
