terraform {
  required_version = "=1.9.2"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "=2.5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "=5.61.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-o2ym9tux"
    dynamodb_table = "terraform-state-lock"
    key            = "terraform/tail/terraform.tfstate"
    region         = "us-east-1"
  }
}

provider "aws" {
  region = local.aws_region
}

module "tailscale" {
  source  = "cloudboss/tailscale-subnet-router/aws"
  version = "0.1.0"

  ami                = local.ami
  autoscaling        = local.autoscaling
  enable_nat_gateway = local.enable_nat_gateway
  kms_key_id         = local.kms_key_id
  ssh_key            = local.ssh_key
  stack_key          = local.stack_key
  subnet_ids         = local.subnet_ids
  tailscale          = local.tailscale
  vpc_id             = local.vpc_id
}
