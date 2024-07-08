
### THE BACKEND ###
## NOTE: could use dynamoLock table if needed

terraform {
  backend "s3" {
    bucket               = "fakebusiness-terraform"
    key                  = "aws.tfstate"
    region               = "us-east-1"
    workspace_key_prefix = "aws"
    encrypt              = true
  }
}

### Main Provider ###
provider "aws" {
  region = "us-east-1"

  # These tags will apply to all resources
  default_tags {
    tags = {
      Environment = terraform.workspace
      Stage       = terraform.workspace
      Creator     = "Terraform"
    }
  }
}

provider "twingate" {
  api_token = var.twingate_token
  network   = "fakebusiness1"
}

