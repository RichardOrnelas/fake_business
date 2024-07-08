##############################
######## Load Balancer #######
##############################

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = join(".", compact(["api", local.domain]))
  type    = "A"

  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = false
  }
}


resource "aws_lb_target_group" "api" {
  name        = "${var.project}-api"
  port        = "3000"
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

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = ["api.${local.domain}"]
    }
  }
}

################################
######### API + IAM ############
################################

resource "aws_iam_role" "api" {
  name               = "${var.project}-api-role"
  assume_role_policy = data.aws_iam_policy_document.api_grant.json
}

resource "aws_iam_role_policy" "api_policy" {
  name   = "${var.project}-api-service-policy"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api.json
}

data "aws_iam_policy_document" "api" {

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
      "sns:*",
      "cognito-identity:*",
      "cognito-idp:*"
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

data "aws_iam_policy_document" "api_grant" {
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

resource "aws_ecr_repository" "api" {
  count                = terraform.workspace == "production" ? 1 : 0
  name                 = "api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

### SHARED ###
data "aws_iam_policy_document" "ecr_policy" {
  statement {
    sid    = "new policy"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.aws_accounts
    }

    actions = [
      "ecr:*",
    ]
  }
}

resource "aws_ecr_repository_policy" "api_ecr_policy" {
  depends_on = [aws_ecr_repository.api]

  count      = terraform.workspace == "production" ? 1 : 0
  repository = aws_ecr_repository.api[0].name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

# resource "aws_ecr_lifecycle_policy" "ecr_lifecycle" {
#   depends_on = [aws_ecr_repository.api]

#   count      = terraform.workspace == "production" ? 1 : 0
#   repository = aws_ecr_repository.api[0].name

#   policy = <<EOF
# {
#     "rules": [
#         {
#             "rulePriority": 1,
#             "description": "Keep last 25 images",
#             "selection": {
#                 "tagStatus": "tagged",
#                 "tagPrefixList": ["v"],
#                 "countType": "imageCountMoreThan",
#                 "countNumber": 25
#             },
#             "action": {
#                 "type": "expire"
#             }
#         },
#         {
#             "rulePriority": 5,
#             "description": "Delete after 45 days",
#             "selection": {
#                 "tagStatus": "any",
#                 "countType": "sinceImagePushed",
#                 "countNumber": 45
#             },
#             "action": {
#                 "type": "expire"
#             }
#         }
#     ]
# }
# EOF
# }



