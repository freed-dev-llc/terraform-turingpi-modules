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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.14 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 1.14 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cainjector_resources"></a> [cainjector\_resources](#input\_cainjector\_resources) | Resource requests/limits for cert-manager cainjector | <pre>object({<br/>    requests = optional(object({<br/>      cpu    = optional(string, "25m")<br/>      memory = optional(string, "64Mi")<br/>    }), {})<br/>    limits = optional(object({<br/>      cpu    = optional(string, "100m")<br/>      memory = optional(string, "256Mi")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | cert-manager Helm chart version | `string` | `"1.16.2"` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for DNS01 challenges | `string` | `""` | no |
| <a name="input_cloudflare_email"></a> [cloudflare\_email](#input\_cloudflare\_email) | Cloudflare account email | `string` | `""` | no |
| <a name="input_controller_replicas"></a> [controller\_replicas](#input\_controller\_replicas) | Number of cert-manager controller replicas | `number` | `1` | no |
| <a name="input_controller_resources"></a> [controller\_resources](#input\_controller\_resources) | Resource requests/limits for cert-manager controller | <pre>object({<br/>    requests = optional(object({<br/>      cpu    = optional(string, "50m")<br/>      memory = optional(string, "64Mi")<br/>    }), {})<br/>    limits = optional(object({<br/>      cpu    = optional(string, "200m")<br/>      memory = optional(string, "256Mi")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_create_letsencrypt_issuer"></a> [create\_letsencrypt\_issuer](#input\_create\_letsencrypt\_issuer) | Create Let's Encrypt ClusterIssuer | `bool` | `false` | no |
| <a name="input_create_selfsigned_issuer"></a> [create\_selfsigned\_issuer](#input\_create\_selfsigned\_issuer) | Create self-signed ClusterIssuer for internal certificates | `bool` | `true` | no |
| <a name="input_dns01_enabled"></a> [dns01\_enabled](#input\_dns01\_enabled) | Enable DNS01 challenge support | `bool` | `false` | no |
| <a name="input_install_crds"></a> [install\_crds](#input\_install\_crds) | Install cert-manager CRDs | `bool` | `true` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email for Let's Encrypt registration | `string` | `""` | no |
| <a name="input_letsencrypt_server"></a> [letsencrypt\_server](#input\_letsencrypt\_server) | Let's Encrypt server (staging or production) | `string` | `"production"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for cert-manager | `string` | `"cert-manager"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Helm install timeout in seconds | `number` | `300` | no |
| <a name="input_webhook_replicas"></a> [webhook\_replicas](#input\_webhook\_replicas) | Number of cert-manager webhook replicas | `number` | `1` | no |
| <a name="input_webhook_resources"></a> [webhook\_resources](#input\_webhook\_resources) | Resource requests/limits for cert-manager webhook | <pre>object({<br/>    requests = optional(object({<br/>      cpu    = optional(string, "25m")<br/>      memory = optional(string, "32Mi")<br/>    }), {})<br/>    limits = optional(object({<br/>      cpu    = optional(string, "100m")<br/>      memory = optional(string, "128Mi")<br/>    }), {})<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ca_issuer_name"></a> [ca\_issuer\_name](#output\_ca\_issuer\_name) | Name of the CA ClusterIssuer |
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Installed cert-manager chart version |
| <a name="output_letsencrypt_issuer_name"></a> [letsencrypt\_issuer\_name](#output\_letsencrypt\_issuer\_name) | Name of the Let's Encrypt ClusterIssuer |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace where cert-manager is deployed |
| <a name="output_selfsigned_issuer_name"></a> [selfsigned\_issuer\_name](#output\_selfsigned\_issuer\_name) | Name of the self-signed ClusterIssuer |
<!-- END_TF_DOCS -->