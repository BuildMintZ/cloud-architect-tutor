variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type      = string
  sensitive = true
}

variable "iam_instance_profile_name" {
  type    = string
  default = ""
}

variable "associate_public_ip" {
  type    = bool
  default = true
}

variable "associate_eip" {
  type    = bool
  default = false
}

variable "root_volume_type" {
  type    = string
  default = "gp3"
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "cpu_credits" {
  type    = string
  default = "standard"
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "user_data" {
  type    = string
  default = ""
}

variable "instance_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
