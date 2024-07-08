resource "aws_autoscaling_group" "main" {
  for_each = local.subnets

  name                = each.value.name
  max_size            = var.redundancy_factor
  min_size            = var.redundancy_factor
  desired_capacity    = var.redundancy_factor
  health_check_type   = "EC2"
  vpc_zone_identifier = each.value.subnet_ids

  capacity_rebalance = var.use_spot_instances

  mixed_instances_policy {
    instances_distribution {
      on_demand_percentage_above_base_capacity = var.use_spot_instances ? 0 : 100
      spot_allocation_strategy                 = "lowest-price"
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.main[each.key].id
        version            = "$Latest"
      }

      override {
        instance_type = var.instance_type
      }

      dynamic "override" {
        for_each = toset(var.ha_additional_instance_types)

        content {
          instance_type = override.value
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = each.value.name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  timeouts {
    delete = "15m"
  }
}

resource "aws_autoscaling_lifecycle_hook" "spot_termination_wait" {
  for_each = var.use_spot_instances ? local.subnets : {}

  name                   = "TerminationWait"
  autoscaling_group_name = aws_autoscaling_group.main[each.key].name
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
}