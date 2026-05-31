# Architecture

## Vue d'ensemble

Deux infrastructures parallèles provisionnées sur AWS (région `eu-west-3` / Paris) via Terraform, déployant la **même application** (PHP + PDO) sous **deux versions** (prod MySQL et dev PostgreSQL), accessibles sur **4 URLs distinctes** servies en HTTPS sur les ports standard 80/443.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS - eu-west-3                            │
│                                                                     │
│   ┌────────────────────────┐    ┌─────────────────────────────┐    │
│   │   STACK DOCKER         │    │   STACK KUBERNETES (k3s)    │    │
│   │   1 EC2 t3.small       │    │   3 EC2 t3.small + EFS      │    │
│   │   VPC 10.0.0.0/16      │    │   VPC 10.10.0.0/16          │    │
│   │   EIP 13.36.147.208    │    │   EIP CP 13.36.198.45       │    │
│   │                        │    │                             │    │
│   │   Reverse proxy:       │    │   Ingress controller:       │    │
│   │   - Traefik v3.7       │    │   - Traefik (fourni k3s)    │    │
│   │   - TLS auto-signé     │    │   - TLS auto-signé          │    │
│   │                        │    │                             │    │
│   │   Services :           │    │   Pods K8s :                │    │
│   │   - app-prod (PHP)     │    │   ns gestion-produits-prod  │    │
│   │   - db-mysql 8.4       │    │     - Deployment app        │    │
│   │   - app-dev (PHP)      │    │     - StatefulSet db-mysql  │    │
│   │   - db-postgres 16     │    │                             │    │
│   │                        │    │   ns gestion-produits-dev   │    │
│   │   Réseaux Docker :     │    │     - Deployment app (dev)  │    │
│   │   - web (public)       │    │     - StatefulSet db-postgr │    │
│   │   - db-prod (interne)  │    │                             │    │
│   │   - db-dev  (interne)  │    │   StorageClass local-path   │    │
│   └────────────────────────┘    │   (EFS provisionné pour     │    │
│                                 │    bonus, non utilisé en    │    │
│                                 │    pratique)                │    │
│                                 └─────────────────────────────┘    │
│                                                                     │
│   Image gestion-produits : buildée localement, distribuée via       │
│   `docker save` + `scp` + `ctr import` (containerd k3s).            │
└─────────────────────────────────────────────────────────────────────┘
```

## Mapping des URLs

| URL | Stack | EIP | Branche du code | DB |
|---|---|---|---|---|
| `gestion-produits.local` | Docker | `13.36.147.208` | `main` | MySQL 8.4 |
| `dev.gestion-produits.local` | Docker | `13.36.147.208` | `dev` | PostgreSQL 16 |
| `k8s.gestion-produits.local` | K8s | `13.36.198.45` | `main` | MySQL 8.4 |
| `dev.k8s.gestion-produits.local` | K8s | `13.36.198.45` | `dev` | PostgreSQL 16 |

## Choix techniques structurants

| Sujet | Choix | Raison |
|---|---|---|
| Cloud | AWS (Free Tier perso) | Provider Terraform mature, budget OK avec stop/start |
| IaC | Terraform 1.9+ | Standard de facto, écosystème mature |
| Distribution EC2 | Ubuntu 24.04 LTS | apt familier, install Docker/K8s bien documentée |
| K8s | **k3s v1.35** sur 3 EC2 | Initialement kubeadm, basculé sur k3s pour fiabilité (install 30s/node). k3s est K8s certifié CNCF, donc conforme à *"cluster Kubernetes 3 nœuds"* du sujet. |
| Reverse proxy Docker | Traefik v3.7 | Auto-discovery via labels, TLS, redirect HTTP→HTTPS |
| Ingress K8s | Traefik (fourni par k3s) | Cohérence avec la stack Docker |
| Stockage K8s | local-path (k3s) | EFS provisionné par Terraform mais CSI driver non installé faute de temps. Suffisant pour StatefulSet single-pod. |
| DNS / accès | `/etc/hosts` + 2 EIPs | Conforme sujet (pas d'achat de domaine) |
| TLS | Certificats auto-signés | Sujet précise que c'est acceptable |
| Registry | Local (pas de Docker Hub) | CI/CD non implémentée, image distribuée via `ctr import` |

## Flux de déploiement

```
Code app (branche main ou dev)
   │
   │ docker build -t samrst/gestion-produits:<tag>
   ▼
Image locale Docker
   │
   ├── docker compose up -d           ──► Docker EC2 (prod + dev coexist)
   │
   └── docker save → scp → ctr import ──► 3 nodes k3s (puis kubectl apply -k)
```

## Sécurité

- **Security Groups AWS** : 80/443 publics, SSH restreint à l'IP admin (`5.49.95.157/32`).
- **EFS SG** : NFS 2049 ouvert uniquement depuis le SG du cluster K8s.
- **IMDSv2 obligatoire** sur les EC2 (`http_tokens=required`).
- **EBS chiffré** au repos.
- **TLS** auto-signé (acceptable selon sujet).
- **Secrets** : mots de passe DB générés aléatoirement et stockés dans Kubernetes Secrets / fichier `.env` gitignored, jamais commités.
- **IAM** : user dédié `terraform-tp-cont` avec `AdministratorAccess`, séparé du root.
