# NOTE: place update the terraform required versions and providers here

# EXAMPLE: Uncomment and validate values

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "2.4.2"
    }

    twingate = {
      source  = "Twingate/twingate"
      version = ">= 2.0.1"
    }
  }
}
