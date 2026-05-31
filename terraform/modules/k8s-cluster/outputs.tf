output "control_plane_id" {
  description = "EC2 instance ID of the control plane."
  value       = aws_instance.control_plane.id
}

output "control_plane_public_ip" {
  description = "Elastic IP of the control plane (used as the cluster ingress IP)."
  value       = aws_eip.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane inside the VPC."
  value       = aws_instance.control_plane.private_ip
}

output "worker_ids" {
  description = "EC2 instance IDs of all workers."
  value       = aws_instance.workers[*].id
}

output "worker_public_ips" {
  description = "Auto-assigned public IPs of the workers."
  value       = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of the workers (used for kubeadm join)."
  value       = aws_instance.workers[*].private_ip
}

output "cluster_security_group_id" {
  description = "Security group ID attached to all cluster nodes."
  value       = aws_security_group.cluster.id
}

output "efs_file_system_id" {
  description = "EFS file system ID (referenced by the CSI driver storage class)."
  value       = aws_efs_file_system.this.id
}

output "efs_dns_name" {
  description = "EFS DNS name."
  value       = aws_efs_file_system.this.dns_name
}

output "efs_mount_target_id" {
  description = "EFS mount target in the cluster subnet."
  value       = aws_efs_mount_target.this.id
}
