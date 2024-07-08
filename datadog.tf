resource "aws_iam_role" "datadog" {
  name               = "${var.project}-datadog"
  assume_role_policy = data.aws_iam_policy_document.datadog_grant.json
  description        = "${var.project} datadog role"
}

data "aws_iam_policy_document" "datadog_grant" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::464622532012:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"

      values = [
        local.datadog_external_id[terraform.workspace]
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "readonly_role_policy_attachment" {
  role       = aws_iam_role.datadog.id
  policy_arn = data.aws_iam_policy.readonly_access.arn
}
