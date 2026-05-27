# Origine du code applicatif

Le code de l'application **Gestion de produits** présent dans ce dossier provient du dépôt fourni par Avalone dans le cadre du TP EPSI M1 DEV.

## Source

| Champ | Valeur |
|---|---|
| Auteur original | Anthony (Avalone) |
| Dépôt upstream | <https://gl.avalone-fr.com/anthony/gestion-produits> |
| Commit de référence (import initial) | `c78efa48e39988123ded212f63b88d8f31e238af` |
| Date du commit | 2026-05-06 20:58:20 +0200 |
| Message | « Ajout de photos manquantes » |
| Date d'import dans ce dépôt | 2026-05-27 |

## Modalité d'import

Le contenu a été **importé sans le dossier `.git`** du dépôt upstream. Aucun remote upstream n'est configuré sur ce dépôt mono-repo.

Pour récupérer manuellement des changements futurs d'Avalone, cloner le dépôt upstream à part et copier les modifications souhaitées :

```bash
git clone https://gl.avalone-fr.com/anthony/gestion-produits /tmp/upstream
# diff puis report manuel des changements voulus dans app/
```

## Structure importée

| Chemin | Contenu |
|---|---|
| `app/php/www/` | Sources PHP (PDO MySQL) + assets statiques + dossier `uploads/` |
| `app/database/gestion_produits.sql` | Schéma + jeu d'essai MySQL |
| `app/README.upstream.md` | README original d'Avalone (déplacé pour ne pas écraser le README projet) |

## Compatibilité

- PHP 8.x
- MySQL 8.4 (ou MariaDB compatible)
- Login par défaut du jeu d'essai : `admin` / `password`

## Modifications prévues par rapport à l'upstream

Pour les besoins de la conteneurisation et du déploiement, les modifications suivantes seront apportées (cf. commits suivants) :

- Paramétrage de la connexion DB par variables d'environnement (au lieu de credentials en dur)
- Ajout d'un `Dockerfile` et d'un `compose.dev.yml`
- Permissions sur `uploads/` gérées au build de l'image
- Sur la **branche `dev`** : portage du DSN PDO vers PostgreSQL + adaptation des éventuelles requêtes incompatibles
