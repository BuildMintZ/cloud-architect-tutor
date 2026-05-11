resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = var.iam_instance_profile_name != "" ? var.iam_instance_profile_name : null
  associate_public_ip_address = var.associate_public_ip
  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    delete_on_termination = true
    encrypted = true
  }
  user_data = var.user_data
  credit_specification {
    cpu_credits = var.cpu_credits
  }
  lifecycle {
    ignore_changes = [ami, user_data]
  }
  tags = merge(var.tags, { Name = var.instance_name })
}

resource "aws_eip" "this" {
  count  = var.associate_eip ? 1 : 0
  domain = "vpc"
}

resource "aws_eip_association" "this" {
  count         = var.associate_eip ? 1 : 0
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this[0].id
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ec2/${var.instance_name}"
  retention_in_days = var.log_retention_days
}
