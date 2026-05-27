# infra-tp-cont — TP IaC + Conteneurisation avancée

> EPSI M1 DEV — Samuel Ressiot
> Deadline : **dimanche 31 mai 2026 à minuit**

Déploiement automatisé sur AWS de l'application [gestion-produits](https://gl.avalone-fr.com/anthony/gestion-produits) sur deux infrastructures parallèles :

- **Infra Docker** : 1 EC2 avec Traefik comme reverse proxy
- **Cluster Kubernetes** : 3 EC2 (kubeadm) avec EFS comme stockage partagé

Chaque infra héberge **deux versions** de l'application :
- **prod** (MySQL/MariaDB)
- **dev** (PostgreSQL)

Le tout est provisionné par **Terraform**, déployé par **GitHub Actions**, et exposé en HTTPS sur les ports 80/443 via `/etc/hosts` (cf. `docs/07-evaluation-guide.md`).

---

## Documents à lire dans l'ordre

| Fichier | Contenu |
|---|---|
| [`SUBJECT.md`](./SUBJECT.md) | Reformulation détaillée du sujet et grille de notation |
| [`CLAUDE.md`](./CLAUDE.md) | Décisions techniques, architecture, conventions |
| [`ROADMAP.md`](./ROADMAP.md) | Avancement par jalons (J0 → J9) |
| `docs/` | Documentation technique détaillée (à venir) |

---

## Statut

🟦 **Jalon en cours : J1 — Conteneurisation de l'application**

Voir [`ROADMAP.md`](./ROADMAP.md) pour le détail.
