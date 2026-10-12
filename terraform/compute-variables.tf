variable "ami_id" {
  description = "Explicit Amazon Linux 2023 x86-64 AMI ID in the selected region."
  type        = string

  validation {
    condition     = can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "Provide a valid EC2 AMI ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the demonstration application."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Choose t3.micro or t3.small for this capstone."
  }
}
