output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.main[*].id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host (SSH entry point)"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "app_private_ip" {
  description = "Private IP of the app instance (only reachable via the bastion)"
  value       = var.enable_bastion ? aws_instance.app[0].private_ip : null
}

output "ssh_to_bastion" {
  description = "Command to SSH into the bastion"
  value       = var.enable_bastion ? "ssh -A -i ${var.key_pair_name}.pem ec2-user@${aws_instance.bastion[0].public_ip}" : null
}

output "ssh_to_app_from_bastion" {
  description = "Command to run from inside the bastion to reach the private app instance"
  value       = var.enable_bastion ? "ssh ec2-user@${aws_instance.app[0].private_ip}" : null
}
