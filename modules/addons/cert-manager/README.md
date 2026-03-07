# cert-manager Module

Deploys [cert-manager](https://cert-manager.io/) for automatic TLS certificate management in Kubernetes.

## Features

- Automatic certificate issuance and renewal
- Self-signed CA for internal certificates
- Let's Encrypt integration (staging and production)
- DNS01 challenge support via Cloudflare
- Configurable resource limits

## Usage

### Basic (Self-signed CA only)

```hcl
module "cert_manager" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/cert-manager?ref=v1.3.4"
}
```

### With Let's Encrypt

```hcl
module "cert_manager" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/cert-manager?ref=v1.3.4"

  create_letsencrypt_issuer = true
  letsencrypt_email         = "admin@example.com"
  letsencrypt_server        = "production"  # or "staging" for testing
}
```

### With Cloudflare DNS01 (for wildcard certs)

```hcl
module "cert_manager" {
  source = "github.com/freed-dev-llc/terraform-turingpi-modules//modules/addons/cert-manager?ref=v1.3.4"

  create_letsencrypt_issuer = true
  letsencrypt_email         = "admin@example.com"
  letsencrypt_server        = "production"

  dns01_enabled        = true
  cloudflare_email     = "admin@example.com"
  cloudflare_api_token = var.cloudflare_api_token
}
```

## Creating a Certificate

After deploying cert-manager, create certificates using the appropriate issuer:

### Using Self-signed CA

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: my-namespace
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  dnsNames:
    - my-app.local
```

### Using Let's Encrypt

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: my-namespace
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  dnsNames:
    - my-app.example.com
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| chart_version | cert-manager Helm chart version | string | "1.16.2" |
| namespace | Kubernetes namespace | string | "cert-manager" |
| timeout | Helm install timeout in seconds | number | 300 |
| create_selfsigned_issuer | Create self-signed ClusterIssuer | bool | true |
| create_letsencrypt_issuer | Create Let's Encrypt ClusterIssuer | bool | false |
| letsencrypt_email | Email for Let's Encrypt | string | "" |
| letsencrypt_server | staging or production | string | "production" |
| dns01_enabled | Enable DNS01 challenge support | bool | false |
| cloudflare_api_token | Cloudflare API token | string | "" |
| controller_replicas | Number of controller replicas | number | 1 |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where cert-manager is deployed |
| selfsigned_issuer_name | Name of the self-signed ClusterIssuer |
| ca_issuer_name | Name of the CA ClusterIssuer |
| letsencrypt_issuer_name | Name of the Let's Encrypt ClusterIssuer |
