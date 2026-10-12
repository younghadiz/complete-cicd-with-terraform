output "instance_id" {
  description = "Managed application EC2 instance ID."
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Application server address for SSH deployment."
  value       = aws_instance.app.public_ip
}

output "ssh_user" {
  description = "SSH username for the Amazon Linux application server."
  value       = "ec2-user"
}

output "deployment_key_name" {
  description = "Registered EC2 deployment key name."
  value       = aws_key_pair.deployment.key_name
}

output "application_url" {
  description = "Application URL, accessible from approved networks after deployment."
  value       = "http://${aws_instance.app.public_ip}:8080"
}
