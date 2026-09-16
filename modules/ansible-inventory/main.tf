locals {
  facts_path = format("/%s/ansible/facts", trim(var.name, "/"))

  # The aws_ec2 plugin's own configuration. It contains no addresses and no
  # host names, which is exactly why it stays correct when an autoscaling group
  # replaces every instance it describes.
  inventory_config = {
    plugin  = "amazon.aws.aws_ec2"
    regions = var.regions

    filters = merge(
      { "instance-state-name" = ["running"] },
      { for key, value in var.discovery_tags : format("tag:%s", key) => [value] },
    )

    # Groups come from the tag rather than from a list, so a new role appears
    # in the inventory without this file changing.
    keyed_groups = [
      {
        key               = format("tags.%s", var.group_by_tag)
        prefix            = ""
        separator         = ""
        leading_separator = false
      },
      {
        key    = "placement.availability_zone"
        prefix = "az"
      },
    ]

    # Instances in an autoscaling group share a Name tag, so only the instance ID tells them apart.
    hostnames = ["instance-id"]

    compose = merge(
      {
        ansible_user = format("'%s'", var.ssh_user)
      },

      var.connection == "ssm" ? {
        # Reaching an instance with no public address, no open port and no key.
        ansible_connection          = "'community.aws.aws_ssm'"
        ansible_aws_ssm_instance_id = "instance_id"
        ansible_aws_ssm_region      = "placement.region"
      } : {},

      var.connection == "ssm" && var.ssm_bucket_name != null ? {
        ansible_aws_ssm_bucket_name = format("'%s'", var.ssm_bucket_name)
      } : {},

      var.connection == "ssh" ? {
        ansible_host = "private_ip_address"
      } : {},
    )

    strict = false
  }

  facts_lookup = length(var.facts) > 0 ? {
    terraform_facts = format("{{ lookup('amazon.aws.aws_ssm', '%s', region='%s') | from_json }}", local.facts_path, var.regions[0])
  } : {}

  # The facts lookup joins the caller's own "all" variables, so one file holds both.
  group_var_files = {
    for group, vars in merge(length(local.facts_lookup) > 0 ? { all = tomap({}) } : {}, var.group_vars) :
    group => yamlencode(group == "all" ? merge(vars, local.facts_lookup) : vars)
  }
}

# Committed, not generated per operator: it holds no state, only the rule for
# finding hosts.
resource "local_file" "inventory" {
  filename        = format("%s/aws_ec2.yml", var.output_dir)
  content         = yamlencode(local.inventory_config)
  file_permission = "0644"
}

resource "local_file" "group_vars" {
  for_each = local.group_var_files

  filename        = format("%s/group_vars/%s.yml", var.output_dir, each.key)
  content         = each.value
  file_permission = "0644"
}

# One shared copy of the facts. Every operator and every CI runner reads the
# same values, and a stale copy on somebody's laptop cannot exist.
resource "aws_ssm_parameter" "facts" {
  count = length(var.facts) > 0 ? 1 : 0

  name        = local.facts_path
  description = format("Terraform-supplied facts for %s", var.name)
  type        = "SecureString"
  tier        = var.facts_parameter_tier
  key_id      = var.kms_key_arn
  value       = jsonencode(var.facts)

  tags = merge(var.tags, { Name = local.facts_path })
}
