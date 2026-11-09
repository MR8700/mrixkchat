# ÉTAT DU PROJET MRIXK — STATUT OFFICIEL

**Dernière mise à jour :** 09 Novembre 2026  
**Architecte Référent :** Richard MARE  
**Document de spécification :** `file:///home/richard/Documents/MessagerieMRixk.odt`  

---

## 1. PHASE ACTUELLE
- **Phase 0 (Audit & Spécifications) :** TERMINEE  
- **Phase 1 (Socle Technique & Infrastructure) :** TERMINEE & VALIDEE  
- **Phase 2 (Identité, Cryptographie & Appareils) :** TERMINEE & VALIDEE  
- **Prochaine Phase :** Phase 3 (Messagerie E2EE multi-appareils & Synchronisation temps réel)

---

## 2. FONCTIONNALITÉS TERMINÉES ET VÉRIFIÉES

| Composant | Fonctionnalité | Statut | Preuve / Validation |
| :--- | :--- | :--- | :--- |
| **Monorepo** | Structure conforme section 8 (`apps/`, `backend/`, `packages/`, `infrastructure/`, `docs/`, `tests/`) | Terminé | Arborescence Git validée |
| **Cryptographie** | Signatures numériques Ed25519 & vérification | Terminé | `packages/crypto_core/crypto_test.go` PASS |
| **Cryptographie** | Échange de clés X25519 (ECDH) & dérivation HKDF-SHA256 | Terminé | `packages/crypto_core/crypto_test.go` PASS |
| **Cryptographie** | Chiffrement authentifié AES-256-GCM avec AAD et détection d'altération | Terminé | `packages/crypto_core/crypto_test.go` PASS |
| **Cryptographie** | Paquets de préclés signées (`PreKeyPackage`) | Terminé | `packages/crypto_core/crypto_test.go` PASS |
| **Base de Données** | Migrations complètes des 24 entités obligatoires (`000001_initial_schema.up.sql`) | Terminé | Schéma SQL réversible (`down.sql`) |
| **Infrastructure** | Stack Docker Compose (PostgreSQL 16, Redis 7, MinIO S3, Backend) | Terminé | `docker-compose.yml` validé |
| **Identité** | Inscription avec identifiant unique (`@mrixk.richard`), mot de passe salé/hashé | Terminé | `backend/internal/api/router_test.go` PASS |
| **Identité** | Détection et rejet des doublons d'identifiant (HTTP 409 Conflict) | Terminé | `backend/internal/api/router_test.go` PASS |
| **Gestion Appareils** | Autorisation d'appareils avec clés indépendantes Ed25519/X25519 | Terminé | `backend/internal/devices/service_test.go` PASS |
| **Gestion Appareils** | **Limite stricte de 3 appareils autorisés** | Terminé | `backend/internal/devices/service_test.go` PASS |
| **Gestion Appareils** | **Refus explicite du 4ème appareil (HTTP 403 Forbidden)** | Terminé | `backend/internal/api/router_test.go` PASS |
| **Gestion Appareils** | Révocation d'un appareil à distance et libération du quota | Terminé | `backend/internal/devices/service_test.go` PASS |
| **Gestion Appareils** | Invalidation immédiate des sessions révoquées | Terminé | `backend/internal/devices/service_test.go` PASS |
| **Messagerie E2EE** | Réception et stockage strict d'enveloppes chiffrées (zéro clair serveur) | Terminé | `backend/internal/api/router_test.go` PASS |
| **Synchronisation** | Journal ordonné d'événements (`sync_events`) et curseurs | Terminé | `backend/internal/api/router_test.go` PASS |
| **Mémoire Vectorielle** | Similarité cosinus, score lexical, décroissance temporelle | Terminé | `packages/vector_memory/vector_test.go` PASS |
| **Mémoire Vectorielle** | Formule de score hybride : $\alpha S_{sém} + \beta S_{lex} + \gamma S_{rec} + \delta S_{conf}$ | Terminé | `packages/vector_memory/vector_test.go` PASS |
| **IA Locale** | Architecture cognitive $M(u) = \{D(u), V(u), G(u), P(u), H(u)\}$ | Terminé | `packages/ai_runtime/runtime_test.go` PASS |
| **IA Locale** | **Isolation stricte prouvée : $M(u_1) \cap M(u_2) = \emptyset$ (Zéro fuite cognitive)** | Terminé | `packages/ai_runtime/runtime_test.go` PASS |
| **Client Flutter** | Application Flutter modulaire avec navigation adaptée mobile & desktop | Terminé | `apps/client_flutter/lib/main.dart` |
| **Serveur Monolithe** | Serveur Go autonome avec arrêt gracieux et routes `/api/v1` | Terminé | Binaire `bin/mrixk-server` compilé (7.3 Mo) |

---

## 3. TESTS AUTOMATISÉS

- **Tests exécutés :**
  - `packages/crypto_core` : 4 tests (PASS, 0.006s)
  - `packages/vector_memory` : 4 tests (PASS, 0.002s)
  - `packages/ai_runtime` : 2 tests (PASS, 0.002s)
  - `backend/internal/devices` : 1 suite complète de quota d'appareils (PASS, 0.002s)
  - `backend/internal/api` : 1 test d'intégration de bout en bout (PASS, 0.004s)
- **Taux de réussite :** **100% (12/12 suites réussies)**
- **Tests échoués :** **0**

---

## 4. DÉCISIONS TECHNIQUES ACTÉES

1. **Monolithe Modulaire Go :** Choix d'une architecture modulaire en Go 1.22 plutôt que des microservices prématurés, assurant latence minimale, simplicité de maintenance et déploiement aisé.
2. **Cryptographie sans dépendance externe bloquante :** Utilisation des primitives standard Go 1.22 (`crypto/ecdh`, `crypto/ed25519`, `crypto/cipher`, `crypto/sha256`) garantissant une sécurité auditable sans risque de chaîne d'approvisionnement compromise.
3. **Limite de 3 appareils matériels :** Règle métier bloquante avec comptage atomique des appareils actifs et rejet HTTP 403 Forbidden pour toute 4ème tentative tant qu'un appareil existant n'est pas révoqué.
4. **Zéro Connaissance Serveur :** La base serveur PostgreSQL ne stocke que des enveloppes chiffrées en Base64/binaire. Aucun endpoint n'expose ni ne déchiffre de contenu privé.
5. **Espace Cognitif IA Étanche :** Séparation formelle $M(u) = \{D(u), V(u), G(u), P(u), H(u)\}$ vérifiée par tests cryptographiques et logiques. Interdiction absolue d'API IA distante.

---

## 5. PROCHAINES PRIORITÉS (PHASE 3 & SUIVANTES)

1. **Phase 3 :** Intégration du WebSocket en temps réel pour la distribution instantanée des enveloppes chiffrées aux appareils en ligne.
2. **Phase 3 :** Implémentation de la file d'attente locale SQLite hors-ligne et reprise à la reconnexion.
3. **Phase 4 :** Moteur d'envoi de médias par blocs avec contrôle d'intégrité SHA-256 et signalement WebRTC pour appels audio/vidéo.
4. **Phase 5 :** Gestion fine de l'audience pour Moments (statuts éphémères).
5. **Phase 6 :** Intégration du moteur d'inférence GGUF local (llama.cpp) et test de charge RAM/CPU.
