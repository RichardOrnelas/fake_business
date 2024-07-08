module "twingate" {
  source           = "./modules/twingate-connector"
  vpc_id           = aws_vpc.primary.id
  environment      = terraform.workspace
  twingate_network = "fakebusiness1"
  twingate_token   = var.twingate_token

  one_per_subnet     = false
  use_spot_instances = true
}

resource "twingate_resource" "vpc" {
  name              = "${title(terraform.workspace)} VPC"
  remote_network_id = module.twingate.twingate_remote_network_id
  address           = aws_vpc.primary.cidr_block
  is_authoritative  = false

  access_group {
    group_id = "12340982039480129834012"
  }
}

locals {
  # Should give us the brokers in a list with no port
  kafka_brokers = split(",", replace(data.aws_msk_bootstrap_brokers.kafka_brokers.bootstrap_brokers_sasl_iam, ":9098", ""))
}

resource "twingate_resource" "app" {
  name                        = "${title(terraform.workspace)} Web App"
  remote_network_id           = module.twingate.twingate_remote_network_id
  address                     = "app.${terraform.workspace}.fakebusiness.com"
  is_browser_shortcut_enabled = true
  is_authoritative            = false

  access_group {
    group_id = "12340982039480129834012"
  }
}

resource "twingate_resource" "api" {
  name              = "${title(terraform.workspace)} Backend API"
  remote_network_id = module.twingate.twingate_remote_network_id
  address           = "api.${terraform.workspace}.fakebusiness.com"
  is_authoritative  = false

  access_group {
    group_id = "12340982039480129834012"
  }
}

resource "twingate_resource" "site" {
  name                        = "${title(terraform.workspace)} Marketing Site"
  remote_network_id           = module.twingate.twingate_remote_network_id
  address                     = "site.${terraform.workspace}.fakebusiness.com"
  is_browser_shortcut_enabled = true
  is_authoritative            = false

  access_group {
    group_id = "12340982039480129834012"
  }
}

resource "twingate_resource" "conduktor" {
  name              = "${title(terraform.workspace)} Conduktor"
  remote_network_id = module.twingate.twingate_remote_network_id
  address           = "conduktor.${local.domain}"
  is_authoritative  = false

  access_group {
    group_id = "12340982039480129834012"
  }
}

resource "twingate_resource" "kafka_broker" {
  depends_on        = [local.kafka_brokers, data.aws_msk_bootstrap_brokers.kafka_brokers, aws_msk_cluster.main]
  count             = 2
  name              = "${title(terraform.workspace)} Kafka Broker #${count.index}"
  remote_network_id = module.twingate.twingate_remote_network_id
  address           = element(local.kafka_brokers, count.index)
  is_authoritative  = false

  access_group {
    group_id = "12340982039480129834012"
  }
}
