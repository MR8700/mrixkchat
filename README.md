# MRixk — Plateforme de Communication Sécurisée & Intelligence Personnelle Locale

MRixk est une plateforme de communication personnelle et multiplateforme conçue pour garantir la confidentialité native, la souveraineté des données et l'assistance cognitive locale.

---

## 🌟 Piliers Fondamentaux

1. **Identité Maîtrisée :** Identifiant unique (`@handle`), téléphone et email facultatifs, clés cryptographiques générées et conservées sur l'appareil.
2. **Gestion Stricte des Appareils :** **3 appareils maximum par compte**. Chaque appareil possède ses propres clés Ed25519 et X25519. Le 4ème appareil est automatiquement refusé. Révocation distante et indépendance des sessions.
3. **Confidentialité Native (E2EE) :** Chiffrement de bout en bout des messages, pièces jointes et métadonnées sensibles. Le serveur ne reçoit et ne stocke que des enveloppes chiffrées.
4. **MRixk AI (Strictement Locale) :** **Zéro API distante**. Espace cognitif personnel étanche $M(u) = \{D_u, V_u, G_u, P_u, H_u\}$, mémoire vectorielle locale et recherche hybride :
   $$Score = \alpha \cdot S_{\text{sémantique}} + \beta \cdot S_{\text{lexical}} + \gamma \cdot S_{\text{récence}} + \delta \cdot S_{\text{confiance}}$$
5. **Multiplateforme :** Client commun Flutter / Dart (Android, iOS, Windows, Linux) et backend Go modulaire haute performance.

---

## 📁 Architecture du Dépôt

```
mrixk/
├── apps/
│   └── client_flutter/      # Client Flutter (Android, iOS, Windows, Linux)
├── backend/
│   ├── cmd/server/          # Point d'entrée du serveur Go modulaire
│   └── internal/
│       ├── api/             # Routeur HTTP REST /api/v1 & Middleware de sécurité
│       ├── config/          # Gestionnaire de configuration
│       ├── database/        # Abstraction de données & Référentiel
│       ├── devices/         # Service appareils & Quota max 3
│       ├── identity/        # Service identité, inscription & authentification
│       └── messaging/       # Service de distribution d'enveloppes chiffrées
├── packages/
│   ├── crypto_core/         # Primitives cryptographiques (Ed25519, X25519, AES-256-GCM)
│   ├── vector_memory/       # Moteur vectoriel et calcul de similarité hybride
│   └── ai_runtime/          # Architecture cognitive et isolation stricte M(u)
├── infrastructure/
│   ├── docker/              # Dockerfile et configurations conteneurs
│   └── postgres/migrations/ # Migrations SQL complètes (24 entités)
├── docs/
│   ├── specifications/      # Audits techniques et spécifications
│   └── PROJECT_STATUS.md    # Tableau de bord officiel du projet
└── tests/                   # Suites de tests automatisés
```

---

## 🚀 Démarrage Rapide

### Prérequis
- Go 1.22+
- Docker / Podman & Docker Compose (optionnel pour PostgreSQL / Redis / MinIO)

### 1. Exécution des Tests Automatisés
```bash
export GOTOOLCHAIN=local
go test -v ./...
```

### 2. Compilation du Binaire Serveur
```bash
go build -o bin/mrixk-server ./backend/cmd/server
```

### 3. Démarrage du Serveur
```bash
PORT=8080 ./bin/mrixk-server
```

### 4. Démarrage de l'Infrastructure Complète (Docker Compose)
```bash
docker compose up -d
```

---

## 🛡️ Sécurité & Isolation Vérifiée

- ✅ **4ème appareil refusé :** Test automatisé dans `backend/internal/devices/service_test.go` et `backend/internal/api/router_test.go`.
- ✅ **Isolation cognitive IA étanche :** Test automatisé dans `packages/ai_runtime/runtime_test.go` démontrant que l'utilisateur B ne peut accéder à aucune mémoire, préférence ou document de l'utilisateur A ($M(u_1) \cap M(u_2) = \emptyset$).
- ✅ **Intégrité cryptographique :** Test d'altération AES-GCM et signatures de préclés dans `packages/crypto_core/crypto_test.go`.

---

## 📄 Licence & Confidentialité
MRixk — Architecture et code conçus pour la protection absolue de la vie privée.
