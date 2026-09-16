# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name      = "plan-test"
  hash_key  = "source"
  range_key = "run_started_at"

  attributes = [
    { name = "source", type = "S" },
    { name = "run_started_at", type = "N" },
    { name = "status", type = "S" },
  ]
}

run "declares_index_keys_with_key_schema" {
  command = plan

  variables {
    global_secondary_indexes = {
      by_status = { hash_key = "status", range_key = "run_started_at" }
      by_source = { hash_key = "source" }
    }
  }

  assert {
    condition = one([for index in aws_dynamodb_table.this.global_secondary_index : index.key_schema if index.name == "by_status"]) == tolist([
      { attribute_name = "status", key_type = "HASH" },
      { attribute_name = "run_started_at", key_type = "RANGE" },
    ])
    error_message = "An index with a sort key must declare the partition key then the sort key in key_schema."
  }

  assert {
    condition = one([for index in aws_dynamodb_table.this.global_secondary_index : index.key_schema if index.name == "by_source"]) == tolist([
      { attribute_name = "source", key_type = "HASH" },
    ])
    error_message = "An index without a sort key must declare only its partition key."
  }
}
