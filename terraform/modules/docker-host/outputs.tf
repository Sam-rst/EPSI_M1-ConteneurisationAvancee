output "instance_id" {
  description = "Identifiant EC2 de l'hôte Docker."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP publique attachée à l'hôte Docker."
  value       = aws_eip.this.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance dans le VPC."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Identifiant du Security Group."
  value       = aws_security_group.this.id
}

output "ssh_command" {
  description = "Commande SSH prête à l'emploi (à utiliser depuis la machine admin)."
  value       = "ssh ubuntu@${aws_eip.this.public_ip}"
}

output "ami_id" {
  description = "AMI Ubuntu utilisée."
  value       = data.aws_ami.ubuntu.id
}
