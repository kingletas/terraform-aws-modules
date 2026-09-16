# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  assert {
    condition     = length(module.app.instance_ids) == 2
    error_message = "The example must launch instance_count application instances."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.session_manager.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The instances are reached through Session Manager, so their role must carry its managed policy."
  }

  assert {
    condition     = toset(flatten([for principal in data.aws_iam_policy_document.assume_role.statement[0].principals : principal.identifiers])) == toset(["ec2.amazonaws.com"])
    error_message = "Only EC2 may assume the application role."
  }
}
