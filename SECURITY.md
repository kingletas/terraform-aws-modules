# Security policy

## Supported versions

Security fixes go to the `main` branch and are released as part of the current minor version. Upgrade to the latest release to pick one up.

## Reporting a vulnerability

Do not open a public issue or pull request for a security problem. Report it privately instead:

- **Preferred:** on GitHub, open the repository's **Security** tab and select **Report a vulnerability**. The report is visible only to you and the maintainers.
- **Alternative:** email **code@kingletas.com**.

Include:

- the module or example affected, and the release tag or commit you used
- what the module does wrong, and what an attacker could gain from it
- the inputs that reproduce it: a minimal Terraform configuration, or a failing `terraform test` run, is the clearest report
- any workaround you know of

Leave out real account IDs, credentials, state files and plan output. Invented values reproduce a module problem just as well.

## What happens next

You will get a reply confirming the report arrived, then an assessment of whether it is a vulnerability in this repository. A confirmed issue is fixed with a test that reproduces it, and the CHANGELOG entry for the release that carries the fix says what was wrong and what callers need to do.

A problem in AWS itself or in the Terraform AWS provider belongs with AWS or HashiCorp, not here.
