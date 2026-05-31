# Guide d'évaluation — Comment tester le TP en 5 minutes

> Document destiné au correcteur (Anthony).
> Aucun outil à installer côté correcteur — juste un `/etc/hosts` à modifier et un navigateur.

---

## 1. Ajouter 2 lignes à `/etc/hosts`

**Linux/macOS :** `sudo nano /etc/hosts`
**Windows :** ouvrir `C:\Windows\System32\drivers\etc\hosts` en administrateur

Ajouter :

```
13.36.147.208  gestion-produits.local  dev.gestion-produits.local
13.36.198.45   k8s.gestion-produits.local  dev.k8s.gestion-produits.local
```

Ces 2 IPs sont les Elastic IPs AWS attribuées aux infrastructures :
- `13.36.147.208` → EC2 unique qui héberge la **stack Docker** (Traefik + 4 services)
- `13.36.198.45` → control-plane du **cluster K8s** (3 nœuds k3s, Traefik Ingress)

---

## 2. Tester les 4 URLs

**Identifiants pour les 4 URLs :** `admin` / `password`

| URL | Stack | Branche du code | Base de données | À vérifier |
|---|---|---|---|---|
| <https://gestion-produits.local> | Docker | `main` | MySQL 8.4 | Liste des 5 produits, photos sur les fiches |
| <https://dev.gestion-produits.local> | Docker | `dev` | PostgreSQL 16 | Idem, données identiques |
| <https://k8s.gestion-produits.local> | Kubernetes (k3s) | `main` | MySQL 8.4 (StatefulSet) | Idem |
| <https://dev.k8s.gestion-produits.local> | Kubernetes (k3s) | `dev` | PostgreSQL 16 (StatefulSet) | Idem |

Le navigateur affichera un **avertissement TLS** (certificat auto-signé) — cliquer sur « Continuer ». Le sujet précise que des certificats auto-signés sont acceptables.

### Test rapide en ligne de commande (curl)

```bash
# Docker prod (MySQL)
curl -k --resolve gestion-produits.local:443:13.36.147.208 \
  https://gestion-produits.local/ -o /dev/null -w "HTTP %{http_code}\n"
# → HTTP 200

# Docker dev (PostgreSQL)
curl -k --resolve dev.gestion-produits.local:443:13.36.147.208 \
  https://dev.gestion-produits.local/ -o /dev/null -w "HTTP %{http_code}\n"
# → HTTP 200

# K8s prod (MySQL)
curl -k --resolve k8s.gestion-produits.local:443:13.36.198.45 \
  https://k8s.gestion-produits.local/ -o /dev/null -w "HTTP %{http_code}\n"
# → HTTP 200

# K8s dev (PostgreSQL)
curl -k --resolve dev.k8s.gestion-produits.local:443:13.36.198.45 \
  https://dev.k8s.gestion-produits.local/ -o /dev/null -w "HTTP %{http_code}\n"
# → HTTP 200
```

---

## 3. Vérifier que les versions MySQL / PostgreSQL diffèrent bien

Connecté avec `admin/password`, sur chaque URL, ajouter un produit via le bouton **« Ajouter un produit »**. Les nouveaux produits ne seront visibles que sur l'URL où ils ont été créés, prouvant que les 4 bases de données sont indépendantes.

Pour aller plus loin (optionnel) :

```bash
# Lister les conteneurs Docker (single host) :
ssh -i terraform/.ssh/tp-cont-docker.pem ubuntu@13.36.147.208 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'

# Lister les pods Kubernetes :
export KUBECONFIG=terraform/.ssh/kubeconfig
kubectl get pods -A
kubectl get nodes -o wide      # → 3 nodes Ready (k3s v1.35.5)
```

---

## 4. Structure du dépôt

```
infra-tp-cont/
├── README.md                # Vue d'ensemble + index
├── SUBJECT.md               # Reformulation du sujet
├── CLAUDE.md                # Décisions techniques actées
├── ROADMAP.md               # Avancement par jalons
├── Makefile                 # Commandes de haut niveau (make help)
│
├── docs/                    # Documentation détaillée
│   ├── 01-architecture.md
│   ├── 02-terraform.md
│   ├── 03-docker-stack.md
│   ├── 04-kubernetes.md
│   ├── 06-deployment-guide.md
│   └── 07-evaluation-guide.md   # CE FICHIER
│
├── app/                     # Code de l'application (PHP + PDO)
│   ├── Dockerfile           # Image multi-stage PHP 8.2 + Apache
│   ├── compose.yml          # Compose local de développement de l'image
│   ├── php/www/             # Sources PHP
│   └── database/
│       ├── gestion_produits.sql           # Dump MySQL (branche main)
│       └── gestion_produits.postgres.sql  # DDL PostgreSQL (branche dev)
│
├── terraform/               # Infrastructure as Code
│   ├── modules/
│   │   ├── network/         # VPC + subnet public + IGW
│   │   ├── docker-host/     # EC2 t3.small + EIP + SG + cloud-init Docker
│   │   └── k8s-cluster/     # 3 EC2 + EFS + SG cluster
│   ├── envs/
│   │   ├── docker/          # Env Terraform pour la stack Docker
│   │   └── kubernetes/      # Env Terraform pour le cluster K8s
│   └── README.md
│
├── docker/                  # Stack Docker (déployée sur l'EC2)
│   ├── compose.yml          # Traefik + app-prod + db-mysql + app-dev + db-postgres
│   ├── traefik/             # Config dynamique TLS + certifs auto-signés
│   ├── init/                # Dumps SQL d'initialisation
│   ├── scripts/
│   │   ├── gen-certs.sh
│   │   └── deploy.sh
│   └── README.md
│
└── k8s/                     # Manifests Kubernetes (kustomize)
    ├── base/                # Ressources communes (Deployment, StatefulSet, Service)
    ├── overlays/
    │   ├── prod/            # Overlay prod (MySQL)
    │   └── dev/             # Overlay dev (PostgreSQL, image dev)
    └── scripts/
        ├── bootstrap.sh     # Install k3s sur les 3 EC2
        └── deploy.sh        # Déploiement des manifests
```

---

## 5. Reproduire l'environnement from scratch (optionnel)

Si vous souhaitez tout déployer vous-même sur votre compte AWS :

```bash
# Pré-requis : Terraform 1.9+, AWS CLI configuré, Docker Desktop, openssl, jq

git clone https://github.com/samrst/infra-tp-cont
cd infra-tp-cont

# 1. Infra Docker (~3 min)
cd terraform/envs/docker
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars (admin_ip_cidr = votre IP/32)
terraform init && terraform apply
cd ../../..

# 2. Stack Docker (~3 min, build + push image)
./docker/scripts/deploy.sh

# 3. Infra K8s (~5 min, 3 EC2 + EFS)
cd terraform/envs/kubernetes
cp terraform.tfvars.example terraform.tfvars  # (existe si exemple non livré)
# éditer admin_ip_cidr
terraform init && terraform apply
cd ../../..

# 4. Cluster k3s (~3 min)
./k8s/scripts/bootstrap.sh

# 5. Déploiement de l'app sur K8s (~2 min, prod + dev)
./k8s/scripts/deploy.sh

# 6. Vérifier les 4 URLs (voir section 2)
```

Pour tout détruire : `cd terraform/envs/{docker,kubernetes} && terraform destroy`.

---

## 6. Points qui pourraient être améliorés

- **CI/CD GitHub Actions** non implémentée (le code de l'app est buildé localement et l'image est poussée via `ctr import`). Une CI/CD aurait push l'image sur Docker Hub.
- **EFS CSI driver** non installé (le sujet demande du stockage partagé) : on utilise le provisioner `local-path` de k3s. Pour respecter strictement le sujet, l'EFS provisionné par Terraform serait utilisé en ajoutant le driver `aws-efs-csi-driver`.
- **state Terraform** local plutôt que sur S3+DynamoDB (acceptable en TP, à migrer en prod).

---

## 7. Contact

Pour toute question sur le rendu :
**Samuel Ressiot** — `samuel.ressiot@gmail.com`
