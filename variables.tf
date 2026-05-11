variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  type    = string
  default = "learning"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "instance_name" {
  type    = string
  default = "app-ec2"
}

variable "root_volume_size" {
  type    = number
  default = 50
}

variable "vpc_id" {
  type    = string
  default = "vpc-23564"
}

variable "subnet_id" {
  type    = string
  default = "subnet-46588"
}

variable "key_name" {
  type      = string
  default   = "terraform-learning-key"
  sensitive = true
}

variable "ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Port 22"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Port 80"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Port 443"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Port 3000"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Port 9090"
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "install_monitoring" {
  type    = bool
  default = true
}

variable "create_iam_role" {
  type    = bool
  default = true
}
