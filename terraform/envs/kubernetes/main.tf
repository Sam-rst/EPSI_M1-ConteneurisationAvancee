# =============================================================================
# Env Kubernetes - 1 reseau + 3 EC2 + EFS
# =============================================================================

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

# Reseau dedie au cluster K8s (isole de l'infra Docker)
module "network" {
  source = "../../modules/network"

  name               = var.name_prefix
  vpc_cidr           = "10.10.0.0/16"
  public_subnet_cidr = "10.10.1.0/24"
  availability_zone  = var.availability_zone
}

# Cluster
module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  name           = var.name_prefix
  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.public_subnet_id
  vpc_cidr       = module.network.vpc_cidr
  instance_type  = var.instance_type
  worker_count   = var.worker_count
  ssh_public_key = trimspace(tls_private_key.ssh.public_key_openssh)
  admin_ip_cidr  = var.admin_ip_cidr
}
