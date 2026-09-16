# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    server_certificate_body      = "mock-server-certificate"
    server_private_key           = "mock-server-key"
    client_root_certificate_body = "mock-client-certificate"
    client_root_private_key      = "mock-client-key"
    certificate_chain            = "mock-certificate-chain"
  }

  assert {
    condition     = tonumber(split("/", var.client_cidr_block)[1]) >= 12 && tonumber(split("/", var.client_cidr_block)[1]) <= 22
    error_message = "The default client CIDR must be between a /12 and a /22, which is what Client VPN accepts."
  }
}
