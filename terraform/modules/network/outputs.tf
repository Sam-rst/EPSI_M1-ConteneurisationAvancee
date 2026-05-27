output "vpc_id" {
  description = "Identifiant du VPC créé."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Plage CIDR du VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  description = "Identifiant du subnet public."
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "Plage CIDR du subnet public."
  value       = aws_subnet.public.cidr_block
}

output "internet_gateway_id" {
  description = "Identifiant de l'Internet Gateway."
  value       = aws_internet_gateway.this.id
}
