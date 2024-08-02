# tailscale-subnet-router

A Terraform module to deploy a [Tailscale subnet router](https://tailscale.com/kb/1019/subnets) into a VPC. It can also act as a NAT gateway for the VPC.

The AMI is built from the [official Docker image](https://hub.docker.com/r/tailscale/tailscale) by [easyto](https://github.com/cloudboss/easyto), which enables container-like management of instances directly on EC2.

See the `example` directory for a sample root module that uses this module.

# Requirements

The Tailscale [auth key](https://tailscale.com/kb/1085/auth-keys) must be stored in an SSM parameter, optionally encrypted with a customer managed KMS key.

# Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| ami | Configuration of the AMI for instances. | [object](#ami-object) | `{}` | no |
| autoscaling | Configuration of the autoscaling group. | [object](#autoscaling-object) | N/A | yes |
| enable\_nat\_gateway | Whether or not to configure the instance as a NAT gateway. | bool | `false` | no |
| extra\_security\_group\_ids | Extra security groups to assign to the instances. | list(string) | `[]` | no |
| iam | Configuration for IAM. | [object](#iam-object) | `{}` | no |
| lambda\_configure\_vpc | Whether or not to configure the VPC for the [lambda function](https://github.com/cloudboss/terraform-aws-asg-enable-router). | bool | `false` | no |
| kms\_key\_id | ID of the KMS key used to encrypt the SSM parameter containing the Tailscale auth key, if used. | bool | `null` | no |
| name | Name of the lambda and associated cloud resources. | string | N/A | yes |
| ssh\_key | Name of an ssh key to assign to EC2 instances. | string | `null` | no |
| subnet\_ids | Configuration of subnets. | list(string) | N/A | yes |
| tags | Tags to assign to cloud resources. | map(string) | `null` | no |
| tailscale | Configuration for Tailscale. | [object](#tailscale-object) | N/A | yes |
| volume | Configuration of the root EBS volume of the instances. | [object](#volume-object) | `{}` | no |

## ami object

The ami object has the following structure.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| filters | Filters to search for an AMI. Required if `name` is not defined. | [object](#ami-filters-object) | `[]` | conditional |
| most\_recent | Whether or not to return the most recent image found. | bool | `true` | no |
| name | Name of the AMI. Required if `filters` is not defined. | string | `tailscale-v1.70.0` | conditional |
| owner | AWS account where the image is located. | string | `256008164056` | no |

## autoscaling object

The autoscaling object has the following structure.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| instance\_refresh | Configuration of instance refresh. See the upstream [asg module](https://github.com/cloudboss/terraform-aws-asg/blob/v0.1.0/variables.tf#L114-L136) for the structure. | object | `{ strategy = "Rolling" }` | no |
| instance\_type | Type of the EC2 instances. Required if `mixed_instances_overrides` is not defined. | string | `null` | conditional |
| instances\_desired | The initial number of instances desired. | number | `1` | no |
| instances\_max | The maximum number of instances desired. | number | `1` | no |
| instances\_min | The minimum number of instances desired. | number | `1` | no |
| max\_instance\_lifetime | The maximum lifetime of instances in seconds. | number | `null` | no |
| mixed\_instances\_distribution | The distribution of mixed instances. See the upstream [asg module](https://github.com/cloudboss/terraform-aws-asg/blob/v0.1.0/variables.tf#L169-L181) for the structure. | object | `null` | no |
| mixed\_instances\_overrides | A list of override objects for mixed instances. See the upstream [asg module](https://github.com/cloudboss/terraform-aws-asg/blob/v0.1.0/variables.tf#L183-f2441) for the structure of the object. Required if `instance_type` is not defined. | list(object) | `null` | conditional |
| suspended\_processes | A list of autoscaling processes to suspend. | list(string) | `[]` | no |
| termination\_policies | A list of policies to decide how instances should be terminated. | list(string) | `[]` | no |

## iam object

The iam object has the following structure.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| extra\_policy\_arns | Additional policy ARNs to assign to the instance IAM role. | list(string) | `[]` | no |
| permissions\_boundary | An IAM policy ARN to use as a permissions boundary for the IAM role. | string | `null` | no |

## tailscale object

The tailscale object has the following structure.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| authkey\_ssm\_path | Path of SSM parameter where the Tailscale auth key is stored. | string | N/A | yes |
| accept\_dns | Whether or not to accept DNS. | bool | `false` | no |
| extra\_args | Additional arguments to pass to `tailscale set`. | list(string) | `[]` | no |
| route\_vpc\_cidr | Whether or not to advertise the VPC CIDR. | bool | `true` | no |
| routes | A list of specific subnets to advertise. | list(string) | `[]` | no |
| state\_dir | Directory where state is stored. | string | `/tmp` | no |
| tailscaled\_extra\_args | Additional arguments to pass to `tailscaled`. | list(string) | `[]` | no |
| userspace | Whether or not to use userspace networking. | bool | `false` | no |

## volume object

The volume object has the following structure.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| iops | Number of IOPs given to the volume. | number | `null` | no |
| name | Name of the volume. | string | `/dev/xvda` | no |
| size | Size of the volume in GB. | number | `1` | no |
| type | Type of the EBS volume. | string | `gp3` | no |

# Outputs

| Name | Description |
|------|-------------|
| asg | An object containing autoscaling group related resources. |
| lambda | An object containing lambda related resources. |
