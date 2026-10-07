aws_region          = "ca-central-1"
expected_account_id = "002184382122"
project_name        = "complete-cicd-with-terraform"

# Verify an Amazon Linux 2023 x86-64 AMI in the selected region.
ami_id        = "ami-0bf6dbeae330f5823"
instance_type = "t3.micro"

# Replace with your deployment public key.
ssh_public_key = "ssh-ed25519 REPLACE_WITH_PUBLIC_KEY"

# Add the Jenkins public IP and approved administration IP as /32 CIDRs.
ssh_allowed_cidrs = []

# Add approved application-testing IPs as /32 CIDRs.
app_allowed_cidrs = []
