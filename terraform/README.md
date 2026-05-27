# Terraform — Infrastructure du TP

> Provisionne sur AWS les deux infrastructures du TP :
> - `envs/docker/`     → 1 EC2 hôte Docker (J2 / J3)
> - `envs/kubernetes/` → 3 EC2 cluster Kubernetes + EFS (J4 / J5)

---

## Structure

```
terraform/
├── modules/
│   ├── network/         # VPC + subnet public + IGW + route table (réutilisable)
│   ├── docker-host/     # EC2 Ubuntu + Docker installé via cloud-init + EIP
│   └── k8s-cluster/     # (J4) 3 EC2 + kubeadm + EFS
├── envs/
│   ├── docker/          # Compose des modules pour l'infra Docker
│   └── kubernetes/      # (J4) Compose des modules pour l'infra K8s
└── .ssh/                # Clés SSH générées par Terraform (gitignored)
```

Chaque environnement gère son propre `terraform.tfstate` local et peut être
provisionné / détruit indépendamment.

---

## Pré-requis (à faire une fois)

### 1. Outils

- Terraform ≥ 1.9
- AWS CLI v2
- (Optionnel) un client SSH

### 2. Compte AWS

Créer un utilisateur IAM dédié au projet :

1. Console AWS → IAM → Users → **Create user**
2. Nom : `terraform-tp-cont`
3. Permissions : **Attach policies directly** → `AdministratorAccess`
   *(acceptable pour un TP étudiant ; à filtrer en prod)*
4. Onglet **Security credentials** → **Create access key** → use case **CLI**
5. Récupérer les deux clés (la `Secret access key` n'est affichée qu'une fois)

### 3. Profil AWS local

```bash
aws configure --profile tp-cont
# AWS Access Key ID:     <colle ton access key>
# AWS Secret Access Key: <colle ton secret>
# Default region name:   eu-west-3
# Default output format: json

# Vérifier :
aws sts get-caller-identity --profile tp-cont
```

### 4. Alerte budget (fortement recommandé)

Console AWS → Billing → Budgets → **Create budget**
- Type : Cost budget
- Period : Monthly
- Amount : **20 €** (warn) — alerte par mail si dépassement.

---

## Usage — env Docker

```bash
cd terraform/envs/docker

# 1. Copier l'exemple et adapter les valeurs (notamment admin_ip_cidr)
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 2. Récupérer ton IP publique pour le SSH :
curl https://api.ipify.org

# 3. Initialiser
terraform init

# 4. Plan
terraform plan -out=tfplan

# 5. Apply
terraform apply tfplan

# 6. Récupérer les outputs (IP publique, commande SSH, ligne /etc/hosts)
terraform output

# Pour se connecter à l'instance :
$(terraform output -raw ssh_command)

# Pour tout détruire (et arrêter de payer) :
terraform destroy
```

---

## Bonnes pratiques

- ⚠️ **Toujours `terraform plan` avant `terraform apply`** : on ne touche pas
  l'infra sans avoir lu ce que Terraform va faire.
- ⚠️ **Ne jamais committer** :
  - `*.tfstate` / `*.tfstate.backup` (contient des secrets)
  - `terraform.tfvars` (contient l'IP admin)
  - `.ssh/*.pem` (clé privée)
  - `.terraform/` (cache + providers téléchargés)
- 💰 **`terraform destroy`** dès que tu n'as plus besoin de l'instance
  (cf. CLAUDE.md, stratégie budget).
- 🔁 **Idempotence** : un `terraform apply` après un autre `terraform apply` ne
  doit rien changer. Tester régulièrement `destroy` puis `apply` pour valider.
