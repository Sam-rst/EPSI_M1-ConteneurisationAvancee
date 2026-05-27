variable "aws_region" {
  description = "Région AWS cible."
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "Nom du profil AWS local (configuré via `aws configure --profile ...`)."
  type        = string
  default     = "tp-cont"
}

variable "availability_zone" {
  description = "Zone de disponibilité dans la région cible."
  type        = string
  default     = "eu-west-3a"
}

variable "name_prefix" {
  description = "Préfixe utilisé pour nommer toutes les ressources de l'env Docker."
  type        = string
  default     = "tp-cont-docker"
}

variable "instance_type" {
  description = "Type d'instance EC2 pour l'hôte Docker."
  type        = string
  default     = "t3.small"
}

variable "admin_ip_cidr" {
  description = "CIDR autorisé à se connecter en SSH. Mettre TON_IP/32. Voir https://api.ipify.org pour récupérer ton IP publique."
  type        = string
  # Pas de défaut : on force l'utilisateur à fournir une valeur explicite,
  # pour ne pas exposer SSH au monde entier par erreur.
}
