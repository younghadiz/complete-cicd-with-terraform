resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.deployment.key_name
  associate_public_ip_address = true

  user_data                   = file("${path.module}/scripts/bootstrap.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    encrypted             = true
    delete_on_termination = true
  }

  depends_on = [
    aws_route.internet,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.internet
  ]

  tags = {
    Name = "${var.project_name}-app"
  }
}
