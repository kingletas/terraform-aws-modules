# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-09-23

**Upgrading to 0.7.0 destroys and recreates running instances and their data volumes unless you prepare.** `ec2-instance` and `instance-fleet` change the keys their instances, extra EBS volumes, volume attachments and Elastic IPs are addressed by. On the first plan after upgrading, Terraform destroys each one at its old address and creates it again at the new one: a new server, an empty data volume where the old one held data, and a new public address for every Elastic IP. Read the plan before applying. Each entry below says how to keep the existing resources: a `moved` block where the old address is a literal you can write, and `terraform state mv`, run once per environment before the apply, where it is not. `secrets-manager-secret` also raises its Terraform and provider floor.

### Breaking changes

- **`ec2-instance`**: instances are keyed by their ordinal instead of by their name, so `aws_instance.this["storefront-staging-01"]` becomes `aws_instance.this["01"]`, and extra volumes and their attachments become `["01-data"]` instead of `["storefront-staging-01-data"]`. The `Name` tags and every output keep the full name. **Without preparation the upgrade destroys and recreates every instance, its root volume and every extra EBS volume, with the data on it.** Where `name` is a literal in the calling configuration, add a `moved` block per address, such as `moved { from = module.web.aws_instance.this["storefront-staging-01"]  to = module.web.aws_instance.this["01"] }`. Where `name` is built from a variable shared across environments, a `moved` block cannot name the old address; run `terraform state mv 'module.web.aws_instance.this["storefront-staging-01"]' 'module.web.aws_instance.this["01"]'` in each environment before the apply, and the same for each `aws_ebs_volume.this` and `aws_volume_attachment.this`.
- **`instance-fleet`**: instances are keyed by role and ordinal instead of by their full name, so `aws_instance.this["storefront-staging-web-01"]` becomes `aws_instance.this["web-01"]`, and an unnumbered role's `["storefront-staging-bastion"]` becomes `["bastion"]`. Elastic IPs, extra volumes and attachments follow (`aws_eip.this["web-01"]`, `aws_ebs_volume.this["web-01-data"]`). The `Name` tags and every output keep the full name. **Without preparation the upgrade destroys and recreates every instance, every extra EBS volume with its data, and every Elastic IP, which gives the instance a new public address.** Migrate each address with a `moved` block or a per-environment `terraform state mv`, as for `ec2-instance`.
- **`secrets-manager-secret`**: requires Terraform 1.11 or later and AWS provider 6.50.0 or later, for the write-only value below. Provider 6.50.0 is the first that switches an existing version from `secret_string` to `secret_string_wo` without replacing it.

### Added

- **`iam-role`**: `use_name_prefix` (default `true`) names the role exactly `name` when set to `false`, `instance_profile_name` names the instance profile exactly, and `inline_policy_names` gives an inline policy an IAM name apart from its map key. Together they let an existing role, profile and inline policy be adopted into the module with `moved` blocks instead of being replaced; the move adds a `Name` tag and a statement ID in place. IAM names are unique in an account, so an exact name leaves a short window with no role during any replacement and collides if two callers use it; the prefix stays the default. Callers that set none of them are unchanged.
- **`iam-role`**: `name` is checked against IAM's limits at plan: 64 characters as an exact name, 37 as a prefix, and only the characters IAM allows. A longer one used to fail later, at the provider or at AWS. `instance_profile_name` is checked the same way, at 128.
- **`secrets-manager-secret`**: `secret_string_wo` and `secret_string_wo_version` write the secret's value as a write-only argument, so it never reaches Terraform state or a plan. Declare the variable you pass in as `ephemeral = true`. Terraform cannot see a write-only value change, so raise `secret_string_wo_version` to write a new one. It cannot be combined with `initial_version` or `generate_password`. A secret created with `initial_version` can move to `secret_string_wo` in place: remove `initial_version`, set both new inputs, and the version is updated rather than replaced. Earlier copies of the state file still hold the old value, so rotate it afterwards.

## [0.6.0] - 2026-09-23

**Upgrading to 0.6.0 destroys and recreates resources.** Four modules and one example change the keys their resources are addressed by, so on the first plan after upgrading, Terraform destroys the existing resource at the old address and creates it again at the new one: SSM parameters in `ssm-parameter`, SFTP user keys in `transfer-server`, extra aliases in `kms-key`, principal associations in `transit-gateway`, and the endpoint security group rules in the `network-hub` example. Read the plan before applying. Each entry below says what to change in a call. Where the old key is a literal you can write, a `moved` block keeps the existing resource; where it is not, `terraform state mv` from the old address to the new one, run once per environment before the apply, keeps it instead.

### Breaking changes

- **`ssm-parameter`**: `parameters` and `values` are keyed by a short name under the new `path_prefix` instead of by the full path. Move the computed part of each path into `path_prefix` and leave the key a literal: `path_prefix = format("/%s/api", var.environment)` with `parameters = { "log-level" = {} }` writes `/staging/api/log-level` as before. A key may still contain slashes, so one call can cover a subtree. `arns`, `names` and `versions` are keyed by that name, and `names` now gives the full path as its value, which is what an application reads the parameter by; a caller that looked a path up in `names` should ask for the short name instead. Existing parameters are destroyed and recreated at the same paths on upgrade, because the resource address changes. The reason for the change is that a `moved` block may only name an address with a constant key, so a path built from a variable could not be written as one, and an existing parameter could not be adopted into the module without being replaced.
- **`transfer-server`**: each user's `public_keys` is a map keyed by a name you choose instead of a list. Write `public_keys = { primary = file("keys/acme.pub") }`. A key's resource address becomes `username/key_name` rather than `username-0`, so removing a user's first key no longer re-addresses the keys after it and destroys keys that did not change. A key name may not be empty or contain `/`. Existing keys are destroyed and recreated on upgrade unless a `moved` block names the old and new addresses, for example `moved { from = module.sftp.aws_transfer_ssh_key.this["acme-0"]  to = module.sftp.aws_transfer_ssh_key.this["acme/primary"] }`. Recreating an SSH key does not interrupt a partner who is not connected at that moment, but it does mean the key is briefly absent, so plan the upgrade outside a transfer window.
- **Examples**: in `network-hub`, the shared endpoint security group's ingress rules are keyed by network name (`shared`, `spoke-<name>`) instead of by position (`net0`, `net1`). Adding or removing a spoke had re-addressed every rule after it, so each one was destroyed and recreated and inbound HTTPS from those networks was refused while the apply ran. Existing rules are recreated once on upgrade; the rule names also reach each rule's `Name` tag.
- **`kms-key`**: `aliases` is a map keyed by a stable name instead of a list. Write `aliases = { legacy = "app-legacy" }`. Existing extra aliases are recreated on upgrade unless a `moved` block names the old and new keys.
- **`transit-gateway`**: `share_with_principals` is a map keyed by a stable name instead of a list. Write `share_with_principals = { security = "123456789012" }`. Existing principal associations are recreated on upgrade. Keying by name also means an account created in the same configuration can be shared with: the list form put the account ID in the key, and an ID that does not exist until apply failed the plan.

### Fixed

- **`ssm-parameter`**: `names` reports the parameter's path rather than repeating its map key.

## [0.5.0] - 2026-09-16

### Added

- **`ecs-service`**: per-container `init_process_enabled` and `drop_capabilities`, so a container can run an init process and drop Linux capabilities such as `ALL`, and `health_check_timeout` and `health_check_start_period` for the container health check. Containers that set none of them are unchanged.

## [0.4.0] - 2026-09-16

### Added

- **`rds-instance`**: `delete_automated_backups`, off by default, so an instance's automated backups stay restorable for their retention period after it is deleted. An existing instance shows an in-place update on its next plan. The provider's own default deleted them, so this changes what a destroy leaves behind.

## [0.3.0] - 2026-09-16

### Security

- **`iam-role`**: an OIDC trust must name `subject_key` and at least one subject. A trust without them let any identity the issuer signs for assume the role. Subjects made only of wildcards are refused. A GitHub subject must open with a claim that names one owner or repository (`repo`, `repository`, `repository_id`, `repository_owner`, `repository_owner_id` or `job_workflow_ref`) followed by a literal value, so custom subject claim templates are accepted. A trust counts as GitHub when its provider ARN, audience key or subject key names `token.actions.githubusercontent.com` in any letter case, or when a subject starts with `repo:`.
- **`api-gateway-rest`**: every route states its `authorization`. A route that omitted it was public.
- **`kms-key`**: `service_principals` are granted use of the key only for requests from this account (`aws:SourceAccount`, where the service sends it). A CloudWatch Logs principal, in `service_principals` or `delivery_service_principals`, is granted use only for log groups in this account and in the region the principal names.
- **`opensearch-domain`**: a domain with no `subnet_ids` is refused unless `public = true`. Leaving the subnets out no longer puts a domain on a public endpoint by accident.
- **`efs-filesystem`**: the file system policy allows mounting only through a mount target, and root on a client is squashed to an unprivileged user unless `allow_client_root_access = true`.
- **`redshift-cluster`**: `require_ssl` is always set in the cluster's own parameter group, from the new `require_ssl` variable (default `true`). Passing any `parameters` without `require_ssl` left TLS optional. On an existing cluster the new parameter group waits for a reboot, so TLS is not enforced until the cluster is rebooted.
- **`transfer-server`**: a user's IAM policy is scoped to the prefix its `home_directory` maps to, and a `home_directory` containing `..` or naming the bucket root is refused.
- **`ec2-instance`, `instance-fleet`, `launch-template`**: instance tags are no longer exposed through the metadata service by default. Set `instance_metadata_tags = true` to expose them.
- **`ses-domain`**: the SMTP user can send only through this domain's identity and its configuration set.
- **`documentdb-cluster`**: audit logging is on unless `parameters` sets `audit_logs` itself.

### Breaking changes

- **`iam-role`**: `trusted_oidc_providers` entries require `subject_key` and `subjects`. Add both to every entry, for example `subject_key = "token.actions.githubusercontent.com:sub"` and `subjects = ["repo:example-org/app:ref:refs/heads/main"]`. A GitHub subject that opens with any other claim, such as `environment:` or `enterprise:`, is refused; enterprise-level subjects are not supported. Provider keys must stay distinct once reduced to letters and digits, because each becomes a statement ID.
- **`api-gateway-rest`**: `routes[*].authorization` is required. Add `authorization = "NONE"` to routes that are meant to be public, or `AWS_IAM`, `CUSTOM` or `COGNITO_USER_POOLS`. Every route except a `MOCK` integration needs `lambda_invoke_arn` or `integration_uri`.
- **`opensearch-domain`**: an empty `subnet_ids` requires `public = true`, and `public = true` requires an empty `subnet_ids`.
- **`ecs-service`**: `execution_role_arn` is required, because every container logs through the `awslogs` driver. `launch_type` is replaced by `capacity`, which takes exactly one of `launch_type` and `capacity_provider_strategy`: replace `launch_type = "EC2"` with `capacity = { launch_type = "EC2" }`, and a caller that passed `launch_type = null` to use the cluster's default strategy must pass that strategy as `capacity = { capacity_provider_strategy = [...] }`. Moving an existing service from a launch type to a strategy replaces the service. A service with `autoscaling` set is a separate resource, `aws_ecs_service.autoscaled`. To keep an existing autoscaled service, add `moved { from = module.<name>.aws_ecs_service.this  to = module.<name>.aws_ecs_service.autoscaled[0] }` to the calling configuration before applying. Turning `autoscaling` on or off later needs a `moved` block between `aws_ecs_service.this[0]` and `aws_ecs_service.autoscaled[0]` in the same apply, or the replacement fails while the old service drains.
- **`autoscaling-group`**: `launch_template_version` is required. With `instance_refresh` set it must be a version number, such as the `launch-template` module's `latest_version` output; `$Latest` and `$Default` are accepted only with `instance_refresh = null`.
- **`vpc`**: subnet CIDRs are derived from each zone's last letter (`a` is slot 0, `h` is slot 7). Public subnets use slots 0 to 7 and private subnets slots 8 to 15, so adding or removing a zone leaves the other zones' subnets alone. Existing subnets whose CIDR changes are replaced, along with anything inside them, so plan carefully before upgrading a VPC in use. At most eight zones are allowed, `subnet_newbits` must be at least 4, and a zone whose letter does not place it (such as a Local Zone) needs `availability_zone_indexes`.
- **`site-to-site-vpn`**: `vpc_id` is replaced by `vpn_gateway = { vpc_id = "..." }`. `static_routes` is a map of name to CIDR instead of a list. `propagate_to_route_table_ids` is replaced by the map `vpn_gateway_propagation_route_tables`. Static routing through a transit gateway needs `transit_gateway_static_route_tables`. Existing static routes and route propagations are keyed by those names instead of by CIDR or route table ID, so upgrading destroys and recreates them, which interrupts traffic. To keep them, use each old CIDR or route table ID as its map key, or add `moved` blocks from the old addresses.
- **`alb`**: `additional_certificate_arns` is a map keyed by a stable name instead of a list. Certificate attachments are keyed by that name instead of by ARN, so existing ones are recreated on upgrade. The HTTPS listener is controlled by `create_https_listener` (default `true`) and needs `certificate_arn`; a load balancer that is HTTP only must set `create_https_listener = false`. `default_target_group` is optional when `default_fixed_response` is set. Each listener rule needs at least one condition and must name a declared target group. Target group names end in a short hash, so existing target groups are replaced (new ones are created before the old ones are removed).
- **`nlb`**: target group names end in a short hash, so existing target groups are replaced, new before old. `name` must be 2 to 32 letters, digits or hyphens, not starting or ending with a hyphen.
- **`lambda-function`**: `tracing_mode` defaults to `PassThrough`. Set `tracing_mode = "Active"` to keep starting traces, and grant `xray:PutTraceSegments` and `xray:PutTelemetryRecords` on the execution role.
- **`cognito-user-pool`**: `advanced_security_mode` defaults to `OFF`, and `AUDIT` or `ENFORCED` require the new `user_pool_tier = "PLUS"`. `user_pool_tier` defaults to `ESSENTIALS`; a pool on the Lite plan moves to Essentials, which is billed differently, unless you set `user_pool_tier = "LITE"`.
- **`cloudtrail-trail`**: `include_management_events` moves from each `data_events` entry to a module input, joined by `management_events_read_write_type`. Remove it from `data_events` entries. A trail with management events off needs at least one data event. `insight_types` needs write management events: `include_management_events = true` and `management_events_read_write_type` set to `All` or `WriteOnly`.
- **`dms-replication`**: the account-level roles DMS needs can be created with `create_service_roles` (`dms-vpc-role`, `dms-cloudwatch-logs-role`) and `create_endpoint_access_role` (`dms-access-for-endpoint`, for a Redshift target). Both default to `false`, so in an account where the roles do not exist, set them to `true` in exactly one configuration.
- **`launch-template`**: `root_volume.device_name` defaults to the AMI's own root device instead of `/dev/xvda`, which creates a new template version for AMIs whose root device differs. Reading it needs the identity running Terraform to be able to describe the image. An `image_id` of `resolve:ssm:` has no image to read at plan, so it needs `root_volume.device_name`; setting `device_name` skips the lookup. `instance_requirements.cpu_architectures` is removed; the architecture follows the AMI. Remove it from calls.
- **`ec2-instance`, `instance-fleet`**: `extra_volumes[*].delete_on_termination` is removed; it had no effect, and extra volumes are never deleted with the instance. Remove it from calls. Instances are replaced destroy-first, so a replacement has a gap between the old instance stopping and the new one starting.
- **`ec2-instance`, `instance-fleet`, `launch-template`**: `instance_metadata_tags` defaults to `false`. Software that reads tags from the metadata service needs `instance_metadata_tags = true`, and AWS then refuses tag keys containing spaces, slashes or other characters outside letters, digits and `+ - = . , _ : @`. In `ec2-instance` and `instance-fleet` the plan checks the provider's `default_tags` as well as the module's own tags.
- **`dynamodb-table`**: requires AWS provider 6.37.0 or later.
- **`s3-bucket`**: the `id` and `arn` outputs wait for the bucket policy and public access block. A statement passed in `policy_documents` must not reference the same module's `arn` or `id`, or Terraform reports a cycle; build the ARN from the bucket name instead. Grants for services such as CloudFront or CloudTrail belong in `policy_documents` rather than in a separate `aws_s3_bucket_policy`, which would replace the module's policy.
- **`redshift-cluster`**: `require_ssl` may not appear in `parameters`; use the `require_ssl` variable. The module always creates a parameter group, and an existing one is moved to its new address without replacement.
- **`kms-key`**: when `admin_arns` is set, the identity running Terraform is added to the key policy as an administrator (`include_caller_as_admin`, default `true`), so AWS does not refuse a policy that locks it out. A key applied by more than one identity, such as a CI role and a person, has its policy rewritten by each. For a stable policy, set `include_caller_as_admin = false` and list every administrator in `admin_arns`, including each identity that applies the configuration.
- **`aurora-cluster`**: `monitoring_interval` defaults to `60`, which turns on enhanced monitoring for every instance and creates a monitoring role. An existing cluster gets the role and an instance change on the next apply. Set `monitoring_interval = 0` to keep enhanced monitoring off.
- **`documentdb-cluster`**: `audit_logs = "enabled"` is added to any `parameters` map that does not set `audit_logs`, and the module always creates a parameter group. On the next apply, a cluster that passed `parameters = {}` gets a new parameter group, and one whose map left out `audit_logs` turns audit logging on. Set `audit_logs = "disabled"` in `parameters` to keep it off.
- **`backup-plan`**: `name` must be 2 to 40 characters. A rule with `cold_storage_after_days` must keep recovery points at least 90 days after the move to cold storage.
- **`acm-certificate`**: with `wait_for_validation = true` (the default) the apply waits for issuance even when this module does not write the validation records. Set `wait_for_validation = false` when the records are published elsewhere and you do not want the apply to wait.
- **`ansible-inventory`**: inventory hostnames are instance IDs, because instances in an autoscaling group share a `Name` tag. Host variables keyed by name or private address need to be rekeyed. The facts lookup is written into `group_vars/all.yml` together with the `all` entry of `group_vars`, and `terraform_facts` is reserved in that group.
- **`amazon-mq`**: broker passwords need at least four different characters and may not contain a comma, colon or equals sign. A RabbitMQ broker refuses `kms_key_arn`, because RabbitMQ supports only the AWS-owned key.
- **`client-vpn`**: `client_cidr_block` must be between a /12 and a /22.
- **`elasticache-redis`**: more than one node group needs `cluster_mode_enabled = true`, and cluster mode needs `parameter_group_family`. A custom parameter group's name includes the family, so an existing group is replaced, new before old.
- **`aurora-cluster`, `rds-instance`, `redshift-cluster`**: the final snapshot is named `<name>-final`. A destroy fails if a snapshot with that name already exists, so rename or delete an old one first.
- **`transit-gateway`**: `route_table_key` cannot be combined with `default_route_table_association = true`. Every static route needs an `attachment_key` naming one of `vpc_attachments`, unless it is a blackhole, and a `route_table_key` naming one of `route_tables`.
- **`mwaa-environment`**: an `mw1.micro` environment requires `min_workers`, `max_workers` and `schedulers` all set to 1.
- **`cloudwatch-dashboard`**: unplaced widgets are laid out by CloudWatch. Set both `x` and `y` on a widget, or neither, and a placed widget must fit the 24-column grid.
- **`eventbridge-rule`**: a target may set at most one of `input`, `input_path` and `input_transformer`.
- **`cloudwatch-alarm`**: a `metric_query` alarm needs exactly one query with `return_data = true`.
- **`cloudwatch-alarm`**: an evaluation window longer than one day, or longer than one hour when the period is under 60 seconds, is refused at plan, because CloudWatch refuses it at apply.
- **`cloudfront-distribution`**: every behaviour, the default one included, needs a `cache_policy_id`. Use `Managed-CachingOptimized` for static content, or `Managed-CachingDisabled` with an origin request policy such as `Managed-AllViewer` for an application. `precedence` must be a whole number from 0 to 999999999.
- **`security-group`**: egress rules are validated like ingress rules, and both now check protocol and ports. Each egress rule needs exactly one destination and a non-empty description. In both directions `ip_protocol` must be `-1`, `tcp`, `udp`, `icmp`, `icmpv6` or a number from 0 to 255, a `tcp` or `udp` rule needs `from_port` and `to_port` from 0 to 65535 with `from_port` no greater than `to_port`, and an ICMP type and code must be from -1 to 255.
- **`secrets-manager-secret`**: `initial_value` and `initial_json` are replaced by one `initial_version` object with exactly one of `value` or `json`. Write `initial_version = { value = ... }` or `initial_version = { json = { ... } }`. A value that comes from another resource in the same plan now works.

### Fixed

- **`cloudfront-distribution`**: ordered behaviours are applied in `precedence` order, with ties broken by name.
- **`cloudtrail-trail`**: management events are recorded alongside data events. Adding a data event selector had replaced the default management selector. Each selector's `read_write_type` is applied.
- **`ses-domain`**: the SMTP user's policy matches sending addresses in the domain; it had matched none. With `byodkim` set, no Easy DKIM records are published or listed. The SMTP endpoint output uses the partition's DNS suffix.
- **`api-gateway-rest`**: routes may be up to six path segments deep, each segment its own API resource. A top-level resource keeps the path as the route writes it (`orders` or `/orders`), so an API created with 0.2.0 keeps its resources on upgrade. A `MOCK` integration no longer needs a URI.
- **`elasticache-redis`**: cluster mode uses a cluster-enabled parameter group, which a sharded replication group requires.
- **`dynamodb-table`**: global secondary indexes use the provider's `key_schema` block.
- **`ec2-instance`, `instance-fleet`**: an extra EBS volume takes its availability zone from the subnet, so replacing an instance no longer replaces its volumes.
- **`launch-template`**: the root volume settings apply to the AMI's real root device on AMI families whose root is not `/dev/xvda`.
- **`opensearch-domain`**: Auto-Tune settings are omitted on T2 and T3 instance types, which refuse them.
- **`client-vpn`**: an empty `security_group_ids` leaves the setting unset, so the endpoint uses the VPC default security group instead of failing.
- **`ssm-parameter`**: a parameter with no value is reported by variable validation, naming every missing path.
- **`dms-replication`**: a task naming an undeclared endpoint fails with a precondition message instead of an index error. When the module creates the account-level roles, the replication instance and subnet group wait for `dms-vpc-role`, and the endpoints wait for `dms-access-for-endpoint`.
- **`aurora-cluster`, `rds-instance`, `redshift-cluster`**: the final snapshot identifier is always set, so a destroy still takes a final snapshot when `skip_final_snapshot` was turned off after the database was created.
- **`organization`, `rds-instance`, `cloudwatch-dashboard`, `ses-domain`**: ARNs, endpoints and console links use the current partition.
- **`ansible-inventory`**: the facts lookup no longer conflicts with a caller's own `all` group variables.
- **`ecs-service`**: a service can run on a capacity provider strategy, such as Fargate Spot above an on-demand base. The module's `launch_type` default had overridden any strategy, so every task ran on on-demand Fargate.
- **`client-vpn`**: the certificate authentication inputs describe what AWS expects: a certificate issued by the client certificate authority, imported with that authority as its chain. The endpoint accepts every client certificate the authority signs.
- **Examples**: `container-platform` runs each service with one on-demand task and most of the rest on Fargate Spot. `magento` stores the Valkey auth token and the OpenSearch master password as SSM SecureString parameters the nodes can read, and names them in `/etc/magento/environment` and the facts. A new `ami_id` in `magento` no longer replaces the cron, admin and builder nodes in the same apply; replace `terraform_data.singleton_ami` to roll them. `magento` encrypts the static assets bucket with SSE-S3 so CloudFront can serve `/static/*`, and writes load balancer access logs in every region. `account-baseline` lets AWS Backup publish job notifications to the security topic. In `network-hub`, a spoke with its own NAT gateway routes to the shared VPC through the transit gateway. In `data-pipeline`, the alarm for a run that never started uses a 24-hour window, which CloudWatch accepts.

### Added

- **`alb`**: `create_http_listener` and `default_fixed_response`, so a load balancer can accept only requests carrying a shared origin header (for example from CloudFront) and answer everything else with a fixed response.
- **`alb`**: `https_listener_default_action` and `listener_rules` outputs describe what the listener does, without header values.
- **`api-gateway-rest`**: `manage_account_cloudwatch_role` creates the account-level role API Gateway needs to write access logs.
- **`aurora-cluster`**: `monitoring_interval`, for enhanced monitoring.
- **`autoscaling-group`**: target tracking on a custom metric through `customized_metric`.
- **`backup-plan`**: `s3_backup_enabled` for S3 buckets, and a `role_policy_arns` output.
- **`dms-replication`**: `create_service_roles`, `create_endpoint_access_role` and a `service_role_arns` output.
- **`ecs-service`**: `cpu_architecture`, for `ARM64` tasks.
- **`efs-filesystem`**: `allow_client_root_access`.
- **`elasticache-redis`**: `cluster_mode_enabled`, so a single shard can run in cluster mode and add shards later.
- **`kms-key`**: `delivery_service_principals`, for services such as CloudWatch or EventBridge that deliver to a resource encrypted with the key, and `include_caller_as_admin`.
- **`s3-bucket`**: `policy_documents`, merged into the bucket policy the module writes.
- **`site-to-site-vpn`**: `transit_gateway_association`, `transit_gateway_propagation_route_tables` and `transit_gateway_static_route_tables`, for routing a VPN attachment in transit gateway route tables.
- **`sns-topic`**: `publishing_services` and `publishing_source_arns`. The grant accepts a service that names this account by either `aws:SourceAccount` or `aws:SourceOwner`, so AWS Backup can publish, and the Sids `AllowServicePublishBySourceAccount` and `AllowServicePublishBySourceOwner` are reserved. **`sqs-queue`**: `sending_services` and `sending_source_arns`. Both grant AWS services access limited to this account, and optionally to named source ARNs.
- **`transfer-server`**: `bucket_kms_key`, which grants users the KMS access a bucket encrypted with a customer managed key requires.
- **`ansible-inventory`**: `ssm_bucket_name`, the bucket the Systems Manager connection transfers modules through.
- **`cognito-user-pool`**: `user_pool_tier`.
- **`vpc`**: `availability_zone_indexes`.
- **`cloudtrail-trail`**: `include_management_events` and `management_events_read_write_type`.
- **`ecs-service`**: `capacity` and a `capacity_provider_strategy` output.
- Plan tests of their own for the modules changed in this release, including refusal tests that expect each new validation and precondition to stop the plan.
- `make test DIR=modules/<name>` (or `DIR=examples/<name>`) runs the plan tests of one module or example.

### Changed

- **Examples**: every example that sends alarms to an encrypted topic grants CloudWatch (and AWS Backup or EventBridge where they publish) use of the key. Bucket grants for CloudTrail, CloudFront, Redshift audit logging and load balancer logs go through `s3-bucket`'s `policy_documents`. `magento` accepts traffic at the load balancer only from CloudFront with the origin header, and only its builder node can write the static assets bucket; `network-hub` routes spoke egress and on-premises ranges through the transit gateway correctly, requires `on_premises.routes` with BGP, and creates a Route 53 private hosted zone per interface endpoint so every VPC resolves the central endpoints by name; `partner-sftp-exchange` alarms on failed logins to real partner usernames; `mwaa-data-warehouse` separates the staging bucket from the audit log bucket and creates the DMS roles; `serverless-api` adds `manage_api_gateway_account_role`.
- **Examples**: `data-pipeline` passes each source as an object with `name`, `engine`, `server_name`, `port`, `database` and `credentials_secret_arn` in the extract execution input, instead of a list of names. `partner-sftp-exchange` drops the unused `description` from `partners`.
- **Examples**: in `magento`, the static-assets bucket uses SSE-S3 so CloudFront can read it, only the builder node's role writes it, ALB access logs are delivered in every region, and nodes have no permission on the Ansible transfer bucket (the machine running Ansible needs it). In `network-hub`, spokes with their own NAT gateway route to the shared VPC, and private hosted zones make the central interface endpoints resolvable from every VPC. In `data-pipeline`, the missed-run alarm uses a 24-hour window CloudWatch accepts.
- The release workflow skips the checks for a tagged commit that has already passed CI, and release notes no longer include the changelog's link definitions.
- Every check runs with fake AWS credentials, every other credential source closed and AWS endpoints pointed at a closed local port, so a test can never reach an AWS account.
- `.pre-commit-config.yaml` is removed. `make check` is the gate.

## [0.2.0] - 2026-09-15

### Added

- **`organization`** builds an AWS Organization, its organizational units and its member accounts. Units nest two levels so every `for_each` key is known at plan, and a child is addressed as `parent/child` wherever a unit is named. `create_organization = false` adopts an organization that already exists.
- **`organization-policy`** creates one organizational policy and attaches it to roots, units or accounts, keyed by a name so detaching one target leaves the others alone.
- **`iam-oidc-provider`** registers an OIDC issuer so a CI system assumes a role instead of holding an access key. It outputs the `aud` and `sub` condition keys built from the issuer host, so an `iam-role` trust states the host once and cannot disagree with the provider it names.
- **`amazon-mq`** builds a RabbitMQ or ActiveMQ broker. The two engines differ in deployment modes, users, storage and logging, and each difference is a precondition that stops the plan rather than an error AWS returns at apply with half a stack built.
- **`ses-domain`** verifies a sending domain with DKIM, a custom envelope sender and a configuration set, and either publishes the DNS records into Route 53 or lists them for a zone run elsewhere. An SMTP user is available and off by default, because an application that can call the SES API should use a role instead.
- **`kinesis-firehose`** delivers to S3 or to an HTTP endpoint, with the mandatory backup bucket the HTTP path needs. A plaintext endpoint URL is refused at plan, because the vendor access key would otherwise go on the wire in the clear.
- **`cloudwatch-metric-stream`** pushes metrics to a delivery stream rather than having a vendor poll `GetMetricData`. Include and exclude filters are mutually exclusive and the module says so at plan, and extra statistics are named per metric because they are billed that way.
- **Failure-path tests.** The new modules test the direction that refuses as well as the direction that passes: a RabbitMQ broker asked for ActiveMQ's deployment mode, a multi-AZ broker given one subnet, an account in a unit that was never declared, an SES event destination with two targets, and a policy whose content is not JSON.
- **A policy lane.** `make policy` checks the conventions in `CONTRIBUTING.md` with conftest: no `provider` block in a module, a version on every required provider, a range rather than a pin, no `count` set to a length, no existence decided by whether a string is null, a `sensitive` marker on any credential-shaped string, and the same three files in every module. Seven rules, none of which duplicates checkov or tflint, and all of which could previously be broken with a green build.
- **Every policy rule is proved to still refuse.** `policy/tests/fixture` holds one module per rule, each breaking exactly one convention. The lane runs the repository, which must be silent, then every fixture, each of which must produce exactly one finding and the right one. A rule that quietly stops matching otherwise looks identical to a repository that is clean.
- `conftest` is pinned in `.tool-versions`, and a missing or mismatched version reports the lane as not run rather than counting it as a pass.
- Policy fixtures are stored as `*.tf.fixture` and named `.tf` only inside the runner's own copy. They are broken Terraform on purpose, and under a `.tf` name `trivy` and `tflint` report them as real findings on every commit.

### Changed

- **`CONTRIBUTING.md` named the wrong mechanism for pinning an example.** It asked for exact version constraints in examples; every example in fact uses a range and commits `.terraform.lock.hcl`, which is where an exact provider version and its hashes actually belong, and which `make clean` deliberately leaves alone. The rule now says so, and the policy lane checks the half that is real: a module states a range.

### Fixed

- The README said `make check` ran five lanes and quoted an old checkov count. It now lists all seven lanes, the `make plan-test` target and the current scan result.
- `make help` said `make clean` removes the examples' lock files. It doesn't: it removes the modules' lock files, and the examples' stay committed.

## [0.1.0] - 2026-09-10

The first release.

### Added

- **52 modules** covering conventions, networking, compute, load balancing, data, storage, messaging, data movement, edge and API, identity and secrets, and operations. Each has typed and described inputs, validation where a value can be checked at plan, and a README with generated tables.
- **11 examples** that compose the modules into stacks: a Magento storefront, a container platform with its ECR repositories, a serverless API, a static site behind CloudFront, a transit gateway hub, a Step Functions pipeline, an Airflow, DMS and Redshift warehouse, a partner SFTP exchange, an account baseline, a client VPN and an instance tier. Each README covers cost, the decisions that are deliberate, and what the example does not do.
- **Plan tests** covering every module, run against mock providers with `make plan-test`: each example plans the modules it composes, and each module no example uses has a test of its own. They evaluate every expression with real values — including IDs that do not exist until apply — which `terraform validate` does not, and they need no credentials.
- **`make check`**, which runs formatting, validation, the plan tests, tflint, checkov and a README freshness check, and reports a lane whose tool is missing rather than counting it as a pass.
- **`.tool-versions`**, pinning Terraform, tflint, terraform-docs and checkov. The check scripts refuse a mismatched version rather than report output that would differ.

### Conventions every module follows

- A collection that becomes resources is a map with static keys, so a plan never depends on a value that does not exist until apply.
- Whether a resource exists is decided by a bool or an object, never by whether a string is null.
- Encryption is on, public addresses are off and IMDSv2 is required, each with a variable to choose otherwise deliberately.
- No module carries a provider block.

[Unreleased]: https://github.com/kingletas/terraform-aws-modules/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/kingletas/terraform-aws-modules/releases/tag/v0.7.0
[0.6.0]: https://github.com/kingletas/terraform-aws-modules/releases/tag/v0.6.0
[0.5.0]: https://github.com/kingletas/terraform-aws-modules/releases/tag/v0.5.0
[0.4.0]: https://github.com/kingletas/terraform-aws-modules/releases/tag/v0.4.0
[0.3.0]: https://github.com/kingletas/terraform-aws-modules/releases/tag/v0.3.0
[0.2.0]: https://github.com/kingletas/terraform-aws-modules/tree/ea80d9b4a36eb0a0f26c6179be6d22a9918850f5
[0.1.0]: https://github.com/kingletas/terraform-aws-modules/tree/fade717f693f0ad5b6200d453b285013ef6a5991
