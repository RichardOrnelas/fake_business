######### NEWWWWWWW
# S3
locals {
  assets_name         = "${var.project}-assets"
  assets_cf_origin_id = local.assets_name
  assets_domain       = "assets.${local.domain}"
}

resource "aws_s3_bucket" "assets" {
  bucket = "${local.assets_name}-${terraform.workspace}"
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  depends_on = [aws_s3_bucket_versioning.assets]

  bucket = aws_s3_bucket.assets.id

  rule {
    id = "ExpireOldThings"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 2
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_logging" "assets" {
  bucket = aws_s3_bucket.assets.id

  target_bucket = aws_s3_bucket.assets_access_logs.id
  target_prefix = "s3/assets-pipeline/"
}

resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = [
      "https://${local.assets_domain}",
      "https://*.${local.domain}",
    ]

    expose_headers  = ["Etag"]
    max_age_seconds = 604800
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_bucket_policy.json
}

data "aws_iam_policy_document" "assets_bucket_policy" {
  statement {
    sid     = "CloudFrontRead"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.assets.id}/*",
    ]
    principals {
      type = "Service"
      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*"
      ]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "assets-spa-oac"
  description                       = "Access to SPA buckets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "assets" {

  lifecycle {
    prevent_destroy = false
  }

  origin {
    domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id                = local.assets_cf_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "Assets Build Pipeline"
  default_root_object = "index.html"

  aliases = [
    "assets.${local.domain}"
  ]

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.assets_access_logs.bucket_regional_domain_name
    prefix          = "cloudfront/assets-pipeline/"
  }

  default_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.assets_cf_origin_id
    compress         = true

    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.s3_origin.id
    cache_policy_id            = aws_cloudfront_cache_policy.assets.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id

    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.primary.arn
    minimum_protocol_version = "TLSv1.2_2019"
    ssl_support_method       = "sni-only"
  }

  # I cant be bothered
  wait_for_deployment = false
}

resource "aws_cloudfront_cache_policy" "assets" {
  name    = "assets-pipeline-build-cache-${terraform.workspace}"
  comment = "assets Pipeline: Build"

  default_ttl = local.cache_ttl
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    # Whitelisting the host forwards it to S3 which causes
    # AccessDenied errors... leave it as none
    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "assets" {
  name    = "assets-pipeline-build-headers-${terraform.workspace}"
  comment = "assets Pipeline: Builds"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET"]
    }

    access_control_allow_origins {
      items = [
        "https://${local.assets_domain}",
        "https://*.${local.domain}"
      ]
    }

    access_control_max_age_sec = 86400

    origin_override = true
  }

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }
    strict_transport_security {
      include_subdomains         = false
      override                   = true
      access_control_max_age_sec = local.hsts_max_age
      preload                    = false
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

### DNS ###

resource "aws_route53_record" "assets" {
  for_each = toset(["A", "AAAA"])

  zone_id = aws_route53_zone.primary.zone_id
  name    = local.assets_domain
  type    = each.value

  alias {
    name                   = aws_cloudfront_distribution.assets.domain_name
    zone_id                = aws_cloudfront_distribution.assets.hosted_zone_id
    evaluate_target_health = false
  }
}

#######################
#######  LOGS  ########
#######################

resource "aws_s3_bucket" "assets_access_logs" {
  bucket = "${var.project}-assets-access-logs-${terraform.workspace}"
}

resource "aws_s3_bucket_policy" "assets_access_logs" {
  bucket = aws_s3_bucket.assets_access_logs.id
  policy = data.aws_iam_policy_document.assets_access_logs.json
}

resource "aws_s3_bucket_ownership_controls" "assets_access_logs" {
  bucket = aws_s3_bucket.assets_access_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "assets_access_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.assets_access_logs]

  bucket = aws_s3_bucket.assets_access_logs.id
  acl    = "private"
}

data "aws_iam_policy_document" "assets_access_logs" {
  statement {

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.assets_access_logs.arn}/*",
      aws_s3_bucket.assets_access_logs.arn
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
      "${aws_s3_bucket.assets_access_logs.arn}/*",
      aws_s3_bucket.assets_access_logs.arn
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
