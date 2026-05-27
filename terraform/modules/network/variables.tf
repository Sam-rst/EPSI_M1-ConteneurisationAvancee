variable "name" {
  description = "Préfixe utilisé pour nommer toutes les ressources réseau (VPC, subnet, IGW, etc.)."
  type        = string
}

variable "vpc_cidr" {
  description = "Plage d'adresses CIDR du VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Plage CIDR du subnet public dans lequel sont déployées les instances exposées sur Internet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Zone de disponibilité du subnet public. Doit être dans la région du provider."
  type        = string
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources créées par le module."
  type        = map(string)
  default     = {}
}
