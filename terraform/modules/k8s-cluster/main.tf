# =============================================================================
# Module k8s-cluster - 3 EC2 + EFS pour stockage partage
# =============================================================================
# Provisionne :
#   - 1 EC2 control plane (avec EIP attachee)
#   - N EC2 workers (par defaut 2, total 3 nodes comme demande par le sujet)
#   - 1 EFS file system + mount target dans le subnet du cluster
#   - 1 Key Pair AWS
#   - 1 Security Group cluster avec :
#       * SSH 22 depuis admin_ip_cidr
#       * HTTP 80 + HTTPS 443 depuis 0.0.0.0/0 (vers Traefik Ingress sur CP)
#       * Inter-node libre (depuis le SG lui-meme)
#       * NodePort range 30000-32767 ouvert au public (en backup)
#   - 1 Security Group EFS qui autorise NFS 2049 depuis le SG cluster
#
# Le bootstrap kubeadm (init/join, Calico, EFS CSI driver) est fait par le
# script k8s/scripts/bootstrap.sh apres terraform apply.
# =============================================================================

# AMI Ubuntu 24.04 LTS Canonical -----------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Key pair AWS ----------------------------------------------------------------
resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key

  tags = merge(var.tags, { Name = "${var.name}-key" })
}

# Security Group pour les nodes K8s -------------------------------------------
resource "aws_security_group" "cluster" {
  name        = "${var.name}-sg"
  description = "Security group for kubeadm cluster nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

# SSH depuis admin
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.cluster.id
  description       = "SSH from admin IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_ip_cidr
}

# kube-api depuis admin (pour utiliser kubectl en local si besoin)
resource "aws_vpc_security_group_ingress_rule" "kube_api_admin" {
  security_group_id = aws_security_group.cluster.id
  description       = "kube-api from admin IP"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = var.admin_ip_cidr
}

# HTTP/HTTPS public (vers Traefik Ingress sur le CP via hostNetwork ou NodePort)
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.cluster.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.cluster.id
  description       = "HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# NodePort range (utile en fallback pour exposer Traefik)
resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  security_group_id = aws_security_group.cluster.id
  description       = "NodePort range"
  ip_protocol       = "tcp"
  from_port         = 30000
  to_port           = 32767
  cidr_ipv4         = "0.0.0.0/0"
}

# Trafic intra-cluster (tous protocoles)
resource "aws_vpc_security_group_ingress_rule" "intra_cluster" {
  security_group_id            = aws_security_group.cluster.id
  description                  = "All traffic between cluster nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.cluster.id
}

# Egress libre
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.cluster.id
  description       = "All egress allowed"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Security Group pour EFS -----------------------------------------------------
resource "aws_security_group" "efs" {
  name        = "${var.name}-efs-sg"
  description = "Security group for EFS (NFS 2049 from cluster nodes only)"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-efs-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from cluster nodes"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.cluster.id
}

resource "aws_vpc_security_group_egress_rule" "efs_egress" {
  security_group_id = aws_security_group.efs.id
  description       = "All egress allowed"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# EFS file system + mount target ----------------------------------------------
resource "aws_efs_file_system" "this" {
  creation_token   = "${var.name}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, { Name = "${var.name}-efs" })
}

resource "aws_efs_mount_target" "this" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.efs.id]
}

# Control plane node ----------------------------------------------------------
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cluster.id]
  key_name               = aws_key_pair.this.key_name

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    role = "control-plane"
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, { Name = "${var.name}-cp-root" })
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-cp"
    Role = "control-plane"
  })
}

# Workers ---------------------------------------------------------------------
resource "aws_instance" "workers" {
  count = var.worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cluster.id]
  key_name               = aws_key_pair.this.key_name

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    role = "worker"
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, { Name = "${var.name}-w${count.index + 1}-root" })
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-w${count.index + 1}"
    Role = "worker"
  })
}

# Elastic IP sur le control plane ---------------------------------------------
resource "aws_eip" "control_plane" {
  instance = aws_instance.control_plane.id
  domain   = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-cp-eip" })
}
