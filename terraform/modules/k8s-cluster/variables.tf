variable "name" {
  description = "Prefix used to name all cluster resources (EC2, SG, EFS, etc.)."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the cluster lives."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet where the 3 EC2 nodes are deployed."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the VPC, used to allow intra-cluster traffic."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for all 3 nodes."
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of worker nodes (the cluster has 1 control plane + N workers)."
  type        = number
  default     = 2
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB for each node."
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "SSH public key authorized for the ubuntu user on all nodes."
  type        = string
}

variable "admin_ip_cidr" {
  description = "CIDR allowed to SSH and to reach 6443 (kube-api) from outside the VPC."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
