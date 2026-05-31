# TP IaC + Conteneurisation avancée — Samuel Ressiot

> **EPSI M1 DEV** — TP noté IaC Terraform & Conteneurisation
> Référent : Anthony (Avalone) — `anthony@avalone-fr.com`
> Rendu : 31 mai 2026

---

## ✅ Statut

**Tous les jalons applicatifs terminés et validés en bout-en-bout.**

| URL | Stack | Branche | DB | Statut |
|---|---|---|---|---|
| <https://gestion-produits.local> | Docker (EIP `13.36.147.208`) | `main` | MySQL 8.4 | ✅ HTTP 200 |
| <https://dev.gestion-produits.local> | Docker | `dev` | PostgreSQL 16 | ✅ HTTP 200 |
| <https://k8s.gestion-produits.local> | K8s (EIP CP `13.36.198.45`) | `main` | MySQL 8.4 | ✅ HTTP 200 |
| <https://dev.k8s.gestion-produits.local> | K8s | `dev` | PostgreSQL 16 | ✅ HTTP 200 |

Login : `admin` / `password` sur les 4 URLs.

---

## 🚀 Tester en 2 minutes (correcteur)

Voir [`docs/07-evaluation-guide.md`](docs/07-evaluation-guide.md) pour le pas à pas complet.

**Résumé :**
1. Ajouter à `/etc/hosts` :
   ```
   13.36.147.208  gestion-produits.local  dev.gestion-produits.local
   13.36.198.45   k8s.gestion-produits.local  dev.k8s.gestion-produits.local
   ```
2. Ouvrir les 4 URLs dans le navigateur, accepter le certificat auto-signé, se connecter avec `admin` / `password`.
3. Vérifier que les 5 produits du jeu d'essai sont affichés. Optionnel : ajouter un produit sur une URL pour confirmer que les 4 bases sont indépendantes.

---

## 🗂 Documentation

| Fichier | Contenu |
|---|---|
| [`SUBJECT.md`](SUBJECT.md) | Reformulation détaillée du sujet et grille de notation |
| [`CLAUDE.md`](CLAUDE.md) | Décisions techniques actées, contexte projet |
| [`ROADMAP.md`](ROADMAP.md) | Avancement par jalons (J0 → J9) |
| [`docs/01-architecture.md`](docs/01-architecture.md) | Vue d'ensemble, diagramme, choix techniques |
| [`docs/07-evaluation-guide.md`](docs/07-evaluation-guide.md) | **Guide du correcteur (à lire en priorité)** |
| [`terraform/README.md`](terraform/README.md) | Procédure AWS + Terraform |
| [`docker/README.md`](docker/README.md) | Stack Docker et reverse proxy |

---

## ⚙️ Stack technique

- **Cloud** : AWS (région `eu-west-3` / Paris)
- **IaC** : Terraform 1.9+
- **Distribution** : Ubuntu 24.04 LTS
- **Docker** : Engine 27/29 + Compose v2
- **Kubernetes** : k3s v1.35 (3 nodes : 1 CP + 2 workers)
- **Reverse proxy / Ingress** : Traefik v3.7
- **TLS** : certificats auto-signés (acceptable selon sujet)
- **App** : PHP 8.2 + Apache + PDO MySQL / PostgreSQL

---

## 🎯 Notation attendue

| Module | Critère | Points | Statut |
|---|---|---|---|
| **IaC Terraform** | Infra Docker (`terraform/envs/docker`) | /7 | ✅ Provisionnée, idempotente |
| | Infra K8s (`terraform/envs/kubernetes`) | /13 | ✅ Provisionnée, bootstrap k3s automatisé |
| | **Sous-total IaC** | **/20** | |
| **Conteneurisation** | Dockerfile multi-stage de l'app | /3 | ✅ PHP+Apache, PDO MySQL+PG, healthcheck |
| | Déploiement app sur Docker (prod) | /6 | ✅ Traefik + 2 réseaux isolés + TLS |
| | Déploiement app sur K8s | /7 | ✅ Kustomize base + overlays prod/dev |
| | Mise à jour de l'app (version dev PG) | /4 | ✅ Branche `dev` + 2 stacks parallèles |
| | **Sous-total Conteneurisation** | **/20** | |
| **TOTAL** | | **/40** | |

---

## 📦 Cibles Makefile (interface utilisateur)

```bash
make help            # liste les cibles
make info            # affiche les EIPs et les 4 URLs
make demo            # curl les 4 URLs et affiche les HTTP codes
make up              # terraform apply des 2 envs + bootstrap k3s
make deploy          # déploie l'app sur Docker et K8s
make destroy-all     # détruit toutes les infras AWS
```

---

## 🛑 Limites connues / points à améliorer (transparence)

- **CI/CD GitHub Actions** non implémentée — l'image est buildée localement et distribuée via `docker save` + `scp` + `ctr import`. Une CI/CD aurait pushé sur Docker Hub.
- **EFS CSI driver** non installé sur k3s — l'EFS est provisionné par Terraform mais le driver `aws-efs-csi-driver` n'a pas été déployé faute de temps. Les `PersistentVolumeClaim` utilisent le provisioner `local-path` fourni par k3s, qui suffit pour un StatefulSet single-pod mais n'est techniquement pas "partagé entre nodes" (limitation à signaler honnêtement).
- **State Terraform** local (S3+DynamoDB pas mis en place). Acceptable en TP.
- Le pivot **kubeadm → k3s** à 24h de la deadline est documenté dans [`ROADMAP.md`](ROADMAP.md) et [`CLAUDE.md`](CLAUDE.md). k3s est K8s certifié CNCF, le sujet ne demande pas explicitement kubeadm.
