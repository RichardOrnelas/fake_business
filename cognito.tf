# docs available https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool

###############################
########## COGNITO ############
###############################

resource "aws_cognito_user_pool" "main" {
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      schema, email_configuration, sms_authentication_message
    ]
  }

  name = "${var.project}-users"

  deletion_protection        = "ACTIVE"
  sms_authentication_message = "Your ${title(var.project)} authentication code is {####}."

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 30
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
  lambda_config {
    pre_sign_up = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:cognitoLinkAccountsTrigger"
  }

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # sms_configuration {
  #   enabled = true
  # }


  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  # lambda_config {
  #   # create_auth_challenge = var.create_auth_challenge_lambda_arn  # (Optional) ARN of the lambda creating an authentication challenge.
  #   # custom_message = var.custom_message_lambda_arn  # (Optional) Custom Message AWS Lambda trigger.
  #   # define_auth_challenge = var.define_auth_challenge_lambda_arn  # (Optional) Defines the authentication challenge.
  #   post_authentication = local.post_auth_lambda_arn # (Optional) Post-authentication AWS Lambda trigger.
  #   post_confirmation   = local.post_auth_lambda_arn # (Optional) Post-confirmation AWS Lambda trigger.
  #   # pre_authentication = var.pre_authentication_lambda_arn  # (Optional) Pre-authentication AWS Lambda trigger.
  #   # pre_sign_up = var.pre_sign_up_lambda_arn  # (Optional) Pre-registration AWS Lambda trigger.
  # }

  # ### SCHEMA ###
  schema {
    name                     = "given_name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }

  schema {
    name                     = "family_name"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "${var.project}-cognito-client"

  user_pool_id = aws_cognito_user_pool.main.id

  allowed_oauth_flows_user_pool_client = true

  generate_secret         = false
  explicit_auth_flows     = ["ALLOW_CUSTOM_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  refresh_token_validity  = 1
  enable_token_revocation = true
  access_token_validity   = 1

  allowed_oauth_flows          = ["code"]
  allowed_oauth_scopes         = ["email", "openid", "profile"]
  callback_urls                = [local.global_secrets.COGNITO_REDIRECT_SIGN_IN_URL]
  logout_urls                  = [local.global_secrets.COGNITO_REDIRECT_SIGN_OUT_URL]
  supported_identity_providers = ["Google"]

  token_validity_units {
    access_token  = "days"
    id_token      = "minutes"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user_pool_domain" "domain" {
  user_pool_id = aws_cognito_user_pool.main.id
  domain       = local.global_secrets.COGNITO_DOMAIN_BASE
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id = aws_cognito_user_pool.main.id

  provider_name = "Google"
  provider_type = "Google"

  attribute_mapping = {
    email        = "email"
    name         = "name"
    phone_number = "phoneNumbers"
    username     = "sub"
  }

  provider_details = {
    client_id                     = var.google_client_id
    client_secret                 = var.google_client_secret
    authorize_scopes              = "openid email profile phone"
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  idp_identifiers = ["Google"]
}
