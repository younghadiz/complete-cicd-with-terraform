variable "ssh_public_key" {
  description = "OpenSSH public key for Jenkins deployment access."
  type        = string

  validation {
    condition     = can(regex("^ssh-ed25519 ", trimspace(var.ssh_public_key)))
    error_message = "Provide the project's OpenSSH ED25519 public key."
  }
}

variable "ssh_allowed_cidrs" {
  description = "IPv4 CIDRs permitted to connect over SSH."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidrs :
      can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
    ])
    error_message = "Provide valid IPv4 CIDRs; unrestricted SSH is not permitted."
  }
}

variable "app_allowed_cidrs" {
  description = "IPv4 CIDRs permitted to access the application on port 8080."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.app_allowed_cidrs :
      can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
    ])
    error_message = "Provide valid, restricted IPv4 CIDRs for application access."
  }
}
