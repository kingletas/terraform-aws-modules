locals {
  # Every instance in the fleet, flattened from roles into one map keyed by the instance name.
  instances = merge([
    for role_name, role in var.roles : {
      for index in range(role.count) :
      (role.numbered
        ? format("%s-%s-%02d", var.name, role_name, index + 1)
        : format("%s-%s", var.name, role_name)
        ) => {
        role    = role_name
        ordinal = index + 1

        ami_id        = coalesce(role.ami_id, var.defaults.ami_id)
        instance_type = coalesce(role.instance_type, var.defaults.instance_type)

        # Round-robin across whichever subnet list applies, so a role of three
        # spreads across zones without the caller working out the arithmetic.
        subnet_id = element(
          coalesce(role.subnet_ids, var.defaults.subnet_ids),
          index
        )

        security_group_ids   = coalesce(role.security_group_ids, var.defaults.security_group_ids)
        key_name             = try(coalesce(role.key_name, var.defaults.key_name), null)
        iam_instance_profile = try(coalesce(role.iam_instance_profile, var.defaults.iam_instance_profile), null)

        associate_public_ip_address = coalesce(role.associate_public_ip_address, var.defaults.associate_public_ip_address)
        assign_elastic_ip           = role.assign_elastic_ip
        source_dest_check           = coalesce(role.source_dest_check, var.defaults.source_dest_check)
        monitoring                  = coalesce(role.monitoring, var.defaults.monitoring)
        ebs_optimized               = coalesce(role.ebs_optimized, var.defaults.ebs_optimized)

        root_volume_type       = coalesce(role.root_volume_type, var.defaults.root_volume_type)
        root_volume_size       = coalesce(role.root_volume_size, var.defaults.root_volume_size)
        root_volume_iops       = try(coalesce(role.root_volume_iops, var.defaults.root_volume_iops), null)
        root_volume_throughput = try(coalesce(role.root_volume_throughput, var.defaults.root_volume_throughput), null)

        kms_key_id = try(coalesce(role.kms_key_id, var.defaults.kms_key_id), null)
        user_data  = try(coalesce(role.user_data, var.defaults.user_data), null)

        extra_volumes = role.extra_volumes
        tags          = role.tags
      }
    }
  ]...)

  subnets_with_volumes = {
    for name, instance in local.instances : name => instance.subnet_id if length(instance.extra_volumes) > 0
  }

  elastic_ips = { for name, instance in local.instances : name => instance if instance.assign_elastic_ip }

  volume_attachments = merge([
    for instance_name, instance in local.instances : {
      for volume_name, volume in instance.extra_volumes :
      format("%s-%s", instance_name, volume_name) => {
        instance_name = instance_name
        volume_name   = volume_name
        volume        = volume
      }
    }
  ]...)
}

resource "aws_instance" "this" {
  # checkov:skip=CKV_AWS_126: detailed monitoring defaults true in the defaults object
  # checkov:skip=CKV_AWS_135: ebs_optimized defaults true in the defaults object
  for_each = local.instances

  ami                         = each.value.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = each.value.security_group_ids
  key_name                    = each.value.key_name
  iam_instance_profile        = each.value.iam_instance_profile
  associate_public_ip_address = each.value.associate_public_ip_address
  source_dest_check           = each.value.source_dest_check
  monitoring                  = each.value.monitoring
  ebs_optimized               = each.value.ebs_optimized
  user_data                   = each.value.user_data

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["gp3", "io1", "io2"], each.value.root_volume_type) ? each.value.root_volume_iops : null
    throughput            = each.value.root_volume_type == "gp3" ? each.value.root_volume_throughput : null
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = each.value.kms_key_id

    tags = merge(var.tags, each.value.tags, { Name = format("%s-root", each.key) })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = var.instance_metadata_tags ? "enabled" : "disabled"
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.key
    Role = each.value.role
  })

  # Destroy-first, so an extra volume is detached from the old instance before it is attached to the new one.
  lifecycle {
    precondition {
      condition = !var.instance_metadata_tags || alltrue([
        for key in keys(merge(var.tags, each.value.tags, { Name = "", Role = "" })) :
        can(regex("^[A-Za-z0-9+=.,_:@-]+$", key)) && !contains([".", "..", "_index"], key)
      ])
      error_message = "With instance_metadata_tags on, AWS refuses a tag key containing anything but letters, digits and + - = . , _ : @, or one that is ., .. or _index."
    }
  }
}

# A bastion or a NAT-style appliance needs an address that survives a replacement.
resource "aws_eip" "this" {
  for_each = local.elastic_ips

  domain   = "vpc"
  instance = aws_instance.this[each.key].id

  tags = merge(var.tags, each.value.tags, { Name = each.key })
}

# A volume takes its zone from the subnet, which outlives any one instance, so replacing an instance keeps the volume.
data "aws_subnet" "volume" {
  for_each = local.subnets_with_volumes

  id = each.value
}

resource "aws_ebs_volume" "this" {
  for_each = local.volume_attachments

  availability_zone = data.aws_subnet.volume[each.value.instance_name].availability_zone
  size              = each.value.volume.size
  type              = each.value.volume.type
  iops              = contains(["gp3", "io1", "io2"], each.value.volume.type) ? each.value.volume.iops : null
  throughput        = each.value.volume.type == "gp3" ? each.value.volume.throughput : null
  encrypted         = true
  kms_key_id        = local.instances[each.value.instance_name].kms_key_id

  tags = merge(var.tags, { Name = each.key })
}

resource "aws_volume_attachment" "this" {
  for_each = local.volume_attachments

  device_name = each.value.volume.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value.instance_name].id

  # Detaching a mounted volume hangs unless the instance is stopped first.
  stop_instance_before_detaching = true
}
