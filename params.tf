resource "aws_ssm_parameter" "global" {
  depends_on = [aws_cognito_user_pool.main, aws_cognito_user_pool_client.client]
  for_each   = local.global_secrets
  type       = "SecureString"
  name       = "/${var.project}/${each.key}"
  value      = each.value
}

resource "aws_ssm_parameter" "datadog_api_key" {
  type  = "SecureString"
  name  = "/${var.project}/DD_API_KEY"
  value = var.datadog_api_key
}

resource "aws_ssm_parameter" "sentry_auth_token" {
  type  = "SecureString"
  name  = "/${var.project}/SENTRY_AUTH_TOKEN"
  value = var.sentry_auth_token
}

resource "aws_ssm_parameter" "cognito_user_pool" {
  type  = "SecureString"
  name  = "/${var.project}/COGNITO_USER_POOL"
  value = aws_cognito_user_pool.main.id
}

resource "aws_ssm_parameter" "cognito_client_id" {
  type  = "SecureString"
  name  = "/${var.project}/COGNITO_CLIENT_ID"
  value = aws_cognito_user_pool_client.client.id
}

resource "aws_ssm_parameter" "rudderstack_data_plane_url" {
  type  = "SecureString"
  name  = "/${var.project}/RUDDERSTACK_DATA_PLANE_URL"
  value = var.rudderstack_data_plane_url
}

resource "aws_ssm_parameter" "rudderstack_write_key" {
  type  = "SecureString"
  name  = "/${var.project}/RUDDERSTACK_WRITE_KEY"
  value = var.rudderstack_write_key
}
