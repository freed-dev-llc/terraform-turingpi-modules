# Longhorn Distributed Storage Module

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-freed--dev--llc%2Fturingpi-blue?logo=terraform)](https://registry.terraform.io/modules/freed-dev-llc/modules/turingpi/latest/submodules/addons-longhorn)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Terraform module to deploy [Longhorn](https://longhorn.io/) distributed block storage on a Kubernetes cluster.

## Usage

```hcl
module "longhorn" {
  source  = "freed-dev-llc/modules/turingpi//modules/addons/longhorn"
  version = ">= 1.3.0"

  # Basic configuration
  default_replica_count = 2

  # Optional: NVMe-optimized storage class
  # create_nvme_storage_class = true
  # nvme_replica_count        = 2

  # Optional: Ingress for UI access
  # ingress_enabled = true
  # ingress_host    = "longhorn.local"

  # Optional: S3 backup target
  # backup_target                   = "s3://my-bucket@us-east-1/longhorn-backup"
  # backup_target_credential_secret = "longhorn-backup-secret"
}
```

## Prerequisites

### Talos Linux

When running on Talos Linux, Longhorn requires system extensions that are not included in the default image:

| Extension | Required For | Purpose |
|-----------|--------------|---------|
| `siderolabs/iscsi-tools` | **Required** | iSCSI initiator for distributed block storage |
| `siderolabs/util-linux-tools` | **Required** | Filesystem utilities (blkid, lsblk, etc.) |
| `siderolabs/nfs-utils` | Optional | NFSv3 file locking support for RWX volumes |

Build a custom Talos image with these extensions using the [Talos Image Factory](https://factory.talos.dev):

```bash
# Create a schematic with required extensions
curl -X POST https://factory.talos.dev/schematics \
  -H "Content-Type: application/yaml" \
  --data-binary @- << 'EOF'
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
EOF

# Download the image for ARM64 (e.g., Turing RK1)
# Replace {SCHEMATIC_ID} with the returned ID and {VERSION} with Talos version
curl -LO "https://factory.talos.dev/image/{SCHEMATIC_ID}/{VERSION}/metal-arm64.raw.xz"
```

**Pre-built Schematic ID** (iscsi-tools + util-linux-tools):

```
613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245
```

### Standard Kubernetes (K3s, K8s)

Most standard Kubernetes distributions include the required tools. However, some base images (like Armbian) may need packages installed:

**Debian/Ubuntu/Armbian:**

```bash
apt-get update && apt-get install -y open-iscsi nfs-common
systemctl enable --now iscsid
```

**RHEL/CentOS/Rocky:**

```bash
yum install -y iscsi-initiator-utils nfs-utils
systemctl enable --now iscsid
```

### Storage Capacity Planning

Longhorn reserves approximately 30% of disk space by default. On nodes with limited storage (e.g., 32GB eMMC), this can significantly reduce schedulable capacity:

| Disk Size | Reserved (~30%) | Schedulable |
|-----------|-----------------|-------------|
| 32GB      | ~9.6GB          | ~22GB       |
| 64GB      | ~19.2GB         | ~45GB       |
| 128GB     | ~38.4GB         | ~90GB       |

**Tip:** For eMMC-constrained nodes, consider:

- Reducing `prometheus_storage_size` to 10Gi or less
- Using `default_replica_count = 1` for non-critical workloads
- Adding NVMe storage and using disk selectors

### Namespace Security

On clusters with Pod Security Admission enabled, the `longhorn-system` namespace requires privileged access:

```bash
kubectl label namespace longhorn-system pod-security.kubernetes.io/enforce=privileged --overwrite
```

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
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_target"></a> [backup\_target](#input\_backup\_target) | Backup target URL (e.g., s3://bucket@region/path) | `string` | `null` | no |
| <a name="input_backup_target_credential_secret"></a> [backup\_target\_credential\_secret](#input\_backup\_target\_credential\_secret) | Secret name containing backup credentials | `string` | `null` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Longhorn Helm chart version | `string` | `"1.7.2"` | no |
| <a name="input_create_nvme_storage_class"></a> [create\_nvme\_storage\_class](#input\_create\_nvme\_storage\_class) | Create an NVMe-optimized storage class with disk selector | `bool` | `false` | no |
| <a name="input_default_data_path"></a> [default\_data\_path](#input\_default\_data\_path) | Default data path for Longhorn storage | `string` | `"/var/lib/longhorn"` | no |
| <a name="input_default_replica_count"></a> [default\_replica\_count](#input\_default\_replica\_count) | Default number of replicas for volumes (1-3) | `number` | `2` | no |
| <a name="input_ingress_annotations"></a> [ingress\_annotations](#input\_ingress\_annotations) | Additional annotations for Longhorn Ingress | `map(string)` | `{}` | no |
| <a name="input_ingress_enabled"></a> [ingress\_enabled](#input\_ingress\_enabled) | Enable Ingress for Longhorn UI | `bool` | `false` | no |
| <a name="input_ingress_host"></a> [ingress\_host](#input\_ingress\_host) | Hostname for Longhorn UI Ingress | `string` | `"longhorn.local"` | no |
| <a name="input_manager_resources"></a> [manager\_resources](#input\_manager\_resources) | Resource requests/limits for Longhorn manager | <pre>object({<br/>    requests = optional(object({<br/>      cpu    = optional(string, "100m")<br/>      memory = optional(string, "128Mi")<br/>    }), {})<br/>    limits = optional(object({<br/>      cpu    = optional(string, "500m")<br/>      memory = optional(string, "512Mi")<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for Longhorn | `string` | `"longhorn-system"` | no |
| <a name="input_nvme_replica_count"></a> [nvme\_replica\_count](#input\_nvme\_replica\_count) | Replica count for NVMe storage class (typically lower for performance) | `number` | `2` | no |
| <a name="input_privileged_namespace"></a> [privileged\_namespace](#input\_privileged\_namespace) | Apply privileged PodSecurity labels to namespace (required for Talos Linux) | `bool` | `true` | no |
| <a name="input_set_default_storage_class"></a> [set\_default\_storage\_class](#input\_set\_default\_storage\_class) | Set Longhorn as the default storage class | `bool` | `true` | no |
| <a name="input_set_nvme_as_default"></a> [set\_nvme\_as\_default](#input\_set\_nvme\_as\_default) | Set NVMe storage class as default instead of standard Longhorn | `bool` | `false` | no |
| <a name="input_talos_extensions_installed"></a> [talos\_extensions\_installed](#input\_talos\_extensions\_installed) | Acknowledge that required Talos extensions are installed (iscsi-tools, util-linux-tools). Set to true only after flashing nodes with a custom Talos image that includes these extensions. See README for Image Factory instructions. | `bool` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Helm install timeout in seconds | `number` | `600` | no |
| <a name="input_ui_replicas"></a> [ui\_replicas](#input\_ui\_replicas) | Number of Longhorn UI replicas | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Deployed Longhorn chart version |
| <a name="output_default_storage_class"></a> [default\_storage\_class](#output\_default\_storage\_class) | Default storage class name |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Longhorn namespace |
| <a name="output_nvme_storage_class"></a> [nvme\_storage\_class](#output\_nvme\_storage\_class) | NVMe storage class name (if created) |
| <a name="output_ui_url"></a> [ui\_url](#output\_ui\_url) | Longhorn UI URL (if ingress enabled) |
<!-- END_TF_DOCS -->

## NVMe Storage Configuration

For nodes with NVMe drives, you can create an optimized storage class:

```hcl
module "longhorn" {
  source = "freed-dev-llc/modules/turingpi//modules/addons/longhorn"

  create_nvme_storage_class = true
  nvme_replica_count        = 2  # Lower replica count for performance

  # Optionally set NVMe as the default
  # set_nvme_as_default = true
}
```

After deployment, tag your NVMe disks in Longhorn UI or via API:

- Add tag `nvme` to NVMe disk nodes

## License

Apache 2.0 - See [LICENSE](../../../LICENSE) for details.
