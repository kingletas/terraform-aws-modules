# Plans the module with IDs from resources created in the same plan, which are
# unknown until apply, which a for_each or count must not depend on.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_ids_unknown_until_apply" {
  command = plan

  module {
    source = "./tests/fixture"
  }
}
