output "state_bucket_name" {
  description = "Bucket used by the application Terraform backend."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_region" {
  description = "Region used in the application backend configuration."
  value       = var.aws_region
}
