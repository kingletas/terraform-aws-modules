# From nothing to a planned stack

By the end of this you'll have planned a real AWS stack from these modules, on your own machine, with no AWS account, in about ten minutes. Then you'll use one module in a project of your own.

## Contents

- [What this is](#what-this-is)
- [Step 1: get the tools](#step-1-get-the-tools)
- [Step 2: clone it](#step-2-clone-it)
- [Step 3: plan an example without an AWS account](#step-3-plan-an-example-without-an-aws-account)
- [Step 4: plan it against real AWS](#step-4-plan-it-against-real-aws)
- [Step 5: use a module in your own project](#step-5-use-a-module-in-your-own-project)
- [What you get for free](#what-you-get-for-free)
- [Where to go next](#where-to-go-next)

## What this is

A library of Terraform modules for AWS, and eleven examples that put them together into things you'd actually run: a Magento store, a container platform, a data warehouse.

Each module does one job. A VPC module builds a VPC; a security group module builds a security group. You compose them yourself, the way the examples do.

## Step 1: get the tools

The exact versions live in `.tool-versions` at the top of the repository:

```text
terraform 1.16.2
tflint 0.64.0
terraform-docs 0.24.0
checkov 3.3.15
```

**You only need Terraform to follow this guide.** The other three are for `make check`, which you run before changing a module.

Install Terraform from [HashiCorp's site](https://developer.hashicorp.com/terraform/install), and the others from their own release pages when you need them — [tflint](https://github.com/terraform-linters/tflint/releases), [terraform-docs](https://github.com/terraform-docs/terraform-docs/releases), and checkov with `pip install checkov==3.3.15`. Then check Terraform's version:

```bash
terraform version
```

Any newer 1.x works for using the modules. The check scripts are stricter: they refuse a different version of tflint or terraform-docs, because each version formats its output differently and you'd get false failures.

## Step 2: clone it

The repository is private, so your GitHub account needs access. Clone over SSH:

```bash
git clone git@github.com:kingletas/terraform-aws-modules.git && cd terraform-aws-modules
```

`make help` lists everything the repository can do:

```bash
make help
```

## Step 3: plan an example without an AWS account

Every example has a plan test. It runs `terraform plan` against **mock providers**: stand-ins that answer the way AWS would, so every expression is evaluated with real values and nothing is created.

Start with the smallest example, two instances in a private VPC:

```bash
cd examples/ec2-in-vpc && terraform init && terraform test
```

A passing run looks like this:

```text
tests/plan.tftest.hcl... in progress
  run "plans_with_real_values"... pass
tests/plan.tftest.hcl... tearing down
tests/plan.tftest.hcl... pass

Success! 1 passed, 0 failed.
```

**That's a real plan of 32 resources** — a VPC, subnets across two zones, a NAT gateway, flow logs, an IAM role and two instances — checked without touching AWS.

To plan every example, and every module no example uses, from the top of the repository:

```bash
make plan-test
```

If one fails, the error names the module and the line. The most common cause is a `for_each` keyed on a value that only exists after apply. Key it on a name you know in advance instead.

## Step 4: plan it against real AWS

This needs AWS credentials. Anything that works for the AWS CLI works here — a profile, SSO, or environment variables.

```bash
cd examples/ec2-in-vpc && terraform plan
```

The plan shows everything that would be created. **Read it before applying.** This example runs a NAT gateway, which AWS bills by the hour whether anything uses it or not.

When you're ready:

```bash
terraform apply
```

And when you're done, so the NAT gateway stops billing:

```bash
terraform destroy
```

**About twenty modules have never been applied against AWS by this project**: the ones a local emulator can't run, like RDS, OpenSearch and CloudFront. They're planned and statically checked. Apply them somewhere you can afford a mistake first.

## Step 5: use a module in your own project

In your own Terraform, point `source` at a module and pin a release with `?ref=`. Without the pin you get whatever is on the default branch that day.

```hcl
module "vpc" {
  source = "git::ssh://git@github.com/kingletas/terraform-aws-modules.git//modules/vpc?ref=v0.1.0"

  name               = "platform"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

module "web_sg" {
  source = "git::ssh://git@github.com/kingletas/terraform-aws-modules.git//modules/security-group?ref=v0.1.0"

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

**Use the `git::ssh://` form while the repository is private.** The shorter `github.com/…` form in the module READMEs fetches over HTTPS, and Terraform fails with an authentication error unless git has HTTPS credentials for GitHub.

Then fetch the modules:

```bash
terraform init
```

Each module's README lists every input and output. Required inputs have no default; everything else has a safe one.

## What you get for free

- **Encryption is on everywhere it can be** — volumes, buckets, queues, databases, logs.
- **Nothing is public by default.** Buckets block public access, instances get no public address, databases are private.
- **Instances require IMDSv2**, which closes the most common way to steal an instance's credentials.
- **Collections are keyed by name, not position.** Removing the second of three rules removes that rule and leaves the third alone.
- **Plans don't depend on values from apply.** Every collection that becomes resources has keys you know in advance, so a first `terraform plan` works.
- **Each example says what it costs** and what it deliberately doesn't do.

## Where to go next

- [The module list](../README.md#whats-here) — what each module builds
- [The examples](../examples) — each README explains the decisions behind the stack
- [CONTRIBUTING.md](../CONTRIBUTING.md) — how to add or change a module
