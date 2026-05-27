# ROADMAP — TP IaC + Conteneurisation

> Vue d'ensemble du travail à réaliser, organisée par **jalons**.
> Chaque jalon = livrable testable et commit séparé.
> Voir `SUBJECT.md` pour les exigences détaillées, `CLAUDE.md` pour les décisions techniques.

**Deadline finale : dimanche 31 mai 2026 à minuit**
**Rendu : mail à `anthony@avalone-fr.com` avec lien du dépôt**

---

## Légende

- ⬜ À faire
- 🟦 En cours
- ✅ Terminé
- 🔴 Bloqué

---

## J0 — Initialisation du projet

> Objectif : repo prêt, docs cadrées, équipe (Claude + moi) alignée.

- ✅ Lire le sujet PDF
- ✅ Brainstorm + décisions techniques (cf. CLAUDE.md)
- ✅ `SUBJECT.md` rédigé
- ✅ `CLAUDE.md` rédigé
- ✅ `ROADMAP.md` rédigé (ce fichier)
- ⬜ `.gitignore` initial
- ⬜ `README.md` initial
- ⬜ `git init` + premier commit
- ⬜ Repo GitHub `infra-tp-cont` créé et push

**Commits prévus :**
- `chore: initialisation du projet`
- `docs: ajout du sujet, contexte et roadmap`

---

## J1 — Conteneurisation de l'application *(3 pts)*

> Objectif : application Avalone tourne en local via Docker, image publiée sur Docker Hub.

- ⬜ Cloner `gestion-produits` depuis GitLab Avalone
- ⬜ Créer le fork sur GitHub (origin = mon GitHub, upstream = GitLab Avalone)
- ⬜ Écrire `Dockerfile` multi-stage (PHP-FPM + Apache OU PHP + serveur intégré)
- ⬜ Écrire `docker-compose.yml` local (app + MariaDB) pour tester
- ⬜ Charger le jeu d'essai (DB + images)
- ⬜ Vérifier l'app accessible en local sur `http://localhost`
- ⬜ Créer le compte / repo Docker Hub `samuressiot/gestion-produits`
- ⬜ Premier build/push manuel pour valider

**Commits prévus :**
- `feat(app): ajout du Dockerfile pour l'application` (sur le repo de l'app)
- `feat(app): ajout du docker-compose local de dev` (sur le repo de l'app)
- `docs: documentation de la conteneurisation` (sur infra-tp-cont)

---

## J2 — Infrastructure Docker (Terraform) *(7 pts)*

> Objectif : `terraform apply` provisionne 1 EC2 + EIP + SG, prête à recevoir Docker.

- ⬜ Compte AWS : créer utilisateur IAM dédié, configurer credentials locales
- ⬜ Configurer alerte budget AWS (20 € warn, 50 € cap)
- ⬜ `terraform/modules/network/` : VPC, subnet public, IGW, route table
- ⬜ `terraform/modules/docker-host/` : 1 EC2 t3.small, EIP, SG (80/443/22), key pair
- ⬜ `user_data` cloud-init : install Docker + docker compose plugin
- ⬜ `terraform/envs/docker/main.tf` : appel des modules
- ⬜ Variables : `terraform.tfvars.example`
- ⬜ Test idempotence : `terraform destroy && terraform apply`
- ⬜ SSH manuel pour vérifier `docker version` OK

**Commits prévus :**
- `feat(terraform): module network (VPC, subnet, SG)`
- `feat(terraform): module docker-host (EC2 + EIP + cloud-init Docker)`
- `feat(terraform): env docker complet et idempotent`

---

## J3 — Déploiement de l'app sur Docker *(6 pts)*

> Objectif : Traefik route `https://gestion-produits.local` vers l'app prod.

- ⬜ Écrire `docker/docker-compose.yml` prod (Traefik + app-prod + db-mysql)
- ⬜ Config Traefik (statique + dynamique) avec labels + TLS auto-signé
- ⬜ Script de génération du certif auto-signé au boot
- ⬜ Init schema MySQL au premier boot (volume + script SQL)
- ⬜ Déploiement via SSH + `docker compose up -d`
- ⬜ Ajout entrée `/etc/hosts` local : `<EIP> gestion-produits.local`
- ⬜ Test bout en bout : navigation, ajout produit, persistance après restart
- ⬜ Cible Makefile `make deploy-docker`

**Commits prévus :**
- `feat(docker): docker-compose prod avec Traefik + MySQL`
- `feat(docker): configuration Traefik et TLS auto-signé`
- `feat(make): cibles deploy-docker et démo`

---

## J4 — Infrastructure Kubernetes (Terraform) *(13 pts)*

> Objectif : 3 EC2 forment un cluster kubeadm fonctionnel + EFS provisionné.

- ⬜ `terraform/modules/k8s-cluster/` : 3 EC2 t3.small (1 CP + 2 W), EIP sur CP, SG cluster
- ⬜ EFS provisionné dans le même VPC, mount targets dans le subnet du cluster
- ⬜ SG EFS : autorise NFS 2049 depuis le SG des nodes
- ⬜ `user_data` cloud-init nodes : install containerd, kubeadm, kubelet, kubectl
- ⬜ Bootstrap script : `kubeadm init` sur le CP, `kubeadm join` sur les workers (token partagé via SSM Parameter Store)
- ⬜ Install Calico (CNI) post-bootstrap
- ⬜ Install EFS CSI driver + StorageClass `efs-sc`
- ⬜ `terraform/envs/kubernetes/main.tf` : appel des modules
- ⬜ Test : `kubectl get nodes` retourne 3 nodes Ready, `kubectl get pods -A` tout green
- ⬜ Test stockage : PVC `efs-sc` provisioné, monté dans un pod test

**Commits prévus :**
- `feat(terraform): module k8s-cluster (3 EC2 + bootstrap kubeadm)`
- `feat(terraform): provisionnement EFS et CSI driver`
- `feat(k8s): installation Calico CNI`
- `feat(terraform): env kubernetes complet et idempotent`

---

## J5 — Déploiement de l'app sur Kubernetes *(7 pts)*

> Objectif : Traefik Ingress route `https://k8s.gestion-produits.local` vers l'app prod en K8s.

- ⬜ Install Traefik en Ingress controller (hostNetwork sur CP, ou NodePort + iptables)
- ⬜ `k8s/base/app/` : Deployment + Service + Ingress (template kustomize)
- ⬜ `k8s/base/db/` : StatefulSet MySQL + Service + PVC EFS + Secret password
- ⬜ `k8s/overlays/prod/` : image:prod, host gestion-produits.local
- ⬜ Init schema via initContainer ou ConfigMap mounté
- ⬜ `kubectl apply -k k8s/overlays/prod`
- ⬜ Test bout en bout + persistance après suppression de pod (StatefulSet rescheduled)
- ⬜ Cible Makefile `make deploy-k8s`

**Commits prévus :**
- `feat(k8s): manifests de base (Deployment, Service, Ingress)`
- `feat(k8s): StatefulSet MySQL avec PVC EFS`
- `feat(k8s): overlay prod et déploiement`
- `feat(make): cible deploy-k8s`

---

## J6 — Version dev avec PostgreSQL *(4 pts)*

> Objectif : `dev.gestion-produits.local` et `dev.k8s.gestion-produits.local` servent l'app patchée PostgreSQL.

- ⬜ Sur le fork de l'app : créer branche `dev` à partir de `main`
- ⬜ Patcher le code PHP : DSN PDO `mysql:` → `pgsql:`
- ⬜ Patcher requêtes SQL incompatibles (AUTO_INCREMENT, backticks, LIMIT x,y, etc.)
- ⬜ Écrire `init-postgres.sql` (schéma + jeu d'essai converti)
- ⬜ Tester en local via `docker-compose` (app-dev + postgres)
- ⬜ Build/push image `samuressiot/gestion-produits:dev`
- ⬜ Côté Docker : ajouter services `app-dev` + `db-postgres` au `docker-compose.yml` prod
- ⬜ Côté K8s : ajouter overlay `dev` (image:dev, host dev.k8s.gestion-produits.local, db postgres)
- ⬜ Test bout en bout les 4 URLs

**Commits prévus :**
- `feat(app): branche dev avec migration PostgreSQL` (sur le repo de l'app)
- `feat(docker): ajout app-dev et db-postgres au compose`
- `feat(k8s): overlay dev avec PostgreSQL`

---

## J7 — CI/CD GitHub Actions

> Objectif : push sur `main` ou `dev` → build/push image + déploiement auto sur les 2 stacks.

- ⬜ Créer compte Docker Hub + token avec scope projet
- ⬜ Secrets GitHub : `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `AWS_*`, `SSH_PRIVATE_KEY`, `KUBECONFIG_B64`
- ⬜ Workflow `build-and-deploy.yml` sur le repo de l'app :
  - job `build` : build + push tags `${branch}-${sha}`, `${branch}-latest`, `prod`/`dev`
  - job `deploy-docker` : SSH + `docker compose pull && up -d`
  - job `deploy-k8s` : `kubectl set image deployment/...`
- ⬜ Workflow `terraform.yml` sur infra-tp-cont :
  - `terraform fmt -check`, `validate`, `plan` sur PR
  - `apply` derrière `workflow_dispatch` manuel
- ⬜ Test : push sur branche `dev` → image dev mise à jour automatiquement sur les 2 infras

**Commits prévus :**
- `ci: workflow build et push Docker Hub` (sur le repo de l'app)
- `ci: workflow deploy Docker via SSH` (sur le repo de l'app)
- `ci: workflow deploy Kubernetes` (sur le repo de l'app)
- `ci: workflow Terraform plan et apply` (sur infra-tp-cont)

---

## J8 — Documentation finale et polish

> Objectif : doc complète, démo reproductible, prêt à envoyer.

- ⬜ `README.md` final : présentation, quick start, table des matières
- ⬜ `docs/01-architecture.md` : diagrammes, choix techniques justifiés
- ⬜ `docs/02-terraform.md` : modules, variables, outputs, idempotence
- ⬜ `docs/03-docker-stack.md` : services, réseaux, volumes, Traefik
- ⬜ `docs/04-kubernetes.md` : topologie, EFS, ingress, overlays
- ⬜ `docs/05-cicd.md` : pipelines, secrets, flux
- ⬜ `docs/06-deployment-guide.md` : pas à pas from scratch
- ⬜ `docs/07-evaluation-guide.md` : exactement quoi mettre dans `/etc/hosts` + URLs à tester
- ⬜ Captures d'écran dans `docs/images/`
- ⬜ Cible Makefile `make demo` qui prouve que tout marche
- ⬜ Test final : `terraform destroy` total + `terraform apply` total + `make demo` → green

**Commits prévus :**
- `docs: README et guide de démarrage`
- `docs: documentation Terraform et infrastructure`
- `docs: documentation Docker et Kubernetes`
- `docs: documentation CI/CD et guide correcteur`

---

## J9 — Rendu *(JALON CRITIQUE)*

> Objectif : mail envoyé à Anthony **avant le 31 mai 2026 à minuit**.

- ⬜ Tag git `v1.0` sur les deux repos
- ⬜ Repos GitHub passés en public (ou accès donné à Anthony)
- ⬜ Test final by a fresh `git clone` et déroulement complet du guide d'éval
- ⬜ Mail à `anthony@avalone-fr.com` avec :
  - lien `infra-tp-cont`
  - lien fork `gestion-produits`
  - URLs et lignes `/etc/hosts` à ajouter
  - estimation du temps pour évaluer
- ⬜ Confirmer accusé de réception

---

## Tableau de pointage

| Jalon | Points associés | Statut |
|---|---|---|
| J0 — Init | — | 🟦 En cours |
| J1 — Conteneurisation | 3 | ⬜ |
| J2 — Infra Docker | 7 | ⬜ |
| J3 — Deploy Docker | 6 | ⬜ |
| J4 — Infra K8s | 13 | ⬜ |
| J5 — Deploy K8s | 7 | ⬜ |
| J6 — Version dev | 4 | ⬜ |
| J7 — CI/CD | bonus | ⬜ |
| J8 — Doc finale | — | ⬜ |
| J9 — Rendu | — | ⬜ |
| **Total** | **40** | |

---

## Notes / risques / décisions ouvertes

- ⚠️ **Vérifier** la date d'ouverture du compte AWS (Free Tier 12 mois) → impact budget si proche expiration.
- ⚠️ Si EFS CSI driver pose problème → fallback NFS server sur une 4e EC2 (mais coût additionnel).
- ⚠️ Le sujet exige les ports **80/443 uniquement** → Traefik en `hostNetwork` ou iptables NAT côté K8s, à valider en J4.
- 📝 Décider si le repo `infra-tp-cont` sera public dès le départ ou rendu public au moment du rendu.
