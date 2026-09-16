variable "name" {
  type        = string
  description = "Name prefix. Also the SSM parameter path the facts are written under."
}

variable "output_dir" {
  type        = string
  description = "Directory the inventory configuration is written to. It must already exist, and the files in it are safe to commit."
}

variable "discovery_tags" {
  type        = map(string)
  description = <<-EOT
    Tags identifying the hosts this inventory covers, such as
    { Project = "storefront", Environment = "production" }.

    Ansible discovers hosts by these tags at run time. Nothing here names an
    instance, which is what lets the inventory describe an autoscaling group.
  EOT

  validation {
    condition     = length(var.discovery_tags) > 0
    error_message = "At least one discovery tag is required, or the inventory would match every instance in the account."
  }
}

variable "regions" {
  type        = list(string)
  description = "Regions to discover hosts in."

  validation {
    condition     = length(var.regions) > 0
    error_message = "At least one region is required."
  }
}

variable "group_by_tag" {
  type        = string
  description = "Tag whose value becomes the Ansible group. Role is the usual choice, and instance-fleet sets it."
  default     = "Role"
}

variable "ssh_user" {
  type        = string
  description = "Default remote user, which varies by AMI family: ubuntu, ec2-user, admin, rocky."
  default     = "ubuntu"
}

variable "connection" {
  type        = string
  description = <<-EOT
    How Ansible reaches a host.

    `ssm` tunnels through Systems Manager: no bastion, no open port 22, no key
    to distribute, and it works for a host with no public address. It needs the
    SSM agent on the instance and the session-manager-plugin on the runner.

    `ssh` connects directly, for an AMI without the agent.
  EOT
  default     = "ssm"

  validation {
    condition     = contains(["ssm", "ssh"], var.connection)
    error_message = "The connection must be ssm or ssh."
  }
}

variable "ssm_bucket_name" {
  type        = string
  description = "S3 bucket the SSM connection transfers files through. The aws_ssm connection plugin moves every module it runs through this bucket, not only copied files, so a playbook over SSM needs it. Only the machine running Ansible needs access to it; nodes fetch through presigned URLs."
  default     = null
}

variable "facts" {
  type        = map(string)
  description = <<-EOT
    Values every host should know: endpoints, bucket names and secret ARNs.

    Written to SSM Parameter Store rather than to a file, so every operator and
    every CI runner reads the same values, and a stale local copy cannot exist.
  EOT
  default     = {}
}

variable "group_vars" {
  type        = map(map(string))
  description = "Variables per Ansible group, keyed by group name. Written as group_vars files, which are configuration rather than state and belong in git. With facts set, group_vars/all.yml also carries the terraform_facts lookup."
  default     = {}

  validation {
    condition     = !contains(keys(lookup(var.group_vars, "all", {})), "terraform_facts")
    error_message = "The all group may not set terraform_facts, which the module writes as the lookup for the facts parameter."
  }
}

variable "facts_parameter_tier" {
  type        = string
  description = "SSM parameter tier. Advanced raises the value limit to 8 KB and is billed monthly per parameter."
  default     = "Standard"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the facts. Null uses the AWS-managed SSM key."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the SSM parameters."
  default     = {}
}
