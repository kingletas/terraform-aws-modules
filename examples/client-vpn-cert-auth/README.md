# Client VPN with certificate authentication

A VPC and a Client VPN endpoint that a laptop can connect to with a certificate. No user directory, no identity provider — just a certificate authority you run yourself.

This is the smallest thing that gets you inside a private subnet, and it is a reasonable choice for a development environment or a team of a handful of people.

## What it builds

- A VPC across two availability zones, with no NAT gateway.
- A security group that lets clients reach the endpoint and lets the endpoint reach the VPC.
- A Client VPN endpoint, split-tunnelled, resolving private names through the VPC resolver.
- A CloudWatch log group holding connection logs.

## Before you start

Generate a certificate authority and two certificates with [easy-rsa](https://github.com/OpenVPN/easy-rsa):

```bash
git clone https://github.com/OpenVPN/easy-rsa.git && cd easy-rsa/easyrsa3
```

```bash
./easyrsa init-pki && ./easyrsa build-ca nopass
```

```bash
./easyrsa build-server-full server nopass && ./easyrsa build-client-full client nopass
```

You now have `pki/ca.crt`, `pki/issued/server.crt`, `pki/private/server.key`, `pki/issued/client.crt` and `pki/private/client.key`.

## Running it

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit the region and names, then apply. The certificates are passed on the command line so the private keys never land in a file:

```bash
terraform init && terraform apply -var="server_certificate_body=$(cat pki/issued/server.crt)" -var="server_private_key=$(cat pki/private/server.key)" -var="client_root_certificate_body=$(cat pki/issued/client.crt)" -var="client_root_private_key=$(cat pki/private/client.key)" -var="certificate_chain=$(cat pki/ca.crt)"
```

## Connecting

Export the client configuration:

```bash
aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id "$(terraform output -raw vpn_endpoint_id)" --output text > client.ovpn
```

The exported file has no certificate in it. Append yours:

```bash
{ echo "<cert>"; cat pki/issued/client.crt; echo "</cert>"; echo "<key>"; cat pki/private/client.key; echo "</key>"; } >> client.ovpn
```

Open `client.ovpn` in the AWS VPN Client, OpenVPN or Tunnelblick.

## What it costs

Two subnet associations are billed hourly whether or not anyone connects, and each connected client is billed hourly on top. Run `terraform destroy` when you are finished experimenting.

## Cleaning up

```bash
terraform destroy
```

The imported ACM certificates go with it. The easy-rsa `pki/` directory is yours and is untouched.
