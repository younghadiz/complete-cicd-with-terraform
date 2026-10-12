variable "aws_region" {
  description = "AWS region for the capstone infrastructure."
  type        = string
  default     = "ca-central-1"
}

variable "expected_account_id" {
  description = "AWS account in which provisioning is permitted."
  type        = string
  default     = "002184382122"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must contain exactly 12 digits."
  }
}

variable "project_name" {
  description = "Project prefix used for resource names and tags."
  type        = string
  default     = "complete-cicd-with-terraform"
}
