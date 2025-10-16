# Copyright © 2024 Joseph Wright <joseph@cloudboss.co>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

locals {
  aws_account_id = data.aws_caller_identity.me.account_id

  aws_region = data.aws_region.here.name

  iam_policy_statement_kms = (
    var.kms_key_id == null
    ? []
    : [
      {
        Action   = ["kms:Decrypt"]
        Effect   = "Allow"
        Resource = [one(data.aws_kms_key.it[*].arn)]
      },
    ]
  )

  iam_policy_statement_ssm = [
    {
      Action = [
        "ssm:GetParameter",
        "ssm:GetParametersByPath",
      ]
      Effect   = "Allow"
      Resource = ["${local.ssm_arn_prefix}${var.tailscale.authkey_ssm_path}"]
    },
  ]

  iam_policy_statements = concat(
    local.iam_policy_statement_kms,
    local.iam_policy_statement_ssm,
  )

  init_scripts = (
    var.enable_nat_gateway
    ? [
      <<-EOF
      #!/bin/sh
      /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      EOF
    ]
    : []
  )

  lambda_vpc_config = (
    var.lambda_configure_vpc
    ? {
      id         = var.vpc_id
      subnet_ids = var.subnet_ids
    }
    : null
  )

  routes = toset(
    var.tailscale.route_vpc_cidr
    ? concat([data.aws_vpc.it.cidr_block], var.tailscale.routes)
    : var.tailscale.routes
  )

  security_group_ids = concat(
    [aws_security_group.it.id],
    var.extra_security_group_ids,
  )

  ssm_arn_prefix = "arn:aws:ssm:${local.aws_region}:${local.aws_account_id}:parameter"
}

data "aws_caller_identity" "me" {}

data "aws_region" "here" {}

data "aws_kms_key" "it" {
  count = var.kms_key_id == null ? 0 : 1

  key_id = var.kms_key_id
}

data "aws_vpc" "it" {
  id = var.vpc_id
}

resource "aws_security_group" "it" {
  name   = var.stack_key
  tags   = var.tags
  vpc_id = var.vpc_id
}

module "enable_router_lambda" {
  source  = "cloudboss/asg-enable-router/aws"
  version = "0.1.1"

  autoscaling_group_name   = var.stack_key
  iam_permissions_boundary = var.iam.permissions_boundary
  name                     = "${var.stack_key}-enable-router"
  tags                     = var.tags
  vpc_config               = local.lambda_vpc_config
}

module "security_group_rules" {
  source  = "cloudboss/security-group-rules/aws"
  version = "0.1.0"

  rules = [
    {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 41641
      ip_protocol = "udp"
      to_port     = 41641
      type        = "ingress"
    },
    {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 3478
      ip_protocol = "udp"
      to_port     = 3478
      type        = "egress"
    },
    {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      ip_protocol = "tcp"
      to_port     = 443
      type        = "egress"
    },
    {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      ip_protocol = "udp"
      to_port     = 443
      type        = "egress"
    },
    {
      cidr_ipv4   = data.aws_vpc.it.cidr_block
      ip_protocol = "-1"
      type        = "ingress"
    },
    {
      cidr_ipv4   = data.aws_vpc.it.cidr_block
      ip_protocol = "-1"
      type        = "egress"
    },
  ]
  security_group_id = aws_security_group.it.id
  tags              = var.tags
}

module "iam_role" {
  source  = "cloudboss/iam-role/aws"
  version = "0.1.0"

  trust_policy_statements = [
    {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    },
  ]
  create_instance_profile = true
  name                    = var.stack_key
  permissions_boundary    = var.iam.permissions_boundary
  policy_arns             = var.iam.extra_policy_arns
  policy_statements       = local.iam_policy_statements
  tags                    = var.tags
}

module "user_data" {
  source  = "cloudboss/easyto-user-data/aws"
  version = "0.2.0"

  env = [
    {
      name  = "TS_ACCEPT_DNS"
      value = tostring(var.tailscale.accept_dns)
    },
    {
      name  = "TS_EXTRA_ARGS"
      value = join(" ", var.tailscale.extra_args)
    },
    {
      name  = "TS_ROUTES"
      value = join(",", local.routes)
    },
    {
      name  = "TS_STATE_DIR"
      value = var.tailscale.state_dir
    },
    {
      name  = "TS_TAILSCALED_EXTRA_ARGS"
      value = join(" ", var.tailscale.tailscaled_extra_args)
    },
    {
      name  = "TS_USERSPACE"
      value = tostring(var.tailscale.userspace)
    },
  ]
  env-from = [
    {
      ssm = {
        name = "TS_AUTHKEY"
        path = var.tailscale.authkey_ssm_path
      }
    }
  ]
  init-scripts = local.init_scripts
  sysctls = [
    {
      name  = "net.ipv4.ip_forward"
      value = "1"
    },
    {
      name  = "net.ipv6.conf.all.forwarding"
      value = "1"
    },
  ]
}

module "asg" {
  source  = "cloudboss/asg/aws"
  version = "0.1.0"

  ami = var.ami
  block_device_mappings = [
    {
      device_name = var.volume.name
      ebs = {
        iops        = var.volume.iops
        volume_size = var.volume.size
        volume_type = var.volume.type
      }
    },
  ]
  instance_initiated_shutdown_behavior = "terminate"
  instance_refresh = try(var.autoscaling.instance_refresh, {
    strategy = "Rolling"
  })
  instance_type                = try(var.autoscaling.instance_type, null)
  instances_desired            = try(var.autoscaling.instances_desired, 1)
  instances_max                = try(var.autoscaling.instances_max, 1)
  instances_min                = try(var.autoscaling.instances_min, 1)
  iam_instance_profile         = module.iam_role.instance_profile.arn
  max_instance_lifetime        = try(var.autoscaling.max_instance_lifetime, null)
  mixed_instances_distribution = try(var.autoscaling.mixed_instances_distribution, {})
  mixed_instances_overrides    = try(var.autoscaling.mixed_instances_overrides, [])
  name                         = var.stack_key
  network_interfaces = try(var.autoscaling.network_interfaces, [
    {
      associate_public_ip_address = true
    },
  ])
  security_group_ids  = local.security_group_ids
  ssh_key             = var.ssh_key
  subnet_ids          = var.subnet_ids
  suspended_processes = try(var.autoscaling.suspended_processes, null)
  tags = {
    default = var.tags
  }
  termination_policies = try(var.autoscaling.termination_policies, null)
  user_data = {
    value = module.user_data.value
  }
  vpc_id = var.vpc_id

  depends_on = [module.enable_router_lambda]
}
