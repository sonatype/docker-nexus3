provider "aws" {
  region  = "ap-northeast-1"
  version = "~> 4.0"
}

terraform {
  backend "s3" {
    bucket = "paidy-terraform-state-shared-artifacts"
    key    = "microservices/shared/docker-nexus3"
    region = "ap-northeast-1"
  }
}

