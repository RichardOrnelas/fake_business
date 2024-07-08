# NOTE: GITHUB Roles for Github Actions

resource "aws_iam_openid_connect_provider" "github" {

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github" {
  name               = "${var.project}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_grant.json
  description        = "${var.project} Github Actions Role"
}

resource "aws_iam_role_policy" "github" {
  name   = "${var.project}-${terraform.workspace}-github-actions-policy"
  role   = aws_iam_role.github.id
  policy = data.aws_iam_policy_document.github.json
}

data "aws_iam_policy_document" "github_grant" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test = "StringLike"
      values = [
        "repo:new-range/*"
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "readonly_role_policy_attach" {
  role       = aws_iam_role.github.id
  policy_arn = data.aws_iam_policy.readonly_access.arn
}

data "aws_iam_policy" "readonly_access" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# TODO: do the actual tighter policy
data "aws_iam_policy_document" "github" {
  statement {
    actions = [
      "*"
    ]
    resources = ["*"]
  }
}
