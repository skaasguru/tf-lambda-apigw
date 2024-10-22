terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.72.1"
    }

    archive = {
      source = "hashicorp/archive"
      version = "2.6.0"
    }

    null = {
      source = "hashicorp/null"
      version = "3.2.3"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "archive" {}

provider "null" {}
