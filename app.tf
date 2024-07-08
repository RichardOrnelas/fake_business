##############################
######## Load Balancer #######
##############################

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = join(".", compact(["app", local.domain]))
  type    = "A"

  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = false
  }
}

resource "aws_lb_target_group" "app" {
  lifecycle {
    create_before_destroy = true
  }

  name        = "${var.project}-app"
  port        = "3000"
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.primary.id

  health_check {
    healthy_threshold   = 2
    path                = "/auth/sign-in"
    timeout             = 20
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-399"
  }

  deregistration_delay = 30
}

################################
######### app + IAM ############
################################

resource "aws_iam_role" "app" {
  name               = "${var.project}-app-role"
  assume_role_policy = data.aws_iam_policy_document.app_grant.json
}

resource "aws_iam_role_policy" "app_policy" {
  name   = "${var.project}-app-service-policy"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

data "aws_iam_policy_document" "app" {

  statement {
    actions = [
      "iam:PassRole",
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
      "kafka:*",
      "kafka-cluster:*"
    ]
    resources = [
      aws_msk_cluster.main.arn
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

data "aws_iam_policy_document" "app_grant" {
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


resource "aws_ecr_repository" "app" {
  count                = terraform.workspace == "production" ? 1 : 0
  name                 = "app"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "app_ecr_policy" {
  depends_on = [aws_ecr_repository.app]

  count      = terraform.workspace == "production" ? 1 : 0
  repository = aws_ecr_repository.app[0].name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

# resource "aws_ecr_lifecycle_policy" "ecr_lifecycle" {
#   depends_on = [aws_ecr_repository.primary]

#   count      = terraform.workspace == "production" ? 1 : 0
#   repository = aws_ecr_repository.primary[0].name

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



