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
    client_root_certificate_body = "mock-client-ca-certificate"
    client_root_private_key      = "mock-client-ca-key"
    certificate_chain            = "mock-certificate-chain"
  }
}
