# Ingress-NGINX Kubernetes Addon Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/addons-ingress-nginx)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to deploy [Ingress-NGINX](https://kubernetes.github.io/ingress-nginx/) controller on a Kubernetes cluster.

## Usage

```hcl
provider "helm" {
  kubernetes {
    config_path = "./kubeconfig"
  }
}

module "ingress" {
  source  = "freed-dev-llc/ingress-nginx/kubernetes"
  version = ">= 1.3.0"

  loadbalancer_ip = "192.168.1.200"  # Optional: use with MetalLB
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Ingress-NGINX Helm chart version | `string` | `"4.11.3"` | no |
| <a name="input_default_ingress_class"></a> [default\_ingress\_class](#input\_default\_ingress\_class) | Make this the default ingress class | `bool` | `true` | no |
| <a name="input_enable_admission_webhooks"></a> [enable\_admission\_webhooks](#input\_enable\_admission\_webhooks) | Enable admission webhooks | `bool` | `true` | no |
| <a name="input_loadbalancer_ip"></a> [loadbalancer\_ip](#input\_loadbalancer\_ip) | Static IP for ingress LoadBalancer (optional) | `string` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Helm install timeout in seconds | `number` | `300` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Deployed chart version |
| <a name="output_controller_service"></a> [controller\_service](#output\_controller\_service) | Ingress controller service name |
| <a name="output_loadbalancer_ip"></a> [loadbalancer\_ip](#output\_loadbalancer\_ip) | LoadBalancer IP (if specified) |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Ingress-NGINX namespace |
<!-- END_TF_DOCS -->

## Provider Configuration

This module requires the `helm` provider to be configured with access to your Kubernetes cluster:

```hcl
provider "helm" {
  kubernetes {
    config_path = "./kubeconfig"
  }
}
```

## Using with MetalLB

When using with the MetalLB module, specify a `loadbalancer_ip` from your MetalLB IP pool:

```hcl
module "metallb" {
  source   = "freed-dev-llc/metallb/kubernetes"
  ip_range = "192.168.1.200-192.168.1.220"
}

module "ingress" {
  source          = "freed-dev-llc/ingress-nginx/kubernetes"
  depends_on      = [module.metallb]
  loadbalancer_ip = "192.168.1.200"
}
```

## License

Apache 2.0 - See [LICENSE](../../../LICENSE) for details.
