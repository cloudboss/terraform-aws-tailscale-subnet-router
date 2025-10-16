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

variable "ami" {
  type = object({
    filters = optional(list(object({
      name   = string
      values = list(string)
    })), [])
    most_recent = optional(bool, true)
    name        = optional(string, "tailscale-v1.88.3")
    owner       = optional(string, "256008164056")
  })
  description = "Configuration of the AMI for instances. One of filters or name must be set."

  default = {}
}

variable "autoscaling" {
  type = any

  default = {
    instance_type = "t3.micro"
  }
}

variable "enable_nat_gateway" {
  type = bool

  default = false
}

variable "extra_security_group_ids" {
  type = list(string)

  default = []
}

variable "iam" {
  type = object({
    extra_policy_arns    = optional(list(string), [])
    permissions_boundary = optional(string, null)
  })

  default = {}
}

variable "lambda_configure_vpc" {
  type = bool

  default = false
}

variable "kms_key_id" {
  type = string

  default = null
}

variable "ssh_key" {
  type = string

  default = null
}

variable "stack_key" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "tags" {
  type = map(string)

  default = null
}

variable "tailscale" {
  type = object({
    authkey_ssm_path      = string
    accept_dns            = optional(bool, false)
    extra_args            = optional(list(string), [])
    route_vpc_cidr        = optional(bool, true)
    routes                = optional(list(string), [])
    state_dir             = optional(string, "/tmp")
    tailscaled_extra_args = optional(list(string), [])
    userspace             = optional(bool, false)
  })
}

variable "volume" {
  type = object({
    iops = optional(number, null)
    name = optional(string, "/dev/xvda")
    size = optional(number, 1)
    type = optional(string, "gp3")
  })

  default = {}
}

variable "vpc_id" {
  type = string
}
