# Stack Docker prod

Stack déployée sur l'EC2 AWS (cf. `terraform/envs/docker`) pour héberger
l'application en prod.

## Composition

| Service | Image | Rôle |
|---|---|---|
| `traefik` | `traefik:v3.2` | Reverse proxy, terminaison TLS auto-signé, redirection HTTP→HTTPS, écoute 80/443 |
| `app-prod` | `samrst/gestion-produits:prod` (buildée localement) | Application PHP+Apache, version branche `main`, PDO MySQL |
| `db-mysql` | `mysql:8.4` | Base de données prod, schéma initialisé par le dump Avalone |

Plus tard (J6) : ajout de `app-dev` + `db-postgres` pour la version dev PostgreSQL.

## Structure du dossier

```
docker/
├── compose.yml              # Stack principale
├── .env.example             # Variables d'env attendues (gitignored : .env)
├── README.md
├── traefik/
│   ├── dynamic/             # Config Traefik dynamique (TLS)
│   │   └── tls.yml
│   └── certs/               # Certifs auto-signés (générés, gitignored)
├── init/
│   └── mysql/               # Dump SQL chargé au premier boot (copié depuis app/database)
└── scripts/
    ├── gen-certs.sh         # Génère le certif TLS auto-signé pour gestion-produits.local
    └── deploy.sh            # Pousse le code sur l'EC2 et lance la stack
```

## Déploiement

Pré-requis : `terraform/envs/docker/` déjà `apply`, EC2 en ligne, clé SSH générée.

```bash
# Depuis la racine du repo :
./docker/scripts/deploy.sh
```

Le script :
1. Récupère l'EIP via `terraform output`
2. Synchronise `app/` et `docker/` sur l'EC2 via `rsync`
3. Génère `.env` (mots de passe MySQL aléatoires) si absent
4. Génère le certif TLS auto-signé si absent
5. Lance `docker compose up -d --build`
6. Teste l'URL en HTTPS

## URLs exposées

| URL | Service | Branche |
|---|---|---|
| `https://gestion-produits.local` | `app-prod` | `main` (MySQL) |
| `https://dev.gestion-produits.local` | `app-dev` (J6) | `dev` (PostgreSQL) |

Pour accéder depuis ton navigateur, ajoute à ton `/etc/hosts` :
```
<EIP>  gestion-produits.local  dev.gestion-produits.local
```
(L'EIP est affichée par `terraform output public_ip`.)

## Mise à jour de l'app

Après modification du code dans `app/` :
```bash
./docker/scripts/deploy.sh
```
Le `rsync` envoie le delta, `docker compose up --build` reconstruit l'image et redémarre `app-prod` sans toucher à la DB.

## Téléchargement des logs

```bash
# Sur l'EC2 :
ssh -i terraform/.ssh/tp-cont-docker.pem ubuntu@<EIP>
cd ~/tp-cont/docker
docker compose logs -f traefik
docker compose logs -f app-prod
docker compose logs -f db-mysql
```

## Tear-down

```bash
ssh ubuntu@<EIP> 'cd ~/tp-cont/docker && docker compose down -v'
```

Pour détruire aussi l'EC2 :
```bash
cd terraform/envs/docker
terraform destroy
```
