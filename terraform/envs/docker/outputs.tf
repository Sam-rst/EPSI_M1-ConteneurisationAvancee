output "public_ip" {
  description = "Elastic IP publique de l'hôte Docker (à ajouter dans /etc/hosts)."
  value       = module.docker_host.public_ip
}

output "instance_id" {
  description = "Identifiant EC2 de l'hôte Docker."
  value       = module.docker_host.instance_id
}

output "ssh_private_key_path" {
  description = "Chemin local de la clé privée SSH générée (relatif au répertoire terraform/envs/docker)."
  value       = local_sensitive_file.ssh_private_key.filename
}

output "ssh_command" {
  description = "Commande SSH prête à l'emploi pour se connecter à l'hôte Docker."
  value       = "ssh -i ${local_sensitive_file.ssh_private_key.filename} ubuntu@${module.docker_host.public_ip}"
}

output "hosts_entry" {
  description = "Ligne à ajouter au fichier /etc/hosts du correcteur pour accéder à l'app."
  value       = "${module.docker_host.public_ip}  gestion-produits.local  dev.gestion-produits.local"
}
