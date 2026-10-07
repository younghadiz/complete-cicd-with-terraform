resource "aws_key_pair" "deployment" {
  key_name   = "${var.project_name}-deployment"
  public_key = trimspace(var.ssh_public_key)
}

resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-"
  description = "Restricted access to the capstone application server"
  vpc_id      = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.ssh_allowed_cidrs

  security_group_id = aws_security_group.app.id
  description       = "SSH from an approved deployment or administration network"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "application" {
  for_each = var.app_allowed_cidrs

  security_group_id = aws_security_group.app.id
  description       = "Application access from an approved network"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound access for DNS, package installation and image pulls"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
