# Route 53
resource "aws_route53_record" "conduktor" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = join(".", compact(["conduktor", local.domain]))
  type    = "A"

  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = false
  }
}
# Listener Rule on the ALB
resource "aws_lb_target_group" "conduktor" {
  name        = "${var.project}-conduktor"
  port        = "8080"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.primary.id

  health_check {
    healthy_threshold   = 2
    path                = "/health"
    timeout             = 20
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-399"
  }

  deregistration_delay = 30
}

resource "aws_lb_listener_rule" "conduktor" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.conduktor.arn
  }

  condition {
    host_header {
      values = ["conduktor.${local.domain}"]
    }
  }
}

# IAM Role
resource "aws_iam_role" "conduktor" {
  name               = "${var.project}-conduktor-role"
  assume_role_policy = data.aws_iam_policy_document.conduktor_grant.json
}

resource "aws_iam_role_policy" "conduktor_policy" {
  name   = "${var.project}-conduktor-service-policy"
  role   = aws_iam_role.conduktor.id
  policy = data.aws_iam_policy_document.conduktor.json
}

data "aws_iam_policy_document" "conduktor" {

  statement {
    actions = [
      "kafka:*",
      "kafka-cluster:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "iam:*",
      "sts:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "ec2:Describe*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.document_bucket.arn,
      "${aws_s3_bucket.document_bucket.arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "conduktor_grant" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

# ECS Task definition and service

locals {
  env_vars = {
    PORT                                      = 8080
    CDK_ADMIN_EMAIL                           = "mark@fakebusiness.com"
    CDK_ADMIN_PASSWORD                        = var.conduktor_admin_password
    CDK_DATABASE_HOST                         = aws_db_instance.conduktor.address
    CDK_DATABASE_NAME                         = "postgres"
    CDK_DATABASE_PASSWORD                     = var.conduktor_admin_password
    CDK_DATABASE_PORT                         = aws_db_instance.conduktor.port
    CDK_DATABASE_USERNAME                     = "conduktor"
    CDK_MONITORING_ALERT-MANAGER-URL          = "http://localhost:9010/"
    CDK_MONITORING_CALLBACK-URL               = "http://localhost:8080/monitoring/api/"
    CDK_MONITORING_CORTEX-URL                 = "http://localhost:9009/"
    CDK_MONITORING_NOTIFICATIONS-CALLBACK-URL = "http://localhost:8080"
    CDK_CONSOLE-URL                           = "http://localhost:8080"

  }

  # Secrets that point to an SSM arn
  secret_vars = {}

  # Leave these alone
  env_var_array = [for k, v in local.env_vars : {
    name  = k
    value = tostring(v)
  }]
  secret_var_array = [for k, v in local.secret_vars : {
    name      = k
    valueFrom = v
  }]

  base_app_container = {
    image       = "conduktor/conduktor-console:latest"
    volumesFrom = []
    essential   = true
    mountPoints = []
    portMappings = [
      {
        hostPort      = 8080
        containerPort = 8080
        protocol      = "tcp"
      }
    ]
    environment  = local.env_var_array
    secrets      = local.secret_var_array
    startTimeout = 60
    stopTimeout  = 115
  }
}

resource "aws_ecs_service" "conduktor" {
  depends_on = [aws_ecs_task_definition.conduktor, aws_iam_role.conduktor]

  name            = "conduktor"
  cluster         = aws_ecs_cluster.primary.id
  task_definition = aws_ecs_task_definition.conduktor.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.conduktor.arn
    container_name   = "conduktor"
    container_port   = 8080
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    base              = 1
    capacity_provider = "FARGATE"
    weight            = 100
  }

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }
}

resource "aws_ecs_task_definition" "conduktor" {
  family                   = "conduktor"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 2048
  memory                   = 4096
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.conduktor.arn

  container_definitions = jsonencode([
    merge(local.base_app_container, {
      name = "conduktor"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.conduktor.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "conduktor"
        }
      }
      startTimeout = 60
      stopTimeout  = 115
    }),
    merge(local.base_app_container, {
      name  = "conduktor-monitoring"
      image = "conduktor/conduktor-console-cortex:latest"
      portMappings = [
        {
          hostPort      = 9090
          containerPort = 9090
          protocol      = "tcp"
        },
        {
          hostPort      = 9010
          containerPort = 9010
          protocol      = "tcp"
        },
        {
          hostPort      = 9009
          containerPort = 9009
          protocol      = "tcp"
        }
      ]
    })
  ])
}

# Database

resource "aws_db_instance" "conduktor" {

  allocated_storage                     = 20
  storage_type                          = "gp2"
  engine                                = "postgres"
  engine_version                        = var.db_postgres_version
  instance_class                        = "db.t3.micro"
  db_name                               = "postgres"
  identifier                            = "${var.project}-${terraform.workspace}-conduktor"
  username                              = "conduktor"
  password                              = var.conduktor_admin_password
  port                                  = 5432
  allow_major_version_upgrade           = true
  parameter_group_name                  = aws_db_parameter_group.primary.name
  vpc_security_group_ids                = [aws_security_group.rds.id]
  db_subnet_group_name                  = aws_db_subnet_group.ecs.name
  backup_retention_period               = 7
  auto_minor_version_upgrade            = true
  apply_immediately                     = true
  copy_tags_to_snapshot                 = true
  skip_final_snapshot                   = true
  final_snapshot_identifier             = "${var.project}-${terraform.workspace}-conduktor-final"
  storage_encrypted                     = true
  multi_az                              = false
  performance_insights_enabled          = false
  deletion_protection                   = false
  performance_insights_retention_period = 0
}

resource "aws_cloudwatch_log_group" "conduktor" {
  name = "conduktor"
}
