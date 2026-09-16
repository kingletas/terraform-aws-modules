# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "tls" {}
mock_provider "local" {}

run "plans_with_real_values" {
  command = plan

  variables {
    name = "plan-test"
  }

  assert {
    condition     = tls_private_key.this[0].algorithm == "ED25519" && length(aws_secretsmanager_secret.this) == 1
    error_message = "With no public key, the module should generate an ED25519 key and store it in Secrets Manager."
  }

  assert {
    condition     = aws_secretsmanager_secret.this[0].name == "ssh/plan-test" && length(local_sensitive_file.private_key) == 0
    error_message = "The stored key should be named after the key pair, and nothing written to disk unless asked."
  }
}

run "registers_a_supplied_public_key_without_generating_one" {
  command = plan

  variables {
    name       = "plan-test"
    public_key = "ssh-ed25519 AAAAplantestnotarealkey plan-test"
  }

  assert {
    condition     = length(tls_private_key.this) == 0 && length(aws_secretsmanager_secret.this) == 0
    error_message = "A supplied public key should mean no generated key and nothing stored."
  }

  assert {
    condition     = aws_key_pair.this.public_key == "ssh-ed25519 AAAAplantestnotarealkey plan-test"
    error_message = "The key pair should register the supplied public key."
  }
}
