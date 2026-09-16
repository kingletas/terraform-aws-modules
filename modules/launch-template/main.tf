locals {
  tags = merge(var.tags, { Name = var.name })

  root_device_name = coalesce(var.root_volume.device_name, data.aws_ami.this.root_device_name)
}

# The root device name differs between AMI families, so it is read from the image.
data "aws_ami" "this" {
  include_deprecated = true

  filter {
    name   = "image-id"
    values = [var.image_id]
  }
}

resource "aws_launch_template" "this" {
  name_prefix = format("%s-", var.name)
  description = var.description

  image_id      = var.image_id
  instance_type = var.instance_requirements == null ? var.instance_type : null
  key_name      = var.key_name

  user_data = var.user_data == null ? null : base64encode(var.user_data)

  vpc_security_group_ids = var.associate_public_ip_address ? null : var.security_group_ids

  dynamic "network_interfaces" {
    for_each = var.associate_public_ip_address ? [1] : []

    content {
      associate_public_ip_address = true
      security_groups             = var.security_group_ids
      delete_on_termination       = true
    }
  }

  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile_arn == null ? [] : [var.iam_instance_profile_arn]

    content {
      arn = iam_instance_profile.value
    }
  }

  block_device_mappings {
    device_name = local.root_device_name

    ebs {
      volume_type           = var.root_volume.type
      volume_size           = var.root_volume.size
      iops                  = contains(["gp3", "io1", "io2"], var.root_volume.type) ? var.root_volume.iops : null
      throughput            = var.root_volume.type == "gp3" ? var.root_volume.throughput : null
      delete_on_termination = var.root_volume.delete_on_termination
      encrypted             = true
      kms_key_id            = var.kms_key_id
    }
  }

  dynamic "block_device_mappings" {
    for_each = var.extra_volumes

    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_type           = block_device_mappings.value.type
        volume_size           = block_device_mappings.value.size
        iops                  = contains(["gp3", "io1", "io2"], block_device_mappings.value.type) ? block_device_mappings.value.iops : null
        throughput            = block_device_mappings.value.type == "gp3" ? block_device_mappings.value.throughput : null
        delete_on_termination = block_device_mappings.value.delete_on_termination
        encrypted             = true
        kms_key_id            = var.kms_key_id
      }
    }
  }

  dynamic "instance_requirements" {
    for_each = var.instance_requirements == null ? [] : [var.instance_requirements]

    content {
      vcpu_count {
        min = instance_requirements.value.vcpu_min
        max = instance_requirements.value.vcpu_max
      }

      memory_mib {
        min = instance_requirements.value.memory_mib_min
        max = instance_requirements.value.memory_mib_max
      }
    }
  }

  monitoring {
    enabled = var.detailed_monitoring
  }

  # IMDSv2 only, and one hop, so a container on the instance cannot read the role credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = var.instance_metadata_tags ? "enabled" : "disabled"
  }

  capacity_reservation_specification {
    capacity_reservation_preference = var.capacity_reservation_preference
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  tag_specifications {
    resource_type = "network-interface"
    tags          = local.tags
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true

    precondition {
      condition = !var.instance_metadata_tags || alltrue([
        for key in keys(local.tags) : can(regex("^[A-Za-z0-9+=.,_:@-]+$", key)) && !contains([".", "..", "_index"], key)
      ])
      error_message = "With instance_metadata_tags on, AWS refuses a tag key containing anything but letters, digits and + - = . , _ : @, or one that is ., .. or _index."
    }
  }
}
