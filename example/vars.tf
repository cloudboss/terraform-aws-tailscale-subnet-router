locals {
  ami = {
    name = "tailscale-v1.88.3"
  }

  autoscaling = {
    instance_type = "t3a.nano"
  }

  aws_region = "us-east-1"

  enable_nat_gateway = true

  kms_key_id = "alias/credentials"

  ssh_key = "easyto"

  stack_key = "tail"

  subnet_ids = [
    "subnet-ce19ab6789a0f558b",
    "subnet-770acebbb9c051efa",
    "subnet-a9d33d85eef79e604",
  ]

  tailscale = {
    authkey_ssm_path = "/tail/authkey"
  }

  vpc_id = "vpc-cfaf8fae40a4beef1"
}
