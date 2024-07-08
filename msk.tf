resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project}-main"
  kafka_version          = "3.7.x"
  number_of_broker_nodes = 2 # must be multiple of subnet count

  broker_node_group_info {
    instance_type = var.kafka_instance_class
    client_subnets = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id
    ]
    # storage_info {
    #   ebs_storage_info {
    #     volume_size = 1000
    #   }
    # }
    security_groups = [aws_security_group.msk.id]
  }

  configuration_info {
    arn      = terraform.workspace == "production" ? aws_msk_configuration.production.arn : aws_msk_configuration.main37.arn
    revision = terraform.workspace == "production" ? aws_msk_configuration.production.latest_revision : aws_msk_configuration.main37.latest_revision
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  # encryption_info {
  #   encryption_at_rest_kms_key_arn = aws_kms_key.kms.arn
  # }

  # open_monitoring {
  #   prometheus {
  #     jmx_exporter {
  #       enabled_in_broker = true
  #     }
  #     node_exporter {
  #       enabled_in_broker = true
  #     }
  #   }
  # }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
      # firehose {
      #   enabled         = true
      #   delivery_stream = aws_kinesis_firehose_delivery_stream.test_stream.name
      # }
      # s3 {
      #   enabled = true
      #   bucket  = aws_s3_bucket.bucket.id
      #   prefix  = "logs/msk-"
      # }
    }
  }
}

resource "aws_msk_configuration" "main" {
  kafka_versions = ["3.2.0"]
  name           = "${var.project}-main-cluster-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
compression.type=producer
min.insync.replicas=1
num.io.threads=2
num.network.threads=2
num.partitions=${local.kafka_partition_count}
num.recovery.threads.per.data.dir=1
num.replica.fetchers=1
offsets.retention.minutes=1440
offsets.topic.replication.factor=1
replica.fetch.max.bytes=1048576
replica.fetch.response.max.bytes=1048576
PROPERTIES
}

resource "aws_msk_configuration" "main37" {
  kafka_versions = ["3.7.x"]
  name           = "${var.project}-main-cluster-config-3-7"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
compression.type=producer
min.insync.replicas=1
num.io.threads=2
num.network.threads=2
num.partitions=${local.kafka_partition_count}
num.recovery.threads.per.data.dir=1
num.replica.fetchers=1
offsets.retention.minutes=1440
offsets.topic.replication.factor=1
replica.fetch.max.bytes=1048576
replica.fetch.response.max.bytes=1048576
PROPERTIES
}

resource "aws_msk_configuration" "production" {
  kafka_versions = ["3.2.0"]
  name           = "${var.project}-main-cluster-config-production"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
compression.type=producer
min.insync.replicas=1
num.io.threads=2
num.network.threads=2
num.partitions=${local.kafka_partition_count}
num.recovery.threads.per.data.dir=1
num.replica.fetchers=1
offsets.retention.minutes=1440
offsets.topic.replication.factor=1
replica.fetch.max.bytes=1048576
replica.fetch.response.max.bytes=1048576
PROPERTIES
}

resource "aws_cloudwatch_log_group" "msk" {
  name = "msk_broker_logs"
}


# resource "aws_msk_cluster" "main" {
#   cluster_name = "${var.project}-main-cluster"

#   vpc_config {
#     subnet_ids         = aws_subnet.private[*].id
#     security_group_ids = [aws_security_group.msk.id]
#   }

#   client_authentication {
#     sasl {
#       iam {
#         enabled = true
#       }
#     }
#   }
# }

# resource "aws_msk_cluster_policy" "primary" {
#   cluster_arn = aws_msk_cluster.main.arn
#   policy      = data.aws_iam_policy_document.msk.json
# }

# data "aws_iam_policy_document" "msk" {
#   statement {

#     actions = [
#       "kafka:*"
#     ]

#     resources = ["*"]

#     principals {
#       type = "AWS"
#       identifiers = [
#         "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
#       ]
#     }
#   }
# }

resource "aws_security_group" "msk" {
  name        = "msk-access"
  description = "msk Instance Access"
  vpc_id      = aws_vpc.primary.id

  tags = {
    Name = "msk-access"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "msk_self" {
  description       = "Allow private network traffic from itself over all ports"
  security_group_id = aws_security_group.msk.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
}

resource "aws_security_group_rule" "msk_ecs" {
  description              = "Allow Kafka traffic from ECS cluster"
  security_group_id        = aws_security_group.msk.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "msk_local" {
  description       = "Allow Kafka traffic from local network"
  security_group_id = aws_security_group.msk.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [aws_vpc.primary.cidr_block]
}

resource "aws_security_group_rule" "msk_vpn" {
  description              = "Allow MSK traffic from VPN connection"
  security_group_id        = aws_security_group.msk.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = -1
  source_security_group_id = module.twingate.twingate_security_group
}

resource "aws_security_group_rule" "msk_egress" {
  security_group_id = aws_security_group.msk.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound internet"
}

data "aws_msk_bootstrap_brokers" "kafka_brokers" {
  depends_on  = [aws_msk_cluster.main]
  cluster_arn = aws_msk_cluster.main.arn
}

# resource "aws_ssm_parameter" "kafka_brokers" {
#   type  = "SecureString"
#   name  = "/${var.project}/KAFKA_BOOTSTRAP_SERVERS"
#   value = jsonencode([data.aws_msk_bootstrap_brokers.kafka_brokers.bootstrap_brokers_sasl_iam])
# }

resource "aws_ssm_parameter" "kafka_bootstrap_servers" {
  type  = "SecureString"
  name  = "/${var.project}/KAFKA_BOOTSTRAP_SERVERS"
  value = jsonencode(split(",", aws_msk_cluster.main.bootstrap_brokers_sasl_iam))
}

resource "aws_ssm_parameter" "zookeeper_connect_string" {
  type  = "SecureString"
  name  = "/${var.project}/ZOOKEEPER_CONNECT_STRING"
  value = aws_msk_cluster.main.zookeeper_connect_string
}
