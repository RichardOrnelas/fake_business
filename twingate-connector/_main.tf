terraform {
  required_version = ">= 1.7.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30.0"
    }

    twingate = {
      source  = "Twingate/twingate"
      version = ">= 2.0.1"
    }
  }
}

variable "instance_type" {
  type        = string
  description = "or t3a.micro, or t3a.small"
  default     = "t3a.nano"
}

variable "one_per_subnet" {
  type        = bool
  default     = true
  description = "One host per subnet for redundancy, or put it wherever and have fewer"
}

variable "ha_additional_instance_types" {
  type    = list(string)
  default = []
}

variable "redundancy_factor" {
  type    = number
  default = 1
}

variable "use_spot_instances" {
  type    = bool
  default = true
}

variable "environment" {
  type = string
}

variable "override_network_name" {
  type    = string
  default = null
}

variable "vpc_id" {
  type = string
}

variable "status_emails_enabled" {
  type    = bool
  default = true
}

variable "twingate_network" {
  type        = string
  description = "name of the twingate network"
}

variable "twingate_token" {
  type        = string
  description = "twingate api token"
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "hosts" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Access"
    values = ["private"]
  }
}

# data "aws_secretsmanager_secret_version" "twingate" {
#   secret_id = "arn:aws:secretsmanager:us-west-2:393467788062:secret:terraform/twingate_api-Dvd03M"
# }

locals {

  subnet_ids_raw = sort(data.aws_subnets.hosts.ids)
  subnet_ids     = local.subnet_ids_raw

  # twingate_secret = jsondecode(data.aws_secretsmanager_secret_version.twingate.secret_string)
  twingate_network = var.twingate_network
  twingate_token   = var.twingate_token

  twingate_network_name = var.override_network_name == null ? "AWS ${title(var.environment)} - TF" : var.override_network_name

  vpc_cidr = data.aws_vpc.main.cidr_block
  common_tags = {
    Application = "twingate"
  }
}


data "aws_subnet" "main" {
  for_each = toset(local.subnet_ids)
  id       = each.key
}

locals {
  subnets_tmp = { for sid, obj in data.aws_subnet.main : obj.availability_zone => {
    name           = "twingate-${obj.availability_zone}"
    connector_name = "aws-${var.environment}-${obj.availability_zone}"
    subnet_ids     = [sid]
  } }

  subnets = var.one_per_subnet ? local.subnets_tmp : {
    "all" = {
      name           = "twingate"
      connector_name = "aws-${var.environment}"
      subnet_ids     = local.subnet_ids
    }
  }

}

provider "twingate" {
  api_token = local.twingate_token
  network   = local.twingate_network
}

output "twingate_security_group" {
  value = aws_security_group.twingate.id
}

output "twingate_remote_network_id" {
  value = twingate_remote_network.aws_network.id
}
