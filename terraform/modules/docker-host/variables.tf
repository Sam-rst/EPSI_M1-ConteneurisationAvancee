variable "name" {
  description = "Préfixe utilisé pour nommer les ressources (instance, EIP, SG, key pair)."
  type        = string
}

variable "vpc_id" {
  description = "Identifiant du VPC dans lequel déployer l'instance."
  type        = string
}

variable "subnet_id" {
  description = "Identifiant du subnet (public) où placer l'instance."
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size_gb" {
  description = "Taille du volume racine EBS en Go."
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "Clé publique SSH à autoriser pour l'utilisateur ubuntu."
  type        = string
}

variable "admin_ip_cidr" {
  description = "CIDR autorisé à se connecter en SSH sur l'instance. Recommandé : ton IP publique en /32. Le défaut 0.0.0.0/0 est non sécurisé et ne doit servir qu'en debug temporaire."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources créées par le module."
  type        = map(string)
  default     = {}
}
