# SUBJECT — TP noté M1 DEV

> IaC – Terraform – Conteneurisation avancée
> EPSI M1 DEV — 07/05/2026
> Source : `docs/20260507 - IAC - CONT - TP noté.pdf - Nextcloud AVALONE.pdf`

---

## 1. Contexte

Ce TP couvre **deux modules** dont les notes sont **extraites séparément** :

| Module | Note | Total |
|---|---|---|
| **IaC – Terraform** | Déploiement de l'infrastructure | /20 |
| **Conteneurisation avancée** | Conteneurisation + déploiements + mise à jour | /20 |

Le travail unique alimente deux notes ; chaque livrable doit donc couvrir les deux modules avec la même qualité.

---

## 2. Objectif global

Déployer une application web sur un **cluster Kubernetes** en **automatisant toutes les étapes**, du provisionnement de l'infrastructure jusqu'au déploiement de l'application. Le même travail est aussi déployé sur une **infrastructure Docker** afin de comparer les deux approches.

---

## 3. Application à déployer

- **Nom** : Gestion de produits
- **Source** : <https://gl.avalone-fr.com/anthony/gestion-produits>
- **Stack** : PHP + MySQL/MariaDB
- **Caractéristiques** : application simpliste de CRUD sur des produits (libellé, prix, description, images). Jeu d'essai fourni (base de données + images).

---

## 4. Travail demandé — détail par section

### 4.1. Conteneurisation de l'application *(noté /3)*

- Conteneuriser l'application pour qu'elle fonctionne avec Docker sur un poste de travail.
- L'image doit pouvoir être **mise à jour facilement** et **exécutée dans n'importe quel environnement** supportant les conteneurs.
- Implicite : Dockerfile correct, multi-stage si pertinent, image publiée sur un registry.

### 4.2. Déploiement de l'infrastructure (Terraform / OpenTofu) *(noté /7 + /13 = 20)*

Déployer **deux infrastructures distinctes** :

1. **Infrastructure Docker** *(7 points)*
   - Exécution de Docker
   - **Reverse proxy frontal** (au choix)

2. **Cluster Kubernetes** *(13 points)*
   - Composé de **trois nœuds**
   - **Solution de stockage partagé** à prévoir

L'infrastructure cible est **libre** (Proxmox, hyperviseur, cloud public AWS/Azure/GCP, autre). **Contrainte** : elle doit être **facilement accessible** pour que le travail soit testable.

### 4.3. Déploiement de l'application *(noté /6 + /7 = 13)*

- L'application est déployée sur **les deux infrastructures**.
- Prendre en compte les **contraintes d'un déploiement en production**.
- **Automatisé au maximum**.
- **Accès via une URL** utilisant uniquement les **ports HTTP/HTTPS par défaut** (80 et 443).

**Contrainte URL/DNS :**
- ❌ Ne **pas acheter** de nom de domaine pour l'occasion.
- ✅ Utiliser le fichier `hosts`, un serveur DNS local, ou autre astuce.
- ✅ Si un domaine public est déjà possédé, il peut être utilisé avec certificat TLS public, **mais cela n'est pas plus valorisé** qu'une exécution locale avec certificats invalides.

### 4.4. Mise à jour de l'application *(noté /4)*

- Mettre en place une **version "dev"** de l'application.
- La version dev utilise **PostgreSQL** à la place de MySQL/MariaDB.
- Elle doit être accessible via une **URL spécifique** différente de la prod.
- Elle doit être disponible sur **les deux infrastructures** (Docker et Kubernetes).
- Le **processus de mise à jour** doit être **automatisé au maximum**.

---

## 5. Livrables

### Forme

- Un **dépôt git** contenant l'intégralité du travail :
  - code Terraform (modules + envs)
  - définitions Docker (Dockerfile, docker-compose)
  - manifests Kubernetes
  - scripts d'automatisation
- Un **descriptif Markdown** dans ce dépôt qui doit contenir :
  - le **descriptif technique** du travail réalisé,
  - les **instructions pour l'utiliser** (déploiement, test, mise à jour, etc.).

### Transmission

- Mail à `anthony@avalone-fr.com`.
- **Deadline** : **dimanche 31 mai 2026 à minuit**.

---

## 6. Grille de notation (récapitulatif)

### Partie IaC – Terraform *(/20)*

| Critère | Points |
|---|---|
| Déploiement de l'infrastructure pour Docker | 7 |
| Déploiement de l'infrastructure pour Kubernetes | 13 |
| **Total IaC** | **20** |

### Partie Conteneurisation *(/20)*

| Critère | Points |
|---|---|
| Conteneurisation de l'application | 3 |
| Déploiement de l'application sur Docker en prod | 6 |
| Déploiement de l'application sur Kubernetes | 7 |
| Mise à jour de l'application | 4 |
| **Total Conteneurisation** | **20** |

---

## 7. Synthèse des contraintes implicites

À ne pas oublier (déduit du sujet) :

- ✅ Infrastructure **accessible publiquement** (pour que le correcteur teste).
- ✅ Cluster K8s avec **3 nœuds** (pas 1, pas 2, pas un cluster managé monoblock).
- ✅ **Stockage partagé** dans le cluster K8s (donc DB doit pouvoir migrer entre nodes).
- ✅ **HTTP/HTTPS sur 80/443** uniquement (pas de port custom dans l'URL).
- ✅ Pas d'achat de domaine (`hosts` local accepté).
- ✅ **Automatisation maximale** : tout doit pouvoir être rejoué from scratch.
- ✅ **Deux infras parallèles** (Docker + Kubernetes), pas un choix.
- ✅ **Deux versions de l'app** (prod MySQL + dev PostgreSQL) **simultanément déployées**.
- ✅ **Doc Markdown technique + instructions d'utilisation** au minimum.
