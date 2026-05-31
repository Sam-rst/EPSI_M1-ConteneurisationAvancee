# =============================================================================
# Module docker-host — EC2 Ubuntu + Docker Engine
# =============================================================================
# Provisionne :
#   - 1 instance EC2 Ubuntu 24.04 LTS (AMI Canonical officielle, dernière)
#   - 1 Elastic IP attachée à l'instance
#   - 1 Security Group exposant 80, 443 publiquement et 22 depuis admin_ip_cidr
#   - 1 Key Pair AWS à partir de la clé publique fournie
#   - Cloud-init qui installe Docker Engine + Compose v2
#
# La stack applicative (Traefik + app + DB) sera déployée plus tard
# en J3 (docker compose sur cette instance).
# =============================================================================

# AMI Ubuntu 24.04 LTS officielle Canonical (compte AWS 099720109477) ---------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key pair AWS dérivée de la clé publique fournie en variable -----------------
resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key

  tags = merge(var.tags, {
    Name = "${var.name}-key"
  })
}

# Security Group : 80/443 public + 22 restreint --------------------------------
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security for Docker host - 80/443 public, SSH restricted"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  description       = "SSH from admin IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_ip_cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All egress allowed"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Instance EC2 ----------------------------------------------------------------
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = aws_key_pair.this.key_name

  user_data                   = templatefile("${path.module}/cloud-init.yaml.tftpl", {})
  user_data_replace_on_change = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true

    tags = merge(var.tags, {
      Name = "${var.name}-root"
    })
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 obligatoire (bonne pratique sécurité)
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.name}"
    Role = "docker-host"
  })
}

# Elastic IP statique attachée à l'instance ------------------------------------
resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-eip"
  })

  # On veut éviter de perdre l'EIP par mégarde : Terraform refusera un destroy
  # tant qu'on n'aura pas explicitement retiré ce lifecycle.
  lifecycle {
    prevent_destroy = false # mis à true plus tard quand l'EIP sera "officielle"
  }
}
