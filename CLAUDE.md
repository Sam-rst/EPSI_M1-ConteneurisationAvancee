# CLAUDE.md

> Ce fichier sert à donner du contexte à Claude (Code / Web) pour toutes les sessions futures sur ce projet. Lis-le avant de proposer quoi que ce soit.

---

## Identité du projet

- **Nom** : TP noté M1 DEV — IaC Terraform + Conteneurisation avancée
- **École** : EPSI, M1 DEV
- **Auteur** : Samuel Ressiot (`samuel.ressiot@gmail.com`)
- **Référent** : Anthony (Avalone) — `anthony@avalone-fr.com`
- **Deadline** : **dimanche 31 mai 2026 à minuit**
- **Notation** : /40 (deux modules de /20 — voir `SUBJECT.md`)

---

## Documents de référence

- `SUBJECT.md` — Reformulation du sujet (à consulter en cas de doute sur ce qui est demandé)
- `ROADMAP.md` — État d'avancement, phases, jalons
- `docs/20260507 - IAC - CONT - TP noté.pdf - Nextcloud AVALONE.pdf` — Sujet original (PDF)

---

## Décisions techniques actées (NE PAS RE-DÉBATTRE sans accord explicite)

| Sujet | Choix | Raison |
|---|---|---|
| Cloud provider | **AWS** (compte personnel Free Tier) | Provider Terraform mature, accessibilité, budget OK si stop/start |
| Région | `eu-west-3` (Paris) | Latence + conformité |
| K8s | **kubeadm sur 3 EC2 t3.small** (1 CP + 2 workers) | Pédagogie, budget (EKS exclu — ~70€/mois pour rien) |
| Infra Docker | **1 EC2 t3.small** | Single host suffisant |
| Reverse proxy Docker | **Traefik** | Auto-discovery via labels, TLS auto |
| Ingress K8s | **Traefik** | Cohérence avec stack Docker |
| Stockage K8s partagé | **AWS EFS** + CSI driver | Service managé, NFS, Free Tier 5 Go |
| DNS / accès URL | **Fichier `/etc/hosts` + 2 Elastic IPs** | Conforme sujet (pas d'achat de domaine) |
| TLS | **Certificats auto-signés** | Sujet précise que c'est acceptable |
| App registry | **Docker Hub** (`samrst/gestion-produits`) | Choix utilisateur |
| CI/CD | **GitHub Actions** | Repo unique sur GitHub |
| Organisation des repos | **Mono-repo** (infra + app dans `infra-tp-cont`) | Plus simple, un seul workflow CI à gérer |
| Version "dev" PostgreSQL | **Branche `dev` du mono-repo** | Patch du code app + image taguée `dev` |
| CNI K8s | **Calico** | Standard, documenté |
| Automation locale | **Makefile** (interface utilisateur unique) | Simple, lisible |

---

## Architecture en une image

```
┌─────────────────────────────────────────────────────────────┐
│                   AWS (eu-west-3)                           │
│                                                             │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │   STACK DOCKER       │    │   STACK KUBERNETES       │   │
│  │   EC2 t3.small + EIP │    │   3× EC2 t3.small + EIP  │   │
│  │   - Traefik          │    │   kubeadm + Traefik      │   │
│  │   - app-prod (MySQL) │    │   Ingress + Calico       │   │
│  │   - db-mysql         │    │   EFS CSI                │   │
│  │   - app-dev (PG)     │    │   - app-prod + mysql     │   │
│  │   - db-postgres      │    │   - app-dev  + postgres  │   │
│  └──────────────────────┘    └──────────────────────────┘   │
│                                  ▲                          │
│                                  │ NFS                      │
│                              ┌───┴───┐                      │
│                              │  EFS  │ (StorageClass)       │
│                              └───────┘                      │
│                                                             │
│  GitHub Actions ──► build & push Docker Hub ──► deploy     │
└─────────────────────────────────────────────────────────────┘
```

---

## Repos liés

| Repo | URL | Rôle |
|---|---|---|
| `infra-tp-cont` | (ce dépôt, sur GitHub Samuel) | **Mono-repo** : Terraform, manifests K8s, compose, code app, Dockerfile, CI/CD, doc, Makefile |
| `gestion-produits` (upstream) | <https://gl.avalone-fr.com/anthony/gestion-produits> | Source originale Avalone (référence, pas de remote git configuré) |

**Note** : le code de l'app est intégré dans `app/`, sans le `.git` du repo upstream. La traçabilité de l'origine est documentée dans `app/UPSTREAM.md`. La branche `dev` du mono-repo contient le code patché PostgreSQL.

---

## Structure cible du dépôt

```
infra-tp-cont/
├── README.md
├── SUBJECT.md
├── CLAUDE.md
├── ROADMAP.md
├── Makefile
├── docs/
│   ├── 01-architecture.md
│   ├── 02-terraform.md
│   ├── 03-docker-stack.md
│   ├── 04-kubernetes.md
│   ├── 05-cicd.md
│   ├── 06-deployment-guide.md
│   ├── 07-evaluation-guide.md
│   └── images/
├── terraform/
│   ├── modules/
│   │   ├── network/
│   │   ├── docker-host/
│   │   └── k8s-cluster/
│   ├── envs/
│   │   ├── docker/
│   │   └── kubernetes/
│   └── shared/
├── docker/
│   ├── docker-compose.yml
│   └── traefik/
├── k8s/
│   ├── base/
│   │   ├── app/
│   │   └── db/
│   ├── overlays/
│   │   ├── prod/
│   │   └── dev/
│   └── system/
│       ├── calico.yaml
│       ├── efs-csi.yaml
│       └── traefik.yaml
└── app/                   # ⬅ code de l'application (import upstream Avalone)
    ├── UPSTREAM.md        # source originale + commit de référence
    ├── Dockerfile
    ├── compose.dev.yml    # docker compose local de développement
    └── …                  # PHP, SQL, assets
```

---

## Hôtes / URLs cibles

Le correcteur ajoutera ceci à son `/etc/hosts` :

```
<EIP_DOCKER>  gestion-produits.local  dev.gestion-produits.local
<EIP_K8S_CP>  k8s.gestion-produits.local  dev.k8s.gestion-produits.local
```

| URL | Stack | Branche app | DB |
|---|---|---|---|
| `https://gestion-produits.local` | Docker | `main` | MariaDB |
| `https://dev.gestion-produits.local` | Docker | `dev` | PostgreSQL |
| `https://k8s.gestion-produits.local` | Kubernetes | `main` | MySQL (StatefulSet) |
| `https://dev.k8s.gestion-produits.local` | Kubernetes | `dev` | PostgreSQL (StatefulSet) |

---

## Conventions

- **Langue** : code en anglais (variables, fichiers), doc et commits en français.
- **Commits** : format conventionnel ⇒ `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`.
- **Branches Terraform** : pas de magie, tout dans `main`. PRs si on bosse à deux, sinon push direct.
- **Secrets** : jamais committés. Toujours dans GitHub Secrets / AWS SSM / `.tfvars` git-ignoré.
- **Tests d'idempotence** : avant de marquer une phase terminée, faire un `terraform destroy` puis `apply` complet.

---

## Stratégie budget AWS (critique)

- Free Tier disponible mais **insuffisant** pour 4 EC2 simultanément.
- **Cible** : < 30 € sur toute la durée du TP.
- **Règle d'or** : `make stop-all` chaque fin de session de travail.
- **Élastic IPs** : laisser les 2 EIPs allouées (~3 €/mois pour 2) — `prevent_destroy` dans Terraform.
- **EFS** : 5 Go gratuits du Free Tier suffisent largement.
- **Avant la deadline** : prévoir un `make demo` qui démarre tout, attend que ce soit prêt, vérifie, et un `make stop-all` propre.
- **Surveillance** : alerte de budget AWS configurée à 20 € (warn) / 50 € (cap).

---

## Pièges connus à surveiller

1. **EIP payante si instance stoppée** → coût oublié, surveiller.
2. **kubeadm join token expire en 24h** → script de regénération automatique (`kubeadm token create --print-join-command`).
3. **EFS mount requiert SG NFS 2049** ouvert entre EC2 et EFS — souvent oublié.
4. **Traefik en hostNetwork** sur le CP pour exposer 80/443 sans LoadBalancer cloud — alternative : `iptables` NAT 80→30080 / 443→30443.
5. **Migration MySQL → PostgreSQL** : syntaxe SQL (backticks, AUTO_INCREMENT, LIMIT x,y) à patcher dans le code de l'app.
6. **Images Docker** : ne pas pusher l'image de dev sur le tag `latest`, sinon prod = dev.
7. **Free Tier 12 mois** : vérifier la date d'ouverture du compte AWS, si proche de l'expiration les coûts vont monter.

---

## Workflow type d'une session de travail

1. `cd` dans le repo
2. `make start-all` (démarrer les EC2 si stoppées)
3. Bosser, itérer
4. Tester via les URLs `*.gestion-produits.local`
5. Commit + push (déclenche GitHub Actions)
6. `make stop-all` avant de fermer le laptop

---

## Comment Claude doit travailler

- **Toujours** lire ce fichier + `ROADMAP.md` avant de proposer une modification.
- **Toujours** invoquer la skill `superpowers:brainstorming` avant de coder une nouvelle feature non listée dans la roadmap.
- **Toujours** invoquer `superpowers:test-driven-development` ou `superpowers:writing-plans` selon le contexte.
- **Ne jamais** introduire un nouvel outil/service sans validation explicite (cf. décisions actées).
- **Toujours** mettre à jour `ROADMAP.md` quand une tâche est complétée.
- Commits petits, atomiques, message en français.
