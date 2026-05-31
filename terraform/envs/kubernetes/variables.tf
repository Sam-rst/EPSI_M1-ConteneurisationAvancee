variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-3"
}

variable "aws_profile" {
  description = "Local AWS profile."
  type        = string
  default     = "tp-cont"
}

variable "availability_zone" {
  description = "AZ for the cluster subnet."
  type        = string
  default     = "eu-west-3a"
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "tp-cont-k8s"
}

variable "instance_type" {
  description = "EC2 instance type for cluster nodes."
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of worker nodes (total = 1 CP + N workers)."
  type        = number
  default     = 2
}

variable "admin_ip_cidr" {
  description = "Your public IP in /32 (allowed for SSH and kube-api)."
  type        = string
}
