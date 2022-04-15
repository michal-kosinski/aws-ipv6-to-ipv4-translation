variable "common_name" {
  default = "mikosins-test"
}

variable "instance_type" {
  default = "t3.small"
}

variable "create_jumphost" {
  default = false
}

variable "create_ecs" {
  default = false
}

variable "create_eks" {
  default = true
}

variable "create_rds" {
  default = false
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      IaC  = "true"
      Name = var.common_name
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_key_pair" "test" {
  key_name   = var.common_name
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD6nv7LdXmMSfGouit9P+WlpBDvQ2Q4xhfbAie/o1pzjhIG5K+mlvAlxWU6h4bx7m0Ah64SNM2Bx93ZlsBXPYK2uzMk8J6ryZBcMzx97cWKXNljGueDbhEKeFtalsnqNoxASPGXNw4xPnjHFtbMp85OMvFPn8e+8CjREETuRivJ7Rke+Wrp8w5l7V1yJ5cIy59OiibgXI30UKCCqc02o++31aT6Kb4v977z3Aq88u1ucTwDdk/tJXwcM/70roOeibObGOyk3ujxYv9jXvsrtI2FE1AtFGuI1Zj944XD1bNS6AZbFN+4yhZeau02cFGtaPmcXOqX/w5UugeQQnBOAvBWowQ1zMx4j1BKfOjPo2OZZtmnowHY0atuWlkYm+ymKOKksThzv79kud6FKRKcXaQTAmdo/VkBvU7Kb0TsGWshfKJZbIpQTSt8PfSEIGri9mCN1hvkeSStj72FmYo9YhzqJZzDLzVVT9qX1XVwolKlnBKCUOFvOOkvlbbJd/D29fM= michal@michal-Z390"
}

data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

data "aws_lb_target_group" "test" {
  name = aws_lb.dualstack.name
}
