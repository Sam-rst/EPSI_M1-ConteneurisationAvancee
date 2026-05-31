output "control_plane_public_ip" {
  description = "Elastic IP of the control plane."
  value       = module.k8s_cluster.control_plane_public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane (used by workers for kubeadm join)."
  value       = module.k8s_cluster.control_plane_private_ip
}

output "worker_public_ips" {
  description = "Public IPs of the workers."
  value       = module.k8s_cluster.worker_public_ips
}

output "worker_private_ips" {
  description = "Private IPs of the workers."
  value       = module.k8s_cluster.worker_private_ips
}

output "efs_file_system_id" {
  description = "EFS file system ID (set in k8s EFS CSI storage class)."
  value       = module.k8s_cluster.efs_file_system_id
}

output "ssh_private_key_path" {
  description = "Path to the cluster SSH private key."
  value       = local_sensitive_file.ssh_private_key.filename
}

output "ssh_command_cp" {
  description = "Ready-to-use SSH command for the control plane."
  value       = "ssh -i ${local_sensitive_file.ssh_private_key.filename} ubuntu@${module.k8s_cluster.control_plane_public_ip}"
}

output "hosts_entry" {
  description = "Line to add to /etc/hosts to reach the K8s ingress."
  value       = "${module.k8s_cluster.control_plane_public_ip}  k8s.gestion-produits.local  dev.k8s.gestion-produits.local"
}
