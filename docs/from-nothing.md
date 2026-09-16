# From nothing to a planned stack

By the end of this guide you will have planned a real AWS stack from these modules on your own machine, without an AWS account, in about ten minutes. Then you will use one module in a project of your own.

## Contents

- [What this is](#what-this-is)
- [Step 1: get the tools](#step-1-get-the-tools)
- [Step 2: clone the repository](#step-2-clone-the-repository)
- [Step 3: plan an example without an AWS account](#step-3-plan-an-example-without-an-aws-account)
- [Step 4: plan it against real AWS](#step-4-plan-it-against-real-aws)
- [Step 5: use a module in your own project](#step-5-use-a-module-in-your-own-project)
- [What the modules do by default](#what-the-modules-do-by-default)
- [Where to go next](#where-to-go-next)

## What this is

A library of Terraform modules for AWS, and a set of examples that put them together into stacks you would actually run: a Magento store, a container platform, a data warehouse.

Each module does one job. The VPC module builds a VPC; the security group module builds a security group. You compose them yourself, the way the examples do.

## Step 1: get the tools

The versions the repository is checked with live in `.tool-versions` at the top of the repository:

```text
terraform 1.16.2
tflint 0.64.0
terraform-docs 0.24.0
checkov 3.3.15
conftest 0.62.0
```

**You only need Terraform, `make` and `bash` to follow this guide.** The other four tools are for `make check`, which you run before changing a module.

Install Terraform from [HashiCorp's site](https://developer.hashicorp.com/terraform/install). When you need the others, get them from their release pages: [tflint](https://github.com/terraform-linters/tflint/releases), [terraform-docs](https://github.com/terraform-docs/terraform-docs/releases) and [conftest](https://github.com/open-policy-agent/conftest/releases). Install checkov with `pip install checkov==3.3.15`. Then check Terraform's version:

```bash
terraform version
```

Any Terraform 1.9 or later works for using the modules. The check scripts are stricter about the other tools: they refuse a version of tflint, terraform-docs, checkov or conftest that differs from `.tool-versions`, because each version reports differently and you would get false failures.

## Step 2: clone the repository

```bash
git clone https://github.com/kingletas/terraform-aws-modules.git && cd terraform-aws-modules
```

`make help` lists everything the repository can do:

```bash
make help
```

## Step 3: plan an example without an AWS account

Every example has a plan test. It runs `terraform plan` against **mock providers**: stand-ins that answer the way AWS would, so every expression is evaluated with real values and nothing is created.

Start with the smallest example, two instances in a private VPC. From the top of the repository:

```bash
make test DIR=examples/ec2-in-vpc
```

`make test` runs with fake AWS credentials, so even a test that goes wrong cannot reach an AWS account.

A passing run looks like this:

```text
tests/plan.tftest.hcl... in progress
  run "plans_with_real_values"... pass
tests/plan.tftest.hcl... tearing down
tests/plan.tftest.hcl... pass

Success! 1 passed, 0 failed.
```

That is a full plan of the stack (a VPC, subnets across two zones, a NAT gateway, flow logs, an IAM role and two instances) checked without touching AWS.

To run every example's test and every module's own test, from the top of the repository:

```bash
make plan-test
```

If one fails, the error names the module and the line. A common cause is a `for_each` keyed on a value that only exists after apply. Key it on a name you know in advance instead.

## Step 4: plan it against real AWS

This needs AWS credentials. Anything that works for the AWS CLI works here: a profile, IAM Identity Center (SSO), or environment variables.

From the top of the repository, move into the example and initialise it:

```bash
cd examples/ec2-in-vpc
```

```bash
terraform init
```

Then plan it:

```bash
terraform plan
```

The plan shows everything that would be created. **Read it before applying.** This example runs a NAT gateway, which AWS bills by the hour whether anything uses it or not.

When you are ready:

```bash
terraform apply
```

When you are done, destroy it so the NAT gateway stops billing:

```bash
terraform destroy
```

Try a module in an account where a mistake is cheap before you use it in production, and read its README for the prerequisites it lists, such as account-level roles or settings that must already exist.

## Step 5: use a module in your own project

In your own Terraform, point `source` at a module and pin a release with `?ref=`. Without the pin you get whatever is on the default branch at the time you run `terraform init`.

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=v0.3.1"

  name               = "platform"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

module "web_sg" {
  source = "github.com/kingletas/terraform-aws-modules//modules/security-group?ref=v0.3.1"

  name        = "platform-web"
  description = "Web servers"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https = {
      description = "HTTPS from inside the VPC"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = module.vpc.cidr_block
    }
  }
}
```

Then fetch the modules:

```bash
terraform init
```

Each module's README lists every input and output. Required inputs have no default; everything else has a safe one. The [README](../README.md#versioning-and-pinning) explains how releases are versioned and how to pin to a commit.

## What the modules do by default

- **Encryption is on wherever AWS supports it**: volumes, buckets, queues, databases, logs.
- **Nothing is public by default.** Buckets block public access, instances get no public address, databases are private.
- **Instances require IMDSv2**, which closes the most common way to steal an instance's credentials through its metadata service.
- **Collections are keyed by name, not position.** Removing the second of three rules removes that rule and leaves the third alone.
- **A first plan does not depend on values from apply.** Every collection that becomes resources has keys you know in advance.
- **Each example says what it costs** and what it does not do.

## Where to go next

- [The module list](../README.md#whats-here): what each module builds
- [The examples](../examples): each README explains the decisions behind the stack
- [CONTRIBUTING.md](../CONTRIBUTING.md): how to add or change a module
