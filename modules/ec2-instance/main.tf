locals {
  instances = {
    for index in range(var.instance_count) :
    format("%s-%02d", var.name, index + 1) => {
      subnet_id = var.subnet_ids[index % length(var.subnet_ids)]
    }
  }

  volume_attachments = merge([
    for instance_name, instance in local.instances : {
      for volume_name, volume in var.extra_volumes :
      format("%s-%s", instance_name, volume_name) => {
        instance_name = instance_name
        volume_name   = volume_name
      }
    }
  ]...)
}

resource "aws_instance" "this" {
  for_each = local.instances

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = var.associate_public_ip_address

  ebs_optimized = var.ebs_optimized
  monitoring    = var.monitoring

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  root_block_device {
    volume_type           = var.root_volume.type
    volume_size           = var.root_volume.size
    iops                  = contains(["gp3", "io1", "io2"], var.root_volume.type) ? var.root_volume.iops : null
    throughput            = var.root_volume.type == "gp3" ? var.root_volume.throughput : null
    delete_on_termination = var.root_volume.delete_on_termination
    encrypted             = true
    kms_key_id            = var.kms_key_id

    tags = merge(var.tags, { Name = format("%s-root", each.key) })
  }

  # IMDSv2 only. Token-less metadata requests are what server-side request forgery reaches.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(var.tags, { Name = each.key })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ebs_volume" "this" {
  for_each = local.volume_attachments

  availability_zone = aws_instance.this[each.value.instance_name].availability_zone
  size              = var.extra_volumes[each.value.volume_name].size
  type              = var.extra_volumes[each.value.volume_name].type
  iops              = contains(["gp3", "io1", "io2"], var.extra_volumes[each.value.volume_name].type) ? var.extra_volumes[each.value.volume_name].iops : null
  throughput        = var.extra_volumes[each.value.volume_name].type == "gp3" ? var.extra_volumes[each.value.volume_name].throughput : null
  encrypted         = true
  kms_key_id        = var.kms_key_id

  tags = merge(var.tags, { Name = each.key })
}

resource "aws_volume_attachment" "this" {
  for_each = local.volume_attachments

  device_name = var.extra_volumes[each.value.volume_name].device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value.instance_name].id

  # Detaching a mounted volume hangs unless the instance is stopped first.
  stop_instance_before_detaching = true
}
