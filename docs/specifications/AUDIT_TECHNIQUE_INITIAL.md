# AUDIT TECHNIQUE INITIAL ET PLAN ARCHITECTURAL — PROJET MRIXK

**Date :** 09 Novembre 2026  
**Rôle :** Architecte Logiciel Principal & Ingénieur Full-Stack Senior  
**Projet :** MRixk — Plateforme de Communication Sécurisée, Multiplateforme avec IA Locale Isolée  
**Document de référence :** `file:///home/richard/Documents/MessagerieMRixk.odt` (2,1 Mo)  

---

## 1. ÉTAT INITIAL DU DÉPÔT ET DE L'ENVIRONNEMENT

### 1.1. Inspection du système hôte et environnement de développement
- **Système d'exploitation :** Linux Parrot OS (Debian 6.11 x86_64), Noyau `6.11.5-1parrot1`.
- **Processeur et calcul :** Intel Core 6 cœurs, architecture x86_64, GPU intégré Intel UHD 630.
- **Mémoire vive (RAM) :** 15 Gio total (12 Gio disponible).
- **Stockage disque :** Disque `/dev/sda2` avec **447 Gio d'espace libre**.
- **Outils installés :**
  - Go : `go version go1.22.11 linux/amd64` (`/usr/bin/go`).
  - Podman / Docker : Podman 4.3.1 avec émulation CLI Docker et `docker-compose`.
  - Python : `Python 3.11.2`.
  - Node.js : `v18.19.0`.
  - Compilateur C/C++ : `gcc 12.2.0`, `GNU Make 4.3`.
  - Base de données locale : `sqlite3 3.40.1`.
  - Contrôle de version : `git version 2.39.5`.
- **Éléments non installés par défaut :**
  - Flutter SDK et Dart SDK (à intégrer dans l'espace utilisateur ou conteneur de build).
  - Cargo / Rust (compilateur rustc non présent sur le système hôte, crypto modulaire avec composants Go/C/Rust).

### 1.2. État du dépôt initial
- **Dépôt Git préalable :** Aucun dépôt git initialisé pour MRixk avant notre intervention. Le poste contenait uniquement le document de spécification de référence (`/home/richard/Documents/MessagerieMRixk.odt`), un schéma d'architecture PNG (`/home/richard/Documents/mermaid-diagram.png`) et des documents universitaires sans rapport dans `Master 1 UJKZ`.
- **Action immédiate réalisée :** Initialisation du monorepo Git dans `/home/richard/mrixk`, configuration de l'auteur (`Richard MARE <richard@mrixk.internal>`), et mise en place de l'arborescence officielle.

---

## 2. ANALYSE COMPARATIVE (SPÉCIFICATIONS vs EXISTANT)

| Domaine Spécifié | Exigence de la Spécification (`MessagerieMRixk.odt`) | État Initial | Action Requise |
| :--- | :--- | :--- | :--- |
| **Structure du projet** | Monorepo unifié : `apps/`, `backend/`, `packages/`, `infrastructure/`, `docs/`, `tests/` | Absent | **Création du monorepo complet conforme section 8** |
| **Identité & Comptes** | Identifiant unique `@handle`, téléphone facultatif, sans mot de passe en clair | Absent | **Service d'identité avec hash Argon2id/Bcrypt et Ed25519** |
| **Appareils** | **Max 3 appareils**, clés privées sur l'appareil, refus du 4ème appareil, sessions révocables | Absent | **Moteur de sessions avec quota strict à 3 appareils et tests unitaires** |
| **Cryptographie** | Ed25519 (signatures), X25519 (échange de clés), ChaCha20-Poly1305 / AES-256-GCM, Double Ratchet / Signal Protocol | Absent | **Package `crypto_core` autonome et auditable** |
| **Base Serveur** | PostgreSQL (24 tables relationnelles avec contraintes et index) | Absent | **Migrations SQL versionnées `000001_initial_schema.up.sql`** |
| **Messagerie & Sync** | Enveloppes chiffrées uniquement sur le serveur, journal d'événements `sync_events`, accusés de réception | Absent | **Service de messagerie & sync engine avec modèle E2EE** |
| **IA Locale** | **Zéro API distante**, isolation $M(u) = \{D_u, V_u, G_u, P_u, H_u\}$, recherche hybride vectorielle + lexicale | Absent | **Package `ai_runtime` + `vector_memory` avec test d'isolation stricte** |
| **Client Multiplateforme** | Application Flutter / Dart structurée par features | Absent | **Socle client Flutter dans `apps/client_flutter`** |
| **Infrastructure** | Docker Compose : Postgres, Redis, MinIO (S3 compatible) | Absent | **Fichier `docker-compose.yml` et configuration prête à l'emploi** |

---

## 3. COMPOSANTS RÉUTILISABLES ET STRATÉGIE TECHNIQUE

1. **Go 1.22 Standard Library :**
   - Cryptographie moderne native : `crypto/ecdh` (X25519 standard), `crypto/ed25519`, `crypto/cipher` (ChaCha20-Poly1305, AES-GCM), `crypto/sha256`, `crypto/rand`.
   - Routage HTTP standardisé avec paramètres de chemin (`GET /api/v1/devices/{id}`).
   - Concurrence native (`goroutines`, `sync.RWMutex`, `context`).
2. **SQLite 3.40.1 :**
   - Moteur local standard pour le stockage chiffré des appareils et les tests intégrés rapides.
3. **Conteneurisation Podman :**
   - Exécution sans privilèges root (rootless) pour Postgres, Redis et MinIO.
4. **Calculs IA adaptés aux contraintes matérielles (Intel UHD 630, 15 Go RAM) :**
   - Modèles quantifiés GGUF (Q4_K_M) pour limiter l'empreinte mémoire à < 4 Go.
   - Calcul hybride sémantique/lexical local basé sur la formule spécifiée :
     $$Score = \alpha \cdot S_{\text{sémantique}} + \beta \cdot S_{\text{lexical}} + \gamma \cdot S_{\text{récence}} + \delta \cdot S_{\text{confiance}}$$

---

## 4. ARCHITECTURE CIBLE RETENUE

Voir le schéma architectural complet dans la documentation et la matrice des composants.

---

## 5. PLAN DE DÉVELOPPEMENT PRIORISÉ

1. **Phase 0 — Audit & Spécifications (Terminée)** : Cartographie complète, analyse des écarts, architecture cible.
2. **Phase 1 — Socle Technique (En cours)** :
   - Initialisation du monorepo et configuration Git.
   - Définition de l'infrastructure Docker Compose (PostgreSQL, Redis, MinIO).
   - Migrations SQL versionnées pour l'ensemble des 24 entités obligatoires.
   - Implémentation du backend Go modulaire et du serveur HTTP `/api/v1`.
   - CI GitHub Actions et documentation initiale.
3. **Phase 2 — Identité, Cryptographie & Appareils** :
   - Implémentation de `packages/crypto_core` (Ed25519, X25519, HKDF, ChaCha20-Poly1305).
   - Inscription et authentification par défi cryptographique.
   - Enregistrement des appareils avec **limite stricte de 3 appareils**.
   - **Tests automatisés du rejet du 4ème appareil**.
   - Gestion et révocation des sessions.
4. **Phase 3 — Messagerie E2EE & Synchronisation** :
   - Conversations directes et de groupe.
   - Enveloppes chiffrées inviolables côté serveur.
   - Journal de synchronisation (`sync_events`), accusés de réception et file hors-ligne.
5. **Phase 4 — Médias Découpés & Signalement WebRTC** :
   - Upload découpé en blocs avec reprise sur interruption et vérification SHA-256.
   - Sessions d'appels audio/vidéo et signalement WebRTC.
6. **Phase 5 — Annuaire & Espace Social (Moments)** :
   - Carnet de contacts avec notes chiffrées strictement privées.
   - Statuts éphémères et gestion fine de l'audience.
7. **Phase 6 — MRixk AI : Intelligence Personnelle Locale** :
   - Runtime IA local avec mémoire vectorielle et graphe de connaissances.
   - **Tests stricts d'isolation cognitive : $M(u_1) \cap M(u_2) = \emptyset$**.
8. **Phase 7 — Durcissement & Validation Multiplateforme** :
   - Validation des 19 critères d'acceptation V1.
