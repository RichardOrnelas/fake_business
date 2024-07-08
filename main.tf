# put all resources here

locals {
  availability_zones            = split(",", var.availability_zones[var.region])
  az_count                      = length(local.availability_zones)
  domain                        = join(".", compact([terraform.workspace == "production" ? "" : terraform.workspace, "fakebusiness.com"]))
  hsts_max_age                  = 365 * 24 * 3600
  cache_ttl                     = 3600
  whitelist_ips                 = ["${aws_nat_gateway.primary.public_ip}/32"]
  acm_subject_alternative_names = ["*.${local.domain}", "*.app.${local.domain}", "*.api.${local.domain}", "*.site.${local.domain}"]
  kafka_partition_count         = terraform.workspace == "production" ? 300 : 20
  vpc_cidr_blocks = {
    "default"    = "10.100.0.0/16"
    "dev"        = "10.20.0.0/16",
    "staging"    = "10.10.0.0/16",
    "production" = "10.0.0.0/16"
  }

  datadog_external_id = {
    "default"    = "0"
    "dev"        = "1234567890"
    "staging"    = "1234567890"
    "production" = "1234567890"
  }

  global_secrets = {
    DATABASE_URL                  = format("postgres://%s:%s@%s/%s", aws_db_instance.primary.username, var.db_password, aws_db_instance.primary.endpoint, aws_db_instance.primary.db_name)
    COGNITO_DOMAIN_BASE           = "${var.project}-${terraform.workspace}"
    COGNITO_DOMAIN                = "${var.project}-${terraform.workspace}.auth.us-east-1.amazoncognito.com"
    COGNITO_REDIRECT_SIGN_IN_URL  = "https://app.${local.domain}/dashboard"
    COGNITO_REDIRECT_SIGN_OUT_URL = "https://app.${local.domain}/auth/sign-in"
    WEB_CLOUDFRONT_ID             = aws_cloudfront_distribution.site.id
    WEB_BUCKET_NAME               = aws_s3_bucket.site.id
    AWS_REGION                    = "us-east-1"
    API_URL                       = "https://${aws_route53_record.api.fqdn}"
    APP_URL                       = "https://${aws_route53_record.app.fqdn}"
    SITE_URL                      = "https://${aws_route53_record.www["A"].fqdn}"
    DOCUMENT_BUCKET               = aws_s3_bucket.document_bucket.id
    STAGE                         = terraform.workspace
    DD_DATA_STREAMS_ENABLED       = true
  }
}

data "aws_caller_identity" "current" {}

data "aws_cloudfront_origin_request_policy" "s3_origin" {
  name = "Managed-CORS-S3Origin"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

################################
######## WAF Whitelist #########
################################
### WAF aka Web Access Firewall aka DDOS protection and IP whitelisting

resource "aws_wafv2_ip_set" "ip_whitelist" {
  name               = "ip-whitelist"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = local.whitelist_ips
}

resource "aws_wafv2_web_acl" "firewall" {
  name  = "${var.project}-firewall"
  scope = "CLOUDFRONT"

  default_action {
    block {}
  }

  rule {
    name     = "allow-whitelist"
    priority = 10

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.ip_whitelist.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Allowed"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "Blocked"
    sampled_requests_enabled   = true
  }
}

################################
########## DNS and ACM #########
################################
resource "aws_route53_zone" "primary" {
  name = local.domain
}

resource "aws_acm_certificate" "primary" {
  domain_name               = local.domain
  subject_alternative_names = local.acm_subject_alternative_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "ssl_cert" {
  depends_on = [aws_route53_zone.primary]

  for_each = {
    for dvo in aws_acm_certificate.primary.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "ssl_cert" {
  certificate_arn         = aws_acm_certificate.primary.arn
  validation_record_fqdns = [for record in aws_route53_record.ssl_cert : record.fqdn]
}

################################
# Application Documents Bucket #
################################
resource "aws_s3_bucket" "document_bucket" {
  bucket = "${var.project}-documents-${terraform.workspace}"
}

resource "aws_s3_bucket_logging" "document_bucket" {
  bucket = aws_s3_bucket.document_bucket.id

  target_bucket = aws_s3_bucket.document_bucket.id
  target_prefix = "_bucket_access_logs"
}

resource "aws_s3_bucket_policy" "document_bucket" {
  bucket = aws_s3_bucket.document_bucket.id
  policy = data.aws_iam_policy_document.document_bucket.json
}

data "aws_iam_policy_document" "document_bucket" {
  statement {
    sid       = "DenyIncorrectEncryptionHeader"
    effect    = "Deny"
    resources = ["${aws_s3_bucket.document_bucket.arn}/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.document_bucket.arn}/*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "document_bucket" {
  bucket = aws_s3_bucket.document_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "document_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.document_bucket]

  bucket = aws_s3_bucket.document_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.document_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://${aws_route53_record.app.fqdn}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

################################
########### Database ###########
################################

resource "aws_db_subnet_group" "ecs" {
  name        = "rds-db-subnets"
  subnet_ids  = aws_subnet.private[*].id
  description = "RDS Subnets"
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project}-rds-enhanced-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "primary" {

  allocated_storage                     = var.db_storage
  storage_type                          = terraform.workspace == "production" ? "gp3" : "gp2"
  engine                                = "postgres"
  engine_version                        = var.db_postgres_version
  instance_class                        = var.db_instance_class
  db_name                               = var.project
  identifier                            = "${var.project}-${terraform.workspace}"
  username                              = var.project
  password                              = var.db_password
  port                                  = 5432
  allow_major_version_upgrade           = true
  parameter_group_name                  = aws_db_parameter_group.primary.name
  vpc_security_group_ids                = [aws_security_group.rds.id]
  db_subnet_group_name                  = aws_db_subnet_group.ecs.name
  backup_retention_period               = 7
  auto_minor_version_upgrade            = true
  apply_immediately                     = true
  copy_tags_to_snapshot                 = true
  skip_final_snapshot                   = terraform.workspace == "production" ? false : true
  final_snapshot_identifier             = "${var.project}-${terraform.workspace}-final"
  storage_encrypted                     = true
  multi_az                              = terraform.workspace == "production" ? true : false
  performance_insights_enabled          = terraform.workspace == "production" ? true : false
  monitoring_interval                   = terraform.workspace == "production" ? 5 : 0
  deletion_protection                   = terraform.workspace == "production" ? true : false
  performance_insights_retention_period = terraform.workspace == "production" ? 7 : 0
  monitoring_role_arn                   = terraform.workspace == "production" ? aws_iam_role.rds_enhanced_monitoring.arn : null
}

resource "aws_db_parameter_group" "primary" {
  name   = "rds-pg"
  family = "postgres16"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_tle,pg_cron"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "cron.database_name"
    value        = "fakebusiness"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-access"
  description = "RDS Instance Access"
  vpc_id      = aws_vpc.primary.id

  tags = {
    Name = "rds-access"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_postgres_ecs" {
  description              = "Allow postgres traffic from ECS cluster"
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "rds_postgres_vpn" {
  description              = "Allow postgres traffic from VPN connection"
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.twingate.twingate_security_group
}

resource "aws_security_group_rule" "rds_egress" {
  security_group_id = aws_security_group.rds.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound internet"
}

# ECS Execution
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_grant.json
  description        = "${var.project} ECS Task Execution Role"
}

resource "aws_iam_role_policy" "ecs_execution_policy" {
  name   = "${var.project}-ecs-execution-policy"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_policy.json
}

data "aws_iam_policy_document" "ecs_execution_policy" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:Create*",
      "logs:Put*"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ssm:GetParameters",
      # "secretsmanager:GetSecretValue",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecs_execution_grant" {
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
###########################
###### LOAD BALANCER ######
###########################

resource "aws_lb" "web" {
  name                       = var.project
  internal                   = false
  security_groups            = [aws_security_group.alb_public.id]
  subnets                    = aws_subnet.public[*].id
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "load_balancer"
    enabled = true
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.primary.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    target_group_arn = aws_lb_target_group.app.arn
    type             = "forward"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      default_action
    ]
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      default_action
    ]
  }
}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project}-alb-logs-${terraform.workspace}"
}

resource "aws_s3_bucket_logging" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  target_bucket = aws_s3_bucket.alb_logs.id
  target_prefix = "_bucket_access_logs"
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "alb_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.alb_logs]

  bucket = aws_s3_bucket.alb_logs.id
  acl    = "private"
}

data "aws_iam_policy_document" "alb_logs" {
  statement {

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.alb_logs.arn}/*",
      aws_s3_bucket.alb_logs.arn
    ]
    principals {
      type = "Service"
      identifiers = [
        "delivery.logs.amazonaws.com",
        "logdelivery.elasticloadbalancing.amazonaws.com"
      ]
    }
  }

  statement {

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.alb_logs.arn}/*",
      aws_s3_bucket.alb_logs.arn
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::127311923021:root", # us-east-1 
        "arn:aws:iam::797873946194:root", # us-west-2
        "arn:aws:iam::027434742980:root", # us-west-1 
      ]
    }
  }
}

resource "aws_security_group" "alb_public" {
  name        = "alb-public"
  description = "Allow public internet traffic to load balancer"
  vpc_id      = aws_vpc.primary.id

  tags = {
    Name = "alb-access"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_public_80_platform" {
  description       = "Allow public network traffic over HTTP"
  security_group_id = aws_security_group.alb_public.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = terraform.workspace == "production" ? ["0.0.0.0/0"] : local.whitelist_ips
}

resource "aws_security_group_rule" "alb_vpn" {
  description              = "Allow alb traffic from VPN connection"
  security_group_id        = aws_security_group.alb_public.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.twingate.twingate_security_group
}

resource "aws_security_group_rule" "alb_public_443_platform" {
  description       = "Allow public network traffic over HTTPS"
  security_group_id = aws_security_group.alb_public.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = terraform.workspace == "production" ? ["0.0.0.0/0"] : local.whitelist_ips
}

resource "aws_security_group_rule" "lb_ingress_cloudfront" {
  description       = "HTTPS to the Load Balancer from CloudFront"
  security_group_id = aws_security_group.alb_public.id
  type              = "ingress"
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
}

resource "aws_security_group_rule" "lb_egress" {
  security_group_id = aws_security_group.alb_public.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound internet"
}

################################
##########    ECS     ##########
################################

resource "aws_security_group" "ecs" {
  lifecycle {
    create_before_destroy = true
  }

  name        = "ecs-access"
  description = "ECS Services on cluster and Fargate"
  vpc_id      = aws_vpc.primary.id

  tags = {
    Name = "ecs-access"
  }
}

resource "aws_security_group_rule" "ecs_self" {
  description       = "Allow private network traffic from itself over all ports"
  security_group_id = aws_security_group.ecs.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
}

resource "aws_security_group_rule" "ecs_sg_https" {
  description              = "Allow private network traffic from ECS security groups over HTTPS"
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_public.id
}

resource "aws_security_group_rule" "ecs_sg_http" {
  description              = "Allow private network traffic from ECS security groups over HTTP"
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_public.id
}

resource "aws_security_group_rule" "ecs_sg_http2" {
  description              = "Allow private network traffic from ECS security groups over 8080"
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_public.id
}

resource "aws_security_group_rule" "ecs_sg_web" {
  description              = "Allow private network traffic from ECS security groups over 3000"
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_public.id
}

resource "aws_security_group_rule" "ecs_vpn" {
  security_group_id        = aws_security_group.ecs.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.twingate.twingate_security_group
  description              = "Allow VPN traffic to ECS security group for console tasks"
}

resource "aws_security_group_rule" "ecs_egress" {
  security_group_id = aws_security_group.ecs.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound internet"
}

### @note: ECS ###
resource "aws_ecs_cluster" "primary" {
  name = "primary"
}

resource "aws_ecs_cluster_capacity_providers" "primary" {
  cluster_name = aws_ecs_cluster.primary.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
