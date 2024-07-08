# NOTE: Variables only

# EXAMPLE: 

variable "project" {
  description = "Identifier for the project"
  type        = string
  default     = "fakebusiness"
}

variable "aws_accounts" {
  description = "list of aws accounts"
  type        = list(string)
  default     = ["123456789100", "223456789100", "323456789100"]
}

variable "region" {
  type        = string
  description = "AWS Region to deploy resources in"
  default     = "us-east-1"
}

variable "availability_zones" {
  type        = map(string)
  description = "List of availability zones in the region"
  default = {
    "us-east-1" = "us-east-1a,us-east-1b,us-east-1c"
  }
}

variable "db_postgres_version" {
  type        = string
  description = "Postgres database version"
  default     = "16.2"
}

variable "db_instance_class" {
  type        = string
  description = "Size and Class for the RDS Postgres instance"
  default     = "db.t3.micro"
}

variable "db_storage" {
  type        = number
  description = "Postgres allocated storage"
  default     = 20
}

variable "kafka_instance_class" {
  type        = string
  description = "MSK Kafka instance class"
  default     = "kafka.t3.small"
}

variable "slack_webhook" {
  type        = string
  description = "Slack Webhook URL for Cloudwatch Alerts"
}

variable "db_password" {
  type        = string
  description = "database password"
}

variable "twingate_token" {
  type        = string
  description = "Twingate Network Access Token"
}

variable "datadog_api_key" {
  type        = string
  description = "Datadog API Key"
}

variable "google_client_id" {
  type        = string
  description = "Google Client ID for SSO Cognito App"
}

variable "google_client_secret" {
  type        = string
  description = "Google Client Secret for SSO Cognito App"
}

variable "sentry_auth_token" {
  type        = string
  description = "Sentry Auth Token"
}

variable "conduktor_admin_password" {
  type        = string
  description = "Admin password for Conduktor service"
}

variable "rudderstack_data_plane_url" {
  type        = string
  description = "Rudderstack Data Plane URL"
}

variable "rudderstack_write_key" {
  type        = string
  description = "Rudderstack Write Key"
}
