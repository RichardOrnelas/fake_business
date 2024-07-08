resource "aws_ses_domain_identity" "main" {
  domain = local.domain
}

resource "aws_ses_domain_identity_verification" "main_verification" {
  domain = aws_ses_domain_identity.main.id

  depends_on = [aws_route53_record.amazonses_verification_record]
}

resource "aws_route53_record" "amazonses_verification_record" {
  zone_id = aws_route53_zone.primary.id
  name    = "_amazonses.${local.domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "ses.${aws_ses_domain_identity.main.domain}"
}

resource "aws_route53_record" "ses_domain_mail_from_mx" {
  zone_id = aws_route53_zone.primary.id
  name    = aws_ses_domain_mail_from.main.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.us-east-1.amazonses.com"] # Change to the region in which `aws_ses_domain_identity.example` is created
}

# Example Route53 TXT record for SPF
resource "aws_route53_record" "ses_domain_mail_from_txt" {
  zone_id = aws_route53_zone.primary.id
  name    = aws_ses_domain_mail_from.main.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}

data "aws_iam_policy_document" "main" {
  statement {
    actions   = ["SES:SendEmail", "SES:SendRawEmail"]
    resources = [aws_ses_domain_identity.main.arn]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
  }
}

resource "aws_ses_identity_policy" "main" {
  identity = aws_ses_domain_identity.main.arn
  name     = "main"
  policy   = data.aws_iam_policy_document.main.json
}

resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "primary-rules"
}

resource "aws_ses_identity_notification_topic" "main" {
  topic_arn                = aws_sns_topic.cloudwatch_alerts.arn
  notification_type        = "Bounce"
  identity                 = aws_ses_domain_identity.main.domain
  include_original_headers = true
}

resource "aws_ses_receipt_rule" "store" {
  name          = "store"
  rule_set_name = "primary-rules"
  recipients    = ["*@fakebusiness.com"]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name = aws_s3_bucket.email.id
    position    = 1
  }
}

resource "aws_s3_bucket" "email" {
  bucket = "${var.project}-ses-emails-${terraform.workspace}"
}

resource "aws_s3_bucket_policy" "email" {
  bucket = aws_s3_bucket.email.id
  policy = data.aws_iam_policy_document.email_bucket_policy.json
}

data "aws_iam_policy_document" "email_bucket_policy" {
  statement {
    sid     = "SES Write"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.email.id}/*",
    ]
    principals {
      type = "Service"
      identifiers = [
        "ses.amazonaws.com"
      ]
    }
  }
}
