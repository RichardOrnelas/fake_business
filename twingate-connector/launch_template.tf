resource "aws_launch_template" "main" {
  for_each = local.subnets

  name          = each.value.name
  image_id      = data.aws_ami.twingate.image_id
  instance_type = var.instance_type

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  vpc_security_group_ids = [aws_security_group.twingate.id]

  dynamic "tag_specifications" {
    for_each = ["instance", "network-interface", "volume"]

    content {
      resource_type = tag_specifications.value

      tags = merge(local.common_tags, {
        Name = each.value.name
      })
    }
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    network       = local.twingate_network
    access_token  = twingate_connector_tokens.main[each.key].access_token
    refresh_token = twingate_connector_tokens.main[each.key].refresh_token
  }))

  tags = local.common_tags
}
