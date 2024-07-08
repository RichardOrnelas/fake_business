##### ALARMS #####
# NETWORK #
resource "aws_cloudwatch_metric_alarm" "nat_gateway_usage" {
  alarm_name                = "nat_gateway_usage"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "BytesOutToDestination"
  namespace                 = "AWS/NATGateway"
  period                    = 900
  statistic                 = "Maximum"
  threshold                 = 1000000
  alarm_description         = "NAT Gateway Usage Exceeded"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

# MSK #
resource "aws_cloudwatch_metric_alarm" "msk_cpu_credit" {
  alarm_name          = "msk_cpu_credit"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/Kafka"
  dimensions = {
    Broker = 1
  }
  period                    = 120
  statistic                 = "Average"
  threshold                 = 100
  alarm_description         = "MSK Broker CPU Credit Below Average"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "kafka_data_logs_disk_used" {
  alarm_name          = "kafka_data_logs_disk_used"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "KafkaDataLogsDiskUsed"
  namespace           = "AWS/Kafka"
  dimensions = {
    Broker = 1
  }
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "MSK Disk Usage Low"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

# RDS #

resource "aws_cloudwatch_metric_alarm" "rds_storage_space" {
  alarm_name          = "rds_storage_space"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }
  period                    = 120
  statistic                 = "Average"
  threshold                 = 5000000000
  alarm_description         = "RDS Disk Usage Low"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  alarm_name          = "rds_write_latency"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }
  period                    = 120
  statistic                 = "Average"
  threshold                 = 0.01
  alarm_description         = "RDS Write Latency High"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "rds_read_latency" {
  alarm_name          = "rds_read_latency"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }
  period                    = 120
  statistic                 = "Average"
  threshold                 = 0.01
  alarm_description         = "RDS Read Latency High"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

##### ECS #####
locals {
  ecs_services = ["fakebusiness-api-web", "fakebusiness-api-catevents", "fakebusiness-app-web", "fakebusiness-api-files", "fakebusiness-api-orders", "fakebusiness-api-cat_errors"]
}
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  lifecycle {
    ignore_changes = [dimensions]
  }
  count               = length(local.ecs_services)
  alarm_name          = "ecs_cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  dimensions = {
    ServiceName = element(local.ecs_services, count.index)
    ClusterName = "primary"
  }
  period                    = 120
  statistic                 = "Average"
  threshold                 = 90
  alarm_description         = "ECS CPU high"
  alarm_actions             = [aws_sns_topic.cloudwatch_alerts.arn]
  insufficient_data_actions = []
}

##### BUDGETS #####
resource "aws_budgets_budget" "total" {
  name         = "monthly_budget"
  budget_type  = "COST"
  limit_amount = "1200"
  limit_unit   = "USD"
  # time_period_end   = "2087-06-15_00:00"
  # time_period_start = "2017-07-01_00:00"
  time_unit = "MONTHLY"


  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.cloudwatch_alerts.arn]
  }
}



##### ALERTS #####

resource "aws_sns_topic" "cloudwatch_alerts" {
  name = "${var.project}-${terraform.workspace}-alerts"
}

resource "aws_sns_topic_subscription" "topic_lambda" {
  topic_arn = aws_sns_topic.cloudwatch_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_sns.arn
}

resource "aws_lambda_function" "slack_sns" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "slack_lambda_function_payload.zip"
  function_name = "slack_sns"
  role          = aws_iam_role.slack_iam_for_lambda.arn
  handler       = "slack.handler"

  source_code_hash = data.archive_file.slack_lambda.output_base64sha256

  runtime = "nodejs20.x"

  environment {
    variables = {
      SLACK_WEBHOOK = var.slack_webhook
    }
  }
}

resource "aws_cloudwatch_log_group" "name" {
  name              = "/aws/lambda/slack_sns"
  retention_in_days = 7
}

data "archive_file" "slack_lambda" {
  type        = "zip"
  source_file = "./functions/slack.js"
  output_path = "slack_lambda_function_payload.zip"
}

data "aws_iam_policy_document" "slack_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "slack_iam_for_lambda" {
  name               = "slack_iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.slack_assume_role.json
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_sns.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cloudwatch_alerts.arn
}
