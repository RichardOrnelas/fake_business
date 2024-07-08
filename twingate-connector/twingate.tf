resource "twingate_remote_network" "aws_network" {
  name     = local.twingate_network_name
  location = "AWS"
}

resource "twingate_connector" "main" {
  for_each = local.subnets

  name                   = each.value.connector_name
  remote_network_id      = twingate_remote_network.aws_network.id
  status_updates_enabled = var.status_emails_enabled
}

resource "twingate_connector_tokens" "main" {
  for_each = local.subnets

  connector_id = twingate_connector.main[each.key].id
  keepers = {
    token = local.twingate_token
  }
}


