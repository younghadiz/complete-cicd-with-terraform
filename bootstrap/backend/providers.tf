provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project   = "complete-cicd-with-terraform"
      Component = "TerraformState"
      ManagedBy = "Terraform"
      Owner     = "Gafari"
    }
  }
}
