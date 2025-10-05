terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  backend "s3" {
    bucket  = "soat-tfstate-bucket"
    key     = "lambda-authorizer/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}