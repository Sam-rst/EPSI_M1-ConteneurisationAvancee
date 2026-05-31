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

🟦 **Jalon en cours : J6 — Version dev PostgreSQL**

- ✅ J1 — image Docker validée en local
- ✅ J2 — infra Docker en ligne sur AWS, EIP **`13.36.147.208`**
- ✅ J3 — stack prod Docker : `https://gestion-produits.local` OK (auth + produits)
- ✅ J4 — cluster K8s **k3s** 3 nodes Ready, EIP CP **`13.36.198.45`**
- ✅ J5 — app prod K8s : `https://k8s.gestion-produits.local` OK (auth + produits)

Voir [`ROADMAP.md`](./ROADMAP.md) pour le détail.
