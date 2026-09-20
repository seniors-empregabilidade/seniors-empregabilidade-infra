terraform {
  required_version = ">= 1.11"

  backend "s3" {
    bucket       = "seniors-tfstate-951614974043"
    key          = "prod/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "seniors"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
