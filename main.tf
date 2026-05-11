# ============================================================
# MODULAR SINGLE-INSTANCE TERRAFORM
# Scenario: Web App — Monitored Single Instance (1k-5k)
# Tier: small | Users: 1000
# ============================================================
# Terraform limitation taught:
#   Local state is fine for learning. For production, use S3 backend.
#   This is a "Day 1" architecture; scaling requires ASG/ALB.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

module "security_group" {
  source = "./modules/security-groups"
  sg_name        = "${var.instance_name}-sg"
  sg_description = "SG for ${var.instance_name}"
  vpc_id         = var.vpc_id
  ingress_rules  = var.ingress_rules
  allow_all_egress = true
  tags = {
    Name = "${var.instance_name}-sg"
  }
}

module "ec2_instance" {
  source = "./modules/ec2-instance"
  ami_id               = data.aws_ami.amazon_linux_2.id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  security_group_ids   = [module.security_group.security_group_id]
  key_name             = var.key_name
  associate_public_ip  = true
  associate_eip        = false
  root_volume_size     = var.root_volume_size
  root_volume_type     = "gp3"
  cpu_credits          = "standard"
  log_retention_days   = 7
  user_data            = templatefile("${path.module}/user_data.sh", { install_monitoring = var.install_monitoring, instance_name = var.instance_name })
  instance_name        = var.instance_name
  iam_instance_profile_name = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : ""
  tags = {
    Environment = var.environment
  }
}

# Optional IAM role for SSM & CloudWatch
resource "aws_iam_role" "ec2_role" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.instance_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.instance_name}-profile"
  role  = aws_iam_role.ec2_role[0].name
}

output "public_ip" {
  value = module.ec2_instance.instance_public_ip
}

output "ssh_command" {
  value     = "ssh -i ${var.key_name}.pem ec2-user@${module.ec2_instance.instance_public_ip}"
  sensitive = true
}
