# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name       = "plan-test"
  subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
}

run "uses_the_engine_default_parameter_group_without_parameters" {
  command = plan

  assert {
    condition     = length(aws_elasticache_parameter_group.this) == 0 && local.parameter_group_name == null
    error_message = "Without parameters or sharding, no parameter group should be named."
  }
}

run "names_the_parameter_group_after_its_family" {
  command = plan

  variables {
    parameter_group_family = "redis6.x"
    parameters             = { maxmemory-policy = "volatile-lru" }
  }

  assert {
    condition     = aws_elasticache_parameter_group.this[0].name == "plan-test-params-redis6-x"
    error_message = "The parameter group name should change with its family, so a replacement does not collide with the old group."
  }
}

run "uses_the_cluster_default_parameter_group_when_sharded" {
  command = plan

  variables {
    num_node_groups        = 3
    parameter_group_family = "valkey8"
  }

  assert {
    condition     = local.parameter_group_name == "default.valkey8.cluster.on"
    error_message = "A sharded group with no parameters should use the family's cluster-mode default group."
  }
}

run "turns_cluster_mode_on_in_its_own_parameter_group_when_sharded" {
  command = plan

  variables {
    num_node_groups        = 2
    parameter_group_family = "valkey8"
    parameters             = { maxmemory-policy = "volatile-lru" }
  }

  assert {
    condition     = contains([for parameter in aws_elasticache_parameter_group.this[0].parameter : "${parameter.name}=${parameter.value}"], "cluster-enabled=yes")
    error_message = "A sharded group's own parameter group should set cluster-enabled to yes."
  }
}

run "refuses_sharding_without_a_family" {
  command = plan

  variables {
    num_node_groups = 2
  }

  expect_failures = [aws_elasticache_replication_group.this]
}
