variable "aws_vpc_cidr_block" {
  default = "10.11.0.0/16"
}

variable "availability_zones" {
  default = ["a", "b"]
}

variable "aws_vpc_public_cidr_block" {
  default = ["10.11.1.0/24", "10.11.2.0/24"]
}

variable "aws_vpc_private_cidr_block" {
  default = ["10.11.3.0/24", "10.11.4.0/24"]
}

variable "glamorous_devops_app_image" {
}


