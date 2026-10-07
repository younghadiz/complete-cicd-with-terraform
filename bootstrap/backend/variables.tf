variable "aws_region" {
  description = "Region for the Terraform state bucket."
  type        = string
  default     = "ca-central-1"
}

variable "expected_account_id" {
  description = "Account permitted to manage the state bucket."
  type        = string
  default     = "002184382122"
}

variable "state_bucket_name" {
  description = "Globally unique bucket name matching the application backend configuration."
  type        = string
  default     = "gafari-tf-cicd-002184382122-ca-central-1"
}
