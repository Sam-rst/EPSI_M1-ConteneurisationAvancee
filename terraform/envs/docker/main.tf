# =============================================================================
# Env docker — orchestre les modules network + docker-host
# =============================================================================
# Provisionne :
#   - 1 paire SSH générée localement par Terraform (clé privée sauvée dans
#     ../.ssh/<name>.pem, gitignored)
#   - 1 VPC + subnet public + IGW (via module network)
#   - 1 EC2 Ubuntu 24.04 + Docker (via module docker-host)
# =============================================================================

# Génération d'une paire SSH dédiée au projet -----------------------------------
# Avantages :
#   - Reproductible (pas besoin que l'utilisateur ait une clé prête)
#   - Isolée du reste des clés de la machine
#   - Détruite en même temps que l'infra (`terraform destroy`)
#
# La clé privée est écrite dans terraform/.ssh/<name>.pem (gitignored).
# Permissions correctement positionnées (0600) pour que ssh ne râle pas.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.module}/../../.ssh/${var.name_prefix}.pem"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  filename        = "${path.module}/../../.ssh/${var.name_prefix}.pub"
  content         = tls_private_key.ssh.public_key_openssh
  file_permission = "0644"
}

# Réseau ------------------------------------------------------------------------
module "network" {
  source = "../../modules/network"

  name              = var.name_prefix
  availability_zone = var.availability_zone
}

# Hôte Docker -------------------------------------------------------------------
module "docker_host" {
  source = "../../modules/docker-host"

  name           = var.name_prefix
  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.public_subnet_id
  instance_type  = var.instance_type
  ssh_public_key = trimspace(tls_private_key.ssh.public_key_openssh)
  admin_ip_cidr  = var.admin_ip_cidr
}
