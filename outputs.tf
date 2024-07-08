# NOTE: Outputs only

output "domain" {
  description = "Domain for the project environment"
  value       = local.domain
}

output "route53_zone_id" {
  description = "some description"
  value       = aws_route53_zone.primary.id
}

output "route53_nameservers" {
  description = "some description"
  value       = aws_route53_zone.primary.name_servers
}

output "acm_cert_arn" {
  description = "some description"
  value       = aws_acm_certificate.primary.arn
}

output "nat_gateway_ip" {
  description = "NAT Gateway IP address"
  value       = aws_nat_gateway.primary.public_ip
}

output "site_bucket_name" {
  description = "Name of the marketing site bucket"
  value       = aws_s3_bucket.site.id
}

output "assets_bucket_name" {
  description = "Name of the assets bucket"
  value       = aws_s3_bucket.assets.id
}

output "email_bucket_name" {
  description = "Name of the email bucket"
  value       = aws_s3_bucket.email.id
}

output "document_bucket_name" {
  description = "Name of the document bucket"
  value       = aws_s3_bucket.document_bucket.id
}

output "document_bucket_arn" {
  description = "ARN of the document bucket"
  value       = aws_s3_bucket.document_bucket.arn
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "ID of the Cognito Client"
  value       = aws_cognito_user_pool_client.client.id
}

output "database_url" {
  description = "URL to the RDS postgres database"
  value       = format("postgres://%s:%s@%s/%s", aws_db_instance.primary.username, "PASSWORD", aws_db_instance.primary.endpoint, aws_db_instance.primary.db_name)
}

output "kafka_arn" {
  description = "ARN of the Serverless Managed Kafka"
  value       = aws_msk_cluster.main.arn
}

output "kafka_bootstrap_servers" {
  description = "Bootstrap Servers of the Serverless Managed Kafka"
  value       = data.aws_msk_bootstrap_brokers.kafka_brokers.bootstrap_brokers_sasl_iam
}

output "api_url" {
  description = "API URL"
  value       = "https://${aws_route53_record.api.fqdn}"
}

output "app_url" {
  description = "Web App URL"
  value       = "https://${aws_route53_record.app.fqdn}"
}

output "site_url" {
  description = "Website URL"
  value       = "https://${aws_route53_record.www["A"].fqdn}"
}

output "conduktor_url" {
  description = "Conduktor URL"
  value       = "https://${aws_route53_record.conduktor.fqdn}"
}

output "assets_url" {
  description = "Assets URL"
  value       = "https://${aws_route53_record.assets["A"].fqdn}"
}

output "email_bucket" {
  description = "SES Email storage bucket ARN"
  value       = aws_s3_bucket.email.arn
}

output "ses_arn" {
  description = "ARN for the SES domain"
  value       = "arn:aws:ses:us-east-1:${data.aws_caller_identity.current.account_id}:identity/${aws_ses_domain_mail_from.main.domain}"
}

output "github_oidc_role_arn" {
  description = "Github OIDC Role ARN"
  value       = aws_iam_role.github.arn
}
output "zookeeper_connect_string" {
  description = "Kafka Zookeeper connection string"
  value       = aws_msk_cluster.main.zookeeper_connect_string
}

output "bootstrap_brokers_iam" {
  description = "TLS connection host:port pairs"
  value       = split(",", aws_msk_cluster.main.bootstrap_brokers_sasl_iam)
}
