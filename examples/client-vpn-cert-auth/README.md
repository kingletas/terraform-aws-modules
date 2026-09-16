# client-vpn-cert-auth

A VPC and a Client VPN endpoint that a laptop connects to with a certificate. There is no user directory and no identity provider: you run the certificate authority yourself.

It is the smallest way to get inside a private subnet, and it suits a development environment or a small team.

## What it builds

- A VPC across two availability zones, with a public and a private subnet in each and no NAT gateway.
- A security group that lets clients reach the endpoint on UDP 443 and lets the endpoint reach anything in the VPC.
- Two ACM certificates imported from your files: the server certificate, and a client certificate with the certificate authority as its chain. The endpoint trusts that authority, so it accepts any client certificate the authority signs.
- A Client VPN endpoint associated with both private subnets. It is split-tunnelled, so only VPC traffic goes through the tunnel, and it resolves private names through the VPC resolver (the VPC CIDR base address plus two).
- One authorization rule that lets every connected client reach the whole VPC.
- A CloudWatch log group holding connection logs for 365 days.

## Before you deploy

You need:

- AWS credentials for the target account, and Terraform 1.9 or later.
- The AWS CLI, to export the client configuration after apply.
- [easy-rsa](https://github.com/OpenVPN/easy-rsa) 3, to create the certificate authority and certificates.
- An OpenVPN-compatible client: the AWS VPN Client, OpenVPN or Tunnelblick.

### Create the certificates

Run every command in this section from this example's directory, `examples/client-vpn-cert-auth`. easy-rsa creates `pki/` in the directory where `init-pki` runs, so the certificates and keys land in `examples/client-vpn-cert-auth/pki/`.

Clone easy-rsa outside this repository. The commands below assume `$HOME/easy-rsa`; if you installed easy-rsa from a package manager, point `EASYRSA` at that `easyrsa` instead.

```bash
git clone --depth 1 https://github.com/OpenVPN/easy-rsa.git "$HOME/easy-rsa"
```

```bash
EASYRSA="$HOME/easy-rsa/easyrsa3/easyrsa"
```

Create the PKI and the certificate authority. `build-ca` asks for a common name; any name you will recognise works.

```bash
"${EASYRSA}" init-pki
```

```bash
"${EASYRSA}" build-ca nopass
```

Issue a server certificate and a client certificate. Each command asks you to confirm by typing `yes`.

```bash
"${EASYRSA}" build-server-full server nopass
```

```bash
"${EASYRSA}" build-client-full client nopass
```

`nopass` leaves the private keys unencrypted, which ACM requires for an import. The commands create these files, relative to this example's directory:

| File | What it is |
|---|---|
| `pki/ca.crt` | The certificate authority |
| `pki/issued/server.crt` | Server certificate |
| `pki/private/server.key` | Server private key |
| `pki/issued/client.crt` | Client certificate |
| `pki/private/client.key` | Client private key |

The repository's `.gitignore` ignores `pki/`, `*.crt`, `*.key`, `*.pem` and `*.ovpn`. If you copy this example somewhere else, add the same ignores there before you create any of these files.

### Keep the private keys out of the wrong places

Terraform stores everything you pass it in state, including both private keys, in plain text. `sensitive = true` on the variables only hides the values from plan output. This example has no backend block, so state is a local `terraform.tfstate` file. Before you apply anywhere that matters, configure a backend that encrypts state and restricts who can read it, such as an S3 bucket with encryption and a bucket policy limited to the people who run this example.

Pass the certificate material as environment variables rather than typing it into `-var` flags. Values pasted onto a command line end up in shell history, and command-line arguments are visible to other processes on the machine while Terraform runs. Terraform `.tfvars` files cannot call `file()`, so environment variables are the way to read the files without copying their contents anywhere.

## How to use it

Copy the variables file and set the region, name and CIDR ranges:

```bash
cp terraform.tfvars.example terraform.tfvars
```

In the same shell you will run Terraform from, still in this example's directory, export the five certificate variables:

```bash
export TF_VAR_server_certificate_body="$(cat pki/issued/server.crt)"
export TF_VAR_server_private_key="$(cat pki/private/server.key)"
export TF_VAR_client_root_certificate_body="$(cat pki/issued/client.crt)"
export TF_VAR_client_root_private_key="$(cat pki/private/client.key)"
export TF_VAR_certificate_chain="$(cat pki/ca.crt)"
```

Then initialise, plan and apply:

```bash
terraform init
```

```bash
terraform plan
```

```bash
terraform apply
```

To check the example without AWS credentials, run its plan test from the top of the repository. It plans against mock providers with placeholder certificates and creates nothing:

```bash
make test DIR=examples/client-vpn-cert-auth
```

The `.tf` files call modules by relative path (`../../modules/<name>`). If you copy this example outside this repository, change each `source` to `github.com/kingletas/terraform-aws-modules//modules/<name>?ref=v0.5.0`.

### Connect

Export the client configuration:

```bash
aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id "$(terraform output -raw vpn_endpoint_id)" --output text > client.ovpn
```

The exported file has no certificate in it. Append the client certificate and key:

```bash
{ echo "<cert>"; cat pki/issued/client.crt; echo "</cert>"; echo "<key>"; cat pki/private/client.key; echo "</key>"; } >> client.ovpn
```

Open `client.ovpn` in your VPN client. The file contains a private key, so protect it like one.

### Clean up

The certificate variables have no defaults, so export them again in a new shell before destroying:

```bash
terraform destroy
```

The imported ACM certificates are deleted with everything else. The `pki/` directory is yours and is left untouched.

## Inputs worth knowing

| Variable | Default | Why you would change it |
|---|---|---|
| `region` | `us-east-1` | Where the VPC and endpoint are created |
| `name` | `vpn-demo` | Prefix for every resource name |
| `vpc_cidr` | `10.20.0.0/16` | To avoid overlapping a network your clients already reach |
| `client_cidr_block` | `10.100.0.0/22` | Address pool for connected clients. It must not overlap `vpc_cidr`, and Client VPN accepts a size between /12 and /22 |
| `environment` | `sandbox` | Tagging |
| `server_certificate_body`, `server_private_key` | none | Server certificate and key, required |
| `client_root_certificate_body`, `client_root_private_key` | none | A client certificate issued by your certificate authority, and its key, required. AWS reads the authority from its chain |
| `certificate_chain` | none | The certificate authority's certificate, used as the chain for both imports, required |

## Costs

The endpoint is billed per hour for each subnet association, and this example makes two, whether or not anyone connects. Each connected client is billed per hour on top. Run `terraform destroy` when you are finished.

## Limits

- **Clients reach the VPC and nothing else.** The tunnel is split, and the VPC has no NAT gateway, so instances in the private subnets have no outbound internet access either.
- **Every client can reach the whole VPC.** The single authorization rule does not distinguish between people. Certificate authentication has no groups to narrow it by.
- **One shared client certificate as written.** To give each person their own, run `build-client-full` once per person with the same CA. Every certificate signed by that CA is accepted.
- **No revocation.** Removing one person's access needs a certificate revocation list imported into the endpoint with the AWS CLI. This example does not manage one, so until you import one, the only way to cut off a leaked certificate is a new CA.
